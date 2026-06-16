#!/bin/bash
# scan-weekly-failures.sh — Weekly per-PG failure aggregation for tracked prod OT models.
#
# For every tracked prod OT model (from human-input/models.md), pulls the last-7d
# DEAD/FAILED job runs from Scuba `mast_hpc_job_run_status`, enriches each model
# with (model_type, pg, mvai_tier, owner) via the shared lib-enrich-model.sh, and
# aggregates DETERMINISTICALLY IN-SCRIPT (not a cron-prompt LLM step that could
# silently skip) into three views:
#   (a) crash counts per PG (THREADS / VIDEO / FEED / INSTAGRAM / unknown)
#   (b) error-pattern clusters — failure messages are normalized to a stable
#       signature (task-ids / hosts / timestamps / paths / ranks / numbers
#       stripped) and counted fleet-wide AND per PG
#   (c) top challenges per PG — the dominant failure themes (failure_type ×
#       cluster) ranked by freq × tier-weight (T1 weighted heavier than T?)
#
# This is the FLEET cherry-pick + generalization of the IG-only, crash-only
# "Check 3: Weekly Crash Aggregation" in
# claude-templates/.../ot-reliability-health-check/SKILL.md — extended to ALL
# four PGs and to error-pattern + top-challenge aggregation.
#
# Source dataset (Scuba): mast_hpc_job_run_status
#   filter:  state IN ('DEAD','FAILED'), job_name LIKE 'mvai-training-online-<EID>%'
#   columns: time, job_name, attempt_index, job_version, job_failure_type,
#            job_failure_category, source_failure_message
# NOTE the skill's spec named `error_traits_category` + `normalized_message`;
# those columns do NOT exist in the live dataset. The real categorical is
# `job_failure_type` (HPC_TASK_GROUP_APPLICATION_FAILURE, SCHEDULING_ERROR, …)
# with `job_failure_category` as a usually-null secondary; the verbose free text
# is `source_failure_message`. The script normalizes that free text in-house for
# clustering. Fallback dataset (training_platform_model_events) is NOT wired —
# the primary returns data for the tracked fleet (verified 2026-06-05); if the
# primary ever returns zero fleet-wide, the summary reports 0 honestly rather
# than silently switching sources.
#
# Efficiency: ONE Scuba query covers the whole tracked set (single LIKE-prefix
# OR), partitioned by entity_id in Python. Enrichment (the expensive per-model
# `meta` calls) runs ONLY for models that actually had a failure, in a bounded
# parallel pool (xargs -P) — never for clean models. So cost scales with the
# number of FAILING tracked models, not the full registry.
#
# Usage:
#   bash scan-weekly-failures.sh [--days N] [--json-only] [--concurrency N]
#
# Options:
#   --days N         Lookback window in days (default: 7)
#   --json-only      Emit only the single aggregate JSON object, no human summary
#   --concurrency N  Parallel enrichment workers (default: 8)
#
# Output: a SINGLE JSON object on stdout (atomic) with keys:
#   scan_time, window_days, window_start, window_end
#   coverage:   {tracked, scanned, with_failures, enrich_errors, scuba_ok}
#   per_pg:     { <PG>: {crash_count, model_count, top_failure_types[],
#                        top_clusters[], top_challenges[]} }
#   clusters_fleet: [ {signature, count, failure_types[], pgs[]} ]  (top N)
#   models:     [ {entity_id, model_type, pg, mvai_tier, owner, crash_count,
#                  failure_types{type:count}, mast_link, sample_clusters[]} ]
#
# Exit codes:
#   0 = at least one tracked model had a failure in the window
#   1 = clean (zero failures across the tracked fleet)
#   2 = usage error or Scuba fetch failure (coverage.scuba_ok=false)

set -euo pipefail

# Shared model-enrichment helper (single source of truth across all fleet-health
# scans). enrich_model <entity_id> → "model_type|pg|mvai_tier|owner".
# shellcheck source=lib-enrich-model.sh
source "$(dirname "$0")/lib-enrich-model.sh"

# Shared URL-construction helper (single source of truth for internalfb.com links).
# Build each model's MAST link via mast_url so it is resolvable-by-construction
# (carries the mvai-training-online- prefix; the bare-eid URL 404s).
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"

DAYS=7
JSON_ONLY=false
CONCURRENCY=8
SCAN_ONE=""
MODELS_FILE="$(dirname "$0")/../human-input/models.md"
SCUBA_DATASET="mast_hpc_job_run_status"
TOP_N=8   # how many clusters / challenges to keep per view

