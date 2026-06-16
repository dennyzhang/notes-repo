#!/usr/bin/env bash
# cron-diff-reviewer-comment.sh — auto-review-bot daemon (Phase 0/1 of 4).
#
# Scans Denny's REVIEWER queue (diffs others sent him to review). For each
# new revision since last scan, runs the "major comment" classifier
# (`private_scripts/lib/diff_reviewer_classifier.py`). If any category fires, drafts
# a Phab-style comment and sends it to Pylon's GChat space for Denny to
# review and paste manually.
#
# Phase 2 (graduation) and Phase 3 (autonomous post) are CODE-COMPLETE in
# sibling files but DORMANT — Phase 2 graduation check runs weekly inside
# cron-diff-autolearn.sh; Phase 3 post helper only fires if a category is
# in state/diff-reviewer-graduated.json (empty until Phase 2 promotes one).
#
# Schedule (crontab): every 30 min, 09:00–19:00 PT, Mon-Fri
#   */30 9-19 * * 1-5 source ~/work/claude/scripts/cron-alert.sh && cron_run \
#     900 diff-reviewer-comment ~/work/claude/scripts/cron-diff-reviewer-comment.sh \
#     >> ~/logs/diff-reviewer-comment.log 2>&1
#
# Env:
#   DRY_RUN=1 — classify + log to stdout only; no ledger append, no chat send
#   FORCE=1   — ignore per-version dedup state (re-process all queued diffs)
#
# Killswitches:
#   touch ~/work/claude/state/diff-reviewer-paused → silent exit
#
# Spec: cheatsheets/diff/reviewer-comment-automation.md
# Tests: scripts/tests/test_diff_reviewer.py

set -uo pipefail

DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LIB_DIR="$SCRIPT_DIR/lib"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
LOCK_FILE="/tmp/cron-diff-reviewer-comment.lock"
ACTION_LOG="$HOME/logs/diff-reviewer-comment-audit.log"
STATE_FILE="$REPO_DIR/state/diff-reviewer-state.json"
GRADUATED_FILE="$REPO_DIR/state/diff-reviewer-graduated.json"
PAUSED_MARKER="$REPO_DIR/state/diff-reviewer-paused"
LEDGER_FILE="$REPO_DIR/diff-comment-learnings.md"

# Pylon's 1:1 delivery space — drafts go here for review.
# Externalized to config/DAILY-DOCS.json (gchat_spaces.pylon).
PYLON_SPACE="spaces/$(get_gchat_space pylon)"

unset CLAUDECODE 2>/dev/null || true
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cron-alert.sh"

mkdir -p "$(dirname "$ACTION_LOG")" "$(dirname "$STATE_FILE")"

# ─── Audit log ───────────────────────────────────────────────────────────
ensure_audit_schema_header() {
    if [ -f "$ACTION_LOG" ] && [ -s "$ACTION_LOG" ]; then
        if ! head -1 "$ACTION_LOG" | grep -q '^# schema='; then
            local tmp; tmp=$(mktemp)
            { echo '# schema=v1'; cat "$ACTION_LOG"; } > "$tmp" && mv "$tmp" "$ACTION_LOG"
        fi
    else
        echo '# schema=v1' > "$ACTION_LOG"
    fi
}
ensure_audit_schema_header

audit_log() {
    local diff="$1" event="$2" outcome="$3"
    printf '%s | diff=%-12s | event=%-22s | outcome=%s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$diff" "$event" "$outcome" \
        >> "$ACTION_LOG"
}

# ─── Pre-checks ──────────────────────────────────────────────────────────
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "diff-reviewer-comment" "Workspace missing"
    exit 1
fi

if [ -f "$PAUSED_MARKER" ]; then
    echo "$LOG_PREFIX Paused (marker $PAUSED_MARKER present). Silent exit."
    audit_log "-" "run_skipped" "PAUSED_MARKER"
    write_heartbeat "diff-reviewer-comment"
    exit 0
fi

