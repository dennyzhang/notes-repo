#!/usr/bin/env bash
# gdocs_lib.sh — Shared Google Docs push + format primitives for cron-*.sh scripts.
#
# Source after cron-alert.sh so PATH + doc-ID helpers are already in scope.
#   source "$(dirname "$0")/cron-alert.sh"
#   source "$(dirname "$0")/lib/gdocs_lib.sh"
#
# Design goal: one canonical implementation of every post-push formatting step
# (column widths, body font, heading font, header-row background, empty-line
# shrink, Purpose/Pipeline/Source header verification). Scripts call these
# helpers instead of inlining their own copies.
#
# Canonical source: the named functions in cron-area-monitor.sh (the most
# battle-tested formatting code). Extracted verbatim, then parameterized.
#
# Every helper is idempotent and logs via $LOG_PREFIX (set by the caller).
# Every helper fails soft: if batch-update rejects a request, the helper logs
# a warning and returns 0 so a single bad request does not abort the whole run.

# Guard against double-sourcing.
[ -n "${__GDOCS_LIB_SOURCED:-}" ] && return 0
__GDOCS_LIB_SOURCED=1

# NOTE (2026-05-30): do NOT set GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=1 here — the
# `--untrusted-authors-mode` flag is a boolean switch that takes NO value, so the
# env value "1" makes every gdocs call abort with `invalid value '1'`. To apply
# untrusted mode to a cron's gdocs calls, add the bare `--untrusted-authors-mode`
# flag to each call site (no value). The gdocs_get_structure helper already does.

# NOTE (2026-05-30): an earlier fix here force-set GOOGLE_MUX_NO_DAEMON=1 to
# dodge the wedged google-mux daemon. Reverted — per cheatsheets/gdocs/rules.md
# (lines 216-217) the correct fix for daemon wedge is RECOVERY (kill the
# google-mux daemon + remove the stale socket, then retry in daemon mode), NOT
# --no-daemon. --no-daemon triggered `supportsAllDrives` HTTP 400s on
# batch-update / find-replace (the exact ops the pushers need). Daemon recovery
# is handled by ensure_gmux_healthy (cron-ai-health) and cron-keepalive.

# ─── Config ───────────────────────────────────────────────────────────────
GDOCS_BODY_FONT_PT="${GDOCS_BODY_FONT_PT:-11}"
GDOCS_BODY_FONT_FAMILY="${GDOCS_BODY_FONT_FAMILY:-Arial}"
GDOCS_HEADER_ROW_BG="${GDOCS_HEADER_ROW_BG:-#C9DAF8}"  # light blue (cheatsheet default)
LOG_PREFIX="${LOG_PREFIX:-$(date '+%Y-%m-%d %H:%M')}"

# Path to the Python helper. NOTE: scripts/ is a symlink into ~/notes, and
# fb:notes refuses .py files, so the helper lives in private_scripts/lib/.
# Prefer the sibling copy (portable checkouts), fall back to private_scripts.
_GDOCS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_GDOCS_LIB_DIR/gdocs_helper.py" ]; then
    GDOCS_HELPER_PY="$_GDOCS_LIB_DIR/gdocs_helper.py"
else
    GDOCS_HELPER_PY="$HOME/work/claude/private_scripts/lib/gdocs_helper.py"
fi

# ─── Error Tracking ───────────────────────────────────────────────────────
# Scripts that source this lib inherit a global error counter. Every mutating
# helper increments on failure (instead of swallowing silently with `|| true`).
# At script end, call gdocs_exit_with_status to propagate a non-zero exit and
# fire cron-alert if any step failed.
#
# Why this matters: the FOLLOWUPS backlog is full of "silent failure in cron-X
# only surfaced when Denny looked at the doc". One global counter + one alert
# at script end closes that loop — errors reach ALERTS.md within minutes.
GDOCS_LIB_ERRORS="${GDOCS_LIB_ERRORS:-0}"

gdocs_track_error() {
    GDOCS_LIB_ERRORS=$((GDOCS_LIB_ERRORS + 1))
    echo "$LOG_PREFIX [ERROR] $*" >&2
}

# Call at the end of a cron script (after all gdocs work is done):
#   gdocs_exit_with_status "$(basename "$0" .sh)"
# Alerts and exits non-zero if any gdocs operation failed during the run.
gdocs_exit_with_status() {
    local script_name="${1:-unknown}"
    if [ "$GDOCS_LIB_ERRORS" -gt 0 ]; then
        echo "$LOG_PREFIX [FAIL] $script_name: $GDOCS_LIB_ERRORS gdocs operation(s) failed" >&2
        # cron-alert.sh's cron_alert writes to ALERTS.md. Only call if available.
        if declare -f cron_alert >/dev/null; then
            cron_alert "$script_name" "$GDOCS_LIB_ERRORS gdocs operation(s) failed — see log for [ERROR] lines"
        fi
        return 1
    fi
    return 0
}

# ─── Dry-Run Mode ─────────────────────────────────────────────────────────
# Set DRY_RUN=1 to redirect all mutating gdocs calls to local files under
# /tmp/gdocs-dryrun-<pid>/. Structure inspection still hits the live API so
# the generated requests reflect real document state.
#
# Usage:
#   DRY_RUN=1 bash scripts/cron-area-monitor.sh
#   → writes batch-update JSON to /tmp/gdocs-dryrun-$$/batch-*.json
#   → writes replace input to /tmp/gdocs-dryrun-$$/replace-*.{html,md}
#
# Pre-commit hook: scripts/lib/precommit-dry-run.sh runs every edited cron
# script in DRY_RUN=1 mode and aborts the commit if any exits non-zero. This
# catches structural bugs before cron picks them up.
DRY_RUN="${DRY_RUN:-0}"
GDOCS_DRYRUN_DIR="${GDOCS_DRYRUN_DIR:-/tmp/gdocs-dryrun-$$}"
if [ "$DRY_RUN" = "1" ]; then
    mkdir -p "$GDOCS_DRYRUN_DIR"
    echo "$LOG_PREFIX [DRY-RUN] Mutations will be captured under $GDOCS_DRYRUN_DIR (no prod writes)"
