#!/usr/bin/env bash
# cheatsheet-sweep.sh — periodic full-tree structural sweep (flywheel station 1b).
#
# WHY THIS EXISTS: the commit gate (cheatsheet-lint-hook.sh) is REACTIVE — it
# only sees files in the current commit. Pre-existing structural debt in files
# nobody is editing (broken refs, stale provenance, orphans, oversize) is
# invisible to it. This sweep is the PROACTIVE counterpart: it audits the whole
# tree on a schedule, auto-applies the unambiguous/reversible fixes, and drafts
# the rest for operator review. Cheap (no LLM) — safe to run daily.
#
# Install (crontab): daily 07:30 (before the weekly harvest)
#   30 7 * * * ~/notes/users/dennyzhang/scripts/cron/cheatsheet-sweep.sh >> ~/logs/cheatsheet-harvest/sweep.log 2>&1
#
# Auto-fixed (reversible): legacy `cheatsheet-X.md` refs with a unique target.
# Drafted for review: dead refs, oversize files, orphans. The 4-hourly notes
# auto-push commits the auto-fixes; they pass the gate.
set -uo pipefail

LINT="$HOME/notes/users/dennyzhang/scripts/lint/lint-cheatsheets.sh"
OUTDIR="$HOME/logs/cheatsheet-harvest"
DATE="$(date +%Y-%m-%d)"
DRAFT="$OUTDIR/sweep-$DATE.md"
mkdir -p "$OUTDIR"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

[ -f "$LINT" ] || { log "ERROR: linter missing: $LINT"; exit 1; }

log "sweep: applying auto-fixes"
bash "$LINT" --fix
bash "$LINT" --fix-index   # self-heal CHEATSHEET-INDEX.md "Files" counts

# Full structural audit + content-grounding backlog -> draft if anything needs a human.
audit="$(bash "$LINT" 2>&1)"
grounding="$(bash "$LINT" --audit-grounding 2>&1)"
gsummary="$(printf '%s' "$grounding" | tail -1)"
if echo "$audit" | grep -qE '^# [1-9]' || printf '%s' "$gsummary" | grep -qE ' [1-9][0-9]* / '; then
  {
    echo "# Cheatsheet sweep — $DATE"
    echo ""
    echo "Auto-fixes already applied (legacy renames w/ unique target; index counts)."
    echo "## Structural findings (dead refs / oversize / orphans):"
    echo '```'
    echo "$audit"
    echo '```'
    echo "## Content: ungrounded rule backlog (rules with no citation token)"
    echo "Review-driver, NOT a defect count — craft rules (style advice) legitimately"
    echo "have no incident source. Backfill incident-derived rules from the learnings-log;"
    echo "mark craft rules exempt."
    echo '```'
    echo "$grounding"
    echo '```'
  } > "$DRAFT"
  log "sweep: review draft written -> $DRAFT ($gsummary)"
else
  log "sweep: tree clean, no draft"
fi
exit 0
