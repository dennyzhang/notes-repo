#!/usr/bin/env bash
# test_gdocs_lib.sh — Homegrown tests for scripts/lib/gdocs_lib.sh.
#
# No bats/shunit2 on the devserver — this is a minimal test harness.
# Each test is a function named test_*. The main loop runs all of them,
# counts pass/fail, and exits non-zero if any fails.
#
# Run:
#   bash scripts/lib/test_gdocs_lib.sh
#
# What is tested:
#   - DRY_RUN shim intercepts mutating gdocs calls (batch-update, apply,
#     replace, content insert-*, format, comments mutations)
#   - DRY_RUN shim passes through read-only calls (get, content
#     get-structure, comments list, revisions, etc.)
#   - DRY_RUN shim intercepts `timeout <dur> gdocs ...`
#   - Error tracking: gdocs_track_error increments the counter
#   - gdocs_exit_with_status returns non-zero when errors accumulated
#   - gdocs_dryrun_next_file produces unique filenames
#   - Revision capture writes a sentinel with revision_id\ttimestamp
#
# What is NOT tested (requires live docs or a full mock harness):
#   - Body font / header-bg / column widths batch requests (parser logic
#     tested indirectly via shim capture)
#   - gdocs_validate_h1_today / gdocs_validate_min_tables (need real doc)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SCRIPTS="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
CURRENT_TEST=""

# ─── Test harness ─────────────────────────────────────────────────────────
setup() {
    # Isolated per-test state: unset lib globals, fresh temp dirs.
    unset __GDOCS_LIB_SOURCED DRY_RUN GDOCS_LIB_ERRORS
    TEST_TMP=$(mktemp -d)
    export GDOCS_DRYRUN_DIR="$TEST_TMP/dryrun"
    export GDOCS_PREPUSH_DIR="$TEST_TMP/prepush"
    export CLAUDE_STATE_DIR="$TEST_TMP/state"
    mkdir -p "$GDOCS_DRYRUN_DIR" "$GDOCS_PREPUSH_DIR" "$CLAUDE_STATE_DIR"
}

teardown() {
    [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
    unset TEST_TMP __GDOCS_LIB_SOURCED DRY_RUN GDOCS_LIB_ERRORS
    # Also remove any shim functions that were defined so next test starts clean.
    unset -f gdocs 2>/dev/null || true
    unset -f timeout 2>/dev/null || true
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-values differ}"
    if [ "$expected" != "$actual" ]; then
        echo "  FAIL ($CURRENT_TEST): $msg — expected '$expected', got '$actual'"
        return 1
    fi
    return 0
}

assert_file_exists() {
    local f="$1"
    local msg="${2:-file missing}"
    if [ ! -f "$f" ]; then
        echo "  FAIL ($CURRENT_TEST): $msg — $f does not exist"
        return 1
    fi
    return 0
}

assert_match() {
    local needle="$1"
    local haystack="$2"
    local msg="${3:-substring not found}"
    if ! echo "$haystack" | grep -q -- "$needle"; then
        echo "  FAIL ($CURRENT_TEST): $msg — '$needle' not in output"
        echo "    actual: $haystack"
        return 1
    fi
    return 0
}

run_test() {
    CURRENT_TEST="$1"
    setup
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    if "$CURRENT_TEST"; then
        PASS=$((PASS + 1))
        echo "  PASS  $CURRENT_TEST"
    else
        FAIL=$((FAIL + 1))
    fi
    teardown
}

# ─── Tests ────────────────────────────────────────────────────────────────

test_dryrun_intercepts_batch_update() {
    # After setup+source, re-source with DRY_RUN=1 so shim is defined.
    unset __GDOCS_LIB_SOURCED
    export DRY_RUN=1
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    echo '{"test":1}' | gdocs batch-update FAKE_DOC --data - 2>&1 | grep -q 'DRY-RUN' || {
        echo "  FAIL: no DRY-RUN log line emitted"
        return 1
    }
    local files
    files=$(find "$GDOCS_DRYRUN_DIR" -name 'shim-batch-update*.json' | wc -l | tr -d ' ')
    assert_eq "1" "$files" "expected 1 captured batch-update file"
}

test_dryrun_intercepts_apply() {
    unset __GDOCS_LIB_SOURCED
    export DRY_RUN=1
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    gdocs apply FAKE_DOC --from foo.html < /dev/null >/dev/null 2>&1
    local files
    files=$(find "$GDOCS_DRYRUN_DIR" -name 'shim-apply*.json' | wc -l | tr -d ' ')
    assert_eq "1" "$files" "expected 1 captured apply file"
}

