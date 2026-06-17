#!/usr/bin/env bash
# cron-diff-signal-monitor.sh — Asymmetric autonomy diff signal monitor (Posture B).
#
# Per non-green open diff, classify the failure and act accordingly:
#
#   CLASS 1 — MECHANICAL (silent auto-fix, no ping)
#     Lint warnings / formatter drift / stale rebase / generated-file drift.
#     Workflow: sl goto → sl pull --rebase → arc f → sl amend → jf submit.
#     Demoted to CLASS 3 if working copy is dirty (we won't touch user WIP).
#
#   CLASS 2 — TEST/BUILD FAILURE (safe attempts, escalate on failure)
#     Try ONLY: re-trigger deferred CI in case of flake.
#     NEVER mutate test code, assertions, expected values, or impl logic.
#     Always escalates so Denny knows the signal is red.
#
#   CLASS 3 — UNCERTAIN: escalate immediately. Conservative posture.
#
# Every action (classification, fix attempt, success, failure, demotion,
# escalation) is appended to ~/logs/diff-signal-monitor.log with a stable
# parseable line format so Denny can audit silent autonomous mutations
# after the fact:
#   ISO_TIMESTAMP | diff=DXXX | class=N | action=NAME | outcome=RESULT
#
# Schedule: Every 8h (00:00, 08:00, 16:00 PT)
#   0 0,8,16 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 1200 \
#     diff-signal-monitor ~/work/claude/scripts/cron-diff-signal-monitor.sh \
#     >> ~/logs/diff-signal-monitor.log 2>&1
#
# Env: DRY_RUN=1 — classify + log only; no mutations, no chat send.

set -uo pipefail

DRY_RUN="${DRY_RUN:-0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
FBSOURCE="$HOME/fbsource"
CONFIGERATOR="$HOME/configerator"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
LOCK_FILE="/tmp/cron-diff-signal-monitor.lock"
ACTION_LOG="$HOME/logs/diff-signal-monitor.log"

# Pylon's 1:1 delivery space (work instance). Externalized to config/DAILY-DOCS.json
# (gchat_spaces.pylon) — see history for the 2026-05-22 migration off the dead space.
PYLON_SPACE="spaces/$(get_gchat_space pylon)"

# ─── Diff Flywheel (Stage 1/3/4) ─────────────────────────────────────────
# All flywheel work is gated by FLYWHEEL_ENABLED. Cutover 2026-04-23: default
# is ON. Manifest writing + attribution scan + JSON-classifier fallback are
# active. Set FLYWHEEL_ENABLED=0 explicitly to disable (kill switch).
FLYWHEEL_ENABLED="${FLYWHEEL_ENABLED:-1}"
FLYWHEEL_DIR="$REPO_DIR/state/diff-flywheel"
FLYWHEEL_LIVE="$FLYWHEEL_DIR/live.json"
FLYWHEEL_ESCALATIONS_DIR="$FLYWHEEL_DIR/escalations"
FLYWHEEL_LEARNING_EVENTS="$FLYWHEEL_DIR/learning-events.jsonl"
FLYWHEEL_CLASSIFY_PY="$HOME/work/claude/private_scripts/lib/diff-flywheel-classify.py"
NARROW_FIX_PY="$HOME/work/claude/private_scripts/lib/pyre_narrow_fix.py"
SIGNAL_EVAL_PY="$HOME/work/claude/private_scripts/lib/diff_signal_eval.py"

# ─── Signal-list pagination (D106859590 incident, 2026-05-30) ────────────
# `meta phabricator.diff.signals list` returns only the first 100 rows by
# default. Large diffs (D106859590 had 1683 signals) push the one failing
# land-blocker far past row 100 — and the unmanaged-pathway copy of a target
# (name suffixed `- unmanaged`) is exactly where Pyre type-check failures hide.
# Without --limit the broad parse saw zero failures while ci-status said
# failed=1, so the blocker was silently missed. Pull the full set so BOTH
# pathways (managed + unmanaged) are always ingested. Bump if a diff ever
# legitimately exceeds this many signals.
SIGNALS_LIMIT="${SIGNALS_LIMIT:-2000}"

# ─── CLASS 1.5: Pyre Optional-narrowing autofix (2026-05-30) ─────────────
# Pyre [16] "Optional has no attribute X" errors have a deterministic,
# behavior-preserving fix: wrap the receiver in none_throws(). When a
# type-check CLASS 2 signal is hit, we try this BEFORE the retrigger path:
#   goto -> pull --rebase -> arc pyre (discover [16] errors) -> none_throws
#   wrap via pyre_narrow_fix.py -> arc lint -a -> RE-RUN arc pyre. Only
#   amend + submit if it goes GREEN; otherwise revert + fall through to the
#   normal CLASS 2 retrigger/escalate. The re-pyre rail guarantees a wrong
#   or partial fix can never land. Bounded to NARROWFIX_MAX_PER_RUN per run
#   (pyre is expensive). Set CLASS15_NARROWFIX_ENABLED=0 to disable.
CLASS15_NARROWFIX_ENABLED="${CLASS15_NARROWFIX_ENABLED:-1}"
NARROWFIX_MAX_PER_RUN="${NARROWFIX_MAX_PER_RUN:-2}"
narrowfix_attempts=0

# ─── Land-Retrigger (D104348699 incident, 2026-05-08) ───────────────────
# A diff with publish_when_ready can be CI-green yet have land_job_status=
# LAND_RECENTLY_FAILED — the auto-land verdict failed (often transient).
# CI-status checks alone miss this — we must inspect metadata's
# land_job_status. Auto-retry with `meta phabricator.diff land` if the
# diff is otherwise landable. Set LAND_RETRIGGER_ENABLED=0 to disable.
LAND_RETRIGGER_ENABLED="${LAND_RETRIGGER_ENABLED:-1}"

# ─── Metadata Hygiene (2026-05-21) ───────────────────────────────────────
# Catches stale Phab metadata that jf submit does NOT auto-clear:
#   - depends_on field stale after `sl rebase -r <hash> -d remote/master`.
# Detection is read-only (sl log); fix calls meta phabricator.diff
# remove-dependency. Works across fbsource + configerator. Set to 0 to
# disable.
METADATA_HYGIENE_ENABLED="${METADATA_HYGIENE_ENABLED:-1}"

# ─── Auto-Rebase Stale Parents (2026-05-21) ──────────────────────────────
# If Phab's commit parent is on remote/master but trunk has advanced,
# rebase to fresh trunk + resubmit. WC-mutating: gated by per-repo WC
# clean check + global METADATA_HYGIENE_ENABLED. On merge conflict:
# abort cleanly and escalate (NEVER leave repo in unfinished rebase).
# Set AUTO_REBASE_ENABLED=0 to disable independently.
AUTO_REBASE_ENABLED="${AUTO_REBASE_ENABLED:-1}"
# Tracks which repos have been pulled this run (avoid repeat sl pull).
declare -A REPO_PULLED 2>/dev/null || true

# ─── CI Retrigger Defer (2026-05-21) ─────────────────────────────────────
# CLASS 2 (test/build) failures used to retrigger CI and immediately
# escalate — pinging boss for every flake even when retrigger succeeded.
# Now: retrigger + write a pending marker + DON'T escalate this run.
# Next cron run: if green → silent recovery (counted as fixed). If still
# red on same version → real failure, escalate then. Markers >36h are
# GC'd (forced escalation). Set CI_RETRIGGER_DEFER_ENABLED=0 to disable.
CI_RETRIGGER_DEFER_ENABLED="${CI_RETRIGGER_DEFER_ENABLED:-1}"
CI_RETRIGGER_PENDING_DIR="$REPO_DIR/state/diff-flywheel/ci-retrigger-pending"
CI_RETRIGGER_MAX_AGE_SEC=129600  # 36h

# ─── Shelve-Around-Autofix (2026-05-21) ─────────────────────────────────
# If fbsource WC is dirty at cron time, CLASS 1 autofix is globally
# demoted to CLASS 3 — every auto-fixable diff escalates instead. Fix:
# `sl shelve` the WIP, run the cron with WC clean, `sl unshelve` at exit.
# On unshelve conflict: abort + leave shelf in store + emit recovery alert.
# Set SHELVE_AUTOFIX_ENABLED=0 to disable.
SHELVE_AUTOFIX_ENABLED="${SHELVE_AUTOFIX_ENABLED:-1}"
SHELF_NAME=""  # set if we shelve; consumed by cleanup trap on exit

unset CLAUDECODE 2>/dev/null || true

# shellcheck disable=SC1091
source "$SCRIPT_DIR/cron-alert.sh"

mkdir -p "$(dirname "$ACTION_LOG")"

# Stage 1 schema versioning — write `# schema=v1` header on first line so
# Stage 2 distillation can refuse to parse mismatched schemas after future
# format changes. Idempotent: only writes if missing.
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

# audit_log — every classified action goes here. One line per action.
audit_log() {
    local diff="$1" cls="$2" action="$3" outcome="$4"
    printf '%s | diff=%-12s | class=%s | action=%-20s | outcome=%s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$diff" "$cls" "$action" "$outcome" \
        >> "$ACTION_LOG"
}

# ─── Stage 4 helpers (no-op when FLYWHEEL_ENABLED!=1) ────────────────────
# Both helpers degrade silently if flywheel state dir is missing — the daily
# cron MUST keep working even if the flywheel implementation is half-broken.

# Write escalation manifest at escalation time. One file per open escalation,
# removed by attribution scan once Denny resolves the diff.
write_escalation_manifest() {
    [ "$FLYWHEEL_ENABLED" != "1" ] && return 0
    local diff_num="$1" signal_name="$2" cls="$3" failed="$4" warnings="$5" passed="$6"
    mkdir -p "$FLYWHEEL_ESCALATIONS_DIR" 2>/dev/null || return 0

    local meta_json
    meta_json=$(timeout 15 meta phabricator.diff metadata -n "$diff_num" -o json 2>/dev/null || echo '{}')

    DIFF_NUM="$diff_num" SIG_NAME="$signal_name" CLS="$cls" \
    FAILED="$failed" WARNINGS="$warnings" PASSED="$passed" \
    META_JSON="$meta_json" OUT_PATH="$FLYWHEEL_ESCALATIONS_DIR/$diff_num.json" \
    python3 -c '
import json, os
from datetime import datetime, timezone

try:
    meta = json.loads(os.environ.get("META_JSON", "{}") or "{}")
except Exception:
    meta = {}

manifest = {
    "diff": os.environ["DIFF_NUM"],
    "escalated_at": datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M:%S%z"),
    "signal_name": os.environ["SIG_NAME"],
    "class_inferred": int(os.environ["CLS"]),
    "commit_hash_at_escalation": meta.get("commit_hash", ""),
    "version_at_escalation": str(meta.get("latest_version_number", "") or meta.get("version", "") or ""),
    "author_at_escalation": meta.get("author", ""),
    "status_at_escalation": meta.get("status", ""),
    "ci_state_at_escalation": {
        "failed": int(os.environ["FAILED"]),
        "warnings": int(os.environ["WARNINGS"]),
        "passed": int(os.environ["PASSED"]),
    },
}
with open(os.environ["OUT_PATH"], "w") as f:
    json.dump(manifest, f, indent=2)
' 2>/dev/null || true
}

