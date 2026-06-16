#!/usr/bin/env bash
# cheatsheet-lint-hook.sh — Sapling pretxncommit gate for cheatsheet changes.
#
# Wire-in (~/.config/sapling/sapling.conf):
#   [hooks]
#   pretxncommit.cheatsheet-lint = bash ~/notes/users/dennyzhang/scripts/hooks/cheatsheet-lint-hook.sh
#
# Blocks a commit that introduces a *fixable* cheatsheet regression on the
# files it touches: a new/edited cheatsheet with no "Last updated:" footer, or
# a newly-broken relative markdown link. Size-cap debt is WARN-only (handled by
# the weekly full audit) so editing an already-over-cap file like common.md
# never bricks the 4-hourly auto-push cron.
#
# Delegates to lint-cheatsheets.sh --gate (single source of truth for rules).
# Exit 0 = pass; exit 1 = block. Fail-open on any script bug.
#
# Bypass: add [skip-cheatsheet-lint] to the commit message.
set +e

LINTER="$HOME/notes/users/dennyzhang/scripts/lint/lint-cheatsheets.sh"
CS_PREFIX="users/dennyzhang/cheatsheets/"

[ -f "$LINTER" ] || { echo "WARN: $LINTER missing; skipping cheatsheet gate." >&2; exit 0; }

# Commit message — honor the bypass token.
if [ -n "$HG_NODE" ]; then
  msg=$(sl log -r "$HG_NODE" -T '{desc}' 2>/dev/null)
  files=$(sl log -r "$HG_NODE" -T '{join(files,"\n")}\n' 2>/dev/null)
else
  msg=$(sl log -r . -T '{desc}' 2>/dev/null)
  files=$(sl status -n 2>/dev/null)
fi
case "$msg" in *"[skip-cheatsheet-lint]"*) echo "cheatsheet-lint: bypassed via [skip-cheatsheet-lint]" >&2; exit 0 ;; esac

# Repo-relative cheatsheet .md files in this commit -> absolute paths.
repo_root=$(sl root 2>/dev/null)
mapfile -t changed < <(printf '%s\n' "$files" | grep "^${CS_PREFIX}.*\.md$" | sed "s#^#${repo_root}/#")
[ "${#changed[@]}" -eq 0 ] && exit 0  # nothing relevant in this commit

out=$(bash "$LINTER" --gate "${changed[@]}" 2>&1)
rc=$?
if [ "$rc" -eq 1 ]; then
  echo "$out" >&2
  echo "" >&2
  echo "(blocked by pretxncommit cheatsheet-lint — fix the BLOCK lines, or" >&2
  echo " add [skip-cheatsheet-lint] to the commit message to bypass)" >&2
  exit 1
elif [ "$rc" -ne 0 ]; then
  echo "WARN: lint-cheatsheets.sh --gate rc=$rc; allowing commit." >&2
  exit 0
fi
# rc=0: print any WARN lines (size debt) but don't block.
[ -n "$out" ] && echo "$out" >&2
exit 0