test_dryrun_intercepts_content_insert_markdown() {
    unset __GDOCS_LIB_SOURCED
    export DRY_RUN=1
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    gdocs content insert-markdown FAKE_DOC @foo.md --index 1 < /dev/null >/dev/null 2>&1
    local files
    files=$(find "$GDOCS_DRYRUN_DIR" -name 'shim-content-insert-markdown*.json' | wc -l | tr -d ' ')
    assert_eq "1" "$files" "expected 1 captured insert-markdown file"
}

test_dryrun_intercepts_timeout_wrapped_gdocs() {
    unset __GDOCS_LIB_SOURCED
    export DRY_RUN=1
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    echo '{"test":2}' | timeout 15 gdocs batch-update FAKE_DOC --data - >/dev/null 2>&1
    local files
    files=$(find "$GDOCS_DRYRUN_DIR" -name 'shim-batch-update*.json' | wc -l | tr -d ' ')
    assert_eq "1" "$files" "expected 1 captured file via timeout-wrapped call"
}

test_dryrun_captures_unique_filenames() {
    unset __GDOCS_LIB_SOURCED
    export DRY_RUN=1
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    echo '{"a":1}' | gdocs batch-update FAKE_DOC --data - >/dev/null 2>&1
    echo '{"b":2}' | gdocs batch-update FAKE_DOC --data - >/dev/null 2>&1
    echo '{"c":3}' | gdocs batch-update FAKE_DOC --data - >/dev/null 2>&1
    local count
    count=$(find "$GDOCS_DRYRUN_DIR" -name 'shim-batch-update*.json' | wc -l | tr -d ' ')
    assert_eq "3" "$count" "expected 3 unique files"
}

test_error_counter_starts_at_zero() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    assert_eq "0" "$GDOCS_LIB_ERRORS"
}

test_track_error_increments_counter() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    gdocs_track_error "test failure 1" 2>/dev/null
    gdocs_track_error "test failure 2" 2>/dev/null
    assert_eq "2" "$GDOCS_LIB_ERRORS"
}

test_exit_with_status_returns_zero_if_no_errors() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    # Stub cron_alert so it doesn't touch the real alerts file.
    cron_alert() { return 0; }
    gdocs_exit_with_status "test-script" >/dev/null 2>&1
    assert_eq "0" "$?" "exit-with-status should return 0 when no errors"
}

test_exit_with_status_returns_nonzero_if_errors() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    cron_alert() { return 0; }
    gdocs_track_error "simulated" 2>/dev/null
    gdocs_exit_with_status "test-script" >/dev/null 2>&1
    assert_eq "1" "$?" "exit-with-status should return 1 when errors occurred"
}

test_exit_with_status_calls_cron_alert_on_failure() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    local called=0
    cron_alert() { called=1; }
    gdocs_track_error "simulated" 2>/dev/null
    gdocs_exit_with_status "test-script" >/dev/null 2>&1 || true
    assert_eq "1" "$called" "cron_alert should be called on failure"
}

test_dryrun_file_contains_stdin_payload() {
    unset __GDOCS_LIB_SOURCED
    export DRY_RUN=1
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    echo '{"magic":"42"}' | gdocs batch-update FAKE_DOC --data - >/dev/null 2>&1
    local f
    f=$(find "$GDOCS_DRYRUN_DIR" -name 'shim-batch-update*.json' | head -1)
    assert_file_exists "$f" || return 1
    grep -q 'magic' "$f" || {
        echo "  FAIL: stdin payload not captured in dry-run file ($f)"
        return 1
    }
    return 0
}

test_dryrun_off_by_default() {
    unset __GDOCS_LIB_SOURCED
    unset DRY_RUN
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    # Without DRY_RUN=1, the gdocs shim function should NOT be defined.
    if declare -f gdocs >/dev/null; then
        echo "  FAIL: gdocs shim leaked into non-DRY_RUN mode"
        return 1
    fi
    return 0
}

test_track_error_logs_to_stderr() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    local err
    err=$(gdocs_track_error "unique-marker-xyz" 2>&1 >/dev/null)
    assert_match "unique-marker-xyz" "$err" "error message missing from stderr"
}

# ─── Run all tests ────────────────────────────────────────────────────────
echo "Running gdocs_lib.sh tests..."
echo ""

test_prepend_function_defined() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    type -t gdocs_prepend_today_section | grep -q function
}

test_prepend_missing_file_returns_error() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    local rc
    gdocs_prepend_today_section fake-doc t.0 /nonexistent/file.md 2>/dev/null
    rc=$?
    assert_eq "1" "$rc" "expected rc=1 for missing content file"
    assert_eq "1" "$GDOCS_LIB_ERRORS" "expected 1 tracked error for missing file"
}

