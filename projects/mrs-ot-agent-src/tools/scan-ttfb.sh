#!/bin/bash
# scan-ttfb.sh — TTFB / cold-start detector for tracked prod OT jobs.
#
# Context: a freshly (re)started OT trainer must initialize (package pull, model
# build, DPP reader spin-up, PT2/compile warm-up) before it reads its FIRST batch
# and QPS climbs off zero. A HEALTHY job crosses that "first-batch" line in a few
# minutes. A job STUCK in init — a hung DPP reader, a compile that never finishes,
# an OOM-loop on startup — sits MAST RUNNING with QPS pinned at ~0 for a long time
# and never starts producing. Nothing looks broken (state=RUNNING) but it is dead
# weight burning GPUs and falling further behind on freshness every minute.
#
# DETECTION (per RUNNING tracked job):
#   1. Resolve the CURRENT attempt's start_time via `meta ai.mast-job attempts`
#      (highest-numbered attempt; the one that is RUNNING).
#   2. elapsed = now - attempt_start.
#   3. Only judge jobs INSIDE the window THRESHOLD_MIN(60) < elapsed < MAX_DETECT_MIN(360):
#        - elapsed <= 60m  → too soon, a healthy cold start can legitimately take a
#          while; skip cheaply (don't even fetch QPS).
#        - elapsed >= 360m → if it were a cold-start stall it would have surfaced as
#          a zombie / dpp-starvation / perf flag by now; outside our window, skip.
#   4. For jobs in-window, fetch dpp_worker examples-read QPS BOUNDED TO THE ELAPSED
#      WINDOW (cheap — minutes, not the 168h the perf scan pulls). If the MAX QPS
#      since attempt-start is ~0 (EPS), the job NEVER reached its first batch =
#      cold-start stall → FLAG act-now.
#
# Distinct from siblings:
#   - zombie         : was running, worker crashed / stopped progressing.
#   - dpp-starvation : was producing, data flow dropped to ~0 NOW (RECENT window).
#   - perf           : PARTIAL drop (<0.85x baseline), still producing.
#   - ttfb/cold-start: NEVER produced since the current attempt start (max QPS ~0
#                      over the WHOLE elapsed window). The "never started" class.
#
# Routing = the owner: check init / DPP reader spin-up / PT2 compile / OOM-on-start.
#
# LATENCY (operator: fleet-health has a hard latency requirement): the elapsed-window
# QPS pull is short by construction (the in-window cap is 360m, and most jobs are
# skipped cheaply before any QPS fetch — only ones in the 60–360m window pay it).
# Parallel xargs fan-out, same cost profile as the dpp / perf scans. Target <2min.
#
# RELATIVE BASELINING OWED (data-gated, 2026-06-10): like dpp-starvation and perf,
# the truly principled signal is per-job-relative (this job's own normal cold-start
# duration), not a fixed 60m floor. That needs a per-job trailing baseline off
# fleet-health-history, which is NOT yet shippable: the history store keeps only
# FLAGGED findings (not full per-job series) and spans <1wk, so there is no healthy
# baseline corpus to learn each job's normal init time from. v1 uses the fixed
# 60/360 window (a healthy OT trainer reaches first batch well under 60m in practice);
# switch to per-job-relative once persist-fleet-history stores full series. See
# tools/lib-fleet-baseline.py for the (currently DATA-GATED) baseline helper.
#
# Usage: bash scan-ttfb.sh [--threshold-min N] [--max-detect-min N] [--all]
#                          [--limit N] [--json-only] [--concurrency N] [--scan-one EID]
# Exit:  0 = cold-start stall(s) found   1 = clean   2 = usage/fetch fail

set -euo pipefail
# shellcheck source=lib-enrich-model.sh
source "$(dirname "$0")/lib-enrich-model.sh"
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"
# shellcheck source=lib-qps.sh
source "$(dirname "$0")/lib-qps.sh"
LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

THRESHOLD_MIN=60     # below this elapsed-since-attempt-start → too soon, skip
MAX_DETECT_MIN=360   # above this → outside our window (other scans own it), skip
EPS=1.0              # max examples/sec at/below this over the elapsed window = never started
LIMIT=100
JSON_ONLY=false
SCAN_ALL=false
CONCURRENCY=8
SCAN_ONE=""
MODELS_FILE="$(dirname "$0")/../human-input/models.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --threshold-min) THRESHOLD_MIN="$2"; shift 2 ;;
    --max-detect-min) MAX_DETECT_MIN="$2"; shift 2 ;;
    --all) SCAN_ALL=true; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --json-only) JSON_ONLY=true; shift ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --scan-one) SCAN_ONE="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--threshold-min N] [--max-detect-min N] [--all] [--limit N] [--json-only] [--concurrency N]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done
