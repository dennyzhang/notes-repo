#!/usr/bin/env bash
# cron-daily-progress.sh — Accumulate shipped work into weekly PSC draft.
#
# Extracted from cron-nightly-routine-preprocessing.sh Section 4.
# Runs weekdays at 2:25 AM via crontab. On Fridays, also triggers weekly report.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-daily-progress.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"

# Clear Claude Code session markers so nested claude -p works
unset CLAUDECODE 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check: workspace exists
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "daily-progress" "Workspace missing — ~/work/claude/CLAUDE.md missing"
    exit 1
fi

# Prevent overlapping runs
LOCK_MAX_AGE_SECONDS=7200
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$LOG_PREFIX Lock held by pid $pid for ${lock_age}s (>${LOCK_MAX_AGE_SECONDS}s) — killing stale process"
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
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$LOG_PREFIX === Daily Progress Snapshot ==="

DOW=$(date +%u)  # 1=Mon .. 7=Sun
TODAY=$(date +%Y-%m-%d)
WEEK_NUM=$(date +%V)
WEEK_START=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d 2>/dev/null || echo "unknown")
DRAFT_FILE="$REPO_DIR/context/myself/psc/WEEKLY-DRAFT.md"

mkdir -p "$REPO_DIR/context/psc"

progress_exit=0
run_llm "daily-progress" 1200 /dev/stdout "You are running as a cron job to generate Denny Zhang's daily progress snapshot. Today is ${TODAY} (W${WEEK_NUM}, day ${DOW}/5).

Step 1: Read context/IMPACT.md — these are curated impact entries. Use them as primary source.
Step 1b: Read context/cache/DIFF-HEALTH.md — if any authored diffs have issues (CI failing, needs rebase, unaddressed comments), include a 'Diff Health' subsection in today's entry.
Step 2: Collect today's diffs (authored by dennyzhang, created today) via:
  jf graphql --query 'query { phabricator_diff_custom_search_query(args: {query: \"{\\\"key\\\":\\\"AND\\\",\\\"children\\\":[{\\\"key\\\":\\\"EQUALS_ME\\\",\\\"field\\\":\\\"DIFF_AUTHOR_FBID\\\"},{\\\"key\\\":\\\"IS_WITHIN_LAST_1_DAYS\\\",\\\"field\\\":\\\"DIFF_CREATED_TIME\\\"}]}\"}) { phabricator_diffs(first: 50) { edges { node { number diff_title created_time committed_time } } } } }'
Step 3: Read ${DRAFT_FILE} if it exists — append today's entries, don't overwrite previous days.
Step 4: Write the updated draft to ${DRAFT_FILE}.

Format for today's section (append under existing content):

---
## ${TODAY} (Day ${DOW})

### Shipped
[diffs landed today — use IMPACT.md descriptions when available, fall back to diff analysis]

### In Progress
[diffs in review]

### Other
[tasks created/closed, meetings, comms — only if notable]

If it's Friday (day 5), also add a week summary section at the top:

## Week Summary — W${WEEK_NUM} (${WEEK_START} to ${TODAY})
[1-2 sentence PSC-ready impact summary for the whole week]

Keep each day's section under 15 lines. Focus on shipped impact." \
    -- --allowedTools 'Read' 'Write' 'Edit' 'Glob' 'Grep' 'Bash(*)' \
    --model claude-opus-4-6 --effort high \
    --max-turns 50 || progress_exit=$?

if [ $progress_exit -eq 0 ]; then
    if [ -f "$DRAFT_FILE" ]; then
        draft_date=$(date -r "$DRAFT_FILE" +%Y-%m-%d 2>/dev/null || echo "unknown")
        if [ "$draft_date" = "$TODAY" ]; then
            cron_alert_clear "daily-progress"
            echo "$LOG_PREFIX   Progress appended to WEEKLY-DRAFT.md"
        else
            cron_alert "daily-progress" "Exited OK but WEEKLY-DRAFT.md not updated today (last: $draft_date)"
        fi
    else
        cron_alert "daily-progress" "Exited OK but WEEKLY-DRAFT.md missing"
    fi
else
    cron_alert "daily-progress" "Failed (exit $progress_exit) — check /tmp/cron-daily-progress-err.log"
    echo "$LOG_PREFIX   Progress failed (exit $progress_exit)"
fi

# Heartbeat sentinel — only on success
if [ $progress_exit -eq 0 ]; then
    write_heartbeat "daily-progress"
fi

echo "$LOG_PREFIX === Daily Progress Done ==="
