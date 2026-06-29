#!/bin/bash
# scan-perf-regression.sh — Pre-SEV performance-regression detector for tracked
# OT prod models (the ones in the OT master agent's models.md).
#
# These are GRADUAL degradations that precede a SEV, not failures:
#   - training example age creeping up      (freshness)
#   - training QPS drifting down            (throughput)
#   - GPU memory climbing                   (leading indicator of the OOM zombie)
#
# Detection is BASELINE-RELATIVE (per model, vs its own trailing median), not a
# global threshold — every model's healthy QPS/age differs. Trend/slope matters
# as much as the instantaneous value (early warning before the SEV line).
#
# NOTE on the baseline (2026-06-10, GAP 3): "baseline-relative" here = the median of
# THIS RUN's live 168h pull (in-window), which is correct and shipping. What is still
# OWED is a CROSS-RUN per-job baseline learned from fleet-health-history (so a model
# whose 168h window is itself depressed by a multi-day issue is still caught vs its
# longer-term normal). That is DATA-GATED: the history store keeps FLAGGED findings
# only (no healthy steady-state series) and spans <1wk — see tools/lib-fleet-baseline.py,
# which returns INSUFFICIENT_HISTORY today. Swap in relative_band() once persist-
# fleet-history stores a dense per-job healthy QPS series across all runs.
#
# Source of scope: human-input/models.md (same registry scan-zombie-fleet.sh uses).
# Read-only: queries Scuba (mvai_metrics, gpu_dyno_stats) only. Never mutates.
#
# Usage:
#   bash scan-perf-regression.sh [--baseline-hours H] [--concurrency N]
#                                [--json-only] [--scan-one ENTITY_ID]
#
# Exit codes:
#   0 = regression(s) found
#   1 = fleet clean (no regression)
#   2 = usage error / data fetch failure
#
# Mirrors scan-zombie-fleet.sh: bounded xargs -P worker pool; each worker
# re-invokes this script in hidden --scan-one mode and emits at most ONE compact
# JSON line (built fully, printf'd atomically so parallel lines never interleave)
# plus a one-line status to a per-worker temp file. Parent tallies after.

set -euo pipefail

# Shared model-enrichment helper (single source of truth across all three
# fleet-health scans). Exposes enrich_model <entity_id> → "model_type|pg|mvai_tier|owner".
# shellcheck source=lib-enrich-model.sh
source "$(dirname "$0")/lib-enrich-model.sh"

# Shared training-QPS fetch helper (single source of truth, also used by
# scan-scribe-age.sh for deterministic cause-class). Exposes
# fetch_qps_json <entity_id> <hours> → sets QPS_FETCH_PRIMARY / QPS_FETCH_FALLBACK,
# rc 0=ok / 2=fetch failed. Parsing+derivation lives in lib_qps.py.
# shellcheck source=lib-qps.sh
source "$(dirname "$0")/lib-qps.sh"
LIB_QPS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Shared URL-construction helper (single source of truth for every internalfb.com
# link). Build the MAST link from the bare entity_id via mast_url so it carries
# the mvai-training-online- prefix (correct-by-construction; the bare-eid URL
# 404'd — root cause of the 2026-06-05/06 perf-link fix).
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"

BASELINE_H=168              # trailing window for the baseline (7d)
GPU_SLOPE_H=24             # window for GPU-mem slope (leading OOM indicator)
CONCURRENCY=8
JSON_ONLY=false
SCAN_ONE=""
MODELS_FILE="$(dirname "$0")/../human-input/models.md"

# Flag rules (baseline-relative; tune as data accrues).
AGE_RATIO=2.0             # recent age > AGE_RATIO x baseline → flag
AGE_FLOOR_SECS=120        # ...but only if recent age also exceeds this (kill 0-noise)
QPS_FRAC=0.85             # recent QPS < QPS_FRAC x baseline → flag
GPU_SLOPE_PP=5.0          # GPU mem-util slope over window > this many points → flag
GPU_RECENT_MIN=80.0       # ...and only if recent GPU mem-util above this (matters)
GPU_HIGH_PCT=90.0         # ABSOLUTE: recent GPU mem-util ≥ this → flag regardless of slope
                          # (imminent-OOM; operator 2026-06-22 from S670887 OOM-zombie context)
                          # ⚠ BACKTEST 2026-06-22: gpu_dyno_stats.gpu_memory_utilization_float
                          # returns 0 for real models filtered by model_entity_id (400k samples,
                          # value 0) — DEAD source, shared with gpu_mem_climb (also non-functional).
                          # gpu_mem_high will NOT fire until this metric/filter is repointed to a
                          # live GPU-mem source. FOLLOW-UP: fix the source, then both triggers work.

while [ $# -gt 0 ]; do
  case "$1" in
    --baseline-hours) BASELINE_H="$2"; shift 2 ;;
    --concurrency)    CONCURRENCY="$2"; shift 2 ;;
    --json-only)      JSON_ONLY=true; shift ;;
    --scan-one)       SCAN_ONE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--baseline-hours H] [--concurrency N] [--json-only]"
      echo "  Scans tracked prod models from models.md for pre-SEV perf regression."
      echo "  Signals: example age (data_age_at_publish_secs), window QPS,"
      echo "           GPU mem-util slope. Baseline-relative, per model."
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

