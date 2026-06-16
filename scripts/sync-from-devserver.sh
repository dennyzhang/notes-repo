#!/bin/bash
# sync-from-devserver.sh — One-directional sync: devserver → Mac
# Runs ON the Mac, pulls FROM the devserver.
# Usage: bash sync-from-devserver.sh [devserver-hostname]

set -euo pipefail

DEVSERVER="${1:-devstable}"
REMOTE_PATH="~/work/claude/"
DROPBOX_PATH="$HOME/Library/CloudStorage/Dropbox/org_data/work/claude/"
if [ -d "$DROPBOX_PATH" ]; then
    LOCAL_PATH="$DROPBOX_PATH"
else
    LOCAL_PATH="$HOME/work/claude/"
fi

echo "Pulling from $DEVSERVER:$REMOTE_PATH → $LOCAL_PATH"

# --force: devserver reorgs occasionally turn a real dir into a symlink
# (e.g. mrs-ot-agent-context/auto-fixes -> system-fixes/auto-fixes). Without
# --force rsync refuses to replace a non-empty local dir with a symlink and
# exits 23, which aborts the whole sync under `set -e`.
rsync -avz --delete --force --copy-links \
    --exclude='.git' \
    --exclude='_disk.txt' \
    --exclude='backup' \
    --exclude='remote_fetch' \
    --exclude='.claude/state' \
    --exclude='.claude/sessions' \
    --exclude='.claude/settings.json' \
    --exclude='.claude/settings.local.json' \
    --exclude='.claude/scheduled_tasks.lock' \
    --exclude='context/cache/state' \
    --exclude='context/cache/digests' \
    --exclude='context/cache/journals' \
    --exclude='context/cache/gchat' \
    --exclude='context/cache/comms' \
    --exclude='logs' \
    "$DEVSERVER:$REMOTE_PATH" "$LOCAL_PATH"

NOTES_REMOTE="~/notes/users/dennyzhang/"
NOTES_LOCAL="${LOCAL_PATH}notes/users/dennyzhang/"
echo "Pulling from $DEVSERVER:$NOTES_REMOTE → $NOTES_LOCAL"
rsync -avz --force --exclude='.git' \
    "$DEVSERVER:$NOTES_REMOTE" "$NOTES_LOCAL"

cd "$NOTES_LOCAL"
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "Notes: no changes"
else
    git add -A && git commit -m "sync $(date '+%Y-%m-%d %H:%M')" || true
    # Proxy-aware, non-fatal push: this env has no direct public egress (only the
    # X2P proxy). Try direct first, then ssh-over-443 through the proxy. Never let
    # a notes-push failure abort the parent sync.
    if ! git push 2>/dev/null; then
        PROXY="${HTTP_PROXY:-http://localhost:10054}"; PROXY="${PROXY#http://}"; PROXY="${PROXY#https://}"
        NOTES_URL="$(git remote get-url origin 2>/dev/null | sed -E 's#git@github.com:#ssh://git@ssh.github.com:443/#')"
        GIT_SSH_COMMAND="ssh -o ProxyCommand='nc -X connect -x ${PROXY} %h %p' -o StrictHostKeyChecking=no -i $HOME/Dropbox/private_data/emacs_stuff/backup_small/ssh_key/github_id_rsa" \
            git push "$NOTES_URL" HEAD 2>/dev/null \
            && echo "Notes: pushed via proxy" \
            || echo "Notes: push FAILED (non-fatal) — committed locally"
    fi
fi
cd - > /dev/null

echo "Done. $(date '+%Y-%m-%d %H:%M')"

# First-run setup (run once after first sync):
# mkdir -p ~/work/claude
# mkdir -p ~/.claude/projects/-home-dennyzhang-work-claude
# ln -s ~/work/claude/memory ~/.claude/projects/-home-dennyzhang-work-claude/memory
#
# Notes submodule setup (run once):
# cd ~/work/claude
# git submodule add git@github.com:dennyzhang/notes-repo.git notes/users/dennyzhang