fi

# Unique filename per call. Uses nanosecond timestamp + $RANDOM because
# command substitution $(gdocs_dryrun_next_file ...) runs in a subshell, so
# a plain incrementing counter variable would be reset between calls.
gdocs_dryrun_next_file() {
    local prefix="$1"
    printf "%s/%s-%s-%04d.json" "$GDOCS_DRYRUN_DIR" "$prefix" "$(date +%s%N)" "$RANDOM"
}

# Internal: run a batch-update in either dry-run or real mode.
# Reads JSON on stdin. On real mode, runs gdocs batch-update + tracks errors.
# On dry-run, writes the JSON to a file and logs the path.
#   <json> | _gdocs_batch <doc_id> <label>
_gdocs_batch() {
    local doc_id="$1"
    local label="${2:-batch}"
    if [ "$DRY_RUN" = "1" ]; then
        local out
        out=$(gdocs_dryrun_next_file "$label")
        cat > "$out"
        echo "$LOG_PREFIX [DRY-RUN]   captured $label → $out"
        return 0
    fi
    local _gb_err
    _gb_err=$(mktemp -t gdocs-batch.XXXX.err)
    if ! command gdocs batch-update "$doc_id" --data - --untrusted-authors-mode >/dev/null 2>"$_gb_err"; then
        local _gb_msg
        _gb_msg=$(grep -oE 'HTTP [0-9]+[^"]*|"message":\s*"[^"]+"' "$_gb_err" | head -2 | tr '\n' ' ' | head -c 300)
        [ -z "$_gb_msg" ] && _gb_msg=$(tail -2 "$_gb_err" | tr '\n' ' ' | head -c 300)
        gdocs_track_error "batch-update failed ($label): $_gb_msg"
        rm -f "$_gb_err"
        return 1
    fi
    rm -f "$_gb_err"
    return 0
}

# ─── DRY_RUN Shim for `gdocs` and `timeout gdocs` ─────────────────────────
# When DRY_RUN=1, shadow the `gdocs` binary with a shell function that
# intercepts mutating subcommands and writes the intended request to a file
# under $GDOCS_DRYRUN_DIR instead of making the API call.
#
# Also shadow `timeout` so `timeout 15 gdocs batch-update ...` is captured
# (otherwise `timeout` exec()s directly and bypasses the shell function).
#
# Read-only subcommands (get, content get-structure, comments list, tabs
# list, revisions, permissions list, export, ghtml) fall through to the real
# binary so structure inspection still reflects real document state.
#
# This is what makes Tier 2 work without rewriting every callsite:
#   DRY_RUN=1 bash scripts/cron-area-monitor.sh
#   → every `gdocs batch-update` / `gdocs apply` / `gdocs content insert-*`
#     redirects to /tmp/gdocs-dryrun-<pid>/shim-*.json
#   → structure reads still hit the live API
#
# Gotcha: scripts that do `command gdocs ...` or `\gdocs ...` will bypass
# the shim. None of the current cron scripts do this. If you add one that
# does, fix the call or add a carve-out here.
if [ "$DRY_RUN" = "1" ]; then
    gdocs() {
        local cmd1="${1:-}"
        local cmd2="${2:-}"
        local mutating=0
        case "$cmd1" in
            batch-update|apply|replace|create|copy|move|delete|upload-image|add-tab) mutating=1 ;;
            content)
                case "$cmd2" in
                    insert-text|insert-markdown|insert-html|find-replace|tables|images) mutating=1 ;;
                esac ;;
            format) mutating=1 ;;
            comments)
                case "$cmd2" in add|reply|resolve|delete) mutating=1 ;; esac ;;
        esac
        if [ "$mutating" = "1" ]; then
            local label="shim-${cmd1}${cmd2:+-$cmd2}"
            local out
            out=$(gdocs_dryrun_next_file "$label")
            {
                printf '# DRY-RUN captured at %s\n' "$(date -Iseconds)"
                printf '# command: gdocs'
                printf ' %q' "$@"
                printf '\n# stdin:\n'
                if [ ! -t 0 ]; then
                    cat
                else
                    printf '(no stdin)\n'
                fi
            } > "$out"
            echo "$LOG_PREFIX [DRY-RUN]   gdocs $cmd1 $cmd2 → $out"
            return 0
        fi
        command gdocs "$@"
    }
    export -f gdocs 2>/dev/null || true

    timeout() {
        # Detect the classic form: `timeout <duration> <cmd...>`.
        # Duration accepts suffix s/m/h/d and may be a decimal — a loose regex is fine.
        local maybe_dur="${1:-}"
        if [[ "$maybe_dur" =~ ^[0-9.]+[smhd]?$ ]]; then
            shift
            "$@"
            return $?
        fi
        # Not a duration (could be a flag like --foreground) — pass through.
        command timeout "$@"
    }
    export -f timeout 2>/dev/null || true
fi

# ─── Push Guard ───────────────────────────────────────────────────────────
# Wrapper around gdocs-safe-replace.sh. Never call `gdocs replace` directly.
#   gdocs_replace_safe <doc_id> --from <file> [--tab-id <tab>] [other flags]
gdocs_replace_safe() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    bash "$script_dir/gdocs-safe-replace.sh" "$@"
}