# Pre-loop attribution scan. For each open manifest:
#   - Same hash + still red    → keep waiting
#   - Hash changed + green + author=denny → emit learning-event, drop manifest
#   - Diff abandoned/landed without going green → drop manifest, no learning
#   - Manifest >30d old        → archive
flywheel_attribution_scan() {
    [ "$FLYWHEEL_ENABLED" != "1" ] && return 0
    [ ! -d "$FLYWHEEL_ESCALATIONS_DIR" ] && return 0

    local manifest scanned=0 resolved=0 archived=0 dropped=0
    shopt -s nullglob
    for manifest in "$FLYWHEEL_ESCALATIONS_DIR"/D*.json; do
        scanned=$((scanned + 1))

        local mfile_age_days
        mfile_age_days=$(( ($(date +%s) - $(stat -c %Y "$manifest" 2>/dev/null || echo "$(date +%s)")) / 86400 ))

        if [ "$mfile_age_days" -gt 30 ]; then
            mkdir -p "$FLYWHEEL_ESCALATIONS_DIR/_archive" 2>/dev/null
            mv "$manifest" "$FLYWHEEL_ESCALATIONS_DIR/_archive/" 2>/dev/null && archived=$((archived + 1))
            continue
        fi

        local diff_num
        diff_num=$(basename "$manifest" .json)

        local cur_status_json cur_meta_json
        cur_status_json=$(timeout 30 meta phabricator.diff ci-status -n "$diff_num" -o json 2>/dev/null || echo '{}')
        cur_meta_json=$(timeout 15 meta phabricator.diff metadata -n "$diff_num" -o json 2>/dev/null || echo '{}')

        # LIVE land-blocking re-evaluation (D106859590 fix, 2026-05-30):
        # the ci-status aggregate (failed/warnings) can transiently read green
        # while an unmanaged-pathway Pyre type-check is still FAILED — exactly
        # how the scan emitted a bogus human-fix learning event. Re-query the
        # real failed-signal set per current version (BOTH pathways, untruncated
        # via --limit) and count blockers. This is the source of truth for
        # "is this version actually clean", overriding the stale aggregate.
        local cur_failed_json cur_blockers
        cur_failed_json=$(timeout 60 meta phabricator.diff.signals list -n "$diff_num" \
            --status=failed --limit="$SIGNALS_LIMIT" -o json 2>/dev/null || echo '[]')
        cur_blockers=$(echo "$cur_failed_json" | timeout 15 python3 "$SIGNAL_EVAL_PY" --count 2>/dev/null || echo 0)
        case "$cur_blockers" in ''|*[!0-9]*) cur_blockers=0 ;; esac

        # Decide outcome in python — easier than juggling JSON in shell.
        local decision
        decision=$(MANIFEST_PATH="$manifest" \
                   CUR_STATUS_JSON="$cur_status_json" \
                   CUR_META_JSON="$cur_meta_json" \
                   CUR_BLOCKERS="$cur_blockers" \
                   LEARNING_EVENTS="$FLYWHEEL_LEARNING_EVENTS" \
                   python3 -c '
import json, os, sys
from datetime import datetime

try:
    manifest = json.load(open(os.environ["MANIFEST_PATH"]))
except Exception:
    print("KEEP")
    sys.exit(0)

try:
    cur_status = json.loads(os.environ.get("CUR_STATUS_JSON", "{}") or "{}")
except Exception:
    cur_status = {}
try:
    cur_meta = json.loads(os.environ.get("CUR_META_JSON", "{}") or "{}")
except Exception:
    cur_meta = {}

def to_int(v):
    try: return int(v)
    except: return 0

cur_failed = to_int(cur_status.get("failed", 0))
cur_warnings = to_int(cur_status.get("warnings", 0))
# Live per-version land-blocker count from the real failed-signal set (both
# pathways, untruncated) — overrides a transiently-green ci-status aggregate.
live_blockers = to_int(os.environ.get("CUR_BLOCKERS", "0"))
cur_hash = cur_meta.get("commit_hash", "") or ""
cur_author = (cur_meta.get("author", "") or "").lower()
cur_status_str = (cur_meta.get("status", "") or "").lower()
is_landed = str(cur_meta.get("is_landed", "false")).lower() == "true"
is_closed = str(cur_meta.get("is_closed", "false")).lower() == "true"

orig_hash = manifest.get("commit_hash_at_escalation", "") or ""
# A diff is non-green if EITHER the aggregate is red OR the live signal set
# still carries a land-blocker. The latter catches the D106859590 unmanaged-
# Pyre miss, where ci-status read failed=0 but a `- unmanaged` type-check was
# still Failed — preventing a false human-fix learning event.
non_green = (cur_failed > 0) or (cur_warnings > 0) or (live_blockers > 0)

# Drop if abandoned/landed without becoming green
if "abandon" in cur_status_str or is_closed or is_landed:
    if non_green:
        print("DROP")
        sys.exit(0)

# Same hash, still red → wait
if cur_hash and cur_hash == orig_hash and non_green:
    print("KEEP")
    sys.exit(0)

# Hash changed AND now green AND author is denny → learn
if cur_hash and orig_hash and cur_hash != orig_hash and not non_green and "dennyzhang" in cur_author:
    # Per-version freshness: the manifest signal_name is FROZEN at escalation
    # time and can be stale by resolution (the diff may have churned through
    # many versions, and the escalated signal may have been a transient
    # WARNING — e.g. a flaky GPU test — not the actual land-blocker). We can
    # no longer see which signal blocked the last red version (the diff is
    # green now), so grade confidence instead of silently trusting it:
    #   - WARNING-only escalation (failed==0 at escalation) => low confidence.
    #     Warning signals are flaky-prone; attributing a human fix to one and
    #     promoting it as an escalate pattern pollutes the corpus (D106859590
    #     credited the flaky ifr_silvertorch GPU test, masking the real
    #     unmanaged-pyre land-blocker).
    #   - version churn (escalation version != resolved version) is recorded
    #     so the distill stage can weight cross-version attributions.
    esc_failed = to_int(manifest.get("ci_state_at_escalation", {}).get("failed", 0))
    ver_at_esc = str(manifest.get("version_at_escalation", "") or "")
    ver_resolved = str(cur_meta.get("latest_version_number", "") or cur_meta.get("version", "") or "")
    confidence = "low" if esc_failed == 0 else "high"
    event = {
        "event_type": "human_post_escalation_fix",
        "diff": manifest.get("diff", ""),
        "signal_name": manifest.get("signal_name", ""),
        "class_inferred_at_escalation": manifest.get("class_inferred", 3),
        "before_commit": orig_hash,
        "after_commit": cur_hash,
        "escalated_at": manifest.get("escalated_at", ""),
        "resolved_at": datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M:%S%z"),
        "version_at_escalation": ver_at_esc,
        "resolved_version": ver_resolved,
        "version_churned": bool(ver_at_esc and ver_resolved and ver_at_esc != ver_resolved),
        "escalation_failed_count": esc_failed,
        "attribution_confidence": confidence,
        "live_blockers_at_resolution": live_blockers,
    }
    with open(os.environ["LEARNING_EVENTS"], "a") as f:
        f.write(json.dumps(event) + "\n")
    print("LEARN")
    sys.exit(0)

# Diff is now green but couldnt attribute (hash unchanged, or unknown author).
# Drop manifest — we wont learn from this one but we shouldnt keep checking forever.
if not non_green:
    print("DROP_GREEN")
    sys.exit(0)

print("KEEP")
' 2>/dev/null || echo "KEEP")

        case "$decision" in
            LEARN)
                rm -f "$manifest"
                resolved=$((resolved + 1))
                audit_log "$diff_num" "-" "flywheel_attr" "LEARNED_human_fix"
                ;;
            DROP)
                rm -f "$manifest"
                dropped=$((dropped + 1))
                audit_log "$diff_num" "-" "flywheel_attr" "DROPPED_abandoned_or_landed"
                ;;
            DROP_GREEN)
                rm -f "$manifest"
                dropped=$((dropped + 1))
                audit_log "$diff_num" "-" "flywheel_attr" "DROPPED_green_unattributed"
                ;;
            KEEP|*)
                ;;
        esac
    done
    shopt -u nullglob

    if [ "$scanned" -gt 0 ]; then
        audit_log "-" "-" "flywheel_attr_summary" "scanned=${scanned}_learned=${resolved}_dropped=${dropped}_archived=${archived}"
    fi
}

# ─── Pre-checks ───────────────────────────────────────────────────────────
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "diff-signal-monitor" "Workspace missing"
    exit 1
fi

if [ ! -d "$FBSOURCE/.sl" ] && [ ! -d "$FBSOURCE/.hg" ]; then
    cron_alert "diff-signal-monitor" "fbsource not an sl/hg repo — autofix path unavailable"
    exit 1
fi

# ─── Lock ─────────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$lock_age" -lt 1800 ]; then
        echo "$LOG_PREFIX Already running (pid $pid), skipping"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

ESCALATIONS_FILE=$(mktemp /tmp/cron-diff-signal-escalations.XXXXXX)
ORIG_PWD="$(pwd)"
ORIG_REV=""

cleanup() {
    if [ -n "$ORIG_REV" ] && [ "$DRY_RUN" != "1" ]; then
        cd "$FBSOURCE" 2>/dev/null && \
            timeout 30 sl goto "$ORIG_REV" \
                --reason "diff-signal-monitor restore HEAD on exit - sl help goto" \
                >/dev/null 2>&1 || true
    fi
    if [ -n "$SHELF_NAME" ] && [ "$DRY_RUN" != "1" ]; then
        cd "$FBSOURCE" 2>/dev/null || true
        if unshelve_out=$(timeout 60 sl unshelve -n "$SHELF_NAME" \
                --reason "diff-signal-monitor restore shelved WIP on exit - sl help unshelve" 2>&1); then
            audit_log "-" "-" "shelve_restore" "OK_${SHELF_NAME}"
        else
            echo "$LOG_PREFIX [WARN] unshelve failed: $unshelve_out"
            timeout 30 sl unshelve --abort \
                --reason "diff-signal-monitor abort failed unshelve - sl help unshelve" >/dev/null 2>&1 || true
            cron_alert "diff-signal-monitor" \
                "Unshelve conflict — your WIP is preserved as shelf '$SHELF_NAME'. Restore manually: cd $FBSOURCE && sl unshelve -n $SHELF_NAME --reason 'restore pylon-shelved WIP - sl help unshelve'"
            audit_log "-" "-" "shelve_restore" "FAILED_${SHELF_NAME}"
        fi
    fi
    cd "$ORIG_PWD" 2>/dev/null || true
    rm -f "$LOCK_FILE" "$ESCALATIONS_FILE"
}
trap cleanup EXIT

[ "$DRY_RUN" = "1" ] && echo "$LOG_PREFIX === DRY RUN MODE — no mutations, no chat send ==="
echo "$LOG_PREFIX === Diff Signal Monitor (asymmetric autonomy, Posture B) ==="
audit_log "-" "-" "run_start" "dry_run=$DRY_RUN"

# ─── Working-copy state ──────────────────────────────────────────────────
# Refuse autonomous CLASS 1 mutations if WC dirty. Capture original commit
# so we can restore it after any goto.
WC_CLEAN=0
cd "$FBSOURCE"
capture_orig_rev() {
    ORIG_REV=$(timeout 15 sl log -r . -T '{node}' \
        --reason "diff-signal-monitor capture HEAD - sl help log" 2>/dev/null || echo "")
}
if sl_status_out=$(timeout 30 sl status --reason "diff-signal-monitor pre-check WC clean - sl help status" 2>/dev/null); then
    if [ -z "$sl_status_out" ]; then
        WC_CLEAN=1
        capture_orig_rev
        echo "$LOG_PREFIX WC clean at ${ORIG_REV:0:12} — CLASS 1 autonomy enabled"
        audit_log "-" "-" "wc_check" "CLEAN_at_${ORIG_REV:0:12}"
    elif [ "$SHELVE_AUTOFIX_ENABLED" = "1" ] && [ "$DRY_RUN" != "1" ]; then
        candidate_shelf="pylon-autofix-$(date +%s)"
        if shelve_out=$(timeout 60 sl shelve -n "$candidate_shelf" -u \
                --reason "diff-signal-monitor shelve WIP to enable CLASS 1 autofix - sl help shelve" 2>&1); then
            SHELF_NAME="$candidate_shelf"
            WC_CLEAN=1
            capture_orig_rev
            echo "$LOG_PREFIX WC dirty — shelved as '$SHELF_NAME', CLASS 1 autonomy enabled"
            audit_log "-" "-" "wc_check" "SHELVED_${SHELF_NAME}_at_${ORIG_REV:0:12}"
        else
            echo "$LOG_PREFIX [WARN] sl shelve failed: $shelve_out — CLASS 1 will demote to CLASS 3"
            audit_log "-" "-" "wc_check" "SHELVE_FAILED_demote_CLASS1"
        fi
    else
        echo "$LOG_PREFIX WC dirty — CLASS 1 will demote to CLASS 3"
        audit_log "-" "-" "wc_check" "DIRTY_demote_CLASS1"
    fi
else
    echo "$LOG_PREFIX [WARN] sl status failed — assuming dirty"
    audit_log "-" "-" "wc_check" "SL_STATUS_FAILED"
fi
cd "$ORIG_PWD"

