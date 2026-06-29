#!/usr/bin/env bash
# cron-diff-deep-review.sh - autonomous twice-daily multi-LLM diff reviewer.
#
# Runs Claude + Codex + Gemini in parallel against each diff in Denny's
# reviewer queue, then appends the findings to the Routine gdoc
# (deep_review tab key in DAILY-DOCS.json, tab title "4 Diff Review").
# NEVER posts to Phabricator - per CLAUDE.md.
#
# Naming: deliberately distinct from RADAR (cron-diff-reviewer-comment.sh).
#   RADAR             = rule-based, narrow, fast, posts to Phab.
#   diff-deep-review  = multi-LLM, broad, slow, gdoc only.
#
# Design lives in: private_scripts/lib/diff_deep_review.py (top docstring).
# This wrapper handles: cron-alert plumbing, gdoc append, heartbeat, alerts.
#
# Schedule (registered in private_scripts/setup-claude.sh):
#   0 7,12 * * 1-5  - twice/day, 07:00 + 12:00 PT, Mon-Fri
#
# Crontab entry (auto-installed by setup-claude.sh):
#   0 7,12 * * 1-5 source ~/work/claude/scripts/cron-alert.sh && cron_run \
#     1800 diff-deep-review ~/work/claude/scripts/cron-diff-deep-review.sh \
#     >> ~/logs/diff-deep-review.log 2>&1
#
# Env:
#   DRY_RUN=1  render to stdout, no gdoc append, no state advance
#   FORCE=1    ignore seen-state, re-review every diff
#   LIMIT=N    cap diffs/run (default 5, set by lib)
#   ONLY=D1,D2 review only these diffs (backtest mode)

set -uo pipefail

DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"
LIMIT="${LIMIT:-}"
ONLY="${ONLY:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LIB_PY="$REPO_DIR/private_scripts/lib/diff_deep_review.py"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"

unset CLAUDECODE 2>/dev/null || true
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cron-alert.sh"

if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "diff-deep-review" "Workspace missing"
    exit 1
fi

if [ ! -f "$LIB_PY" ]; then
    cron_alert "diff-deep-review" "Lib missing: $LIB_PY"
    exit 1
fi

ROUTINE_DOC_ID="$(get_doc_id routine 2>/dev/null)"
if [ -z "$ROUTINE_DOC_ID" ]; then
    cron_alert "diff-deep-review" "Routine doc ID not in DAILY-DOCS.json"
    exit 1
fi

ROUTINE_TAB_ID="$(get_doc_tab routine deep_review 2>/dev/null)"
if [ -z "$ROUTINE_TAB_ID" ]; then
    cron_alert "diff-deep-review" "deep_review tab not in DAILY-DOCS.json routine.tabs"
    exit 1
fi

echo "$LOG_PREFIX === Deep diff review (Claude single-LLM · dry_run=$DRY_RUN force=$FORCE) ==="

# Build invocation args for the lib
PY_ARGS=()
[ "$DRY_RUN" = "1" ] && PY_ARGS+=(--dry-run)
[ "$FORCE" = "1" ] && PY_ARGS+=(--force)
[ -n "$LIMIT" ] && PY_ARGS+=(--limit "$LIMIT")
[ -n "$ONLY" ] && PY_ARGS+=(--only "$ONLY")

# Render markdown via the python lib. Timeout: 25 min — three LLM calls per
# diff x up to 5 diffs in parallel, with 3-min per-call cap. Generous.
# stdout = gdoc-bound markdown; stderr = log-only progress notes.
DIGEST_FILE="$(mktemp -t diff-deep-review-XXXXXX.md)"
STDERR_FILE="$(mktemp -t diff-deep-review-err-XXXXXX.log)"
trap 'rm -f "$DIGEST_FILE" "$STDERR_FILE"' EXIT

if ! timeout 1500 python3 "$LIB_PY" "${PY_ARGS[@]}" > "$DIGEST_FILE" 2> "$STDERR_FILE"; then
    echo "$LOG_PREFIX [ERR] Lib invocation failed:"
    [ -s "$STDERR_FILE" ] && sed "s|^|$LOG_PREFIX [LIB-ERR] |" "$STDERR_FILE"
    [ -s "$DIGEST_FILE" ] && sed "s|^|$LOG_PREFIX [LIB-OUT] |" "$DIGEST_FILE"
    cron_alert "diff-deep-review" "Lib render failed"
    exit 1
fi

# Log lib progress notes (stderr) — keeps them out of the gdoc payload
[ -s "$STDERR_FILE" ] && sed "s|^|$LOG_PREFIX [LIB] |" "$STDERR_FILE"

if [ ! -s "$DIGEST_FILE" ]; then
    echo "$LOG_PREFIX No content rendered (empty queue or all diffs cached). Silent ok."
    write_heartbeat "diff-deep-review"
    cron_alert_clear "diff-deep-review"
    exit 0
