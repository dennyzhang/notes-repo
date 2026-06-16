#!/usr/bin/env bash
# scan-cron-errors.sh — Lint cron scripts for error-swallowing patterns.
# Run manually or from hooks to catch 2>/dev/null, &>/dev/null, and || true misuse.
#
# Allowlisted patterns (safe shell idioms):
#   unset VAR 2>/dev/null        — unset is harmless
#   kill -0 PID 2>/dev/null      — process existence check, "No such process" is noise
#   cat LOCKFILE 2>/dev/null     — lock file may not exist
#   command -v CMD &>/dev/null   — standard command existence check
#   grep -q PATTERN 2>/dev/null  — conditional matching on possibly-absent files
#   date -d ... 2>/dev/null      — cross-platform fallback (Linux vs macOS)
#   Lines inside heredoc/prompt strings (claude -p "...") are not real shell
#
# Usage: bash scripts/scan-cron-errors.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
violations=0

# Check if a line matches an allowlisted pattern
is_allowed() {
    local line="$1"
    # unset is harmless
    echo "$line" | grep -qE '^\s*unset\s' && return 0
    # kill -0 for process checking
    echo "$line" | grep -q 'kill -0' && return 0
    # cat for lock file reading
    echo "$line" | grep -qE 'cat\s+"\$.*LOCK' && return 0
    # command -v for command existence
    echo "$line" | grep -q 'command -v' && return 0
    # grep -q/-c for conditional matching
    echo "$line" | grep -qE 'grep\s+-[qc]' && return 0
    # date fallback chains (cross-platform)
    echo "$line" | grep -qE 'date\s+-[dv]' && return 0
    # Inside a quoted heredoc/prompt (indented lines in claude -p strings)
    echo "$line" | grep -qE '^\s+(ssh|sl |hg |git )' && return 0
    return 1
}

echo "Scanning cron scripts for error-swallowing patterns..."
echo

for script in "$SCRIPT_DIR"/cron-*.sh "$SCRIPT_DIR"/prefetch-*.sh; do
    [ -f "$script" ] || continue
    name=$(basename "$script")

    # Pattern 1: 2>/dev/null on non-trivial commands
    while IFS= read -r match; do
        line_num=$(echo "$match" | cut -d: -f1)
        line_content=$(echo "$match" | cut -d: -f2-)
        is_allowed "$line_content" && continue
        echo "  WARN: $name:$line_num — stderr suppressed: $line_content"
        violations=$((violations + 1))
    done < <(grep -n '2>/dev/null' "$script" 2>/dev/null || true)

    # Pattern 2: &>/dev/null (suppresses both stdout and stderr)
    while IFS= read -r match; do
        line_num=$(echo "$match" | cut -d: -f1)
        line_content=$(echo "$match" | cut -d: -f2-)
        is_allowed "$line_content" && continue
        echo "  WARN: $name:$line_num — all output suppressed: $line_content"
        violations=$((violations + 1))
    done < <(grep -n '&>/dev/null' "$script" 2>/dev/null || true)

    # Pattern 3: 2>/dev/null || true (double swallow — most dangerous)
    while IFS= read -r match; do
        line_num=$(echo "$match" | cut -d: -f1)
        line_content=$(echo "$match" | cut -d: -f2-)
        is_allowed "$line_content" && continue
        echo "  CRIT: $name:$line_num — double swallow: $line_content"
        violations=$((violations + 1))
    done < <(grep -n '2>/dev/null.*||.*true' "$script" 2>/dev/null || true)
done

echo
if [ "$violations" -gt 0 ]; then
    echo "Found $violations error-swallowing violation(s). Fix before deploying."
    exit 1
else
    echo "No error-swallowing violations found."
    exit 0
fi
