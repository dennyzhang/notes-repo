#!/usr/bin/env bash
# quality-gate-precheck.sh — Deterministic pre-delivery checks.
#
# Called by PreToolUse hook before delivery actions.
# Replaces the LLM-based quality gate agent with mechanical verification.
#
# Exit 0 = pass (allow delivery), Exit 1 = fail (block delivery).
#
# Usage (from hook): bash ~/work/claude/scripts/quality-gate-precheck.sh "$CLAUDE_TOOL_INPUT"

TOOL_INPUT="${1:-}"

# ── Quick checks (no I/O, run first) ─────────────────────────────────────────

# Block jf publish (draft-only rule)
if echo "$TOOL_INPUT" | grep -qE 'jf publish'; then
    echo "BLOCKED: jf publish is not allowed. Use jf submit --draft."
    exit 1
fi

# Require --draft on jf submit
if echo "$TOOL_INPUT" | grep -qE 'jf submit' && ! echo "$TOOL_INPUT" | grep -qF -- '--draft'; then
    echo "BLOCKED: jf submit must include --draft flag."
    exit 1
fi

# ── Arc lint check (for jf submit | conf submit) ────────────────────────────
# Coverage: every submit pathway across every repo Denny commits to.
#   - jf submit       → fbsource (.py and friends)
#   - conf submit     → configerator (.cinc/.cconf/.mcconf/.thrift; .cinc uses BLACK)
# Add new pathways here when a new repo or submit tool enters the workflow.
if echo "$TOOL_INPUT" | grep -qE 'jf submit|conf submit'; then

    # Find the sapling repo with active changes
    REPO=""
    for candidate in "$HOME/fbsource" "/data/users/$USER/configerator" "$HOME/local/configerator" "$HOME/configerator" "$HOME/www"; do
        if [ -d "$candidate/.sl" ] || [ -d "$candidate/.hg" ] || [ -d "$candidate/.eden" ]; then
            if (cd "$candidate" && sl status 2>/dev/null | grep -q '.'); then
                REPO="$candidate"
                break
            fi
        fi
    done

    if [ -z "$REPO" ]; then
        # No active repo found — skip lint check (already committed or non-code diff)
        exit 0
    fi

    # Snapshot working-copy state, then run arc lint -a (auto-apply autodeps2,
    # formatters, etc.). If lint applies a patch silently, we want to surface
    # it as a BLOCK so the user re-amends instead of submitting stale code.
    pre_lint_status=$(cd "$REPO" && sl status 2>/dev/null)
    lint_output=$(cd "$REPO" && arc lint -a 2>&1)
    post_lint_status=$(cd "$REPO" && sl status 2>/dev/null)

    if [ "$pre_lint_status" != "$post_lint_status" ]; then
        echo "BLOCKED: arc lint -a auto-applied patches (likely AUTODEPS2 BUCK fix or formatter)."
        echo "Re-amend (sl amend) and re-submit."
        echo ""
        diff <(echo "$pre_lint_status") <(echo "$post_lint_status") | head -20
        echo ""
        echo "Lint output:"
        echo "$lint_output" | grep -E '>>>|Error|Warning|Applied' | head -10
        exit 1
    fi

    # Filter out AURORA crashes (phps: not found) — known broken linter
    lint_errors=$(echo "$lint_output" | grep -iE 'error|warning' | grep -vi 'AURORA\|phps.*not found\|No lint engine' | head -20)

    if [ -n "$lint_errors" ]; then
        echo "BLOCKED: arc lint has unresolved issues. Fix before submitting."
        echo ""
        echo "$lint_errors"
        echo ""
        echo "Run: arc lint --apply-patches   (to auto-fix)"
        exit 1
    fi

    # Configerator-specific: require conf build
    if echo "$REPO" | grep -qi "configerator"; then
        build_output=$(cd "$REPO" && timeout 120 conf build 2>&1)
        if echo "$build_output" | grep -qi "fail\|error"; then
            echo "BLOCKED: Configerator diff requires 'conf build' to pass before submit."
            echo ""
            echo "$build_output" | grep -iE "fail|error" | head -10
            echo ""
            echo "Run: cd $REPO && conf build"
            exit 1
        fi
    fi

    # Fbsource-specific: require arc pyre.
    #
    # KNOWN PITFALL: `arc pyre` colors its output with ANSI escape codes, so
    # naive `^fbcode/` anchors silently miss real errors. Also pyre's error
    # lines read `fbcode/foo.py:12:34 Incompatible parameter type [6]: ...` —
    # the word "error" never appears on the line itself, only in the
    # per-target `Type errors in target ...` header.
    #
    # The grep below strips ANSI codes first, then relies on pyre's explicit
    # success marker "No type errors found" OR the `Type errors in target`
    # header that prefixes every failure. This caught the V1 pyre failures
    # on D102248557 and D102275380 that the previous grep pattern silently
    # passed.
    if [ "$REPO" = "$HOME/fbsource" ]; then
        pyre_output=$(cd "$REPO" && timeout 300 arc pyre check-changed-targets 2>&1)
        pyre_stripped=$(echo "$pyre_output" | sed 's/\x1b\[[0-9;]*m//g')
        if echo "$pyre_stripped" | grep -q "No type errors found"; then
            : # clean
        elif echo "$pyre_stripped" | grep -qE "^Type errors in target "; then
            pyre_errors=$(echo "$pyre_stripped" | grep -E "^fbcode/.*\.py:[0-9]+:[0-9]+" | head -10)
            echo "BLOCKED: Pyre type check has errors. Fix before submitting."
            echo ""
            echo "${pyre_errors:-$pyre_stripped}" | head -20
            echo ""
            echo "Run: arc pyre check-changed-targets"
            exit 1
        fi
    fi

    # ── Diff Summary linting (cheatsheet enforcement) ───────────────────────
    # Delegates to lint-diff-summary.sh (single source of truth — same script
    # is wired into the Sapling pretxncommit hook for non-Claude callers).
    if [ -n "$REPO" ]; then
        REPO="$REPO" bash "$HOME/work/claude/scripts/lint-diff-summary.sh"
        rc=$?
        if [ "$rc" -eq 1 ]; then
            exit 1
        elif [ "$rc" -ne 0 ]; then
            echo "WARN: lint-diff-summary.sh rc=$rc (likely script bug); allowing submit."
        fi
    fi

    # Privacy screener reminder — check if diff touches privacy-sensitive paths
    if [ -n "$REPO" ]; then
        privacy_sensitive=$(cd "$REPO" && sl status 2>/dev/null | grep -iE 'privacy|pii|gdpr|data_retention|user_data|personal_info' | head -3)
        if [ -n "$privacy_sensitive" ]; then
            echo "WARNING: This diff touches privacy-sensitive files. Ensure Privacy Safe Land (PSL) pre-screener is attached."
            echo "Files: $privacy_sensitive"
            echo "Run /privacy-sweep to auto-attach if needed."
            # Warning only, not blocking — privacy review is async
        fi
    fi
