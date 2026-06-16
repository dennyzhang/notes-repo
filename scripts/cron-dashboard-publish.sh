#!/usr/bin/env bash
# cron-dashboard-publish.sh — regenerate the cron dashboard HTML and update a
# STABLE Collab Files page (browser-viewable via internalfb.com, works behind
# the corp firewall).
#
# Uses a gdrive FUSE mount so the file ID — and therefore the shareable URL —
# stays constant while content is updated in place. No rotation, never "outdated"
# (operator complaint 2026-06-14): the AI Playbook can embed one permanent link
# and an open Collab tab auto-refreshes to the latest content every 5s.
#
# Stable URL -> state/cron-dashboard-url.txt (read by cron-ai-health.sh).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML="/tmp/cron-dashboard.html"
MOUNT="$HOME/gdrive"
URL_FILE="$SCRIPT_DIR/../state/cron-dashboard-url.txt"
UPLOADER="$HOME/.claude/skills/visualize/scripts/gdrive_upload.sh"

# Ensure the FUSE mount is up (detached so it survives this process exiting).
if ! grep -qF " $MOUNT fuse" /proc/mounts 2>/dev/null; then
    mkdir -p "$MOUNT"
    setsid gdrive mount "$MOUNT" --folder my-drive >/tmp/gdrive-mount.log 2>&1 &
    for _ in 1 2 3 4 5 6 7 8; do
        grep -qF " $MOUNT fuse" /proc/mounts 2>/dev/null && break
        sleep 1
    done
fi

python3 "$HOME/work/claude/private_scripts/cron-dashboard.py" --html "$HTML"

[ -x "$UPLOADER" ] || { echo "[ERROR] uploader missing: $UPLOADER" >&2; exit 1; }
out=$(bash "$UPLOADER" "$HTML" cron-dashboard 2>&1) || { echo "[ERROR] upload failed: $out" >&2; exit 1; }
url=$(echo "$out" | grep -oE 'COLLAB_URL=.*' | cut -d= -f2-)
if [ -n "$url" ]; then
    echo "$url" > "$URL_FILE"
    echo "[OK] dashboard published (stable URL): $url"
else
    echo "[ERROR] no COLLAB_URL in: $out" >&2
    exit 1
fi