# ─── Classification (pure function) ──────────────────────────────────────
# Stdin: signal name. Stdout: 1 | 2 | 3.
#
# Hardcoded matrix is the FLOOR. JSON layer (live.json) only EXTENDS — it
# is consulted ONLY if the hardcoded matrix returns 3 (no match), so JSON
# patterns can never override hardcoded ones. Degrades silently to 3 if
# JSON load fails — no regression from baseline.
classify_signal() {
    local lc
    lc=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$lc" in
        *lint*|*arclint*|*autoformat*|*formatter*|*black*|*clang-format*|*"buck format"*|*prettier*|*ruff*)
            echo 1; return ;;
        *rebase*|*"out of date"*|*"out-of-date"*|*"merge conflict"*|*"stale base"*|*"needs rebase"*)
            echo 1; return ;;
        # target-determinator fails for BOTH transient infra AND merge conflicts.
        # Route to CLASS 2 (retrigger + defer 1 cycle), NOT blanket-mute or
        # immediate-escalate: a flake clears on retrigger; a real merge conflict
        # survives it and escalates next cycle. Persistence = the flake/real
        # discriminator we can't get from the name alone (2026-06-01, D107103689).
        *target-determinator*|*target_determinator*)
            echo 2; return ;;
        *codegen*|*"generated file"*|*autogen*|*"buck genrule"*|*"thrift gen"*)
            echo 1; return ;;
        # Narrow Pyre/mypy annotation signals — pyre infer can codemod these
        # cleanly. MUST come before the broad pyre/mypy → CLASS 2 line below.
        *missing-annotation*|*missing-return-annotation*|*missing-attribute-annotation*|*missing-parameter-annotation*|*"missing annotation"*|*"missing return annotation"*|*"missing parameter annotation"*|*"needs annotation"*|*incomplete-annotation*)
            echo 1; return ;;
        *build*|*compile*|*sandcastle*|*test*|*ci*|*check*|*verifier*|*pyre*|*mypy*)
            echo 2; return ;;
    esac

    # Hardcoded matrix returned no match (would be CLASS 3). Try JSON layer.
    if [ "$FLYWHEEL_ENABLED" = "1" ] && [ -f "$FLYWHEEL_LIVE" ] && [ -f "$FLYWHEEL_CLASSIFY_PY" ]; then
        local json_cls
        json_cls=$(timeout 5 python3 "$FLYWHEEL_CLASSIFY_PY" \
                       --signal "$1" --live "$FLYWHEEL_LIVE" 2>/dev/null) || json_cls=""
        case "$json_cls" in
            1|2) echo "$json_cls"; return ;;
        esac
    fi
    echo 3
}

# ─── Lint-comment visibility (2026-05-24) ────────────────────────────────
# `phabricator.diff comments` surfaces inline lint findings (arc-lint
# advice/warning, devmate suggestions) that `phabricator.diff.signals
# list` does NOT include. Without this, the NO_DETAIL_default_3 branch
# escalates with zero context — boss sees "N warn signal(s), no detail"
# in chat and has to open the diff to know what's wrong (case in point:
# the 2026-05-24 0800 escalation, 5 of 6 diffs hit this path).
#
# Pure visibility: no auto-mutation. arc f in attempt_class1_fix already
# handles the autofixable subset; this just enriches the CLASS 3
# escalation text so boss can act from chat.
#
# Stdout: zero or more tab-delimited rows, sorted by severity then code:
#   STATUS\tCODE\tLOCATION\tONE_LINE_DESC
# STATUS ∈ {WARNING, ADVICE}. Zero rows = genuine no-detail failure.
LINT_COMMENTS_ENABLED="${LINT_COMMENTS_ENABLED:-1}"

# ─── Known-noise allowlist (2026-05-25) ──────────────────────────────────
# Signals whose only failure mode is broken/non-actionable infra (not the
# diff author's fault). If a diff's ONLY non-green signals are in this
# list, demote to green and skip escalation. File format: one substring
# per line; '#' lines = comments. Substring match against signal name.
#
# Default seed: slick_sli_alerting_coverage (chronically broken meta-
# signal on AAA reliability diffs). Add more entries via the .txt file —
# no code changes needed.
KNOWN_NOISE_FILE="$REPO_DIR/state/known-noise-signals.txt"

# Loads patterns once. Sets array NOISE_PATTERNS (empty if file missing).
# Pure-bash, no python dep — must be safe to call from any code path.
load_known_noise_patterns() {
    NOISE_PATTERNS=()
    [ ! -f "$KNOWN_NOISE_FILE" ] && return 0
    while IFS= read -r line || [ -n "$line" ]; do
        # Strip leading/trailing whitespace, skip comments and blanks.
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        NOISE_PATTERNS+=("$line")
    done < "$KNOWN_NOISE_FILE"
}

# Returns 0 if $1 matches any NOISE_PATTERNS substring, 1 otherwise.
is_known_noise() {
    local name="$1" pat
    for pat in "${NOISE_PATTERNS[@]}"; do
        case "$name" in *"$pat"*) return 0 ;; esac
    done
    return 1
}

# Returns 0 if $1 matches any known-real classifier pattern (matches the
# classify_signal() case statement). Used to detect "unknown signal type"
# — names that hit neither real-pattern nor noise allowlist. Pure naming
# regex, no side effects.
is_known_signal_pattern() {
    local lc
    lc=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$lc" in
        *lint*|*arclint*|*autoformat*|*formatter*|*black*|*clang-format*|*"buck format"*|*prettier*|*ruff*) return 0 ;;
        *rebase*|*"out of date"*|*"out-of-date"*|*"merge conflict"*|*"stale base"*|*"needs rebase"*) return 0 ;;
        *codegen*|*"generated file"*|*autogen*|*"buck genrule"*|*"thrift gen"*) return 0 ;;
        *missing-annotation*|*missing-return-annotation*|*missing-attribute-annotation*|*missing-parameter-annotation*|*"missing annotation"*|*"missing return annotation"*|*"missing parameter annotation"*|*"needs annotation"*|*incomplete-annotation*) return 0 ;;
        *build*|*compile*|*sandcastle*|*test*|*ci*|*check*|*verifier*|*pyre*|*mypy*) return 0 ;;
    esac
    return 1
}

# Load noise patterns once at startup.
load_known_noise_patterns

fetch_lint_comments() {
    [ "$LINT_COMMENTS_ENABLED" != "1" ] && return 0
    local diff_num="$1"
    local raw
    raw=$(timeout 30 meta phabricator.diff comments -n "$diff_num" --output=json 2>/dev/null || echo '[]')
    [ -z "$raw" ] && return 0
    echo "$raw" | python3 -c "
import sys, json, re
try:
    items = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
if isinstance(items, dict):
    items = items.get('comments') or items.get('items') or []
rows = []
for it in (items or []):
    if not isinstance(it, dict): continue
    src = (it.get('source') or '').lower()
    is_warn = 'signal (warning)' in src
    is_adv  = 'signal (advice)'  in src
    if not (is_warn or is_adv):
        continue
    resolved = str(it.get('resolved') or '').lower() in ('true','yes','1')
    if resolved: continue
    status = 'WARNING' if is_warn else 'ADVICE'
    loc = (it.get('location') or '').replace('\t',' ')
    content = (it.get('content') or '').replace('\t',' ').replace('\n',' ')
    m = re.search(r'Lint name: \`([^\`]+)\`', content) \
        or re.search(r'Lint code: \`([^\`]+)\`', content) \
        or re.match(r'^([A-Z][A-Za-z0-9_/-]+):', content)
    code = m.group(1) if m else 'lint'
    desc = re.sub(r'\s+Lint code: .*$', '', content)[:120]
    rows.append((0 if is_warn else 1, code, status, loc, desc))
rows.sort()
for _, code, status, loc, desc in rows:
    print(f'{status}\t{code}\t{loc}\t{desc}')
" 2>/dev/null || true
}

# ─── CLASS 1 auto-fix ────────────────────────────────────────────────────
# Workflow: sl goto → sl pull --rebase → [pyre infer if annotation signal]
#           → arc f → sl amend → jf submit.
# $2 (signal_label) is optional; when it matches annotation patterns AND the
# diff has .py files under fbcode/, run `pyre infer -i --simple-annotations`
# on those files. Scope check (post arc f) catches any drift.
# Returns 0 on success, 1 on failure (best-effort cleanup/restore on failure).
attempt_class1_fix() {
    local diff_num="$1"
    local signal_label="${2:-}"
    cd "$FBSOURCE" || { audit_log "$diff_num" 1 "cd_fbsource" "FAILED"; return 1; }

    if ! timeout 60 sl goto "$diff_num" \
        --reason "diff-signal-monitor goto for autofix - sl help goto" \
        >/dev/null 2>&1; then
        audit_log "$diff_num" 1 "sl_goto" "FAILED"
        return 1
    fi
    audit_log "$diff_num" 1 "sl_goto" "OK"

    # Capture files in this commit (for unsafe-scope sanity check after arc f)
    local diff_files
    diff_files=$(timeout 15 sl log -r . -T '{join(files,"\n")}\n' \
        --reason "list files in diff - sl help log" 2>/dev/null | grep -v '^$' || true)

    local rev_before_fix
    rev_before_fix=$(timeout 15 sl log -r . -T '{node}' \
        --reason "capture rev before fix - sl help log" 2>/dev/null || echo "")

    # sl pull --rebase: handles stale-base CLASS 1 and refreshes for arc f.
    if ! timeout 240 sl pull --rebase \
        --reason "diff-signal-monitor refresh base before autofix - sl help pull" \
        >/dev/null 2>&1; then
        audit_log "$diff_num" 1 "sl_pull_rebase" "FAILED_or_CONFLICT"
        timeout 30 sl rebase --abort \
            --reason "abort failed rebase - sl help rebase" >/dev/null 2>&1 || true
        return 1
    fi
    audit_log "$diff_num" 1 "sl_pull_rebase" "OK"

    # Pyre infer — narrow auto-fix for missing-annotation signals.
    # Gated: only when the signal label says annotation AND diff has .py
    # files under fbcode/. --simple-annotations restricts to changes
    # guaranteed to codemod cleanly with --in-place. Failure is non-fatal:
    # we fall through to arc f, scope check, and the no-op-skip guard.
    local lc_label
    lc_label=$(echo "$signal_label" | tr '[:upper:]' '[:lower:]')
    case "$lc_label" in
        *annotation*|*annotate*)
            local py_files
            py_files=$(echo "$diff_files" | grep '^fbcode/.*\.py$' | sed 's|^fbcode/||' || true)
            if [ -n "$py_files" ]; then
                local pyre_args=()
                while IFS= read -r f; do [ -n "$f" ] && pyre_args+=("$f"); done <<< "$py_files"
                if ( cd "$FBSOURCE/fbcode" && timeout 300 pyre infer -i --simple-annotations "${pyre_args[@]}" ) >/dev/null 2>&1; then
                    audit_log "$diff_num" 1 "pyre_infer" "OK_${#pyre_args[@]}_files"
                else
                    audit_log "$diff_num" 1 "pyre_infer" "FAILED_or_noop"
                fi
            else
                audit_log "$diff_num" 1 "pyre_infer" "SKIP_no_fbcode_py"
            fi
            ;;
    esac

    # arc f — formatter + linter auto-apply.
    if ! timeout 240 arc f >/dev/null 2>&1; then
        audit_log "$diff_num" 1 "arc_f" "FAILED"
        timeout 30 sl revert --all \
            --reason "revert after arc f failure - sl help revert" >/dev/null 2>&1 || true
        return 1
    fi
    audit_log "$diff_num" 1 "arc_f" "OK"

    local post
    post=$(timeout 15 sl status \
        --reason "post-arc-f status - sl help status" 2>/dev/null || echo "")

    if [ -z "$post" ]; then
        # No drift detected by arc f. The non-green signals weren't lint after
        # all (or the rebase alone resolved it). Submit the rebased commit so
        # the rebase fix lands.
        audit_log "$diff_num" 1 "arc_f_changes" "NONE_post_rebase_only"
    else
        # Sanity: arc f must only touch files in the diff's scope. If it
        # touched other paths (rare — usually means generated-file regen
        # crossing into unrelated areas), revert + escalate.
        if [ -n "$diff_files" ]; then
            local changed_paths unexpected
            changed_paths=$(echo "$post" | awk '{print $2}')
            unexpected=$(comm -23 \
                <(echo "$changed_paths" | sort -u) \
                <(echo "$diff_files" | sort -u) 2>/dev/null || true)
            if [ -n "$unexpected" ]; then
                audit_log "$diff_num" 1 "scope_check" "UNSAFE_$(echo "$unexpected" | head -3 | tr '\n' ',' | sed 's/,$//')"
                timeout 30 sl revert --all \
                    --reason "revert unsafe arc f changes outside diff scope - sl help revert" \
                    >/dev/null 2>&1 || true
                return 1
            fi
            audit_log "$diff_num" 1 "scope_check" "OK"
        fi

        if ! timeout 60 sl amend \
            --reason "diff-signal-monitor fold autofix - sl help amend" \
            >/dev/null 2>&1; then
            audit_log "$diff_num" 1 "sl_amend" "FAILED"
            timeout 30 sl revert --all \
                --reason "revert after amend failure - sl help revert" >/dev/null 2>&1 || true
            return 1
        fi
        audit_log "$diff_num" 1 "sl_amend" "AMENDED"
    fi

    # If neither rebase nor arc f changed the commit, this signal wasn't
    # actually a CLASS 1 fix — escalate instead of submitting a no-op
    # version (prevents loop on misclassified signals).
    local rev_after_fix
    rev_after_fix=$(timeout 15 sl log -r . -T '{node}' \
        --reason "capture rev after fix - sl help log" 2>/dev/null || echo "")
    if [ -n "$rev_before_fix" ] && [ "$rev_before_fix" = "$rev_after_fix" ]; then
        audit_log "$diff_num" 1 "no_op_skip" "MISCLASSIFIED_no_changes"
        return 1
    fi

    if ! timeout 180 jf submit -m "auto-fix: lint/format/rebase via cron-diff-signal-monitor" \
        >/dev/null 2>&1; then
        audit_log "$diff_num" 1 "jf_submit" "FAILED"
        return 1
    fi
    audit_log "$diff_num" 1 "jf_submit" "SUBMITTED"
    return 0
}

