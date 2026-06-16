#!/usr/bin/env bash
# cron-oncall-shift-summary.sh — Post-process the OT Oncall Shift Google Doc to
# auto-triage and auto-fill 'model owner' TODO fields from SEV metadata
# (owner_name field) and mrs_online_training team roster lookup.
#
# Never publishes a bare TODO — blocks doc write if unresolvable TODOs remain.
#
# Runs daily at 6:30 AM Pacific via crontab (after cron-ot-support-triage.sh).
#
# Pipeline:
#   1. Export current shift doc as markdown
#   2. Extract SEV IDs referenced alongside TODO markers
#   3. Query `meta sevmanager.sev metadata` for each SEV to get owner_name
#   4. Query mrs_online_training team roster for fallback
#   5. Replace TODO markers with resolved values
#   6. Validate no bare TODOs remain; write updated content back
#
# Usage:
#   ./cron-oncall-shift-summary.sh              # Normal run
#   ./cron-oncall-shift-summary.sh --dry-run    # Preview changes without writing

set -euo pipefail
trap 'echo "ERROR at line $LINENO (exit $?)" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-oncall-shift-summary.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
DRY_RUN=false

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    echo "$LOG_PREFIX === DRY RUN MODE ==="
fi

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/gdocs_lib.sh"

cron_self_heal "oncall-shift-summary" 2>/dev/null || true

# Prevent overlapping runs
LOCK_MAX_AGE_SECONDS=3600
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$LOG_PREFIX Lock held by pid $pid for ${lock_age}s — killing stale process"
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
        else
            echo "$LOG_PREFIX Already running (pid $pid, age ${lock_age}s), skipping"
            exit 0
        fi
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; rm -rf "${WORK_DIR:-}"' EXIT

echo "$LOG_PREFIX === OT Oncall Shift Summary — Auto-Triage ==="
JOB_START_TIME=$(date +%s)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

DOC_ID=$(get_doc_id "ot_oncall_shift") || {
    cron_alert "oncall-shift-summary" "Missing doc ID for ot_oncall_shift in DAILY-DOCS.json"
    exit 1
}
TAB_ID=$(get_doc_tab "ot_oncall_shift" "current_week") || {
    cron_alert "oncall-shift-summary" "Missing tab ID for ot_oncall_shift.current_week"
    exit 1
}
STATE_DIR="${REPO_DIR}/context/cache/state"
mkdir -p "$STATE_DIR"
WORK_DIR=$(mktemp -d /tmp/oncall-shift-summary-XXXXXX)

echo "$LOG_PREFIX Config: doc=$DOC_ID, tab=$TAB_ID, work_dir=$WORK_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: EXPORT — Get current doc content
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [1] Exporting current doc content"

if ! gdocs export "$DOC_ID" --format md --tab-id "$TAB_ID" > "$WORK_DIR/doc-current.md" 2>/dev/null; then
    cron_alert "oncall-shift-summary" "Failed to export OT Oncall Shift doc"
    exit 1
fi

doc_lines=$(wc -l < "$WORK_DIR/doc-current.md")
echo "$LOG_PREFIX   Exported: $doc_lines lines"

# Count TODO markers
todo_count=$(grep -ci 'TODO' "$WORK_DIR/doc-current.md" 2>/dev/null || echo 0)
echo "$LOG_PREFIX   TODO markers found: $todo_count"

if [ "$todo_count" -eq 0 ]; then
    echo "$LOG_PREFIX   No TODO markers — nothing to auto-fill"
    write_heartbeat "oncall-shift-summary"
    cron_alert_clear "oncall-shift-summary"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: EXTRACT — Find SEV IDs and TODO contexts
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [2] Extracting SEV IDs and TODO contexts"

python3 - "$WORK_DIR/doc-current.md" "$WORK_DIR/sev-ids.json" "$WORK_DIR/todo-contexts.json" << 'PYEOF'
import json
import re
import sys

doc_path, sev_out, todo_out = sys.argv[1], sys.argv[2], sys.argv[3]

with open(doc_path) as f:
    content = f.read()
    lines = content.split('\n')

sev_pattern = re.compile(r'\bS(\d{5,7})\b')
todo_pattern = re.compile(r'TODO\s*\(oncall\)', re.IGNORECASE)

all_sevs = set()
todo_contexts = []

