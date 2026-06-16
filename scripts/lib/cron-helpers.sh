#!/usr/bin/env bash
# cron-helpers.sh — Shared utilities for cron scripts.
#
# Source after cron-alert.sh and lib/gdocs_lib.sh:
#   source "$SCRIPT_DIR/cron-alert.sh"
#   source "$SCRIPT_DIR/lib/gdocs_lib.sh"
#   source "$SCRIPT_DIR/lib/cron-helpers.sh"

[ -n "${__CRON_HELPERS_SOURCED:-}" ] && return 0
__CRON_HELPERS_SOURCED=1

# This file lives in scripts/lib/, so SCRIPT_DIR resolves to scripts/lib —
# callers pass their own SCRIPT_DIR pointing at scripts/, so prefer that.
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_PREFIX="${LOG_PREFIX:-$(date '+%Y-%m-%d %H:%M')}"

# ─── restore_table_format ────────────────────────────────────────────────
# Snapshot-based table format preservation across pushes.
#
# Google Docs resets column widths to uniform equal-width after row
# insertion. This function restores the known-good format from a cached
# snapshot, then captures a fresh snapshot for next run.
#
# Flow:
#   1. Apply cached format snapshot from previous run (widths + header
#      style + font + borders via updateTableColumnProperties)
#   2. Fall back to config-driven widths (GDOC-TABLE-WIDTHS.json) if
#      no snapshot exists (first run)
#   3. Capture fresh snapshot for next run
#   4. Assert no table has uniform equal-width columns
#
# Canonical 5-column schema for the Cron Fleet table:
#   Job | Status | Runs | Last Run (Detail) | Pass Rate (Duration)
#
# Args:
#   $1 — doc_id
#   $2 — tab_id
#   $3 — snapshot_path (JSON file, e.g. ~/work/claude/state/...)
#   $4 — doc_key (for config fallback + logging)
#
# Returns 0 on success, 1 if the equal-width assertion fails.
restore_table_format() {
    local doc_id="$1" tab_id="$2" snapshot_path="$3" doc_key="${4:-unknown}"

    # Step 1: Apply cached snapshot OR config-driven widths
    if [ -f "$snapshot_path" ]; then
        echo "$LOG_PREFIX   Restoring table format from cached snapshot..."
        gdocs_apply_table_format_snapshot "$doc_id" "$tab_id" "$snapshot_path"
    else
        echo "$LOG_PREFIX   No cached format snapshot — falling back to config-driven widths"
        gdocs_apply_table_widths "$doc_id" "$tab_id" "$doc_key" || true
    fi

    # Step 2: Capture fresh snapshot for next run
    gdocs_capture_table_format_snapshot "$doc_id" "$tab_id" "$snapshot_path" || true

    # Step 3: Assert columns are NOT uniform equal-width
    local structure
    structure=$(gdocs_get_structure "$doc_id" "$tab_id")
    if [ -z "$structure" ]; then
        echo "$LOG_PREFIX   [WARN] Cannot verify column widths — empty structure"
        return 0
    fi

    local equal_issues
    equal_issues=$(echo "$structure" | python3 -c "
import sys, re
issues = []
table_idx = 0
for line in sys.stdin:
    line = line.strip()
    m = re.match(r'\[(\d+)-(\d+)\] TABLE: (\d+)x(\d+)', line)
    if m:
        table_idx += 1
    cm = re.search(r'colWidths=\[([^\]]+)\]', line)
    if cm:
        widths = [float(w.strip()) for w in cm.group(1).split(',')]
        if len(widths) >= 2 and len(set(round(w, 1) for w in widths)) == 1:
            issues.append(f'table {table_idx}: all {len(widths)} cols equal ({widths[0]:.1f}pt)')
for i in issues:
    print(i)
" 2>/dev/null || true)

    if [ -n "$equal_issues" ]; then
        echo "$LOG_PREFIX   [WARN] ASSERTION FAILED — tables with uniform equal-width columns:"
        echo "$equal_issues" | while read -r _issue; do
            echo "$LOG_PREFIX     $_issue"
        done
        return 1
    fi

    echo "$LOG_PREFIX   Column width assertion passed: no tables have uniform equal-width columns"
    return 0
}
