#!/usr/bin/env bash
# lint-diff-summary.sh — Standalone diff-summary linter.
#
# Reads a commit message from stdin (or via $1 = sl revision spec) and
# applies the cheatsheet rules at ~/work/claude/cheatsheets/diff/common.md.
# Exits 0 = pass, exit 1 = block with rule violated, exit 2 = script bug
# (caller should fail-open).
#
# Callers:
#   - quality-gate-precheck.sh (PreToolUse on jf submit)
#   - sl-summary-lint-hook.sh  (Sapling pretxncommit hook)
#   - /diff-summary-lint slash command (manual)
#
# Usage:
#   echo "$commit_msg" | bash lint-diff-summary.sh
#   bash lint-diff-summary.sh <sl-revision>
#   bash lint-diff-summary.sh   (defaults to working-copy parent: .)
#
# Environment:
#   REPO       repo path (default: $(pwd))
#   LINT_LOG   audit log path (default: ~/work/claude/state/diff-summary-lint.log)
#   STAT_DATA  optional pre-computed `sl diff --stat` output (skips re-run)

set +e  # fail-open on internal errors

REPO="${REPO:-$(pwd)}"
LINT_LOG="${LINT_LOG:-$HOME/work/claude/state/diff-summary-lint.log}"
mkdir -p "$(dirname "$LINT_LOG")" 2>/dev/null || true

# Source: stdin if not a tty, else sl log -r <arg>
if [ -p /dev/stdin ] || ! [ -t 0 ]; then
    commit_msg=$(cat)
else
    rev="${1:-.}"
    commit_msg=$(cd "$REPO" && sl log -r "$rev" -T '{desc}' 2>/dev/null)
fi

if [ -z "$commit_msg" ]; then
    echo "WARN: empty commit message; skipping summary lint." >&2
    echo "$(date -Iseconds) WARN repo=$REPO reason=empty-message" >> "$LINT_LOG"
    exit 0
fi

# Honor explicit escape hatch.
if echo "$commit_msg" | grep -qE '\[skip-summary-lint\]'; then
    echo "$(date -Iseconds) SKIP repo=$REPO reason=escape-hatch" >> "$LINT_LOG"
    exit 0
fi

