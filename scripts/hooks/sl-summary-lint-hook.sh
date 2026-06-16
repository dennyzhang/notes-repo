#!/usr/bin/env bash
# sl-summary-lint-hook.sh — Sapling pretxncommit hook for diff-summary linting.
#
# Wire-in (~/.config/sapling/sapling.conf):
#   [hooks]
#   pretxncommit.summary-lint = bash ~/work/claude/scripts/sl-summary-lint-hook.sh
#
# Catches `sl commit` / `sl amend` before the transaction closes,
# regardless of whether the user is in a Claude Code session or a raw
# terminal. Delegates to lint-diff-summary.sh for the actual rule
# checks (single source of truth).
#
# Sapling sets $HG_NODE = new commit hash. We pipe its message into
# the linter via stdin.
#
# Exit 0 = pass; exit 1 = block. Fail-open on script bug.

set +e

REPO="$(pwd)"
LINTER="$HOME/work/claude/scripts/lint-diff-summary.sh"
LINT_LOG="$HOME/work/claude/state/diff-summary-lint.log"
mkdir -p "$(dirname "$LINT_LOG")" 2>/dev/null || true

if [ ! -x "$LINTER" ]; then
    echo "WARN: $LINTER missing or not executable; skipping summary lint." >&2
    exit 0
fi

# Get the in-flight commit message. $HG_NODE is set by Sapling for
# pretxncommit hooks. Fall back to the working-copy parent if not set.
if [ -n "$HG_NODE" ]; then
    msg=$(sl log -r "$HG_NODE" -T '{desc}' 2>/dev/null)
else
    msg=$(sl log -r . -T '{desc}' 2>/dev/null)
fi

if [ -z "$msg" ]; then
    # No message extracted — likely a sl operation without a commit (e.g.,
    # rebase noop). Don't block.
    exit 0
fi

# Pre-compute diff stat to pass via env (avoids the linter re-running sl).
stat=$(sl diff --stat -r '.^' -r . 2>/dev/null)

# Pipe message to linter. Capture output for context if it blocks.
output=$(echo "$msg" | REPO="$REPO" LINT_LOG="$LINT_LOG" STAT_DATA="$stat" \
    bash "$LINTER" 2>&1)
rc=$?

if [ "$rc" -eq 1 ]; then
    echo "$output" >&2
    echo "" >&2
    echo "(blocked by Sapling pretxncommit summary-lint hook —" >&2
    echo " bypass: add [skip-summary-lint] to Summary body, OR" >&2
    echo " disable hook: edit ~/.config/sapling/sapling.conf [hooks] section)" >&2
    exit 1
elif [ "$rc" -ne 0 ]; then
    # Script bug — fail open with a warning.
    echo "WARN: lint-diff-summary.sh rc=$rc; allowing commit." >&2
    echo "$(date -Iseconds) BUG repo=$REPO rc=$rc context=sl-pretxncommit" >> "$LINT_LOG"
fi

exit 0
