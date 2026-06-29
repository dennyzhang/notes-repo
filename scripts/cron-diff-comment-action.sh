#!/usr/bin/env bash
# cron-diff-comment-action.sh — close open Devmate/human comments on MY diffs.
#
# WHY: diff-signal-monitor handles failing CI signals but does NOT fix open
# inline/Devmate review comments — so advisory comments on green diffs just
# accumulate (Denny flagged 2026-06-18: 8 open diffs carrying ~37 unaddressed
# comments). The Pre-Submit Gate #9 cheatsheet described this cron as existing;
# it never did. This builds it.
#
# WHAT (per run): enumerate MY open diffs -> for each with >=1 unresolved
# non-author comment (read-only `meta phabricator.diff comments`), dispatch a
# headless agent to FIX THE CODE the comment asks for -> arc lint -> arc pyre ->
# sl amend -> jf submit --draft. Cap 3 diffs/run.
#
# HARD GUARDS (defense in depth — these are load-bearing):
#   - MINE ONLY: --author-is-me; the agent re-verifies author==dennyzhang.
#   - READ-ONLY on Phab: NEVER post/reply/resolve a comment (bash-guard enforces).
#     Comments are closed by fixing code + amending, never by touching the thread.
#   - DRAFT ONLY: jf submit --draft --publish-when-ready (jf wrapper + bash-guard
#     Pylon-draft enforcement). Never publishes, never lands.
#   - SKIP DIRTY WC: if the shared fbsource checkout is dirty, skip (don't fight
#     a concurrent task / the shared-checkout collision).
#   - VERIFY-OR-REVERT: if lint/pyre fail after the edit, the agent reverts.
#   - CONFIGERATOR / non-FBS diffs: skipped (out of scope for this cron).
#
# NOT a standalone cron. Launched in the BACKGROUND by cron-diff-signal-monitor
# at the end of each of its runs (consolidated 2026-06-18 per Denny: don't add a
# new cron when the diff flywheel already enumerates my open diffs every run).
# Background-launched because the LLM fixer can take ~20min/diff and must not
# block the monitor's timeout. The lock below prevents overlapping launches.
set -eo pipefail

REPO_DIR="$HOME/work/claude"
FBSOURCE="$HOME/fbsource/fbcode"
CAP=3   # max diffs handled per run

unset CLAUDECODE 2>/dev/null || true
# shellcheck disable=SC1091
source "$REPO_DIR/scripts/cron-alert.sh"
# shellcheck disable=SC1091
source "$REPO_DIR/scripts/lib/llm-dispatch.sh"

# Single-run lock — overlapping launches (e.g. a slow run + the next monitor
# pass) must not race on the shared fbsource checkout.
LOCK="/tmp/cron-diff-comment-action.lock"
if [ -f "$LOCK" ]; then
    lpid=$(cat "$LOCK" 2>/dev/null || echo "")
    if [ -n "$lpid" ] && kill -0 "$lpid" 2>/dev/null; then
        cron_log "another comment-action run active (pid $lpid) — skipping"; exit 0
    fi
    rm -f "$LOCK"
fi
echo $$ > "$LOCK"
# shellcheck disable=SC2064
trap "rm -f '$LOCK'" EXIT

cron_log "=== diff-comment-action: scanning my open diffs ==="

[ -d "$FBSOURCE" ] || { cron_alert "diff-comment-action" "fbsource missing"; exit 1; }
cd "$FBSOURCE"

# Skip if the shared checkout is dirty — never fight a concurrent task.
if [ -n "$(sl status --reason 'comment-action dirty check - sl help status' 2>/dev/null | head -1)" ]; then
    cron_log "fbsource WC dirty — skipping this run (avoid shared-checkout collision)"
    write_heartbeat "diff-comment-action"
    exit 0
fi

# Let the headless agent's jf submit pass the preflight gate.
create_preflight_sentinels

# Enumerate my open diffs (FBS only handled here).
mapfile -t DIFFS < <(timeout 60 meta phabricator.diff list --author-is-me --include-only-open -l 50 2>/dev/null \
    | awk 'NR>2 && $1 ~ /^D[0-9]+/ {print $1}')

[ "${#DIFFS[@]}" -gt 0 ] || { cron_log "no open diffs"; write_heartbeat "diff-comment-action"; exit 0; }