# Extract Summary body — between Summary: line and next standard section.
summary_body=$(echo "$commit_msg" | awk '
    /^Summary:/{flag=1; next}
    /^(Test Plan|Reviewers|Tags|Subscribers|Tasks|Differential Revision|reviewed by):/{flag=0}
    flag {print}
')

# Strip code spans so D/P checks don't flag CLI examples inside backticks.
summary_no_code=$(echo "$summary_body" | python3 -c "
import re, sys
t = sys.stdin.read()
t = re.sub(r'\x60{3}.*?\x60{3}', '', t, flags=re.DOTALL)
t = re.sub(r'\x60[^\x60\n]*\x60', '', t)
sys.stdout.write(t)
" 2>/dev/null)
[ -n "$summary_no_code" ] || summary_no_code="$summary_body"

# Missing Summary section — warn but don't block.
if [ -z "$summary_body" ]; then
    echo "WARN: commit has no 'Summary:' section." >&2
    echo "$(date -Iseconds) WARN repo=$REPO reason=no-summary" >> "$LINT_LOG"
    exit 0
fi

words=$(echo "$summary_body" | wc -w)

# ── Scope detection ──
stat_output="${STAT_DATA:-$(cd "$REPO" && sl diff --stat -r '.^' -r . 2>/dev/null)}"
lines_changed=$(echo "$stat_output" | tail -1 | grep -oE '[0-9]+ insertions' \
    | head -1 | grep -oE '[0-9]+' | head -1)
lines_changed=${lines_changed:-0}
non_doc=$(echo "$stat_output" \
    | grep -E '\|.*[+-]' \
    | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' \
    | grep -vE '\.(md|rst|txt|yaml|cconf|cinc)$' | head -1)

if [ -z "$non_doc" ] && [ "$lines_changed" -le 50 ]; then
    cap=60; cap_label="doc/config-only ≤50 lines"
elif [ "$lines_changed" -le 150 ]; then
    cap=120; cap_label="code change ≤150 lines"
else
    cap=300; cap_label="larger / refactor / feature"
fi

_block() {
    local rule="$1"; shift
    echo "BLOCKED: $*"
    echo "  See: ~/work/claude/cheatsheets/diff/common.md § Summary Writing"
    echo "  Bypass: add [skip-summary-lint] to Summary body (logged for audit)."
    echo "$(date -Iseconds) BLOCK repo=$REPO rule=$rule" >> "$LINT_LOG"
    exit 1
}

# ── Word count ──
if [ "$words" -gt "$cap" ]; then
    echo "BLOCKED: Diff summary has $words words; cap is $cap ($cap_label)."
    echo "  Fix template (3-line Why/Fix/Scope):"
    echo "    Summary:"
    echo "    - **Why**: <broken state OR missing capability; cite SEV/post URL>"
    echo "    - **Fix**: <smallest description of new behavior; one sentence>"
    echo "    - **Scope**: <non-obvious cross-cutting impact; skip if purely additive>"
    echo "  Bypass: add [skip-summary-lint] to Summary body (logged for audit)."
    echo "$(date -Iseconds) BLOCK repo=$REPO rule=word-count words=$words cap=$cap" >> "$LINT_LOG"
    exit 1
fi

# ── Stack lineage line (case-insensitive) ──
if echo "$summary_body" | grep -qiE '^[[:space:]]*stack[[:space:]]*:.*[→D-]'; then
    _block "stack-line" "Summary contains 'Stack:' lineage line (Phabricator renders this automatically)."
fi

# ── 'Source incident:' repeated >1 ──
inc_count=$(echo "$summary_body" | grep -cE 'Source incident:')
inc_count=${inc_count:-0}
if [ "$inc_count" -gt 1 ]; then
    _block "source-incident-repeat" "'Source incident:' appears $inc_count× in Summary; cite once at top."
fi

# ── Numbered tour (3+ lines mirror diff structure) ──
tour_count=$(echo "$summary_body" | grep -cE '^[0-9]+\.\s')
tour_count=${tour_count:-0}
if [ "$tour_count" -ge 3 ]; then
    _block "numbered-tour" "Summary contains a numbered tour ($tour_count '^N.' lines mirroring the diff structure)."
fi

# ── Bare D/P numbers (after stripping code spans) ──
bare_d=$(echo "$summary_no_code" | grep -oE '(^|[^/[(])\bD[0-9]{6,}\b' \
    | grep -vE 'https://|Differential Revision' | head -1)
bare_p=$(echo "$summary_no_code" | grep -oE '(^|[^/[(])\bP[0-9]{7,}\b' \
    | grep -vE 'https://' | head -1)
if [ -n "$bare_d" ] || [ -n "$bare_p" ]; then
    _block "bare-d-p" "Summary contains bare D/P numbers without URL: ${bare_d:-$bare_p}"
fi

# ── What-not-why opening (skip if Why/Fix/Scope template) ──
if echo "$summary_body" | head -3 | grep -qiE '^[[:space:]]*[-*]?\s*\*\*Why\*\*:|^[[:space:]]*Why:'; then
    : # template form — skip
else
    opening=$(echo "$summary_body" | sed -n '/[A-Za-z]/{p;q}' | head -c 30)
    if echo "$opening" | grep -qiE '^(This diff|This file|New |Adds |Adding )'; then
        _block "what-not-why" "Summary opens with what-not-why: '$opening...'"
    fi
fi

echo "$(date -Iseconds) PASS repo=$REPO words=$words cap=$cap" >> "$LINT_LOG"
exit 0
