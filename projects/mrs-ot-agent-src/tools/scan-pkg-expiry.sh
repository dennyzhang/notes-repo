#!/bin/bash
# scan-pkg-expiry.sh — Expiring-fbpkg detector for tracked prod OT jobs.
#
# CONSUMER-SIDE complement to ot-fbpkg-cap-watch (which is PUBLISHER-side: repo
# version-cap pressure + orphan tags). This scan catches the OTHER failure mode:
# a RUNNING OT job whose ephemeral fbpkg (app-layer or base-layer) is expiring or
# already expired. While the job holds the package it keeps running, but the next
# restart/host-move/reschedule after expiry fails the package pull → the job can't
# come back up (unresolved-package error). "Expired but still RUNNING" is the
# landmine: nothing looks broken, but it's one preempt from unrecoverable.
#
# For each tracked job (RUNNING or NOT — a stopped job is the higher expiry risk:
# it must re-pull the pkg to start and its version is no longer pinned by an
# in_use_by_model tag, so it's GC-eligible), reads app_layer_pkg + base_layer_pkg from MAST
# application_metadata, runs `fbpkg info <pkg>` and parses the version-level
# `Ephemeral:  Version expires <YYYY-MM-DD HH:MM:SS>` line. NON-ephemeral
# versions (no such line — e.g. continuously-built light_cli persistent builds)
# are SKIPPED, never flagged (verified 2026-06-08 on real fleet: sampled jobs run
# on persistent app/base pkgs with no expiry).
#
# Severity:  expired (days_left<0) or days_left<=ACT_DAYS → act-now;
#            days_left<=WATCH_DAYS → watch;  else not flagged.
#
# Usage: bash scan-pkg-expiry.sh [--act-days N] [--watch-days N] [--all]
#                                [--limit N] [--json-only] [--concurrency N]
# Exit codes:  0 = expiring/expired pkg(s) found   1 = clean   2 = usage/fetch fail
#
# Mirrors scan-zombie-fleet.sh's fan-out (xargs -P workers, --scan-one mode),
# shared enrichment/url libs, and the machine-summary contract so the digest
# renders coverage from DATA, never narration.

set -euo pipefail

# shellcheck source=lib-enrich-model.sh
source "$(dirname "$0")/lib-enrich-model.sh"
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"

ACT_DAYS=3
WATCH_DAYS=7
LIMIT=100
JSON_ONLY=false
SCAN_ALL=false
CONCURRENCY=8
SCAN_ONE=""
MODELS_FILE="$(dirname "$0")/../human-input/models.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --act-days)    ACT_DAYS="$2"; shift 2 ;;
    --watch-days)  WATCH_DAYS="$2"; shift 2 ;;
    --all)         SCAN_ALL=true; shift ;;
    --limit)       LIMIT="$2"; shift 2 ;;
    --json-only)   JSON_ONLY=true; shift ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --scan-one)    SCAN_ONE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--act-days N] [--watch-days N] [--all] [--limit N] [--json-only] [--concurrency N]"
      echo "  Default: tracked prod models from models.md. --all: all running OT jobs."
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

NOW_EPOCH=$(python3 -c "import time; print(int(time.time()))")

log() { if [ "${JSON_ONLY}" = "false" ]; then echo "$@"; fi; }