fi

byte_count=$(wc -c < "$DIGEST_FILE")
echo "$LOG_PREFIX Rendered $byte_count bytes:"
sed "s|^|$LOG_PREFIX [RENDER] |" "$DIGEST_FILE" | head -200

if [ "$DRY_RUN" = "1" ]; then
    echo "$LOG_PREFIX [DRY] Would append to Routine doc $ROUTINE_DOC_ID tab $ROUTINE_TAB_ID"
    write_heartbeat "diff-deep-review"
    cron_alert_clear "diff-deep-review"
    exit 0
fi

# Append (NOT replace - tab has Denny's comments). meta CLI runs remotely so
# pass content via --text, not --file=-.
DIGEST_TEXT="$(cat "$DIGEST_FILE")"
# Push as HTML via gdocs (standalone) per gdocs-rules.md rule 133.
# --index 1 PREPENDS today's run at the top of the tab, preserving prior
# runs below it. Per Denny feedback 2026-06-18: latest date at top, not
# bottom. Matches cheatsheet rule "Update accumulating doc (daily content)"
# pattern (line 60 of gdocs/rules.md).
# Lib outputs the rendered template body (HTML fragment, no <html>/<body>).
if append_out=$(printf '%s' "$DIGEST_TEXT" | gdocs content insert-html \
        --tab-id="$ROUTINE_TAB_ID" \
        --index 1 \
        "$ROUTINE_DOC_ID" - 2>&1); then
    echo "$LOG_PREFIX Prepended HTML to top of '4 Diff Review' tab: $(echo "$append_out" | tail -3)"
    write_heartbeat "diff-deep-review"
    cron_alert_clear "diff-deep-review"
else
    echo "$LOG_PREFIX [ERR] gdoc insert-html failed: $append_out"
    cron_alert "diff-deep-review" "gdoc insert-html failed"
    exit 1
fi

# Post-push: trim history to the most-recent N day-blocks. Per Denny
# feedback (comments JLE/l5U on routine gdoc 2026-06-21): full-replace was
# wiping prior days; switched to prepend-then-trim so the tab keeps a
# rolling window without unbounded growth. KEEP_N=5 day-blocks ≈ 1 week of
# weekday runs (2 runs/day x 5 days = 10 blocks; we trim half of that to
# stay scannable). Comments are preserved — trim uses surgical
# deleteContentRange, never replace.
TRIM_PY="$REPO_DIR/private_scripts/lib/trim_deep_review_history.py"
KEEP_N="${DEEP_REVIEW_KEEP_N:-5}"
if [ -f "$TRIM_PY" ]; then
    if trim_out=$(timeout 60 python3 "$TRIM_PY" \
            "$ROUTINE_DOC_ID" "$ROUTINE_TAB_ID" "$KEEP_N" 2>&1); then
        echo "$LOG_PREFIX History trim: $trim_out"
    else
        echo "$LOG_PREFIX [WARN] History trim failed (non-fatal): $trim_out"
    fi
else
    echo "$LOG_PREFIX [WARN] trim helper missing: $TRIM_PY"
fi

# Post-push: apply proportional column widths to the just-appended tables.
# gdocs-rules.md rule 110 mandates FIXED_WIDTH on every column — equal-width
# default makes tables look sparse and wastes the wide cells (Issue/Fix).
WIDTHS_CFG="$REPO_DIR/config/GDOC-TABLE-WIDTHS.json"
WIDTHS_PY="$REPO_DIR/private_scripts/lib/apply_deep_review_widths.py"
# Count <table> tags in the just-pushed digest so widths apply only touches
# the tables THIS RUN emitted (prepend at index 1 means earlier indices in
# the tab belong to prior runs and have their own styling already).
TABLE_COUNT=$(grep -c '<table' "$DIGEST_FILE" 2>/dev/null || echo 0)
echo "$LOG_PREFIX This run emitted $TABLE_COUNT table(s); widths apply will target the first $TABLE_COUNT."
if [ -f "$WIDTHS_PY" ] && [ -f "$WIDTHS_CFG" ] && [ "$TABLE_COUNT" -gt 0 ]; then
    if widths_out=$(timeout 60 python3 "$WIDTHS_PY" \
            "$ROUTINE_DOC_ID" "$ROUTINE_TAB_ID" "routine" "$WIDTHS_CFG" \
            "$TABLE_COUNT" 2>&1); then
        echo "$LOG_PREFIX Column widths applied: $widths_out"
    else
        echo "$LOG_PREFIX [WARN] Column-width apply failed (non-fatal): $widths_out"
    fi
else
    echo "$LOG_PREFIX [WARN] widths apply skipped (lib/config missing or 0 tables)"
fi

echo "$LOG_PREFIX === Done ==="
