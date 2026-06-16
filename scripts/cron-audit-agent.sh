#!/usr/bin/env bash
# cron-audit-agent.sh — Daily doc quality evaluation using LLM.
#
# Reads today's content additions from target docs, evaluates against
# per-doc criteria (from AI Feedback Log > Audit Agent Design), and
# appends scores + suggestions to each doc's Self Eval tab.
#
# Target docs (Phase 1): routine, ot_triage, ai_feedback_log
# Design: config/DAILY-DOCS.json key docs.ai_feedback_log
#
# Crontab entry (in setup-claude.sh):
#   30 19 * * 1-5 source ~/work/claude/scripts/cron-alert.sh && cron_run 900 audit-agent ~/work/claude/scripts/cron-audit-agent.sh >> ~/logs/audit-agent.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-audit-agent.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
# Legacy heartbeat removed — use write_heartbeat() from cron-alert.sh
WORK_DIR=$(mktemp -d /tmp/cron-audit-agent-XXXXXX)

# Source shared helpers
source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Locking — with PID liveness check (not just age-based)
if [ -f "$LOCK_FILE" ]; then
    lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if kill -0 "$lock_pid" 2>/dev/null && [ "$lock_age" -lt 1800 ]; then
        echo "$LOG_PREFIX [SKIP] Lock held by PID $lock_pid (${lock_age}s old). Skipping."
        exit 0
    fi
    echo "$LOG_PREFIX [WARN] Stale lock (PID $lock_pid dead or age ${lock_age}s). Removing."
    rm -f "$LOCK_FILE"
fi
echo "$$" > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; rm -rf "${WORK_DIR:-}"' EXIT

# Clear session markers
unset CLAUDE_CODE_SESSION_ID 2>/dev/null || true

echo "$LOG_PREFIX === Audit Agent Start ==="

# ═══════════════════════════════════════════════════════════════════════════════
# TARGET DOCS + CRITERIA
# ═══════════════════════════════════════════════════════════════════════════════

# Routine doc criteria (RC1-RC4)
ROUTINE_ID="$(get_doc_id routine)"
ROUTINE_CRITERIA="RC1: Coaching tips are actionable — tip names a specific behavior to change with a concrete next step (FAIL if generic advice like 'be more strategic').
RC2: Meeting prep has context — prep loads person profile, recent threads (FAIL if talking points generated from title alone).
RC3: Actions have owners and dates — every action item has a person and a deadline (FAIL if 'follow up on X' with no who/when).
RC4: No stale content carried forward — yesterday's items updated or removed (FAIL if same text appears 3+ days unchanged)."

# OT Triage doc criteria (OC1-OC3)
OT_TRIAGE_ID="$(get_doc_id project_context)"
OT_CRITERIA="OC1: Evidence is linked — every claim has a Scuba query URL, log viewer link, or config URL (FAIL if claims like 'model is stale' without verification link).
OC2: Root cause is verified, not guessed — root cause cites specific evidence: error message, metric, timeline (FAIL if 'likely' or 'probably' without evidence).
OC3: Action items route to the right oncall — triage identifies which team owns the fix: training vs serving vs data (FAIL if generic 'investigate further' without routing)."

# AI Feedback Log criteria (from Self Eval tab — E1-E5)
AI_LOG_ID="$(get_doc_id ai_feedback_log)"
AI_CRITERIA="E1: Classification accuracy — entry would matter in a different session with a different task (FAIL if specific correction to current work).
E2: Detection coverage — observation auto-captured without user saying 'track this' (FAIL if user had to explicitly request tracking).
E3: Root cause depth — root cause explains WHY the pattern recurs, not just WHAT happened (FAIL if restates symptom).
E4: Action effectiveness — outcome shows measurable improvement or confirmed resolution (FAIL if 'pending' for 2+ weeks).
E5: No noise — every entry would make Denny nod 'yes, that's a real pattern' (FAIL if trivial or mis-classified)."

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT TODAY'S CONTENT FROM EACH DOC
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [1] Exporting doc content"

ensure_gmux_healthy 2>/dev/null || {
    echo "$LOG_PREFIX [FAIL] google-mux not responsive"
    cron_alert "audit-agent" "google-mux not responsive — skipping audit"
    exit 1
}

for doc_name in routine ot_triage ai_log; do
    case $doc_name in
        routine)   doc_id="$ROUTINE_ID" ;;
        ot_triage) doc_id="$OT_TRIAGE_ID" ;;
        ai_log)    doc_id="$AI_LOG_ID" ;;
    esac

    echo "$LOG_PREFIX   Exporting $doc_name..."
    timeout 15 gdocs export "$doc_id" --format txt > "$WORK_DIR/${doc_name}_content.txt" 2>/dev/null || {
        echo "$LOG_PREFIX   [WARN] Failed to export $doc_name"
        echo "" > "$WORK_DIR/${doc_name}_content.txt"
    }
    content_size=$(wc -c < "$WORK_DIR/${doc_name}_content.txt" 2>/dev/null || echo 0)
    echo "$LOG_PREFIX   $doc_name: ${content_size} bytes"
