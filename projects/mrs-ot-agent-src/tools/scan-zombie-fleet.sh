#!/bin/bash
# scan-zombie-fleet.sh — Zombie OT training job detector for tracked prod models.
#
# By default, scans the tracked prod models from the OT master agent's models.md.
# Use --all to scan all running OT jobs (slower, broader).
#
# Detects the KI-001 zombie pattern:
#   reply file exists + job still RUNNING + gap > 30 min
#
# Usage:
#   bash scan-zombie-fleet.sh [--threshold MINUTES] [--all] [--limit N] [--json-only] [--concurrency N]
#
# Options:
#   --threshold MINUTES  Gap threshold in minutes (default: 30)
#   --all                Scan all running OT jobs, not just tracked models
#   --limit N            Max jobs when using --all (default: 100)
#   --json-only          Output only JSON lines, no human-readable summary
#   --concurrency N      Number of parallel workers (default: 8)
#
# Exit codes:
#   0 = zombies found
#   1 = no zombies found (fleet healthy)
#   2 = usage error or data fetch failure
#
# Performance: per-model work runs in a bounded pool of N workers (xargs -P).
# Each worker re-invokes this script in a hidden `--scan-one <token>` mode,
# emitting at most ONE zombie-JSON line to stdout (built fully then printf'd
# atomically so parallel lines never interleave) plus a one-line status to a
# per-worker temp file. The parent aggregates counts after all workers finish.

set -euo pipefail

# Shared model-enrichment helper (single source of truth across all three
# fleet-health scans). Exposes enrich_model <entity_id> → "model_type|pg|mvai_tier|owner".
# shellcheck source=lib-enrich-model.sh
source "$(dirname "$0")/lib-enrich-model.sh"

# Shared URL-construction helper (single source of truth for internalfb.com links).
# Emit the resolvable MAST link built from the running job_name via mast_url.
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"

THRESHOLD_MIN=30
LIMIT=100
JSON_ONLY=false
SCAN_ALL=false
CONCURRENCY=16   # 8→16 (2026-06-10): zombie fan-out was the fleet-health long pole on a slow-meta day (9m vs 5-6m budget); workers are meta-latency-bound so more workers ≈ linear wall-time win
SCAN_ONE=""
MODELS_FILE="$(dirname "$0")/../human-input/models.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --threshold) THRESHOLD_MIN="$2"; shift 2 ;;
    --all)       SCAN_ALL=true; shift ;;
    --limit)     LIMIT="$2"; shift 2 ;;
    --json-only) JSON_ONLY=true; shift ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --scan-one)  SCAN_ONE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--threshold MINUTES] [--all] [--limit N] [--json-only] [--concurrency N]"
      echo ""
      echo "Default: scans tracked prod models from models.md"
      echo "  --all: scans all running OT jobs (slower)"
      echo "  --concurrency N: parallel workers (default 8)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

THRESHOLD_SECS=$((THRESHOLD_MIN * 60))
NOW_EPOCH=$(python3 -c "import time; print(int(time.time()))")