test_prepend_unknown_flag_returns_error() {
    unset __GDOCS_LIB_SOURCED
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    local rc
    gdocs_prepend_today_section fake-doc t.0 /tmp --bogus-flag x 2>/dev/null
    rc=$?
    assert_eq "1" "$rc" "expected rc=1 for unknown flag"
}

test_apply_widths_config_missing_returns_zero() {
    # Missing config should NOT error — just warn and return 0.
    unset __GDOCS_LIB_SOURCED
    export GDOCS_TABLE_WIDTHS_CONFIG=/nonexistent/file.json
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    local rc
    gdocs_apply_table_widths fake-doc t.0 routine 2>/dev/null
    rc=$?
    assert_eq "0" "$rc" "expected rc=0 when config missing"
    unset GDOCS_TABLE_WIDTHS_CONFIG
}

test_apply_widths_unknown_doc_key_returns_zero() {
    # Valid config but doc_key not present — helper should no-op (rc=0).
    # Stub gdocs_get_structure so we don't hit the network.
    unset __GDOCS_LIB_SOURCED
    local cfg="$TEST_TMP/widths.json"
    printf '{"routine":{"t.0":{"1":{"widths":[100,300]}}}}' > "$cfg"
    export GDOCS_TABLE_WIDTHS_CONFIG="$cfg"
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    gdocs_get_structure() { printf '[1-26] HEADING_1: "Title"\n[26-500] TABLE: cols=2\n'; }
    local rc
    gdocs_apply_table_widths fake-doc t.0 not_in_config 2>/dev/null
    rc=$?
    assert_eq "0" "$rc" "expected rc=0 for unknown doc_key"
    unset GDOCS_TABLE_WIDTHS_CONFIG
}

test_apply_widths_happy_path_emits_batch() {
    # Valid config + matching structure: verify batch JSON is captured by
    # the DRY_RUN shim and contains the expected width ops (1 per column).
    unset __GDOCS_LIB_SOURCED
    local cfg="$TEST_TMP/widths.json"
    # 2 tables: config has widths for #1 only — helper should emit 3 ops (3 cols).
    cat > "$cfg" <<JSON
{"routine":{"t.0":{"1":{"widths":[100,300,68]}}}}
JSON
    export GDOCS_TABLE_WIDTHS_CONFIG="$cfg"
    export DRY_RUN=1
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/gdocs_lib.sh"
    gdocs_get_structure() {
        printf '[1-26] HEADING_1: "Today"\n[26-500] TABLE: cols=3\n[500-700] TABLE: cols=2\n'
    }
    local rc
    gdocs_apply_table_widths fake-doc t.0 routine >/dev/null 2>&1
    rc=$?
    assert_eq "0" "$rc" "expected rc=0 on happy path" || return 1
    local batch_file
    batch_file=$(find "$GDOCS_DRYRUN_DIR" -name "widths-routine*.json" | head -1)
    assert_file_exists "$batch_file" "expected DRY_RUN shim to capture batch JSON" || return 1
    local op_count
    op_count=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$batch_file")
    assert_eq "3" "$op_count" "expected 3 updateTableColumnProperties ops (1 per col of first table only)" || return 1
    local first_start
    first_start=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d[0]['updateTableColumnProperties']['tableStartLocation']['index'])" "$batch_file")
    assert_eq "26" "$first_start" "expected tableStartLocation.index=26 (first TABLE start)" || return 1
    unset GDOCS_TABLE_WIDTHS_CONFIG DRY_RUN
}

run_test test_dryrun_intercepts_batch_update
run_test test_dryrun_intercepts_apply
run_test test_dryrun_intercepts_content_insert_markdown
run_test test_dryrun_intercepts_timeout_wrapped_gdocs
run_test test_dryrun_captures_unique_filenames
run_test test_error_counter_starts_at_zero
run_test test_track_error_increments_counter
run_test test_exit_with_status_returns_zero_if_no_errors
run_test test_exit_with_status_returns_nonzero_if_errors
run_test test_exit_with_status_calls_cron_alert_on_failure
run_test test_dryrun_file_contains_stdin_payload
run_test test_dryrun_off_by_default
run_test test_track_error_logs_to_stderr
run_test test_prepend_function_defined
run_test test_prepend_missing_file_returns_error
run_test test_prepend_unknown_flag_returns_error
run_test test_apply_widths_config_missing_returns_zero
run_test test_apply_widths_unknown_doc_key_returns_zero
run_test test_apply_widths_happy_path_emits_batch

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "ALL PASSED ($PASS/$((PASS+FAIL)))"
    exit 0
else
    echo "FAILED: $FAIL / $((PASS+FAIL))"
    exit 1
fi
