#!/usr/bin/env bash
# cron-sync-to-github.sh — Commit and push local workspace to GitHub
#
# Flow: git add → git commit → git push (force if histories diverged)
# Runs on MAC only. File sync from devserver is handled by cron-file-sync.sh.
#
# Crontab entry (in setup-claude.sh):
#   17 9 * * * bash .../cron-sync-to-github.sh >> ~/logs/sync-to-github.log 2>&1

set -euo pipefail

# Inherit macOS ssh-agent (cron doesn't get SSH_AUTH_SOCK from login shell)
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    for sock in /private/tmp/com.apple.launchd.*/Listeners; do
        if [ -S "$sock" ]; then
            export SSH_AUTH_SOCK="$sock"
            break
        fi
    done
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/cron-alert.sh"

REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOCK_FILE="/tmp/cron-sync-to-github.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M:%S')"

log() { echo "$LOG_PREFIX [github-sync] $*"; }

# Prevent overlapping runs
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

# Check GitHub SSH connectivity
ssh_output=$(ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 || true)
if ! echo "$ssh_output" | grep -q "successfully authenticated"; then
    log "GitHub SSH auth failed. SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-unset}. Run 'ssh -T git@github.com' to debug."
    cron_alert "github-sync" "GitHub SSH auth failed — SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-unset}"
    exit 1
fi

cd "$REPO_DIR"

# Initialize git repo if needed (first run)
if [ ! -d .git ]; then
    log "No git repo found — skipping. Run 'git init && git remote add origin <url>' first."
    exit 0
fi

# Check for changes
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "No changes to commit"
else
    # Show what changed before committing
    changed_files=$(git status --short)
    log "Changes detected:"
    echo "$changed_files" | while read -r line; do
        log "  $line"
    done
    # Delegate to commit-digest.sh which splits changes into SIGNAL + STATE
    # commits with descriptive per-file hints (easier GitHub spot-checking).
    bash "$REPO_DIR/scripts/commit-digest.sh" 2>&1 | while read -r line; do log "  $line"; done
fi

# Push — force if histories diverged (e.g., after local squash/trim)
if git push -u origin main --quiet 2>&1; then
    log "Pushed to GitHub"
    cron_alert_clear "github-sync"
elif git push -u origin main --force --quiet 2>&1; then
    log "Force-pushed to GitHub (histories had diverged)"
    cron_alert_clear "github-sync"
else
    log "Push failed"
    cron_alert "github-sync" "git push to GitHub failed — check SSH key and remote"
    exit 1
fi

# Success path only — heartbeat (per workflow-design.md rule 2)
write_heartbeat "sync-to-github"
