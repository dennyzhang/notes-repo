#!/bin/bash
# scan-scribe-age.sh — Scribe example-age SLO scanner for tracked prod OT models.
#
# Scans the tracked prod models from the OT master agent's models.md and flags
# any model whose scribe example age breaches the 10-min freshness SLO.
#
# A breach means dpp_worker is consuming examples that are >10 min old — the
# trainer is being fed stale data (upstream Scribe/DPP lag, or trainer-side QPS
# can't keep up).
#
# Each breach is emitted with a DETERMINISTIC `cause_class` (computed in-script
# from a training-QPS probe — shared lib-qps.sh fetch + lib_qps.py derive), NOT a
# cron-prompt LLM step that could silently skip:
#   not-training  — no derivable QPS / recent QPS ~0 (job idle, not emitting)
#   trainer-behind — recent QPS healthy-high vs its own baseline, no drop
#                    (consuming fine, but being fed stale data)
#   upstream-lag  — recent QPS present but degraded vs baseline (Scribe/DPP behind)
#   unknown       — the QPS probe itself errored / couldn't resolve; carries
#                   `cause_reason="probe-failed"` (honest, NOT silently "not probed")
# Zombie-overlap is intentionally NOT computed here — the ot-fleet-health cron
# cross-references its own zombie list. This scan emits only the QPS-based cause.
#
# Source metric (ODS, milliseconds):
#   dpp_worker.scribe_example_age_ms.avg.60
# on the model-level ROLLUP entity:
#   mast.mvai-training-online-<ENTITY_ID>.<VERSION>.dpp_worker
# (NOT the per-worker `...dpp_worker.<id>.csid_N` rows). Per model we take the
# MAX value over the returned 15-min window — most conservative; a single
# >10-min bucket counts as a breach.
#
# Usage:
#   bash scan-scribe-age.sh [--threshold-ms N] [--json-only] [--concurrency N]
#
# Options:
#   --threshold-ms N     Breach threshold in milliseconds (default: 600000 = 10 min)
#   --json-only          Output only JSON lines, no human-readable summary
#   --concurrency N      Number of parallel workers (default: 8)
#
# Exit codes:
#   0 = breaches found
#   1 = no breaches found (fleet healthy)
#   2 = usage error or data fetch failure
#
# Performance: per-model work runs in a bounded pool of N workers (xargs -P).
# Each worker re-invokes this script in a hidden `--scan-one <entity_id>` mode,
# emitting at most ONE breach-JSON line to stdout (built fully then printf'd
# atomically so parallel lines never interleave) plus a one-line status to a
# per-worker temp file. The parent aggregates counts after all workers finish.

set -euo pipefail

# Shared model-enrichment helper (single source of truth across all three
# fleet-health scans). Exposes enrich_model <entity_id> → "model_type|pg|mvai_tier|owner".
# shellcheck source=lib-enrich-model.sh
source "$(dirname "$0")/lib-enrich-model.sh"

# Shared training-QPS fetch helper (single source of truth, also used by
# scan-perf-regression.sh). Exposes fetch_qps_json <entity_id> <hours> → sets
# QPS_FETCH_PRIMARY / QPS_FETCH_FALLBACK, rc 0=ok / 2=fetch failed. Used here to
# compute each breach's cause_class DETERMINISTICALLY in-script (replaces the old
# skippable cron-prompt LLM liveness probe). Parsing+derivation in lib_qps.py.
# shellcheck source=lib-qps.sh
source "$(dirname "$0")/lib-qps.sh"
LIB_QPS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Shared URL-construction helper (single source of truth for internalfb.com links).
# Emit the resolvable MAST link built from the running job_name via mast_url.
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"

# Baseline window (hours) for the cause-class QPS probe. Matches scan-perf-
# regression's default so the same series/baseline math applies.
QPS_BASELINE_H=168
# recent-QPS-drop fraction: recent < QPS_DROP_FRAC × baseline → degraded.
QPS_DROP_FRAC=0.85

THRESHOLD_MS=600000
JSON_ONLY=false
CONCURRENCY=8
SCAN_ONE=""
MODELS_FILE="$(dirname "$0")/../human-input/models.md"
WINDOW_SECS=900

while [ $# -gt 0 ]; do
  case "$1" in
    --threshold-ms) THRESHOLD_MS="$2"; shift 2 ;;
    --json-only)    JSON_ONLY=true; shift ;;
    --concurrency)  CONCURRENCY="$2"; shift 2 ;;
    --scan-one)     SCAN_ONE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--threshold-ms N] [--json-only] [--concurrency N]"
      echo ""
      echo "Scans tracked prod models from models.md for scribe example age > SLO."
      echo "  --threshold-ms N: breach threshold in ms (default 600000 = 10 min)"
      echo "  --concurrency N:  parallel workers (default 8)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

