#!/usr/bin/env bash
# cron-gchat-observer.sh — multi-space GChat history observer.
#
# THE OBSERVER (per cheatsheets/agents/workflow-design.md § Observer/Consumer).
# Pulls last N days of messages from every space in config/GCHAT-SPACES.yaml
# (plus the OT bot space) and writes per-day markdown caches to:
#   state/gchat-cache/<space-id>/messages-YYYY-MM-DD.md
#   state/gchat-cache/<space-id>/MANIFEST.json
#   state/gchat-cache/INDEX.json  (one-stop manifest of all cached spaces)
#
# Downstream consumers (cron-gchat-consumer-*.sh) read from this cache instead
# of re-fetching from GChat — single fetch amortizes ACROSS consumers.
#
# Schedule: hourly (every consumer running at any cadence sees fresh-ish data).
# Crontab: 0 * * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 900
#          gchat-observer ~/work/claude/scripts/cron-gchat-observer.sh
#          >> ~/logs/gchat-observer.log 2>&1
#
# Env:
#   GCHAT_OBSERVER_DAYS=N       (default 7)
#   GCHAT_OBSERVER_MSG_LIMIT=N  (default 300)
#   GCHAT_OBSERVER_SPACES=...   override config (comma-sep space IDs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/cron-alert.sh"

DAYS_BACK="${GCHAT_OBSERVER_DAYS:-7}"
MSG_LIMIT="${GCHAT_OBSERVER_MSG_LIMIT:-300}"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
SPACES_YAML="$HOME/work/claude/config/GCHAT-SPACES.yaml"
CACHE_ROOT="$HOME/work/claude/state/gchat-cache"
INDEX_FILE="$CACHE_ROOT/INDEX.json"
mkdir -p "$CACHE_ROOT"

# Resolve space list: explicit override OR parse YAML.
if [ -n "${GCHAT_OBSERVER_SPACES:-}" ]; then
    SPACES_CSV="$GCHAT_OBSERVER_SPACES"
