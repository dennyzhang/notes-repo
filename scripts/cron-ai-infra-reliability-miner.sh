#!/usr/bin/env bash
# cron-ai-infra-reliability-miner.sh — Monthly AI Infra Reliability learning miner (autonomous).
#
# Migrated from the MyClaw cron (myclaw.db job 'ai-infra-reliability-miner') to system cron
# on 2026-06-13, to follow the same practice as the other ~/work/claude system crons:
# self-documented crontab entry, cron-alert harness, lock, output verification, heartbeat.
#
# What it does: scans ~35 days of SEV review, strategy docs/wikis, Workplace, and notes delta;
# dedups candidate learnings against _state/seen.jsonl; appends DELTA-ONLY (top ~5 by leverage)
# to PATH-TO-EXPERT.md section 5 and the Domain Prep gdoc 'Path to Expert' tab.
# Runs SILENTLY — the work product is the file/gdoc writes, not a chat message.
#
# Schedule: monthly, 1st at 09:17 PT (matches the prior MyClaw schedule).
# Crontab entry:
#   17 9 1 * * source ~/work/claude/scripts/cron-alert.sh && cron_run 3000 ai-infra-reliability-miner ~/work/claude/scripts/cron-ai-infra-reliability-miner.sh >> ~/logs/ai-infra-reliability-miner.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-ai-infra-reliability-miner.lock"
PATH_TO_EXPERT="$REPO_DIR/learnings/ai-infra-reliability/PATH-TO-EXPERT.md"

# Clear Claude Code session markers so nested claude -p works
unset CLAUDECODE CLAUDE_CODE_CURRENT_SESSION_ID 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check: workspace exists
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "ai-infra-reliability-miner" "Workspace missing — ~/work/claude/CLAUDE.md missing"
    exit 1
fi

# Prevent overlapping runs (monthly job, but guard against a stuck prior run)
LOCK_MAX_AGE_SECONDS=7200
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$(date '+%Y-%m-%d %H:%M') Lock held by pid $pid for ${lock_age}s — killing stale process"
            kill "$pid" 2>/dev/null || true; sleep 2; kill -9 "$pid" 2>/dev/null || true
        else
            echo "$(date '+%Y-%m-%d %H:%M') Already running (pid $pid, age ${lock_age}s), skipping"
            exit 0
        fi
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

if ! command -v claude &>/dev/null; then
    cron_alert "ai-infra-reliability-miner" "claude CLI not available"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M') Starting AI Infra Reliability monthly miner"
cd "$REPO_DIR"

# Record pre-run mtime so we can verify the miner actually appended this cycle.
pre_mtime=$(stat -c %Y "$PATH_TO_EXPERT" 2>/dev/null || echo 0)

exit_code=0
run_llm "ai-infra-reliability-miner" 3000 /dev/stdout "Run the AI Infra Reliability monthly miner (autonomous). Read ~/work/claude/learnings/ai-infra-reliability/_state/sources.md (locked source list) and PATH-TO-EXPERT.md section 4 (design). Scan the last ~35 days of: SEV Review (MRS/MVAI/training-infra/checkpoint/freshness/NCCL/preemption SEVs where Denny is investigator/subscriber/in-scope), the Training Infra Reliability strategy doc + wikis, Workplace groups (PE MRS ML Internal, PE MRS ML, MRS reliability), and Denny's ~/work/claude notes delta. For each candidate learning compute fingerprint=normalized(principle)+category and dedup against _state/seen.jsonl: NEW=add; REINFORCEMENT=append evidence_ids + bump last_seen, do NOT resurface (3+ promotes rank); CONTRADICTION=flag for human review, never auto-overwrite. Tag each NEW learning to one of the 8 competency-map domains (a no-fit learning => propose a new domain). Output DELTA-ONLY, cap top ~5 by leverage: append a dated block to PATH-TO-EXPERT.md section 5 (Monthly Deltas) AND the matching 'Path to Expert' tab in the Domain Prep gdoc (id $(get_doc_id ai_infra_miner), tab t.asqhhkr6h2lf). Linkify all S/D/T IDs and run the gdoc cheatsheet formatting (cheatsheets/gdocs/rules.md). Re-evaluate the 8 gaps_for_denny against new evidence; move any operationalized gap to a Closed Gaps log with evidence. Only capture category-removing or metric/SLO/escalation-changing learnings; every learning needs an evidence ID or is marked ungrounded. Update _state/seen.jsonl. If zero new high-signal learnings: append one line 'No new category-level learnings this cycle; N reinforcements' to PATH-TO-EXPERT.md section 5. This runs as a SILENT system cron job — do NOT send any GChat message; just do the file/gdoc writes and print a one-line summary to stdout when done." -- \
    --allowedTools Read Write Edit Glob Grep Bash Skill Task \
    --model claude-opus-4-6 --effort high \
    --max-turns 60 \
    || exit_code=$?

# Verify the miner actually touched PATH-TO-EXPERT.md this run (it always appends, even on
# the zero-learnings path) — catches a silent no-op exit.
post_mtime=$(stat -c %Y "$PATH_TO_EXPERT" 2>/dev/null || echo 0)
if [ "$exit_code" -eq 0 ] && [ "$post_mtime" -gt "$pre_mtime" ]; then
    cron_alert_clear "ai-infra-reliability-miner"
    echo "$(date '+%Y-%m-%d %H:%M') Miner done — PATH-TO-EXPERT.md updated this cycle"
elif [ "$exit_code" -ne 0 ]; then
    cron_alert "ai-infra-reliability-miner" "Miner failed (exit $exit_code) — check ~/logs/ai-infra-reliability-miner.log"
    echo "$(date '+%Y-%m-%d %H:%M') Miner failed (exit $exit_code)"
else
    cron_alert "ai-infra-reliability-miner" "Miner exited OK but PATH-TO-EXPERT.md not updated this cycle"
    echo "$(date '+%Y-%m-%d %H:%M') Output verification failed — PATH-TO-EXPERT.md unchanged"
fi

write_heartbeat "ai-infra-reliability-miner"
