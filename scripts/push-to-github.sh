#!/bin/bash
# push-to-github.sh — Commit all local changes and push the claude repo to GitHub.
# Proxy-aware: this environment (Claude Code on the Mac / devserver) has NO direct
# public egress — only the X2P agent proxy at $HTTP_PROXY (localhost:10054). Plain
# `git push` over ssh:22 fails with EPERM ("Operation not permitted") because ssh
# ignores HTTP_PROXY. So we try a direct push first (works from a normal Terminal
# with real internet), then fall back to ssh tunneled through the proxy on 443.
# Usage: bash push-to-github.sh ["commit message"]

set -uo pipefail

DROPBOX_PATH="$HOME/Library/CloudStorage/Dropbox/org_data/work/claude"
[ -d "$DROPBOX_PATH" ] && REPO="$DROPBOX_PATH" || REPO="$HOME/work/claude"
cd "$REPO"

MSG="${1:-sync from devstable — $(date '+%Y-%m-%d %H:%M')}"
GH_KEY="$HOME/Dropbox/private_data/emacs_stuff/backup_small/ssh_key/github_id_rsa"

# Strip stray artifact (synced from devserver) before staging.
rm -f _disk.txt

git add -A
if git diff --cached --quiet; then
    echo "No changes to commit."
else
    git commit -m "$MSG" || { echo "Commit failed (pre-commit hook?)."; exit 1; }
fi

echo "Attempting direct push (origin main)..."
if git push origin main 2>/tmp/gh-push-err; then
    echo "Pushed directly."
    exit 0
fi
echo "Direct push failed:"; sed 's/^/  /' /tmp/gh-push-err

# Fallback: ssh over 443 through the egress proxy.
PROXY="${HTTP_PROXY:-http://localhost:10054}"
PROXY="${PROXY#http://}"; PROXY="${PROXY#https://}"
echo "Falling back to proxied ssh via $PROXY (ssh.github.com:443)..."
GIT_SSH_COMMAND="ssh -o ProxyCommand='nc -X connect -x ${PROXY} %h %p' -o StrictHostKeyChecking=no -i ${GH_KEY}" \
    git push ssh://git@ssh.github.com:443/dennyzhang/claude.git main \
    && echo "Pushed via proxy." \
    || { echo "Push failed via both routes."; exit 1; }
