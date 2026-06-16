#!/usr/bin/env bash
# block-stacked-commit.sh — PreToolUse hook for sl/hg commit.
#
# Blocks `sl commit` when the current commit (.) is a draft, which would
# auto-stack the new commit on an unrelated draft and create an unwanted
# Phabricator "Depends On" link in jf submit. See cheatsheets/diff/common.md:9
# and 138-148 for the rule this enforces.
#
# Pass --allow-stack as a top-level argument (NOT inside -m) to bypass when a
# real code dependency makes stacking correct.
#
# Exit 0 = allow, Exit 1 = block (stderr message becomes the block reason).
#
# Usage (from hook): bash ~/work/claude/scripts/block-stacked-commit.sh "$CLAUDE_TOOL_INPUT"

TOOL_INPUT="${1:-}"

# Strip -m '...' / -m "..." / --message '...' blocks BEFORE any pattern match
# so commit messages can't trigger or bypass detection.
SCRUBBED=$(printf '%s' "$TOOL_INPUT" \
    | sed -E "s/-m[[:space:]]+'[^']*'//g; s/-m[[:space:]]+\"[^\"]*\"//g" \
    | sed -E "s/--message[[:space:]]+'[^']*'//g; s/--message[[:space:]]+\"[^\"]*\"//g")

# Only fire on commit-creating commands. Covers sl/hg + commit/ci alias.
# \s+ tolerates multiple spaces. hg is aliased to sl per Meta convention.
echo "$SCRUBBED" | grep -qE '\b(sl|hg)\s+(commit|ci)\b' || exit 0
# Amend modifies the existing commit — no new stacking
echo "$SCRUBBED" | grep -qE '\b(sl|hg)\s+amend\b|--amend\b' && exit 0
# Escape hatch: must appear OUTSIDE -m (we already scrubbed -m blocks)
echo "$SCRUBBED" | grep -qE '(^|\s)--allow-stack(\s|$)' && exit 0

# Find the active sapling repo with pending changes
# (clean repo => no commit possible from it, so skip)
REPO=""
for candidate in "$HOME/fbsource" "/data/users/$USER/configerator" "$HOME/local/configerator" "$HOME/configerator" "$HOME/www"; do
    if [ -d "$candidate/.sl" ] || [ -d "$candidate/.hg" ] || [ -d "$candidate/.eden" ]; then
        if (cd "$candidate" && sl status 2>/dev/null | grep -q '.'); then
            REPO="$candidate"
            break
        fi
    fi
done

# No dirty repo found — let sl/hg handle it (will no-op anyway)
[ -z "$REPO" ] && exit 0

# Read phase of `.`. "draft" = unlanded; "public" = on trunk.
phase=$(cd "$REPO" && sl log -r . -T '{phase}' --reason "check phase before commit - sl help log" 2>/dev/null)

if [ "$phase" = "draft" ]; then
    parent_info=$(cd "$REPO" && sl log -r . -T '{node|short} {phabdiff} {desc|firstline}' --reason "report stacked parent - sl help log" 2>/dev/null)
    cat <<EOF >&2
BLOCKED: sl/hg commit would stack on a draft.

Repo:           $REPO
Current commit: $parent_info

Stacking creates a Phabricator "Depends On" link that's painful to remove later
(rebase + jf submit + meta phabricator.diff remove-dependency). See
~/work/claude/cheatsheets/diff/common.md:9, 138-148.

To proceed:
  1. Standalone diff (default): cd $REPO && sl goto remote/master --reason "..."
     then redo the commit.
  2. Intentional stacking (real code dep): re-run with --allow-stack.
EOF
    exit 1
fi

exit 0
