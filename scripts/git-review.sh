#!/bin/bash
# git-review.sh — bucketed git diff for easy spot-checking.
#
# Splits changes into SIGNAL (worth reading) and STATE (auto-generated,
# skim only). Passes all args through to `git diff`, so:
#   scripts/git-review.sh                     # working tree vs HEAD
#   scripts/git-review.sh --staged            # staged
#   scripts/git-review.sh HEAD~5..HEAD        # last 5 commits
#   scripts/git-review.sh main..HEAD          # branch diff
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

STATE_REGEX='^(HANDOFF|ALERTS|TASK-LOG|FOLLOWUPS|TASKS)\.md$'
STATE_REGEX+='|^context/(STATE|CONTEXT|HANDOFF|IMPACT|LOCAL-TASKS|CONTEXT-FAILURES)\.md$'
STATE_REGEX+='|^context/cache/'
STATE_REGEX+='|^context/myself/PATTERNS\.md$'
STATE_REGEX+='|^projects/.*/SIGNALS\.md$'
STATE_REGEX+='|^projects/_health-cache\.json$'
STATE_REGEX+='|^projects/_registry\.json$'
STATE_REGEX+='|^config/SHARED-DOC-SCANNER\.json$'
STATE_REGEX+='|^memory/MEMORY\.md$'

CHANGED=$(git diff --name-only "$@")
if [[ -z "$CHANGED" ]]; then
  echo "No changes."
  exit 0
fi

SIGNAL_FILES=()
STATE_FILES=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ "$f" =~ $STATE_REGEX ]]; then
    STATE_FILES+=("$f")
  else
    SIGNAL_FILES+=("$f")
  fi
done <<< "$CHANGED"

bar() { printf '%.0s=' {1..64}; echo; }

bar
printf '  SIGNAL  (%d files — review these)\n' "${#SIGNAL_FILES[@]}"
bar
if (( ${#SIGNAL_FILES[@]} > 0 )); then
  git diff --stat "$@" -- "${SIGNAL_FILES[@]}"
  echo
  git --no-pager diff "$@" -- "${SIGNAL_FILES[@]}"
else
  echo "  (none)"
fi

echo
bar
printf '  STATE   (%d files — auto-generated, skim only)\n' "${#STATE_FILES[@]}"
bar
if (( ${#STATE_FILES[@]} > 0 )); then
  git diff --stat "$@" -- "${STATE_FILES[@]}"
  echo
  echo "To inspect: git diff $* -- ${STATE_FILES[*]}"
else
  echo "  (none)"
fi
