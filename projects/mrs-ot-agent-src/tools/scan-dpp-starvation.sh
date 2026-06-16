#!/bin/bash
# scan-dpp-starvation.sh — DPP / data-starvation detector for tracked prod OT jobs.
#
# Context: D108195174 / S674219 (SEV1 2026-06-10) — an EAG scribe drain dropped DPP
# scribe-token-ingress ~75% → fleet OT QPS=0 while jobs stayed MAST RUNNING. The
# per-job DETECTION signal is dpp_worker examples-read → ~0 (the trainer is RUNNING but
# the DPP/data pipeline isn't feeding it). That's the SAME ODS metric scribe-age/perf
# already query via lib-qps, so detection reuses it. The deeper root-cause CONFIRM
# (scribe token ingress, Scuba dpp_stats_v2 / canvas pzoyunzx) is the routing evidence
# for DPP oncall and is surfaced as the action, not auto-probed in v1.
#
# WHY THE PROXY, NOT THE OPERATOR'S LITERAL ">95% data_starvation_pct" (verified
# 2026-06-10, Scuba dpp_stats_v2): the operator's canonical threshold is per-job
# data_starvation_pct (= dpp.client_unified_starvation_duration_us.sum.60 / 600000)
# > 95%. The dataset + column exist and the column is filterable by mast_job_name /
# model_entity_id; the S674219 SEV IS visible there (job 2144239965 spiked from a
# ~30-50% baseline to avg 92.85% / max 100% at 11:00-13:00 PT). BUT a fixed fleet-wide
# >95% flag is UNUSABLE as-is: a recent 2h per-job scan showed ~ALL healthy OT jobs
# already sit at 97-99% starvation_pct (these trainers are data-bound by design, so
# high absolute starvation is their normal steady state). A >95% filter would flag the
# WHOLE fleet — the exact false-positive flood the digest exists to prevent. The real
# S674219 signal was a RELATIVE climb off the job's own (atypically low) baseline, which
# needs per-job baselining — the same diurnal-baseline work the perf scan is still
# blocked on. So v1 KEEPS the examples-read ~0 proxy (catches the QPS→0 collapse class
# cleanly) and routes the >95% dpp_stats_v2 confirm to the human as the action. Switch
# to a per-job-baseline-relative starvation_pct flag once that baseline lands.
#
# PER-JOB RELATIVE BASELINE — ATTEMPTED, STILL DATA-GATED (2026-06-10, GAP 3). The
# helper tools/lib-fleet-baseline.py is in place to compute each job's own normal
# band from fleet-health-history. It returns INSUFFICIENT_HISTORY for every job
# today and is NOT wired into this flag, on purpose: (1) dpp-starvation findings are
# not even persisted (persist-fleet-history.sh stores only zombie/scribe/perf), so
# there is ZERO dpp history to baseline from; (2) the store keeps FLAGGED findings
# only (survivorship-biased — no healthy steady-state series to learn "normal" from);
# (3) it spans <1wk. Shipping a band off that would flag noise. So the examples-read
# ~0 proxy stays until persist-fleet-history is upgraded to store a dense per-job
# healthy starvation_pct series; then swap in lib_fleet_baseline.relative_band().
#
# Flag: a RUNNING job whose dpp_worker examples-read rate over the recent window is ~0.
# Distinct from: TTFB (never started — cold start), perf (PARTIAL drop <0.85x baseline).
# DPP-starvation = was/should be running but data flow is ~0 NOW. Routing = DPP/scribe
# (mldp_oncall) with the dpp_stats_v2 ingress + canvas pzoyunzx as the confirm evidence.
#
# LATENCY: only a SHORT recent window (RECENT_H) is fetched per job (cheap), parallel
# fan-out — same cost profile as the perf scan. Honors the fleet-health latency budget.
#
# Usage: bash scan-dpp-starvation.sh [--recent-h N] [--all] [--limit N] [--json-only] [--concurrency N]
# Exit:  0 = starvation found   1 = clean   2 = usage/fetch fail

