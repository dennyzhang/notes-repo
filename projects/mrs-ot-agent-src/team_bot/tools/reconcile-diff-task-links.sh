#!/usr/bin/env bash
# reconcile-diff-task-links.sh — sweep bot-authored diffs whose title references
# a T### task but whose Phabricator `tasks:` field is EMPTY, and backfill the
# link (task-side `--add-diff`). Heals the diff↔task association failure class
# that a point-in-time create+verify misses (task filed after the diff,
# Tasks: line stripped on amend, Unpublished/proposal diffs, cross-session).
#
# Root case: D106049931 carried "(T272497510)" in its title but tasks: was empty
# → task showed 0 linked diffs (2026-06-08). Verify-at-creation can't catch the
# cross-session / post-hoc / amend-strip variants — a reconciliation sweep can.
#
# Usage:
#   reconcile-diff-task-links.sh [--apply] [--limit=N]
#     (default = DRY-RUN: report candidates, mutate nothing)
#     --apply  = backfill links via `meta tasks.task update --add-diff` (capped)
#     --limit  = how many recent self-authored diffs to scan (default 60)
#
# Safety: additive+reversible (linking only, never unlink); MAX_BACKFILL cap;
# logs every action; verifies each backfill; skips Abandoned/Closed-no-task by
# design only when the title has no T### (we only ever ADD a link the title
# already asserts). Never touches review state.

set -uo pipefail

APPLY=0
LIMIT=60
MAX_BACKFILL=25
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --limit=*) LIMIT="${a#--limit=}" ;;
    *) echo "unknown arg: $a" >&2; exit 1 ;;
  esac
done

LOG="$HOME/.myclaw-ot-bot/spaces/AAQAVOjYc80/reconcile-diff-task-links.log"
ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
emit() { echo "$*"; echo "$(ts) $*" >> "$LOG"; }

emit "[reconcile] start apply=$APPLY limit=$LIMIT"

# Recent self-authored diffs: "D<number>  <title...>"
diffs=$(meta phabricator.diff list --author-is-me --limit="$LIMIT" 2>/dev/null \
        | grep -oE '^D[0-9]+.*')

candidates=0; backfilled=0; failed=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  dnum=$(printf '%s' "$line" | grep -oE '^D[0-9]+')
  # Task ids referenced in the TITLE (the common leak: free-text mention).
  tref=$(printf '%s' "$line" | grep -oE 'T[0-9]{6,}' | head -1)
  [ -z "$tref" ] && continue            # no task asserted in title → nothing to reconcile
  # Already linked? (bidirectional check from the diff side)
  if meta phabricator.diff tasks --number="$dnum" 2>/dev/null | grep -qE '^T[0-9]'; then
    continue                            # link present → fine
  fi
  candidates=$((candidates+1))
  emit "[candidate] $dnum title asserts $tref but tasks: is EMPTY"
  if [ "$APPLY" -eq 1 ]; then
    if [ "$backfilled" -ge "$MAX_BACKFILL" ]; then
      emit "[cap] reached MAX_BACKFILL=$MAX_BACKFILL — stopping; re-run to continue"
      break
    fi
    if meta tasks.task update --task="$tref" --add-diff="$dnum" >/dev/null 2>&1 \
       && meta phabricator.diff tasks --number="$dnum" 2>/dev/null | grep -q "$tref"; then
      backfilled=$((backfilled+1)); emit "[backfilled] $dnum -> $tref (verified)"
    else
      failed=$((failed+1)); emit "[FAILED] $dnum -> $tref (link or verify failed)"
    fi
  fi
done <<< "$diffs"

emit "[reconcile] done candidates=$candidates backfilled=$backfilled failed=$failed"
# Machine-readable summary line (for a cron wrapper to gate on).
echo "RECONCILE candidates=$candidates backfilled=$backfilled failed=$failed apply=$APPLY"
