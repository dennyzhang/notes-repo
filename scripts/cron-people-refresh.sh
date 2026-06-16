#!/usr/bin/env bash
# cron-people-refresh.sh — Daily auto-refresh of people profiles.
#
# Scans context/people/ for profiles older than 3 days and refreshes them
# by spawning a Claude session with /my-people refresh.
#
# Schedule: Daily 4 AM via crontab
# Staleness: 3 days (compromise between weekly=stale and daily=wasteful)
# Crontab entry:
#   0 4 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 1800 people-refresh ~/work/claude/scripts/cron-people-refresh.sh >> ~/logs/people-refresh.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
PEOPLE_DIR="$REPO_DIR/context/people"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
LOCK_FILE="/tmp/cron-people-refresh.lock"
MAX_REFRESH=12  # Cap per run — must fit within 1800s outer timeout (12 × 120s = 1440s)

# Clear Claude Code session markers so nested claude -p works
unset CLAUDECODE 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check
if [ ! -d "$PEOPLE_DIR" ]; then
    echo "$LOG_PREFIX People directory missing: $PEOPLE_DIR"
    exit 0
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
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$LOG_PREFIX === People Profile Refresh ==="

# Find profiles older than 7 days (excluding README and special files)
stale_profiles=()
while IFS= read -r profile; do
    basename=$(basename "$profile" .md)
    [[ "$basename" == "README" || "$basename" == "IC7-WATCHLIST" || "$basename" == "TEMPLATE" || "$basename" == "REGISTRY" ]] && continue
    stale_profiles+=("$basename")
done < <(find "$PEOPLE_DIR" -name "*.md" -mtime +3 2>/dev/null)

total_stale=${#stale_profiles[@]}
echo "$LOG_PREFIX Found $total_stale stale profiles (>3 days old)"

if [ "$total_stale" -eq 0 ]; then
    echo "$LOG_PREFIX All profiles are fresh. Nothing to refresh."
    write_heartbeat "people-refresh"
    echo "$LOG_PREFIX === People Refresh Done (0 refreshed) ==="
    exit 0
fi

# Cap at MAX_REFRESH per run
refresh_count=0
refreshed=()
failed=()

for username in "${stale_profiles[@]}"; do
    [ "$refresh_count" -ge "$MAX_REFRESH" ] && break

    echo "$LOG_PREFIX Refreshing: $username"
    lowercase=$(echo "$username" | tr '[:upper:]' '[:lower:]')

    # Spawn Claude to refresh this profile
    refresh_exit=0
    run_llm "people-refresh" 120 /tmp/cron-people-refresh-${lowercase}.log \
        "Refresh the people profile for $lowercase. Read the existing profile at context/people/${username}.md, preserve the Manual Annotations and Work History Digest sections, and update all auto-refreshed sections (Identity, Current Focus, Recent Work, Communication) from current data sources. Write the updated profile back to the same file. Do NOT post to external systems." -- \
        --allowedTools Read,Write,Edit,Bash \
        --model claude-haiku-4-5-20251001 \
        --max-turns 12 \
        || refresh_exit=$?

    if [ "$refresh_exit" -eq 0 ]; then
        refreshed+=("$lowercase")
        echo "$LOG_PREFIX   $username: refreshed"
    else
        failed+=("$lowercase")
        # Capture error reason from temp log for diagnosis
        err_reason=$(grep -oE "Error: .{0,80}" /tmp/cron-people-refresh-${lowercase}.log 2>/dev/null | tail -1 || echo "unknown")
        echo "$LOG_PREFIX   $username: FAILED (exit $refresh_exit) — $err_reason"
    fi

    refresh_count=$((refresh_count + 1))
done

# Report
echo "$LOG_PREFIX Refreshed: ${#refreshed[@]} | Failed: ${#failed[@]} | Remaining: $((total_stale - refresh_count))"

if [ ${#failed[@]} -gt 0 ]; then
    cron_alert "people-refresh" "${#failed[@]} profiles failed to refresh: ${failed[*]}"
else
    cron_alert_clear "people-refresh"
fi

# Heartbeat only on success path
if [ ${#refreshed[@]} -gt 0 ] || [ "$total_stale" -eq 0 ]; then
    write_heartbeat "people-refresh"
fi

echo "$LOG_PREFIX === People Refresh Done (${#refreshed[@]} refreshed) ==="
