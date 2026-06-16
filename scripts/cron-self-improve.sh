#!/usr/bin/env bash
# cron-self-improve.sh — Autoresearch-pattern recursive self-improvement for cron fleet.
#
# Inspired by Karpathy's autoresearch: observe → hypothesize → experiment → evaluate → recurse.
#
# Flow:
#   1. OBSERVE — parse cron-runtime.csv, AI-AUDIT-REPORT.md, enforcement-metrics.csv
#   2. DIAGNOSE — compute per-job failure rates, find worst-performing dimension
#   3. HYPOTHESIZE — Claude analyzes data, proposes 1-3 improvements
#   4. EVALUATE — compare experiments started >3 days ago against baseline
#   5. Output: CRON-EXPERIMENTS.md with proposals, verdicts, and revert instructions
#
# Safety:
#   - NEVER auto-modifies script logic, creates/deletes scripts
#   - Safe auto-apply: timeout changes, schedule shifts, retry count adjustments
#   - All changes logged with revert commands
#   - Human review queue for unsafe proposals
#
# Schedule: Weekly Sunday 10 PM via crontab (offset from knowledge-distiller at 9 PM)
# Crontab entry:
#   0 22 * * 0 source ~/work/claude/scripts/cron-alert.sh && cron_run 900 self-improve ~/work/claude/scripts/cron-self-improve.sh >> ~/logs/self-improve.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
LOCK_FILE="/tmp/cron-self-improve.lock"
EXPERIMENTS="$REPO_DIR/context/cache/CRON-EXPERIMENTS.md"
RUNTIME_CSV="$HOME/logs/cron-runtime.csv"
AUDIT_REPORT="$REPO_DIR/context/cache/AI-AUDIT-REPORT.md"
METRICS_CSV="$HOME/logs/enforcement-metrics.csv"
ANALYSIS="/tmp/cron-self-improve-analysis.md"

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# ─── Preflight ───────────────────────────────────────────────────────────────

if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "self-improve" "Workspace missing"
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
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$LOG_PREFIX === Cron Self-Improve (autoresearch loop) ==="

# ─── Phase 1: OBSERVE — gather fleet metrics ────────────────────────────────

echo "$LOG_PREFIX [1/4] OBSERVE — gathering fleet metrics"

# Per-job failure stats over last 7 days
JOB_STATS="/tmp/cron-self-improve-stats.csv"
echo "job,total,pass,fail,pass_rate,avg_duration,timeout_count,retry_pass" > "$JOB_STATS"

if [ -f "$RUNTIME_CSV" ]; then
    seven_days_ago=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')

    # Extract unique job names (excluding keepalive — too noisy)
    jobs=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" \
        '$1 >= since && $2 != "keepalive" {print $2}' | sort -u)

    for job in $jobs; do
        total=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" -v j="$job" \
            '$1 >= since && $2 == j {count++} END {print count+0}')
        pass=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" -v j="$job" \
            '$1 >= since && $2 == j && $3 == 0 {count++} END {print count+0}')
        fail=$((total - pass))
        if [ "$total" -gt 0 ]; then
            pass_rate=$((pass * 100 / total))
        else
            pass_rate=100
        fi
        avg_dur=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" -v j="$job" \
            '$1 >= since && $2 == j {sum+=$4; count++} END {if(count>0) printf "%.0f", sum/count; else print 0}')
        timeouts=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" -v j="$job" \
            '$1 >= since && $2 == j && $3 == 124 {count++} END {print count+0}')
        retry_pass=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" -v j="$job" \
            '$1 >= since && $2 == j && $3 == 0 && $5 == 2 {count++} END {print count+0}')

        echo "$job,$total,$pass,$fail,$pass_rate,$avg_dur,$timeouts,$retry_pass" >> "$JOB_STATS"
    done
fi

echo "$LOG_PREFIX   Generated per-job stats: $(wc -l < "$JOB_STATS") jobs"

# ─── Phase 2: EVALUATE — check existing experiments ─────────────────────────

echo "$LOG_PREFIX [2/4] EVALUATE — checking active experiments"

# Initialize experiments file if missing
if [ ! -f "$EXPERIMENTS" ]; then
    cat > "$EXPERIMENTS" << 'INIT'