log() {
  if [ "${JSON_ONLY}" = "false" ]; then
    echo "$@"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Worker-mode helpers (used by both --scan-one and aggregation paths).
# ─────────────────────────────────────────────────────────────────────────────

# resolve_running_job <entity_id> -> echoes "JOB_NAME|VERSION" if RUNNING, else nothing.
# Returns non-zero (no output) on fetch failure / non-RUNNING.
resolve_running_job() {
  local eid="$1"
  local job_name="mvai-training-online-${eid}"
  local meta status version
  meta=$(timeout 15 meta ai.mast-job metadata --name="${job_name}" -o json 2>&1) || return 1
  status=$(echo "${meta}" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('status',''))" 2>/dev/null)
  version=$(echo "${meta}" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('version',''))" 2>/dev/null)
  if [ "${status}" = "RUNNING" ] && [ -n "${version}" ]; then
    echo "${job_name}|${version}"
    return 0
  fi
  return 1
}

# scan_job <JOB_NAME> <VERSION>
# Performs the zombie check for one already-resolved job. On a zombie, prints
# exactly one compact JSON line to stdout. Writes a status marker to the
# WORKER_STATUS file: "ZOMBIE", "OK", or "ERROR".
scan_job() {
  local JOB_NAME="$1"
  local VERSION="$2"

  # Get job metadata
  local JOB_META
  JOB_META=$(timeout 15 meta ai.mast-job metadata --name="${JOB_NAME}" --version="${VERSION}" -o json 2>&1) || {
    echo "ERROR" >> "${WORKER_STATUS}"
    return
  }

  # Get attempt info (task count + current attempt start)
  local ATTEMPT_META
  ATTEMPT_META=$(timeout 15 meta ai.mast-job attempts --name="${JOB_NAME}" --version="${VERSION}" -o json 2>&1) || {
    echo "ERROR" >> "${WORKER_STATUS}"
    return
  }

  local ATTEMPT_INFO TASK_COUNT CURRENT_ATTEMPT_START
  ATTEMPT_INFO=$(echo "${ATTEMPT_META}" | python3 -c "
import sys, json
from datetime import datetime, timezone, timedelta
try:
    d = json.loads(sys.stdin.read())
    attempts = d if isinstance(d, list) else [d]
    # Find the latest RUNNING attempt
    running = [a for a in attempts if a.get('status') == 'RUNNING']
    latest = running[-1] if running else attempts[-1]
    task_count = latest.get('task_count', 1)
    # Parse start_time to epoch for comparison with reply file
    start_str = latest.get('start_time', '')
    if start_str:
        dt_naive = datetime.strptime(start_str.rsplit(' ', 1)[0], '%Y-%m-%d %H:%M:%S')
        tz_str = start_str.rsplit(' ', 1)[1] if ' ' in start_str else 'PDT'
        tz_offset = {'PDT': -7, 'PST': -8, 'UTC': 0, 'EDT': -4, 'EST': -5}.get(tz_str, -7)
        dt = dt_naive.replace(tzinfo=timezone(timedelta(hours=tz_offset)))
        start_epoch = int(dt.timestamp())
    else:
        start_epoch = 0
    print(f'{task_count}|{start_epoch}')
except:
    print('1|0')
" 2>/dev/null)

  TASK_COUNT=$(echo "${ATTEMPT_INFO}" | cut -d'|' -f1)
  CURRENT_ATTEMPT_START=$(echo "${ATTEMPT_INFO}" | cut -d'|' -f2)

  # Extract base layer (zombie-specific fields).
  local JOB_EXTRAS BASE_PKG BASE_DATE
  JOB_EXTRAS=$(echo "${JOB_META}" | python3 -c "
import sys, json
try:
    raw = json.loads(sys.stdin.read())
    app_meta_str = raw.get('application_metadata', '{}')
    app_meta = json.loads(app_meta_str) if isinstance(app_meta_str, str) else app_meta_str
    base_pkg = app_meta.get('base_layer_pkg', 'unknown')
    base_date = app_meta.get('base_upstream_date', 'unknown')
    print(f'{base_pkg}|{base_date}')
except:
    print('unknown|unknown')
" 2>/dev/null)

  BASE_PKG=$(echo "${JOB_EXTRAS}" | cut -d'|' -f1)
  BASE_DATE=$(echo "${JOB_EXTRAS}" | cut -d'|' -f2)

  # Shared enrichment (model_type / pg / mvai_tier / owner) via the common helper
  # so these render identically to the other fleet-health scans. OWNER now uses
  # the helper's full fallback chain (model_owner_unixname → registry owner →
  # oncall → '?') instead of the old model_owner_unixname→raw.owner→unknown one.
  # entity_id is the JOB_NAME minus the mvai-training-online- prefix.
  local EID ENRICH ENR_MODEL_TYPE ENR_PG ENR_TIER OWNER
  EID="${JOB_NAME#mvai-training-online-}"
  ENRICH=$(enrich_model "${EID}")
  ENR_MODEL_TYPE="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
  ENR_PG="${ENRICH%%|*}";         ENRICH="${ENRICH#*|}"
  ENR_TIER="${ENRICH%%|*}";       ENRICH="${ENRICH#*|}"
  OWNER="${ENRICH}"

  # Check reply files for all tasks
  local EARLIEST_REPLY_TS="" EARLIEST_REPLY_TASK="" EARLIEST_REPLY_MSG="" TASKS_WITH_REPLY=0
  local task_id RESULT PARSED TS MSG

  for task_id in $(seq 0 $((TASK_COUNT - 1))); do
    RESULT=$(timeout 15 meta ai.mast-job logs --name="${JOB_NAME}" --version="${VERSION}" \
      --task-id="${task_id}" \
      --file-path="mast_hpc_task_failure_reply_file" \
      --max-lines=5 --use-legacy-logreader 2>&1) || RESULT=""

    [ -z "${RESULT}" ] && continue

    PARSED=$(echo "${RESULT}" | python3 -c "
import sys, json, re
raw = sys.stdin.read().strip()
if not raw:
    print('0|NO_REPLY_FILE')
else:
    best_ts = 0
    best_msg = ''
    for match in re.finditer(r'\{', raw):
        start = match.start()
        depth = 0
        for i in range(start, len(raw)):
            if raw[i] == '{': depth += 1
            elif raw[i] == '}': depth -= 1
            if depth == 0:
                try:
                    d = json.loads(raw[start:i+1])
                    ts = d.get('timestamp', 0)
                    msg = d.get('message', '?')[:120].replace('\n', ' ')
                    if ts > best_ts:
                        best_ts = ts
                        best_msg = msg
                except:
                    pass
                break
    if best_ts > 0:
        print(f'{best_ts}|{best_msg}')
    else:
        print('0|NO_REPLY_FILE')
" 2>/dev/null)

    TS=$(echo "${PARSED}" | cut -d'|' -f1)
    MSG=$(echo "${PARSED}" | cut -d'|' -f2-)

    if [ "${TS}" != "0" ]; then
      TASKS_WITH_REPLY=$((TASKS_WITH_REPLY + 1))
      if [ -z "${EARLIEST_REPLY_TS}" ] || [ "${TS}" -lt "${EARLIEST_REPLY_TS}" ]; then
        EARLIEST_REPLY_TS="${TS}"
        EARLIEST_REPLY_TASK="${task_id}"
        EARLIEST_REPLY_MSG="${MSG}"
      fi
    fi
  done

  if [ -z "${EARLIEST_REPLY_TS}" ]; then
    echo "OK" >> "${WORKER_STATUS}"
    return
  fi

  # Skip reply files from old attempts — only flag if reply file is from the current attempt
  if [ "${CURRENT_ATTEMPT_START}" -gt 0 ] && [ "${EARLIEST_REPLY_TS}" -lt "${CURRENT_ATTEMPT_START}" ]; then
    echo "OK" >> "${WORKER_STATUS}"
    return
  fi

  local GAP GAP_MIN
  GAP=$((NOW_EPOCH - EARLIEST_REPLY_TS))
  GAP_MIN=$((GAP / 60))

  if [ "${GAP}" -gt "${THRESHOLD_SECS}" ]; then
    local FIX_INCLUDED="unknown"
    if [ "${BASE_DATE}" != "unknown" ]; then
      FIX_INCLUDED=$(python3 -c "
base = '${BASE_DATE}'.replace('+', ' ')[:10]
fix = '2026-05-21'
print('yes' if base >= fix else 'no')
" 2>/dev/null)
    fi

    # Resolvable MAST link built correct-by-construction from the running
    # job_name (used as-is by mast_url since it already carries the prefix).
    local MAST_URL; MAST_URL="$(mast_url "${JOB_NAME}")"
    local ZOMBIE_JSON
    ZOMBIE_JSON=$(echo "${EARLIEST_REPLY_MSG}" | \
      MODEL_TYPE="${ENR_MODEL_TYPE}" PG="${ENR_PG}" MVAI_TIER="${ENR_TIER}" OWNER="${OWNER}" \
      MAST_URL="${MAST_URL}" python3 -c "
import os, sys, json
msg = sys.stdin.read().strip()
print(json.dumps({
    'job_name': '${JOB_NAME}',
    'version': '${VERSION}',
    'model_entity_id': '${EID}',
    'mast_url': os.environ['MAST_URL'],
    'owner': os.environ['OWNER'],
    'model_type': os.environ['MODEL_TYPE'],
    'pg': os.environ['PG'],
    'mvai_tier': os.environ['MVAI_TIER'],
    'base_layer_pkg': '${BASE_PKG}',
    'base_upstream_date': '${BASE_DATE}',
    'fix_d98638473_included': '${FIX_INCLUDED}',
    'reply_file_task': ${EARLIEST_REPLY_TASK},
    'reply_file_timestamp': ${EARLIEST_REPLY_TS},
    'reply_file_message': msg,
    'gap_seconds': ${GAP},
    'gap_minutes': ${GAP_MIN},
    'tasks_with_reply': ${TASKS_WITH_REPLY},
    'task_count': ${TASK_COUNT},
    'scan_time': ${NOW_EPOCH}
}, separators=(',', ':')))
")
    echo "ZOMBIE" >> "${WORKER_STATUS}"
    # One atomic printf — full line built above, so parallel writes never interleave.
    printf '%s\n' "${ZOMBIE_JSON}"
  else
    echo "OK" >> "${WORKER_STATUS}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Hidden worker mode: process exactly one token.
#   token = "entity_id"        (tracked mode → resolve running job, then scan)
#   token = "JOB_NAME|VERSION" (--all mode → already resolved, scan directly)
# Requires WORKER_STATUS env var pointing at this worker's status file.
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "${SCAN_ONE}" ]; then
  : "${WORKER_STATUS:?WORKER_STATUS must be set in worker mode}"
  if [[ "${SCAN_ONE}" == *"|"* ]]; then
    JOB_NAME="${SCAN_ONE%%|*}"
    VERSION="${SCAN_ONE#*|}"
    scan_job "${JOB_NAME}" "${VERSION}"
  else
    if RESOLVED=$(resolve_running_job "${SCAN_ONE}"); then
      JOB_NAME="${RESOLVED%%|*}"
      VERSION="${RESOLVED#*|}"
      scan_job "${JOB_NAME}" "${VERSION}"
    fi
    # Non-RUNNING / not-found entity: nothing to scan, no status written
    # (matches sequential "skipping" — not counted as scanned or error).
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Parent mode.
# ─────────────────────────────────────────────────────────────────────────────
NOW_HUMAN=$(python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.fromtimestamp(${NOW_EPOCH}, tz=timezone(timedelta(hours=-7))).strftime('%Y-%m-%d %H:%M:%S PDT'))")

log "=== OT Zombie Fleet Scan ==="
log "Time:      ${NOW_HUMAN}"
log "Threshold: ${THRESHOLD_MIN} min"

# Step 1: Build the token list to fan out over.
#   --all  → resolved "JOB_NAME|VERSION" tokens (one meta list call)
#   tracked → entity-id tokens (resolution happens inside each worker)
if [ "${SCAN_ALL}" = "true" ]; then
  log "Mode:      all running OT jobs (limit ${LIMIT})"
  log ""
  log "[1/3] Fetching running OT jobs..."

  JOBS_RAW=$(meta ai.mast-job list \
    --job-name-matches-prefix "mvai-training-online-" \
    --status-is RUNNING \
    --limit "${LIMIT}" \
    -o json 2>&1) || {
    log "ERROR: Failed to fetch running jobs."
    exit 2
  }

  TOKEN_LIST=$(echo "${JOBS_RAW}" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    jobs = data if isinstance(data, list) else data.get('jobs', data.get('data', []))
    for j in jobs:
        name = j.get('name', j.get('job_name', ''))
        ver = j.get('version', j.get('latest_version', ''))
        if name and ver:
            print(f'{name}|{ver}')
except Exception as e:
    print(f'ERROR|{e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null) || {
    log "ERROR: Failed to parse job list."
    exit 2
  }
else
  log "Mode:      tracked prod models (from models.md)"
  log ""
  log "[1/3] Reading tracked models..."

  if [ ! -f "${MODELS_FILE}" ]; then
    log "ERROR: models.md not found at ${MODELS_FILE}"
    exit 2
  fi

  # Extract entity IDs from the markdown TABLE ROWS only (lines starting with '|').
  # Scoping to table rows prevents a stray `entity_id=` in prose/Notes from
  # injecting a phantom model into the scan (the whole-file grep was fragile).
  TOKEN_LIST=$(grep -P '^\|' "${MODELS_FILE}" | grep -oP 'entity_id=\K\d+' | sort -u)
  ENTITY_COUNT=$(echo "${TOKEN_LIST}" | grep -c . || echo 0)
  log "  Found ${ENTITY_COUNT} tracked prod models."
  log ""
fi

# Drop blank lines
TOKEN_LIST=$(echo "${TOKEN_LIST}" | grep -v '^$' || true)
TOTAL_JOBS=$(echo "${TOKEN_LIST}" | grep -c . || echo 0)

if [ "${TOTAL_JOBS}" -eq 0 ]; then
  log ""
  log "No running OT jobs found."
  exit 1
fi

log ""
log "[2/3] Scanning for zombie pattern (reply file + RUNNING), ${CONCURRENCY} workers..."
log ""

# Temp dir for per-worker status files + aggregated zombie JSON.
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT
ZOMBIE_OUT="${WORK_DIR}/zombies.jsonl"
: > "${ZOMBIE_OUT}"

# Fan out: each token → one worker (this script in --scan-one mode), bounded by
# CONCURRENCY. Each worker appends its status to a unique file (named by its
# token-derived index, via an env counter) so the parent can tally afterward.
# Worker stdout (the zombie JSON line, if any) is collected into ZOMBIE_OUT.
SELF="$0"

# We pass the per-worker status file path via WORKER_STATUS; to avoid append
# contention each worker writes to its own file keyed by a unique id (PID +
# RANDOM + nanoseconds). Worker stdout (the zombie JSON line, if any) is
# redirected into ZOMBIE_OUT. Workers run JSON-only so no human log leaks.
printf '%s\n' "${TOKEN_LIST}" | grep -v '^$' | \
  WORK_DIR="${WORK_DIR}" SELF="${SELF}" THRESHOLD_MIN="${THRESHOLD_MIN}" \
  xargs -P "${CONCURRENCY}" -I {} bash -c '
    tok="$1"
    export WORKER_STATUS="${WORK_DIR}/status.$$.${RANDOM}.$(date +%N)"
    bash "${SELF}" --scan-one "${tok}" --threshold "${THRESHOLD_MIN}" --json-only
  ' _ {} >> "${ZOMBIE_OUT}"

# Aggregate counts from all per-worker status files.
# grep -c always prints exactly one integer line (and exits 1 on zero matches,
# which we tolerate); no `|| echo` fallback, which would double the output.
ZOMBIE_COUNT=$(grep -c '^{' "${ZOMBIE_OUT}" 2>/dev/null) || true
SCANNED=0
ERRORS=0
if compgen -G "${WORK_DIR}/status.*" > /dev/null 2>&1; then
  ALL_STATUS=$(cat "${WORK_DIR}"/status.* 2>/dev/null || true)
  SCANNED=$(printf '%s\n' "${ALL_STATUS}" | grep -c .) || true
  ERRORS=$(printf '%s\n' "${ALL_STATUS}" | grep -c '^ERROR$') || true
fi

# Emit collected zombie JSON lines to stdout (one compact object per line).
if [ "${ZOMBIE_COUNT}" -gt 0 ]; then
  grep '^{' "${ZOMBIE_OUT}" || true
fi

# Machine-readable summary — ALWAYS printed to stdout (even under --json-only),
# so the digest render cites coverage from DATA, never narrates it (self-report
# rule). 2026-06-05: added after the fleet-health digest rendered a fabricated
# "zombie 62/65 ok" line (truth was scanned=61, zombies=1, errors=0 → 60/61 ok);
# the scan emitted no machine summary, so the render guessed and the operator
# reasonably inferred 3 zombies from 65-62. ok = scanned - zombies - errors.
# NOTE: scanned = RUNNING models actually checked (the zombie pattern only
# applies to RUNNING jobs), which is < total tracked models — render the
# denominator as `scanned`, NOT the tracked-model total.
OK_COUNT=$(( SCANNED - ZOMBIE_COUNT - ERRORS ))
printf '{"summary":{"scanned":%s,"zombies":%s,"errors":%s,"ok":%s,"threshold_min":%s}}\n' \
  "${SCANNED}" "${ZOMBIE_COUNT}" "${ERRORS}" "${OK_COUNT}" "${THRESHOLD_MIN}"

log ""
log "[3/3] Fleet Scan Summary"
log "════════════════════════════════════════════════════════════"
log "  Scanned:    ${SCANNED} tracked prod models"
log "  Zombies:    ${ZOMBIE_COUNT}"
log "  Errors:     ${ERRORS} (metadata/timeout failures)"
log "  Threshold:  ${THRESHOLD_MIN} min"
log "  Scan time:  ${NOW_HUMAN}"
log "════════════════════════════════════════════════════════════"

if [ "${ZOMBIE_COUNT}" -gt 0 ]; then
  log ""
  log "Action: zombie jobs have a reply file written >${THRESHOLD_MIN}m ago"
  log "but the task process never exited. MAST cannot read the reply file"
  log "until the task exits, so these jobs stay RUNNING indefinitely."
  log ""
  log "Root cause: missing exit_w_cleanup in light.py main() (D98638473)."
  log "Fix: upgrade base layer to a version built after 2026-05-21, or"
  log "manually kill the zombie job."
  exit 0
else
  log ""
  log "Fleet is clean — no zombie jobs detected."
  exit 1
fi
