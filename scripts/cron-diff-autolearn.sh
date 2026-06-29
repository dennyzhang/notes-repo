#!/usr/bin/env bash
# cron-diff-autolearn.sh — Weekly scan of diff reviewer comments → cheatsheet updates.
#
# Autolearn Channel 1: Reads reviewer comments on recent diffs, extracts
# recurring patterns, and appends new rules to diff cheatsheet Common Mistakes.
#
# Schedule: Weekly Monday 6 AM via crontab
# Crontab entry:
#   0 6 * * 1 source ~/work/claude/scripts/cron-alert.sh && cron_run 900 diff-autolearn ~/work/claude/scripts/cron-diff-autolearn.sh >> ~/logs/diff-autolearn.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
LOCK_FILE="/tmp/cron-diff-autolearn.lock"

# Clear Claude Code session markers
unset CLAUDECODE 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "diff-autolearn" "Workspace missing"
    exit 1
fi

# Prevent overlapping runs
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$lock_age" -lt 3600 ]; then
        echo "$LOG_PREFIX Already running (pid $pid), skipping"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE" /tmp/cron-diff-autolearn-diffs.json /tmp/cron-diff-autolearn-comments.md /tmp/cron-diff-autolearn-output.md /tmp/cron-diff-autolearn-existing.md' EXIT

echo "$LOG_PREFIX === Diff Review Autolearn ==="

# Step 1: Find recent diffs authored by Denny (last 7 days)
SEVEN_DAYS_AGO=$(date -d '7 days ago' '+%Y-%m-%dT00:00:00Z' 2>/dev/null || date -v-7d '+%Y-%m-%dT00:00:00Z')
DIFF_LIST="/tmp/cron-diff-autolearn-diffs.json"

meta search.doc search -q " " --doc-type=DIFF --author-is-me \
    --start-creation-time="$SEVEN_DAYS_AGO" --limit=20 -o json 2>/dev/null > "$DIFF_LIST" || echo "[]" > "$DIFF_LIST"