while [ $# -gt 0 ]; do
  case "$1" in
    --days)        DAYS="$2"; shift 2 ;;
    --json-only)   JSON_ONLY=true; shift ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --enrich-one)  SCAN_ONE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--days N] [--json-only] [--concurrency N]"
      echo ""
      echo "Weekly per-PG failure aggregation for tracked prod OT models."
      echo "  --days N:        lookback window in days (default 7)"
      echo "  --concurrency N: parallel enrichment workers (default 8)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

NOW_EPOCH=$(python3 -c "import time; print(int(time.time()))")
WINDOW_SECS=$((DAYS * 86400))
WINDOW_START=$((NOW_EPOCH - WINDOW_SECS))

log() { if [ "${JSON_ONLY}" = "false" ]; then echo "$@"; fi; }

# ─────────────────────────────────────────────────────────────────────────────
# Hidden enrichment-worker mode: resolve enrichment for exactly one entity_id and
# print "entity_id|model_type|pg|mvai_tier|owner" atomically. Used by the parent
# xargs pool so the expensive `meta` calls parallelize. On any failure emits the
# id with 'unknown' fields + owner '?' (never a blank line) and a status marker.
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "${SCAN_ONE}" ]; then
  : "${WORKER_STATUS:?WORKER_STATUS must be set in enrich-worker mode}"
  ENR=$(enrich_model "${SCAN_ONE}" 2>/dev/null) || ENR=""
  if [ -z "${ENR}" ]; then
    ENR="unknown|unknown|T?|?"
    echo "ERROR" >> "${WORKER_STATUS}"
  else
    echo "OK" >> "${WORKER_STATUS}"
  fi
  printf '%s|%s\n' "${SCAN_ONE}" "${ENR}"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Parent mode.
# ─────────────────────────────────────────────────────────────────────────────
NOW_HUMAN=$(python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.fromtimestamp(${NOW_EPOCH}, tz=timezone(timedelta(hours=-7))).strftime('%Y-%m-%d %H:%M:%S PDT'))")

log "=== OT Weekly Per-PG Failure Aggregation ==="
log "Time:    ${NOW_HUMAN}"
log "Window:  last ${DAYS}d"
log "Source:  Scuba ${SCUBA_DATASET} (state IN DEAD/FAILED)"
log ""
log "[1/4] Reading tracked models..."

if [ ! -f "${MODELS_FILE}" ]; then
  log "ERROR: models.md not found at ${MODELS_FILE}"
  printf '{"scan_time":%s,"coverage":{"scuba_ok":false},"error":"models.md not found"}\n' "${NOW_EPOCH}"
  exit 2
fi

# Tracked entity ids (from entity_id=NNNN links in the markdown table).
TOKEN_LIST=$(grep -oP 'entity_id=\K\d+' "${MODELS_FILE}" | sort -u | grep -v '^$' || true)
TRACKED=$(printf '%s\n' "${TOKEN_LIST}" | grep -c . || echo 0)
log "  Found ${TRACKED} tracked prod models."
log ""

if [ "${TRACKED}" -eq 0 ]; then
  log "No tracked prod models found."
  printf '{"scan_time":%s,"coverage":{"tracked":0,"scuba_ok":true},"per_pg":{},"models":[]}\n' "${NOW_EPOCH}"
  exit 1
fi

log "[2/4] Querying Scuba for last-${DAYS}d DEAD/FAILED runs (one fleet query)..."