fi

# ── Bare "checked" lint (tab-writing scripts) ───────────────────────────────
# Status markers must include HH:MM timestamp — bare "checked" without a
# following digit is a generation bug (ROUTINE-DOC-RULES RULE 39).
SCRIPTS_DIR="$HOME/work/claude/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    bare_checked=""
    for f in "$SCRIPTS_DIR"/routine-render.py "$SCRIPTS_DIR"/cron-nightly-routine-preprocessing.sh; do
        [ -f "$f" ] || continue
        hits=$(grep -nP '\bchecked\b(?!\s*[\d$(\{)])' "$f" 2>/dev/null \
            | grep -ivP 'checked=|tc_checked|\$checked|\$\{checked|last_checked|checked_sha|#.*checked|REPLACE_HHMM|sed.*checked|Groups checked' \
            || true)
        if [ -n "$hits" ]; then
            bare_checked="${bare_checked}${f}:\n${hits}\n"
        fi
    done
    if [ -n "$bare_checked" ]; then
        echo "WARNING: Bare 'checked' without HH:MM timestamp found in tab-writing scripts:"
        echo -e "$bare_checked"
        echo "Add a timestamp: 'checked \$(date +%H:%M)' or 'checked {hh:mm}'"
    fi
fi

# ── All checks passed ────────────────────────────────────────────────────────
exit 0
