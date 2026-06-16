#!/usr/bin/env bash
# cheatsheet-harvest.sh — weekly skill-harvest for the cheatsheet flywheel (Goal 2).
#
# Runs the harvest as a headless `claude` turn driven by the prompt at
# cheatsheet-harvest.prompt.md. That prompt instructs claude to use the Workflow
# tool (fan-out scan -> dedup -> adversarial reject -> draft) and write ONE
# candidate change to the dated draft file. NOTHING is landed or pushed — the
# operator reviews the draft, then decides (tier policy in
# cheatsheets/agents/cheatsheet-flywheel.md).
#
# Install (crontab): weekly, Monday 08:00
#   0 8 * * 1 ~/notes/users/dennyzhang/scripts/cron/cheatsheet-harvest.sh >> ~/logs/cheatsheet-harvest/cron.log 2>&1
#
# Safe by construction: read-mostly; only write is the draft file under OUTDIR.
set -uo pipefail

PROMPT="$HOME/notes/users/dennyzhang/scripts/cron/cheatsheet-harvest.prompt.md"
OUTDIR="$HOME/logs/cheatsheet-harvest"
DATE="$(date +%Y-%m-%d)"
OUT="$OUTDIR/$DATE.md"
mkdir -p "$OUTDIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

[ -f "$PROMPT" ] || { log "ERROR: prompt missing: $PROMPT"; exit 1; }
command -v claude >/dev/null || { log "ERROR: claude not on PATH"; exit 1; }

log "harvest start -> $OUT"
# --print: non-interactive single turn. Pass the prompt with the output path
# substituted so claude writes the draft itself.
sed "s#{{OUT}}#$OUT#g" "$PROMPT" | claude --print >> "$OUT.run.log" 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
  log "WARN: claude exited rc=$rc (see $OUT.run.log)"
fi
if [ -s "$OUT" ]; then
  log "harvest produced candidate draft: $OUT ($(wc -l < "$OUT") lines)"
else
  log "harvest: no candidate this run (nothing new cleared the bar)"
fi
exit 0
