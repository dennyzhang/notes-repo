#!/usr/bin/env bash
# cron-diff-autolearn.sh — Weekly scan of diff reviewer comments → cheatsheet updates.
#
# Autolearn Channel 1: Reads reviewer comments on recent diffs, extracts
# recurring patterns, and appends new rules to diff cheatsheet Common Mistakes.
#
# Schedule: Weekly Monday 6 AM via crontab
# Crontab entry:
#   0 6 * * 1 source ~/work/claude/scripts/cron-alert.sh && cron_run 900 diff-autolearn ~/work/claude/scripts/cron-diff-autolearn.sh >> ~/logs/diff-autolearn.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
LOCK_FILE="/tmp/cron-diff-autolearn.lock"

# Clear Claude Code session markers
unset CLAUDECODE 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "diff-autolearn" "Workspace missing"
    exit 1
fi

# Prevent overlapping runs
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$lock_age" -lt 3600 ]; then
        echo "$LOG_PREFIX Already running (pid $pid), skipping"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE" /tmp/cron-diff-autolearn-diffs.json /tmp/cron-diff-autolearn-comments.md /tmp/cron-diff-autolearn-output.md /tmp/cron-diff-autolearn-existing.md' EXIT

echo "$LOG_PREFIX === Diff Review Autolearn ==="

# Step 1: Find recent diffs authored by Denny (last 7 days)
SEVEN_DAYS_AGO=$(date -d '7 days ago' '+%Y-%m-%dT00:00:00Z' 2>/dev/null || date -v-7d '+%Y-%m-%dT00:00:00Z')
DIFF_LIST="/tmp/cron-diff-autolearn-diffs.json"

meta search.doc search -q " " --doc-type=DIFF --author-is-me \
    --start-creation-time="$SEVEN_DAYS_AGO" --limit=20 -o json 2>/dev/null > "$DIFF_LIST" || echo "[]" > "$DIFF_LIST"