# Cron Self-Improvement Experiments

Autoresearch-pattern recursive improvement loop for the cron fleet.
Each experiment tracks: hypothesis, change, baseline, result, verdict.

## Active Experiments

(none)

## Completed Experiments

(none)

## Proposal Queue (human review needed)

(none)
INIT
    echo "$LOG_PREFIX   Initialized CRON-EXPERIMENTS.md"
fi

# Count active experiments that are >3 days old (ready for evaluation)
active_experiments=0
evaluatable=0
if grep -q "^### EXP-" "$EXPERIMENTS" 2>/dev/null; then
    active_experiments=$(grep -c "^### EXP-" "$EXPERIMENTS" 2>/dev/null || echo 0)
    # Find experiments with start dates older than 3 days
    three_days_ago=$(date -d '3 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-3d '+%Y-%m-%d')
    evaluatable=$(grep -A2 "^### EXP-" "$EXPERIMENTS" | grep -c "Started:.*20[0-9][0-9]-" 2>/dev/null || echo 0)
fi
echo "$LOG_PREFIX   Active experiments: $active_experiments, evaluatable: $evaluatable"

# ─── Phase 3: HYPOTHESIZE — Claude analyzes and proposes ────────────────────

echo "$LOG_PREFIX [3/4] HYPOTHESIZE — spawning Claude for analysis"

# Build context for Claude
CONTEXT="/tmp/cron-self-improve-context.md"
{
    echo "# Cron Fleet Self-Improvement Analysis"
    echo ""
    echo "## Current Date: $TODAY"
    echo ""
    echo "## Per-Job Stats (7-day)"
    echo ""
    cat "$JOB_STATS"
    echo ""
    echo "## Current Audit Report"
    echo ""
    if [ -f "$AUDIT_REPORT" ]; then
        cat "$AUDIT_REPORT"
    else
        echo "(no audit report found)"
    fi
    echo ""
    echo "## Current Crontab Schedule"
    echo '```'
    crontab -l 2>/dev/null | grep -v '^#$' | grep -v '^$'
    echo '```'
    echo ""
    echo "## Existing Experiments"
    echo ""
    cat "$EXPERIMENTS"
    echo ""
    echo "## Enforcement Metrics (last 50 events)"
    echo ""
    if [ -f "$METRICS_CSV" ]; then
        tail -50 "$METRICS_CSV"
    else
        echo "(no enforcement metrics found)"
    fi
} > "$CONTEXT"

# Spawn Claude to analyze and produce proposals
CLAUDE_OUTPUT="/tmp/cron-self-improve-claude-output.md"
claude_exit=0
run_llm "self-improve" 600 "$CLAUDE_OUTPUT" "You are the autoresearch engine for a cron automation fleet.

## YOUR TASK

Analyze the fleet data in $CONTEXT and produce TWO outputs:

### Output 1: Analysis (write to $ANALYSIS)
A brief (under 30 lines) diagnostic covering:
1. **Worst dimension** — which audit dimension needs the most improvement and why
2. **Top 3 failing jobs** — ranked by failure rate, with root cause hypothesis for each
3. **Trend** — is the fleet getting better, worse, or flat vs prior weeks?
4. **Experiment verdicts** — for any active experiments >3 days old, compare post-change metrics to baseline. Verdict: KEPT, REVERTED, or INCONCLUSIVE

### Output 2: Proposals (write to $CLAUDE_OUTPUT)
Produce 1-3 improvement proposals in this EXACT format (one per proposal):

\`\`\`
### EXP-{YYYYMMDD}-{seq}
- **Hypothesis**: {one sentence — what you think is wrong and why}
- **Change**: {specific, concrete change — e.g., 'increase timeout from 900s to 1500s for ot-support-triage'}
- **Type**: SAFE|UNSAFE
- **Baseline**: {current metric value — e.g., '65% pass rate for ot-support-triage'}
- **Expected**: {target metric — e.g., '90%+ pass rate'}
- **Revert**: {exact command to undo — e.g., 'change timeout back to 900s in crontab'}
- **Started**: $TODAY
- **Status**: ACTIVE
\`\`\`

Rules:
- SAFE = schedule time change, timeout adjustment, retry count change (can be auto-applied)
- UNSAFE = script logic change, new dependency, structural change (queued for human)
- Do NOT propose changes for jobs with >95% pass rate
- Do NOT propose more than 1 experiment per job
- If all jobs are >95%, propose OUTPUT QUALITY improvements instead (since that's the current RED dimension)
- Each proposal MUST have a concrete, copy-pasteable revert command
- Read the context file with the Read tool. Write both output files with the Write tool.
- Do NOT execute any bash commands or modify any system state.

## IMPORTANT
- Be specific. 'Improve timeout' is not a proposal. 'Change cron_run timeout for nightly-routine from 2700 to 3300' is.
- Base proposals on EVIDENCE from the stats, not assumptions.
- If an experiment is already ACTIVE for a job, do NOT propose another for the same job." \
    -- --allowedTools Read,Write \
    --model claude-sonnet-4-6 \
    --max-turns 10 \
    || claude_exit=$?

if [ $claude_exit -ne 0 ]; then
    echo "$LOG_PREFIX   Claude analysis failed (exit $claude_exit)"
    cron_alert "self-improve" "Claude analysis failed (exit $claude_exit)"
    rm -f "$CONTEXT" "$JOB_STATS"
    exit 1
fi

echo "$LOG_PREFIX   Claude analysis complete"

# ─── Phase 4: INTEGRATE — merge proposals into experiments file ──────────────

echo "$LOG_PREFIX [4/4] INTEGRATE — merging proposals"

proposals_added=0

if [ -f "$CLAUDE_OUTPUT" ] && [ -s "$CLAUDE_OUTPUT" ]; then
    # Extract proposals (blocks starting with ### EXP-)
    # Append new proposals to Active Experiments section
    while IFS= read -r line; do
        if [[ "$line" == "### EXP-"* ]]; then
            exp_id=$(echo "$line" | awk '{print $2}')
            # Check if this experiment already exists
            if grep -qF "$exp_id" "$EXPERIMENTS" 2>/dev/null; then
                echo "$LOG_PREFIX   Skipping duplicate: $exp_id"
                continue
            fi
            proposals_added=$((proposals_added + 1))
        fi
    done < "$CLAUDE_OUTPUT"

    if [ "$proposals_added" -gt 0 ]; then
        # Insert proposals before the "## Completed Experiments" line
        tmp_exp=$(mktemp)
        awk -v proposals="$CLAUDE_OUTPUT" '
            /^## Completed Experiments/ {
                # Insert proposals before this line
                while ((getline pline < proposals) > 0) {
                    print pline
                }
                print ""
            }
            # Remove (none) placeholder from Active Experiments
            /^\(none\)$/ && seen_active && !seen_completed { next }
            /^## Active Experiments/ { seen_active=1 }
            /^## Completed Experiments/ { seen_completed=1 }
            { print }
        ' "$EXPERIMENTS" > "$tmp_exp"

        # Validate the output isn't empty before replacing
        if [ -s "$tmp_exp" ]; then
            mv "$tmp_exp" "$EXPERIMENTS"
            echo "$LOG_PREFIX   Added $proposals_added new proposals to CRON-EXPERIMENTS.md"
        else
            rm -f "$tmp_exp"
            echo "$LOG_PREFIX   Integration produced empty file — keeping original"
        fi
    else
        echo "$LOG_PREFIX   No new proposals to add"
    fi
fi

# Print analysis summary if available
if [ -f "$ANALYSIS" ] && [ -s "$ANALYSIS" ]; then
    echo "$LOG_PREFIX --- Analysis Summary ---"
    cat "$ANALYSIS"
    echo "$LOG_PREFIX --- End Summary ---"
fi

# ─── Cleanup + Heartbeat ────────────────────────────────────────────────────

rm -f "$CONTEXT" "$JOB_STATS" "$CLAUDE_OUTPUT" "$ANALYSIS"

# Heartbeat only on success (Rule 2 compliance)
write_heartbeat "self-improve"

if [ "$proposals_added" -gt 0 ]; then
    cron_alert_clear "self-improve"
    echo "$LOG_PREFIX === Self-Improve Done: $proposals_added proposals added ==="
else
    cron_alert_clear "self-improve"
    echo "$LOG_PREFIX === Self-Improve Done: fleet looks stable, no proposals ==="
fi