log() { [ "${JSON_ONLY}" = "false" ] && echo "$@" || true; }

# ─────────────────────────────────────────────────────────────────────────────
# Worker: pull 3 metric series for one model, compute baseline-relative drift,
# emit ONE JSON line if any rule fires. Writes FLAG/OK/SKIP/ERROR to WORKER_STATUS.
# ─────────────────────────────────────────────────────────────────────────────
check_model() {
  local EID="$1"

  # Owner / model name / tier from the registry row (no extra meta call).
  local ROW OWNER MNAME
  # models.md columns (2026-06-04, after the leading '#' row-number column was added):
  # $1='' $2=# $3=Model $4=ModelType $5=EntityID $6=Customer $7=Owner $8=GPUs ...
  ROW=$(grep -F "entity_id=${EID}" "${MODELS_FILE}" 2>/dev/null | head -1 || true)
  MNAME=$(echo "${ROW}" | awk -F'|' '{gsub(/^ *| *$/,"",$3); print $3}')
  OWNER=$(echo "${ROW}" | awk -F'|' '{gsub(/^ *| *$/,"",$7); print $7}')
  [ -z "${MNAME}" ] && MNAME="?"
  [ -z "${OWNER}" ] && OWNER="?"

  # --- pull the three series (JSON list of buckets; values are strings) ---
  # QPS is PRIMARY (liveness gate + main trigger). The shared helper does the
  # primary→fallback fetch with the failure-vs-empty discipline (rc 2 = a fetch
  # FAILED → ERROR, never silently SKIP; "[]" = genuinely not emitting). Codex
  # findings 2026-06-03 / 2026-06-05, now centralized in lib-qps.sh.
  local AGE_J QPS_J QPSQ_J GPU_J
  fetch_qps_json "${EID}" "${BASELINE_H}" || { echo "ERROR" >> "${WORKER_STATUS}"; return; }
  QPS_J="${QPS_FETCH_PRIMARY}"
  QPSQ_J="${QPS_FETCH_FALLBACK}"
  # AGE/GPU are secondary; a fetch failure just costs that one signal (not a
  # silent regression drop, since QPS already gated above).
  AGE_J=$(timeout 40 meta scuba.dataset query -d mvai_metrics -a p90 -c data_age_at_publish_secs \
    -w "[{\"column\":\"model_entity_id\",\"op\":\"eq\",\"values\":[\"${EID}\"]}]" \
    --hours="${BASELINE_H}" --time-bucket="1 hour" -o json 2>/dev/null) || AGE_J="[]"
  [ -z "${AGE_J}" ] && AGE_J="[]"
  GPU_J=$(timeout 40 meta scuba.dataset query -d gpu_dyno_stats -a max -c gpu_memory_utilization_float \
    -w "[{\"column\":\"model_entity_id\",\"op\":\"eq\",\"values\":[\"${EID}\"]}]" \
    --hours="${GPU_SLOPE_H}" --time-bucket="1 hour" -o json 2>/dev/null) || GPU_J="[]"
  [ -z "${GPU_J}" ] && GPU_J="[]"

  local OUT
  OUT=$(EID="${EID}" MNAME="${MNAME}" OWNER="${OWNER}" \
        AGE_J="${AGE_J}" QPS_J="${QPS_J}" QPSQ_J="${QPSQ_J}" GPU_J="${GPU_J}" \
        AGE_RATIO="${AGE_RATIO}" AGE_FLOOR_SECS="${AGE_FLOOR_SECS}" \
        QPS_FRAC="${QPS_FRAC}" GPU_SLOPE_PP="${GPU_SLOPE_PP}" GPU_RECENT_MIN="${GPU_RECENT_MIN}" \
        GPU_HIGH_PCT="${GPU_HIGH_PCT}" \
        LIB_QPS_DIR="${LIB_QPS_DIR}" \
        python3 <<'PY'
import os, json, statistics, sys

# Shared QPS series-parsing + rate-derivation (single source of truth, also used
# by scan-scribe-age.sh). series/dpp_worker_qps/recent_baseline/resolve_qps_series
# live in lib_qps.py so the QPS verdict is computed identically across scans.
sys.path.insert(0, os.environ["LIB_QPS_DIR"])
from lib_qps import series, recent_baseline, resolve_qps_series, qps_down_sustained  # noqa: E402

def slope_pp(s, frac=3):
    """(mean of last third) - (mean of first third), in raw units (pp for %)."""
    vals = [v for _, v in s]
    if len(vals) < 6:
        return None, None
    k = max(1, len(vals)//frac)
    first = statistics.mean(vals[:k])
    last = statistics.mean(vals[-k:])
    return last - first, last

EID   = os.environ["EID"]
MNAME = os.environ["MNAME"]
OWNER = os.environ["OWNER"]
AGE_RATIO = float(os.environ["AGE_RATIO"])
AGE_FLOOR = float(os.environ["AGE_FLOOR_SECS"])
QPS_FRAC  = float(os.environ["QPS_FRAC"])
GPU_SLOPE = float(os.environ["GPU_SLOPE_PP"])
GPU_RMIN  = float(os.environ["GPU_RECENT_MIN"])
GPU_HIGH  = float(os.environ["GPU_HIGH_PCT"])

age = series("AGE_J", "data_age_at_publish_secs")
gpu = series("GPU_J", "gpu_memory_utilization_float")

# QPS-source resolution (coverage fix 2026-06-05; centralized in lib_qps.py):
#   PRIMARY = ODS dpp_worker.num_examples_read.sum.60, per-worker shard-sum / 60
#   (examples/s) — same dpp_worker family as scribe-age, covers the WHOLE fleet.
#   FALLBACK = TB qps/global/window/train (verbatim), only if ODS yielded nothing.
#   Only when NEITHER source is present is the model SKIPPED.
qps, qps_source, qpsq_present = resolve_qps_series()

# Liveness/coverage gate. Distinguish two skip reasons (the old code conflated them):
#   - "no_metric": no dpp_worker rows AND no TB qps key for this EID → genuine
#     coverage boundary (sub-model keyed elsewhere).
#   - "dead": a dpp_worker entity EXISTS (rollup-only / single sample) but yielded
#     no usable shard rate → model not currently emitting a derivable rate.
# A model WITH qps history whose recent value collapsed toward 0 is NOT skipped —
# that is the most severe regression (QPS→0, the S670887 symptom); it falls through
# to qps_down below. Codex 2026-06-03.
if not qps:
    reason = "dead" if qpsq_present else "no_metric"
    print("SKIP " + reason)
    raise SystemExit

# Present-but-too-sparse guard (codex 2026-06-05): recent_baseline() needs ≥6
# samples; with fewer it returns None and qps_down can never fire, so the model
# would silently score OK while actually being uncoverable. Make that explicit —
# a non-empty-but-unbaselineable series is "dead" (insufficient data to judge),
# NOT a clean OK. (GPU has its own ≥6 guard and is a secondary signal, so a
# sparse-qps model with rich gpu still can't produce a trustworthy qps verdict.)
if len([v for _, v in qps]) < 6:
    print("SKIP dead")
    raise SystemExit

# Triggers = qps_down OR gpu_mem_climb (the gaps NOT covered elsewhere).
# example_age is OWNED by tools/scan-scribe-age.sh (ot-fleet-health, team space,
# hard 10min SLO) — per P-014 (defer overlap) we do NOT fire a standalone
# freshness alert here; age_up is computed only as a CO-SIGNAL to attribute the
# QPS regression to a subsystem.

# Human-readable number formatter (deterministic — don't leave K/M to the LLM).
# Edge cases: None/non-numeric → "?"; <1000 → integer; <1M → X.XK; else X.XXM; 0 → "0".
def kfmt(n):
    try:
        n = float(n)
    except (TypeError, ValueError):
        return "?"
    if n < 0:
        return "?"
    if n < 1000:
        return str(int(round(n)))
    if n < 1_000_000:
        return f"{n/1000:.1f}K"
    return f"{n/1_000_000:.2f}M"

# co-signal: example age elevated vs its own baseline
age_up = False
age_detail = None
a_rec, a_base = recent_baseline(age)
if a_rec is not None and a_rec >= AGE_FLOOR and a_base is not None:
    ratio = a_rec / a_base if a_base > 0 else float('inf')
    if ratio >= AGE_RATIO:
        age_up = True
        xr = round(ratio, 1) if ratio != float('inf') else "inf"
        age_detail = {"signal": "example_age_up_cosignal", "recent_s": round(a_rec),
                      "baseline_s": round(a_base), "x": xr,
                      "h": f"age {round(a_rec/60)}m ({xr}× base)"}

# trigger: QPS down vs baseline (sawtooth-robust; see lib_qps.qps_down_sustained):
#   recent = MEDIAN of last ~45min of buckets (not mean-of-last-2) AND a MAJORITY
#   of the recent-window buckets must be below threshold. This kills the spurious
#   ~100% drops a lone zero-trough used to cause (the 17-vs-23 run-to-run noise)
#   while still flagging genuine multi-hour QPS collapses.
qps_low, q_info = qps_down_sustained(qps, QPS_FRAC)
qps_detail = None
if qps_low and q_info is not None:
    q_rec = q_info["recent"]
    q_base = q_info["baseline"]
    frac = q_info["frac"]
    drop = 100 - round(100 * frac)
    qps_detail = {"signal": "qps_down", "recent": round(q_rec),
                  "baseline": round(q_base), "pct_of_base": round(100*frac),
                  "drop_pct": drop, "qps_source": qps_source,
                  "below_buckets": q_info["below"], "window_buckets": q_info["window"],
                  "h": f"qps {kfmt(q_rec)} ↓{drop}% (vs {kfmt(q_base)}, "
                       f"{q_info['below']}/{q_info['window']} buckets low)"}

# trigger: GPU mem-util climbing (leading OOM-zombie indicator)
g_slope, g_recent = slope_pp(gpu)
gpu_climb = False
gpu_detail = None
if g_slope is not None and g_recent is not None:
    if g_slope > GPU_SLOPE and g_recent >= GPU_RMIN:
        gpu_climb = True
        gpu_detail = {"signal": "gpu_mem_climb", "slope_pp": round(g_slope, 1),
                      "recent_pct": round(g_recent, 1),
                      "h": f"GPU mem +{round(g_slope,1)}pp→{round(g_recent)}%"}

# trigger: GPU mem-util ABSOLUTE ≥ GPU_HIGH (imminent-OOM, fires regardless of slope —
# a job already pinned ≥90% is at OOM risk even if flat). Uses a direct recent value
# (mean of last ≤3 hourly-max buckets) so it does NOT need slope_pp's ≥6-sample floor.
# Operator 2026-06-22 from S670887 (OOM-zombie; GPU-mem was the missing pre-failure probe).
g_vals = [v for _, v in gpu]
g_recent_abs = statistics.mean(g_vals[-3:]) if g_vals else None
gpu_high = False
gpu_high_detail = None
if g_recent_abs is not None and g_recent_abs >= GPU_HIGH:
    gpu_high = True
    gpu_high_detail = {"signal": "gpu_mem_high", "recent_pct": round(g_recent_abs, 1),
                       "threshold_pct": int(GPU_HIGH),
                       "h": f"GPU mem {round(g_recent_abs)}% (≥{int(GPU_HIGH)}%, OOM risk)"}

if not (qps_low or gpu_climb or gpu_high):
    print("OK")
    raise SystemExit

fired = [d for d in (qps_detail, gpu_detail, gpu_high_detail, age_detail) if d]

# Decision-matrix → likely subsystem (see cheatsheets/oncall/mast-debugging.md).
if gpu_high and qps_low:
    sub = "GPU mem ≥90% WITH QPS drop — active OOM/memory-pressure stall; restart-risk, check trace-doctor + gpu_dyno_stats now"
elif gpu_high:
    sub = "GPU mem ≥90% (imminent-OOM) — reduce batch/activation memory or watch for OOM-zombie; trace-doctor memory analyzer"
elif qps_low and gpu_climb:
    sub = "memory pressure / leak (early OOM-zombie warning) — check gpu_dyno_stats slope + trace-doctor"
elif qps_low and age_up:
    sub = "trainer can't keep up (GPU throttle / straggler / PT2 recompile) — trace-doctor + per-rank QPS"
elif qps_low:
    sub = "input-bound / data stall (DPP readers / dataloader / partitions) — trace-doctor critical-path"
elif age_up:
    sub = "upstream / publish pipeline lag (scribe volume / Hedwig backpressure / snapshot) — trainer likely fine"
elif gpu_climb:
    sub = "GPU memory climbing (pre-OOM) — watch for zombie; check publish-path allocations"
else:
    sub = "perf drift — investigate"

print("FLAG")
print(json.dumps({
    "entity_id": EID,
    "model": MNAME,
    "owner": OWNER,
    "signals": fired,
    "likely_subsystem": sub,
}, separators=(",", ":")))
PY
) || { echo "ERROR" >> "${WORKER_STATUS}"; return; }

  local VERDICT VTOK JSON_LINE
  VERDICT=$(printf '%s\n' "${OUT}" | head -1)
  VTOK="${VERDICT%% *}"   # first word; SKIP carries a reason ("SKIP no_metric"/"SKIP dead")
  if [ "${VTOK}" = "FLAG" ]; then
    JSON_LINE=$(printf '%s\n' "${OUT}" | sed -n '2p')

    # Shared enrichment (model_type / pg / mvai_tier / owner) via the common
    # helper, ONLY for flagged models (cost-bounded, matching the breaches-only
    # pattern of the sibling scans). owner from the helper's full fallback chain
    # OVERRIDES the registry-row owner so all three scans render identically.
    # Merged into the already-built FLAG JSON so existing fields are preserved.
    local ENRICH ENR_MODEL_TYPE ENR_PG ENR_TIER ENR_OWNER
    ENRICH=$(enrich_model "${EID}")
    ENR_MODEL_TYPE="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
    ENR_PG="${ENRICH%%|*}";         ENRICH="${ENRICH#*|}"
    ENR_TIER="${ENRICH%%|*}";       ENRICH="${ENRICH#*|}"
    ENR_OWNER="${ENRICH}"
    # Resolvable MAST link built correct-by-construction from the bare eid
    # (carries the mvai-training-online- prefix; bare-eid URL 404s). Emitted as a
    # JSON field so render-fleet-digest.py renders it verbatim, no rebuild.
    local MAST_URL; MAST_URL="$(mast_url "${EID}")"
    JSON_LINE=$(JSON_LINE="${JSON_LINE}" MODEL_TYPE="${ENR_MODEL_TYPE}" PG="${ENR_PG}" \
      MVAI_TIER="${ENR_TIER}" OWNER="${ENR_OWNER}" MAST_URL="${MAST_URL}" python3 -c "
import os, json
d = json.loads(os.environ['JSON_LINE'])
d['model_type'] = os.environ['MODEL_TYPE']
d['pg'] = os.environ['PG']
d['mvai_tier'] = os.environ['MVAI_TIER']
d['mast_url'] = os.environ['MAST_URL']
# owner: prefer the helper's resolved value unless it is the unknown sentinel.
ow = os.environ['OWNER']
if ow and ow != '?':
    d['owner'] = ow
print(json.dumps(d, separators=(',', ':')))
" 2>/dev/null) || JSON_LINE=$(printf '%s\n' "${OUT}" | sed -n '2p')

    echo "FLAG" >> "${WORKER_STATUS}"
    printf '%s\n' "${JSON_LINE}"
  elif [ "${VTOK}" = "SKIP" ]; then
    # Record reason-tagged skip so the summary can split coverage-boundary
    # ("no_metric") from not-emitting ("dead"). Both still grep as "^SKIP".
    local SREASON="${VERDICT#SKIP }"; [ "${SREASON}" = "${VERDICT}" ] && SREASON="no_metric"
    echo "SKIP ${SREASON}" >> "${WORKER_STATUS}"
  elif [ "${VTOK}" = "OK" ]; then
    echo "OK" >> "${WORKER_STATUS}"
  else
    echo "ERROR" >> "${WORKER_STATUS}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Hidden worker mode.
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "${SCAN_ONE}" ]; then
  : "${WORKER_STATUS:?WORKER_STATUS must be set in worker mode}"
  check_model "${SCAN_ONE}"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Parent mode.
# ─────────────────────────────────────────────────────────────────────────────
NOW_HUMAN=$(python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.now(tz=timezone(timedelta(hours=-7))).strftime('%Y-%m-%d %H:%M:%S PDT'))")
log "=== OT Performance-Regression Fleet Scan ==="
log "Time:     ${NOW_HUMAN}"
log "Baseline: trailing ${BASELINE_H}h, per-model median (robust)"
log ""

if [ ! -f "${MODELS_FILE}" ]; then
  log "ERROR: models.md not found at ${MODELS_FILE}"
  exit 2
fi

TOKEN_LIST=$(grep -oP 'entity_id=\K\d+' "${MODELS_FILE}" | sort -u | grep -v '^$' || true)
TOTAL=$(echo "${TOKEN_LIST}" | grep -c . || echo 0)
log "[1/2] ${TOTAL} tracked models. Scanning with ${CONCURRENCY} workers..."
log ""

if [ "${TOTAL}" -eq 0 ]; then
  log "No tracked models found."
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT
FLAG_OUT="${WORK_DIR}/flags.jsonl"
: > "${FLAG_OUT}"
SELF="$0"

printf '%s\n' "${TOKEN_LIST}" | grep -v '^$' | \
  WORK_DIR="${WORK_DIR}" SELF="${SELF}" BASELINE_H="${BASELINE_H}" \
  xargs -P "${CONCURRENCY}" -I {} bash -c '
    tok="$1"
    export WORKER_STATUS="${WORK_DIR}/status.$$.${RANDOM}.$(date +%N)"
    # Fallback: if the worker dies under set -euo pipefail BEFORE writing its
    # status (e.g. an unguarded pipeline), record ERROR so it is counted, never
    # silently lost from the tally. Codex finding 2026-06-03.
    bash "${SELF}" --scan-one "${tok}" --baseline-hours "${BASELINE_H}" --json-only \
      || echo "ERROR" >> "${WORKER_STATUS}"
  ' _ {} >> "${FLAG_OUT}"

FLAG_COUNT=$(grep -c '^{' "${FLAG_OUT}" 2>/dev/null) || true
SCANNED=0; ERRORS=0; SKIPPED=0; SKIP_NOMETRIC=0; SKIP_DEAD=0
if compgen -G "${WORK_DIR}/status.*" > /dev/null 2>&1; then
  ALL=$(cat "${WORK_DIR}"/status.* 2>/dev/null || true)
  SCANNED=$(printf '%s\n' "${ALL}" | grep -c .) || true
  ERRORS=$(printf '%s\n' "${ALL}" | grep -c '^ERROR$') || true
  # Skip lines are reason-tagged ("SKIP no_metric" / "SKIP dead"); count by prefix.
  SKIPPED=$(printf '%s\n' "${ALL}" | grep -c '^SKIP') || true
  SKIP_NOMETRIC=$(printf '%s\n' "${ALL}" | grep -c '^SKIP no_metric') || true
  SKIP_DEAD=$(printf '%s\n' "${ALL}" | grep -c '^SKIP dead') || true
fi

if [ "${FLAG_COUNT}" -gt 0 ]; then
  grep '^{' "${FLAG_OUT}" || true
fi

# Machine-readable summary — ALWAYS printed (even under --json-only), so callers
# (ot-fleet-health's 📉 section) get scanned/skipped coverage without the human
# log lines. (2026-06-04: prompt-change-validator caught that --json-only gates
# off log() → the skip count the 📉 coverage line needs was unavailable.)
printf '{"summary":{"scanned":%s,"total":%s,"flagged":%s,"skipped":%s,"errors":%s}}\n' \
  "${SCANNED}" "${TOTAL}" "${FLAG_COUNT}" "${SKIPPED}" "${ERRORS}"

log ""
log "[2/2] Summary"
log "════════════════════════════════════════════════════════════"
log "  Scanned:     ${SCANNED} / ${TOTAL} models"
log "  Regressions: ${FLAG_COUNT}"
log "  Skipped:     ${SKIPPED} (${SKIP_NOMETRIC} no-metric / ${SKIP_DEAD} dead — zombie-scan's job)"
log "  Errors:      ${ERRORS} (timeout / fetch failure)"
log "════════════════════════════════════════════════════════════"

[ "${FLAG_COUNT}" -gt 0 ] && exit 0 || exit 1