# ─── CLASS 1.5: narrow Pyre Optional-narrowing autofix ───────────────────
# Returns 0 iff it fixed + verified-green + submitted. Returns 1 for "not
# applicable" or any failure; caller then falls through to normal CLASS 2.
# Verify rail compares pyre before/after by message (line-shift tolerant) and
# only proceeds if errors strictly decreased with none added.
is_type_check_label() {
    local lc; lc=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$lc" in
        *type-check*|*type_check*|*typecheck*|*"type checking"*|*pyre*|*mypy*) return 0 ;;
    esac
    return 1
}

attempt_narrow_typefix() {
    local diff_num="$1"
    cd "$FBSOURCE/fbcode" 2>/dev/null || { audit_log "$diff_num" 15 "cd_fbcode" "FAILED"; return 1; }

    if ! timeout 60 sl goto "$diff_num" \
        --reason "narrow-typefix goto - sl help goto" >/dev/null 2>&1; then
        audit_log "$diff_num" 15 "sl_goto" "FAILED"; return 1
    fi
    local rev_before diff_files
    rev_before=$(timeout 15 sl log -r . -T '{node}' \
        --reason "rev before narrowfix - sl help log" 2>/dev/null || echo "")
    diff_files=$(timeout 15 sl log -r . -T '{join(files,"\n")}\n' \
        --reason "files in diff - sl help log" 2>/dev/null | grep -v '^$' || true)

    if ! timeout 240 sl pull --rebase \
        --reason "narrow-typefix refresh base - sl help pull" >/dev/null 2>&1; then
        audit_log "$diff_num" 15 "sl_pull_rebase" "FAILED_or_CONFLICT"
        timeout 30 sl rebase --abort \
            --reason "abort failed rebase - sl help rebase" >/dev/null 2>&1 || true
        return 1
    fi

    # Discover errors (non-zero exit expected when errors exist).
    local before_f after_f
    before_f=$(mktemp /tmp/narrowfix-before.XXXXXX)
    after_f=$(mktemp /tmp/narrowfix-after.XXXXXX)
    # shellcheck disable=SC2064
    trap "rm -f '$before_f' '$after_f'" RETURN
    # Use check-owning-targets on the diff's .py files, NOT check-changed-targets:
    # check-changed-targets missed the exact target CI flags — on D106859590 it
    # checked trainer_test-library but not trainer:trainer-type-checking, so the
    # cron saw NO_FIXABLE on a real [16] error (2026-05-31). owning-targets
    # resolves each file's actual type-check target.
    local _py_rel
    _py_rel=$(echo "$diff_files" | grep -E '^fbcode/.*\.py$' | sed 's|^fbcode/||' | tr '\n' ' ')
    if [ -n "$_py_rel" ]; then
        timeout 540 arc pyre check-owning-targets $_py_rel >"$before_f" 2>&1 || true
    else
        timeout 540 arc pyre check-changed-targets >"$before_f" 2>&1 || true
    fi

    # Apply none_throws wraps for [16] Optional-attr errors only.
    local fix_json fixes
    fix_json=$(timeout 60 python3 "$NARROW_FIX_PY" --root "$FBSOURCE/fbcode" \
        --pyre-output "$before_f" 2>/dev/null || echo '{}')
    fixes=$(echo "$fix_json" | python3 -c "import json,sys;print(json.load(sys.stdin).get('fixes',0))" 2>/dev/null || echo 0)
    if [ "${fixes:-0}" -eq 0 ]; then
        # Instrument the detection-miss so it's DIAGNOSABLE, not inferred. On
        # D106859590 (2026-05-31) we got NO_FIXABLE and had to guess why because
        # the pyre output was in an auto-deleted temp file. Persist it + record
        # what it actually contained: 0 [16] errors = wrong target / clean;
        # [16] present but fixes=0 = parser bug; 0 lines = pyre empty/timeout.
        local _dbg="$HOME/logs/narrowfix-debug-${diff_num}-$(date +%Y%m%d-%H%M%S).log"
        cp "$before_f" "$_dbg" 2>/dev/null || true
        local _pl _e16 _eall
        _pl=$(wc -l < "$before_f" 2>/dev/null | tr -d ' ' || echo 0)
        _e16=$(grep -cE '\[16\]' "$before_f" 2>/dev/null || echo 0)
        _eall=$(grep -cE '\[[0-9]+\]:' "$before_f" 2>/dev/null || echo 0)
        audit_log "$diff_num" 15 "narrow_apply" "NO_FIXABLE lines=${_pl} err16=${_e16} errtotal=${_eall} dbg=${_dbg}"
        timeout 30 sl revert --all --reason "revert: nothing fixed - sl help revert" >/dev/null 2>&1 || true
        return 1
    fi
    audit_log "$diff_num" 15 "narrow_apply" "WRAPPED_${fixes}"

    if ! timeout 240 arc lint -a >/dev/null 2>&1; then
        audit_log "$diff_num" 15 "arc_lint" "FAILED"
        timeout 30 sl revert --all --reason "revert after lint failure - sl help revert" >/dev/null 2>&1 || true
        return 1
    fi

    # Scope check: only the diff's own files may have changed.
    local post changed unexpected
    post=$(timeout 15 sl status --reason "post-fix status - sl help status" 2>/dev/null || echo "")
    if [ -n "$diff_files" ] && [ -n "$post" ]; then
        changed=$(echo "$post" | awk '{print $2}')
        unexpected=$(comm -23 <(echo "$changed" | sort -u) <(echo "$diff_files" | sort -u) 2>/dev/null || true)
        if [ -n "$unexpected" ]; then
            audit_log "$diff_num" 15 "scope_check" "UNSAFE_$(echo "$unexpected" | head -3 | tr '\n' ',' | sed 's/,$//')"
            timeout 30 sl revert --all --reason "revert unsafe scope - sl help revert" >/dev/null 2>&1 || true
            return 1
        fi
    fi

    # VERIFY RAIL: re-run pyre (same target set as discover), require strict
    # reduction with no new errors.
    if [ -n "${_py_rel:-}" ]; then
        timeout 540 arc pyre check-owning-targets $_py_rel >"$after_f" 2>&1 || true
    else
        timeout 540 arc pyre check-changed-targets >"$after_f" 2>&1 || true
    fi
    if ! timeout 30 python3 "$NARROW_FIX_PY" --verify --before "$before_f" --after "$after_f" >/dev/null 2>&1; then
        audit_log "$diff_num" 15 "verify_pyre" "REGRESS_or_NO_REDUCTION_revert"
        timeout 30 sl revert --all --reason "revert: narrow-fix did not verify - sl help revert" >/dev/null 2>&1 || true
        return 1
    fi
    audit_log "$diff_num" 15 "verify_pyre" "STRICT_REDUCTION_ok"

    if ! timeout 60 sl amend \
        --reason "narrow-typefix fold none_throws - sl help amend" >/dev/null 2>&1; then
        audit_log "$diff_num" 15 "sl_amend" "FAILED"
        timeout 30 sl revert --all --reason "revert after amend failure - sl help revert" >/dev/null 2>&1 || true
        return 1
    fi
    local rev_after
    rev_after=$(timeout 15 sl log -r . -T '{node}' \
        --reason "rev after narrowfix - sl help log" 2>/dev/null || echo "")
    if [ -n "$rev_before" ] && [ "$rev_before" = "$rev_after" ]; then
        audit_log "$diff_num" 15 "no_op_skip" "NO_CHANGE"
        return 1
    fi

    if ! timeout 180 jf submit -m "auto-fix: wrap Optional in none_throws() to clear Pyre [16] (CLASS 1.5, verified strict error reduction)" >/dev/null 2>&1; then
        audit_log "$diff_num" 15 "jf_submit" "FAILED"
        return 1
    fi
    audit_log "$diff_num" 15 "jf_submit" "SUBMITTED"
    return 0
}

# ─── Metadata hygiene: clear stale depends_on ────────────────────────────
# When a diff is rebased onto trunk and resubmitted, jf submit updates the
# code but does NOT clear Phab's depends_on (sticky from prior stack). The
# UI then misleadingly shows the diff as still stacked. Detect: Phab
# depends_on non-empty AND local parent is on remote/master. Fix: call
# remove-dependency. Read-only sl ops, no checkout, safe in any WC state.
metadata_hygiene_clear_stale_deps() {
    [ "$METADATA_HYGIENE_ENABLED" != "1" ] && return 0
    local diff_num="$1" meta_json="$2"

    local phab_depends phab_commit phab_repo
    eval "$(echo "$meta_json" | python3 -c "
import sys, json, shlex
try:
    d = json.loads(sys.stdin.read())
except Exception:
    d = {}
print(f'phab_depends={shlex.quote(str(d.get(\"depends_on\",\"\") or \"\"))}')
print(f'phab_commit={shlex.quote(str(d.get(\"commit_hash\",\"\") or \"\"))}')
print(f'phab_repo={shlex.quote(str(d.get(\"repository_name\",\"\") or \"\"))}')
" 2>/dev/null)"

    [ -z "${phab_depends:-}" ] && return 0
    [ -z "${phab_commit:-}" ] && return 0

    local repo_dir
    case "${phab_repo:-}" in
        fbsource) repo_dir="$FBSOURCE" ;;
        configerator) repo_dir="$CONFIGERATOR" ;;
        *) return 0 ;;
    esac
    [ ! -d "$repo_dir" ] && return 0

    # Read-only: does local parent of this commit sit on remote/master?
    local parent_remotes
    parent_remotes=$(cd "$repo_dir" && timeout 10 sl log -r "${phab_commit}^" \
        -T '{remotenames}' \
        --reason "hygiene check: parent on trunk? - sl help log" 2>/dev/null || echo "")
    if ! echo "$parent_remotes" | grep -qw "remote/master"; then
        return 0
    fi

    # Parent IS trunk but Phab still shows deps → stale. Clear each.
    local dep
    for dep in $(echo "$phab_depends" | grep -oE 'D[0-9]+' | sed 's/^D//'); do
        if [ "$DRY_RUN" = "1" ]; then
            audit_log "$diff_num" 1 "hygiene_stale_deps" "DRY_RUN_would_clear_D$dep"
            continue
        fi
        if timeout 30 meta phabricator.diff remove-dependency \
            --number="${diff_num#D}" --dependency="$dep" >/dev/null 2>&1; then
            audit_log "$diff_num" 1 "hygiene_stale_deps" "CLEARED_D$dep"
        else
            audit_log "$diff_num" 1 "hygiene_stale_deps" "FAILED_D$dep"
        fi
    done
}