set -euo pipefail
# shellcheck source=lib-enrich-model.sh
source "$(dirname "$0")/lib-enrich-model.sh"
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"
# shellcheck source=lib-qps.sh
source "$(dirname "$0")/lib-qps.sh"
LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

RECENT_H=2          # recent window to judge "examples-read ~0"
EPS=1.0             # examples/sec below this = starved
LIMIT=100
JSON_ONLY=false
SCAN_ALL=false
CONCURRENCY=8
SCAN_ONE=""
MODELS_FILE="$(dirname "$0")/../human-input/models.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --recent-h) RECENT_H="$2"; shift 2 ;;
    --all) SCAN_ALL=true; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --json-only) JSON_ONLY=true; shift ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --scan-one) SCAN_ONE="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--recent-h N] [--all] [--limit N] [--json-only] [--concurrency N]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done
NOW_EPOCH=$(date +%s)
log() { if [ "${JSON_ONLY}" = "false" ]; then echo "$@"; fi; }

# recent_max_qps <eid> <hours> -> echoes max examples/sec over the window (0 if none);
# returns 2 on fetch FAILURE (never a silent empty). present=False (no dpp_worker rows)
# → echoes empty so caller can distinguish "no metric" from "0 rate".
recent_max_qps() {
  local eid="$1" hours="$2"
  fetch_qps_json "${eid}" "${hours}" || return 2
  # QPS_FETCH_PRIMARY is ALREADY the COMPACT `<ts> <rate>` series (+ `# present`),
  # pre-reduced in-shell by lib-qps.sh. Use dpp_worker_qps (compact reader). The old
  # reduce_dpp_worker_rows call expected RAW ODS rows → parsed 0 compact lines →
  # present=False → EVERY job treated as "no metric" and skipped, silently masking
  # real starvation. Fixed 2026-06-10 (codex cross-model review caught it via the
  # identical bug in the new scan-ttfb.sh, which was modeled on this helper).
  QPS_J="${QPS_FETCH_PRIMARY}" EID="${eid}" python3 - "${LIB_DIR}" <<'PY' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1]); import lib_qps
s, present = lib_qps.dpp_worker_qps("QPS_J", os.environ.get('EID',''))
if not present:
    sys.exit(0)            # no dpp_worker metric → emit nothing (caller treats as skip)
vals = [v for _, v in s]
print(f"{max(vals) if vals else 0:.2f}")
PY
}