diff_count=$(python3 -c "import json; d=json.load(open('$DIFF_LIST')); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo "0")
echo "$LOG_PREFIX Found $diff_count diffs in last 7 days"

if [ "$diff_count" -eq 0 ]; then
    echo "$LOG_PREFIX No diffs to scan. Exiting."
    write_heartbeat "diff-autolearn"
    exit 0
fi

# Step 2: Extract diff numbers and fetch comments
COMMENTS_FILE="/tmp/cron-diff-autolearn-comments.md"
echo "# Reviewer Comments on Recent Diffs ($TODAY)" > "$COMMENTS_FILE"

python3 -c "
import json, subprocess, sys

with open('$DIFF_LIST') as f:
    diffs = json.load(f)

if not isinstance(diffs, list):
    diffs = []

for diff in diffs[:15]:  # Cap at 15
    title = diff.get('title', 'Unknown')
    url = diff.get('url', '')
    # Extract diff number from URL
    diff_num = ''
    if '/D' in url:
        diff_num = 'D' + url.split('/D')[-1].split('/')[0].split('?')[0]
    elif 'diff_id' in diff:
        diff_num = 'D' + str(diff['diff_id'])

    if not diff_num:
        continue

    # Fetch comments
    try:
        result = subprocess.run(
            ['meta', 'phabricator.diff', 'comments', '-n', diff_num, '-o', 'json'],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0:
            comments = json.loads(result.stdout)
            # Filter for actionable review comments (not from dennyzhang, not inline-only)
            review_comments = []
            if isinstance(comments, list):
                for c in comments:
                    author = c.get('author', {}).get('username', '') if isinstance(c.get('author'), dict) else str(c.get('author', ''))
                    if 'dennyzhang' not in author.lower():
                        content = c.get('content', '') or c.get('message', '') or ''
                        if len(content) > 20:  # Skip short comments (LGTM, etc)
                            review_comments.append({
                                'author': author,
                                'content': content[:500]  # Truncate long comments
                            })

            if review_comments:
                with open('$COMMENTS_FILE', 'a') as f:
                    f.write(f'\n## {diff_num}: {title}\n')
                    for rc in review_comments:
                        f.write(f'- **{rc[\"author\"]}**: {rc[\"content\"]}\n')
    except Exception as e:
        print(f'Error fetching comments for {diff_num}: {e}', file=sys.stderr)
" 2>/dev/null

comment_lines=$(wc -l < "$COMMENTS_FILE")
echo "$LOG_PREFIX Collected $comment_lines lines of reviewer comments"

if [ "$comment_lines" -lt 5 ]; then
    echo "$LOG_PREFIX Not enough reviewer comments to analyze. Exiting."
    write_heartbeat "diff-autolearn"
    rm -f "$COMMENTS_FILE" "$DIFF_LIST"
    exit 0
fi

# Step 3: Claude extracts patterns
AUTOLEARN_OUTPUT="/tmp/cron-diff-autolearn-output.md"
EXISTING_RULES="/tmp/cron-diff-autolearn-existing.md"

# Learned rows live in diff-learnings-log.md § Common Mistakes — the dated rows
# were distilled OUT of common.md (whose Common Mistakes table is now empty), so
# dedup MUST read the log, and writes below MUST target the log. Reading the old
# empty common.md table is why Channel 1 silently no-op'd after the distillation.
LEARNINGS_LOG="$REPO_DIR/cheatsheets/diff/diff-learnings-log.md"
{
    echo "# Existing Common Mistakes (for dedup)"
    { grep "^|" "$LEARNINGS_LOG" 2>/dev/null || true; } | head -60
} > "$EXISTING_RULES"

autolearn_exit=0
run_llm "diff-autolearn" 180 "$AUTOLEARN_OUTPUT" "You are the diff review autolearn engine.

## INPUTS
1. Reviewer comments: $COMMENTS_FILE
2. Existing cheatsheet rules: $EXISTING_RULES

## TASK
1. Read both files.
2. Identify ACTIONABLE patterns in reviewer comments — things that indicate a recurring mistake or a convention Claude should learn. Skip: 'LGTM', questions, one-off domain-specific comments.
3. For each pattern, check if it ALREADY exists in the existing rules (dedup by meaning, not exact text).
4. For NEW patterns only, OUTPUT them as your FINAL TEXT RESPONSE in this exact
   format (print it — do NOT use any file-editing tool; a wrapper parses your
   text and inserts the rows safely):

FILE: cheatsheets/diff/diff-learnings-log.md
| What happened | Correct approach |
|---|---|
| Description of the mistake | The fix (Learned $TODAY: DXXXXXX autolearn) |

If no new patterns found, output exactly 'NO_NEW_PATTERNS'.

## RULES
- Read tool ONLY. NEVER write or edit files — print your answer as text.
- Maximum 5 new patterns per run (quality over quantity).
- Each pattern must reference the specific diff number it came from.
- Do NOT include patterns that are already in the existing rules." \
    -- --allowedTools Read \
    --max-turns 8 \
    || autolearn_exit=$?

patterns_added=0
if [ "$autolearn_exit" -eq 0 ] && [ -f "$AUTOLEARN_OUTPUT" ] && [ -s "$AUTOLEARN_OUTPUT" ]; then
    if grep -q "NO_NEW_PATTERNS" "$AUTOLEARN_OUTPUT"; then
        echo "$LOG_PREFIX No new patterns found"
    else
        # Parse + insert each row via the shared helper (single race-safe,
        # deduped, idempotent insert into the § Common Mistakes table — see
        # private_scripts/lib/cheatsheet_insert_row.py). The old inline sed/python
        # both targeted common.md's now-empty table (silent no-op) and had a
        # row-duplication history.
        current_file=""
        while IFS= read -r line; do
            if [[ "$line" == "FILE: "* ]]; then
                current_file="$REPO_DIR/${line#FILE: }"
            elif [[ "$line" == "|"* && -n "$current_file" && "$line" != *"What happened"* && "$line" != *"---"* ]]; then
                [ -f "$current_file" ] || continue
                # `if var=$(cmd); then` keeps this set-e-safe: a dedup skip
                # (exit 2) must NOT abort the cron — only exit 0 = inserted.
                if ins_out=$(python3 "$REPO_DIR/private_scripts/lib/cheatsheet_insert_row.py" \
                        "$current_file" "## Common Mistakes" "$line" 2>/dev/null); then
                    patterns_added=$((patterns_added + 1))
                    echo "$LOG_PREFIX Added: ${ins_out}"
                    echo "$(date '+%Y-%m-%d %H:%M'),diff-review,added,$(basename "$current_file"),${ins_out}" >> "$REPO_DIR/state/autolearn-metrics.csv"
                fi
            fi
        done < "$AUTOLEARN_OUTPUT"
    fi
else
    echo "$LOG_PREFIX Pattern extraction failed (exit=$autolearn_exit)"
fi

# Cleanup
rm -f "$COMMENTS_FILE" "$DIFF_LIST" "$EXISTING_RULES" "$AUTOLEARN_OUTPUT"

# ─── Channel 2: Diff Flywheel — Stage 2 distillation ─────────────────────
# Reads ~/logs/diff-signal-monitor.log audit lines, computes per-signal
# stats, writes promotions to candidates.json (and live.json if
# FLYWHEEL_PROMOTE_TO_LIVE=1). Cutover gate: shadow_only=1 by default.
# Cutover 2026-04-23: FLYWHEEL_ENABLED default ON; FLYWHEEL_PROMOTE_TO_LIVE
# stays OFF for the 1-week shadow gate. Denny flips PROMOTE_TO_LIVE=1 after
# 1 week of clean shadow runs (per design doc Step 8).
FLYWHEEL_ENABLED="${FLYWHEEL_ENABLED:-1}"
FLYWHEEL_PROMOTE_TO_LIVE="${FLYWHEEL_PROMOTE_TO_LIVE:-0}"
FLYWHEEL_DIR="$REPO_DIR/state/diff-flywheel"
FLYWHEEL_DISTILL_PY="$HOME/work/claude/private_scripts/lib/diff-flywheel-distill.py"
FLYWHEEL_CHANNEL3_PY="$HOME/work/claude/private_scripts/lib/diff-flywheel-channel3.py"

if [ "$FLYWHEEL_ENABLED" = "1" ] && [ -f "$FLYWHEEL_DISTILL_PY" ]; then
    echo "$LOG_PREFIX === Channel 2: Diff Flywheel distillation ==="
    shadow_arg=1
    [ "$FLYWHEEL_PROMOTE_TO_LIVE" = "1" ] && shadow_arg=0
    if distill_out=$(timeout 60 python3 "$FLYWHEEL_DISTILL_PY" \
            --audit-log "$HOME/logs/diff-signal-monitor.log" \
            --live "$FLYWHEEL_DIR/live.json" \
            --candidates "$FLYWHEEL_DIR/candidates.json" \
            --human-layer "$REPO_DIR/cheatsheets/diff/learned-classifier.md" \
            --window-days 30 \
            --shadow-only "$shadow_arg" 2>&1); then
        echo "$LOG_PREFIX Channel 2: $distill_out"
    else
        echo "$LOG_PREFIX Channel 2 FAILED: $distill_out"
        cron_alert "diff-autolearn" "Channel 2 distill failed"
    fi
fi

# ─── Channel 3: Diff Flywheel — close-loop attribution → candidates ──────
# Reads learning-events.jsonl (written by signal-monitor when Denny
# resolves an escalated diff), captures each as a candidate pattern with
# tier=human_attribution. v1: literal signal_regex; v2 will add LLM-driven
# generalized pattern extraction from `sl diff` between before/after.
if [ "$FLYWHEEL_ENABLED" = "1" ] && [ -f "$FLYWHEEL_CHANNEL3_PY" ]; then
    echo "$LOG_PREFIX === Channel 3: Diff Flywheel close-loop attribution ==="
    if ch3_out=$(timeout 60 python3 "$FLYWHEEL_CHANNEL3_PY" \
            --events "$FLYWHEEL_DIR/learning-events.jsonl" \
            --processed "$FLYWHEEL_DIR/learning-events-processed.txt" \
            --candidates "$FLYWHEEL_DIR/candidates.json" 2>&1); then
        echo "$LOG_PREFIX Channel 3: $ch3_out"
    else
        echo "$LOG_PREFIX Channel 3 FAILED: $ch3_out"
        cron_alert "diff-autolearn" "Channel 3 attribution failed"
    fi
fi

# Channel 4 (Auto-Review-Bot graduation) removed 2026-06-17 — diff-reviewer-comment
# consolidated into cron-ai-diff-review.sh (multi-LLM, gdoc append, no Phab posting).
# The graduation→autonomous-Phab-post path was dormant; revisit only if reinstated.

# ─── Channel 5: red-CI → authoring cheatsheet rule (reliable flywheel) ────
# Closes the arc Channels 2/3 leave open: red CI only trains the reactive FIXER;
# nothing teaches the AUTHORING agent to stop generating diffs that go red.
#
# Reliability design (each addresses a specific failure mode):
#   - Failure-isolated: the whole channel runs inside run_channel5(), invoked as
#     `run_channel5 || cron_alert`. set -e is suspended in a function whose
#     result is tested, so ANY internal failure returns cleanly and can NEVER
#     abort the cron or the other channels (attack A1).
#   - Observable: every run appends a funnel record to channel5-runs.jsonl
#     (events→groups→proposed→verified→inserted→pending→dupe→errors) so an idle
#     or stalled wheel is visible, not silent (attacks A2).
#   - Quality-gated: per group, an independent VERIFY pass adversarially checks
#     each proposed rule; only verified rules reach the live cheatsheet, the rest
#     go to channel5-pending.md for the weekly digest (attack A3, hot-path
#     pollution).
#   - Convergent + closed-loop: a processed-marker (channel5-processed.json)
#     records each signature's decision so groups aren't re-litigated weekly, and
#     records rule_added_at so a recurrence AFTER a rule is detected and the rule
#     flagged ineffective for revision (attacks A5, A7).
#   - GC-aware: distinguishes "fix diff empty because rebase" from "commit GC'd /
#     unresolvable" so a real lesson isn't silently dropped as a non-lesson (A4).
# Set CHANNEL5_ENABLED=0 to disable.
CHANNEL5_ENABLED="${CHANNEL5_ENABLED:-1}"
CH5_MIN_COUNT="${CH5_MIN_COUNT:-2}"
CH5_WINDOW_DAYS="${CH5_WINDOW_DAYS:-30}"
CH5_MAX_GROUPS="${CH5_MAX_GROUPS:-5}"
CH5_AGG_PY="$REPO_DIR/private_scripts/lib/diff-flywheel-channel5-aggregate.py"
CH5_REC_PY="$REPO_DIR/private_scripts/lib/diff-flywheel-channel5-record.py"
CH5_INSERT_PY="$REPO_DIR/private_scripts/lib/cheatsheet_insert_row.py"
CH5_EVICT_PY="$REPO_DIR/private_scripts/lib/cheatsheet_evict.py"
CH5_FBSOURCE="${FBSOURCE:-$HOME/fbsource}"
CH5_MARKER="$FLYWHEEL_DIR/channel5-processed.json"
CH5_RUNS="$FLYWHEEL_DIR/channel5-runs.jsonl"
CH5_PENDING="$FLYWHEEL_DIR/channel5-pending.md"
CH5_DIGEST="$FLYWHEEL_DIR/channel5-digest.md"
CH5_ARCHIVE="$REPO_DIR/cheatsheets/diff/diff-learnings-log-archive.md"
CH5_TABLE_CAP="${CH5_TABLE_CAP:-50}"

# Fetch the fix diff for a group's commit pairs into $2, GC-aware.
# Echoes a reason token: "code" | "rebase" | "unavailable".
ch5_fetch_fix_diff() {
    local pairs="$1" out="$2" parr pr bf af resolved=0
    : > "$out"
    IFS=';' read -ra parr <<< "$pairs"
    for pr in "${parr[@]}"; do
        bf="${pr%%:*}"; af="${pr##*:}"
        [ -z "$bf" ] && continue
        # GC check: can sl resolve BOTH commits? If not, the diff would read
        # empty and be mislabeled "rebase" — distinguish it instead.
        if ! ( cd "$CH5_FBSOURCE" && timeout 20 sl log -r "$af" -T '{node}' \
                --reason "ch5 gc-check - sl help log" </dev/null >/dev/null 2>&1 ); then
            continue
        fi
        resolved=1
        ( cd "$CH5_FBSOURCE" && timeout 30 sl diff -r "$bf" -r "$af" \
            --reason "channel5 read fix diff - sl help diff" </dev/null 2>/dev/null ) \
            | head -120 >> "$out" || true
    done
    if [ "$resolved" -eq 0 ]; then echo "unavailable"
    elif [ -s "$out" ]; then echo "code"
    else echo "rebase"; fi
}

run_channel5() {
    local n_events n_groups=0 n_proposed=0 n_verified=0 n_inserted=0 \
          n_pending=0 n_dupe=0 n_notlesson=0 n_ineffective=0 n_unavailable=0
    # NOTE: `grep -c` prints "0" AND exits 1 on zero matches, so `|| echo 0`
    # would double-print "0\n0" and corrupt the funnel JSON. Swallow exit, default.
    n_events=$(grep -c "human_post_escalation_fix" "$FLYWHEEL_DIR/learning-events.jsonl" 2>/dev/null || true)
    n_events=${n_events:-0}

    local recurring="/tmp/cron-diff-autolearn-ch5-recurring.json"
    local groups_tsv="/tmp/cron-diff-autolearn-ch5-groups.tsv"
    local existing="/tmp/cron-diff-autolearn-ch5-existing.md"
    local gctx="/tmp/cron-diff-autolearn-ch5-gctx.md"
    local gdiff="/tmp/cron-diff-autolearn-ch5-gdiff.txt"
    local pout="/tmp/cron-diff-autolearn-ch5-propose.md"
    local vout="/tmp/cron-diff-autolearn-ch5-verify.md"

    python3 "$CH5_AGG_PY" --events "$FLYWHEEL_DIR/learning-events.jsonl" \
        --processed "$CH5_MARKER" --window-days "$CH5_WINDOW_DAYS" \
        --min-count "$CH5_MIN_COUNT" --max-groups "$CH5_MAX_GROUPS" \
        > "$recurring" 2>/dev/null || echo "[]" > "$recurring"
    n_groups=$(python3 -c "import json;print(len(json.load(open('$recurring'))))" 2>/dev/null || echo 0)
    echo "$LOG_PREFIX Channel 5: ${n_events} event(s) in log, ${n_groups} actionable group(s)"

    if [ "${n_groups:-0}" -eq 0 ]; then
        python3 "$CH5_REC_PY" funnel --runs "$CH5_RUNS" \
            --record "{\"events\":${n_events},\"groups\":0,\"inserted\":0,\"pending\":0,\"note\":\"idle\"}" 2>/dev/null || true
        rm -f "$recurring"
        return 0
    fi

    grep "^|" "$LEARNINGS_LOG" 2>/dev/null | head -120 > "$existing" || true

    # One TSV row per group (FILE not pipe → inner sl can't drain the loop stdin).
    python3 -c "
import json
for g in json.load(open('$recurring')):
    pairs=';'.join(f\"{p['before']}:{p['after']}\" for p in g.get('commit_pairs',[])[:2])
    print('\t'.join([g['signature'],g['category'],str(g['count']),
                     ','.join(g['source_diffs']),g.get('example_signal',''),
                     pairs,g.get('status','new'),g.get('prior_rule','')]))
" > "$groups_tsv" 2>/dev/null || true

    while IFS=$'\t' read -r sig cat cnt diffs example pairs status prior; do
        [ -z "$sig" ] && continue
        local reason
        reason=$(ch5_fetch_fix_diff "$pairs" "$gdiff")

        # No code evidence → record a decision so we converge, never re-LLM it.
        if [ "$reason" = "rebase" ]; then
            n_notlesson=$((n_notlesson + 1))
            python3 "$CH5_REC_PY" decide --marker "$CH5_MARKER" --signature "$sig" \
                --decision not_lesson --source-diffs "$diffs" 2>/dev/null || true
            echo "$LOG_PREFIX Channel 5 [$sig]: rebase/retrigger, no code lesson — skip"
            continue
        fi
        if [ "$reason" = "unavailable" ]; then
            n_unavailable=$((n_unavailable + 1))
            python3 "$CH5_REC_PY" decide --marker "$CH5_MARKER" --signature "$sig" \
                --decision not_lesson --source-diffs "$diffs" 2>/dev/null || true
            echo "$LOG_PREFIX Channel 5 [$sig]: fix commits GC'd / unresolvable — skip"
            continue
        fi

        # Build single-group context.
        {
            echo "## ${sig}  (×${cnt}, ${cat}, status=${status})"
            echo "Diffs: ${diffs}"
            echo "Signal: ${example}"
            [ -n "$prior" ] && echo "PRIOR RULE (recurred anyway — propose a STRONGER one): ${prior}"
            echo ""
            echo "How it was fixed (sl diff before→after):"
            echo '```diff'; cat "$gdiff"; echo '```'
        } > "$gctx"

        # PROPOSE pass.
        local pexit=0
        run_llm "diff-autolearn-ch5-propose" 150 "$pout" "You are the red-CI authoring-rule engine.
Input: a single recurring red-CI cause + the diff that fixed it ($gctx). Existing rules for dedup ($existing).
Produce AT MOST ONE generalizable PREVENTION rule — a rule that, had the authoring agent followed it, the diff would not have gone red. SKIP if it's a one-off, infra/flake, or already covered by an existing rule.
OUTPUT as your FINAL TEXT RESPONSE (print only — never edit files):
FILE: cheatsheets/diff/diff-learnings-log.md
| <the recurring mistake, one line> | <prevention rule> (Learned $TODAY: ${diffs%%,*} red-CI x${cnt}) |
If not generalizable, output exactly 'NO_NEW_PATTERNS'.
RULES: Read tool ONLY; never write files. Phrase as prevention, not cleanup. One row max." \
            -- --allowedTools Read --max-turns 6 || pexit=$?

        local row
        row=$(grep -E "^\| .* \|.*\|$" "$pout" 2>/dev/null | grep -v "What happened" | grep -v -- "---" | head -1 || true)
        if [ "$pexit" -ne 0 ] || [ -z "$row" ]; then
            n_notlesson=$((n_notlesson + 1))
            python3 "$CH5_REC_PY" decide --marker "$CH5_MARKER" --signature "$sig" \
                --decision not_lesson --source-diffs "$diffs" 2>/dev/null || true
            echo "$LOG_PREFIX Channel 5 [$sig]: no generalizable rule proposed"
            continue
        fi
        n_proposed=$((n_proposed + 1))

        # VERIFY pass — independent adversarial check (attack A3).
        local vexit=0
        run_llm "diff-autolearn-ch5-verify" 120 "$vout" "You are an adversarial reviewer of a proposed diff-authoring rule. Try to REFUTE it.
Proposed rule row: ${row}
Evidence it was derived from: ${gctx}
A rule is only valid if ALL hold: (1) it is a genuine AUTHORING mistake (not infra/flake/one-off), (2) it generalizes beyond these specific diffs, (3) the cited fix diff actually supports it, (4) it is actionable as prevention before submit, (5) it is not already standard/obvious.
Default to REJECT when uncertain.
OUTPUT exactly one line as your FINAL RESPONSE: 'KEEP' or 'REJECT: <short reason>'. Read tool ONLY; never edit files." \
            -- --allowedTools Read --max-turns 4 || vexit=$?

        if [ "$vexit" -eq 0 ] && grep -qiE "^KEEP\b|^KEEP$" "$vout" 2>/dev/null; then
            n_verified=$((n_verified + 1))
            if ins_out=$(python3 "$CH5_INSERT_PY" "$LEARNINGS_LOG" "## Common Mistakes" "$row" 2>/dev/null); then
                n_inserted=$((n_inserted + 1)); patterns_added=$((patterns_added + 1))
                echo "$LOG_PREFIX Channel 5 INSERTED [$sig]: ${ins_out}"
                echo "$(date '+%Y-%m-%d %H:%M'),red-ci,added,diff-learnings-log.md,${ins_out}" >> "$REPO_DIR/state/autolearn-metrics.csv"
            else
                n_dupe=$((n_dupe + 1))
                echo "$LOG_PREFIX Channel 5 dup [$sig]: rule already present"
            fi
            python3 "$CH5_REC_PY" decide --marker "$CH5_MARKER" --signature "$sig" \
                --decision inserted --source-diffs "$diffs" --rule-text "$row" 2>/dev/null || true
        else
            # Failed verification → stage for human glance, do NOT touch live file.
            n_pending=$((n_pending + 1))
            {
                echo "- **${TODAY}** [$sig ×${cnt}] proposed but UNVERIFIED — $(grep -iE '^REJECT' "$vout" 2>/dev/null | head -1)"
                echo "  candidate: ${row}"
                echo "  diffs: ${diffs}"
            } >> "$CH5_PENDING"
            python3 "$CH5_REC_PY" decide --marker "$CH5_MARKER" --signature "$sig" \
                --decision pending --source-diffs "$diffs" --rule-text "$row" 2>/dev/null || true
            echo "$LOG_PREFIX Channel 5 PENDING [$sig]: failed verify → staged"
        fi

        # Closed loop: a recurrence after a prior rule means that rule failed.
        if [ "$status" = "recurring_after_rule" ]; then
            n_ineffective=$((n_ineffective + 1))
            {
                echo "- **${TODAY}** [$sig] RULE INEFFECTIVE — recurred after prior rule was added; revise."
                echo "  prior: ${prior}"
            } >> "$CH5_PENDING"
            python3 "$CH5_REC_PY" decide --marker "$CH5_MARKER" --signature "$sig" \
                --decision ineffective --source-diffs "$diffs" 2>/dev/null || true
        fi
    done < "$groups_tsv"

    python3 "$CH5_REC_PY" funnel --runs "$CH5_RUNS" --record \
        "{\"events\":${n_events},\"groups\":${n_groups},\"proposed\":${n_proposed},\"verified\":${n_verified},\"inserted\":${n_inserted},\"pending\":${n_pending},\"dupe\":${n_dupe},\"not_lesson\":${n_notlesson},\"unavailable\":${n_unavailable},\"ineffective\":${n_ineffective}}" 2>/dev/null || true
    echo "$LOG_PREFIX Channel 5 funnel: proposed=${n_proposed} verified=${n_verified} inserted=${n_inserted} pending=${n_pending} dupe=${n_dupe} ineffective=${n_ineffective}"

    # A8 eviction: bound the live table by archiving the OLDEST flywheel-tagged
    # rows beyond the cap (human rows never touched, archive is reversible).
    if [ -f "$CH5_EVICT_PY" ]; then
        local ev
        ev=$(python3 "$CH5_EVICT_PY" "$LEARNINGS_LOG" "## Common Mistakes" \
            --archive "$CH5_ARCHIVE" --cap "$CH5_TABLE_CAP" \
            --tag-regex "autolearn|red-CI" --today "$TODAY" 2>/dev/null || echo "evict failed")
        echo "$LOG_PREFIX Channel 5 eviction: ${ev}"
    fi

    # Digest snapshot (overwrite each run) — the readable weekly artifact:
    # funnel + open pending queue + ineffective rules, co-located with state.
    local live_rules
    live_rules=$(grep -cE "Learned [0-9-]+.*(autolearn|red-CI)" "$LEARNINGS_LOG" 2>/dev/null || true)
    {
        echo "# Channel 5 (red-CI → authoring) — digest"
        echo ""
        echo "_Regenerated ${TODAY} by cron-diff-autolearn (weekly). Pull artifact; not pushed._"
        echo ""
        echo "## This run"
        echo "- events in log: ${n_events} | actionable groups: ${n_groups}"
        echo "- proposed: ${n_proposed} | verified→inserted: ${n_inserted} | dup: ${n_dupe}"
        echo "- pending (failed verify): ${n_pending} | ineffective flagged: ${n_ineffective}"
        echo "- skipped: ${n_notlesson} no-code-lesson, ${n_unavailable} commit-GC'd"
        echo "- live flywheel rules in cheatsheet: ${live_rules:-0} (cap ${CH5_TABLE_CAP})"
        echo ""
        echo "## Open pending queue (review / revise)"
        if [ -s "$CH5_PENDING" ]; then cat "$CH5_PENDING"; else echo "_none_"; fi
        echo ""
        echo "## Recent runs (funnel tail)"
        echo '```'
        tail -5 "$CH5_RUNS" 2>/dev/null || echo "(no runs yet)"
        echo '```'
    } > "$CH5_DIGEST" 2>/dev/null || true

    rm -f "$recurring" "$groups_tsv" "$existing" "$gctx" "$gdiff" "$pout" "$vout"
    return 0
}

if [ "$CHANNEL5_ENABLED" = "1" ] && [ -f "$CH5_AGG_PY" ] && [ -f "$CH5_REC_PY" ] \
        && [ -f "$FLYWHEEL_DIR/learning-events.jsonl" ]; then
    echo "$LOG_PREFIX === Channel 5: red-CI → authoring rule (window ${CH5_WINDOW_DAYS}d, >=${CH5_MIN_COUNT} diffs) ==="
    # Failure isolation: set -e is suspended inside a tested function, so any
    # Channel 5 failure can never abort the cron / other channels.
    run_channel5 || {
        echo "$LOG_PREFIX Channel 5 ERRORED — isolated, cron continues"
        cron_alert "diff-autolearn" "Channel 5 errored (isolated)"
        python3 "$CH5_REC_PY" funnel --runs "$CH5_RUNS" \
            --record "{\"error\":1,\"note\":\"run_channel5 nonzero\"}" 2>/dev/null || true
    }
fi

# Heartbeat
write_heartbeat "diff-autolearn"
if [ "$patterns_added" -gt 0 ]; then
    cron_alert_clear "diff-autolearn"
    echo "$LOG_PREFIX === Diff Autolearn Done: $patterns_added patterns added ==="
else
    cron_alert_clear "diff-autolearn"
    echo "$LOG_PREFIX === Diff Autolearn Done: no new patterns ==="
fi
