#!/usr/bin/env bash
# cron-diff-reviewer-routine-digest.sh - daily morning digest of yesterday's
# auto-review-bot activity, appended to the Routine gdoc.
#
# Renders a 3-5 line markdown summary (drafts produced, verdicts breakdown,
# categories near graduation) and appends it to the Routine gdoc via
# `meta google.docs.append markdown`. Lands at end-of-doc per the gdoc
# append constraint (see cheatsheets/diff/reviewer-comment-automation.md
# - Option B integration note).
#
# Schedule: daily 6:30 AM PT (after cron-nightly-routine-preprocessing
# finishes building today's H1 at ~2:45 AM)
# Crontab entry:
#   30 6 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 120 \
#     diff-reviewer-routine-digest \
#     ~/work/claude/scripts/cron-diff-reviewer-routine-digest.sh \
#     >> ~/logs/diff-reviewer-routine-digest.log 2>&1
#
# Env:
#   DRY_RUN=1 - render to stdout, do not append to gdoc
#   DIGEST_DATE=YYYY-MM-DD - override "yesterday"

set -uo pipefail

DRY_RUN="${DRY_RUN:-0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LIB_DIR="$SCRIPT_DIR/lib"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
DIGEST_DATE="${DIGEST_DATE:-$(date -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d')}"

unset CLAUDECODE 2>/dev/null || true
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cron-alert.sh"

if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "diff-reviewer-routine-digest" "Workspace missing"
    exit 1
fi

ROUTINE_DOC_ID="$(get_doc_id routine 2>/dev/null)"
if [ -z "$ROUTINE_DOC_ID" ]; then
    cron_alert "diff-reviewer-routine-digest" "Routine doc ID not in DAILY-DOCS.json"
    exit 1
fi

# Auto-Review-Bot tab — created 2026-04-29 to keep daemon digests scoped
# to a dedicated tab instead of polluting the main routine flow.
ROUTINE_TAB_ID="$(get_doc_tab routine auto_review_bot 2>/dev/null)"
if [ -z "$ROUTINE_TAB_ID" ]; then
    cron_alert "diff-reviewer-routine-digest" "auto_review_bot tab not in DAILY-DOCS.json routine.tabs"
    exit 1
fi

echo "$LOG_PREFIX === Auto-Review-Bot routine digest for $DIGEST_DATE ==="

# Render digest via the python lib (pure function, no I/O)
DIGEST_TEXT=$(timeout 30 python3 "$HOME/work/claude/private_scripts/lib/diff_reviewer_routine_digest.py" \
    --date "$DIGEST_DATE" 2>&1) || {
    echo "$LOG_PREFIX [ERR] Failed to render digest: $DIGEST_TEXT"
    cron_alert "diff-reviewer-routine-digest" "Render failed"
    exit 1
}

if [ -z "$DIGEST_TEXT" ]; then
    echo "$LOG_PREFIX [ERR] Empty digest output"
    cron_alert "diff-reviewer-routine-digest" "Empty digest"
    exit 1
fi

echo "$LOG_PREFIX Digest content ($(echo "$DIGEST_TEXT" | wc -c) bytes):"
echo "$DIGEST_TEXT" | sed "s|^|$LOG_PREFIX [DIGEST] |"

if [ "$DRY_RUN" = "1" ]; then
    echo "$LOG_PREFIX [DRY] Would append to Routine doc $ROUTINE_DOC_ID tab $ROUTINE_TAB_ID"
    write_heartbeat "diff-reviewer-routine-digest"
    exit 0
fi

# Append to Routine gdoc Auto-Review-Bot tab. --text passes content directly
# (avoids the meta CLI's --file=- stdin issue observed 2026-04-29 - the CLI
# runs remotely and can't see local /tmp paths). --tab-id keeps the digest
# scoped to its dedicated tab.
if append_out=$(meta google.docs.append markdown \
        --id="$ROUTINE_DOC_ID" \
        --tab-id="$ROUTINE_TAB_ID" \
        --text="$DIGEST_TEXT" 2>&1); then
    echo "$LOG_PREFIX Appended to Routine doc Auto-Review-Bot tab: $append_out"
    write_heartbeat "diff-reviewer-routine-digest"
    cron_alert_clear "diff-reviewer-routine-digest"
else
    echo "$LOG_PREFIX [ERR] gdoc append failed: $append_out"
    cron_alert "diff-reviewer-routine-digest" "gdoc append failed"
    exit 1
fi

echo "$LOG_PREFIX === Done ==="