diff_count=$(python3 -c "import json; d=json.load(open('$DIFF_LIST')); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo "0")
echo "$LOG_PREFIX Found $diff_count diffs in last 7 days"

if [ "$diff_count" -eq 0 ]; then
    echo "$LOG_PREFIX No diffs to scan. Exiting."
    write_heartbeat "diff-autolearn"
    exit 0
fi

# Step 2: Extract diff numbers and fetch comments
COMMENTS_FILE="/tmp/cron-diff-autolearn-comments.md"
echo "# Reviewer Comments on Recent Diffs ($TODAY)" > "$COMMENTS_FILE"

python3 -c "
import json, subprocess, sys

with open('$DIFF_LIST') as f:
    diffs = json.load(f)

if not isinstance(diffs, list):
    diffs = []

for diff in diffs[:15]:  # Cap at 15
    title = diff.get('title', 'Unknown')
    url = diff.get('url', '')
    # Extract diff number from URL
    diff_num = ''
    if '/D' in url:
        diff_num = 'D' + url.split('/D')[-1].split('/')[0].split('?')[0]
    elif 'diff_id' in diff:
        diff_num = 'D' + str(diff['diff_id'])

    if not diff_num:
        continue

    # Fetch comments
    try:
        result = subprocess.run(
            ['meta', 'phabricator.diff', 'comments', '-n', diff_num, '-o', 'json'],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0:
            comments = json.loads(result.stdout)
            # Filter for actionable review comments (not from dennyzhang, not inline-only)
            review_comments = []
            if isinstance(comments, list):
                for c in comments:
                    author = c.get('author', {}).get('username', '') if isinstance(c.get('author'), dict) else str(c.get('author', ''))
                    if 'dennyzhang' not in author.lower():
                        content = c.get('content', '') or c.get('message', '') or ''
                        if len(content) > 20:  # Skip short comments (LGTM, etc)
                            review_comments.append({
                                'author': author,
                                'content': content[:500]  # Truncate long comments
                            })

            if review_comments:
                with open('$COMMENTS_FILE', 'a') as f:
                    f.write(f'\n## {diff_num}: {title}\n')
                    for rc in review_comments:
                        f.write(f'- **{rc[\"author\"]}**: {rc[\"content\"]}\n')
    except Exception as e:
        print(f'Error fetching comments for {diff_num}: {e}', file=sys.stderr)
" 2>/dev/null

comment_lines=$(wc -l < "$COMMENTS_FILE")
echo "$LOG_PREFIX Collected $comment_lines lines of reviewer comments"

if [ "$comment_lines" -lt 5 ]; then
    echo "$LOG_PREFIX Not enough reviewer comments to analyze. Exiting."
    write_heartbeat "diff-autolearn"
    rm -f "$COMMENTS_FILE" "$DIFF_LIST"
    exit 0
fi

# Step 3: Claude extracts patterns
AUTOLEARN_OUTPUT="/tmp/cron-diff-autolearn-output.md"
EXISTING_RULES="/tmp/cron-diff-autolearn-existing.md"

{
    echo "# Existing Common Mistakes (for dedup)"
    { grep "^|" "$REPO_DIR/cheatsheets/diff/common.md" 2>/dev/null || true; } | head -20
    echo ""
    { grep "^|" "$REPO_DIR/cheatsheets/diff/fbcode.md" 2>/dev/null || true; } | head -20
    echo ""
    { grep "^|" "$REPO_DIR/cheatsheets/diff/review.md" 2>/dev/null || true; } | head -20
} > "$EXISTING_RULES"

autolearn_exit=0
run_llm "diff-autolearn" 180 "$AUTOLEARN_OUTPUT" "You are the diff review autolearn engine.

## INPUTS
1. Reviewer comments: $COMMENTS_FILE
2. Existing cheatsheet rules: $EXISTING_RULES

## TASK
1. Read both files.
2. Identify ACTIONABLE patterns in reviewer comments — things that indicate a recurring mistake or a convention Claude should learn. Skip: 'LGTM', questions, one-off domain-specific comments.
3. For each pattern, check if it ALREADY exists in the existing rules (dedup by meaning, not exact text).
4. For NEW patterns only, write them to $AUTOLEARN_OUTPUT in this format:

FILE: cheatsheets/diff/common.md
| What happened | Correct approach |
|---|---|
| Description of the mistake | The fix (Learned $TODAY: DXXXXXX autolearn) |

If no new patterns found, write 'NO_NEW_PATTERNS'.

## RULES
- Only Read and Write tools. No bash, no external commands.
- Maximum 5 new patterns per run (quality over quantity).
- Each pattern must reference the specific diff number it came from.
- Do NOT include patterns that are already in the existing rules." \
    -- --allowedTools Read,Write \
    --model claude-haiku-4-5-20251001 \
    --max-turns 8 \
    || autolearn_exit=$?

patterns_added=0
if [ "$autolearn_exit" -eq 0 ] && [ -f "$AUTOLEARN_OUTPUT" ] && [ -s "$AUTOLEARN_OUTPUT" ]; then
    if grep -q "NO_NEW_PATTERNS" "$AUTOLEARN_OUTPUT"; then
        echo "$LOG_PREFIX No new patterns found"
    else
        # Parse and append patterns
        current_file=""
        while IFS= read -r line; do
            if [[ "$line" == "FILE: "* ]]; then
                current_file="$REPO_DIR/${line#FILE: }"
            elif [[ "$line" == "|"* && -n "$current_file" && "$line" != *"What happened"* && "$line" != *"---"* ]]; then
                if [ -f "$current_file" ] && grep -q "Common Mistakes" "$current_file"; then
                    mistake_key=$(echo "$line" | cut -d'|' -f2 | cut -c1-40 | xargs)
                    if ! grep -qF "$mistake_key" "$current_file" 2>/dev/null; then
                        # Append after the placeholder row or last table row
                        sed -i "/Auto-populated by diff review autolearn/d" "$current_file" 2>/dev/null || true
                        # Insert ONCE at the last row of the Common Mistakes table.
                        # Previously used `sed /^## Common Mistakes/,/^## /{/^|.*|.*|$/a\\` which
                        # appends after EVERY matching row — N existing rows → N copies inserted.
                        # See feedback_no_permission_for_infra_fix.md / contamination of common.md
                        # (rows duplicated 11→22→44→88→176 across 5 cron runs).
                        python3 - "$current_file" "$line" <<'PY'
import sys
path, new_row = sys.argv[1], sys.argv[2]
lines = open(path).readlines()
insert_idx = -1
in_table = False
for i, line in enumerate(lines):
    if '## Common Mistakes' in line:
        in_table = True
        continue
    if in_table and line.startswith('|') and '---' not in line and 'What happened' not in line:
        insert_idx = i + 1
    elif in_table and line.startswith('## '):
        break
if insert_idx > 0:
    lines.insert(insert_idx, new_row.rstrip('\n') + '\n')
    open(path, 'w').writelines(lines)
PY
                        patterns_added=$((patterns_added + 1))
                        echo "$LOG_PREFIX Added: ${mistake_key}"
                        echo "$(date '+%Y-%m-%d %H:%M'),diff-review,added,$(basename $current_file),${mistake_key}" >> ~/work/claude/state/autolearn-metrics.csv
                    fi
                fi
            fi
        done < "$AUTOLEARN_OUTPUT"
    fi
else
    echo "$LOG_PREFIX Pattern extraction failed (exit=$autolearn_exit)"
fi

# Cleanup
rm -f "$COMMENTS_FILE" "$DIFF_LIST" "$EXISTING_RULES" "$AUTOLEARN_OUTPUT"

# ─── Channel 2: Diff Flywheel — Stage 2 distillation ─────────────────────
# Reads ~/logs/diff-signal-monitor.log audit lines, computes per-signal
# stats, writes promotions to candidates.json (and live.json if
# FLYWHEEL_PROMOTE_TO_LIVE=1). Cutover gate: shadow_only=1 by default.
# Cutover 2026-04-23: FLYWHEEL_ENABLED default ON; FLYWHEEL_PROMOTE_TO_LIVE
# stays OFF for the 1-week shadow gate. Denny flips PROMOTE_TO_LIVE=1 after
# 1 week of clean shadow runs (per design doc Step 8).
FLYWHEEL_ENABLED="${FLYWHEEL_ENABLED:-1}"
FLYWHEEL_PROMOTE_TO_LIVE="${FLYWHEEL_PROMOTE_TO_LIVE:-0}"
FLYWHEEL_DIR="$REPO_DIR/state/diff-flywheel"
FLYWHEEL_DISTILL_PY="$HOME/work/claude/private_scripts/lib/diff-flywheel-distill.py"
FLYWHEEL_CHANNEL3_PY="$HOME/work/claude/private_scripts/lib/diff-flywheel-channel3.py"

if [ "$FLYWHEEL_ENABLED" = "1" ] && [ -f "$FLYWHEEL_DISTILL_PY" ]; then
    echo "$LOG_PREFIX === Channel 2: Diff Flywheel distillation ==="
    shadow_arg=1
    [ "$FLYWHEEL_PROMOTE_TO_LIVE" = "1" ] && shadow_arg=0
    if distill_out=$(timeout 60 python3 "$FLYWHEEL_DISTILL_PY" \
            --audit-log "$HOME/logs/diff-signal-monitor.log" \
            --live "$FLYWHEEL_DIR/live.json" \
            --candidates "$FLYWHEEL_DIR/candidates.json" \
            --human-layer "$REPO_DIR/cheatsheets/diff/learned-classifier.md" \
            --window-days 30 \
            --shadow-only "$shadow_arg" 2>&1); then
        echo "$LOG_PREFIX Channel 2: $distill_out"
    else
        echo "$LOG_PREFIX Channel 2 FAILED: $distill_out"
        cron_alert "diff-autolearn" "Channel 2 distill failed"
    fi
fi

# ─── Channel 3: Diff Flywheel — close-loop attribution → candidates ──────
# Reads learning-events.jsonl (written by signal-monitor when Denny
# resolves an escalated diff), captures each as a candidate pattern with
# tier=human_attribution. v1: literal signal_regex; v2 will add LLM-driven
# generalized pattern extraction from `sl diff` between before/after.
if [ "$FLYWHEEL_ENABLED" = "1" ] && [ -f "$FLYWHEEL_CHANNEL3_PY" ]; then
    echo "$LOG_PREFIX === Channel 3: Diff Flywheel close-loop attribution ==="
    if ch3_out=$(timeout 60 python3 "$FLYWHEEL_CHANNEL3_PY" \
            --events "$FLYWHEEL_DIR/learning-events.jsonl" \
            --processed "$FLYWHEEL_DIR/learning-events-processed.txt" \
            --candidates "$FLYWHEEL_DIR/candidates.json" 2>&1); then
        echo "$LOG_PREFIX Channel 3: $ch3_out"
    else
        echo "$LOG_PREFIX Channel 3 FAILED: $ch3_out"
        cron_alert "diff-autolearn" "Channel 3 attribution failed"
    fi
fi

# ─── Channel 4: Auto-Review-Bot graduation check ─────────────────────────
# Reads ~/work/claude/diff-comment-learnings.md ledger (written by
# cron-diff-reviewer-comment.sh + interactive Pylon's verdict-recording),
# computes per-category stats, promotes eligible categories to
# state/diff-reviewer-graduated.json, demotes any category with a harm
# verdict, and writes state/diff-reviewer-stats-block.md for AI Health
# to include in its weekly digest.
#
# Spec: cheatsheets/diff/reviewer-comment-automation.md § Phase 2
GRADUATION_PY="$HOME/work/claude/private_scripts/lib/diff_reviewer_graduation.py"
if [ -f "$GRADUATION_PY" ]; then
    echo "$LOG_PREFIX === Channel 4: Auto-Review-Bot graduation check ==="
    if grad_out=$(timeout 30 python3 "$GRADUATION_PY" 2>&1); then
        echo "$LOG_PREFIX Channel 4: $grad_out"
    else
        echo "$LOG_PREFIX Channel 4 FAILED: $grad_out"
        cron_alert "diff-autolearn" "Channel 4 graduation check failed"
    fi
fi

# Heartbeat
write_heartbeat "diff-autolearn"
if [ "$patterns_added" -gt 0 ]; then
    cron_alert_clear "diff-autolearn"
    echo "$LOG_PREFIX === Diff Autolearn Done: $patterns_added patterns added ==="
else
    cron_alert_clear "diff-autolearn"
    echo "$LOG_PREFIX === Diff Autolearn Done: no new patterns ==="
fi