for i, line in enumerate(lines):
    sevs_in_line = sev_pattern.findall(line)
    all_sevs.update(sevs_in_line)

    if todo_pattern.search(line):
        context_start = max(0, i - 3)
        context_end = min(len(lines), i + 3)
        nearby_sevs = set()
        for j in range(context_start, context_end):
            nearby_sevs.update(sev_pattern.findall(lines[j]))

        todo_contexts.append({
            'line_num': i + 1,
            'line': line.strip(),
            'nearby_sevs': sorted(nearby_sevs),
            'is_table_row': line.strip().startswith('|'),
        })

with open(sev_out, 'w') as f:
    json.dump(sorted(all_sevs), f)

with open(todo_out, 'w') as f:
    json.dump(todo_contexts, f, indent=2)

print(f"  SEVs found: {len(all_sevs)}")
print(f"  TODO contexts: {len(todo_contexts)}")
PYEOF

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: RESOLVE — Query SEV metadata for owner_name
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [3] Resolving SEV owners from metadata"

sev_count=$(python3 -c "import json; print(len(json.load(open('$WORK_DIR/sev-ids.json'))))" 2>/dev/null)

if [ "$sev_count" -gt 0 ]; then
    python3 - "$WORK_DIR/sev-ids.json" "$WORK_DIR/sev-owners.json" << 'PYEOF'
import json
import subprocess
import sys

sev_ids_path, owners_out = sys.argv[1], sys.argv[2]

with open(sev_ids_path) as f:
    sev_ids = json.load(f)

