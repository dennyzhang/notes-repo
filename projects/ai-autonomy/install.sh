#!/usr/bin/env bash
# install.sh — auto-discovery installer for the ai-autonomy gate (no human paste).
#
# Each host self-installs. Wire ONCE into the ~/work/claude cron fleet — a daily notes-pull +
# discover cron next to cron-notes-push.sh — then it's automatic:
#   cd ~/notes && sl pull -q 2>/dev/null && \
#     bash ~/notes/users/dennyzhang/projects/ai-autonomy/install.sh --if-changed
#
# Idempotent + self-validating + reversible: activates ONLY if the gate selftest passes,
# stamps the installed content-hash version, and never half-applies. A bad push to master
# self-rejects on each host instead of bricking the fleet (auto-apply = high blast radius).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# Host-local automation state — same dir the rest of the ~/work/claude cron fleet uses.
STATE="${AI_AUTONOMY_STATE:-$HOME/work/claude/state}"
STAMP="$STATE/ai-autonomy.version"
mkdir -p "$STATE"

# version = content hash of the project (changes whenever a rule/script changes)
version() { find "$DIR" -type f \( -name '*.sh' -o -name '*.json' \) -exec sha1sum {} + \
            | sort | sha1sum | cut -d' ' -f1; }
CUR="$(version)"; HAVE="$(cat "$STAMP" 2>/dev/null || echo none)"

if [ "${1:-}" = "--if-changed" ] && [ "$CUR" = "$HAVE" ]; then
  echo "ai-autonomy: up to date ($CUR)"; exit 0
fi
echo "ai-autonomy: installing $HAVE -> $CUR"

# 1. validate — never activate a broken gate (fleet-blast safety)
if ! bash "$DIR/ask-gate.sh" --selftest >/dev/null 2>&1; then
  echo "ai-autonomy: SELFTEST FAILED — aborting; host stays on $HAVE"; exit 1
fi
command -v jq >/dev/null || echo "ai-autonomy: WARN jq missing — gate rules won't load"

# 2. activate (idempotent): expose a stable gate path the daemon/hooks call, independent
#    of where the notes repo is checked out. Layer-2 (canUseTool + post-turn auto-approver)
#    and Layer-3 (examples hook) read this path and self-activate here once that wiring lands.
ln -sf "$DIR/ask-gate.sh"    "$STATE/ask-gate.sh"
ln -sf "$DIR/gate-rules.json" "$STATE/ai-autonomy-rules.json"
echo "ai-autonomy: gate -> $STATE/ask-gate.sh"

# 3. stamp — discovery is a version compare, not a doc to read
echo "$CUR" > "$STAMP"
echo "ai-autonomy: installed $CUR"
