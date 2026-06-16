#!/usr/bin/env bash
# cron-weekly-report.sh — Auto-generate weekly PSC draft every Friday evening.
# Uses weekly-status-report skill + IMPACT.md for curated descriptions.
#
# Crontab entry:
#   0 18 * * 5 $HOME/work/claude/scripts/cron-weekly-report.sh >> ~/logs/weekly-report.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-weekly-report.lock"

# Clear Claude Code session markers so nested claude -p works
unset CLAUDECODE 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check: workspace exists
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "weekly-report" "Workspace missing — ~/work/claude/CLAUDE.md missing"
    exit 1
fi

# Prevent overlapping runs
LOCK_MAX_AGE_SECONDS=7200
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$(date '+%Y-%m-%d %H:%M') Lock held by pid $pid for ${lock_age}s (>${LOCK_MAX_AGE_SECONDS}s) — killing stale process"
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
        else
            echo "$(date '+%Y-%m-%d %H:%M') Already running (pid $pid, age ${lock_age}s), skipping"
            exit 0
        fi
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$(date '+%Y-%m-%d %H:%M') Starting weekly report generation (weekly-status-report + IMPACT.md)"

if ! command -v claude &>/dev/null; then
    cron_alert "weekly-report" "claude CLI not available"
    exit 1
fi

WEEK_NUM=$(date +%V)
WEEK_START=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d 2>/dev/null || echo "unknown")
WEEK_END=$(date +%Y-%m-%d)

cd "$REPO_DIR"
exit_code=0
run_llm "weekly-report" 2400 /dev/stdout "You are running as a cron job to generate the weekly PSC draft for Denny Zhang. Today is $(date +%Y-%m-%d), Friday of W${WEEK_NUM} (${WEEK_START} to ${WEEK_END}).

Step 1: Read context/IMPACT.md for curated impact entries from this week.
Step 2: Read context/myself/psc/MY-PSC.md to check what's already captured for W${WEEK_NUM}.
Step 3: Generate the weekly status report — collect diffs, tasks, Workplace posts, and comms from the past 7 days. Use IMPACT.md entries as primary source for diff descriptions.
Step 4: Write the draft to context/myself/psc/WEEKLY-DRAFT.md (overwrite previous).

Format:

# Weekly Draft — W${WEEK_NUM} (${WEEK_START} to ${WEEK_END})
Generated: $(date +%Y-%m-%d)

## Items Already in PSC
[list items from MY-PSC.md W${WEEK_NUM} entry]

## New Items Found (not yet in PSC)

### Shipped
[diffs landed — use IMPACT.md descriptions when available]

### Influenced
[decisions shaped, with evidence from Workplace/GChat/meetings]

### SEVs
[any SEV involvement]

## Suggested Impact Framing
[1-sentence PSC-ready summary for the week]

Be concise. Focus on PSC-worthy items only." -- \
    --allowedTools Read Write Edit Glob Grep Bash Skill Task \
    --model claude-opus-4-6 \
    --max-turns 30 \
    || exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Verify output was actually written
    DRAFT_FILE="$REPO_DIR/context/myself/psc/WEEKLY-DRAFT.md"
    if [ -f "$DRAFT_FILE" ]; then
        draft_date=$(date -r "$DRAFT_FILE" +%Y-%m-%d 2>/dev/null || echo "unknown")
        if [ "$draft_date" = "$(date +%Y-%m-%d)" ]; then
            cron_alert_clear "weekly-report"
            echo "$(date '+%Y-%m-%d %H:%M') Weekly report generated and verified: $DRAFT_FILE"
        else
            cron_alert "weekly-report" "Weekly report exited OK but WEEKLY-DRAFT.md not updated today (last: $draft_date)"
            echo "$(date '+%Y-%m-%d %H:%M') Output verification failed — draft stale"
        fi
    else
        cron_alert "weekly-report" "Weekly report exited OK but WEEKLY-DRAFT.md missing"
        echo "$(date '+%Y-%m-%d %H:%M') Output verification failed — draft missing"
    fi
else
    cron_alert "weekly-report" "Report generation failed with exit code $exit_code — check /tmp/cron-weekly-report-err.log"
    echo "$(date '+%Y-%m-%d %H:%M') Report generation failed (exit $exit_code)"
fi

# Write heartbeat sentinel
write_heartbeat "weekly-report"