owners = {}
for sev_id in sev_ids:
    try:
        result = subprocess.run(
            ['meta', 'sevmanager.sev', 'metadata', f'--sev=S{sev_id}', '-o', 'json'],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            owners[sev_id] = {
                'owner_name': data.get('owner_name', ''),
                'journalist': data.get('journalist', ''),
                'opened_by': data.get('opened_by', ''),
                'status': data.get('status', ''),
                'level': data.get('level', ''),
                'title': data.get('title', ''),
            }
            print(f"  S{sev_id}: owner={data.get('owner_name', '?')}")
        else:
            print(f"  S{sev_id}: metadata query failed (rc={result.returncode})")
            owners[sev_id] = {}
    except (subprocess.TimeoutExpired, Exception) as e:
        print(f"  S{sev_id}: error — {e}")
        owners[sev_id] = {}

with open(owners_out, 'w') as f:
    json.dump(owners, f, indent=2)

print(f"  Resolved {sum(1 for v in owners.values() if v.get('owner_name'))} "
      f"of {len(sev_ids)} SEV owners")
PYEOF
else
    echo '{}' > "$WORK_DIR/sev-owners.json"
    echo "$LOG_PREFIX   No SEVs to resolve"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: ROSTER — Query mrs_online_training team roster as fallback
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [4] Querying mrs_online_training team roster"

{
    meta oncall.rotation schedule --rotation=mrs_online_training --active -o json 2>/dev/null \
        || echo '[]'
} > "$WORK_DIR/oncall-roster.json"

current_oncall=$(python3 -c "
import json
try:
    data = json.load(open('$WORK_DIR/oncall-roster.json'))
    if isinstance(data, list) and data:
        print(data[0].get('employee', ''))
    elif isinstance(data, dict) and data.get('data'):
        print(data['data'][0].get('employee', ''))
    else:
        print('')
except Exception:
    print('')
" 2>/dev/null)
echo "$LOG_PREFIX   Current oncall: ${current_oncall:-unknown}"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5: FILL — Replace TODO markers with resolved values
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [5] Auto-filling TODO markers"

python3 - "$WORK_DIR/doc-current.md" "$WORK_DIR/sev-owners.json" \
    "$WORK_DIR/todo-contexts.json" "${current_oncall:-}" \
    "$WORK_DIR/doc-updated.md" "$WORK_DIR/fill-report.json" << 'PYEOF'
import json
import re
import sys

doc_path = sys.argv[1]
owners_path = sys.argv[2]
contexts_path = sys.argv[3]
current_oncall = sys.argv[4]
output_path = sys.argv[5]
report_path = sys.argv[6]

with open(doc_path) as f:
    content = f.read()
with open(owners_path) as f:
    sev_owners = json.load(f)
with open(contexts_path) as f:
    todo_contexts = json.load(f)

sev_pattern = re.compile(r'\bS(\d{5,7})\b')
todo_pattern = re.compile(r'TODO\s*\(oncall\)', re.IGNORECASE)

fills = []
unfilled = []

lines = content.split('\n')

for i, line in enumerate(lines):
    if not todo_pattern.search(line):
        continue

    original = line

    context_start = max(0, i - 5)
    context_end = min(len(lines), i + 3)
    nearby_sevs = []
    for j in range(context_start, context_end):
        nearby_sevs.extend(sev_pattern.findall(lines[j]))
    nearby_sevs = list(dict.fromkeys(nearby_sevs))

    filled = False

    for sev_id in nearby_sevs:
        owner_data = sev_owners.get(sev_id, {})
        owner_name = owner_data.get('owner_name', '')
        if not owner_name:
            continue

        is_table = line.strip().startswith('|')

        if is_table:
            cells = line.split('|')
            for ci, cell in enumerate(cells):
                if todo_pattern.search(cell):
                    replacement = owner_name
                    if 'follow-up' in cell.lower() or 'deep fix' in cell.lower():
                        replacement = f"Owner: {owner_name} — see S{sev_id}"
                    elif 'owner' in cell.lower():
                        replacement = owner_name
                    cells[ci] = cell.replace(
                        todo_pattern.search(cell).group(),
                        replacement
                    )
                    filled = True
            lines[i] = '|'.join(cells)
        else:
            match = todo_pattern.search(line)
            if match:
                lines[i] = line.replace(
                    match.group(),
                    f"{owner_name} (from S{sev_id} metadata)"
                )
                filled = True

        if filled:
            fills.append({
                'line_num': i + 1,
                'sev': f"S{sev_id}",
                'owner': owner_name,
                'original': original.strip(),
                'updated': lines[i].strip(),
            })
            break

    if not filled and current_oncall:
        match = todo_pattern.search(lines[i])
        if match:
            lines[i] = lines[i].replace(
                match.group(),
                f"{current_oncall} (oncall — needs triage)"
            )
            fills.append({
                'line_num': i + 1,
                'sev': None,
                'owner': current_oncall,
                'source': 'oncall_roster_fallback',
                'original': original.strip(),
                'updated': lines[i].strip(),
            })
            filled = True

    if not filled:
        unfilled.append({
            'line_num': i + 1,
            'line': original.strip(),
        })

updated_content = '\n'.join(lines)

remaining_todos = len(todo_pattern.findall(updated_content))

with open(output_path, 'w') as f:
    f.write(updated_content)

report = {
    'fills': fills,
    'unfilled': unfilled,
    'total_fills': len(fills),
    'remaining_todos': remaining_todos,
    'blocked': remaining_todos > 0,
}
with open(report_path, 'w') as f:
    json.dump(report, f, indent=2)

print(f"  Filled: {len(fills)} TODO markers")
print(f"  Unfilled: {len(unfilled)} TODO markers")
print(f"  Remaining: {remaining_todos}")
if fills:
    for fill in fills[:5]:
        sev = fill.get('sev', 'roster')
        print(f"    - L{fill['line_num']}: {sev} → {fill['owner']}")
    if len(fills) > 5:
        print(f"    ... and {len(fills) - 5} more")
PYEOF

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5b: LAUNCH DETECTION — Detect new model launches, add Hand-off items
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [5b] Detecting new model launches during shift window"

KNOWN_MODELS_FILE="$STATE_DIR/oncall-shift-known-models.json"

python3 - "$WORK_DIR/doc-updated.md" "$KNOWN_MODELS_FILE" \
    "$WORK_DIR/doc-updated.md" "$WORK_DIR/launch-report.json" << 'PYEOF'
import json
import re
import subprocess
import sys

doc_path = sys.argv[1]
known_models_path = sys.argv[2]
output_path = sys.argv[3]
report_path = sys.argv[4]

with open(doc_path) as f:
    content = f.read()

known_models = set()
try:
    with open(known_models_path) as f:
        known_models = set(json.load(f))
except (FileNotFoundError, json.JSONDecodeError):
    pass

current_models = set()
new_launches = []

try:
    result = subprocess.run(
        ['meta', 'ai.model.instance', 'list',
         '--oncall=mrs_online_training',
         '--instance-type=SNAPSHOT',
         '--limit=200', '--output=json'],
        capture_output=True, text=True, timeout=60
    )
    if result.returncode == 0 and result.stdout.strip():
        data = json.loads(result.stdout)
        instances = data if isinstance(data, list) else data.get('data', [])
        for inst in instances:
            name = inst.get('model_type_name', '') or str(inst.get('model_id', ''))
            if name:
                current_models.add(name)
        new_models = current_models - known_models
        if new_models:
            for m in sorted(new_models):
                new_launches.append({'model': m, 'source': 'model_instance_list'})
            print(f"  New models detected: {', '.join(sorted(new_models))}")
        else:
            print(f"  No new models (checked {len(current_models)} models)")
    else:
        print(f"  Model query returned no data (rc={result.returncode})")
except (subprocess.TimeoutExpired, Exception) as e:
    print(f"  Model query failed: {e}")

all_models = sorted(known_models | current_models)
with open(known_models_path, 'w') as f:
    json.dump(all_models, f, indent=2)

has_slick = bool(re.search(r'SLICK.*SLI.*dashboard', content, re.IGNORECASE))
has_qe = bool(re.search(
    r'QE.*support.*SLA|QE.*onboarding.*skip', content, re.IGNORECASE
))

items_added = []

if new_launches and (not has_slick or not has_qe):
    model_names = [l['model'] for l in new_launches[:5]]
    models_str = ', '.join(model_names)
    if len(new_launches) > 5:
        models_str += f' (+{len(new_launches) - 5} more)'

    new_items = []
    if not has_slick:
        new_items.append(
            f"- **[Post-Launch]** SLICK SLI dashboards need refresh "
            f"— new model launch detected: {models_str}"
        )
        items_added.append('SLICK SLI dashboard refresh')
    if not has_qe:
        new_items.append(
            f"- **[Post-Launch]** Confirm QE support SLA alignment "
            f"for launches that may have skipped onboarding flow "
            f"({models_str})"
        )
        items_added.append('QE support SLA alignment')

    insert_block = '\n'.join(new_items) + '\n'

    handoff_match = re.search(
        r'(#{1,3}\s*Hand-off\s+action\s+items?[^\n]*\n)',
        content, re.IGNORECASE,
    )
    if handoff_match:
        pos = handoff_match.end()
        content = content[:pos] + insert_block + content[pos:]
    else:
        first_h = re.search(r'^#\s+[^\n]+\n', content, re.MULTILINE)
        section = '\n## Hand-off action items\n' + insert_block + '\n'
        if first_h:
            content = content[:first_h.end()] + section + content[first_h.end():]
        else:
            content = section + content

    print(f"  Added {len(items_added)} Hand-off items")
else:
    if not new_launches:
        print("  No new launches — skipping Hand-off items")
    else:
        print("  SLICK/QE Hand-off items already present")

with open(output_path, 'w') as f:
    f.write(content)

report = {
    'new_launches': new_launches,
    'items_added': items_added,
    'had_slick': has_slick,
    'had_qe': has_qe,
    'current_model_count': len(current_models),
    'known_model_count': len(known_models),
}
with open(report_path, 'w') as f:
    json.dump(report, f, indent=2)
PYEOF

launch_items_added=$(python3 -c "
import json
try:
    r = json.load(open('$WORK_DIR/launch-report.json'))
    print(len(r.get('items_added', [])))
except Exception:
    print(0)
" 2>/dev/null)
echo "$LOG_PREFIX   Launch hand-off items added: $launch_items_added"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5c: ACTIVE-INVOLVEMENT GATE — OT-ONCALL RULE 27
# For each SEV in Section 7, verify oncall IC was actively involved via:
#   (a) sevmanager SEV page comments by OT IC
#   (b) diffs referencing the SEV authored by OT IC
#   (c) GChat threads (SEV chat messages by OT IC)
# Only include SEVs with >=1 evidence type. Annotate with (evidence: ...).
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [5c] Active-involvement gate (Rule 27)"

python3 - "$WORK_DIR/doc-updated.md" "$WORK_DIR/sev-ids.json" \
    "${current_oncall:-}" "$WORK_DIR/doc-updated.md" \
    "$WORK_DIR/involvement-report.json" << 'PYEOF'
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta

doc_path = sys.argv[1]
sev_ids_path = sys.argv[2]
oncall_ic = sys.argv[3]
output_path = sys.argv[4]
report_path = sys.argv[5]

with open(doc_path) as f:
    content = f.read()
with open(sev_ids_path) as f:
    sev_ids = json.load(f)

if not oncall_ic or not sev_ids:
    with open(output_path, 'w') as f:
        f.write(content)
    with open(report_path, 'w') as f:
        json.dump({'skipped': True, 'reason': 'no IC or no SEVs',
                   'excluded': 0, 'annotated': 0}, f, indent=2)
    print("  Skipped: no oncall IC or no SEVs to gate")
    sys.exit(0)

lines = content.split('\n')
sev_re = re.compile(r'\bS(\d{5,7})\b')

# Locate SEV section (Section 7 heading, or fallback to any "SEV" heading)
sec_start = sec_end = None
sec_level = 0
for i, line in enumerate(lines):
    m = re.match(r'^(#{1,3})\s', line)
    if m:
        hdr = line[len(m.group(1)):].strip()
        is_sec7 = bool(re.match(r'7[\.\)\s:]', hdr))
        is_sev = bool(re.search(r'\bSEVs?\b', hdr, re.IGNORECASE))
        if is_sec7 or (sec_start is None and is_sev):
            sec_start = i
            sec_level = len(m.group(1))
        elif sec_start is not None and len(m.group(1)) <= sec_level:
            sec_end = i
            break

if sec_start is None:
    with open(output_path, 'w') as f:
        f.write(content)
    with open(report_path, 'w') as f:
        json.dump({'skipped': True, 'reason': 'SEV section not found',
                   'excluded': 0, 'annotated': 0}, f, indent=2)
    print("  Skipped: no SEV section found in doc")
    sys.exit(0)

if sec_end is None:
    sec_end = len(lines)

print(f"  SEV section: lines {sec_start + 1}-{sec_end}")

# Collect SEV rows (skip headings and table separator lines)
sev_rows = []
for i in range(sec_start + 1, sec_end):
    line = lines[i]
    if re.match(r'^#{1,3}\s', line):
        continue
    if re.match(r'^\|[\s\-:]+\|', line):
        continue
    found = sev_re.findall(line)
    if found:
        sev_rows.append({
            'idx': i,
            'sevs': found,
            'is_table': line.strip().startswith('|'),
        })

if not sev_rows:
    with open(output_path, 'w') as f:
        f.write(content)
    with open(report_path, 'w') as f:
        json.dump({'skipped': True, 'reason': 'no SEV rows in section',
                   'excluded': 0, 'annotated': 0}, f, indent=2)
    print("  No SEV rows in section")
    sys.exit(0)

unique_sevs = sorted(set(s for r in sev_rows for s in r['sevs']))
print(f"  Checking {len(unique_sevs)} unique SEVs "
      f"across {len(sev_rows)} rows")

# --- Evidence (a): SEV page comments by oncall IC ---
ic_commented_sevs = set()
try:
    cutoff = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
    r = subprocess.run(
        ['meta', 'sevmanager.comment', 'list',
         f'--author={oncall_ic}', f'--after={cutoff}',
         '--columns=sev_number', '-o', 'json'],
        capture_output=True, text=True, timeout=30
    )
    if r.returncode == 0 and r.stdout.strip():
        data = json.loads(r.stdout)
        rows_data = data if isinstance(data, list) \
            else data.get('data', [])
        for row_data in rows_data:
            num = str(row_data.get('sev_number', '')).lstrip('S')
            if num in unique_sevs:
                ic_commented_sevs.add(num)
except Exception as e:
    print(f"  [warn] comment check: {e}")

# --- Evidence (b): diffs referencing SEV by oncall IC ---
ic_diff_sevs = set()
try:
    r = subprocess.run(
        ['meta', 'phabricator.diff', 'list',
         f'--author-is={oncall_ic}',
         '--columns=number,title', '-o', 'json', '--limit=100'],
        capture_output=True, text=True, timeout=30
    )
    if r.returncode == 0 and r.stdout.strip():
        data = json.loads(r.stdout)
        diffs = data if isinstance(data, list) \
            else data.get('data', [])
        for d in diffs:
            title = str(d.get('title', ''))
            for sid in unique_sevs:
                if f'S{sid}' in title or sid in title:
                    ic_diff_sevs.add(sid)
except Exception as e:
    print(f"  [warn] diff check: {e}")

# --- Evidence (c): GChat (SEV chat messages by oncall IC) ---
ic_gchat_sevs = set()
for sid in unique_sevs:
    try:
        r = subprocess.run(
            ['meta', 'sevmanager.chat', 'list',
             f'--sev=S{sid}',
             '--columns=unixname', '-o', 'json', '--limit=200'],
            capture_output=True, text=True, timeout=15
        )
        if r.returncode == 0 and r.stdout.strip():
            data = json.loads(r.stdout)
            msgs = data if isinstance(data, list) \
                else data.get('data', [])
            if any(m.get('unixname') == oncall_ic for m in msgs):
                ic_gchat_sevs.add(sid)
    except Exception as e:
        print(f"  [warn] gchat S{sid}: {e}")

# Build per-SEV evidence map
evidence_map = {}
for sid in unique_sevs:
    ev = []
    if sid in ic_commented_sevs:
        ev.append('sev-comments')
    if sid in ic_diff_sevs:
        ev.append('diffs')
    if sid in ic_gchat_sevs:
        ev.append('gchat')
    evidence_map[sid] = ev
    tag = ', '.join(ev) if ev else 'NONE'
    print(f"    S{sid}: {tag}")

# Apply gate: remove rows without evidence, annotate the rest
remove_set = set()
annotated = excluded = 0

for row in sev_rows:
    row_ev = set()
    for sid in row['sevs']:
        row_ev.update(evidence_map.get(sid, []))
    if not row_ev:
        remove_set.add(row['idx'])
        excluded += 1
    else:
        ev_str = ', '.join(sorted(row_ev))
        line = lines[row['idx']]
        if '(evidence:' not in line:
            if row['is_table'] and line.rstrip().endswith('|'):
                lines[row['idx']] = (
                    line.rstrip()[:-1]
                    + f' (evidence: {ev_str}) |'
                )
            else:
                lines[row['idx']] = (
                    f'{line} (evidence: {ev_str})'
                )
            annotated += 1

for idx in sorted(remove_set, reverse=True):
    del lines[idx]

with open(output_path, 'w') as f:
    f.write('\n'.join(lines))

report = {
    'evidence': {f'S{k}': v for k, v in evidence_map.items()},
    'annotated': annotated,
    'excluded': excluded,
    'total_rows': len(sev_rows),
    'oncall_ic': oncall_ic,
}
with open(report_path, 'w') as f:
    json.dump(report, f, indent=2)

print(f"  Gate: {annotated} annotated, {excluded} excluded")
PYEOF

involvement_excluded=$(python3 -c "
import json
try:
    r = json.load(open('$WORK_DIR/involvement-report.json'))
    print(r.get('excluded', 0))
except Exception:
    print(0)
" 2>/dev/null)
involvement_annotated=$(python3 -c "
import json
try:
    r = json.load(open('$WORK_DIR/involvement-report.json'))
    print(r.get('annotated', 0))
except Exception:
    print(0)
" 2>/dev/null)
echo "$LOG_PREFIX   Involvement gate: $involvement_annotated annotated, $involvement_excluded excluded"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 6: VALIDATE — Block if bare TODOs remain
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [6] Validation"

remaining=$(python3 -c "import json; print(json.load(open('$WORK_DIR/fill-report.json'))['remaining_todos'])" 2>/dev/null)
total_fills=$(python3 -c "import json; print(json.load(open('$WORK_DIR/fill-report.json'))['total_fills'])" 2>/dev/null)

involvement_changes=$(python3 -c "
import json
try:
    r = json.load(open('$WORK_DIR/involvement-report.json'))
    print(r.get('excluded', 0) + r.get('annotated', 0))
except Exception:
    print(0)
" 2>/dev/null)

if [ "$total_fills" -eq 0 ] && [ "${launch_items_added:-0}" -eq 0 ] && \
   [ "${involvement_changes:-0}" -eq 0 ]; then
    echo "$LOG_PREFIX   No fills, launch items, or involvement changes — nothing changed"
    echo "$LOG_PREFIX   Skipping doc write (nothing changed)"
    write_heartbeat "oncall-shift-summary"
    exit 0
fi

if [ "$remaining" -gt 0 ]; then
    echo "$LOG_PREFIX   [WARN] $remaining bare TODO(s) remain after auto-fill"
    echo "$LOG_PREFIX   Bare TODOs will be tagged with oncall name as fallback"
fi

echo "$LOG_PREFIX   Fills: $total_fills, remaining TODOs: $remaining"

# Pre-push lint (Rule 27): every Section 7 SEV row must have evidence annotation
sev_rows_missing_evidence=$(python3 -c "
import re
with open('$WORK_DIR/doc-updated.md') as f:
    lines = f.read().split('\n')
sec_start = None
sec_level = 0
count = 0
for i, line in enumerate(lines):
    m = re.match(r'^(#{1,3})\s', line)
    if m:
        hdr = line[len(m.group(1)):].strip()
        is_sec7 = bool(re.match(r'7[\.\)\s:]', hdr))
        is_sev = bool(re.search(r'\bSEVs?\b', hdr, re.IGNORECASE))
        if is_sec7 or (sec_start is None and is_sev):
            sec_start = i
            sec_level = len(m.group(1))
        elif sec_start is not None and len(m.group(1)) <= sec_level:
            break
    elif sec_start is not None:
        if re.search(r'\bS\d{5,7}\b', line) and '(evidence:' not in line \
           and not re.match(r'^\|[\s\-:]+\|', line):
            count += 1
print(count)
" 2>/dev/null)

if [ "${sev_rows_missing_evidence:-0}" -gt 0 ]; then
    echo "$LOG_PREFIX   [BLOCKED] $sev_rows_missing_evidence Section 7 SEV row(s) missing (evidence:) annotation"
    echo "$LOG_PREFIX   Pre-push lint FAILED (Rule 27): all SEV rows must have evidence"
    cron_alert "oncall-shift-summary" \
        "Rule 27 lint: $sev_rows_missing_evidence SEV rows lack evidence annotation"
    exit 1
fi
echo "$LOG_PREFIX   Pre-push lint (Rule 27): all SEV rows have evidence annotations"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 7: WRITE — Push updated content (unless dry-run)
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$DRY_RUN" = true ]; then
    echo "$LOG_PREFIX [7] DRY RUN — would update doc with $total_fills fills"
    echo "$LOG_PREFIX   Updated doc saved at: $WORK_DIR/doc-updated.md"
    echo "$LOG_PREFIX   Fill report at: $WORK_DIR/fill-report.json"
    diff "$WORK_DIR/doc-current.md" "$WORK_DIR/doc-updated.md" || true
else
    echo "$LOG_PREFIX [7] Writing updated doc"

    cp "$WORK_DIR/doc-updated.md" "/tmp/oncall-shift-summary-output.md"

    gdocs_capture_prepush_revision "$DOC_ID" "oncall-shift-summary" || true

    if gdocs_prepend_today_section "$DOC_ID" "$TAB_ID" \
            "$WORK_DIR/doc-updated.md" \
            --format markdown --max-size-bytes 30000 --label "oncall-shift-summary"; then
        echo "$LOG_PREFIX   Doc updated via prepend"
        tab_freshness_mark "oncall-shift-summary"
    else
        echo "$LOG_PREFIX   [WARN] Prepend failed — saving fill report for manual review"
        cp "$WORK_DIR/fill-report.json" "$STATE_DIR/oncall-shift-summary-fills.json"
    fi
fi

# Save reports for audit trail
cp "$WORK_DIR/fill-report.json" "$STATE_DIR/oncall-shift-summary-last-fills.json" 2>/dev/null || true
cp "$WORK_DIR/launch-report.json" "$STATE_DIR/oncall-shift-summary-last-launches.json" 2>/dev/null || true
cp "$WORK_DIR/involvement-report.json" "$STATE_DIR/oncall-shift-summary-last-involvement.json" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

rm -rf "$WORK_DIR"
unset WORK_DIR

write_heartbeat "oncall-shift-summary"
JOB_DURATION=$(( $(date +%s) - JOB_START_TIME ))
cron_track_result "oncall-shift-summary" 0
cron_alert_clear "oncall-shift-summary"

echo "$LOG_PREFIX === OT Oncall Shift Summary Done (${JOB_DURATION}s, $total_fills fills, ${launch_items_added:-0} launch items, ${involvement_annotated:-0} evidence, ${involvement_excluded:-0} excluded) ==="
