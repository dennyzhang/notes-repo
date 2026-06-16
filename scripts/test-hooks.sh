#!/bin/bash
# test-hooks.sh — fixture-based smoke tests for hook scripts and rendered settings.
# Run before render-hooks.sh in a CI loop. Tests live in scripts/test-hooks.fixtures.tsv.
# Usage: bash scripts/test-hooks.sh [--verbose]

set -uo pipefail

CLAUDE_DIR="$HOME/work/claude"
VERBOSE=${1:-}
PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
    local name="$1"
    local cmd="$2"
    local expected_rc="$3"
    local expected_substring="${4:-}"

    local actual_out actual_rc
    actual_out=$(eval "$cmd" 2>&1) || true
    actual_rc=$?

    local ok=1
    if [ "$actual_rc" != "$expected_rc" ]; then ok=0; fi
    if [ -n "$expected_substring" ] && ! echo "$actual_out" | grep -qF "$expected_substring"; then ok=0; fi

    if [ "$ok" -eq 1 ]; then
        PASS=$((PASS + 1))
        [ "$VERBOSE" = "--verbose" ] && echo "  PASS: $name"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$name (rc=$actual_rc expected=$expected_rc out=${actual_out:0:120})")
    fi
}

echo "=== test-hooks.sh — running ==="

# --- 1. settings.json validity ---
run_test "settings.json is valid JSON" \
    "/usr/bin/python3 -m json.tool $CLAUDE_DIR/.claude/settings.json > /dev/null" 0

# --- 2. lint-settings passes ---
run_test "lint-settings.sh passes" \
    "bash $CLAUDE_DIR/scripts/lint-settings.sh" 0 "OK:"

# --- 3. render-hooks dry-run produces JSON ---
run_test "render-hooks --dry-run succeeds" \
    "bash $CLAUDE_DIR/scripts/render-hooks.sh --dry-run" 0 "DRY RUN"

# --- 4. _lib.sh sources without error ---
run_test "_lib.sh sources cleanly" \
    "bash -c 'source $CLAUDE_DIR/config/hooks/_lib.sh && type hook_log >/dev/null'" 0

# --- 5. hooks.yaml is valid YAML ---
run_test "hooks.yaml parses" \
    "/usr/bin/python3 -c 'import yaml; yaml.safe_load(open(\"$CLAUDE_DIR/config/hooks.yaml\"))'" 0

# --- 6. all hook scripts exist ---
for s in $(/usr/bin/python3 -c "
import yaml
cfg = yaml.safe_load(open('$CLAUDE_DIR/config/hooks.yaml'))
for ev in cfg.values():
    for r in ev:
        if r.get('type') == 'script':
            print(r['script'])
" 2>/dev/null | sort -u); do
    run_test "script exists: $s" "[ -f $CLAUDE_DIR/$s ]" 0
done

# --- 7. block-stacked-commit blocks `git commit` (sample) ---
if [ -f "$CLAUDE_DIR/scripts/block-stacked-commit.sh" ]; then
    run_test "block-stacked-commit accepts safe input" \
        "bash $CLAUDE_DIR/scripts/block-stacked-commit.sh 'ls -la'" 0
fi

# --- Summary ---
echo
echo "=== Summary: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
    echo "FAILURES:"
    for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
    exit 1
fi
exit 0
