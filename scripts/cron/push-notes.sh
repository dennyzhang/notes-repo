#!/bin/bash
# Auto-push notes repo every 4 hours
#
# Install: crontab -e → 0 */4 * * * ~/notes/users/dennyzhang/scripts/push-notes.sh >> ~/push-notes.log 2>&1

set -euo pipefail

NOTES_DIR="/data/users/dennyzhang/notes"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

cd "$NOTES_DIR" || { log "ERROR: cannot cd to $NOTES_DIR"; exit 1; }

# Check for uncommitted changes
if [ -n "$(sl status 2>/dev/null)" ]; then
    sl add users/dennyzhang/ 2>/dev/null || true
    sl commit -m "auto-push: $(date '+%Y-%m-%d %H:%M')" --reason "auto-push notes cron - sl help commit" 2>/dev/null || true
    log "Committed pending changes"
fi

# Check for unpushed commits
if sl log -r 'draft()' -T '{node}\n' --reason "check for unpushed commits - sl help log" 2>/dev/null | grep -q .; then
    sl push --to master --reason "auto-push notes cron - sl help push" 2>&1
    log "Pushed to master"
else
    log "Nothing to push"
fi