# ─── Structure Inspection ─────────────────────────────────────────────────
# Return the tab structure (raw output of `gdocs content get-structure`).
# Empty string on error. Safe to call repeatedly — callers can cache.
#   gdocs_get_structure <doc_id> <tab_id>
gdocs_get_structure() {
    local doc_id="$1"
    local tab_id="$2"
    # --untrusted-authors-mode: docs with a personal-gmail collaborator return
    # an EMPTY structure without it, which silently broke all post-push
    # formatting ("empty structure" warnings, AI Playbook 2026-05-30). (2026-05-30)
    gdocs content get-structure "$doc_id" --tab-id "$tab_id" --untrusted-authors-mode 2>/dev/null || true
}

# ─── Format helpers (delegated to gdocs_helper.py) ────────────────────────
# Each helper is a 3-step pipeline: fetch structure → Python builds JSON →
# _gdocs_batch pushes. JSON construction lives in gdocs_helper.py subcommands
# (tested in test_gdocs_helper.py), not inline here — inline python breeds
# quoting and stdin-collision bugs.

# _gdocs_json_push <doc_id> <step_label> <subcommand> [subcmd_args...]
# stdin: structure text. Runs the Python helper to build batch JSON, then
# pushes via _gdocs_batch. Empty "[]" output is a no-op (returns 0).
# Note: uses `if` not `[ ] && return 0` — the latter returns 1 when the guard
# is false, which kills the function under `set -e` in caller scripts.
_gdocs_json_push() {
    local doc_id="$1" step_label="$2"
    shift 2
    local json
    json=$(python3 "$GDOCS_HELPER_PY" "$@")
    if [ -z "$json" ] || [ "$json" = "[]" ]; then
        return 0
    fi
    echo "$json" | _gdocs_batch "$doc_id" "$step_label"
}

#   gdocs_format_tab_body_font <doc_id> <tab_id> [tab_label]
gdocs_format_tab_body_font() {
    local doc_id="$1" tab_id="$2" tab_label="${3:-$2}"
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    [ -z "$structure" ] && return 0
    if printf '%s\n' "$structure" | _gdocs_json_push "$doc_id" "body-font-${tab_label}" \
        body-font --tab-id "$tab_id" --size "$GDOCS_BODY_FONT_PT"; then
        echo "$LOG_PREFIX   Body font set to ${GDOCS_BODY_FONT_PT}pt ($tab_label)"
    fi
}

#   gdocs_shrink_empty_lines <doc_id> <tab_id> [tab_label]
gdocs_shrink_empty_lines() {
    local doc_id="$1" tab_id="$2" tab_label="${3:-$2}"
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    [ -z "$structure" ] && return 0
    if printf '%s\n' "$structure" | _gdocs_json_push "$doc_id" "shrink-empty-${tab_label}" \
        shrink-empty --tab-id "$tab_id"; then
        echo "$LOG_PREFIX   Shrunk empty lines ($tab_label)"
    fi
}

#   gdocs_apply_font_family <doc_id> <tab_id> [tab_label] [font_family]
gdocs_apply_font_family() {
    local doc_id="$1" tab_id="$2" tab_label="${3:-$2}" family="${4:-$GDOCS_BODY_FONT_FAMILY}"
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    [ -z "$structure" ] && return 0
    if printf '%s\n' "$structure" | _gdocs_json_push "$doc_id" "font-family-${tab_label}" \
        font-family --tab-id "$tab_id" --family "$family"; then
        echo "$LOG_PREFIX   Font family set to $family ($tab_label)"
    fi
}

#   gdocs_apply_header_row_bg <doc_id> <tab_id> [tab_label] [color]
gdocs_apply_header_row_bg() {
    local doc_id="$1" tab_id="$2" tab_label="${3:-$2}" color="${4:-$GDOCS_HEADER_ROW_BG}"
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    [ -z "$structure" ] && return 0
    if printf '%s\n' "$structure" | _gdocs_json_push "$doc_id" "header-bg-${tab_label}" \
        header-bg --tab-id "$tab_id" --color "$color"; then
        echo "$LOG_PREFIX   Header-row background $color applied ($tab_label)"
    fi
}

#   gdocs_set_col_widths <doc_id> <tab_id> <tab_label> <widths_csv>
gdocs_set_col_widths() {
    local doc_id="$1" tab_id="$2" tab_label="$3" widths_csv="$4"
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    [ -z "$structure" ] && return 0
    if printf '%s\n' "$structure" | _gdocs_json_push "$doc_id" "col-widths-${tab_label}" \
        col-widths --tab-id "$tab_id" --widths "$widths_csv"; then
        echo "$LOG_PREFIX   Column widths [$widths_csv] applied ($tab_label)"
    fi
}

# ─── Header Block Enforcement (Purpose / Pipeline / Source) ───────────────
# Verify the 3-item italic header paragraph is present directly under the H1
# of a periodic/cron-updated tab. Feedback memory:
# feedback_gdoc_compact_tables_and_header.md — every periodic doc must carry
# "Purpose: ... Pipeline: ... Source: ..." as a single italic paragraph.
#
# Returns 0 if header found, 1 if missing. Logs either way — does not fix.
# (Fixing requires knowing what to write; that is the script's responsibility.)
#   gdocs_verify_header_block <doc_id> <tab_id> [tab_label]
gdocs_verify_header_block() {
    local doc_id="$1" tab_id="$2" tab_label="${3:-$2}"
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    if [ -z "$structure" ]; then
        echo "$LOG_PREFIX   [WARN] header-verify: empty structure ($tab_label)"
        return 1
    fi
    if printf '%s\n' "$structure" | python3 "$GDOCS_HELPER_PY" validate --rule header-block >/dev/null 2>&1; then
        echo "$LOG_PREFIX   Header block verified: Purpose/Pipeline/Source present ($tab_label)"
        return 0
    fi
    echo "$LOG_PREFIX   [WARN] Header block missing — expected Purpose/Pipeline/Source under H1 ($tab_label)"
    return 1
}

