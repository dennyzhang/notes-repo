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

echo "$(date '+%Y-%m-%d %H:%M') Starting AI Infra Reliability miner (twice-weekly Mon + Thu)"
cd "$REPO_DIR"

# Record pre-run mtime so we can verify the miner actually appended this cycle.
pre_mtime=$(stat -c %Y "$PATH_TO_EXPERT" 2>/dev/null || echo 0)

exit_code=0
run_llm "ai-infra-reliability-miner" 3000 /dev/stdout "Run the AI Infra Reliability miner (autonomous, twice-weekly Mon + Thu 09:17 PT). Read ~/work/claude/learnings/ai-infra-reliability/_state/sources.md (locked source list) and PATH-TO-EXPERT.md section 4 (design). Scan the last ~10 days of: SEV Review (MRS/MVAI/training-infra/checkpoint/freshness/NCCL/preemption SEVs where Denny is investigator/subscriber/in-scope), the Training Infra Reliability strategy doc + wikis, Workplace groups (PE MRS ML Internal, PE MRS ML, MRS reliability), and Denny's ~/work/claude notes delta. (Window tightened from 35d → 10d on 2026-06-19 when schedule moved monthly → twice-weekly; dedup against _state/seen.jsonl handles overlap.) **EXPERT-CURATION BAR (Denny review 2026-06-21 — quality > volume; the goal is to BECOME an expert, not collect trivia)**: (1) Every 'Top learning' and every finding MUST cite ≥2 concrete evidence IDs — pick from {SEV S<number>, wiki page ID, diff D<number>, task T<number>, Workplace post permalink}. A learning with <2 evidence IDs is DROPPED, never written. Inline the IDs in the learning text + add an 'Evidence:' line with the linkified IDs. (2) PROMOTION GATE: a candidate becomes a 'STABLE LEARNING' only after 3 independent reinforcements (3 distinct dated evidence IDs spanning ≥2 sources or ≥2 runs in _state/seen.jsonl). Anything below 3 is tagged '[PROVISIONAL — N/3 reinforcements]' and stays out of the KEY MESSAGE / stable canon. Track reinforcement_count in seen.jsonl; on hitting 3, emit a 'PROMOTED TO STABLE' line in section 5 with full evidence chain. (3) CONSISTENCY CHECK vs prior runs: BEFORE writing any new learning, diff its principle against the last 5 runs' learnings in PATH-TO-EXPERT.md section 5. If it CONTRADICTS a stable learning, do NOT silently overwrite — emit a '⚠️ CONTRADICTION' block naming the prior learning + run date + the new evidence, and leave both in place pending human review. If it DUPLICATES a prior principle with weaker evidence, drop the new one and just append evidence to the existing entry. Print a 'Consistency: N learnings checked vs prior runs, M contradictions, K duplicates dropped' line to stdout. For each candidate learning compute fingerprint=normalized(principle)+category and dedup against _state/seen.jsonl: NEW=add; REINFORCEMENT=append evidence_ids + bump last_seen + bump reinforcement_count, do NOT resurface unless promotion-gate just fired; CONTRADICTION=flag (see above), never auto-overwrite. Tag each NEW learning to one of the 8 competency-map domains (a no-fit learning => propose a new domain). Output DELTA-ONLY, cap top ~3 by leverage (and only those that pass the ≥2-evidence bar): append a dated block to PATH-TO-EXPERT.md section 5 (Monthly Deltas) AND the matching 'Path to Expert' tab in the Domain Prep gdoc (id \$(get_doc_id ai_infra_miner), tab t.asqhhkr6h2lf). ALSO write to the routine gdoc tab '6 Infra Reliability' (doc id 102gEn1Ek4PyefvrOuSNBPNZghsus-rJ9LGbnhtO_vvY, tab id t.aqi2ky6jh9u4) using this layout: header line then '## 🌟 KEY MESSAGE — surface this in daily brief' followed by ONE sentence ≤200 chars naming the single highest-leverage STABLE learning (NEVER a provisional one) + the specific situation/decision it applies to (so the routine-aggregator can pick it up for the daily brief), then '## Top learnings (this run)' followed by the top 3 dated learning blocks, each carrying its 'Evidence:' line and provisional/stable tag. Before writing, FIRST read the current content of tab t.aqi2ky6jh9u4 and PREPEND it to the [Arc] Infra Reliability tab (tab id t.1hndpw9vo431) with a '## <today's date> — prior run' header (preserve existing archive content below). Linkify all S/D/T IDs and apply the gdoc cheatsheet formatting (cheatsheets/gdocs/rules.md). Re-evaluate the 8 gaps_for_denny against new evidence; move any operationalized gap to a Closed Gaps log with evidence. Only capture category-removing or metric/SLO/escalation-changing learnings; every learning needs ≥2 evidence IDs (or is dropped — no more 'ungrounded' fallback). Update _state/seen.jsonl with reinforcement_count + last 5 evidence_ids per fingerprint. **PROJECT-CANDIDATE FLAG (Denny review 2026-06-22 routine-doc comment)**: when a learning has BROAD customer surface (≥3 distinct affected teams/services) AND high pain (SEV0/SEV1 history, or P0 task assignments, or repeated WP complaints from ≥2 PGs), tag it '[PROJECT CANDIDATE]' on its first line and append a row to projects/PIPELINE.md (columns: #, title, source signal with run-date, customer surface, status=Candidate, next step). DO NOT promote to projects/_registry.json — that requires Denny's explicit sign-off. **DOMAIN-INGESTION CROSS-REF**: if the learning is shaped as 'mechanism + category fix' (the canonical-rule shape), cross-reference cheatsheets/oncall/domain-ingestion.md and propose a new Rule N entry in your stdout summary so Denny can promote it. If zero new high-signal learnings pass the bar: append one line 'No new category-level learnings this cycle; N reinforcements, K provisional-still-below-3-of-3' to PATH-TO-EXPERT.md section 5 AND emit a '_No new learnings this cycle_' KEY MESSAGE on the routine tab. This runs as a SILENT system cron job — do NOT send any GChat message; just do the file/gdoc writes and print a one-line summary to stdout when done." -- \
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