NOW_EPOCH=$(date +%s)
log() { if [ "${JSON_ONLY}" = "false" ]; then echo "$@"; fi; }

# current_attempt_start <eid> -> echoes the CURRENT (latest, RUNNING) attempt's
# start epoch; nothing + rc1 if the job isn't RUNNING / has no resolvable attempt;
# rc2 on a fetch FAILURE (never a silent empty). The latest attempt = highest
# `attempt` number; we require its status to be RUNNING (a cold-start stall is by
# definition a RUNNING attempt that never produced).
current_attempt_start() {
  local eid="$1"
  local job="mvai-training-online-${eid}"
  local out
  out=$(timeout 20 meta ai.mast-job attempts --name="${job}" -o json 2>/dev/null) || return 2
  EID="${eid}" python3 - "${out}" <<'PY'
import sys, json
from datetime import datetime
raw = sys.argv[1]
try:
    d = json.loads(raw)
except Exception:
    sys.exit(1)
atts = d if isinstance(d, list) else d.get("attempts", d.get("data", []))
if not isinstance(atts, list) or not atts:
    sys.exit(1)
# latest attempt = max numeric 'attempt'
def anum(a):
    try:
        return int(a.get("attempt", "0"))
    except (TypeError, ValueError):
        return -1
cur = max(atts, key=anum)
if (cur.get("status") or "").upper() != "RUNNING":
    sys.exit(1)
st = (cur.get("start_time") or "").strip()
if not st:
    sys.exit(1)
# MAST renders e.g. "2026-06-10 11:58:08 PDT" — an explicit tz ABBREVIATION token.
# Parse the offset from that token (codex 2026-06-10: stripping it and parsing as
# host-local makes elapsed WRONG whenever the cron host TZ != the rendered TZ →
# jobs shift out of the 60..360m window). Map the common abbreviations to fixed UTC
# offsets and compute an absolute epoch; only fall back to host-local (with the old
# strip behavior) for an unknown abbreviation, which is then host-TZ-dependent.
from datetime import timezone, timedelta
TZ_OFFSETS = {  # hours from UTC
    "UTC": 0, "GMT": 0,
    "PST": -8, "PDT": -7, "MST": -7, "MDT": -6,
    "CST": -6, "CDT": -5, "EST": -5, "EDT": -4,
}
toks = st.split()
tzabbr = toks[-1] if (len(toks) >= 3 and not toks[-1].isdigit()) else None
base = " ".join(toks[:-1]) if tzabbr else st
try:
    naive = datetime.strptime(base, "%Y-%m-%d %H:%M:%S")
except ValueError:
    sys.exit(1)
if tzabbr in TZ_OFFSETS:
    ep = int(naive.replace(tzinfo=timezone(timedelta(hours=TZ_OFFSETS[tzabbr]))).timestamp())
else:
    # unknown / no tz token → host-local interpretation (host-TZ dependent fallback)
    ep = int(naive.timestamp())
print(ep)
PY
}

# max_qps_since <eid> <minutes> <attempt_start_epoch> -> echoes max examples/sec
# STRICTLY since the current attempt start (0 if none); rc2 on fetch FAILURE. Empty
# (no dpp_worker metric at all) → caller can't judge → treats as skip, not flag.
max_qps_since() {
  local eid="$1" minutes="$2" astart="$3"
  # lib-qps takes HOURS; round the elapsed minutes up to whole hours, min 1, so the
  # bounded pull always covers the whole window since attempt start (cheap: <=6h).
  local hours
  hours=$(awk -v m="${minutes}" 'BEGIN{h=int((m+59)/60); if(h<1)h=1; print h}')
  fetch_qps_json "${eid}" "${hours}" || return 2
  # QPS_FETCH_PRIMARY is ALREADY the COMPACT `<ts> <rate>` series (+ a `# present`
  # marker), pre-reduced in-shell by lib-qps.sh's `--reduce-dpp-worker` pipe. Read
  # it with dpp_worker_qps (compact-env reader); do NOT call reduce_dpp_worker_rows
  # here — that expects RAW ODS rows and would parse 0 lines → always-skip (codex
  # 2026-06-10: same latent bug existed in scan-dpp-starvation.sh, fixed there too).
  #
  # FILTER ts >= astart (codex 2026-06-10): the pull window is rounded UP to whole
  # hours, so it can start up to ~59m BEFORE the attempt start. QPS from a PRIOR
  # attempt in that pre-start slack would falsely lift max_qps above EPS and mask a
  # real cold-start stall (false negative). dpp_worker compact timestamps are ODS
  # epoch seconds, directly comparable to the attempt-start epoch.
  QPS_J="${QPS_FETCH_PRIMARY}" EID="${eid}" ASTART="${astart}" python3 - "${LIB_DIR}" <<'PY' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1]); import lib_qps