# Auto-rebase: if Phab's commit parent is on remote/master but trunk has
# advanced, pull + rebase the single commit onto fresh trunk + resubmit.
# Aborts cleanly on merge conflict (never leaves repo in unfinished state).
metadata_hygiene_rebase_stale_parent() {
    [ "$METADATA_HYGIENE_ENABLED" != "1" ] && return 0
    [ "$AUTO_REBASE_ENABLED" != "1" ] && return 0
    local diff_num="$1" meta_json="$2"

    local phab_commit phab_repo
    eval "$(echo "$meta_json" | python3 -c "
import sys, json, shlex
try:
    d = json.loads(sys.stdin.read())
except Exception:
    d = {}
print(f'phab_commit={shlex.quote(str(d.get(\"commit_hash\",\"\") or \"\"))}')
print(f'phab_repo={shlex.quote(str(d.get(\"repository_name\",\"\") or \"\"))}')
" 2>/dev/null)"

    [ -z "${phab_commit:-}" ] && return 0

    local repo_dir
    case "${phab_repo:-}" in
        fbsource) repo_dir="$FBSOURCE" ;;
        configerator|"Configerator Hg") repo_dir="$CONFIGERATOR" ;;
        *) return 0 ;;
    esac
    [ ! -d "$repo_dir" ] && return 0

    # Commit must exist locally to rebase. Suppress "unknown revision" noise.
    if ! (cd "$repo_dir" && timeout 10 sl log -r "$phab_commit" -T '{node}' \
            --reason "auto-rebase: commit exists? - sl help log" >/dev/null 2>&1); then
        return 0
    fi

    # Parent must be on remote/master (any point). If parent IS a draft
    # (intentional stack), skip — boss may want the stack preserved.
    local parent_remotes
    parent_remotes=$(cd "$repo_dir" && timeout 10 sl log -r "${phab_commit}^" \
        -T '{remotenames}' \
        --reason "auto-rebase: parent on trunk? - sl help log" 2>/dev/null || echo "")
    echo "$parent_remotes" | grep -qw "remote/master" || return 0

    # WC must be clean — won't rebase if user has uncommitted work.
    local wc_status
    wc_status=$(cd "$repo_dir" && timeout 15 sl status \
        --reason "auto-rebase: WC clean? - sl help status" 2>/dev/null || echo "DIRTY")
    if [ -n "$wc_status" ]; then
        return 0
    fi

    # Pull once per repo per cron run (avoid repeat network hits).
    if [ -z "${REPO_PULLED[$repo_dir]:-}" ]; then
        (cd "$repo_dir" && timeout 120 sl pull \
            --reason "auto-rebase: refresh trunk - sl help pull" >/dev/null 2>&1) || true
        REPO_PULLED[$repo_dir]=1
    fi

    # Is parent actually behind tip? If parent == tip, no rebase needed.
    local parent_node master_node
    parent_node=$(cd "$repo_dir" && timeout 10 sl log -r "${phab_commit}^" -T '{node}' \
        --reason "auto-rebase: parent node - sl help log" 2>/dev/null || echo "")
    master_node=$(cd "$repo_dir" && timeout 10 sl log -r 'remote/master' -T '{node}' \
        --reason "auto-rebase: trunk tip - sl help log" 2>/dev/null || echo "")
    [ -z "$parent_node" ] && return 0
    [ -z "$master_node" ] && return 0
    [ "$parent_node" = "$master_node" ] && return 0

    if [ "$DRY_RUN" = "1" ]; then
        audit_log "$diff_num" 1 "hygiene_rebase" "DRY_RUN_would_rebase_${phab_commit:0:12}_to_${master_node:0:12}"
        return 0
    fi

    # Attempt rebase. On conflict, abort and escalate — must NEVER leave
    # the repo in an unfinished-rebase state (blocks all future sl ops).
    local rebase_out
    rebase_out=$(cd "$repo_dir" && timeout 120 sl rebase -r "$phab_commit" -d remote/master \
        --reason "auto-rebase $diff_num to fresh trunk - sl help rebase" 2>&1)
    if echo "$rebase_out" | grep -qiE 'unresolved conflict|abort|merge conflict'; then
        (cd "$repo_dir" && timeout 30 sl rebase --abort \
            --reason "auto-rebase: clean up after conflict - sl help rebase" >/dev/null 2>&1) || true
        audit_log "$diff_num" 3 "hygiene_rebase" "CONFLICTS_aborted"
        return 1
    fi

    # Parse new hash from "OLDHASH -> NEWHASH" line.
    local new_hash
    new_hash=$(echo "$rebase_out" | grep -oE '[0-9a-f]{12} -> [0-9a-f]{12}' | tail -1 | awk '{print $3}')
    if [ -z "$new_hash" ]; then
        audit_log "$diff_num" 3 "hygiene_rebase" "REBASE_no_new_hash"
        return 1
    fi

    # Checkout new commit + resubmit. WC pointer moves here.
    if ! (cd "$repo_dir" && timeout 60 sl goto "$new_hash" \
            --reason "auto-rebase: checkout rebased $diff_num - sl help goto" >/dev/null 2>&1); then
        audit_log "$diff_num" 3 "hygiene_rebase" "GOTO_FAILED_$new_hash"
        return 1
    fi

    if (cd "$repo_dir" && timeout 180 jf submit --draft --publish-when-ready >/dev/null 2>&1); then
        audit_log "$diff_num" 1 "hygiene_rebase" "REBASED_${phab_commit:0:12}_to_$new_hash"
        return 0
    else
        audit_log "$diff_num" 3 "hygiene_rebase" "REBASE_OK_SUBMIT_FAILED_$new_hash"
        return 1
    fi
}

# ─── CI Retrigger Defer helpers ──────────────────────────────────────────
# Write/read/age-check the pending marker that gates CLASS 2 escalation.
# Marker schema: {diff,version,label,triggered_at,triggered_at_ts}.
ci_retrigger_marker_path() {
    echo "$CI_RETRIGGER_PENDING_DIR/$1.json"
}

ci_retrigger_mark_pending() {
    [ "$CI_RETRIGGER_DEFER_ENABLED" != "1" ] && return 0
    local diff_num="$1" version="$2" label="$3"
    mkdir -p "$CI_RETRIGGER_PENDING_DIR" 2>/dev/null || return 0
    local marker; marker=$(ci_retrigger_marker_path "$diff_num")
    DIFF="$diff_num" VER="$version" LBL="$label" MARKER="$marker" python3 -c "
import json, os, time
m = {
    'diff': os.environ['DIFF'],
    'version': os.environ.get('VER',''),
    'label': os.environ.get('LBL',''),
    'triggered_at': time.strftime('%Y-%m-%dT%H:%M:%S%z'),
    'triggered_at_ts': int(time.time()),
}
with open(os.environ['MARKER'],'w') as f: json.dump(m,f)
" 2>/dev/null || true
}