# ─── Cleanup Empty Lines (wrapper) ────────────────────────────────────────
# Thin wrapper around gdocs-cleanup-empty-lines.sh (the existing shared
# script). Callers should prefer this to re-implementing the logic.
#   gdocs_cleanup_empty_lines <doc_id> [tab_id]
gdocs_cleanup_empty_lines() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local cleanup="$script_dir/gdocs-cleanup-empty-lines.sh"
    [ -x "$cleanup" ] || { echo "$LOG_PREFIX   [WARN] cleanup script missing: $cleanup"; return 0; }
    bash "$cleanup" "$@" 2>&1 | tail -5 || true
}

# ─── Revision Snapshot + Post-Push Validation + Rollback Alert ───────────
# Auto-rollback via `gdocs replace` is unsafe on commented docs — it
# destroys all comments. So instead: capture the pre-push revision ID into
# a sentinel file BEFORE any mutation, then after post-push formatting run
# validators. On validation failure, alert with the pre-push revision ID so
# the human can restore via Docs UI (one click, comment-safe).
#
# Sentinel location: ~/work/claude/state/gdocs-prepush/<doc_id>-<label>.txt
# Contents: revision_id\ttimestamp
GDOCS_PREPUSH_DIR="${GDOCS_PREPUSH_DIR:-$CLAUDE_STATE_DIR/gdocs-prepush}"
mkdir -p "$GDOCS_PREPUSH_DIR" 2>/dev/null

# Capture current (pre-push) latest revision into a dated sentinel. Call
# this BEFORE any mutation in the script. Sentinels are per-date so a
# cascade failure (today corrupts + tomorrow corrupts) still leaves
# earlier good revisions available for rollback.
#
# Layout: <GDOCS_PREPUSH_DIR>/<doc_id>-<label>/<YYYY-MM-DD>.txt
# Retention: 14 days (older pruned on every capture).
#   gdocs_capture_prepush_revision <doc_id> <label>
gdocs_capture_prepush_revision() {
    local doc_id="$1"
    local label="${2:-default}"
    local rev_id
    # Last numeric-ID line of `gdocs revisions` is the newest.
    rev_id=$(command gdocs revisions "$doc_id" 2>/dev/null | awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}' | tail -1)
    if [ -z "$rev_id" ]; then
        echo "$LOG_PREFIX   [WARN] Could not capture pre-push revision for $doc_id ($label)" >&2
        return 1
    fi
    local dir="$GDOCS_PREPUSH_DIR/${doc_id}-${label}"
    mkdir -p "$dir" 2>/dev/null
    local today
    today=$(date '+%Y-%m-%d')
    printf '%s\t%s\n' "$rev_id" "$(date -Iseconds)" > "$dir/${today}.txt"

    # Prune: keep only last 14 dated sentinels.
    # Sort by name (YYYY-MM-DD sorts chronologically), delete all but newest 14.
    find "$dir" -maxdepth 1 -name '*.txt' -type f -printf '%f\n' 2>/dev/null \
        | sort -r | tail -n +15 | while read -r stale; do
            rm -f "$dir/$stale" 2>/dev/null
        done

    echo "$LOG_PREFIX   Pre-push revision captured: $rev_id ($label)"
    return 0
}

# Read back the most recent pre-push revision ID for this doc+label.
# If <date> provided, reads that date's sentinel; otherwise the latest.
#   gdocs_get_prepush_revision <doc_id> <label> [date=YYYY-MM-DD]
gdocs_get_prepush_revision() {
    local doc_id="$1"
    local label="${2:-default}"
    local want_date="${3:-}"
    local dir="$GDOCS_PREPUSH_DIR/${doc_id}-${label}"
    # Legacy single-file sentinel — keep reading it if the new dir is absent.
    local legacy="$GDOCS_PREPUSH_DIR/${doc_id}-${label}.txt"
    if [ ! -d "$dir" ] && [ -f "$legacy" ]; then
        awk '{print $1}' "$legacy"
        return 0
    fi
    [ -d "$dir" ] || { echo ""; return 1; }

    local target
    if [ -n "$want_date" ]; then
        target="$dir/${want_date}.txt"
    else
        target=$(find "$dir" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | sort -r | head -1)
    fi
    [ -n "$target" ] && [ -f "$target" ] || { echo ""; return 1; }
    awk '{print $1}' "$target"
}

# List all retained pre-push revision IDs for a doc/label, newest first.
#   gdocs_list_prepush_revisions <doc_id> <label>
gdocs_list_prepush_revisions() {
    local doc_id="$1"
    local label="${2:-default}"
    local dir="$GDOCS_PREPUSH_DIR/${doc_id}-${label}"
    [ -d "$dir" ] || return 0
    find "$dir" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | sort -r \
        | while read -r f; do
            local d
            d=$(basename "$f" .txt)
            local rev
            rev=$(awk '{print $1}' "$f")
            printf '%s\t%s\n' "$d" "$rev"
        done
}

# Simple tab-level invariants. Each returns 0 on pass, 1 on fail; logs the
# reason. Callers combine these into whatever validation contract fits the
# target doc. Keep validators cheap — they run on every push.

# Does the tab have an H1 that mentions today's date (YYYY-MM-DD)?
# Use for daily-regenerated periodic tabs.
#   gdocs_validate_h1_today <doc_id> <tab_id> [tab_label]
gdocs_validate_h1_today() {
    local doc_id="$1"
    local tab_id="$2"
    local tab_label="${3:-$tab_id}"
    local today
    today=$(date '+%Y-%m-%d')
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    if echo "$structure" | grep -q "HEADING_1.*${today}"; then
        return 0
    fi
    echo "$LOG_PREFIX   [VALIDATION FAIL] No H1 with today's date (${today}) in ${tab_label}" >&2
    return 1
}

