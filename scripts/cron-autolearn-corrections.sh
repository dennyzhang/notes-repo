#!/usr/bin/env bash
# cron-autolearn-corrections.sh — Auto-improve cheatsheets from execution feedback.
#
# Three learning channels:
#   1. AUDIT FAILS → extract "Before/After" corrections into relevant cheatsheets
#   2. ERROR PATTERNS → surface recurring unfixed cron failures as new diagnose patterns
#   3. CRON EXPERIMENTS → auto-apply SAFE experiments that have been ACTIVE >3 days
#
# This closes the feedback loop that was previously manual:
#   Observe (audit/errors) → Learn (cheatsheet rules) → Apply (safe experiments)
#
# Schedule: Daily 7 AM, after ai-audit and before ai-health
# Crontab:
#   15 7 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 600 autolearn-corrections ~/work/claude/scripts/cron-autolearn-corrections.sh >> ~/logs/autolearn-corrections.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')

source "$SCRIPT_DIR/cron-alert.sh"

RUNTIME_CSV="$HOME/logs/cron-runtime.csv"
AUDIT_RESULTS="$REPO_DIR/context/cache/AUDIT-RESULTS.md"
ERROR_DB="$REPO_DIR/context/cache/ERROR-PATTERNS.json"
EXPERIMENTS="$REPO_DIR/context/cache/CRON-EXPERIMENTS.md"
AUTOLEARN_LOG="$REPO_DIR/state/autolearn-metrics.csv"
CHEATSHEET_DIR="$REPO_DIR/cheatsheets"

echo "$LOG_PREFIX === Autolearn Corrections ==="

corrections_added=0
experiments_applied=0
patterns_surfaced=0

# ─── Channel 1: Audit FAIL → Cheatsheet Rules ───────────────────────────────
# Parse AUDIT-RESULTS.md for FAIL entries with Before/After suggestions.
# Extract the "After" fix as a new cheatsheet rule.

echo "$LOG_PREFIX [1/3] Learning from audit failures..."