scan_job() {
  local JOB="$1" VER="$2" EID; EID="${JOB#mvai-training-online-}"
  local MAXQ; MAXQ=$(recent_max_qps "${EID}" "${RECENT_H}") || { echo "ERROR" >> "${WORKER_STATUS}"; return; }
  # No dpp_worker metric at all → can't judge; skip (not an error, not starved).
  [ -n "${MAXQ}" ] || { echo "OK" >> "${WORKER_STATUS}"; return; }
  # Recent examples-read above epsilon → data IS flowing → healthy.
  awk -v q="${MAXQ}" -v e="${EPS}" 'BEGIN{exit !(q+0 < e)}' || { echo "OK" >> "${WORKER_STATUS}"; return; }

  local ENRICH MT PG TIER OWNER URL
  ENRICH=$(enrich_model "${EID}")
  MT="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
  PG="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
  TIER="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"; OWNER="${ENRICH}"
  URL="$(mast_url "${JOB}")"
  local JSON
  JSON=$(MT="${MT}" PG="${PG}" TIER="${TIER}" OWNER="${OWNER}" URL="${URL}" RECENT_H="${RECENT_H}" python3 -c "
import os, json
print(json.dumps({
  'job_name':'${JOB}','version':'${VER}','model_entity_id':'${EID}','mast_url':os.environ['URL'],
  'owner':os.environ['OWNER'],'model_type':os.environ['MT'],'pg':os.environ['PG'],'mvai_tier':os.environ['TIER'],
  'recent_max_qps':${MAXQ},'recent_h':int(os.environ['RECENT_H']),'severity':'act-now','scan_time':${NOW_EPOCH}
}, separators=(',',':')))")
  echo "FLAG" >> "${WORKER_STATUS}"
  printf '%s\n' "${JSON}"
}

resolve_running_job() {
  local eid="$1"
  local job="mvai-training-online-${eid}"
  local meta status version
  meta=$(timeout 15 meta ai.mast-job metadata --name="${job}" -o json 2>&1) || return 1
  status=$(echo "${meta}" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('status',''))" 2>/dev/null)
  version=$(echo "${meta}" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('version',''))" 2>/dev/null)
  [ "${status}" = "RUNNING" ] && [ -n "${version}" ] && { echo "${job}|${version}"; return 0; }
  return 1
}

if [ -n "${SCAN_ONE}" ]; then
  : "${WORKER_STATUS:?WORKER_STATUS must be set}"
  if [[ "${SCAN_ONE}" == *"|"* ]]; then scan_job "${SCAN_ONE%%|*}" "${SCAN_ONE#*|}"
  else RES=$(resolve_running_job "${SCAN_ONE}") && scan_job "${RES%%|*}" "${RES#*|}"; fi
  exit 0
fi

log "=== OT DPP-starvation Fleet Scan ==="
if [ "${SCAN_ALL}" = "true" ]; then
  JOBS_RAW=$(meta ai.mast-job list --job-name-matches-prefix "mvai-training-online-" --status-is RUNNING --limit "${LIMIT}" -o json 2>&1) || { log "ERROR: list failed"; exit 2; }
  TOKENS=$(echo "${JOBS_RAW}" | python3 -c "
import sys,json
data=json.loads(sys.stdin.read()); jobs=data if isinstance(data,list) else data.get('jobs',data.get('data',[]))
for j in jobs:
    n=j.get('name',j.get('job_name','')); v=j.get('version',j.get('latest_version',''))
    if n and v: print(f'{n}|{v}')") || { log "ERROR: parse failed"; exit 2; }
else
  [ -f "${MODELS_FILE}" ] || { log "ERROR: models.md not found"; exit 2; }
  TOKENS=$(grep -oP 'entity_id=\K\d+' "${MODELS_FILE}" | sort -u)
fi
TOKENS=$(echo "${TOKENS}" | grep -v '^$' || true)
[ "$(echo "${TOKENS}" | grep -c .)" -eq 0 ] && { log "No running OT jobs."; exit 1; }

WORK_DIR=$(mktemp -d); trap 'rm -rf "${WORK_DIR}"' EXIT
OUT="${WORK_DIR}/flagged.jsonl"; : > "${OUT}"; SELF="$0"
printf '%s\n' "${TOKENS}" | grep -v '^$' | \
  WORK_DIR="${WORK_DIR}" SELF="${SELF}" RECENT_H="${RECENT_H}" \
  xargs -P "${CONCURRENCY}" -I {} bash -c '
    export WORKER_STATUS="${WORK_DIR}/status.$$.${RANDOM}.$(date +%N)"
    bash "${SELF}" --scan-one "$1" --recent-h "${RECENT_H}" --json-only
  ' _ {} >> "${OUT}"

FLAG=$(grep -c '^{' "${OUT}" 2>/dev/null) || true
SCANNED=0; ERRORS=0
if compgen -G "${WORK_DIR}/status.*" >/dev/null 2>&1; then
  ALL=$(cat "${WORK_DIR}"/status.* 2>/dev/null || true)
  SCANNED=$(printf '%s\n' "${ALL}" | grep -c .) || true
  ERRORS=$(printf '%s\n' "${ALL}" | grep -c '^ERROR$') || true
fi
[ "${FLAG}" -gt 0 ] && { grep '^{' "${OUT}" || true; }
OKC=$(( SCANNED - FLAG - ERRORS ))
printf '{"summary":{"scanned":%s,"flagged":%s,"errors":%s,"ok":%s,"recent_h":%s}}\n' \
  "${SCANNED}" "${FLAG}" "${ERRORS}" "${OKC}" "${RECENT_H}"
if [ "${FLAG}" -gt 0 ]; then
  log "dpp-starvation: ${FLAG} RUNNING job(s) with examples-read ~0 (data starved)"; exit 0
else
  log "dpp-starvation: clean"; exit 1
fi