# Does the tab have at least N tables?
#   gdocs_validate_min_tables <doc_id> <tab_id> <min_count> [tab_label]
gdocs_validate_min_tables() {
    local doc_id="$1"
    local tab_id="$2"
    local min_count="$3"
    local tab_label="${4:-$tab_id}"
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    local table_count
    table_count=$(echo "$structure" | grep -c 'TABLE:' || true)
    if [ "$table_count" -ge "$min_count" ]; then
        return 0
    fi
    echo "$LOG_PREFIX   [VALIDATION FAIL] Expected >= $min_count tables, got $table_count in $tab_label" >&2
    return 1
}

# Orchestrator: runs validators and, on failure, emits a rollback-ready
# alert with the pre-push revision ID. Non-zero exit on validation failure
# so callers can fail the script and fire cron-alert at end via
# gdocs_exit_with_status.
#
#   gdocs_validate_post_push <doc_id> <tab_id> <label> <validator_fn> [validator_args...]
# Example:
#   gdocs_validate_post_push "$DOC_ID" "$TAB_ID" "routine" gdocs_validate_h1_today
gdocs_validate_post_push() {
    local doc_id="$1"
    local tab_id="$2"
    local label="$3"
    shift 3
    # Remaining args: validator function + its args (excluding doc_id, tab_id, tab_label which we add)
    local validator="$1"
    shift
    if "$validator" "$doc_id" "$tab_id" "$@" "$label"; then
        echo "$LOG_PREFIX   Post-push validation passed ($label)"
        return 0
    fi
    local rev_id
    rev_id=$(gdocs_get_prepush_revision "$doc_id" "$label")
    local doc_url="https://docs.google.com/document/d/${doc_id}/edit"
    echo "$LOG_PREFIX [ERROR] Post-push validation FAILED ($label)" >&2
    echo "$LOG_PREFIX [ERROR]   Doc:          $doc_url" >&2
    echo "$LOG_PREFIX [ERROR]   Pre-push rev: ${rev_id:-unknown} (restore via File → Version history)" >&2
    gdocs_track_error "post-push validation failed ($label) — pre-push rev=${rev_id:-unknown}"
    return 1
}

# ─── Full Post-Push Checklist (one call) ──────────────────────────────────
# Run every formatting step the cheatsheet requires after a gdocs push:
#   1. body font (11pt on tables + normal paragraphs)
#   2. shrink empty separators
#   3. apply font family (Arial)
#   4. header-row background on tables
#   5. verify Purpose/Pipeline/Source header (periodic docs only)
#
# Column widths are NOT called here because they are tab-specific — callers
# must invoke gdocs_set_col_widths separately with their own widths_csv.
#
#   gdocs_post_push <doc_id> <tab_id> <tab_label> [verify_header=1|0]
gdocs_post_push() {
    local doc_id="$1"
    local tab_id="$2"
    local tab_label="${3:-$tab_id}"
    local verify_header="${4:-1}"

    gdocs_format_tab_body_font "$doc_id" "$tab_id" "$tab_label"
    gdocs_shrink_empty_lines   "$doc_id" "$tab_id" "$tab_label"
    gdocs_apply_font_family    "$doc_id" "$tab_id" "$tab_label"
    gdocs_apply_header_row_bg  "$doc_id" "$tab_id" "$tab_label"
    if [ "$verify_header" = "1" ]; then
        gdocs_verify_header_block "$doc_id" "$tab_id" "$tab_label" || true
    fi
}