handled=0
for d in "${DIFFS[@]}"; do
    [ "$handled" -lt "$CAP" ] || { cron_log "cap $CAP reached — stopping"; break; }

    # Count only SUBSTANTIVE unresolved non-author comments: human reviewers, or
    # land-blocking/critical bot signals. SKIP pure-advisory bot nits
    # ('signal (advice)' / 'signal (warning)' from ai_diff_reviewer/lint_root).
    # Chasing advisory nits is a treadmill (D109035581, 2026-06-18): each fix
    # regenerates a fresh batch, churns draft versions, and leaves a
    # 'latest_phabricator_version_is_draft' land-blocker. Advisory comments do
    # NOT block landing, so the cron must not touch a diff that has only those.
    n=$(timeout 40 meta phabricator.diff comments -n "$d" --unresolved-only --skip-author --output=json 2>/dev/null \
        | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: print(0); sys.exit()
items=d if isinstance(d,list) else d.get("comments",d.get("items",[]))
print(sum(1 for c in items if not any(k in str(c.get("source","")).lower() for k in ("advice","warning"))))' 2>/dev/null || echo 0)
    if [ "${n:-0}" -le 0 ]; then
        cron_log "$d: only advisory/warning bot comments — skip (avoid treadmill + draft-land-blocker churn)"
        continue
    fi

    # Only FBS diffs; skip configerator/www.
    repo=$(timeout 30 meta phabricator.diff describe -n "$d" 2>/dev/null | awk '/^  repository:/{print $2; exit}')
    if [ "$repo" != "FBS" ]; then cron_log "$d: repo=$repo (not FBS) — skip"; continue; fi

    cron_log "$d: $n unresolved non-author comment(s) -> dispatching fixer"

    PROMPT=$(cat <<EOF
You are Pylon's autonomous diff-comment fixer running as an unattended cron turn.
TARGET DIFF: $d (a fbsource/fbcode diff authored by dennyzhang).

GOAL: close every OPEN, UNRESOLVED, non-author comment on $d by FIXING THE CODE
it asks for. A comment is closed by amending the fix, NEVER by touching the
comment thread.

ABSOLUTE RULES (violating any = abort the diff, change nothing):
1. READ-ONLY on Phabricator. NEVER run any 'meta phabricator.diff comment',
   reply-comment, inline-comment, resolve, accept, publish, or land. Read verbs
   only (comments, describe, ci-status).
2. MINE ONLY. Confirm 'meta phabricator.diff describe -n $d' shows author
   dennyzhang. If not, abort.
3. DRAFT ONLY. Submit with: jf submit --draft --publish-when-ready --update-fields  # diff-cheatsheet-ok
   Never publish, never land. If the diff is on a shared/dirty checkout you
   cannot cleanly goto, abort without changing anything.

STEPS:
- Read the open comments: meta phabricator.diff comments -n $d --unresolved-only --skip-author --output=json
- sl goto $d ; verify 'sl log -r . -T "{phabdiff}"' == $d (if not, abort — shared checkout moved).
- For each comment, make the SMALLEST correct code edit that addresses it. Skip a
  comment ONLY if it is purely advisory taste with no code action, or asks for a
  test-run you cannot perform; note which you skipped and why.
- Run 'arc lint --apply-patches' (unpiped) and 'arc pyre check-changed-targets'.
  If either has a real Error (not advisory), or your edit breaks the build, run
  'sl revert' on your changes and abort — do NOT submit a broken fix.
- sl amend ; then the draft submit command above.
- Verify the new version on Phab with 'meta phabricator.diff describe -n $d'.

Report a 3-line summary: comments fixed / comments skipped (with reason) / new version.
Keep every output line under 200 chars.
EOF
)

    rc=0
    run_llm "diff-comment-action" 1200 /dev/stdout "$PROMPT" \
        -- --allowedTools 'Read' 'Write' 'Edit' 'Glob' 'Grep' 'Bash(*)' 'Skill' \
        --effort high --max-turns 80 || rc=$?

    if [ "$rc" -eq 0 ]; then
        handled=$((handled + 1))
        cron_log "$d: fixer finished (rc=0)"
    else
        cron_alert "diff-comment-action" "$d: fixer exited rc=$rc — needs a look"
        cron_log "$d: fixer rc=$rc"
    fi

    # Re-skip if the agent left the WC dirty (shouldn't, but defense-in-depth).
    if [ -n "$(sl status --reason 'post-fixer dirty check - sl help status' 2>/dev/null | head -1)" ]; then
        cron_log "WC dirty after $d — stopping run to avoid clobbering"
        break
    fi
done

cron_log "=== diff-comment-action done: handled $handled diff(s) ==="
write_heartbeat "diff-comment-action"
cron_alert_clear "diff-comment-action"
