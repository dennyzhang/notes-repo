#!/usr/bin/env bash
# enforcement-log.sh — Shared enforcement metrics logging.
# Called by hooks to record every block, warn, and pass event.
#
# Usage:
#   source ~/work/claude/scripts/enforcement-log.sh
#   log_enforcement "rule_name" "action_attempted" "blocked|warned|passed" "details"
#
# Or standalone:
#   bash ~/work/claude/scripts/enforcement-log.sh "rule_name" "action" "result" "details"
#
# Log file: ~/logs/enforcement-metrics.csv
# Format: timestamp,session_id,rule,action,result,details

ENFORCEMENT_LOG="${HOME}/logs/enforcement-metrics.csv"

log_enforcement() {
    local rule="$1"
    local action="$2"
    local result="$3"  # blocked, warned, passed, overridden
    local details="${4:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    # Prefer caller-provided SID (set by enforce-prerequisites.sh after JSON parse),
    # then env var (rarely propagated to hook subprocess), then PID fallback.
    local sid="${SID:-${CLAUDE_CODE_CURRENT_SESSION_ID:-unknown}}"
    local sid_short
    if [ "$sid" != "unknown" ] && [ -n "$sid" ]; then
        sid_short=$(echo "$sid" | md5sum | cut -c1-8)
    else
        sid_short="$$"
    fi

    # Create log file with header if it doesn't exist
    if [ ! -f "$ENFORCEMENT_LOG" ]; then
        mkdir -p "$(dirname "$ENFORCEMENT_LOG")"
        echo "timestamp,session_id,rule,action,result,details" > "$ENFORCEMENT_LOG"
    fi

    # Append with file locking (prevents concurrent write corruption)
    local safe_details
    safe_details=$(printf '%s' "$details" | tr ',' ';' | tr '\n' ' ' | cut -c1-200)
    local safe_rule safe_action
    safe_rule=$(printf '%s' "$rule" | tr ',' ';')
    safe_action=$(printf '%s' "$action" | tr ',' ';')
    local line="${timestamp},${sid_short},${safe_rule},${safe_action},${result},${safe_details}"
    # Use flock for atomic append (falls back to raw append if flock unavailable)
    if command -v flock >/dev/null 2>&1; then
        flock -n "$ENFORCEMENT_LOG.lock" -c "echo '$line' >> '$ENFORCEMENT_LOG'" 2>/dev/null || echo "$line" >> "$ENFORCEMENT_LOG"
    else
        echo "$line" >> "$ENFORCEMENT_LOG"
    fi
}

# If called standalone (not sourced), log the arguments
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ $# -ge 3 ]; then
    log_enforcement "$@"
fi