# Build the LIKE-prefix OR over the tracked set. One query for the whole fleet.
LIKE_SQL=$(printf '%s\n' "${TOKEN_LIST}" | python3 -c "
import sys
ids = [l.strip() for l in sys.stdin if l.strip()]
clauses = [\"job_name LIKE 'mvai-training-online-%s%%'\" % i for i in ids]
print(' OR '.join(clauses))
")

SQL="SELECT time, job_name, attempt_index, job_version, job_failure_type, job_failure_category, source_failure_message FROM ${SCUBA_DATASET} WHERE time >= NOW()-${WINDOW_SECS} AND state IN ('DEAD','FAILED') AND (${LIKE_SQL}) LIMIT 50000"

SCUBA_RAW=$(timeout 240 meta scuba.dataset query -d "${SCUBA_DATASET}" --sql "${SQL}" -o json 2>&1) || {
  log "ERROR: Scuba query failed/timed out."
  log "${SCUBA_RAW}" | head -3
  ERRLINE=$(printf '%s' "${SCUBA_RAW}" | head -1 | python3 -c "import sys,json;print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '"scuba query failed"')
  printf '{"scan_time":%s,"coverage":{"tracked":%s,"scuba_ok":false},"error":%s}\n' "${NOW_EPOCH}" "${TRACKED}" "${ERRLINE}"
  exit 2
}

# Partition rows by entity_id; compute per-model crash counts + normalized
# clusters. Emit (1) the set of failing entity_ids (for enrichment) and (2) a
# pickled-as-JSON intermediate of per-model failure detail to a temp file.
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT
PARTITION_JSON="${WORK_DIR}/partition.json"
FAILING_IDS="${WORK_DIR}/failing_ids.txt"

printf '%s' "${SCUBA_RAW}" | TOKEN_LIST="${TOKEN_LIST}" PARTITION_JSON="${PARTITION_JSON}" \
  FAILING_IDS="${FAILING_IDS}" python3 -c "
import sys, os, json, re
from collections import defaultdict, Counter

tracked = set(t.strip() for t in os.environ['TOKEN_LIST'].splitlines() if t.strip())
raw = sys.stdin.read()
try:
    rows = json.loads(raw)
    if isinstance(rows, dict):
        rows = rows.get('data') or rows.get('rows') or rows.get('results') or []
except Exception:
    rows = []

# Map a full job_name back to a tracked entity_id by longest-prefix match on
# 'mvai-training-online-<EID>' (job names can carry suffixes like
# '-prime_threads_u2m_ot_smoke').
PFX = 'mvai-training-online-'
def to_eid(job_name):
    if not job_name or not job_name.startswith(PFX):
        return None
    tail = job_name[len(PFX):]
    # tracked ids are numeric; take the leading numeric run
    m = re.match(r'(\d+)', tail)
    if not m:
        return None
    eid = m.group(1)
    return eid if eid in tracked else None

# Normalize a verbose failure message to a stable cluster signature:
#  strip task ids, hosts, timestamps, ranks, hex, paths, long numbers, quotes.
def norm_sig(msg, ftype):
    if not msg:
        return (ftype or 'UNKNOWN').strip() or 'UNKNOWN'
    s = msg
    s = s.split('\n', 1)[0]                       # first line carries the gist
    s = re.sub(r'tsp_\w+/mast_hpc/\S+', '<TASK>', s)
    s = re.sub(r'mvai-training-online-\d+\S*', '<JOB>', s)
    s = re.sub(r'\b[0-9a-f]{2}(?:[0-9a-f-]{2,})\b', '<HEX>', s)
    s = re.sub(r'\b\d{4}-\d{2}-\d{2}[ _T]\d{2}:\d{2}:\d{2}\S*', '<TS>', s)
    s = re.sub(r'\b[IWE]\d{4}\b', '<LOG>', s)     # glog I0602 etc
    s = re.sub(r'\b\d{2}:\d{2}:\d{2}(?:\.\d+)?\b', '<TIME>', s)
    s = re.sub(r'(rank|local_rank|exitcode|exit code|code)\s*[:=]?\s*-?\d+', r'\1=<N>', s, flags=re.I)
    s = re.sub(r'\S+\.(net|com|fbinfra\S*)', '<HOST>', s)
    s = re.sub(r'(/[\w.\-]+){2,}', '<PATH>', s)
    s = re.sub(r\"'[^']*'\", '<Q>', s)
    s = re.sub(r'\b\d{3,}\b', '<N>', s)
    s = re.sub(r'\s+', ' ', s).strip()
    s = s[:160]
    return s or ((ftype or 'UNKNOWN').strip() or 'UNKNOWN')

per_model = defaultdict(lambda: {'crash_count': 0,
                                 'failure_types': Counter(),
                                 'clusters': Counter()})

def col(row, *names):
    for n in names:
        if n in row and row[n] is not None:
            return row[n]
    return None

for row in rows:
    if not isinstance(row, dict):
        continue
    jn = col(row, 'job_name')
    eid = to_eid(jn)
    if eid is None:
        continue
    ftype = (col(row, 'job_failure_type') or '').strip() or 'UNKNOWN'
    fcat  = (col(row, 'job_failure_category') or '')
    fcat  = fcat.strip() if isinstance(fcat, str) else ''
    msg   = col(row, 'source_failure_message') or ''
    sig   = norm_sig(msg, ftype if ftype != 'UNKNOWN' else (fcat or ftype))
    m = per_model[eid]
    m['crash_count'] += 1
    m['failure_types'][ftype] += 1
    m['clusters'][sig] += 1

# serialize (Counters -> dicts)
out = {}
for eid, d in per_model.items():
    out[eid] = {
        'crash_count': d['crash_count'],
        'failure_types': dict(d['failure_types']),
        'clusters': dict(d['clusters']),
    }
with open(os.environ['PARTITION_JSON'], 'w') as f:
    json.dump(out, f)
with open(os.environ['FAILING_IDS'], 'w') as f:
    for eid in out:
        f.write(eid + '\n')
print('PARTITION_ROWS=%d FAILING_MODELS=%d' % (len(rows), len(out)))
" 1>"${WORK_DIR}/partition_stat.txt" 2>"${WORK_DIR}/partition_err.txt" || {
  log "ERROR: failed to partition Scuba rows."
  cat "${WORK_DIR}/partition_err.txt" 1>&2 || true
  printf '{"scan_time":%s,"coverage":{"tracked":%s,"scuba_ok":false},"error":"partition failed"}\n' "${NOW_EPOCH}" "${TRACKED}"
  exit 2
}

PSTAT=$(cat "${WORK_DIR}/partition_stat.txt" 2>/dev/null || echo "")
log "  ${PSTAT}"
WITH_FAILURES=$(grep -c . "${FAILING_IDS}" 2>/dev/null || echo 0)
log ""

# No failing tracked model → clean fleet.
if [ "${WITH_FAILURES}" -eq 0 ]; then
  log "[3/4] No failures across the tracked fleet — clean week."
  printf '{"scan_time":%s,"window_days":%s,"window_start":%s,"window_end":%s,"coverage":{"tracked":%s,"scanned":%s,"with_failures":0,"enrich_errors":0,"scuba_ok":true},"per_pg":{},"clusters_fleet":[],"models":[]}\n' \
    "${NOW_EPOCH}" "${DAYS}" "${WINDOW_START}" "${NOW_EPOCH}" "${TRACKED}" "${TRACKED}"
  exit 1
fi

log "[3/4] Enriching ${WITH_FAILURES} failing models (PG/tier/owner), ${CONCURRENCY} workers..."

ENRICH_OUT="${WORK_DIR}/enrich.txt"
: > "${ENRICH_OUT}"
SELF="$0"
printf '%s\n' "$(cat "${FAILING_IDS}")" | grep -v '^$' | \
  WORK_DIR="${WORK_DIR}" SELF="${SELF}" \
  xargs -P "${CONCURRENCY}" -I {} bash -c '
    tok="$1"
    export WORKER_STATUS="${WORK_DIR}/status.$$.${RANDOM}.$(date +%N)"
    bash "${SELF}" --enrich-one "${tok}" --json-only
  ' _ {} >> "${ENRICH_OUT}"

ENRICH_ERRORS=0
if compgen -G "${WORK_DIR}/status.*" > /dev/null 2>&1; then
  ENRICH_ERRORS=$(cat "${WORK_DIR}"/status.* 2>/dev/null | grep -c '^ERROR$') || true
fi

log ""
log "[4/4] Aggregating per-PG (crash counts / clusters / top challenges)..."

# Final aggregation: join partition (per-model failure detail) with enrichment
# (per-model pg/tier/owner) and compute the three deterministic views.
# MAST links built correct-by-construction via the shared mast_url helper, one
# per tracked eid (superset of the failing eids the AGG block renders). Passed in
# as a JSON map so the python block never string-builds a URL itself (single
# source of truth = lib-url.sh). The ?env=PRODUCTION query is the weekly view's
# preference and is appended after the resolvable base.
MAST_URL_MAP=$(printf '%s\n' "${TOKEN_LIST}" | grep -v '^$' | while read -r _eid; do
  printf '%s\t%s?env=PRODUCTION\n' "${_eid}" "$(mast_url "${_eid}")"
done | python3 -c "
import sys, json
m = {}
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line: continue
    eid, url = line.split('\t', 1)
    m[eid] = url
print(json.dumps(m))
")

AGG_JSON=$(PARTITION_JSON="${PARTITION_JSON}" ENRICH_OUT="${ENRICH_OUT}" \
  NOW_EPOCH="${NOW_EPOCH}" DAYS="${DAYS}" WINDOW_START="${WINDOW_START}" \
  TRACKED="${TRACKED}" WITH_FAILURES="${WITH_FAILURES}" ENRICH_ERRORS="${ENRICH_ERRORS}" \
  TOP_N="${TOP_N}" MAST_URL_MAP="${MAST_URL_MAP}" python3 -c "
import os, json
from collections import defaultdict, Counter

with open(os.environ['PARTITION_JSON']) as f:
    part = json.load(f)

# MAST links pre-built by lib-url.sh's mast_url (single source of truth) and
# passed in as an eid→url map; the python block never string-builds a URL.
mast_url_map = json.loads(os.environ.get('MAST_URL_MAP', '{}'))

# enrichment: entity_id|model_type|pg|mvai_tier|owner
enr = {}
with open(os.environ['ENRICH_OUT']) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        bits = line.split('|')
        if len(bits) < 5:
            continue
        eid, mt, pg, tier, owner = bits[0], bits[1], bits[2], bits[3], bits[4]
        enr[eid] = {'model_type': mt, 'pg': pg, 'mvai_tier': tier, 'owner': owner}

TOP_N = int(os.environ['TOP_N'])

# tier weight for top-challenge ranking (freq × tier-weight).
def tier_w(t):
    t = (t or '').upper()
    if 'TIER_1' in t or t == 'T1' or t.endswith('_1'):
        return 3.0
    if 'TIER_2' in t or t == 'T2' or t.endswith('_2'):
        return 2.0
    if t in ('T?', '', 'UNKNOWN'):
        return 1.0
    return 1.5

per_pg = defaultdict(lambda: {
    'crash_count': 0,
    'model_count': 0,
    'failure_types': Counter(),
    'clusters': Counter(),
    'challenges': Counter(),   # (failure_type :: cluster) -> weighted score
    'challenge_freq': Counter(),
})
fleet_clusters = Counter()
fleet_cluster_ftypes = defaultdict(Counter)
fleet_cluster_pgs = defaultdict(set)

models_out = []
for eid, d in part.items():
    e = enr.get(eid, {'model_type': 'unknown', 'pg': 'unknown', 'mvai_tier': 'T?', 'owner': '?'})
    pg = e['pg'] or 'unknown'
    tier = e['mvai_tier']
    w = tier_w(tier)
    cc = d['crash_count']
    ftypes = d['failure_types']
    clusters = d['clusters']

    p = per_pg[pg]
    p['crash_count'] += cc
    p['model_count'] += 1
    for ft, n in ftypes.items():
        p['failure_types'][ft] += n
    for sig, n in clusters.items():
        p['clusters'][sig] += n
        # challenge = the (dominant failure-type, cluster) theme, scored freq×tier
        p['challenges'][sig] += n * w
        p['challenge_freq'][sig] += n
        fleet_clusters[sig] += n
        fleet_cluster_pgs[sig].add(pg)
    # attribute fleet cluster ftypes via the model's dominant ftype
    dom_ft = max(ftypes.items(), key=lambda kv: kv[1])[0] if ftypes else 'UNKNOWN'
    for sig, n in clusters.items():
        fleet_cluster_ftypes[sig][dom_ft] += n

    # MAST link (definition tab). attempt/version omitted at model level — point
    # at the job; per-attempt detail is in Scuba/the per-model failure_types.
    # Resolvable-by-construction from lib-url.sh's mast_url (carries the
    # mvai-training-online- prefix); falls back to the prefixed form if a tracked
    # eid is somehow missing from the map (never the bare-eid 404 form).
    mast_link = mast_url_map.get(eid) or (
        'https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-%s?env=PRODUCTION' % eid)
    sample_clusters = [{'signature': s, 'count': n}
                       for s, n in Counter(clusters).most_common(3)]
    models_out.append({
        'entity_id': eid,
        'model_type': e['model_type'],
        'pg': pg,
        'mvai_tier': tier,
        'owner': e['owner'],
        'crash_count': cc,
        'failure_types': dict(ftypes),
        'mast_link': mast_link,
        'sample_clusters': sample_clusters,
    })

models_out.sort(key=lambda m: m['crash_count'], reverse=True)

# ---- Reliability scorecard: push toward 100% passing (operator 2026-06-13
# "keep pushing for 100% passing rate"). Classify failure_types so GENUINE
# app-failures are not diluted by intentional kills / infra preemptions — but
# none of these are EXCUSED, they are surfaced separately so each class can be
# driven down. Headline target = CLEAN-MODEL rate (models with ZERO genuine
# app-failures in the window), the number to drive to 100%.
INTENTIONAL_FT = {'KILLED_BY_USER'}
INFRA_FT = {'PREEMPTED_BY_MAST', 'SCHEDULING_ERROR', 'KILLED_BY_MAST', 'MAST_FRONTEND'}
genuine = intentional = infra = 0
models_with_genuine = 0
for m in models_out:
    g = 0
    for ft, n in m['failure_types'].items():
        if ft in INTENTIONAL_FT:
            intentional += n
        elif ft in INFRA_FT:
            infra += n
        else:
            genuine += n
            g += n
    if g > 0:
        models_with_genuine += 1
_tracked = int(os.environ['TRACKED'])
clean_models = _tracked - models_with_genuine
reliability = {
    'genuine_failures': genuine,
    'intentional_kills': intentional,
    'infra_preempt_sched': infra,
    'models_with_genuine_failures': models_with_genuine,
    'clean_models': clean_models,
    'tracked': _tracked,
    'clean_rate_pct': round(100.0 * clean_models / _tracked, 1) if _tracked else 0.0,
}

per_pg_out = {}
for pg, p in per_pg.items():
    top_ftypes = [{'failure_type': ft, 'count': n}
                  for ft, n in p['failure_types'].most_common(TOP_N)]
    top_clusters = [{'signature': s, 'count': n}
                    for s, n in p['clusters'].most_common(TOP_N)]
    # top challenges: rank by weighted score, expose both the raw freq and score
    top_ch = []
    for s, score in p['challenges'].most_common(TOP_N):
        top_ch.append({'theme': s,
                       'freq': p['challenge_freq'][s],
                       'weighted_score': round(score, 1)})
    per_pg_out[pg] = {
        'crash_count': p['crash_count'],
        'model_count': p['model_count'],
        'top_failure_types': top_ftypes,
        'top_clusters': top_clusters,
        'top_challenges': top_ch,
    }

clusters_fleet = []
for sig, n in fleet_clusters.most_common(TOP_N):
    fts = [ft for ft, _ in fleet_cluster_ftypes[sig].most_common(3)]
    clusters_fleet.append({
        'signature': sig,
        'count': n,
        'failure_types': fts,
        'pgs': sorted(fleet_cluster_pgs[sig]),
    })

out = {
    'scan_time': int(os.environ['NOW_EPOCH']),
    'window_days': int(os.environ['DAYS']),
    'window_start': int(os.environ['WINDOW_START']),
    'window_end': int(os.environ['NOW_EPOCH']),
    'coverage': {
        'tracked': int(os.environ['TRACKED']),
        'scanned': int(os.environ['TRACKED']),
        'with_failures': int(os.environ['WITH_FAILURES']),
        'enrich_errors': int(os.environ['ENRICH_ERRORS']),
        'scuba_ok': True,
    },
    'reliability': reliability,
    'per_pg': per_pg_out,
    'clusters_fleet': clusters_fleet,
    'models': models_out,
}
print(json.dumps(out, separators=(',', ':')))
")

# Emit the single aggregate JSON object atomically.
printf '%s\n' "${AGG_JSON}"

if [ "${JSON_ONLY}" = "false" ]; then
  log ""
  log "Weekly Per-PG Failure Summary"
  log "════════════════════════════════════════════════════════════"
  printf '%s' "${AGG_JSON}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cov = d['coverage']
print('  Tracked: %d | with failures: %d | enrich errors: %d'
      % (cov['tracked'], cov['with_failures'], cov['enrich_errors']))
r = d.get('reliability')
if r:
    print('  PASSING PUSH → clean models (zero genuine app-failure): %d/%d = %.1f%% '
          '(gap to 100%%: %d models)'
          % (r['clean_models'], r['tracked'], r['clean_rate_pct'], r['models_with_genuine_failures']))
    print('  Failure split: genuine app %d | intentional kills %d | infra/preempt/sched %d'
          % (r['genuine_failures'], r['intentional_kills'], r['infra_preempt_sched']))
print('  Per-PG crash counts:')
for pg, p in sorted(d['per_pg'].items(), key=lambda kv: -kv[1]['crash_count']):
    print('    %-10s %5d crashes across %d model(s)'
          % (pg, p['crash_count'], p['model_count']))
print('  Top fleet clusters:')
for c in d['clusters_fleet'][:5]:
    print('    [%3d] %s  (%s)' % (c['count'], c['signature'][:90], ','.join(c['pgs'])))
" 2>/dev/null || true
  log "════════════════════════════════════════════════════════════"
fi

exit 0