# ─── Same-Day Prepend Helper ──────────────────────────────────────────────
# Idempotent same-day dedup + prepend for daily-appended tabs.
#   1. Query structure, find today's H1 span via gdocs_helper.py find-today-section
#   2. Delete the span (if exists) via _gdocs_batch (DRY_RUN-aware)
#   3. Insert <content_file> at index 1 via `gdocs content insert-text`
#      (DRY_RUN shim intercepts — do NOT use `command gdocs`)
#
# Respects --max-size-bytes safety cap (default 15000). Failures route through
# gdocs_track_error so gdocs_exit_with_status can surface them.
#
#   gdocs_prepend_today_section <doc_id> <tab_id> <content_file> [opts...]
#     --format {markdown|html|text}  (default: markdown)
#     --max-size-bytes N             (default: 15000)
#     --today YYYY-MM-DD             (default: today's date)
#     --label LABEL                  (for logs; default: tab_id)
gdocs_prepend_today_section() {
    local doc_id="$1" tab_id="$2" content_file="$3"
    shift 3
    local fmt="markdown" max_size=15000 today label
    today=$(date '+%Y-%m-%d')
    label="$tab_id"
    while [ $# -gt 0 ]; do
        case "$1" in
            --format) fmt="$2"; shift 2;;
            --max-size-bytes) max_size="$2"; shift 2;;
            --today) today="$2"; shift 2;;
            --label) label="$2"; shift 2;;
            *) echo "$LOG_PREFIX [ERROR] gdocs_prepend_today_section: unknown flag $1" >&2; return 1;;
        esac
    done

    [ -f "$content_file" ] || {
        gdocs_track_error "prepend ($label): missing content file $content_file"
        return 1
    }

    # Step 1: Fetch structure
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")

    local dedup_delete_start="" dedup_delete_end=""
    if [ -n "$structure" ]; then
        local doc_end find_err find_out find_rc
        doc_end=$(printf '%s\n' "$structure" | tail -1 | grep -oP '\-\K\d+(?=\])' || true)
        find_err=$(mktemp -t gdocs-prepend-find.XXXX.err)
        find_rc=0
        find_out=$(printf '%s\n' "$structure" | python3 "$GDOCS_HELPER_PY" find-today-section \
            --today "$today" --max-size-bytes "$max_size" \
            ${doc_end:+--doc-end "$doc_end"} 2>"$find_err") || find_rc=$?

        case $find_rc in
            0)
                # Step 2: Record today's span for atomic delete+insert below
                local t_start t_end
                t_start=$(printf '%s' "$find_out" | python3 -c "import sys,json; print(json.load(sys.stdin)['start'])" 2>/dev/null) || { echo "$LOG_PREFIX   [WARN] Failed to parse find-today-section output — skipping dedup" >&2; }
                t_end=$(printf '%s' "$find_out" | python3 -c "import sys,json; print(json.load(sys.stdin)['end'])" 2>/dev/null) || { echo "$LOG_PREFIX   [WARN] Failed to parse find-today-section output — skipping dedup" >&2; }
                dedup_delete_start="$t_start"
                dedup_delete_end="$t_end"
                echo "$LOG_PREFIX   Prepend: will replace today's span $t_start-$t_end ($label)"
                ;;
            2)
                gdocs_track_error "prepend ($label): today section exceeds safety cap ($max_size B): $(cat "$find_err")"
                rm -f "$find_err"
                return 1
                ;;
            3)
                : # today not present — first run of the day, skip dedup
                ;;
            *)
                gdocs_track_error "prepend ($label): find-today-section error rc=$find_rc: $(cat "$find_err")"
                rm -f "$find_err"
                return 1
                ;;
        esac
        rm -f "$find_err"
    else
        echo "$LOG_PREFIX [WARN] prepend ($label): empty structure; inserting without dedup"
    fi

    # Step 3: Atomic delete+insert via single batchUpdate call.
    # Previously these were two separate API calls, creating a window where the
    # doc was in a shrunken state (delete completed, insert not yet started).
    # If the insert failed, content was lost. Now both operations are in one
    # batchUpdate — either both succeed or neither does.
    local insert_flag line_count
    case "$fmt" in
        html) insert_flag="--html";;
        text) insert_flag="";;
        markdown|*) insert_flag="--markdown";;
    esac
    line_count=$(wc -l < "$content_file" | tr -d ' ')

    if [ -n "${dedup_delete_start:-}" ]; then
        # Delete today's existing span, then insert new content.
        # Google Docs batchUpdate only supports insertText (plain text) —
        # HTML/markdown requires the gdocs CLI insert-text command. So these
        # must be two API calls. We mitigate with insert retry on failure.
        if ! printf '[{"deleteContentRange":{"range":{"tabId":"%s","startIndex":%s,"endIndex":%s}}}]' \
                "$tab_id" "$dedup_delete_start" "$dedup_delete_end" \
                | _gdocs_batch "$doc_id" "prepend-dedup-$label"; then
            rm -f "$find_err" 2>/dev/null
            return 1
        fi
        echo "$LOG_PREFIX   Prepend: deleted today's span $dedup_delete_start-$dedup_delete_end ($label)"
    fi

    # Insert new content with retry — if delete succeeded but insert fails,
    # retry to avoid leaving the doc in a shrunken state.
    local insert_err2 insert_attempt=0
    insert_err2=$(mktemp -t gdocs-prepend-insert.XXXX.err)
    while [ "$insert_attempt" -lt 3 ]; do
        insert_attempt=$((insert_attempt + 1))
        if gdocs content insert-text "$doc_id" @"$content_file" $insert_flag --index 1 --tab-id "$tab_id" --untrusted-authors-mode 2>"$insert_err2" >/dev/null; then
            echo "$LOG_PREFIX   Prepend: inserted $line_count lines ($label, $fmt)"
            rm -f "$insert_err2"
            return 0
        fi
        echo "$LOG_PREFIX   [WARN] Insert attempt $insert_attempt/3 failed ($label), retrying in 5s..."
        sleep 5
    done
    gdocs_track_error "prepend insert failed after 3 attempts ($label): $(tail -3 "$insert_err2" | tr '\n' ' ')"
    rm -f "$insert_err2"
    return 1
}

