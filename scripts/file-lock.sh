#!/usr/bin/env bash
# file-lock.sh — Atomic file-level locking for concurrent session safety.
#
# Usage:
#   source ~/work/claude/scripts/file-lock.sh
#   file_lock "FOLLOWUPS.md"    # acquire lock (blocks up to 10s)
#   ... edit FOLLOWUPS.md ...
#   file_unlock "FOLLOWUPS.md"  # release lock
#
# Uses mkdir for atomic lock acquisition (no race condition).
# Lock dirs stored in /tmp/claude-file-locks/
# Auto-expires after 60 seconds (stale lock protection with PID check)

LOCK_DIR="/tmp/claude-file-locks"
mkdir -p "$LOCK_DIR" 2>/dev/null

file_lock() {
    local filename=$(echo "$1" | tr '/' '_')
    local lock="$LOCK_DIR/${filename}.lock"
    local max_wait=10
    local waited=0

    while ! mkdir "$lock" 2>/dev/null; do
        waited=$((waited + 1))
        if [ "$waited" -ge $((max_wait * 2)) ]; then
            echo "[file-lock] WARNING: Timeout waiting for lock on $1 — proceeding without lock" >&2
            rm -rf "$lock" 2>/dev/null
            return 1
        fi

        # Check if owning process is still alive
        local owner_pid=""
        [ -f "$lock/pid" ] && owner_pid=$(cat "$lock/pid" 2>/dev/null)
        if [ -n "$owner_pid" ] && ! kill -0 "$owner_pid" 2>/dev/null; then
            # Owner is dead — steal the lock
            rm -rf "$lock"
            continue
        fi

        # Stale lock check (60 second max age)
        local lock_age=$(( $(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || echo "$(date +%s)") ))
        if [ "$lock_age" -gt 60 ]; then
            rm -rf "$lock"
            continue
        fi

        sleep 0.5
    done

    echo "$$" > "$lock/pid"
    return 0
}

file_unlock() {
    local filename=$(echo "$1" | tr '/' '_')
    local lock="$LOCK_DIR/${filename}.lock"
    rm -rf "$lock"
}