s, present = lib_qps.dpp_worker_qps("QPS_J", os.environ.get('EID',''))
if not present:
    sys.exit(0)            # no dpp_worker metric → emit nothing (caller treats as skip)
try:
    astart = int(os.environ.get('ASTART', '0'))
except ValueError:
    astart = 0
vals = []
for ts, v in s:
    try:
        if int(float(ts)) >= astart:
            vals.append(v)
    except (TypeError, ValueError):
        continue
print(f"{max(vals) if vals else 0:.2f}")
PY
}

scan_job() {
  local EID="$1"
  # NOTE: capture rc WITHOUT tripping `set -e`. `ASTART=$(cmd)` on its own line
  # makes a non-zero cmd rc fatal under set -e; guard with `|| arc=$?` so rc 1/2
  # (not-running / fetch-fail) are handled, not aborted (the xargs-123 bug).
  local ASTART arc=0
  ASTART=$(current_attempt_start "${EID}") || arc=$?
  case "${arc}" in
    2) echo "ERROR" >> "${WORKER_STATUS}"; return ;;
    1) echo "SKIP_NA" >> "${WORKER_STATUS}"; return ;;   # not RUNNING / no current attempt → not our class
  esac
  [ -n "${ASTART}" ] || { echo "SKIP_NA" >> "${WORKER_STATUS}"; return; }

  local ELAPSED_MIN; ELAPSED_MIN=$(awk -v n="${NOW_EPOCH}" -v s="${ASTART}" 'BEGIN{printf "%.1f", (n-s)/60.0}')
  # Cheap window gate BEFORE any QPS fetch: skip too-soon and too-old.
  if awk -v e="${ELAPSED_MIN}" -v t="${THRESHOLD_MIN}" 'BEGIN{exit !(e+0 <= t)}'; then
    echo "SKIP_SOON" >> "${WORKER_STATUS}"; return    # too soon to judge
  fi
  if awk -v e="${ELAPSED_MIN}" -v m="${MAX_DETECT_MIN}" 'BEGIN{exit !(e+0 >= m)}'; then
    echo "SKIP_OLD" >> "${WORKER_STATUS}"; return    # outside detection window
  fi

  local MAXQ; MAXQ=$(max_qps_since "${EID}" "${ELAPSED_MIN}" "${ASTART}") || { echo "ERROR" >> "${WORKER_STATUS}"; return; }
  # No dpp_worker metric → can't judge "never started"; skip (not error, not stall).
  [ -n "${MAXQ}" ] || { echo "SKIP_NA" >> "${WORKER_STATUS}"; return; }
  # Max QPS since attempt-start above epsilon → it DID start → healthy (not cold-start).
  # JUDGED_OK = genuinely evaluated in-window and started fine (distinct from skipped).
  awk -v q="${MAXQ}" -v e="${EPS}" 'BEGIN{exit !(q+0 < e)}' || { echo "JUDGED_OK" >> "${WORKER_STATUS}"; return; }

  local JOB="mvai-training-online-${EID}"
  local ENRICH MT PG TIER OWNER URL
  ENRICH=$(enrich_model "${EID}")
  MT="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
  PG="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
  TIER="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"; OWNER="${ENRICH}"
  URL="$(mast_url "${JOB}")"
  local ELAPSED_R; ELAPSED_R=$(awk -v e="${ELAPSED_MIN}" 'BEGIN{printf "%d", e+0.5}')
  local JSON
  JSON=$(MT="${MT}" PG="${PG}" TIER="${TIER}" OWNER="${OWNER}" URL="${URL}" \
    ELAPSED_R="${ELAPSED_R}" MAXQ="${MAXQ}" python3 -c "
import os, json
print(json.dumps({
  'job_name':'${JOB}','model_entity_id':'${EID}','mast_url':os.environ['URL'],
  'owner':os.environ['OWNER'],'model_type':os.environ['MT'],'pg':os.environ['PG'],'mvai_tier':os.environ['TIER'],
  'elapsed_min':int(os.environ['ELAPSED_R']),'max_qps':float(os.environ['MAXQ']),
  'severity':'act-now','scan_time':${NOW_EPOCH}
}, separators=(',',':')))")
  echo "FLAG" >> "${WORKER_STATUS}"
  printf '%s\n' "${JSON}"
}