NOW_EPOCH=$(python3 -c "import time; print(int(time.time()))")
WINDOW_START=$((NOW_EPOCH - WINDOW_SECS))

log() {
  if [ "${JSON_ONLY}" = "false" ]; then
    echo "$@"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Worker-mode helper.
# scan_model <entity_id>
# Queries ODS for the scribe-age rollup, takes the MAX over the window, and on a
# breach prints exactly one compact JSON line to stdout. Writes a status marker
# to the WORKER_STATUS file: "BREACH", "OK", or "ERROR".
# ─────────────────────────────────────────────────────────────────────────────
scan_model() {
  local EID="$1"
  local JOB_NAME="mvai-training-online-${EID}"

  local ODS_RAW
  ODS_RAW=$(timeout 60 meta ods.metric query \
    -e "regex(mast.mvai-training-online-${EID}.*.dpp_worker.*)" \
    -k 'dpp_worker.scribe_example_age_ms.avg.60' \
    --start-time "${WINDOW_START}" --end-time "${NOW_EPOCH}" --granularity 5m 2>&1) || {
    echo "ERROR" >> "${WORKER_STATUS}"
    return
  }

  # Take MAX value over the window, but ONLY from the model-level rollup entity
  #   mast.mvai-training-online-<EID>.<VERSION>.dpp_worker
  # (exactly three dot-segments after the prefix, ending in .dpp_worker — no
  # per-worker `.<id>.csid_N` suffix). Non-rollup rows are ignored.
  local MAX_MS
  MAX_MS=$(echo "${ODS_RAW}" | EID="${EID}" python3 -c "
import sys, os, re
eid = os.environ['EID']
pat = re.compile(r'^mast\.mvai-training-online-' + re.escape(eid) + r'\.\d+\.dpp_worker$')
best = None
for line in sys.stdin:
    parts = line.split()
    if len(parts) < 4:
        continue
    ent = parts[0]
    if not pat.match(ent):
        continue
    try:
        val = float(parts[-1])
    except ValueError:
        continue
    if best is None or val > best:
        best = val
print('' if best is None else int(best))
" 2>/dev/null)

  # No rollup data points (model idle / not reporting) → not a breach, not an
  # error: nothing to assert about freshness. Count as scanned-OK.
  if [ -z "${MAX_MS}" ]; then
    echo "OK" >> "${WORKER_STATUS}"
    return
  fi

  if [ "${MAX_MS}" -gt "${THRESHOLD_MS}" ]; then
    local AGE_MIN
    AGE_MIN=$(python3 -c "print(round(${MAX_MS}/60000, 1))")

    # ── Enrichment (breaches only → cost bounded; runs inside this per-model
    # worker so it parallelizes). model_type / pg / mvai_tier / owner are resolved
    # DETERMINISTICALLY by the shared helper (lib-enrich-model.sh) so the report
    # never depends on a fragile per-breach LLM step (which silently blanked
    # fields). At most two meta calls (mast metadata + optional ai.model describe).
    local ENRICH ENR_MODEL_TYPE ENR_PG ENR_TIER ENR_OWNER
    ENRICH=$(enrich_model "${EID}")
    ENR_MODEL_TYPE="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
    ENR_PG="${ENRICH%%|*}";         ENRICH="${ENRICH#*|}"
    ENR_TIER="${ENRICH%%|*}";       ENRICH="${ENRICH#*|}"
    ENR_OWNER="${ENRICH}"

    # ── Cause-class (DETERMINISTIC, in-script — replaces the old skippable
    # cron-prompt LLM "run a liveness/QPS probe and classify" step that silently
    # left breaches at "cause-class not probed"). Probe training QPS the SAME way
    # scan-perf-regression does (shared lib-qps.sh fetch + lib_qps.py derive),
    # then classify from recent-vs-baseline:
    #   probe fetch FAILED (rc 2)              → unknown (cause_reason=probe-failed)
    #   no derivable rate / recent QPS ~0      → not-training (job idle / not emitting)
    #   recent QPS healthy-high, no drop       → trainer-behind (consuming fine, fed stale)
    #   recent QPS present but degraded vs base → upstream-lag (Scribe/DPP behind)
    # Zombie-overlap is NOT computed here — the fleet-health cron cross-references
    # its own zombie list. This scan emits only the QPS-based cause.
    local CAUSE_CLASS CAUSE_REASON
    if fetch_qps_json "${EID}" "${QPS_BASELINE_H}"; then
      local CAUSE_OUT
      CAUSE_OUT=$(QPS_J="${QPS_FETCH_PRIMARY}" QPSQ_J="${QPS_FETCH_FALLBACK}" EID="${EID}" \
        QPS_DROP_FRAC="${QPS_DROP_FRAC}" LIB_QPS_DIR="${LIB_QPS_DIR}" python3 -c "
import os, sys
sys.path.insert(0, os.environ['LIB_QPS_DIR'])
from lib_qps import resolve_qps_series, recent_baseline
drop_frac = float(os.environ['QPS_DROP_FRAC'])
qps, _src, _present = resolve_qps_series()
# no usable rate at all (no metric, or only counter-resets / single sample) →
# the trainer is not emitting a derivable QPS → treat as not-training.
if not qps:
    print('not-training'); raise SystemExit
recent, base = recent_baseline(qps)
# too sparse to baseline, but a rate exists: judge on the recent level alone —
# near-zero recent ⇒ not-training; otherwise we cannot assert a drop ⇒ trainer-behind.
if recent is None or base is None or base <= 0:
    last = qps[-1][1]
    print('not-training' if last < 1.0 else 'trainer-behind'); raise SystemExit
if recent < 1.0:
    print('not-training'); raise SystemExit
if recent < drop_frac * base:
    print('upstream-lag'); raise SystemExit
print('trainer-behind')
" 2>/dev/null) || CAUSE_OUT=""
      if [ -n "${CAUSE_OUT}" ]; then
        CAUSE_CLASS="${CAUSE_OUT}"
        CAUSE_REASON=""
      else
        # python itself errored (parse/import) → honest unknown, not a guess.
        CAUSE_CLASS="unknown"
        CAUSE_REASON="probe-failed"
      fi
    else
      # QPS fetch failed (timeout / scuba error) → cannot resolve → honest unknown.
      CAUSE_CLASS="unknown"
      CAUSE_REASON="probe-failed"
    fi

    # Resolvable MAST link built correct-by-construction from the running
    # job_name (used as-is by mast_url since it already carries the prefix).
    local MAST_URL; MAST_URL="$(mast_url "${JOB_NAME}")"
    local BREACH_JSON
    BREACH_JSON=$(MODEL_TYPE="${ENR_MODEL_TYPE}" PG="${ENR_PG}" \
      MVAI_TIER="${ENR_TIER}" OWNER="${ENR_OWNER}" \
      CAUSE_CLASS="${CAUSE_CLASS}" CAUSE_REASON="${CAUSE_REASON}" \
      MAST_URL="${MAST_URL}" python3 -c "
import os, json
out = {
    'job_name': '${JOB_NAME}',
    'model_entity_id': '${EID}',
    'mast_url': os.environ['MAST_URL'],
    'example_age_ms': ${MAX_MS},
    'example_age_min': ${AGE_MIN},
    'threshold_ms': ${THRESHOLD_MS},
    'window_start': ${WINDOW_START},
    'window_end': ${NOW_EPOCH},
    'scan_time': ${NOW_EPOCH},
    'model_type': os.environ['MODEL_TYPE'],
    'pg': os.environ['PG'],
    'owner': os.environ['OWNER'],
    'mvai_tier': os.environ['MVAI_TIER'],
    'cause_class': os.environ['CAUSE_CLASS'],
}
# cause_reason only when the cause is genuinely unknown (probe failure) — keeps
# the JSON honest: an unknown without a reason would be indistinguishable from a
# bug. Present cause_classes carry no reason field.
if os.environ.get('CAUSE_REASON'):
    out['cause_reason'] = os.environ['CAUSE_REASON']
print(json.dumps(out, separators=(',', ':')))")
    echo "BREACH" >> "${WORKER_STATUS}"
    # One atomic printf — full line built above, so parallel writes never interleave.
    printf '%s\n' "${BREACH_JSON}"
  else
    echo "OK" >> "${WORKER_STATUS}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Hidden worker mode: process exactly one entity-id token.
# Requires WORKER_STATUS env var pointing at this worker's status file.
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "${SCAN_ONE}" ]; then
  : "${WORKER_STATUS:?WORKER_STATUS must be set in worker mode}"
  scan_model "${SCAN_ONE}"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Parent mode.
# ─────────────────────────────────────────────────────────────────────────────
NOW_HUMAN=$(python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.fromtimestamp(${NOW_EPOCH}, tz=timezone(timedelta(hours=-7))).strftime('%Y-%m-%d %H:%M:%S PDT'))")
THRESHOLD_MIN=$(python3 -c "print(round(${THRESHOLD_MS}/60000, 1))")

log "=== OT Scribe Example-Age Scan ==="
log "Time:      ${NOW_HUMAN}"
log "Threshold: ${THRESHOLD_MS} ms (${THRESHOLD_MIN} min)"
log "Mode:      tracked prod models (from models.md)"
log ""
log "[1/3] Reading tracked models..."

if [ ! -f "${MODELS_FILE}" ]; then
  log "ERROR: models.md not found at ${MODELS_FILE}"
  exit 2
fi

# Extract entity IDs from the markdown table (from entity_id=NNNN links only)
TOKEN_LIST=$(grep -oP 'entity_id=\K\d+' "${MODELS_FILE}" | sort -u)
TOKEN_LIST=$(echo "${TOKEN_LIST}" | grep -v '^$' || true)
TOTAL_JOBS=$(echo "${TOKEN_LIST}" | grep -c . || echo 0)
log "  Found ${TOTAL_JOBS} tracked prod models."
log ""

if [ "${TOTAL_JOBS}" -eq 0 ]; then
  log ""
  log "No tracked prod models found."
  exit 1
fi

log "[2/3] Scanning scribe example age (ODS rollup, MAX over ${WINDOW_SECS}s), ${CONCURRENCY} workers..."
log ""

# Temp dir for per-worker status files + aggregated breach JSON.
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT
BREACH_OUT="${WORK_DIR}/breaches.jsonl"
: > "${BREACH_OUT}"

# Fan out: each entity-id → one worker (this script in --scan-one mode), bounded
# by CONCURRENCY. Each worker appends its status to a unique file (PID + RANDOM +
# nanoseconds) so the parent can tally afterward. Worker stdout (the breach JSON
# line, if any) is collected into BREACH_OUT. Workers run JSON-only so no human
# log leaks.
SELF="$0"
printf '%s\n' "${TOKEN_LIST}" | grep -v '^$' | \
  WORK_DIR="${WORK_DIR}" SELF="${SELF}" THRESHOLD_MS="${THRESHOLD_MS}" \
  xargs -P "${CONCURRENCY}" -I {} bash -c '
    tok="$1"
    export WORKER_STATUS="${WORK_DIR}/status.$$.${RANDOM}.$(date +%N)"
    bash "${SELF}" --scan-one "${tok}" --threshold-ms "${THRESHOLD_MS}" --json-only
  ' _ {} >> "${BREACH_OUT}"

# Aggregate counts from all per-worker status files.
# grep -c always prints exactly one integer line (and exits 1 on zero matches,
# which we tolerate); no `|| echo` fallback, which would double the output.
BREACH_COUNT=$(grep -c '^{' "${BREACH_OUT}" 2>/dev/null) || true
SCANNED=0
ERRORS=0
if compgen -G "${WORK_DIR}/status.*" > /dev/null 2>&1; then
  ALL_STATUS=$(cat "${WORK_DIR}"/status.* 2>/dev/null || true)
  SCANNED=$(printf '%s\n' "${ALL_STATUS}" | grep -c .) || true
  ERRORS=$(printf '%s\n' "${ALL_STATUS}" | grep -c '^ERROR$') || true
fi

# Emit collected breach JSON lines to stdout (one compact object per line).
if [ "${BREACH_COUNT}" -gt 0 ]; then
  grep '^{' "${BREACH_OUT}" || true
fi

# Machine-readable summary — ALWAYS printed to stdout (mirrors zombie/perf), so
# the digest render cites training-age coverage from DATA. 2026-06-05: the ✓ line
# carried zombie + perf coverage but NO training-age coverage — the scan emitted
# no machine summary, so the renderer had nothing to print. ok = scanned -
# breaches - errors.
OK_COUNT=$(( SCANNED - BREACH_COUNT - ERRORS ))
printf '{"summary":{"scanned":%s,"breaches":%s,"errors":%s,"ok":%s,"threshold_min":%s}}\n' \
  "${SCANNED}" "${BREACH_COUNT}" "${ERRORS}" "${OK_COUNT}" "${THRESHOLD_MIN}"

log ""
log "[3/3] Scribe Example-Age Scan Summary"
log "════════════════════════════════════════════════════════════"
log "  Scanned:    ${SCANNED} tracked prod models"
log "  Breaches:   ${BREACH_COUNT}"
log "  Errors:     ${ERRORS} (ODS query/timeout failures)"
log "  Threshold:  ${THRESHOLD_MS} ms (${THRESHOLD_MIN} min)"
log "  Scan time:  ${NOW_HUMAN}"
log "════════════════════════════════════════════════════════════"

if [ "${BREACH_COUNT}" -gt 0 ]; then
  log ""
  log "Action: these models are consuming examples older than the 10-min SLO."
  log "Check upstream Scribe/DPP for the model's category; if trainer-side,"
  log "check QPS. Stale examples → the model is training on outdated data."
  exit 0
else
  log ""
  log "Fleet is clean — all tracked models within the scribe example-age SLO."
  exit 1
fi
