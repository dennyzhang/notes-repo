#!/bin/bash
# notes-sl-lock.sh — serialize tree-mutating `sl` ops on the SHARED notes checkout
# (Option B, operator-approved 2026-06-14). Multiple Claude/MyClaw sessions + crons
# edit one notes working tree with no isolation; a tree-wide `sl` op (commit / goto /
# clean / pull --rebase / amend / revert) from one session can clobber another's
# in-flight work. This wraps such an op in an exclusive flock so two never run at once.
#
# Usage:   notes-sl-lock.sh <cmd...>      e.g.  notes-sl-lock.sh sl commit -m "..."
# Scope:   wrap EVERY tree-mutating sl op on the notes repo with this (Stop-hook +
#          every notes-writing cron). Read-only sl (status/log/diff) need NOT lock.
#
# Fail-OPEN: if the lock can't be opened or 60s elapses, run the command ANYWAY and
# warn — the lock must reduce races, never become a new way to wedge a cron/daemon.
# Caveat: this serializes sl COMMANDS; it does not hold across an Edit-then-commit
# gap (the Edit tool isn't lock-aware) — that residual window is covered by the
# Stop-hook committing fast. Full cure of the edit-window race is per-session
# worktrees (Option A); this is the lighter, approved first step.
set -uo pipefail
[ "$#" -ge 1 ] || { echo "usage: $0 <command...>" >&2; exit 2; }
LOCK="${NOTES_SL_LOCK:-$HOME/notes/.sl-write.lock}"
TIMEOUT="${NOTES_SL_LOCK_TIMEOUT:-60}"

# Open the lock fd; if that fails (no flock / unwritable path), just run unlocked.
if ! exec 9>"$LOCK" 2>/dev/null; then
  echo "[notes-sl-lock] cannot open $LOCK — running unlocked (fail-open)" >&2
  exec "$@"
fi
if command -v flock >/dev/null 2>&1 && flock -w "$TIMEOUT" 9; then
  "$@"; rc=$?
  flock -u 9 2>/dev/null || true
  exit "$rc"
else
  echo "[notes-sl-lock] lock unavailable / ${TIMEOUT}s timeout — running unlocked (fail-open)" >&2
  exec "$@"
fi