# ─── Lock ────────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$lock_age" -lt 1500 ]; then
        echo "$LOG_PREFIX Already running (pid $pid), skipping"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

DRAFTS_FILE=$(mktemp /tmp/cron-diff-reviewer-drafts.XXXXXX)
cleanup() {
    rm -f "$LOCK_FILE" "$DRAFTS_FILE"
}
trap cleanup EXIT

[ "$DRY_RUN" = "1" ] && echo "$LOG_PREFIX === DRY RUN MODE — no ledger append, no chat send ==="
[ "$FORCE" = "1" ] && echo "$LOG_PREFIX === FORCE MODE — ignoring per-version dedup ==="
echo "$LOG_PREFIX === Diff Reviewer Comment Daemon (Phase 0/1) ==="
audit_log "-" "run_start" "dry_run=${DRY_RUN}_force=${FORCE}"

# ─── Init state files ────────────────────────────────────────────────────
[ ! -f "$STATE_FILE" ] && echo '{}' > "$STATE_FILE"
[ ! -f "$GRADUATED_FILE" ] && echo '{}' > "$GRADUATED_FILE"

# ─── List reviewer queue ─────────────────────────────────────────────────
# `meta phabricator.diff list --reviewers-include-me --status-is="Needs Review"`
# returns diffs where Denny is a reviewer and the diff is awaiting review.
# Output mode: JSON for stable parsing.
QUEUE_RAW=$(timeout 60 meta phabricator.diff list \
    --reviewers-include-me \
    --status-is="Needs Review" \
    --output=json 2>/dev/null || echo '[]')