done

# ═══════════════════════════════════════════════════════════════════════════════
# LLM EVALUATION
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [2] LLM evaluation"

EVAL_PROMPT="You are a quality auditor for daily Google Docs. Evaluate each doc's content against its criteria.

Date: $TODAY

## Doc 1: Routine Doc
Content (first 10000 chars — covers today's full content + previous day for staleness detection):
$(head -c 10000 "$WORK_DIR/routine_content.txt" 2>/dev/null)

Criteria:
$ROUTINE_CRITERIA

## Doc 2: OT Triage Doc
Content (first 3000 chars):
$(head -c 3000 "$WORK_DIR/ot_triage_content.txt" 2>/dev/null)

Criteria:
$OT_CRITERIA

## Doc 3: AI Feedback Log
Content (first 3000 chars):
$(head -c 3000 "$WORK_DIR/ai_log_content.txt" 2>/dev/null)

Criteria:
$AI_CRITERIA

## Instructions
For each doc, evaluate each criterion as PASS, FAIL, or N/A.
For each FAIL, provide a specific improvement suggestion with a before/after example.

## Doc 4: Cron Job Health (last 7 days)
$(tail -100 "$HOME/work/claude/state/CRON-HEALTH-METRICS.md" 2>/dev/null || echo "No metrics data yet.")

Criteria:
CH1: Per-job success rate above 80% over last 7 days (FAIL if any job below 80%).
CH2: No job has 3+ consecutive failures without an auto-correct fix being applied.
CH3: Auto-correct fixes are effective — retry after fix succeeds (FAIL if auto-correct fires but retry still fails).

Write the results to $WORK_DIR/audit-results.md in this format:

# Audit Results — $TODAY

## Routine Doc
| # | Criterion | Score | Notes |
|---|-----------|-------|-------|
| RC1 | Coaching tips actionable | PASS/FAIL | specific note |
...

## OT Triage Doc
| # | Criterion | Score | Notes |
|---|-----------|-------|-------|
| OC1 | Evidence linked | PASS/FAIL | specific note |
...

## AI Feedback Log
| # | Criterion | Score | Notes |
|---|-----------|-------|-------|
| E1 | Classification accuracy | PASS/FAIL | specific note |
...

## Cron Job Health
| # | Criterion | Score | Notes |
|---|-----------|-------|-------|
| CH1 | Per-job success rate >80% | PASS/FAIL | list any jobs below threshold with their rate |
| CH2 | No 3+ consecutive failures | PASS/FAIL | list jobs with streaks |
| CH3 | Auto-correct effectiveness | PASS/FAIL/N/A | note |

## Summary
- Routine: X/4 pass
- OT Triage: X/3 pass
- AI Feedback Log: X/5 pass
- Cron Health: X/3 pass
- Regressions (3+ day fails): list any

Write ONLY the audit-results.md file. Be honest — FAIL means FAIL."

llm_start=$(date +%s)

run_llm "audit-agent" 600 "$WORK_DIR/llm-output.log" "$EVAL_PROMPT" \
    -- --allowedTools Read Write \
    --model claude-sonnet-4-6 \
    --max-turns 5 \
    --output-format text

llm_exit=$?
llm_end=$(date +%s)
llm_duration=$((llm_end - llm_start))

if [ $llm_exit -ne 0 ]; then
    echo "$LOG_PREFIX [FAIL] LLM audit failed (exit $llm_exit, ${llm_duration}s)"
    cron_alert "audit-agent" "LLM audit failed (exit $llm_exit, ${llm_duration}s)"
else
    echo "$LOG_PREFIX LLM audit complete (${llm_duration}s)"

    if [ -f "$WORK_DIR/audit-results.md" ] && [ -s "$WORK_DIR/audit-results.md" ]; then
        # Save to cache
        cp "$WORK_DIR/audit-results.md" "$REPO_DIR/context/cache/AUDIT-RESULTS.md"
        echo "$LOG_PREFIX   Results saved → context/cache/AUDIT-RESULTS.md"

        # Count passes and fails
        pass_count=$(grep -c "PASS" "$WORK_DIR/audit-results.md" 2>/dev/null || echo 0)
        fail_count=$(grep -c "FAIL" "$WORK_DIR/audit-results.md" 2>/dev/null || echo 0)
        echo "$LOG_PREFIX   Scores: ${pass_count} PASS, ${fail_count} FAIL"

        # Alert on high failure rate
        if [ "$fail_count" -gt 4 ]; then
            cron_alert "audit-agent" "Doc quality: ${fail_count} criteria failed — check context/cache/AUDIT-RESULTS.md"
        else
            cron_alert_clear "audit-agent"
        fi
    else
        echo "$LOG_PREFIX   [WARN] No audit results generated"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

rm -rf "$WORK_DIR"
unset WORK_DIR

write_heartbeat "audit-agent"
echo "$LOG_PREFIX === Audit Agent Complete ==="
exit 0
