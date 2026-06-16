#!/usr/bin/env bash
# test-harness.sh — Smoke tests for harness infrastructure.
#
# Validates: hooks fire correctly, cheatsheet rules don't conflict,
# cron outputs are well-formed, scripts have valid syntax.
#
# Run manually or via cron-workflow-regression.sh (weekly).
# Usage: bash scripts/test-harness.sh

set -eo pipefail

REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
PASS=0
FAIL=0
WARNINGS=()

report() {
    local status="$1" test="$2" detail="$3"
    if [ "$status" = "PASS" ]; then
        PASS=$((PASS + 1))
        echo "  PASS  $test"
    else
        FAIL=$((FAIL + 1))
        WARNINGS+=("$test: $detail")
        echo "  FAIL  $test — $detail"
    fi
}

echo "$LOG_PREFIX === Harness Smoke Tests ==="

# ─── Test 1: All cron scripts have valid bash syntax ─────────────────────────
echo ""
echo "[1] Cron script syntax"
for script in "$REPO_DIR"/scripts/cron-*.sh; do
    [ -f "$script" ] || continue
    name=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
        report "PASS" "$name syntax"
    else
        report "FAIL" "$name syntax" "bash -n failed"
    fi
done

# ─── Test 2: All hook scripts have valid bash syntax ─────────────────────────
echo ""
echo "[2] Hook script syntax"
for hook in "$REPO_DIR"/config/hooks/*.sh; do
    [ -f "$hook" ] || continue
    name=$(basename "$hook")
    if bash -n "$hook" 2>/dev/null; then
        report "PASS" "$name syntax"
    else
        report "FAIL" "$name syntax" "bash -n failed"
    fi
done

# ─── Test 3: settings.json is valid JSON ─────────────────────────────────────
echo ""
echo "[3] Settings JSON validity"
for settings in "$REPO_DIR/.claude/settings.json" "$REPO_DIR/.claude/settings.local.json"; do
    [ -f "$settings" ] || continue
    name=$(basename "$settings")
    if python3 -c "import json; json.load(open('$settings'))" 2>/dev/null; then
        report "PASS" "$name valid JSON"
    else
        report "FAIL" "$name valid JSON" "JSON parse error — ALL settings from this file are silently disabled"
    fi
done

# ─── Test 4: Cheatsheet contradictions ───────────────────────────────────────
echo ""
echo "[4] Cheatsheet contradiction check"
# Check for "always use X" vs "never use X" across cheatsheets
contradictions=0
# Note: disable pipefail inside this block — head -20 closing the pipe early
# sends SIGPIPE to upstream greps, which with pipefail on would abort the
# whole harness (silently skipped Tests 5-9 for weeks before 2026-04-20 fix).
set +o pipefail
while IFS= read -r always_rule; do
    keyword=$(echo "$always_rule" | grep -oP '(?<=always use |always run )\S+' | head -1 || true)
    [ -z "$keyword" ] && continue
    if grep -rli "never use $keyword\|never run $keyword\|don't use $keyword" "$REPO_DIR/cheatsheets/" 2>/dev/null | grep -v "$(printf '%.20s' "$always_rule")" >/dev/null 2>&1; then
        contradictions=$((contradictions + 1))
    fi
done < <(grep -rhi "always use \|always run " "$REPO_DIR/cheatsheets/" 2>/dev/null | head -20 || true)
set -o pipefail

if [ "$contradictions" -eq 0 ]; then
    report "PASS" "No cheatsheet contradictions found"
else
    report "FAIL" "Cheatsheet contradictions" "$contradictions potential contradictions"
fi

# ─── Test 5: Cheatsheet size caps ────────────────────────────────────────────
echo ""
echo "[5] Cheatsheet size caps (500 lines)"
oversized=0
while IFS= read -r cs; do
    lines=$(wc -l < "$cs")
    if [ "$lines" -gt 500 ]; then
        report "FAIL" "$(basename $cs) size" "$lines lines (cap: 500)"
        oversized=$((oversized + 1))
    fi
done < <(find "$REPO_DIR/cheatsheets" -name "*.md" 2>/dev/null)
[ "$oversized" -eq 0 ] && report "PASS" "All cheatsheets under 500 lines"

# ─── Test 6: Cron jobs registered in crontab ─────────────────────────────────
echo ""
echo "[6] Cron scripts registered in crontab"
crontab_content=$(crontab -l 2>/dev/null || echo "")
for script in "$REPO_DIR"/scripts/cron-*.sh; do
    [ -f "$script" ] || continue
    name=$(basename "$script" .sh)
    # Skip libraries and test scripts
    [[ "$name" == "cron-alert" || "$name" == "cron-workflow-self-eval" ]] && continue
    if echo "$crontab_content" | grep -q "$name"; then
        report "PASS" "$name in crontab"
    else
        report "FAIL" "$name in crontab" "Script exists but no crontab entry"
    fi
done

# ─── Test 7: Heartbeat freshness ─────────────────────────────────────────────
echo ""
echo "[7] Heartbeat freshness (<48h)"
for hb in /tmp/cron-heartbeat-*; do
    [ -f "$hb" ] || continue
    name=$(basename "$hb" | sed 's/cron-heartbeat-//')
    ts=$(cat "$hb" 2>/dev/null | grep -oE '^[0-9]+$' | head -1 || echo "0")
    [ -z "$ts" ] && ts=0
    age=$(( ($(date +%s) - ts) / 3600 ))
    if [ "$age" -lt 48 ]; then
        report "PASS" "$name heartbeat (${age}h old)"
    else
        report "FAIL" "$name heartbeat" "${age}h old (stale)"
    fi
done

# ─── Test 8: CLAUDE.md loads correctly ───────────────────────────────────────
echo ""
echo "[8] CLAUDE.md integrity"
if [ -f "$REPO_DIR/CLAUDE.md" ]; then
    claude_lines=$(wc -l < "$REPO_DIR/CLAUDE.md")
    if [ "$claude_lines" -lt 50 ]; then
        report "FAIL" "CLAUDE.md" "Only $claude_lines lines — suspiciously short"
    elif [ "$claude_lines" -gt 500 ]; then
        report "FAIL" "CLAUDE.md" "$claude_lines lines — too long, will degrade context"
    else
        report "PASS" "CLAUDE.md ($claude_lines lines)"
    fi
    # Check context canary
    if grep -q "boss" "$REPO_DIR/CLAUDE.md"; then
        report "PASS" "Context canary present"
    else
        report "FAIL" "Context canary" "'boss' canary missing from CLAUDE.md"
    fi
else
    report "FAIL" "CLAUDE.md" "File not found"
fi

# ─── Test 9: cron-ai-health.sh pre-push lint fixtures ────────────────────────
# Guards the four pre-push lints added in commit 4cfe0e1 (and later hardened).
# Each lint: one fixture that SHOULD trigger, one that SHOULD NOT.
# The negatives deliberately include the false-positive cases that have
# caused real cron failures — this test fails loudly if the regex regresses.
echo ""
echo "[9] cron-ai-health.sh pre-push lint fixtures"

lint_test_dir=$(mktemp -d)
trap "rm -rf $lint_test_dir" EXIT

# Fixture A: <th> lint — regex: ['"`]<th[\s>]
# Positive: string-literal emission of <th>
printf 'html += "<th>Hello</th>"\n' > "$lint_test_dir/th_pos.py"
# Negative: docstring prose that references <th> by name (the 2026-04-20 bug)
printf '"""Table headers use <td><b>, not <th>, because Google Docs inherits bold."""\n' > "$lint_test_dir/th_neg.py"

if grep -qP "['\"\`]<th[\s>]" "$lint_test_dir/th_pos.py"; then
    report "PASS" "<th> lint catches emission"
else
    report "FAIL" "<th> lint catches emission" "regex missed real <th> string-literal"
fi
if ! grep -qP "['\"\`]<th[\s>]" "$lint_test_dir/th_neg.py"; then
    report "PASS" "<th> lint ignores prose reference"
else
    report "FAIL" "<th> lint ignores prose reference" "regex false-positives on docstring (2026-04-20 bug)"
fi

# Fixture B: data-col-widths lint — any occurrence is a problem
printf '<table data-col-widths="25,25,25,25"><tr>...</tr></table>\n' > "$lint_test_dir/dcw_pos.html"
printf '<table><tr><td><b>Header</b></td></tr></table>\n' > "$lint_test_dir/dcw_neg.html"
if grep -qc 'data-col-widths' "$lint_test_dir/dcw_pos.html"; then
    report "PASS" "data-col-widths lint catches attribute"
else
    report "FAIL" "data-col-widths lint catches attribute" "did not match <table data-col-widths=...>"
fi
if ! grep -qc 'data-col-widths' "$lint_test_dir/dcw_neg.html"; then
    report "PASS" "data-col-widths lint ignores clean table"
else
    report "FAIL" "data-col-widths lint ignores clean table" "false-positive on vanilla <table>"
fi

# Fixture C: width:100% lint — regex: width:\s*100%
printf '<table style="width: 100%%;"><tr><td>x</td></tr></table>\n' > "$lint_test_dir/w100_pos.html"
printf '<table><tr><td>x</td></tr></table>\n' > "$lint_test_dir/w100_neg.html"
if grep -qP 'width:\s*100%' "$lint_test_dir/w100_pos.html"; then
    report "PASS" "width:100% lint catches stretch style"
else
    report "FAIL" "width:100% lint catches stretch style" "did not match width: 100%"
fi
if ! grep -qP 'width:\s*100%' "$lint_test_dir/w100_neg.html"; then
    report "PASS" "width:100% lint ignores clean table"
else
    report "FAIL" "width:100% lint ignores clean table" "false-positive on vanilla <table>"
fi

# Cross-check: the regexes in this test must match what cron-ai-health.sh actually uses.
# If someone edits the cron's regex, this assertion catches the drift.
cron_script="$REPO_DIR/scripts/cron-ai-health.sh"
if grep -qF "grep -qP \"['\\\"\\\`]<th[\\s>]\"" "$cron_script" 2>/dev/null; then
    report "PASS" "cron-ai-health <th> regex matches test fixture"
else
    report "FAIL" "cron-ai-health <th> regex matches test fixture" "regex in cron-ai-health.sh drifted from test — update test or cron"
fi

# ─── Test 10: Status-grep false-positive guard (not-running pattern) ──────────
# Pattern regression from 2026-04-20: a healthcheck cron used
# `grep -q "running"` which matched BOTH "daemon running (...)" AND
# "daemon not running". Daemon was down for 1.5h because the healthcheck
# always thought it was healthy. Enforce: never free-form match on "running"
# alone when the negative form exists in the same CLI's output.
echo ""
echo "[10] Status-grep false-positive guard"
notrunning_offenders=""
while IFS= read -r hit; do
    file=$(echo "$hit" | cut -d: -f1)
    line=$(echo "$hit" | cut -d: -f2)
    notrunning_offenders="${notrunning_offenders:+$notrunning_offenders, }$(basename "$file"):$line"
done < <(grep -rnE 'grep -q[^E]? "running"|grep -q[^E]? running\b' "$REPO_DIR/scripts/" 2>/dev/null | grep -v "test-harness.sh" || true)
if [ -z "$notrunning_offenders" ]; then
    report "PASS" "No free-form 'grep -q running' false-positive patterns"
else
    report "FAIL" "Free-form 'grep -q running' found" "$notrunning_offenders — use anchored regex like '^<cmd> running \\\\(' or systemctl is-active"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  PASS: $PASS  |  FAIL: $FAIL"
echo "═══════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Failures:"
    for w in "${WARNINGS[@]}"; do
        echo "  - $w"
    done
fi

exit $FAIL