# ─── Config-Driven Table Widths ───────────────────────────────────────────
# Apply per-table column widths from config/GDOC-TABLE-WIDTHS.json.
#
# Config shape:
#   { "<doc_key>": { "<tab_id>": { "<table_idx>": {"widths": [p0,p1,...]} } } }
#
# Tables are matched by 1-based index in document order (first TABLE in the
# tab = index 1). Tables without a config entry are left untouched.
#
#   gdocs_apply_table_widths <doc_id> <tab_id> <doc_key>
#
# Returns 0 on success (including "no matching config entries"), 1 on error.
GDOCS_TABLE_WIDTHS_CONFIG="${GDOCS_TABLE_WIDTHS_CONFIG:-$HOME/work/claude/config/GDOC-TABLE-WIDTHS.json}"
gdocs_apply_table_widths() {
    local doc_id="$1" tab_id="$2" doc_key="$3"
    if [ ! -f "$GDOCS_TABLE_WIDTHS_CONFIG" ]; then
        echo "$LOG_PREFIX [WARN] widths config missing: $GDOCS_TABLE_WIDTHS_CONFIG"
        return 0
    fi
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    if [ -z "$structure" ]; then
        return 0
    fi

    # Build per-table batch JSON in Python: reads config + table starts, emits
    # one batch with updateTableColumnProperties for every configured column.
    # stdin = structure text; stdout = JSON batch (or empty string if no-op).
    local batch_json
    batch_json=$(printf '%s\n' "$structure" | \
        GDOCS_WIDTHS_CFG="$GDOCS_TABLE_WIDTHS_CONFIG" \
        GDOCS_DOC_KEY="$doc_key" \
        GDOCS_TAB_ID="$tab_id" \
        python3 -c '
import json, os, re, sys
cfg = json.load(open(os.environ["GDOCS_WIDTHS_CFG"]))
tab_cfg = cfg.get(os.environ["GDOCS_DOC_KEY"], {}).get(os.environ["GDOCS_TAB_ID"], {})
if not tab_cfg:
    print("")
    sys.exit(0)
tab_id = os.environ["GDOCS_TAB_ID"]
table_starts = []
for line in sys.stdin:
    m = re.match(r"\[(\d+)-\d+\]\s*TABLE", line)
    if m:
        table_starts.append(int(m.group(1)))
ops = []
for idx, start in enumerate(table_starts, start=1):
    entry = tab_cfg.get(str(idx))
    if not entry or "widths" not in entry:
        continue
    for col_i, w in enumerate(entry["widths"]):
        ops.append({
            "updateTableColumnProperties": {
                "tableStartLocation": {"index": start, "tabId": tab_id},
                "columnIndices": [col_i],
                "tableColumnProperties": {
                    "widthType": "FIXED_WIDTH",
                    "width": {"magnitude": int(w), "unit": "PT"},
                },
                "fields": "widthType,width",
            }
        })
print(json.dumps(ops) if ops else "")
')
    if [ -z "$batch_json" ] || [ "$batch_json" = "[]" ]; then
        return 0
    fi
    if printf '%s' "$batch_json" | _gdocs_batch "$doc_id" "widths-${doc_key}-${tab_id}"; then
        local applied
        applied=$(printf '%s' "$batch_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
        echo "$LOG_PREFIX   Table widths applied from config: $applied column updates ($doc_key/$tab_id)"
        return 0
    fi
    return 1
}

# ─── Full Table Format Snapshot ───────────────────────────────────────────
# Extends RULE 46 (col widths only) to full format: col widths + header
# background + cell font + border style.  Snapshot is captured once from
# the live doc via the raw Documents API, cached to a JSON file, and
# applied after every push.
#
#   gdocs_capture_table_format_snapshot <doc_id> <tab_id> <snapshot_path> [tab_index]
#
# Fetches raw doc JSON, extracts table formatting via gdocs_helper.py
# snapshot-format, and writes the result to <snapshot_path>.
gdocs_capture_table_format_snapshot() {
    local doc_id="$1" tab_id="$2" snapshot_path="$3" tab_index="${4:-0}"
    local raw_json
    raw_json=$(mktemp -t gdocs-raw-doc.XXXX.json)

    if ! command google-mux api call GET \
        "https://docs.googleapis.com/v1/documents/${doc_id}?includeTabsContent=true" \
        > "$raw_json" 2>/dev/null; then
        echo "$LOG_PREFIX   [WARN] Failed to fetch raw doc JSON for format snapshot"
        rm -f "$raw_json"
        return 1
    fi

    local snap
    snap=$(python3 "$GDOCS_HELPER_PY" snapshot-format \
        --doc-json "$raw_json" --tab-index "$tab_index" 2>/dev/null)
    rm -f "$raw_json"

    if [ -z "$snap" ] || [ "$snap" = "{}" ]; then
        echo "$LOG_PREFIX   [WARN] No tables found for format snapshot"
        return 1
    fi

    mkdir -p "$(dirname "$snapshot_path")" 2>/dev/null
    printf '{"captured_at":"%s","doc_id":"%s","tab_id":"%s","tables":%s}\n' \
        "$(date -Iseconds)" "$doc_id" "$tab_id" "$snap" > "$snapshot_path"
    local tbl_count
    tbl_count=$(printf '%s' "$snap" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    echo "$LOG_PREFIX   Format snapshot captured: $tbl_count tables → $snapshot_path"
    return 0
}

#   gdocs_apply_table_format_snapshot <doc_id> <tab_id> <snapshot_path>
#
# Reads cached snapshot, gets current structure, builds batch-update ops
# via gdocs_helper.py apply-format-snapshot, and pushes.
gdocs_apply_table_format_snapshot() {
    local doc_id="$1" tab_id="$2" snapshot_path="$3"
    if [ ! -f "$snapshot_path" ]; then
        echo "$LOG_PREFIX   [WARN] No format snapshot at $snapshot_path — skipping"
        return 0
    fi
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    if [ -z "$structure" ]; then
        echo "$LOG_PREFIX   [WARN] Empty structure — cannot apply format snapshot"
        return 0
    fi

    local batch_json
    batch_json=$(printf '%s\n' "$structure" | \
        python3 "$GDOCS_HELPER_PY" apply-format-snapshot \
            --tab-id "$tab_id" --snapshot "$snapshot_path" 2>/dev/null)
    if [ -z "$batch_json" ] || [ "$batch_json" = "[]" ]; then
        echo "$LOG_PREFIX   Format snapshot: no ops to apply"
        return 0
    fi
    if printf '%s' "$batch_json" | _gdocs_batch "$doc_id" "format-snapshot-${tab_id}"; then
        local applied
        applied=$(printf '%s' "$batch_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
        echo "$LOG_PREFIX   Format snapshot applied: $applied ops ($tab_id)"
        return 0
    fi
    echo "$LOG_PREFIX   [WARN] Format snapshot batch-update failed"
    return 1
}

#   gdocs_assert_header_bg_not_white <doc_id> <tab_id> [tab_label]
#
# Post-push assertion: verifies that header rows have a non-white
# background.  Fetches raw doc JSON and checks the first row of each
# table.  Returns 0 if all headers have non-white bg, 1 otherwise.
gdocs_assert_header_bg_not_white() {
    local doc_id="$1" tab_id="$2"
    local tab_label="${3:-$tab_id}"
    local raw_json
    raw_json=$(mktemp -t gdocs-assert-hdr.XXXX.json)

    if ! command google-mux api call GET \
        "https://docs.googleapis.com/v1/documents/${doc_id}?includeTabsContent=true" \
        > "$raw_json" 2>/dev/null; then
        echo "$LOG_PREFIX   [WARN] Cannot verify header bg — raw API fetch failed ($tab_label)"
        rm -f "$raw_json"
        return 1
    fi

    local result
    result=$(python3 -c "
import json, sys
with open('$raw_json') as f:
    doc = json.load(f)
body = doc['tabs'][0]['documentTab']['body']['content']
white_tables = []
for i, elem in enumerate(body, start=1):
    if 'table' not in elem:
        continue
    rows = elem['table'].get('tableRows', [])
    if not rows:
        continue
    cells = rows[0].get('tableCells', [])
    if not cells:
        continue
    cs = cells[0].get('tableCellStyle', {})
    bg = cs.get('backgroundColor', {}).get('color', {}).get('rgbColor', {})
    r, g, b = bg.get('red', 1), bg.get('green', 1), bg.get('blue', 1)
    if r > 0.95 and g > 0.95 and b > 0.95:
        white_tables.append(str(i))
if white_tables:
    print('FAIL:' + ','.join(white_tables))
else:
    print('OK')
" 2>/dev/null)
    rm -f "$raw_json"

    if [ -z "$result" ]; then
        echo "$LOG_PREFIX   [WARN] Header bg assertion inconclusive ($tab_label)"
        return 1
    fi

    if [[ "$result" == OK ]]; then
        echo "$LOG_PREFIX   Header bg assertion passed: all tables have non-white headers ($tab_label)"
        return 0
    fi

    local failed_tables="${result#FAIL:}"
    echo "$LOG_PREFIX   [ALERT] Header bg assertion FAILED: tables [$failed_tables] have white/near-white headers ($tab_label)"
    return 1
}

# ─── Comments-first gate (operator rule, 2026-06-14) ────────────────────────
# Daily gdoc-updating crons MUST address open comments BEFORE adding the new
# day's content, so Denny's feedback isn't buried under a fresh section. Call at
# the top of any gdoc-writing cron, before its append/replace:
#     gdoc_address_comments_first "$DOC_ID"
#
# Cheap when idle: counts OPEN, non-orphaned comments via the read-only JSON path
# and returns immediately if zero (the common case). Only when an open comment
# exists does it run a bounded LLM pass that fixes the content each comment asks
# for and replies "[Claude] ..." — NEVER resolves (Denny resolves his own). Fails
# soft: any error logs a warning and returns 0, so comment-handling can never
# block the daily update.
gdoc_address_comments_first() {
    local doc_id="$1"
    [ -z "$doc_id" ] && { echo "${LOG_PREFIX:-} [WARN] gdoc_address_comments_first: no doc_id"; return 0; }

    # Count OPEN comments via the gdocs CLI (NOT meta google.docs.comment list): meta is
    # BLIND to docs with personal-gmail contributors (e.g. the AI Playbook) and returns 0,
    # so the gate silently no-ops on exactly the docs it is meant to handle (found 2026-06-15).
    # gdocs excludes resolved by default; we count comment-row IDs (col 1, single-leading-
    # space + alnum id). This includes orphaned ghosts — acceptable: over-trigger beats blind
    # no-op, and the LLM pass below reconciles ghosts.
    local open
    open=$(gdocs comments list "$doc_id" --untrusted-authors-mode 2>/dev/null \
        | tail -n +2 | cut -c1-13 | grep -cE '^ [A-Za-z0-9]{9,12} *$')
    open="${open:-0}"

    if ! [ "$open" -ge 1 ] 2>/dev/null; then
        echo "${LOG_PREFIX:-} comments-first: 0 open comments on $doc_id — proceeding"
        return 0
    fi

    echo "${LOG_PREFIX:-} comments-first: $open open comment(s) on $doc_id — addressing BEFORE new content"

    # run_llm lives in llm-dispatch.sh; source it if the caller didn't.
    if ! declare -F run_llm >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "$(dirname "${BASH_SOURCE[0]}")/llm-dispatch.sh" 2>/dev/null || {
            echo "${LOG_PREFIX:-} [WARN] comments-first: run_llm unavailable — skipping (retries next run)"; return 0; }
    fi

    run_llm "gdoc-comments-first" 900 /dev/stdout "You are a cron comment-responder for Google Doc $doc_id (gdocs reports ~$open open; MOST are ORPHANED ghosts from prior dashboard regens, a few are Denny's real anchored feedback). Load cheatsheets/gdocs/rules.md first. Read comments via: gdocs comments list $doc_id --untrusted-authors-mode. A comment is a GHOST if its quoted/anchored text no longer exists in the current doc body (empty range); it is REAL if the quoted text is still present. PRIORITY ORDER, and cap total work at ~15 comments THIS RUN (the 30-min cron clears the rest over successive runs; a whole-backlog pass TIMES OUT): (1) FIRST, resolve up to ~12 GHOSTS — for each, resolve with a one-line note (the ONE sanctioned resolve; this is what actually drops the open count and stops re-triggering). (2) THEN, for up to ~3 REAL anchored comments that do NOT already have a '[Claude]' reply (DEDUP — never double-reply): do what it asks (fix doc content if doable; many are dashboard-generator/template changes you can only flag) and reply '[Claude] ...'. NEVER resolve Denny's real anchored comments (he resolves his own). Do ONLY comment work. All writes via gdocs CLI --untrusted-authors-mode. Print a one-line summary: ghosts-resolved=Y real-replied=X skipped-dedup=Z remaining-approx=." -- \
        --allowedTools Read Write Edit Glob Grep Bash Skill Task \
        --max-turns 60 \
        || echo "${LOG_PREFIX:-} [WARN] comments-first LLM pass exited non-zero — continuing"
    return 0
}