DIFF_NUMS=$(echo "$QUEUE_RAW" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
items = data if isinstance(data, list) else data.get('results', data.get('diffs', []))
for d in items or []:
    n = d.get('number') or d.get('diff_number') or ''
    if n:
        print(f'D{n}' if not str(n).startswith('D') else str(n))
" 2>/dev/null || echo "")

if [ -z "$DIFF_NUMS" ]; then
    echo "$LOG_PREFIX No diffs in reviewer queue. Silent exit."
    audit_log "-" "list_queue" "EMPTY"
    write_heartbeat "diff-reviewer-comment"
    cron_alert_clear "diff-reviewer-comment"
    exit 0
fi
diff_count=$(echo "$DIFF_NUMS" | wc -l | tr -d ' ')
echo "$LOG_PREFIX $diff_count diff(s) in reviewer queue"
audit_log "-" "list_queue" "FOUND_${diff_count}"

queried=0
errored=0
skipped_dedup=0
drafts_count=0
auto_posted=0  # Phase 3 — stays 0 until a category graduates

# ─── Per-diff loop ───────────────────────────────────────────────────────
for diff_num in $DIFF_NUMS; do
    queried=$((queried + 1))

    # Fetch metadata (for version dedup, author, line_count, file paths, test_plan)
    meta_raw=$(timeout 30 meta phabricator.diff metadata -n "$diff_num" -o json 2>/dev/null || echo '')
    if [ -z "$meta_raw" ]; then
        errored=$((errored + 1))
        audit_log "$diff_num" "metadata_query" "FAILED"
        continue
    fi

    # Pull fields we need from metadata. Use python for safe JSON access.
    eval "$(echo "$meta_raw" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
def s(k, default=''):
    v = d.get(k, default)
    return str(v).replace(\"'\", \"'\\\\''\")
print(f\"DIFF_VER='{s('latest_version_id')}'\")
print(f\"DIFF_AUTHOR='{s('author')}'\")
print(f\"DIFF_TITLE='{s('title')}'\")
print(f\"DIFF_LINES='{s('line_count', '0')}'\")
print(f\"DIFF_TEST_PLAN='{s('test_plan')}'\")
print(f\"DIFF_REPO='{s('repository_name')}'\")
print(f\"DIFF_IS_LANDING='{s('is_landing', 'false')}'\")
print(f\"DIFF_IS_LANDED='{s('is_landed', 'false')}'\")
")" 2>/dev/null

    # Skip if landing/landed (no point drafting on a diff that's done)
    if [ "${DIFF_IS_LANDING:-false}" = "True" ] || [ "${DIFF_IS_LANDED:-false}" = "True" ]; then
        audit_log "$diff_num" "skip_landing" "is_landing=${DIFF_IS_LANDING}_is_landed=${DIFF_IS_LANDED}"
        continue
    fi

    # Per-version dedup
    if [ "$FORCE" != "1" ]; then
        prev_ver=$(python3 -c "
import json
try:
    s = json.load(open('$STATE_FILE'))
    print(s.get('$diff_num', {}).get('last_version_id', ''))
except Exception:
    print('')
" 2>/dev/null)
        if [ -n "$prev_ver" ] && [ "$prev_ver" = "${DIFF_VER:-}" ]; then
            skipped_dedup=$((skipped_dedup + 1))
            audit_log "$diff_num" "skip_dedup" "version_${DIFF_VER}_unchanged"
            continue
        fi
    fi

    # Fetch CI status + failing-signal names (same shape as cron-diff-signal-monitor)
    ci_raw=$(timeout 30 meta phabricator.diff ci-status -n "$diff_num" -o json 2>/dev/null || echo '{}')
    signals_raw=$(timeout 30 meta phabricator.diff comments --signals-only -n "$diff_num" -o json 2>/dev/null || echo '[]')

    # 2026-05-25: also pull explicit failed-CI-signal NAMES from the signals
    # list endpoint. `comments --signals-only` returns lint/devmate inline
    # advice — it does NOT include build/test failure names. Without this,
    # the classifier never sees the real failure (e.g. test_top_level_lean
    # on D106189268). Merged downstream in python; dedup by name.
    failed_signals_raw=$(timeout 30 meta phabricator.diff.signals list -n "$diff_num" --status=failed -o json 2>/dev/null || echo '[]')

    # Fetch diff file paths (for the test-plan-empty-large-change classifier)
    files_raw=$(timeout 30 meta phabricator.diff files -n "$diff_num" -o json 2>/dev/null || echo '[]')

    # Run classifier — Python returns categories list as JSON
    classifier_out=$(META_RAW="$meta_raw" CI_RAW="$ci_raw" SIGNALS_RAW="$signals_raw" \
        FAILED_SIGNALS_RAW="$failed_signals_raw" \
        FILES_RAW="$files_raw" DIFF_NUM="$diff_num" python3 - <<'PY'
import json, os, sys
sys.path.insert(0, os.path.expanduser("~/work/claude/private_scripts/lib"))
from diff_reviewer_classifier import classify_all, draft_comment_text

def safe_json(env_var, default):
    try:
        return json.loads(os.environ.get(env_var, "") or default)
    except Exception:
        return json.loads(default)

meta = safe_json("META_RAW", "{}")
ci = safe_json("CI_RAW", "{}")
signals_data = safe_json("SIGNALS_RAW", "[]")
files_data = safe_json("FILES_RAW", "[]")

# Failing-signal extraction — matches signal-monitor's extraction shape.
items = signals_data.get("signals", signals_data.get("comments", signals_data)) \
    if isinstance(signals_data, dict) else signals_data
failing_signals = []
seen_names = set()
for s in (items or []):
    if not isinstance(s, dict): continue
    name = s.get("name") or s.get("signal_name") or s.get("title") or s.get("linterName") or s.get("test") or ""
    status = (s.get("status") or s.get("result") or s.get("state") or "").upper()
    if status in ("FAIL", "FAILED", "BROKEN", "ERROR", "RED") and name and name not in seen_names:
        failing_signals.append(name)
        seen_names.add(name)

# 2026-05-25: merge failed-only signals from .signals list endpoint
# (server-filtered by --status=failed). These are CI build/test names
# absent from the comments stream above. Dedup by name across both sources.
failed_data = safe_json("FAILED_SIGNALS_RAW", "[]")
failed_items = failed_data.get("signals", failed_data) \
    if isinstance(failed_data, dict) else failed_data
for s in (failed_items or []):
    if not isinstance(s, dict): continue
    name = s.get("name") or s.get("signal_name") or s.get("title") or s.get("linterName") or s.get("test") or ""
    if name and name not in seen_names:
        failing_signals.append(name)
        seen_names.add(name)

# File path extraction
file_paths = []
fitems = files_data.get("files", files_data) if isinstance(files_data, dict) else files_data
for f in (fitems or []):
    if isinstance(f, dict):
        p = f.get("path") or f.get("file") or ""
    else:
        p = str(f)
    if p:
        file_paths.append(p)

# Inject derived fields the classifier expects
meta["line_count"] = meta.get("line_count", 0)
meta["file_paths"] = file_paths
meta["diff_number"] = os.environ["DIFF_NUM"]

categories = classify_all(meta, ci, failing_signals)

# For each category, render the draft text + return the structured result
out = {
    "categories": categories,
    "drafts": {},
    "context": {
        "non_lint_failing_signals": [
            s for s in failing_signals if not __import__("re").search(
                r"\b(arc\s*lint|arclint|pyre|mypy|autodeps|prettier|black|clang-format|ruff|formatter)\b",
                s, __import__("re").IGNORECASE
            )
        ],
    },
}
for cat in categories:
    out["drafts"][cat] = draft_comment_text(cat, meta, out["context"])
print(json.dumps(out))
PY
)

    if [ -z "$classifier_out" ]; then
        audit_log "$diff_num" "classify" "FAILED_no_output"
        continue
    fi

    # Parse categories list
    cats=$(echo "$classifier_out" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print('\n'.join(d.get('categories', [])))
except Exception:
    sys.exit(0)
" 2>/dev/null)

    if [ -z "$cats" ]; then
        audit_log "$diff_num" "classify" "NO_CATEGORIES"
        # Update state so we don't re-classify until version changes
        if [ "$DRY_RUN" != "1" ]; then
            python3 -c "
import json
s = json.load(open('$STATE_FILE'))
s.setdefault('$diff_num', {})
s['$diff_num']['last_version_id'] = '${DIFF_VER:-}'
s['$diff_num']['last_scan_clean_at'] = '$(date -Iseconds)'
json.dump(s, open('$STATE_FILE', 'w'), indent=2)
" 2>/dev/null || true
        fi
        continue
    fi

    # For each fired category, log + draft + accumulate to DRAFTS_FILE
    while IFS= read -r cat; do
        [ -z "$cat" ] && continue
        draft_text=$(echo "$classifier_out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('drafts', {}).get('$cat', ''))
" 2>/dev/null)

        # Phase 3 graduation check — is this category autonomous?
        is_graduated=$(python3 -c "
import json
try:
    g = json.load(open('$GRADUATED_FILE'))
    print('1' if '$cat' in g else '0')
except Exception:
    print('0')
" 2>/dev/null)

        if [ "$is_graduated" = "1" ]; then
            # Phase 3 path — autonomous post via post helper
            audit_log "$diff_num" "graduated_route" "category=$cat"
            if [ "$DRY_RUN" = "1" ]; then
                echo "$LOG_PREFIX [DRY] Would auto-post on $diff_num ($cat): $draft_text"
            else
                if python3 "$HOME/work/claude/private_scripts/lib/diff_reviewer_post.py" \
                    --diff "$diff_num" \
                    --category "$cat" \
                    --text "$draft_text" \
                    --killswitch-target "$diff_num" \
                    >>"$ACTION_LOG" 2>&1; then
                    audit_log "$diff_num" "auto_post" "OK_$cat"
                    auto_posted=$((auto_posted + 1))
                else
                    audit_log "$diff_num" "auto_post" "FAILED_$cat"
                fi
            fi
        else
            # Phase 0/1 path — accumulate to drafts batch for chat send
            drafts_count=$((drafts_count + 1))
            url="https://www.internalfb.com/diff/$diff_num"
            {
                printf '\n────────────────────\n'
                printf '*%d. %s* (author: %s) — `%s`\n' \
                    "$drafts_count" "$diff_num" "${DIFF_AUTHOR:-?}" "$cat"
                printf '> %s\n' "$draft_text"
                printf '%s\n' "$url"
            } >> "$DRAFTS_FILE"

            audit_log "$diff_num" "draft_queued" "category=$cat"

            # Append DRAFTED row to ledger (unless dry-run)
            if [ "$DRY_RUN" != "1" ]; then
                NOTES_VAL="version=${DIFF_VER:-?} title=${DIFF_TITLE:-?}" \
                    python3 - "$diff_num" "${DIFF_AUTHOR:-?}" "$cat" <<'PY'
import os, sys
sys.path.insert(0, os.path.expanduser("~/work/claude/private_scripts/lib"))
from diff_reviewer_ledger import append_row, ensure_ledger
ensure_ledger()
append_row(
    diff_num=sys.argv[1],
    author=sys.argv[2],
    category=sys.argv[3],
    action="DRAFTED",
    notes=os.environ.get("NOTES_VAL", ""),
)
PY
            fi
        fi
    done <<< "$cats"

    # Update state with new version_id (post-classification)
    if [ "$DRY_RUN" != "1" ]; then
        cats_json=$(echo "$cats" | python3 -c "
import sys, json
print(json.dumps([c for c in sys.stdin.read().splitlines() if c]))
")
        python3 -c "
import json
s = json.load(open('$STATE_FILE'))
s['$diff_num'] = {
    'last_version_id': '${DIFF_VER:-}',
    'drafted_at': '$(date -Iseconds)',
    'categories': $cats_json,
}
json.dump(s, open('$STATE_FILE', 'w'), indent=2)
" 2>/dev/null || true
    fi
done

echo "$LOG_PREFIX Summary: queried=$queried drafted=$drafts_count auto_posted=$auto_posted skipped_dedup=$skipped_dedup errored=$errored"
audit_log "-" "run_summary" "queried=${queried}_drafts=${drafts_count}_posted=${auto_posted}_skipped=${skipped_dedup}_err=${errored}"

# ─── Send batched draft message to Pylon space ───────────────────────────
if [ "$drafts_count" -eq 0 ]; then
    [ "$auto_posted" -gt 0 ] && echo "$LOG_PREFIX $auto_posted comment(s) auto-posted (graduated categories)."
    write_heartbeat "diff-reviewer-comment"
    cron_alert_clear "diff-reviewer-comment"
    exit 0
fi

message="🤖 *Auto-Review-Bot — ${drafts_count} major-comment draft(s)*

Reply with verdict per draft:
\`/post DXXXX\` — paste as-is
\`/edit DXXXX\` — I'll edit, then paste
\`/skip DXXXX\` — false positive, don't post
\`/harm DXXXX\` — would have damaged trust (resets graduation)
$(cat "$DRAFTS_FILE")"

if [ "$DRY_RUN" = "1" ]; then
    echo "$LOG_PREFIX [DRY] Would send to $PYLON_SPACE:"
    echo "$message" | sed "s|^|$LOG_PREFIX [DRY-MSG] |"
    write_heartbeat "diff-reviewer-comment"
    exit 0
fi

if echo "$message" | timeout 30 google-mux chat send "$PYLON_SPACE" - >/dev/null 2>&1; then
    audit_log "-" "drafts_send" "OK_${drafts_count}"
    cron_alert_clear "diff-reviewer-comment"
else
    audit_log "-" "drafts_send" "FAILED_${drafts_count}_unreported"
    cron_alert "diff-reviewer-comment" "GChat send failed, $drafts_count drafts unreported"
fi

write_heartbeat "diff-reviewer-comment"
echo "$LOG_PREFIX === Done ==="
