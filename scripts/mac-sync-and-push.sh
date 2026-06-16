#!/bin/bash
# mac-sync-and-push.sh — Runs ON the Mac. One command for the recurring
# "rsync from devserver and push to github" task. Safe to run on a cron:
# pulls latest from devstable, then pushes (proxy-aware fallback inside
# push-to-github.sh). No-ops the push when there is nothing new. Non-fatal
# if the devstable SSH cert is expired — it just logs and exits.
# Installed in Mac crontab by private_scripts/setup-claude.sh.

set -uo pipefail

DROPBOX_PATH="$HOME/Library/CloudStorage/Dropbox/org_data/work/claude"
[ -d "$DROPBOX_PATH" ] && REPO="$DROPBOX_PATH" || REPO="$HOME/work/claude"
cd "$REPO"

echo "===== mac-sync-and-push $(date '+%Y-%m-%d %H:%M:%S') ====="

# Retry the sync — the devstable SSH connection occasionally drops mid-transfer
# (io_read_nonblocking) due to short-lived-cert renewal. Transient, so retry.
sync_ok=""
for attempt in 1 2 3; do
    if bash scripts/sync-from-devserver.sh; then
        echo "sync: OK (attempt $attempt)"
        sync_ok=1
        break
    fi
    echo "sync: attempt $attempt failed — retrying in 10s"
    sleep 10
done
if [ -z "$sync_ok" ]; then
    echo "sync: FAILED after 3 attempts (likely expired SSH cert to devstable) — skipping push"
    exit 1
fi

bash scripts/push-to-github.sh "auto sync from devstable — $(date '+%Y-%m-%d %H:%M')"
echo "===== done $(date '+%Y-%m-%d %H:%M:%S') ====="