else
    if [ ! -f "$SPACES_YAML" ]; then
        cron_alert "gchat-observer" "Config missing: $SPACES_YAML"
        exit 1
    fi
    SPACES_CSV=$(python3 -c "
import re
text = open('$SPACES_YAML').read()
# Extract every 'id: \"...\"' value (works for the lightly-structured YAML format
# in this repo without requiring PyYAML).
ids = re.findall(r'id:\s*\"([^\"]+)\"', text)
# Always include the OT bot space — historically cached separately by
# cron-ot-myclaw-chat-cache.sh; folding in here so we have one source.
if 'AAQAVOjYc80' not in ids:
    ids.append('AAQAVOjYc80')
print(','.join(ids))
")
fi

if [ -z "$SPACES_CSV" ]; then
    cron_alert "gchat-observer" "No spaces resolved from $SPACES_YAML"
    exit 1
fi

cron_log "starting (days=$DAYS_BACK, limit=$MSG_LIMIT, spaces=$(echo "$SPACES_CSV" | tr ',' '\n' | wc -l))"

# Per-space fetch + cache. Sequential to keep gchat-API load predictable;
# per-space wall time is small (~1-2s each).
TOTAL_SPACES=0
OK_SPACES=0
FAIL_SPACES=0
TOTAL_MSGS=0
PER_SPACE_SUMMARY=""

IFS=',' read -ra SPACE_IDS <<< "$SPACES_CSV"
for space_id in "${SPACE_IDS[@]}"; do
    TOTAL_SPACES=$((TOTAL_SPACES + 1))
    SPACE_FULL="spaces/$space_id"
    SPACE_CACHE_DIR="$CACHE_ROOT/$space_id"
    mkdir -p "$SPACE_CACHE_DIR"

    TMPF=$(mktemp /tmp/gchat-observer-${space_id}.XXXXXX.json)
    if ! meta google.chat.message list -s "$SPACE_FULL" --limit="$MSG_LIMIT" -o json > "$TMPF" 2>/dev/null; then
        cron_log "  SKIP $space_id (fetch failed)"
        FAIL_SPACES=$((FAIL_SPACES + 1))
        rm -f "$TMPF"
        continue
    fi

    # Group by date and write per-day files via Python.
    msgs_n=$(SPACE_ID="$space_id" CACHE_DIR="$SPACE_CACHE_DIR" DAYS_BACK="$DAYS_BACK" \
             TMPF="$TMPF" python3 <<'PYEOF'
import json, os, re, sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

space_id = os.environ['SPACE_ID']
cache_dir = os.environ['CACHE_DIR']
days_back = int(os.environ['DAYS_BACK'])
tmpf = os.environ['TMPF']

with open(tmpf) as f:
    resp = json.load(f)
msgs = resp.get('data', []) if isinstance(resp, dict) else resp

pt_offset = timedelta(hours=-7)
cutoff = datetime.now(timezone.utc) - timedelta(days=days_back)

by_date = defaultdict(list)
for m in msgs:
    ts_str = m.get('create_time', '')
    if not ts_str:
        continue
    try:
        ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
    except ValueError:
        continue
    if ts < cutoff:
        continue
    pt = ts + pt_offset
    by_date[pt.strftime('%Y-%m-%d')].append((ts, m))

sev_re = re.compile(r'\bS[0-9]{6,7}\b')
diff_re = re.compile(r'\bD[0-9]{8,10}\b')

written = 0
total = 0
for date_key, day_msgs in sorted(by_date.items()):
    day_msgs.sort(key=lambda x: x[0])
    sev_ids, diff_ids, senders = set(), set(), set()
    body_lines = []
    for ts, m in day_msgs:
        text = m.get('text') or ''
        sender = m.get('sender_name') or str(m.get('sender', ''))[:20]
        sev_ids.update(sev_re.findall(text))
        diff_ids.update(diff_re.findall(text))
        if sender and not sender.isdigit():
            senders.add(sender)
        pt_ts = (ts + pt_offset).strftime('%Y-%m-%d %H:%M:%S PT')
        body_lines.append(f'## {pt_ts} [{sender}]')
        body_lines.append('')
        body_lines.append(text.strip())
        body_lines.append('')
    frontmatter = [
        '---',
        f'date: {date_key}',
        f'space_id: {space_id}',
        f'generated_at: {datetime.now(timezone.utc).isoformat()}',
        f'message_count: {len(day_msgs)}',
        f"sev_ids_mentioned: [{', '.join(sorted(sev_ids))}]",
        f"diff_ids_mentioned: [{', '.join(sorted(diff_ids))}]",
        f'unique_senders: {len(senders)}',
        '---',
        '',
    ]
    fname = os.path.join(cache_dir, f'messages-{date_key}.md')
    with open(fname, 'w') as f:
        f.write('\n'.join(frontmatter + body_lines))
    written += 1
    total += len(day_msgs)

manifest = {
    'space_id': space_id,
    'generated_at': datetime.now(timezone.utc).isoformat(),
    'days_covered': sorted(by_date.keys()),
    'total_messages': total,
}
with open(os.path.join(cache_dir, 'MANIFEST.json'), 'w') as f:
    json.dump(manifest, f, indent=2)

print(total)
PYEOF
)
    rm -f "$TMPF"
    OK_SPACES=$((OK_SPACES + 1))
    TOTAL_MSGS=$((TOTAL_MSGS + msgs_n))
    PER_SPACE_SUMMARY+="  $space_id: $msgs_n msgs\n"
done

# Write the cross-space INDEX (one-stop manifest for consumers).
python3 <<PYEOF
import json, os
from datetime import datetime, timezone
root = '$CACHE_ROOT'
spaces = []
for d in sorted(os.listdir(root)):
    p = os.path.join(root, d)
    if not os.path.isdir(p):
        continue
    mf = os.path.join(p, 'MANIFEST.json')
    if not os.path.isfile(mf):
        continue
    try:
        spaces.append(json.load(open(mf)))
    except Exception:
        pass
with open('$INDEX_FILE', 'w') as f:
    json.dump({
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'space_count': len(spaces),
        'total_messages': sum(s.get('total_messages', 0) for s in spaces),
        'spaces': spaces,
    }, f, indent=2)
PYEOF

cron_log "done: $OK_SPACES/$TOTAL_SPACES spaces cached, $FAIL_SPACES failed, $TOTAL_MSGS msgs total"
[ "$FAIL_SPACES" -gt 0 ] && cron_log "WARN: $FAIL_SPACES space(s) failed to fetch — see log"

# Success heartbeat ONLY if every space succeeded (workflow-design.md rule 2).
if [ "$FAIL_SPACES" -eq 0 ]; then
    write_heartbeat "gchat-observer"
else
    cron_alert "gchat-observer" "$FAIL_SPACES/$TOTAL_SPACES space(s) failed to fetch"
fi
