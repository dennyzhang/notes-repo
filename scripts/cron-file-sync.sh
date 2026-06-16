#!/usr/bin/env bash
# cron-file-sync.sh — Bidirectional file sync between Mac and devserver
#
# Two sync directions, different frequencies:
#   1. Screenshots Mac → devserver  (every 5 min)
#   2. Claude folder devserver → Mac (hourly)
#
# Runs on MAC only. Requires SSH ControlMaster socket to devserver.
#
# Crontab entries (registered in setup-claude.sh):
#   */5 * * * * bash .../cron-file-sync.sh >> ~/logs/file-sync.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/cron-alert.sh"

REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOCK_FILE="/tmp/cron-file-sync.lock"
HOURLY_SENTINEL="/tmp/cron-file-sync-hourly-last"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M:%S')"

# --- Configuration ---
DEVSERVER="devstable"
SCREENSHOT_LOCAL="$REPO_DIR/screenshot/"
SCREENSHOT_REMOTE="$HOME/work/claude/screenshot/"
CLAUDE_REMOTE="$HOME/work/claude/"
CLAUDE_LOCAL="$REPO_DIR/"
# Interval in seconds for the "hourly" pull (3600 = 1 hour)
HOURLY_INTERVAL=3600

log() { echo "$LOG_PREFIX [file-sync] $*"; }

# --- Lock guard ---
if [ -f "$LOCK_FILE" ]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -gt 600 ]; then
        log "Stale lock (${lock_age}s old) — removing"
        rm -f "$LOCK_FILE"
    else
        log "Already running (lock age: ${lock_age}s) — skipping"
        exit 0
    fi
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

# --- SSH check ---
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$DEVSERVER" true 2>/dev/null; then
    log "Cannot reach $DEVSERVER — SSH session not active. Skipping."
    exit 0
fi

# ============================================================
# 1. Screenshots: Mac → devserver (every run, every 5 min)
# ============================================================
if [ -d "$SCREENSHOT_LOCAL" ]; then
    # Ensure remote directory exists
    ssh "$DEVSERVER" "mkdir -p $SCREENSHOT_REMOTE" 2>/dev/null || true

    log "Pushing screenshots → $DEVSERVER ..."
    rsync -az --ignore-existing \
        "$SCREENSHOT_LOCAL" \
        "$DEVSERVER:$SCREENSHOT_REMOTE"
    log "Screenshots synced"
else
    log "No screenshot directory at $SCREENSHOT_LOCAL — skipping push"
fi

# ============================================================
# 2. Claude folder: devserver → Mac (hourly)
# ============================================================
should_pull=false
if [ ! -f "$HOURLY_SENTINEL" ]; then
    should_pull=true
else
    last_pull=$(stat -f %m "$HOURLY_SENTINEL" 2>/dev/null || echo 0)
    now=$(date +%s)
    elapsed=$(( now - last_pull ))
    if [ "$elapsed" -ge "$HOURLY_INTERVAL" ]; then
        should_pull=true
    fi
fi

if [ "$should_pull" = true ]; then
    log "Pulling Claude folder ← $DEVSERVER (hourly) ..."
    rsync -az --delete --copy-dirlinks \
        --exclude='.git/' \
        --exclude='screenshot/' \
        --exclude='backup/' \
        --exclude='remote_fetch/' \
        --exclude='.DS_Store' \
        "$DEVSERVER:$CLAUDE_REMOTE" "$CLAUDE_LOCAL"
    touch "$HOURLY_SENTINEL"
    log "Claude folder synced"
    cron_alert_clear "file-sync"
else
    log "Hourly pull not due yet (${elapsed}s / ${HOURLY_INTERVAL}s)"
fi