# Returns 0 if marker present AND version still matches the marked one.
# Returns 1 if no marker OR version diverged (boss amended → drops stale marker).
ci_retrigger_is_pending() {
    [ "$CI_RETRIGGER_DEFER_ENABLED" != "1" ] && return 1
    local diff_num="$1" current_version="$2"
    local marker; marker=$(ci_retrigger_marker_path "$diff_num")
    [ ! -f "$marker" ] && return 1
    local marked_version
    marked_version=$(MARKER="$marker" python3 -c "
import json, os
try:
    with open(os.environ['MARKER']) as f: print(json.load(f).get('version',''))
except Exception: print('')
" 2>/dev/null || echo "")
    if [ -n "$current_version" ] && [ -n "$marked_version" ] && \
       [ "$current_version" != "$marked_version" ]; then
        rm -f "$marker"
        return 1
    fi
    return 0
}

# Returns 0 if marker is older than CI_RETRIGGER_MAX_AGE_SEC (force escalate).
ci_retrigger_is_stale() {
    [ "$CI_RETRIGGER_DEFER_ENABLED" != "1" ] && return 1
    local diff_num="$1"
    local marker; marker=$(ci_retrigger_marker_path "$diff_num")
    [ ! -f "$marker" ] && return 1
    local triggered_ts
    triggered_ts=$(MARKER="$marker" python3 -c "
import json, os
try:
    with open(os.environ['MARKER']) as f: print(int(json.load(f).get('triggered_at_ts',0)))
except Exception: print(0)
" 2>/dev/null || echo 0)
    [ "$triggered_ts" -eq 0 ] && return 1
    local age=$(( $(date +%s) - triggered_ts ))
    [ "$age" -gt "$CI_RETRIGGER_MAX_AGE_SEC" ]
}

ci_retrigger_drop_pending() {
    rm -f "$(ci_retrigger_marker_path "$1")" 2>/dev/null
}

# ─── Stage 4 attribution scan (no-op when FLYWHEEL_ENABLED!=1) ────────────
# Walks open escalation manifests BEFORE the main loop, detects
# Denny-resolved diffs, emits learning events, drops resolved manifests.
flywheel_attribution_scan

# ─── List open diffs ─────────────────────────────────────────────────────
DIFF_NUMS=$(timeout 60 jf list --short 2>/dev/null | grep -oE '^D[0-9]+' || true)
if [ -z "$DIFF_NUMS" ]; then
    echo "$LOG_PREFIX No open diffs. Silent exit."
    audit_log "-" "-" "list_diffs" "NONE_OPEN"
    write_heartbeat "diff-signal-monitor"
    exit 0
fi
diff_count=$(echo "$DIFF_NUMS" | wc -l)
echo "$LOG_PREFIX $diff_count open diff(s)"
audit_log "-" "-" "list_diffs" "FOUND_$diff_count"

queried=0
errored=0
auto_fixed=0
escalations=0

# ─── Per-diff loop ───────────────────────────────────────────────────────
for diff_num in $DIFF_NUMS; do
    queried=$((queried + 1))

    raw=$(timeout 30 meta phabricator.diff ci-status -n "$diff_num" -o json 2>/dev/null || echo '')
    if [ -z "$raw" ] || ! echo "$raw" | python3 -c "import sys,json; json.loads(sys.stdin.read())" 2>/dev/null; then
        errored=$((errored + 1))
        echo "$LOG_PREFIX  $diff_num: ci-status query FAILED"
        audit_log "$diff_num" "?" "ci_status_query" "FAILED"
        continue
    fi

    eval "$(echo "$raw" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
def n(k):
    v = d.get(k, '0')
    try: return int(v)
    except: return 0
print(f\"DIFF_FAILED={n('failed')}\")
print(f\"DIFF_WARNINGS={n('warnings')}\")
print(f\"DIFF_PENDING={n('pending')}\")
print(f\"DIFF_PASSED={n('passed')}\")
print(f\"DIFF_TOTAL={n('total_signals')}\")
print(f\"DIFF_URL={d.get('url','')}\")
")"

    # Fetch metadata once — needed for both repo gate AND land-status check.
    # Land-status check must run BEFORE the CI-green skip, otherwise diffs
    # like D104348699 (CI-green/warn-only with LAND_RECENTLY_FAILED) get
    # bypassed (the historical bug surfaced 2026-05-08).
    meta_json=$(timeout 15 meta phabricator.diff metadata -n "$diff_num" -o json 2>/dev/null || echo '{}')
    eval "$(echo "$meta_json" | python3 -c "
import sys, json, shlex
try:
    d = json.loads(sys.stdin.read())
except Exception:
    d = {}
# shlex.quote: phab 'status' field can be 'Changes Planned' / 'Hg Closed'
# (multi-word) so shell-quote everything that may contain spaces.
print(f\"DIFF_REPO={shlex.quote(str(d.get('repository_name','')))}\")
print(f\"DIFF_LAND_STATUS={shlex.quote(str(d.get('land_job_status','')))}\")
print(f\"DIFF_IS_LANDABLE={shlex.quote(str(d.get('is_landable','false')))}\")
print(f\"DIFF_LAND_BLOCKER={shlex.quote(str(d.get('land_blocker','none')))}\")
print(f\"DIFF_PHAB_STATUS={shlex.quote(str(d.get('status','')))}\")
print(f\"DIFF_LATEST_VERSION={shlex.quote(str(d.get('latest_version_number','')))}\")
print(f\"DIFF_TAGS={shlex.quote(str(d.get('tags','')))}\")
print(f\"DIFF_TITLE={shlex.quote(str(d.get('title','')))}\")
print(f\"DIFF_IS_CLOSED={shlex.quote(str(d.get('is_closed','false')))}\")
print(f\"DIFF_IS_LANDED={shlex.quote(str(d.get('is_landed','false')))}\")
" 2>/dev/null)"

    # Skip terminal diffs (abandoned / landed / closed). 2026-05-30: the main
    # loop relied on `jf list` not surfacing terminal diffs; make it explicit.
    # Touching a terminal diff is wasted work and a stray amend+submit could
    # RESURRECT an abandoned diff. Guard BEFORE any hygiene/rebase/autofix.
    case "${DIFF_PHAB_STATUS,,}" in *abandon*) _dsm_terminal=1 ;; *) _dsm_terminal=0 ;; esac
    if [ "$_dsm_terminal" -eq 1 ] || [ "${DIFF_IS_CLOSED,,}" = "true" ] || [ "${DIFF_IS_LANDED,,}" = "true" ]; then
        echo "$LOG_PREFIX  $diff_num: terminal (status='${DIFF_PHAB_STATUS}' closed=${DIFF_IS_CLOSED} landed=${DIFF_IS_LANDED}) — skipping"
        audit_log "$diff_num" "0" "terminal_skip" "status_${DIFF_PHAB_STATUS// /_}"
        continue
    fi

    # Metadata hygiene: clear stale Phab depends_on if local parent landed.
    # Catches today's #2 failure mode — rebase doesn't auto-clear depends_on.
    metadata_hygiene_clear_stale_deps "$diff_num" "$meta_json"

    # Auto-rebase if parent on trunk but trunk has moved (today's #3 mode).
    # WC-mutating; gated by WC-clean + AUTO_REBASE_ENABLED. If it rebases,
    # re-fetch meta_json so downstream checks see the new commit_hash.
    if metadata_hygiene_rebase_stale_parent "$diff_num" "$meta_json"; then
        meta_json=$(timeout 15 meta phabricator.diff metadata -n "$diff_num" -o json 2>/dev/null || echo "$meta_json")
    fi

    # Land-failure detection — runs BEFORE the green-skip branch so that
    # CI-green diffs whose auto-land verdict failed don't slip through.
    # Three sub-paths:
    #   (a) WARNING blocker — wait_for_all rejects on warnings; retry would
    #       reproduce the same verdict. Diagnose + escalate, no retry.
    #   (b) Retry budget exhausted (≥2 attempts on current version) —
    #       same content already failed twice; manual amend needed.
    #   (c) Clean (failed=0, warnings=0) + budget available — retrigger
    #       once. Land queue / signal-window flake recovery.
    if [ "$LAND_RETRIGGER_ENABLED" = "1" ] && \
       [ "${DIFF_LAND_STATUS:-}" = "LAND_RECENTLY_FAILED" ] && \
       [ "${DIFF_IS_LANDABLE,,}" = "true" ] && \
       [ "${DIFF_FAILED:-0}" -eq 0 ]; then

        # Path (a): WARNING signals block wait_for_all verdict — retry futile.
        if [ "${DIFF_WARNINGS:-0}" -gt 0 ]; then
            echo "$LOG_PREFIX  $diff_num: LAND_RECENTLY_FAILED + warn=${DIFF_WARNINGS} — retry would reproduce, escalating"
            audit_log "$diff_num" 2 "land_retrigger" "SKIP_warning_blocker_w${DIFF_WARNINGS}"
            if [ "$DRY_RUN" != "1" ]; then
                write_escalation_manifest "$diff_num" "LAND_RECENTLY_FAILED+warning_blocker" 2 \
                    "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
            fi
            {
                printf '  • %s: LAND_RECENTLY_FAILED — auto-land blocked by %s warning(s)\n' "$diff_num" "$DIFF_WARNINGS"
                printf '    diagnosis: wait_for_all policy treats warnings as blockers; retry reproduces same verdict\n'
                printf '    draft reply: Auto-land blocked by warning signal. Fix/skip the warning-emitting check or amend to clear.\n'
            } >> "$ESCALATIONS_FILE"
            escalations=$((escalations + 1))
            continue
        fi

        # Path (b): retry budget — count attempts on current version.
        # 2+ attempts on same version → futile to retry, escalate.
        attempts_count=0
        if [ -n "${DIFF_LATEST_VERSION:-}" ]; then
            attempts_raw=$(timeout 30 meta phabricator.diff.land-attempts list -n "$diff_num" -o json 2>/dev/null || echo '[]')
            attempts_count=$(VER="$DIFF_LATEST_VERSION" python3 -c "
import sys, json, os
try:
    a = json.loads(sys.stdin.read())
except Exception:
    print(0); sys.exit(0)
target = os.environ.get('VER','')
if not target:
    print(0); sys.exit(0)
print(sum(1 for r in a if isinstance(r, dict) and target in [str(v) for v in r.get('phabricator_versions',[])]))
" <<< "$attempts_raw" 2>/dev/null || echo 0)
        fi

        if [ "${attempts_count:-0}" -ge 2 ]; then
            echo "$LOG_PREFIX  $diff_num: LAND_RECENTLY_FAILED — ${attempts_count} attempts on v${DIFF_LATEST_VERSION}, budget exhausted"
            audit_log "$diff_num" 2 "land_retrigger" "SKIP_budget_exhausted_n${attempts_count}_v${DIFF_LATEST_VERSION}"
            if [ "$DRY_RUN" != "1" ]; then
                write_escalation_manifest "$diff_num" "LAND_RECENTLY_FAILED+budget_exhausted" 2 \
                    "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
            fi
            {
                printf '  • %s: LAND_RECENTLY_FAILED — %s attempts on version %s already exhausted budget\n' \
                    "$diff_num" "$attempts_count" "$DIFF_LATEST_VERSION"
                printf '    diagnosis: same content has verdict-failed twice; verdict reason is sticky\n'
                printf '    draft reply: Auto-land retried %s× on this version, all rejected. Need amend or manual investigation.\n' "$attempts_count"
            } >> "$ESCALATIONS_FILE"
            escalations=$((escalations + 1))
            continue
        fi

        # Path (c): clean + budget — retrigger.
        if [ "$DRY_RUN" = "1" ]; then
            echo "$LOG_PREFIX  $diff_num: LAND_RECENTLY_FAILED clean — [DRY] would retrigger (attempts=$attempts_count)"
            audit_log "$diff_num" 1 "land_retrigger" "DRY_RUN_skip_n${attempts_count}"
            continue
        fi

        echo "$LOG_PREFIX  $diff_num: LAND_RECENTLY_FAILED clean — retriggering (attempts=$attempts_count)"
        if timeout 60 meta phabricator.diff land -n "$diff_num" -o json >/dev/null 2>&1; then
            audit_log "$diff_num" 1 "land_retrigger" "TRIGGERED_n${attempts_count}"
            auto_fixed=$((auto_fixed + 1))
            continue
        else
            audit_log "$diff_num" 1 "land_retrigger" "FAILED_escalate_n${attempts_count}"
            write_escalation_manifest "$diff_num" "LAND_RECENTLY_FAILED" 1 \
                "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
            {
                printf '  • %s: LAND_RECENTLY_FAILED (CI fully green, retry call errored)\n' "$diff_num"
                printf '    tried: meta phabricator.diff land -n %s (call failed, not verdict)\n' "$diff_num"
                printf '    draft reply: Auto-land retry call failed — likely land-queue or auth. Investigating.\n'
            } >> "$ESCALATIONS_FILE"
            escalations=$((escalations + 1))
            continue
        fi
    fi

    # ─── Stuck publish-when-ready detector (2026-05-23) ──────────────────
    # Gap surfaced by boss on D106153924 (open >22h, silent): a diff with
    # `publish_when_ready` tag stuck in Needs Review never trips the
    # LAND_RETRIGGER path (requires is_landable=true), and is otherwise
    # treated as plain green and skipped. The auto-land never fires because
    # land_blocker (revision_not_accepted, no_reviewers, etc.) is sticky.
    # Surface as CLASS 3 so boss can intervene (add reviewer, abandon, etc).
    if [ "${DIFF_FAILED:-0}" -eq 0 ] && [ "${DIFF_WARNINGS:-0}" -eq 0 ] && \
       [ "${DIFF_LAND_STATUS:-}" = "LAND_RECENTLY_FAILED" ] && \
       [ "${DIFF_IS_LANDABLE,,}" = "false" ] && \
       [ -n "${DIFF_LAND_BLOCKER:-}" ] && \
       [ "${DIFF_LAND_BLOCKER}" != "none" ] && \
       echo "${DIFF_TAGS:-}" | grep -q "publish_when_ready"; then
        echo "$LOG_PREFIX  $diff_num: STUCK publish_when_ready — blocker=$DIFF_LAND_BLOCKER status=$DIFF_PHAB_STATUS"
        audit_log "$diff_num" 3 "stuck_pwr" "BLOCKER_${DIFF_LAND_BLOCKER}_status_${DIFF_PHAB_STATUS// /_}"
        if [ "$DRY_RUN" != "1" ]; then
            write_escalation_manifest "$diff_num" "stuck_publish_when_ready:$DIFF_LAND_BLOCKER" 3 \
                "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
        fi
        {
            printf '  • %s: stuck publish_when_ready — blocker=%s status=%s\n' \
                "$diff_num" "$DIFF_LAND_BLOCKER" "$DIFF_PHAB_STATUS"
            printf '    title: %s\n' "${DIFF_TITLE:-<unknown>}"
            printf '    tried: classification only (CI green + LAND_FAILED + not landable — boss must unstick)\n'
            printf '    draft reply: D%s is publish_when_ready but %s. Either add an accepter, abandon, or amend tags.\n' \
                "${diff_num#D}" "$DIFF_LAND_BLOCKER"
        } >> "$ESCALATIONS_FILE"
        escalations=$((escalations + 1))
        continue
    fi

    # failed=0 → NOT a real red. TEST_FINISHED_WITH_WARNINGS (failed=0,
    # warnings>0) is effectively a pass — warnings are advisory. The cron's job
    # is catching RED (failures); it must not flag passing-with-warnings diffs as
    # "need judgment" (Denny 2026-06-01: 9 such diffs escalated as pure noise).
    # Land-BLOCKING warnings are already handled by the LAND_RETRIGGER path above.
    if [ "${DIFF_FAILED:-0}" -eq 0 ]; then
        # If we retriggered CI on a prior run and it's no longer failing,
        # count it as a silent recovery (flake, not real failure).
        if [ "$CI_RETRIGGER_DEFER_ENABLED" = "1" ] && \
           [ -f "$(ci_retrigger_marker_path "$diff_num")" ]; then
            ci_retrigger_drop_pending "$diff_num"
            echo "$LOG_PREFIX  $diff_num: GREEN — retrigger from prior run recovered (was flake)"
            audit_log "$diff_num" 1 "ci_retrigger_defer" "RECOVERED_after_retrigger"
            auto_fixed=$((auto_fixed + 1))
        elif [ "${DIFF_WARNINGS:-0}" -gt 0 ]; then
            # Warning-only: advisory, not red → skip (do NOT escalate, do NOT
            # mutate a passing diff). Logged for audit, not surfaced to Denny.
            echo "$LOG_PREFIX  $diff_num: warning-only (0f/${DIFF_WARNINGS}w) — advisory, not red, skipping"
            audit_log "$diff_num" "-" "ci_status" "WARN_ONLY_advisory_w${DIFF_WARNINGS}"
        else
            echo "$LOG_PREFIX  $diff_num: GREEN ($DIFF_PASSED/$DIFF_TOTAL)"
            audit_log "$diff_num" "-" "ci_status" "GREEN"
        fi
        continue
    fi

    echo "$LOG_PREFIX  $diff_num: NON-GREEN failed=$DIFF_FAILED warn=$DIFF_WARNINGS"
    audit_log "$diff_num" "?" "ci_status" "NON_GREEN_f${DIFF_FAILED}_w${DIFF_WARNINGS}"

    # Repo gate: only fbsource diffs are eligible for CLASS 1 autofix.
    repo="${DIFF_REPO:-}"

    # Fetch failing signal names for classification.
    # Use phabricator.diff.signals list (CI build/test signals), NOT
    # phabricator.diff comments --signals-only (returns inline review
    # signals only — empty for CI failures, was the historical bug
    # that made every diff hit NO_DETAIL_default_3).
    signals_stderr=$(mktemp)
    # --limit=500: the default cap is 100. On wide diffs (D106859590 had
    # total_signals=1683) the unmanaged-pyre land-blocker can sort past the
    # first 100 (which were all PASSED/WARNING), so the broad query alone
    # silently drops it. The --status=failed merge below is the real safety
    # net for failures, but raise the cap so WARNING-pathway signals beyond
    # 100 aren't dropped either (managed vs unmanaged pyre run separately).
    signals_raw=$(timeout 60 meta phabricator.diff.signals list -n "$diff_num" --limit="$SIGNALS_LIMIT" -o json 2>"$signals_stderr" || echo '[]')
    if [ -s "$signals_stderr" ]; then
        audit_log "$diff_num" "?" "signals_fetch" "STDERR_$(head -1 "$signals_stderr" | tr -d '\t' | cut -c1-80)"
    fi
    rm -f "$signals_stderr"
    # 2026-05-25: explicit --status=failed query. Without --status, some CI
    # failures (test_top_level_lean on D106189268) returned no entries at all
    # because their record's 'status' field didn't match the uppercase set.
    # This call narrows server-side and is the AUTHORITATIVE failure set —
    # it includes both managed and `- unmanaged` pathway failures.
    failed_stderr=$(mktemp)
    failed_raw=$(timeout 60 meta phabricator.diff.signals list -n "$diff_num" --status=failed --limit="$SIGNALS_LIMIT" -o json 2>"$failed_stderr" || echo '[]')
    if [ -s "$failed_stderr" ]; then
        audit_log "$diff_num" "?" "signals_failed_fetch" "STDERR_$(head -1 "$failed_stderr" | tr -d '\t' | cut -c1-80)"
    fi
    rm -f "$failed_stderr"

    # Select the non-green signal set via the shared, unit-tested evaluator
    # (D106859590 fix). It merges the --status=failed set (FAILED rows, both
    # pathways) AHEAD of the broad list's WARNING rows, deduped by name — so a
    # real failure always leads first_failure_label even when a flaky WARNING
    # sorts ahead of it in the broad list. The old awk merge deduped broad-list
    # WARNINGs first, which is exactly how the unmanaged-pyre land-blocker got
    # masked behind a GPU-test warning on D106859590. Emits STATUS\tNAME rows.
    failing_signals=$(timeout 15 python3 "$SIGNAL_EVAL_PY" --select \
        --failed-file <(printf '%s' "$failed_raw") \
        --warning-file <(printf '%s' "$signals_raw") 2>/dev/null || true)

    # Mismatch detector: ci-status said failed>0 but we parsed 0 names
    # → CLI shape changed or auth issue. Don't silently default to CLASS 3
    # (that's how the historical bug stayed hidden for weeks).
    parsed_count=$(echo -n "$failing_signals" | grep -c . || true)
    if [ "${DIFF_FAILED:-0}" -gt 0 ] && [ "$parsed_count" -eq 0 ]; then
        echo "$LOG_PREFIX   [WARN] failed=${DIFF_FAILED} but parsed 0 signals — CLI shape mismatch?"
        audit_log "$diff_num" "?" "signals_parse" "MISMATCH_failed${DIFF_FAILED}_parsed0"
    fi

    max_class=0
    first_failure_label=""
    # typecheck_failure_label: the FIRST failing signal that is a type-check
    # (managed OR unmanaged pyre/mypy). Captured independently of
    # first_failure_label so the CLASS 1.5 narrow type-fix can fire even when
    # a non-type-check signal (e.g. a flaky GPU test) is listed first. Before
    # this, narrowfix gated on first_failure_label only, so the unmanaged-pyre
    # land-blocker on D106859590 (listed after GPU warnings) never triggered it.
    typecheck_failure_label=""
    noise_count=0
    if [ -n "$failing_signals" ]; then
        while IFS=$'\t' read -r sig_status sig_name; do
            [ -z "$sig_name" ] && continue
            # Noise allowlist (2026-05-25): demote to CLASS 0, skip
            # classification, count toward all-noise gate below.
            if is_known_noise "$sig_name"; then
                audit_log "$diff_num" "0" "classify_signal" "DEMOTED_known_noise:$sig_name"
                noise_count=$((noise_count + 1))
                continue
            fi
            # Unknown-signal-type observability (2026-05-25): emit BEFORE
            # the normal escalation. Pure logging — no behavior change.
            # Grep 'unknown_signal_type' in the action log to find novel
            # categories the classifier doesn't yet recognize.
            if ! is_known_signal_pattern "$sig_name"; then
                audit_log "$diff_num" "?" "unknown_signal_type" "$sig_name"
            fi
            cls=$(classify_signal "$sig_name")
            [ "$cls" -gt "$max_class" ] && max_class=$cls
            [ -z "$first_failure_label" ] && first_failure_label="$sig_name"
            # Capture first type-check failure regardless of position so the
            # CLASS 1.5 narrow type-fix isn't masked by a non-type-check signal
            # that happens to sort first (managed vs unmanaged pyre pathways).
            if [ -z "$typecheck_failure_label" ] && is_type_check_label "$sig_name"; then
                typecheck_failure_label="$sig_name"
            fi
            audit_log "$diff_num" "$cls" "classify_signal" "$sig_status:$sig_name"
        done <<< "$failing_signals"
    fi

    # All-noise gate (2026-05-25): if every signal was demoted as noise,
    # treat the diff as green and skip escalation entirely. Records an
    # all_noise audit line so we can see when this fires.
    if [ "$noise_count" -gt 0 ] && [ "$noise_count" -eq "$parsed_count" ]; then
        audit_log "$diff_num" "0" "all_noise" "demoted_n=$noise_count"
        echo "$LOG_PREFIX   $diff_num: all $noise_count signal(s) on noise allowlist → treating as green"
        continue
    fi
    LINT_DETAIL_TEXT=""
    if [ "$max_class" -eq 0 ]; then
        # signals.list returned nothing — try comments endpoint for inline
        # lint advice/warning (arc-lint, devmate). See fetch_lint_comments.
        lint_rows=$(fetch_lint_comments "$diff_num")
        lint_count=$(echo -n "$lint_rows" | grep -c . || true)
        if [ "${lint_count:-0}" -gt 0 ]; then
            warn_count=$(echo "$lint_rows" | awk -F'\t' '$1=="WARNING"' | wc -l)
            adv_count=$(echo "$lint_rows" | awk -F'\t' '$1=="ADVICE"' | wc -l)
            top_code=$(echo "$lint_rows" | head -1 | awk -F'\t' '{print $2}')
            top_loc=$(echo "$lint_rows" | head -1 | awk -F'\t' '{print $3}')
            first_failure_label="lint ${warn_count}warn+${adv_count}advice (top: ${top_code} @ ${top_loc})"
            LINT_DETAIL_TEXT=$(echo "$lint_rows" | head -3 | \
                awk -F'\t' '{printf "    • [%s] %s @ %s: %s\n", $1, $2, $3, $4}')
            max_class=3
            audit_log "$diff_num" 3 "classify_signal" "LINT_COMMENTS_${warn_count}w_${adv_count}a"
        else
            # Genuine no-detail — keep original conservative CLASS 3.
            max_class=3
            first_failure_label="${DIFF_FAILED} failed / ${DIFF_WARNINGS} warn signal(s), no detail"
            audit_log "$diff_num" 3 "classify_signal" "NO_DETAIL_default_3"
        fi
    fi

    # Demotion gates: CLASS 1 requires both clean WC and fbsource repo.
    effective_class=$max_class
    if [ "$max_class" -eq 1 ]; then
        if [ "$WC_CLEAN" -ne 1 ]; then
            effective_class=3
            echo "$LOG_PREFIX   demoted CLASS 1 → CLASS 3 (WC not clean)"
            audit_log "$diff_num" 1 "demote" "WC_NOT_CLEAN"
        elif [ -n "$repo" ] && [ "$repo" != "fbsource" ]; then
            effective_class=3
            echo "$LOG_PREFIX   demoted CLASS 1 → CLASS 3 (repo=$repo, autofix only on fbsource)"
            audit_log "$diff_num" 1 "demote" "NON_FBSOURCE_$repo"
        fi
    fi

    case "$effective_class" in
        1)
            if [ "$DRY_RUN" = "1" ]; then
                echo "$LOG_PREFIX   CLASS 1 — [DRY] would silent-autofix"
                audit_log "$diff_num" 1 "auto_fix" "DRY_RUN_skip"
            else
                echo "$LOG_PREFIX   CLASS 1 — silent auto-fix attempt"
                if attempt_class1_fix "$diff_num" "$first_failure_label"; then
                    auto_fixed=$((auto_fixed + 1))
                    audit_log "$diff_num" 1 "auto_fix" "SUCCESS"
                else
                    audit_log "$diff_num" 1 "auto_fix" "FAILED_escalate"
                    write_escalation_manifest "$diff_num" "$first_failure_label" 1 \
                        "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
                    {
                        printf '  • %s: %s\n' "$diff_num" "$first_failure_label"
                        printf '    tried: sl goto / sl pull --rebase / arc f / sl amend / jf submit (CLASS 1 autofix failed)\n'
                        printf '    draft reply: Mechanical autofix (lint/format/rebase) attempted but failed — investigating manually.\n'
                    } >> "$ESCALATIONS_FILE"
                    escalations=$((escalations + 1))
                fi
            fi
            ;;
        2)
            # CLASS 1.5: try a deterministic Pyre Optional-narrowing autofix
            # BEFORE the retrigger path. Verified-green or it reverts and falls
            # through. Type-check labels only; bounded per run (pyre is slow);
            # same WC-clean / fbsource gates as CLASS 1.
            if [ "$CLASS15_NARROWFIX_ENABLED" = "1" ] && [ "$DRY_RUN" != "1" ] \
               && [ "$WC_CLEAN" -eq 1 ] && [ "$narrowfix_attempts" -lt "$NARROWFIX_MAX_PER_RUN" ] \
               && { [ -z "$repo" ] || [ "$repo" = "fbsource" ]; } \
               && [ -n "$typecheck_failure_label" ]; then
                narrowfix_attempts=$((narrowfix_attempts + 1))
                echo "$LOG_PREFIX   CLASS 1.5 - narrow type-fix attempt ($narrowfix_attempts/$NARROWFIX_MAX_PER_RUN) on: $typecheck_failure_label"
                if attempt_narrow_typefix "$diff_num"; then
                    auto_fixed=$((auto_fixed + 1))
                    audit_log "$diff_num" 15 "narrow_typefix" "SUCCESS"
                    continue
                fi
                audit_log "$diff_num" 15 "narrow_typefix" "NOT_APPLICABLE_fallthrough"
            fi
            # Defer escalation: retrigger CI, mark pending, escalate next run
            # only if still red on same version. Silences flake-recovery pings.
            #   - Marker exists, not stale, same version → real failure, escalate
            #   - Marker stale (>36h) → drop + retrigger again as fresh attempt
            #   - No marker (or version diverged) → first attempt, retrigger silently
            if ci_retrigger_is_stale "$diff_num"; then
                ci_retrigger_drop_pending "$diff_num"
                audit_log "$diff_num" 2 "ci_retrigger_defer" "STALE_marker_dropped"
            fi
            if ci_retrigger_is_pending "$diff_num" "${DIFF_LATEST_VERSION:-}"; then
                # Already retriggered last run, still red → real failure.
                ci_retrigger_drop_pending "$diff_num"
                audit_log "$diff_num" 2 "ci_retrigger_defer" "STILL_RED_escalating_v${DIFF_LATEST_VERSION:-}"
                write_escalation_manifest "$diff_num" "$first_failure_label" 2 \
                    "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
                {
                    printf '  • %s: %s\n' "$diff_num" "$first_failure_label"
                    printf '    tried: ci-trigger last run, still red on same version — not a flake\n'
                    # Persistent target-determinator (survived a retrigger) is almost
                    # always a real MERGE CONFLICT, not infra. Give the action.
                    if printf '%s' "$first_failure_label" | grep -qi 'target-determinator'; then
                        printf '    likely cause: MERGE CONFLICT / stale base — survived retrigger, so not infra flake.\n'
                        printf '    action: `jf get %s && sl rebase -d remote/master`. If the rebase shows the changes already on trunk, the diff is redundant → `meta phabricator.diff abandon`.\n' "$diff_num"
                    fi
                    printf '    draft reply: CI failure on `%s` persists after retrigger. Needs investigation.\n' "$first_failure_label"
                } >> "$ESCALATIONS_FILE"
                escalations=$((escalations + 1))
            elif [ "$CI_RETRIGGER_DEFER_ENABLED" = "1" ]; then
                # First-time attempt: retrigger + mark pending + DON'T escalate.
                echo "$LOG_PREFIX   CLASS 2 — retriggering CI (defer escalation 1 cycle)"
                if [ "$DRY_RUN" = "1" ]; then
                    audit_log "$diff_num" 2 "ci_trigger" "DRY_RUN_skip_defer"
                elif timeout 30 meta phabricator.diff ci-trigger -n "$diff_num" >/dev/null 2>&1; then
                    audit_log "$diff_num" 2 "ci_trigger" "TRIGGERED_deferred_v${DIFF_LATEST_VERSION:-}"
                    ci_retrigger_mark_pending "$diff_num" "${DIFF_LATEST_VERSION:-}" "$first_failure_label"
                else
                    # Retrigger call itself failed — escalate now, can't defer.
                    audit_log "$diff_num" 2 "ci_trigger" "FAILED_escalate_now"
                    write_escalation_manifest "$diff_num" "$first_failure_label" 2 \
                        "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
                    {
                        printf '  • %s: %s\n' "$diff_num" "$first_failure_label"
                        printf '    tried: ci-trigger (call errored, not verdict)\n'
                        printf '    draft reply: CI red on `%s`, retrigger call failed — investigating.\n' "$first_failure_label"
                    } >> "$ESCALATIONS_FILE"
                    escalations=$((escalations + 1))
                fi
            else
                # Defer disabled — original behavior: retrigger + escalate immediately.
                tried="ci-trigger (re-run in case of flake)"
                if [ "$DRY_RUN" = "1" ]; then
                    audit_log "$diff_num" 2 "ci_trigger" "DRY_RUN_skip"
                elif timeout 30 meta phabricator.diff ci-trigger -n "$diff_num" >/dev/null 2>&1; then
                    audit_log "$diff_num" 2 "ci_trigger" "TRIGGERED"
                else
                    audit_log "$diff_num" 2 "ci_trigger" "FAILED"
                    tried="ci-trigger attempted but failed"
                fi
                write_escalation_manifest "$diff_num" "$first_failure_label" 2 \
                    "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
                {
                    printf '  • %s: %s\n' "$diff_num" "$first_failure_label"
                    printf '    tried: %s\n' "$tried"
                    printf '    draft reply: CI red on `%s` — re-triggered to rule out flake. Will dig in if it stays red.\n' "$first_failure_label"
                } >> "$ESCALATIONS_FILE"
                escalations=$((escalations + 1))
            fi
            ;;
        3|*)
            echo "$LOG_PREFIX   CLASS 3 — escalating (uncertain or demoted)"
            audit_log "$diff_num" 3 "escalate" "UNCERTAIN_or_DEMOTED"
            write_escalation_manifest "$diff_num" "$first_failure_label" 3 \
                "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "${DIFF_PASSED:-0}"
            {
                printf '  • %s: %s\n' "$diff_num" "$first_failure_label"
                printf '    tried: classification only (uncertain → conservative escalation)\n'
                if [ -n "${LINT_DETAIL_TEXT:-}" ]; then
                    printf '%s' "$LINT_DETAIL_TEXT"
                fi
                # target-determinator fails by applying the diff onto trunk to compute
                # affected targets — so a failure most often means a MERGE CONFLICT /
                # stale base, not infra flake (2026-06-01, D107103689). Give an
                # actionable hint instead of generic "investigating". No auto-mutation
                # here: this cron also scans diffs Denny only reviews, and must never
                # rebase/abandon someone else's diff.
                if printf '%s' "$first_failure_label" | grep -qi 'target-determinator'; then
                    printf '    likely cause: MERGE CONFLICT / stale base (target-determinator can'\''t apply the diff onto trunk).\n'
                    printf '    action: rebase onto trunk (`jf get D%s && sl rebase -d remote/master`). If the rebase shows the diff'\''s changes are already on trunk, it'\''s redundant → `meta phabricator.diff abandon`.\n' "${diff_num#D}"
                fi
                printf '    draft reply: CI shows %sf/%sw on `%s`. Investigating — will follow up.\n' "${DIFF_FAILED:-0}" "${DIFF_WARNINGS:-0}" "$first_failure_label"
            } >> "$ESCALATIONS_FILE"
            escalations=$((escalations + 1))
            ;;
    esac
done

# ─── Restack after any amends, restore HEAD ──────────────────────────────
if [ "$auto_fixed" -gt 0 ] && [ "$DRY_RUN" != "1" ]; then
    cd "$FBSOURCE"
    if ! timeout 60 sl restack \
        --reason "restack after autofix amends - sl help restack" >/dev/null 2>&1; then
        echo "$LOG_PREFIX [WARN] sl restack failed — partial state in stack"
        audit_log "-" "-" "sl_restack" "FAILED"
    else
        audit_log "-" "-" "sl_restack" "OK"
    fi
    cd "$ORIG_PWD"
fi
# (HEAD restoration handled by cleanup trap)

echo "$LOG_PREFIX Summary: queried=$queried auto_fixed=$auto_fixed escalations=$escalations errored=$errored"
audit_log "-" "-" "run_summary" "queried=${queried}_fixed=${auto_fixed}_esc=${escalations}_err=${errored}"

# ─── Reviewer queue: diffs awaiting Denny's action as reviewer ──────────
# Independent of the authored-diff CI loop above. These are diffs OTHER
# people authored where Denny is on the hook to act (review, re-review,
# resolve comments, etc).
REVIEW_QUEUE_FILE=$(mktemp /tmp/cron-diff-signal-review-queue.XXXXXX)
trap 'cleanup; rm -f "$REVIEW_QUEUE_FILE"' EXIT
review_pending=0

review_raw=$(timeout 60 meta phabricator.diff list \
    --reviewers-include-me --review-stage-is="Action Required" \
    --author-is-not=dennyzhang \
    --columns=number,title,author,status \
    -o json 2>/dev/null || echo '[]')

if echo "$review_raw" | python3 -c "import sys,json; json.loads(sys.stdin.read())" 2>/dev/null; then
    while IFS=$'\t' read -r r_num r_author r_title; do
        [ -z "$r_num" ] && continue
        printf '  • %s (by %s): %s\n' "$r_num" "$r_author" "$r_title" >> "$REVIEW_QUEUE_FILE"
        review_pending=$((review_pending + 1))
    done < <(echo "$review_raw" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
for d in (data or []):
    if not isinstance(d, dict): continue
    num = d.get('number','')
    author = d.get('author','')
    title = (d.get('title','') or '').replace('\t',' ')[:120]
    if num: print(f'{num}\t{author}\t{title}')
")
    audit_log "-" "-" "review_queue" "FOUND_${review_pending}"
else
    audit_log "-" "-" "review_queue" "QUERY_FAILED"
fi
echo "$LOG_PREFIX Review queue: $review_pending diff(s) awaiting your action"

# ─── Send escalation message (only when needed) ──────────────────────────
if [ "$escalations" -eq 0 ] && [ "$review_pending" -eq 0 ]; then
    if [ "$auto_fixed" -gt 0 ]; then
        echo "$LOG_PREFIX All non-green diffs auto-fixed silently ($auto_fixed); review queue empty."
    else
        echo "$LOG_PREFIX No escalations, no review queue. Silent exit."
    fi
    write_heartbeat "diff-signal-monitor"
    cron_alert_clear "diff-signal-monitor"
    exit 0
fi

message="⚠️ *Diff Signal Check — ${TODAY}*"

if [ "$escalations" -gt 0 ]; then
    message="${message}

*Your diffs* (${escalations} need judgment):
$(cat "$ESCALATIONS_FILE")"
fi

if [ "$review_pending" -gt 0 ]; then
    message="${message}

*Awaiting your review* (${review_pending}):
$(cat "$REVIEW_QUEUE_FILE")"
fi
if [ "$auto_fixed" -gt 0 ]; then
    message="${message}
_(silently auto-fixed ${auto_fixed} mechanical issue(s); see ${ACTION_LOG})_"
fi
if [ "$errored" -gt 0 ]; then
    message="${message}
_(${errored} diff(s) failed ci-status query — investigate manually)_"
fi

# Durable both-fail fallback: if a PRIOR run's send failed (both as-bot AND as-user
# paths), the escalation was saved to this file so a transient gmux/auth blip never
# silently drops an alert. Flush it by prepending to this run's message; the file is
# cleared only after a successful send below. (Tested 2026-06-16: both send paths work;
# the gap was no durable retry when both fail transiently, as at the 16:00 cron.)
DSM_PENDING_FILE="$REPO_DIR/state/diff-signal-pending-escalation.md"
if [ -s "$DSM_PENDING_FILE" ]; then
    message="_(recovered from a prior failed send)_
$(cat "$DSM_PENDING_FILE")

---
${message}"
    echo "$LOG_PREFIX Flushing pending escalation from a prior failed send"
fi

if [ "$DRY_RUN" = "1" ]; then
    echo "$LOG_PREFIX [DRY] Would send to $PYLON_SPACE:"
    echo "$message" | sed "s|^|$LOG_PREFIX [DRY-MSG] |"
    write_heartbeat "diff-signal-monitor"
    exit 0
fi

# Thread discipline (2026-05-30): post EVERY diff-signal check into ONE
# persistent thread instead of space root, so the whole topic stays threaded
# and replies fold in (Denny: "the diff-signal cron posts to space root").
# Persist the thread id on first send. Thread-targeted sends require --as-bot
# (user OAuth token lacks chat.messages.create scope). If the as-bot send
# fails, fall back to the prior as-user root send so a notification is never
# lost (degraded: no threading). Set DSM_THREAD_ENABLED=0 to disable.
DSM_THREAD_ENABLED="${DSM_THREAD_ENABLED:-1}"
DSM_THREAD_STATE_FILE="$REPO_DIR/state/diff-signal-thread-id"
DSM_SAVED_THREAD=""
[ -f "$DSM_THREAD_STATE_FILE" ] && DSM_SAVED_THREAD=$(tr -d '[:space:]' < "$DSM_THREAD_STATE_FILE" 2>/dev/null)

dsm_used_fallback=0
if [ "$DSM_THREAD_ENABLED" = "1" ]; then
    if [ -n "$DSM_SAVED_THREAD" ]; then
        send_out=$(echo "$message" | timeout 30 google-mux chat --format=json send "$PYLON_SPACE" - \
            --thread "${PYLON_SPACE}/threads/${DSM_SAVED_THREAD}" --as-bot 2>&1)
    else
        send_out=$(echo "$message" | timeout 30 google-mux chat --format=json send "$PYLON_SPACE" - --as-bot 2>&1)
    fi
    send_exit=$?
    if [ "$send_exit" -ne 0 ]; then
        echo "$LOG_PREFIX [WARN] threaded as-bot send failed (exit=$send_exit) — falling back to as-user root"
        send_out=$(echo "$message" | timeout 30 google-mux chat send "$PYLON_SPACE" - 2>&1)
        send_exit=$?
        dsm_used_fallback=1
    fi
else
    send_out=$(echo "$message" | timeout 30 google-mux chat send "$PYLON_SPACE" - 2>&1)
    send_exit=$?
    dsm_used_fallback=1
fi

if [ "$send_exit" -eq 0 ]; then
    # First successful threaded send: capture + persist the thread id.
    if [ -z "$DSM_SAVED_THREAD" ] && [ "$dsm_used_fallback" -eq 0 ]; then
        new_thread=$(echo "$send_out" | python3 -c "
import json, sys, re
try:
    d = json.loads(sys.stdin.read().splitlines()[-1])
    t = d.get('data', {}).get('thread', {}).get('name', '')
    m = re.search(r'threads/([^/]+)', t)
    print(m.group(1) if m else '')
except Exception:
    print('')
" 2>/dev/null)
        if [ -n "$new_thread" ]; then
            mkdir -p "$(dirname "$DSM_THREAD_STATE_FILE")"
            echo "$new_thread" > "$DSM_THREAD_STATE_FILE"
            echo "$LOG_PREFIX Captured diff-signal thread id: $new_thread (persisted)"
        else
            echo "$LOG_PREFIX [WARN] could not parse thread id — next run may create another root thread"
        fi
    fi
    echo "$LOG_PREFIX Sent escalation ($escalations diffs, thread=${DSM_SAVED_THREAD:-NEW}, fallback=$dsm_used_fallback)"
    audit_log "-" "-" "escalation_send" "OK_$escalations"
    cron_alert_clear "diff-signal-monitor"
    # Send succeeded (incl. any flushed pending) — clear the durable backlog.
    [ -f "$DSM_PENDING_FILE" ] && rm -f "$DSM_PENDING_FILE"
else
    echo "$LOG_PREFIX [WARN] GChat send failed (exit=$send_exit)"
    audit_log "-" "-" "escalation_send" "FAILED_exit_$send_exit"
    cron_alert "diff-signal-monitor" "GChat send failed (exit=$send_exit), $escalations diffs unreported"
    # Both paths failed — persist the message so the next run flushes it (never lost).
    mkdir -p "$(dirname "$DSM_PENDING_FILE")"
    printf '%s\n' "$message" > "$DSM_PENDING_FILE"
    echo "$LOG_PREFIX Saved escalation to $DSM_PENDING_FILE — will retry next run"
fi

write_heartbeat "diff-signal-monitor"
echo "$LOG_PREFIX === Done ==="