# ---- worker mode ----
if [ -n "${SCAN_ONE}" ]; then
  : "${WORKER_STATUS:?WORKER_STATUS must be set}"
  scan_job "${SCAN_ONE}"
  exit 0
fi

# ---- parent mode ----
log "=== OT TTFB / cold-start Fleet Scan ==="
if [ "${SCAN_ALL}" = "true" ]; then
  JOBS_RAW=$(meta ai.mast-job list --job-name-matches-prefix "mvai-training-online-" --status-is RUNNING --limit "${LIMIT}" -o json 2>&1) || { log "ERROR: list failed"; exit 2; }
  TOKENS=$(echo "${JOBS_RAW}" | python3 -c "
import sys,json
data=json.loads(sys.stdin.read()); jobs=data if isinstance(data,list) else data.get('jobs',data.get('data',[]))
for j in jobs:
    n=j.get('name',j.get('job_name',''))
    if n: print(n.replace('mvai-training-online-',''))") || { log "ERROR: parse failed"; exit 2; }
else
  [ -f "${MODELS_FILE}" ] || { log "ERROR: models.md not found"; exit 2; }
  TOKENS=$(grep -oP 'entity_id=\K\d+' "${MODELS_FILE}" | sort -u)
fi
TOKENS=$(echo "${TOKENS}" | grep -v '^$' || true)
[ "$(echo "${TOKENS}" | grep -c .)" -eq 0 ] && { log "No tracked OT jobs."; exit 1; }

WORK_DIR=$(mktemp -d); trap 'rm -rf "${WORK_DIR}"' EXIT
OUT="${WORK_DIR}/flagged.jsonl"; : > "${OUT}"; SELF="$0"
printf '%s\n' "${TOKENS}" | grep -v '^$' | \
  WORK_DIR="${WORK_DIR}" SELF="${SELF}" THRESHOLD_MIN="${THRESHOLD_MIN}" MAX_DETECT_MIN="${MAX_DETECT_MIN}" \
  xargs -P "${CONCURRENCY}" -I {} bash -c '
    export WORKER_STATUS="${WORK_DIR}/status.$$.${RANDOM}.$(date +%N)"
    bash "${SELF}" --scan-one "$1" --threshold-min "${THRESHOLD_MIN}" --max-detect-min "${MAX_DETECT_MIN}" --json-only
  ' _ {} >> "${OUT}"

FLAG=$(grep -c '^{' "${OUT}" 2>/dev/null) || true
SCANNED=0; ERRORS=0; JUDGED=0
if compgen -G "${WORK_DIR}/status.*" >/dev/null 2>&1; then
  ALL=$(cat "${WORK_DIR}"/status.* 2>/dev/null || true)
  SCANNED=$(printf '%s\n' "${ALL}" | grep -c .) || true
  ERRORS=$(printf '%s\n' "${ALL}" | grep -c '^ERROR$') || true
  JUDGED=$(printf '%s\n' "${ALL}" | grep -c '^JUDGED_OK$') || true
fi
[ "${FLAG}" -gt 0 ] && { grep '^{' "${OUT}" || true; }
# in_window = jobs actually evaluated for cold-start (judged-healthy + flagged).
# The rest were skipped (too-soon / too-old / not-running / no-metric) — NOT "ok".
# Reporting in_window prevents the false-clean where "flagged:0" reads as all-healthy
# when really ~0 jobs were cold-starting to judge (operator catch 2026-06-10).
IN_WINDOW=$(( JUDGED + FLAG ))
SKIPPED=$(( SCANNED - IN_WINDOW - ERRORS ))
printf '{"summary":{"scanned":%s,"flagged":%s,"errors":%s,"in_window":%s,"skipped":%s,"threshold_min":%s,"max_detect_min":%s}}\n' \
  "${SCANNED}" "${FLAG}" "${ERRORS}" "${IN_WINDOW}" "${SKIPPED}" "${THRESHOLD_MIN}" "${MAX_DETECT_MIN}"
if [ "${FLAG}" -gt 0 ]; then
  log "ttfb: ${FLAG} RUNNING job(s) past ${THRESHOLD_MIN}m with QPS still ~0 (cold-start stall)"; exit 0
else
  log "ttfb: clean"; exit 1
fi
