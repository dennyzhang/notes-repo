#!/usr/bin/env bash
# hook-stack-toggle.sh - A/B test the Claude Code hook stack.
#
# Marty Dumaual research (2026-04-29) showed PreToolUse + UserPromptSubmit
# on the same action degraded perf 0.667 -> 0.431. Our stack has 8+ Pre and
# 6+ Post hooks firing on common tools - untested in combination.
#
# This script swaps `~/.claude/settings.json` between configs to enable
# controlled A/B runs. The full original config is backed up on first run
# and restored by `baseline`. Trimmed configs are computed from the original
# via jq filters so adding a new hook to baseline picks it up automatically
# on the next swap.
#
# Usage:
#   hook-stack-toggle.sh status                  # show current mode
#   hook-stack-toggle.sh baseline                # restore full original stack
#   hook-stack-toggle.sh trim-pre                # drop PreToolUse Bash 3-stack work hooks
#   hook-stack-toggle.sh trim-post               # drop PostToolUse Bash 3-stack
#   hook-stack-toggle.sh trim-both               # drop both
#
# IMPORTANT: Settings take effect on the NEXT Claude Code session. Existing
# sessions keep the snapshot loaded at their start. Plan A/B runs as fresh
# sessions, not mid-session swaps.
#
# Spec: cheatsheets/agents/agent-pressure.md (hook interference section)
# Followup: ~/work/claude/FOLLOWUPS.md "hook interference audit"

set -uo pipefail

SETTINGS="$HOME/.claude/settings.json"
BACKUP="$HOME/.claude/settings.baseline.json"
MODE_MARKER="$HOME/.claude/.hook-stack-mode"

# Patterns identifying the work-doing PreToolUse-Bash hooks (NOT the
# echo-and-exit advisory ones). These are the candidates Marty's
# research suggests interfere when stacked.
PRE_BASH_TRIM_PATTERNS=(
    "quality-gate-precheck.sh"
    "block-stacked-commit.sh"
)

# All PostToolUse-Bash hooks (3 of them) are work-doing.
POST_BASH_TRIM_PATTERNS=(
    "auto-prescreener.sh"
    "gdocs-post-verify.sh"
    "auto-diff-review.sh"
)

usage() {
    sed -n '2,21p' "$0" | sed 's|^# ||;s|^#$||'
    exit "${1:-0}"
}

require_jq() {
    command -v jq >/dev/null 2>&1 || {
        echo "ERROR: jq required (apt-get install jq or use fbpython jq)" >&2
        exit 1
    }
}

ensure_backup() {
    if [ ! -f "$BACKUP" ]; then
        if [ ! -f "$SETTINGS" ]; then
            echo "ERROR: $SETTINGS does not exist - nothing to back up" >&2
            exit 1
        fi
        cp "$SETTINGS" "$BACKUP"
        echo "Saved baseline backup at $BACKUP"
    fi
}

current_mode() {
    if [ -f "$MODE_MARKER" ]; then
        cat "$MODE_MARKER"
    else
        echo "unknown (no marker - settings.json may have been hand-edited)"
    fi
}

# Build a jq script that removes hooks matching any of $1..$N patterns from
# the given trigger key (PreToolUse or PostToolUse).
build_filter() {
    local trigger="$1"; shift
    local patterns=("$@")
    local jq_pattern_arr
    jq_pattern_arr=$(printf '"%s",' "${patterns[@]}" | sed 's/,$//')

    cat <<EOF
.hooks.${trigger} = (
  .hooks.${trigger} // []
  | map(
      .hooks = (
        .hooks
        | map(select(
            (.command // "")
            | (. as \$cmd | [${jq_pattern_arr}] | any(. as \$p | \$cmd | contains(\$p))) | not
          ))
      )
    )
  | map(select((.hooks | length) > 0))
)
EOF
}

apply() {
    local mode="$1"
    require_jq
    ensure_backup

    case "$mode" in
        baseline)
            cp "$BACKUP" "$SETTINGS"
            echo "baseline" > "$MODE_MARKER"
            echo "Restored baseline (full hook stack)."
            ;;
        trim-pre)
            local filter
            filter=$(build_filter "PreToolUse" "${PRE_BASH_TRIM_PATTERNS[@]}")
            jq "$filter" "$BACKUP" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
            echo "trim-pre" > "$MODE_MARKER"
            echo "Trimmed PreToolUse Bash work hooks: ${PRE_BASH_TRIM_PATTERNS[*]}"
            ;;
        trim-post)
            local filter
            filter=$(build_filter "PostToolUse" "${POST_BASH_TRIM_PATTERNS[@]}")
            jq "$filter" "$BACKUP" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
            echo "trim-post" > "$MODE_MARKER"
            echo "Trimmed PostToolUse Bash work hooks: ${POST_BASH_TRIM_PATTERNS[*]}"
            ;;
        trim-both)
            local pre_filter post_filter
            pre_filter=$(build_filter "PreToolUse" "${PRE_BASH_TRIM_PATTERNS[@]}")
            post_filter=$(build_filter "PostToolUse" "${POST_BASH_TRIM_PATTERNS[@]}")
            jq "${pre_filter} | ${post_filter}" "$BACKUP" > "${SETTINGS}.tmp" \
                && mv "${SETTINGS}.tmp" "$SETTINGS"
            echo "trim-both" > "$MODE_MARKER"
            echo "Trimmed both PreToolUse and PostToolUse Bash work hooks."
            ;;
        *)
            echo "ERROR: unknown mode '$mode'" >&2
            usage 1
            ;;
    esac

    # Show what changed - hook counts before vs after
    local before_pre after_pre before_post after_post
    before_pre=$(jq '[.hooks.PreToolUse // [] | .[].hooks[]?] | length' "$BACKUP")
    after_pre=$(jq '[.hooks.PreToolUse // [] | .[].hooks[]?] | length' "$SETTINGS")
    before_post=$(jq '[.hooks.PostToolUse // [] | .[].hooks[]?] | length' "$BACKUP")
    after_post=$(jq '[.hooks.PostToolUse // [] | .[].hooks[]?] | length' "$SETTINGS")
    echo
    echo "Hook counts:"
    echo "  PreToolUse:  ${before_pre} (baseline) -> ${after_pre} (active)"
    echo "  PostToolUse: ${before_post} (baseline) -> ${after_post} (active)"
    echo
    echo "NOTE: Take effect on NEXT Claude Code session. Restart your CLI to pick up the change."
}

main() {
    [ $# -eq 0 ] && usage 0
    case "$1" in
        status)
            echo "Current mode: $(current_mode)"
            [ -f "$BACKUP" ] && echo "Baseline backup: $BACKUP" \
                || echo "Baseline backup: NOT YET CREATED (run any other mode to seed)"
            ;;
        baseline|trim-pre|trim-post|trim-both)
            apply "$1"
            ;;
        -h|--help|help)
            usage 0
            ;;
        *)
            echo "ERROR: unknown command '$1'" >&2
            usage 1
            ;;
    esac
}

main "$@"