if [ -f "$AUDIT_RESULTS" ]; then
    # Date guard — only learn from today's audit results (avoid re-learning stale FAILs)
    audit_date=$(head -5 "$AUDIT_RESULTS" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
    if [ "$audit_date" != "$TODAY" ]; then
        echo "$LOG_PREFIX   Skipping audit channel — results are from $audit_date, not today"
    else
    # Extract FAIL entries with corrections
    AUDIT_LEARNINGS="/tmp/autolearn-audit.md"

    python3 -c "
import re, sys

with open('$AUDIT_RESULTS') as f:
    content = f.read()

# Find current section (Routine Doc, OT Triage Doc, AI Feedback Log)
sections = re.split(r'^---$', content, flags=re.MULTILINE)

learnings = []
for section in sections:
    # Find section name
    section_match = re.search(r'^## (.+)', section, re.MULTILINE)
    if not section_match:
        continue
    section_name = section_match.group(1).strip()

    # Map section to cheatsheet category
    cheatsheet_map = {
        'Routine Doc': 'system/workflow-design.md',
        'OT Triage Doc': 'oncall/sev.md',
        'AI Feedback Log': 'system/task-execution.md',
    }
    target = cheatsheet_map.get(section_name, '')
    if not target:
        continue

    # Find FAIL rows with Before/After
    fails = re.findall(
        r'\| (\w+) \| .+? \| FAIL \| (.+?) \|',
        section
    )
    for criterion_id, notes in fails:
        # Extract After suggestion
        after_match = re.search(r'\*\*After[^:]*:\*\*\s*(.+?)(?:\s*\||\s*$)', notes)
        before_match = re.search(r'\*\*Before[^:]*:\*\*\s*\x60(.+?)\x60', notes)

        if after_match:
            after_text = after_match.group(1).strip().strip('\x60').strip()
            before_text = before_match.group(1).strip() if before_match else 'N/A'
            # Truncate for cheatsheet table
            if len(before_text) > 80:
                before_text = before_text[:77] + '...'
            if len(after_text) > 80:
                after_text = after_text[:77] + '...'
            learnings.append({
                'section': section_name,
                'criterion': criterion_id,
                'target': target,
                'what_happened': before_text,
                'correct_approach': after_text,
            })

# Output as simple TSV
for l in learnings:
    print(f\"{l['target']}\t{l['what_happened']}\t{l['correct_approach']}\")
" > "$AUDIT_LEARNINGS" 2>/dev/null || true

    # Apply learnings to cheatsheets (max 3 per run to avoid churn)
    applied=0
    while IFS=$'\t' read -r target what_happened correct_approach; do
        [ -z "$target" ] && continue
        [ "$applied" -ge 3 ] && break

        target_file="$CHEATSHEET_DIR/$target"
        [ ! -f "$target_file" ] && continue

        # Check for duplicate (fuzzy — first 40 chars of correct_approach)
        check_str=$(echo "$correct_approach" | cut -c1-40)
        if grep -qF "$check_str" "$target_file" 2>/dev/null; then
            echo "$LOG_PREFIX   Skip duplicate: $check_str..."
            continue
        fi

        # Find or create Common Mistakes table
        if grep -q "## Common Mistakes" "$target_file"; then
            # Append before the last line of the table section
            # Find the line after the table header row
            python3 -c "
import sys
lines = open('$target_file').readlines()
insert_idx = -1
in_table = False
for i, line in enumerate(lines):
    if '## Common Mistakes' in line:
        in_table = True
    elif in_table and line.startswith('|') and '---' not in line and 'What happened' not in line:
        insert_idx = i + 1  # Insert after last table row
    elif in_table and not line.startswith('|') and line.strip() and not line.startswith('#'):
        if insert_idx == -1:
            insert_idx = i
        break

if insert_idx == -1:
    # Table header exists but no rows — insert after header separator
    for i, line in enumerate(lines):
        if '## Common Mistakes' in line:
            for j in range(i+1, min(i+5, len(lines))):
                if '---' in lines[j]:
                    insert_idx = j + 1
                    break
            break

if insert_idx >= 0:
    new_row = '| ' + sys.argv[1] + ' | ' + sys.argv[2] + ' |\n'
    lines.insert(insert_idx, new_row)
    with open('$target_file', 'w') as f:
        f.writelines(lines)
    print('OK')
else:
    print('SKIP')
" "$what_happened" "$correct_approach" 2>/dev/null
            result=$?
        else
            # No Common Mistakes section — append one
            {
                echo ""
                echo "## Common Mistakes"
                echo ""
                echo "| What happened | Correct approach |"
                echo "|---|---|"
                echo "| $what_happened | $correct_approach |"
            } >> "$target_file"
        fi

        echo "$LOG_PREFIX   Added audit learning to $target: ${correct_approach:0:60}..."
        echo "$(date '+%Y-%m-%d %H:%M'),audit-fail,added,$target,${correct_approach:0:60}" >> "$AUTOLEARN_LOG"
        applied=$((applied + 1))
        corrections_added=$((corrections_added + 1))
    done < "$AUDIT_LEARNINGS"

    rm -f "$AUDIT_LEARNINGS"
    echo "$LOG_PREFIX   Audit channel: $corrections_added corrections applied"

    # Prune cheatsheet tables that exceed 20 rows (keep newest, remove oldest)
    for cs_file in "$CHEATSHEET_DIR"/*/; do
        find "$cs_file" -name "*.md" -exec python3 -c "
import sys
lines = open(sys.argv[1]).readlines()
in_mistakes = False
table_start = -1
table_rows = []
for i, line in enumerate(lines):
    if '## Common Mistakes' in line:
        in_mistakes = True
        continue
    if in_mistakes and line.startswith('|') and '---' in line:
        table_start = i
        continue
    if in_mistakes and table_start >= 0 and line.startswith('|'):
        table_rows.append((i, line))
    elif in_mistakes and not line.startswith('|') and line.strip():
        break
if len(table_rows) > 20:
    # Remove oldest rows (keep last 20)
    to_remove = set(idx for idx, _ in table_rows[:-20])
    new_lines = [l for i, l in enumerate(lines) if i not in to_remove]
    with open(sys.argv[1], 'w') as f:
        f.writelines(new_lines)
    print(f'Pruned {len(to_remove)} old rows from {sys.argv[1]}')
" {} \; 2>/dev/null || true
    done

    fi  # end date guard
else
    echo "$LOG_PREFIX   No audit results found"
fi

# ─── Channel 2: Error Patterns → Surface Recurring Unfixed Failures ──────────
# Analyze ERROR-PATTERNS.json for patterns that:
#   - Recur 3+ times in 7 days
#   - Have fix_applied but retry still fails (fix doesn't work)
#   - Are in "unknown" category (no diagnosis exists)
# Surface these as follow-up items in ALERTS.md

echo "$LOG_PREFIX [2/3] Analyzing error patterns for recurring issues..."

if [ -f "$ERROR_DB" ]; then
    PATTERN_REPORT="/tmp/autolearn-patterns.txt"

    python3 -c "
import json
from datetime import datetime, timedelta
from collections import Counter

with open('$ERROR_DB') as f:
    db = json.load(f)

cutoff = (datetime.utcnow() - timedelta(days=7)).isoformat() + 'Z'
recent = [p for p in db.get('patterns', []) if p.get('timestamp', '') >= cutoff]

if not recent:
    print('NO_PATTERNS')
    exit(0)

# Find recurring patterns (same job + category, 3+ times)
pattern_key = lambda p: (p['job'], p['category'])
counts = Counter(pattern_key(p) for p in recent)
recurring = {k: v for k, v in counts.items() if v >= 3}

# Find ineffective fixes (fix applied but retry still fails)
ineffective = {}
for p in recent:
    k = pattern_key(p)
    if p.get('fix_applied') == 'applied' and not p.get('retry_succeeded', True):
        if k not in ineffective:
            ineffective[k] = {'count': 0, 'signatures': set()}
        ineffective[k]['count'] += 1
        if p.get('signature'):
            ineffective[k]['signatures'].add(p['signature'][:80])

# Find unknown errors (no diagnosis)
unknowns = [p for p in recent if p['category'] == 'unknown']

# Report
results = []
for (job, cat), count in sorted(recurring.items(), key=lambda x: -x[1]):
    fix_info = ineffective.get((job, cat), {})
    fix_fail_count = fix_info.get('count', 0)
    sigs = list(fix_info.get('signatures', set()))[:2]
    results.append(f'RECURRING|{job}|{cat}|{count}|fix_fails={fix_fail_count}|{\";\".join(sigs)}')

for p in unknowns[:5]:
    results.append(f'UNKNOWN|{p[\"job\"]}|exit={p[\"exit_code\"]}|{p.get(\"signature\", \"no signature\")}')

# Fix effectiveness summary
stats = db.get('fix_stats', {})
for cat, s in stats.items():
    rate = (s['successes'] / s['attempts'] * 100) if s['attempts'] > 0 else 0
    results.append(f'FIX_RATE|{cat}|{s[\"attempts\"]} attempts|{s[\"successes\"]} successes|{rate:.0f}%')

for r in results:
    print(r)
" > "$PATTERN_REPORT" 2>/dev/null || true

    if [ -f "$PATTERN_REPORT" ] && [ -s "$PATTERN_REPORT" ] && ! grep -q "NO_PATTERNS" "$PATTERN_REPORT"; then
        # Count recurring patterns for logging
        recurring_count=$(grep -c "^RECURRING" "$PATTERN_REPORT" 2>/dev/null || echo 0)
        unknown_count=$(grep -c "^UNKNOWN" "$PATTERN_REPORT" 2>/dev/null || echo 0)

        # If there are recurring patterns with failed fixes, surface to ALERTS
        failed_fix_patterns=$(grep "^RECURRING" "$PATTERN_REPORT" | grep -v "fix_fails=0" | head -3 || true)
        if [ -n "$failed_fix_patterns" ]; then
            while IFS='|' read -r _ job cat count fix_info sig; do
                echo "$LOG_PREFIX   Recurring failure: $job ($cat) - $count occurrences, $fix_info"
                # Write to ALERTS.md so it gets human attention
                cron_alert "autofix-${job}" "Recurring $cat failure ($count times in 7d, fix ineffective): $sig"
                patterns_surfaced=$((patterns_surfaced + 1))
            done <<< "$failed_fix_patterns"
        fi

        # Log fix effectiveness rates
        { grep "^FIX_RATE" "$PATTERN_REPORT" || true; } | while IFS='|' read -r _ cat attempts successes rate; do
            echo "$LOG_PREFIX   Fix rate for $cat: $rate ($attempts, $successes)"
        done

        echo "$LOG_PREFIX   Pattern analysis: $recurring_count recurring, $unknown_count unknown"
    else
        echo "$LOG_PREFIX   No error patterns to analyze (clean fleet)"
    fi

    rm -f "$PATTERN_REPORT"
else
    echo "$LOG_PREFIX   No error pattern DB found"
fi

# ─── Auto-resolve stale autofix alerts ────────────────────────────────────────
# If an autofix-* alert exists but the job has 3+ consecutive passes since
# the alert was written, auto-clear it. Prevents stale alerts from masking
# real problems.
if [ -f "$ALERTS_FILE" ] && [ -f "$RUNTIME_CSV" ] && grep -q "\[cron:autofix-" "$ALERTS_FILE" 2>/dev/null; then
    echo "$LOG_PREFIX   Checking for auto-resolvable alerts..."
    auto_resolved=0
    while IFS= read -r alert_line; do
        job_name=$(echo "$alert_line" | grep -oP '\[cron:autofix-\K[^\]]+')
        [ -z "$job_name" ] && continue
        alert_date=$(echo "$alert_line" | grep -oP '^\- \*\*\K[0-9-]+')
        [ -z "$alert_date" ] && continue
        consecutive_passes=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v job="$job_name" -v since="$alert_date" \
            '$1 >= since && $2 == job {if ($3 == 0) streak++; else streak=0} END {print streak+0}')
        if [ "$consecutive_passes" -ge 3 ]; then
            cron_alert_clear "autofix-${job_name}"
            echo "$LOG_PREFIX   Auto-resolved: autofix-${job_name} ($consecutive_passes consecutive passes since $alert_date)"
            auto_resolved=$((auto_resolved + 1))
        fi
    done < <(grep "\[cron:autofix-" "$ALERTS_FILE")
    echo "$LOG_PREFIX   Auto-resolved $auto_resolved stale alert(s)"
fi

# ─── Channel 3: Auto-Apply SAFE Experiments ──────────────────────────────────
# Find SAFE experiments that have been ACTIVE >3 days.
# For timeout/schedule changes, apply them directly to the crontab.

echo "$LOG_PREFIX [3/3] Checking for SAFE experiments to auto-apply..."

APPLIED_COUNT_FILE="/tmp/autolearn-applied-count"
echo 0 > "$APPLIED_COUNT_FILE"

if [ -f "$EXPERIMENTS" ] && grep -q "Status.*: ACTIVE" "$EXPERIMENTS"; then
    three_days_ago=$(date -d '3 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-3d '+%Y-%m-%d')

    # Parse active SAFE experiments older than 3 days
    python3 -c "
import re, sys
from datetime import datetime

with open('$EXPERIMENTS') as f:
    content = f.read()

cutoff = '$three_days_ago'
# Find experiment blocks
blocks = re.split(r'(?=^### EXP-)', content, flags=re.MULTILINE)

for block in blocks:
    if not block.startswith('### EXP-'):
        continue
    if 'ACTIVE' not in block or 'Status' not in block:
        continue
    if 'SAFE' not in block or 'Type' not in block:
        continue

    # Check start date
    start_match = re.search(r'Started\*{0,2}[:\s]+(\d{4}-\d{2}-\d{2})', block)
    if not start_match or start_match.group(1) > cutoff:
        continue

    # Extract experiment details
    exp_id = re.search(r'### (EXP-\S+)', block).group(1)
    change = re.search(r'\*\*Change\*\*[:\s]+(.+)', block)
    change_text = change.group(1).strip() if change else 'unknown'

    # Only auto-apply timeout changes (safest)
    if 'timeout' in change_text.lower():
        # Extract job name and old/new timeout values
        timeout_match = re.search(r'(\d+)s?\s*to\s*(\d+)', change_text)
        job_match = re.search(r'for\s+(\S+)', change_text)
        if timeout_match:
            job_name = job_match.group(1) if job_match else 'UNKNOWN'
            print(f'TIMEOUT|{exp_id}|{timeout_match.group(1)}|{timeout_match.group(2)}|{job_name}|{change_text}')
    elif 'schedule' in change_text.lower() or 'cron' in change_text.lower():
        print(f'SCHEDULE|{exp_id}|{change_text}')
" 2>/dev/null | while IFS='|' read -r change_type exp_id old_val new_val job_name desc; do
        case "$change_type" in
            TIMEOUT)
                echo "$LOG_PREFIX   Auto-applying $exp_id: timeout $old_val → $new_val for $job_name"
                # Find and update in crontab — scope sed to the specific job name
                current_crontab=$(crontab -l 2>/dev/null)
                if [ "$job_name" = "UNKNOWN" ]; then
                    echo "$LOG_PREFIX   Skipping — could not identify target job"
                    continue
                fi
                if echo "$current_crontab" | grep "$job_name" | grep -q "cron_run $old_val"; then
                    # Apply the change — only on the line containing the job name
                    echo "$current_crontab" | sed "/$job_name/s/cron_run $old_val/cron_run $new_val/" | crontab -
                    echo "$LOG_PREFIX   Applied timeout change in crontab"

                    # Mark experiment as APPLIED in experiments file
                    sed -i "s/$exp_id/&\n- **Applied**: $TODAY (auto-applied by autolearn)/" "$EXPERIMENTS" 2>/dev/null || true
                    sed -i "/$exp_id/,/Status/{s/ACTIVE/APPLIED/}" "$EXPERIMENTS" 2>/dev/null || true

                    experiments_applied=$(( $(cat "$APPLIED_COUNT_FILE") + 1 ))
                    echo "$experiments_applied" > "$APPLIED_COUNT_FILE"
                    echo "$(date '+%Y-%m-%d %H:%M'),experiment,applied,$exp_id,$desc" >> "$AUTOLEARN_LOG"
                else
                    echo "$LOG_PREFIX   Could not find timeout $old_val for $job_name in crontab — skipping"
                fi
                ;;
            SCHEDULE)
                echo "$LOG_PREFIX   SCHEDULE change needs review: $exp_id — $desc"
                ;;
        esac
    done

    echo "$LOG_PREFIX   Experiments: $experiments_applied auto-applied"
else
    echo "$LOG_PREFIX   No active experiments to process"
fi

# ─── Channel 4: GChat Coaching → Autolearn Metrics ──────────────────────────
# Scan Denny's GChat messages for AI/Claude workflow coaching signals.
# Extracts correction patterns and writes to autolearn-metrics.csv as source='gchat'.
# Only processes messages from the past 7 days not already recorded today.

echo "$LOG_PREFIX [4/4] Learning from GChat coaching signals..."

gchat_learnings_added=0
GCHAT_CACHE="$REPO_DIR/context/cache/gchat"

if [ -d "$GCHAT_CACHE" ]; then
    gchat_learnings_added=$(python3 - <<PYEOF 2>/dev/null || echo 0
import json, os, re
from pathlib import Path
from datetime import datetime, timezone, timedelta

cache_dir = Path("$GCHAT_CACHE")
autolearn_log = Path("$AUTOLEARN_LOG")
today = datetime.now().strftime("%Y-%m-%d %H:%M")
seven_days_ago = (datetime.now(timezone.utc) - timedelta(days=7)).timestamp()

# Coaching signal keywords: messages from Denny about AI/Claude workflow corrections
ai_words = re.compile(r'\b(claude|agent|workflow|session|cron|hook|skill|script|cheatsheet|mcp)\b', re.I)
correction_words = re.compile(r'\b(should|shouldn\'t|instead|better|wrong|fix|don\'t|always|never|stop|prefer|rule|avoid|must|issue|problem|mistake|correct)\b', re.I)

# Load already-recorded gchat patterns to avoid duplicates
existing_patterns = set()
if autolearn_log.exists():
    for line in autolearn_log.read_text().splitlines():
        parts = line.split(',', 4)
        if len(parts) >= 5 and parts[1] == 'gchat':
            existing_patterns.add(parts[4][:60].strip())

new_entries = []
for json_file in cache_dir.glob("*.json"):
    try:
        data = json.loads(json_file.read_text())
        messages = data.get("messages", [])
        for msg in messages:
            # Filter: Denny's messages in the last 7 days
            ts = msg.get("creation_timestamp", 0)
            if ts < seven_days_ago:
                continue
            sender = msg.get("sender_name", "")
            if sender.lower() not in ("denny zhang", "dennyzhang"):
                continue
            body = msg.get("message_body", "").strip()
            if not body or len(body) < 20:
                continue
            # Must have both AI context AND correction intent
            if not ai_words.search(body):
                continue
            if not correction_words.search(body):
                continue
            # Extract a concise pattern (first 80 chars, single line)
            pattern = re.sub(r'\s+', ' ', body.split('\n')[0])[:80]
            if pattern in existing_patterns:
                continue
            # Format: YYYY-MM-DD HH:MM, gchat, added, <space_title>, <pattern>
            space = data.get("name", json_file.stem)
            ts_str = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M")
            new_entries.append(f"{ts_str},gchat,added,{space},{pattern}")
            existing_patterns.add(pattern)
    except Exception:
        continue

if new_entries:
    with open(autolearn_log, 'a') as f:
        for entry in new_entries:
            f.write(entry + '\n')

print(len(new_entries))
PYEOF
)
    echo "$LOG_PREFIX   GChat coaching learnings added: $gchat_learnings_added"
else
    echo "$LOG_PREFIX   GChat cache not found at $GCHAT_CACHE — skipping"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

experiments_applied=$(cat "$APPLIED_COUNT_FILE" 2>/dev/null || echo 0)
rm -f "$APPLIED_COUNT_FILE"

echo "$LOG_PREFIX === Autolearn Corrections Done ==="
echo "$LOG_PREFIX   Audit corrections: $corrections_added"
echo "$LOG_PREFIX   Error patterns surfaced: $patterns_surfaced"
echo "$LOG_PREFIX   Experiments auto-applied: $experiments_applied"
echo "$LOG_PREFIX   GChat coaching learnings: $gchat_learnings_added"

# Rebuild the unified changelog
bash "$SCRIPT_DIR/generate-autolearn-changelog.sh" 2>/dev/null || true

write_heartbeat "autolearn-corrections"