# pkg_expiry_epoch <pkg name:ver> -> echoes the expiry epoch if the version is
# EPHEMERAL (carries a `Ephemeral:  Version expires <date>` line), else nothing.
# Non-ephemeral / lookup-fail → no output, return 1 (caller treats as "no expiry").
#
# LATENCY (operator: fleet-health has a latency requirement): `fbpkg info` is the
# dominant cost and base-layer pkgs (light_cli) are shared across many jobs, so
# results are DEDUPED by pkg in a shared file cache ($CACHE_DIR, one entry per
# unique pkg). A non-ephemeral result is cached as "NONE"; a transient fbpkg-info
# FAILURE is NOT cached (so it's retried, never poisoned). Races are harmless —
# the result is deterministic, writes are atomic (tmp+mv).
pkg_expiry_epoch() {
  local pkg="$1" cf="" cached info epoch=""
  if [ -n "${CACHE_DIR:-}" ]; then
    cf="${CACHE_DIR}/$(printf '%s' "${pkg}" | tr -c 'A-Za-z0-9' '_')"
    if [ -f "${cf}" ]; then
      cached=$(cat "${cf}" 2>/dev/null)
      [ "${cached}" = "NONE" ] && return 1
      [ -n "${cached}" ] && { echo "${cached}"; return 0; }
    fi
  fi
  info=$(timeout 40 fbpkg info "${pkg}" 2>/dev/null) || return 1   # transient fail — do NOT cache
  epoch=$(printf '%s\n' "${info}" | python3 -c "
import sys, re
from datetime import datetime, timezone
# version-level ephemeral line: 'Ephemeral:   Version expires 2025-09-02 22:07:05'
m = re.search(r'Ephemeral:\s*Version expires\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', sys.stdin.read())
if m:
    print(int(datetime.strptime(m.group(1), '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc).timestamp()))
" 2>/dev/null)
  if [ -n "${cf}" ]; then
    printf '%s' "${epoch:-NONE}" > "${cf}.tmp.$$" 2>/dev/null && mv -f "${cf}.tmp.$$" "${cf}" 2>/dev/null || true
  fi
  [ -n "${epoch}" ] && { echo "${epoch}"; return 0; }
  return 1
}

# scan_job <JOB_NAME> <VERSION> : checks app + base pkg expiry for one job.
# Emits at most ONE JSON line (the SOONEST-expiring flagged pkg) + a status marker.
scan_job() {
  local JOB_NAME="$1" VERSION="$2" STATUS="${3:-UNKNOWN}"
  local RUNNING="true"; [ "${STATUS}" = "RUNNING" ] || RUNNING="false"
  local JOB_META
  JOB_META=$(timeout 15 meta ai.mast-job metadata --name="${JOB_NAME}" --version="${VERSION}" -o json 2>&1) || {
    echo "ERROR" >> "${WORKER_STATUS}"; return; }

  local PKGS
  PKGS=$(echo "${JOB_META}" | python3 -c "
import sys, json
try:
    raw = json.loads(sys.stdin.read())
    am = raw.get('application_metadata', '{}')
    am = json.loads(am) if isinstance(am, str) else am
    for kind, key in (('app','app_layer_pkg'), ('base','base_layer_pkg')):
        v = am.get(key, '')
        if v and ':' in v:
            print(f'{kind}\t{v}')
except Exception:
    pass
" 2>/dev/null)

  [ -z "${PKGS}" ] && { echo "OK" >> "${WORKER_STATUS}"; return; }

  local EID; EID="${JOB_NAME#mvai-training-online-}"
  local BEST_EPOCH="" BEST_KIND="" BEST_PKG=""
  local kind pkg exp_epoch
  while IFS=$'\t' read -r kind pkg; do
    [ -n "${pkg}" ] || continue
    exp_epoch=$(pkg_expiry_epoch "${pkg}") || continue   # skip non-ephemeral
    [ -n "${exp_epoch}" ] || continue
    if [ -z "${BEST_EPOCH}" ] || [ "${exp_epoch}" -lt "${BEST_EPOCH}" ]; then
      BEST_EPOCH="${exp_epoch}"; BEST_KIND="${kind}"; BEST_PKG="${pkg}"
    fi
  done <<< "${PKGS}"

  # No ephemeral pkg on this job → no expiry risk.
  [ -z "${BEST_EPOCH}" ] && { echo "OK" >> "${WORKER_STATUS}"; return; }

  local DAYS_LEFT SEVERITY
  DAYS_LEFT=$(( (BEST_EPOCH - NOW_EPOCH) / 86400 ))
  if [ "${DAYS_LEFT}" -gt "${WATCH_DAYS}" ]; then
    echo "OK" >> "${WORKER_STATUS}"; return   # outside watch window → healthy
  fi
  # A STOPPED job within the window is act-now regardless of days: it must re-pull
  # the pkg to start and will fail once it's expired (and its version is unpinned →
  # GC-eligible). A RUNNING job is act-now only inside ACT_DAYS, else watch.
  if [ "${RUNNING}" = "false" ] || [ "${DAYS_LEFT}" -le "${ACT_DAYS}" ]; then
    SEVERITY="act-now"
  else
    SEVERITY="watch"
  fi

  local ENRICH ENR_MODEL_TYPE ENR_PG ENR_TIER OWNER MAST_URL EXP_HUMAN
  ENRICH=$(enrich_model "${EID}")
  ENR_MODEL_TYPE="${ENRICH%%|*}"; ENRICH="${ENRICH#*|}"
  ENR_PG="${ENRICH%%|*}";         ENRICH="${ENRICH#*|}"
  ENR_TIER="${ENRICH%%|*}";       ENRICH="${ENRICH#*|}"
  OWNER="${ENRICH}"
  MAST_URL="$(mast_url "${JOB_NAME}")"
  EXP_HUMAN=$(python3 -c "from datetime import datetime,timezone; print(datetime.fromtimestamp(${BEST_EPOCH},tz=timezone.utc).strftime('%Y-%m-%d'))")

  local JSON
  JSON=$(MODEL_TYPE="${ENR_MODEL_TYPE}" PG="${ENR_PG}" MVAI_TIER="${ENR_TIER}" OWNER="${OWNER}" \
    MAST_URL="${MAST_URL}" RUNNING="${RUNNING}" STATUS="${STATUS}" python3 -c "
import os, json
print(json.dumps({
  'job_name': '${JOB_NAME}', 'version': '${VERSION}', 'model_entity_id': '${EID}',
  'mast_url': os.environ['MAST_URL'], 'owner': os.environ['OWNER'],
  'model_type': os.environ['MODEL_TYPE'], 'pg': os.environ['PG'], 'mvai_tier': os.environ['MVAI_TIER'],
  'pkg_kind': '${BEST_KIND}', 'pkg': '${BEST_PKG}', 'expires': '${EXP_HUMAN}',
  'days_left': ${DAYS_LEFT}, 'severity': '${SEVERITY}',
  'running': os.environ['RUNNING'] == 'true', 'job_status': os.environ['STATUS'],
  'scan_time': ${NOW_EPOCH}
}, separators=(',',':')))")
  echo "FLAG" >> "${WORKER_STATUS}"
  printf '%s\n' "${JSON}"
}

# resolve_job <entity_id> -> "JOB_NAME|VERSION|STATUS" for ANY job with a version
# (running OR not). Unlike zombie/age, pkg-expiry must cover non-running jobs too —
# a STOPPED job is the HIGHER expiry risk: it must re-pull the pkg to start, and its
# version is no longer pinned by an in_use_by_model tag, so it's GC-eligible. So we
# resolve every tracked job's latest version regardless of status (2026-06-08:
# operator "why pkg-expiry check 61 instead of 65" — running-only was wrong here).
resolve_job() {
  local eid="$1"
  local job_name="mvai-training-online-${eid}"
  local meta status version
  meta=$(timeout 15 meta ai.mast-job metadata --name="${job_name}" -o json 2>&1) || return 1
  status=$(echo "${meta}" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('status',''))" 2>/dev/null)
  version=$(echo "${meta}" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('version',''))" 2>/dev/null)
  [ -n "${version}" ] && { echo "${job_name}|${version}|${status:-UNKNOWN}"; return 0; }
  return 1
}

# ---- worker mode ----
if [ -n "${SCAN_ONE}" ]; then
  : "${WORKER_STATUS:?WORKER_STATUS must be set in worker mode}"
  if [[ "${SCAN_ONE}" == *"|"* ]]; then
    # --all mode token: JOB|VERSION (from the RUNNING job list) → status RUNNING
    scan_job "${SCAN_ONE%%|*}" "${SCAN_ONE#*|}" "RUNNING"
  else
    if RESOLVED=$(resolve_job "${SCAN_ONE}"); then
      IFS='|' read -r _jn _ver _st <<< "${RESOLVED}"
      scan_job "${_jn}" "${_ver}" "${_st}"
    fi
  fi
  exit 0
fi

# ---- parent mode ----
log "=== OT fbpkg-expiry Fleet Scan ==="

if [ "${SCAN_ALL}" = "true" ]; then
  JOBS_RAW=$(meta ai.mast-job list --job-name-matches-prefix "mvai-training-online-" \
    --status-is RUNNING --limit "${LIMIT}" -o json 2>&1) || { log "ERROR: list failed"; exit 2; }
  TOKEN_LIST=$(echo "${JOBS_RAW}" | python3 -c "
import sys,json
data=json.loads(sys.stdin.read()); jobs=data if isinstance(data,list) else data.get('jobs',data.get('data',[]))
for j in jobs:
    n=j.get('name',j.get('job_name','')); v=j.get('version',j.get('latest_version',''))
    if n and v: print(f'{n}|{v}')
" 2>/dev/null) || { log "ERROR: parse failed"; exit 2; }
else
  [ -f "${MODELS_FILE}" ] || { log "ERROR: models.md not found"; exit 2; }
  TOKEN_LIST=$(grep -oP 'entity_id=\K\d+' "${MODELS_FILE}" | sort -u)
fi

TOKEN_LIST=$(echo "${TOKEN_LIST}" | grep -v '^$' || true)
TOTAL=$(echo "${TOKEN_LIST}" | grep -c . || echo 0)
[ "${TOTAL}" -eq 0 ] && { log "No running OT jobs found."; exit 1; }

WORK_DIR=$(mktemp -d); trap 'rm -rf "${WORK_DIR}"' EXIT
OUT="${WORK_DIR}/flagged.jsonl"; : > "${OUT}"
CACHE_DIR="${WORK_DIR}/pkgcache"; mkdir -p "${CACHE_DIR}"  # shared fbpkg-info dedup cache (latency)
SELF="$0"

printf '%s\n' "${TOKEN_LIST}" | grep -v '^$' | \
  WORK_DIR="${WORK_DIR}" CACHE_DIR="${CACHE_DIR}" SELF="${SELF}" ACT_DAYS="${ACT_DAYS}" WATCH_DAYS="${WATCH_DAYS}" \
  xargs -P "${CONCURRENCY}" -I {} bash -c '
    export WORKER_STATUS="${WORK_DIR}/status.$$.${RANDOM}.$(date +%N)"
    bash "${SELF}" --scan-one "$1" --act-days "${ACT_DAYS}" --watch-days "${WATCH_DAYS}" --json-only
  ' _ {} >> "${OUT}"

FLAG_COUNT=$(grep -c '^{' "${OUT}" 2>/dev/null) || true
SCANNED=0; ERRORS=0
if compgen -G "${WORK_DIR}/status.*" > /dev/null 2>&1; then
  ALL_STATUS=$(cat "${WORK_DIR}"/status.* 2>/dev/null || true)
  SCANNED=$(printf '%s\n' "${ALL_STATUS}" | grep -c .) || true
  ERRORS=$(printf '%s\n' "${ALL_STATUS}" | grep -c '^ERROR$') || true
fi
ACT=$(grep '^{' "${OUT}" 2>/dev/null | grep -c '"severity":"act-now"') || true
WATCH=$(grep '^{' "${OUT}" 2>/dev/null | grep -c '"severity":"watch"') || true

[ "${FLAG_COUNT}" -gt 0 ] && { grep '^{' "${OUT}" || true; }

OK_COUNT=$(( SCANNED - FLAG_COUNT - ERRORS ))
printf '{"summary":{"scanned":%s,"flagged":%s,"act_now":%s,"watch":%s,"errors":%s,"ok":%s}}\n' \
  "${SCANNED}" "${FLAG_COUNT}" "${ACT}" "${WATCH}" "${ERRORS}" "${OK_COUNT}"

if [ "${FLAG_COUNT}" -gt 0 ]; then
  log "fbpkg-expiry: ${FLAG_COUNT} job(s) on expiring/expired pkgs (act-now=${ACT}, watch=${WATCH})"
  exit 0
else
  log "fbpkg-expiry: clean — no tracked job on an expiring ephemeral pkg."
  exit 1
fi
