#!/usr/bin/env bash
# cron-TEMPLATE.sh — Canonical starting point for new cron scripts.
#
# Copy this file to scripts/cron-<name>.sh (or private_scripts/cron-<name>.sh
# for personal-by-purpose crons) and replace TEMPLATE placeholders.
#
# This template passes every check in cron-audit.sh by construction:
#   A. sources cron-alert.sh                  ✓ (line below `set`)
#   B. has locking (cron_preflight)           ✓ (canonical helper, not inline)
#   C. calls write_heartbeat                  ✓ (success-gated, at end)
#   D. heartbeat gated on success             ✓ (in if-block after exit-code check)
#   E. no bare global /tmp/ state paths       ✓ (state under $CLAUDE_STATE_DIR)
#   F. claude -p calls have --model tier      ✓ (uses run_llm dispatcher, or set --model)
#   G. parallel fan-out has explicit cap      ✓ (xargs -P or run_llm concurrency)
#   H. registered in setup-claude.sh          [you do this: add a crontab line]
#   I. crontab uses cron_run wrapper          [you do this: see below]
#   J. latency budget (cron_run timeout)      [you do this: pick a sensible timeout]
#
# Required follow-up steps after copying:
#   1. Add a crontab entry in private_scripts/setup-claude.sh under the cron block:
#        <schedule> source ~/work/claude/scripts/cron-alert.sh && cron_run <TIMEOUT_SEC> <NAME> \
#            ~/work/claude/scripts/cron-<NAME>.sh >> ~/logs/<NAME>.log 2>&1
#   2. If this cron uses claude -p, prefer run_llm (sources lib/llm-dispatch.sh) so the
#      model is routed via config/model-config.json — never bare `claude -p` without --model.
#   3. Run audit BEFORE committing: python3 ~/work/claude/private_scripts/lib/cron_audit.py <FILE>

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cron-alert.sh"  # provides cron_preflight / write_heartbeat / cron_log / cron_alert

# ─── Job identity ──────────────────────────────────────────────────────────
JOB_NAME="TEMPLATE"   # short slug, matches crontab `cron_run` name and log filename
# Latency budget (informational — cron_run timeout in crontab is the enforcer).
# Set to ~70% of the cron_run timeout so over-budget fires before the kill.
LATENCY_BUDGET_SEC=120

# ─── Locking (canonical helper, prevents overlapping runs) ─────────────────
cron_preflight "$JOB_NAME" || exit 0   # exits cleanly if a prior run is still going

# ─── Pre-flight checks (fail-fast on dependencies) ─────────────────────────
# Example: ensure_gmux_healthy || { cron_alert "$JOB_NAME" "gmux down"; exit 1; }

cron_log "starting"
start_ts=$(date +%s)

# ─── Main work ─────────────────────────────────────────────────────────────
# Put the real work here. Patterns:
#   - LLM call:  run_llm "$JOB_NAME" 600 /dev/stdout "<prompt>"   # routes via model-config.json
#   - Parallel:  printf '%s\n' "${ITEMS[@]}" | xargs -P 4 -I{} ...    # explicit -P cap
#   - State:     "$CLAUDE_STATE_DIR/$JOB_NAME/..." (never bare /tmp/)
exit_code=0
# do_the_work || exit_code=$?

# ─── Latency self-check (per cost-and-latency.md §25) ──────────────────────
elapsed=$(( $(date +%s) - start_ts ))
if (( elapsed > LATENCY_BUDGET_SEC )); then
    cron_log "OVER-BUDGET: ${elapsed}s > ${LATENCY_BUDGET_SEC}s budget — investigate"
fi

# ─── Heartbeat ONLY on success ─────────────────────────────────────────────
if [ "$exit_code" -eq 0 ]; then
    write_heartbeat "$JOB_NAME"
    cron_log "done (${elapsed}s)"
else
    cron_alert "$JOB_NAME" "exit_code=$exit_code after ${elapsed}s"
fi

exit "$exit_code"
