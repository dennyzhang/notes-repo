#!/usr/bin/env bash
# precommit-cron-checks.sh — Quality gates for scripts/cron-*.sh and scripts/lib/*.sh.
#
# Invoked by .git/hooks/pre-commit with a list of changed cron/lib files. Also
# runnable manually:  bash scripts/lib/precommit-cron-checks.sh <files...>
#
# Checks (each file must pass ALL):
#   1. Bash syntax             — bash -n
#   2. Shellcheck errors       — shellcheck --severity=error
#   3. No silent swallowers    — `gdocs <mutating> ... || true` is forbidden
#
# Exit code: 0 = all pass, 1 = at least one file failed.
#
# Note: a full `DRY_RUN=1 bash <script>` gate is NOT part of pre-commit
# because cron scripts make LLM calls, external API calls, and lock writes
# that shouldn't fire during a commit. DRY_RUN=1 remains a manual testing
# tool — run it locally before staging a risky change:
#   DRY_RUN=1 bash scripts/cron-area-monitor.sh 2>&1 | tail -30
#   ls /tmp/gdocs-dryrun-*/   # captured batch-update JSON
#
# Bypass (only when intentional and documented): git commit --no-verify

set -u

RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
GREEN=$'\033[0;32m'
DIM=$'\033[2m'
NC=$'\033[0m'

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <file1.sh> [<file2.sh> ...]" >&2
    exit 0
fi

fail=0
total=0
for f in "$@"; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    total=$((total + 1))

    # Bash-specific checks — skip for non-.sh files.
    case "$f" in
        *.sh)
            # 1. Bash syntax
            if ! bash -n "$f" 2>/tmp/precommit-syntax-err; then
                echo "${RED}[FAIL] syntax:${NC} $f"
                sed 's/^/  /' /tmp/precommit-syntax-err
                fail=1
                continue
            fi

            # 2. Shellcheck errors (severity=error only)
            if command -v shellcheck >/dev/null; then
                if ! shellcheck --severity=error --external-sources "$f" >/tmp/precommit-shellcheck-err 2>&1; then
                    echo "${RED}[FAIL] shellcheck:${NC} $f"
                    head -20 /tmp/precommit-shellcheck-err | sed 's/^/  /'
                    fail=1
                    continue
                fi
            fi

            # 3. Silent mutating-command swallowers
            if grep -nE 'gdocs (batch-update|apply|replace|content (insert|find-replace))[^|]*\|\| true' "$f" >/tmp/precommit-swallow-err 2>/dev/null; then
                if [ -s /tmp/precommit-swallow-err ]; then
                    echo "${RED}[FAIL] silent-swallower:${NC} $f"
                    head -5 /tmp/precommit-swallow-err | sed 's/^/  /'
                    echo "  ${YELLOW}Fix:${NC} replace \`|| true\` with \`|| echo \"[ERROR] ... at \$0:\$LINENO\" >&2\`"
                    fail=1
                    continue
                fi
            fi
            ;;
        *.py)
            # Python syntax check via ast.parse.
            if ! python3 -c "import ast,sys; ast.parse(open('$f').read())" 2>/tmp/precommit-syntax-err; then
                echo "${RED}[FAIL] python syntax:${NC} $f"
                sed 's/^/  /' /tmp/precommit-syntax-err
                fail=1
                continue
            fi
            ;;
    esac

done

# Test-runner triggers.
#
# Bash tests run when test_gdocs_lib.sh itself or the lib it tests is staged.
# Python tests: ANY staged scripts/*.py or scripts/lib/*.py file triggers the
# full Python test suite. Tests are fast (~1s total) and guardrail every new
# Python change — users were burned by untested .py files before (see #3 in
# 2026-04-18 retro). Find every scripts/lib/test_*.py and run them all.
ran_bash_tests=0
ran_py_tests=0
staged_has_python=0
for f in "$@"; do
    case "$f" in
        */lib/gdocs_lib.sh|*/lib/test_gdocs_lib.sh)
            if [ "$ran_bash_tests" = "0" ]; then
                ran_bash_tests=1
                test_runner="$(dirname "$f")/test_gdocs_lib.sh"
                if [ -f "$test_runner" ]; then
                    if ! bash "$test_runner" >/tmp/precommit-test-out 2>&1; then
                        echo "${RED}[FAIL] gdocs_lib.sh tests:${NC}"
                        tail -20 /tmp/precommit-test-out | sed 's/^/  /'
                        fail=1
                    else
                        echo "${DIM}  bash tests OK:${NC} $test_runner"
                    fi
                fi
            fi
            ;;
        *.py)
            staged_has_python=1
            ;;
    esac
done

# Run ALL Python tests if any .py was staged.
if [ "$staged_has_python" = "1" ] && [ "$ran_py_tests" = "0" ]; then
    ran_py_tests=1
    # Python scripts live in ~/work/claude/private_scripts (fb:notes refuses .py).
    test_files=$(find "$HOME/work/claude/private_scripts" -name 'test_*.py' -type f 2>/dev/null)
    if [ -n "$test_files" ]; then
        py_fail=0
        while IFS= read -r t; do
            [ -z "$t" ] && continue
            if ! python3 "$t" >/tmp/precommit-pytest-out 2>&1; then
                echo "${RED}[FAIL] python tests: $t${NC}"
                tail -20 /tmp/precommit-pytest-out | sed 's/^/  /'
                fail=1
                py_fail=1
            fi
        done <<< "$test_files"
        if [ "$py_fail" = "0" ]; then
            tcount=$(echo "$test_files" | grep -c .)
            echo "${DIM}  python tests OK (${tcount} suite(s))${NC}"
        fi
    fi
fi

rm -f /tmp/precommit-syntax-err /tmp/precommit-shellcheck-err /tmp/precommit-swallow-err /tmp/precommit-test-out /tmp/precommit-pytest-out

if [ "$fail" -eq 0 ]; then
    echo "${GREEN}[pre-commit] OK — ${total} file(s) passed${NC}"
    exit 0
fi

echo ""
echo "${RED}[pre-commit] Commit aborted.${NC} Fix the issues above or bypass with ${YELLOW}git commit --no-verify${NC} (not recommended)."
exit 1
