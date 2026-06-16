#!/usr/bin/env bash
# One-off backfill runner for cron jobs after a server reinstall.
#
# Runs every scheduled cron job ONCE, sequentially (gradually — one at a time),
# via the same cron_run wrapper the crontab uses, so heartbeats, ALERTS.md,
# runtime CSV, and retry behavior all match a real scheduled run.
#
# Ordered fast/foundational -> heavy LLM/gdoc producers, so the machine's
# infra + caches are validated before the long jobs run. Resumable: a progress
# file records completed jobs; re-running skips them unless BACKFILL_FRESH=1.
#
# Usage:
#   bash scripts/backfill-cron-jobs.sh              # run all, skip completed
#   BACKFILL_FRESH=1 bash scripts/backfill-cron-jobs.sh   # ignore prior progress
#   BACKFILL_GAP=30 bash scripts/backfill-cron-jobs.sh    # 30s between jobs
#   BACKFILL_ONLY="keepalive,disk-cleanup" bash scripts/backfill-cron-jobs.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cron-alert.sh"

GAP="${BACKFILL_GAP:-10}"
LOG="$HOME/logs/backfill-cron.log"
PROGRESS="$HOME/work/claude/state/backfill-cron-progress.txt"
mkdir -p "$HOME/logs" "$(dirname "$PROGRESS")"
[ "${BACKFILL_FRESH:-0}" = "1" ] && : > "$PROGRESS"
touch "$PROGRESS"

# Ordered job list: "timeout|name|script|extra_env"
# - diff-signal-monitor deduped (scheduled twice).
# - meeting-followups uses the catchup variant (SCAN_DAYS=3 superset).
JOBS=(
  # --- Phase A: fast infra + state foundation ---
  "120|keepalive|cron-keepalive.sh|"
  "300|disk-cleanup|cron-disk-cleanup.sh|"
  "120|harness-health|cron-harness-health.sh|"
  "300|context-gc|cron-context-gc.sh|"
  "120|context-expire|cron-context-expire.sh|"
  "120|context-expire-weekly|context-expire-weekly.sh|"
  "300|alert-sync|cron-alert-sync.sh|"
  "120|auth-sync-nudge|cron-auth-sync-nudge.sh|"
  "600|ot-myclaw-chat-cache|cron-ot-myclaw-chat-cache.sh|"
  # --- Phase B: data refresh ---
  "1800|people-refresh|cron-people-refresh.sh|"
  "300|project-tier-assign|cron-project-tier-assign.sh|"
  "900|project-context-refresh|cron-project-context-refresh.sh|"
  "1200|diff-signal-monitor|cron-diff-signal-monitor.sh|"
  "300|cron-remediator|cron-remediator.sh|"
  # --- Phase C: learning + audit (LLM) ---
  "600|autolearn-corrections|cron-autolearn-corrections.sh|"
  "900|diff-autolearn|cron-diff-autolearn.sh|"
  "600|knowledge-distiller|cron-knowledge-distiller.sh|"
  "300|workflow-regression|cron-workflow-regression.sh|"
  "900|self-improve|cron-self-improve.sh|"
  "900|audit-agent|cron-audit-agent.sh|"
  "900|ai-audit|cron-ai-audit.sh|"
  # --- Phase D: outputs, meetings, backups ---
  "1200|meeting-prep|cron-meeting-prep.sh|"
  "900|meeting-followups-catchup|cron-meeting-followups.sh|SCAN_DAYS=3"
  "1200|daily-progress|cron-daily-progress.sh|"
  "300|myclaw-backup|cron-myclaw-backup.sh|"
  "600|notes-push|cron-notes-push.sh|"
  "600|daily-housekeeping|cron-daily-housekeeping.sh|"
  # --- Phase E: heaviest (LLM + gdoc, 35-45 min) ---
  "2100|area-monitor|cron-area-monitor.sh|"
  "2400|weekly-report|cron-weekly-report.sh|"
  "2700|nightly-routine|cron-nightly-routine-preprocessing.sh|"
)

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [backfill] $*" | tee -a "$LOG"; }

ONLY="${BACKFILL_ONLY:-}"
total=${#JOBS[@]}
i=0
ran=0
log "=== backfill start: $total jobs, gap=${GAP}s, host=$(hostname -s) ==="
for entry in "${JOBS[@]}"; do
  i=$((i+1))
  IFS='|' read -r timeout name script env <<< "$entry"

  if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$name,"* ]]; then
    continue
  fi
  if grep -qxF "$name" "$PROGRESS"; then
    log "[$i/$total] SKIP $name (already completed)"
    continue
  fi

  log "[$i/$total] RUN $name (timeout ${timeout}s${env:+, env=$env})"
  start=$(date +%s)
  [ -n "$env" ] && export "${env?}"   # e.g. SCAN_DAYS=3
  cron_run "$timeout" "$name" "$SCRIPT_DIR/$script" >> "$HOME/logs/$name.log" 2>&1
  rc=$?
  [ -n "$env" ] && unset "${env%%=*}"
  dur=$(( $(date +%s) - start ))
  if [ "$rc" -eq 0 ]; then
    echo "$name" >> "$PROGRESS"
    log "[$i/$total] OK   $name (${dur}s)"
    ran=$((ran+1))
  else
    log "[$i/$total] FAIL $name (rc=$rc, ${dur}s) — see ~/logs/$name.log; continuing"
  fi
  sleep "$GAP"
done
log "=== backfill done: ran $ran this pass; progress at $PROGRESS ==="
