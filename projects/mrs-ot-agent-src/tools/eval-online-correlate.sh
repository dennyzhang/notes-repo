#!/usr/bin/env bash
# eval-online-correlate.sh — the OFFLINE↔ONLINE correlation tracker for the eval scoreboard.
#
# THE GAP THIS CLOSES (eval/README.md Hard-constraints):
#   "offline composite ≠ prod quality (until correlation matures)".
# The self-evolve loop optimizes an OFFLINE composite (eval-flow-history.jsonl). That number
# only matters if it tracks REAL production OT health. The operator named the production
# ground-truth to correlate against: TRAINING EXAMPLE AGE — the data-freshness / staleness
# signal that is the #1 trigger for OT SEVs (UJ-001 Model Freshness, CL-013). High example-age
# = stale model = the core OT failure this whole lane exists to prevent.
#
# CANONICAL PRODUCTION METRIC (the ground truth — READ-ONLY from ODS):
#   metric key : dpp_worker.scribe_example_age_ms.avg.60          (milliseconds)
#   entity     : mast.mvai-training-online-<ENTITY_ID>.<VER>.dpp_worker   (model-level ROLLUP,
#                NOT the per-worker `.<id>.csid_N` rows)
#   maps to    : KM-T1 (Training Example Age) / Q-001 (metrics/slo-recovery-metrics.md, queries.md)
#   SLO        : healthy <5min, elevated 5-30min, unhealthy >30min (KM-T1 thresholds);
#                this tool uses the same 10-min breach line as scan-scribe-age.sh.
#   Same source + query pattern as tools/scan-scribe-age.sh (single source of truth for HOW to
#   pull example age). This tool aggregates it to ONE fleet-health number per run so it can be
#   time-aligned with the offline composite.
#
# WHAT IT DOES each run:
#   1. ONLINE  — pull example age for every tracked prod model (human-input/models.md), compute a
#                fleet snapshot: models_scanned, breaching (>10min), p50 / p90 / max age (min).
#                Append one row/day to example-age-history.jsonl  → this TIME SERIES is the prod
#                ground-truth that accrues over time.
#   2. OFFLINE — read eval-flow-history.jsonl (composite + dims).
#   3. INCIDENT RECURRENCE — count freshness-related resolved SEVs/day (archive) and triaged
#                events/day (triage_events substrate).
#   4. CORRELATE — join the three series by date; if too few OVERLAPPING days exist yet, report
#                "ACCRUING — N data points, need M" and DO NOT fabricate a correlation number.
#                The value is the standing check that builds over time, not a coefficient today.
#   Writes: example-age-history.jsonl (the accruing prod series), eval-online-correlation.json,
#           and eval/reports/eval-online-correlation.md.
#
# HONESTY: with only a couple of offline points and a fresh prod series, there is NOT yet enough
# overlapping history for a real correlation. The tool says so explicitly and sets the tracker up
# so the coefficient becomes computable as both series grow. A standing measurement beats a
# fabricated number.
#
# Usage: eval-online-correlate.sh [--window-hours N] [--breach-min N] [--need-points N] [--json-only]
#   --window-hours N   ODS lookback per model for the snapshot   (default 6)
#   --breach-min N     example-age breach threshold in minutes   (default 10, matches scan-scribe-age)
#   --need-points N    overlapping days required before a coefficient is reported (default 7)
#   --concurrency N    parallel ODS workers                      (default 8)
#   --json-only        emit only the JSON line, no human summary
#
# READ-ONLY: only `meta ods.metric query` (read) + local file reads. No prod/external writes.
set -uo pipefail

WINDOW_HOURS=6
BREACH_MIN=10
NEED_POINTS=7
CONCURRENCY=8
JSON_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --window-hours) WINDOW_HOURS="$2"; shift 2;;
    --breach-min)   BREACH_MIN="$2";   shift 2;;
    --need-points)  NEED_POINTS="$2";  shift 2;;
    --concurrency)  CONCURRENCY="$2";  shift 2;;
    --json-only)    JSON_ONLY=1; shift;;
    -h|--help) sed -n '1,55p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
CTX="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context"
OUTDIR="$CTX/eval/reports"
MODELS_FILE="$HERE/../human-input/models.md"
SEV_DIR="$CTX/incidents/resolved-sevs"
DB="$HOME/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db"
HIST_AGE="$OUTDIR/example-age-history.jsonl"          # the accruing prod ground-truth series
HIST_OFFLINE="$OUTDIR/eval-flow-history.jsonl"        # offline composite series (read)

BREACH_MS=$(( BREACH_MIN * 60 * 1000 ))
NOW_EPOCH=$(date +%s)
WINDOW_START=$(( NOW_EPOCH - WINDOW_HOURS * 3600 ))
TODAY=$(python3 -c "import datetime;print(datetime.date.today().isoformat())")

# ── hidden per-model worker: one model → "EID MAX_MS" (or "EID NONE") ─────────
scan_one() {
  local EID="$1"
  local RAW
  RAW=$(timeout 60 meta ods.metric query \
    -e "regex(mast.mvai-training-online-${EID}.*.dpp_worker.*)" \
    -k 'dpp_worker.scribe_example_age_ms.avg.60' \
    --start-time "$WINDOW_START" --end-time "$NOW_EPOCH" --granularity 5m 2>/dev/null) || {
      echo "$EID ERROR"; return; }
  # MAX over the window, ROLLUP entity only (exactly <prefix>.<EID>.<VER>.dpp_worker)
  echo "$RAW" | EID="$EID" python3 -c "
import sys, os, re
eid=os.environ['EID']
pat=re.compile(r'^mast\.mvai-training-online-'+re.escape(eid)+r'\.\d+\.dpp_worker\$')
best=None
for line in sys.stdin:
    p=line.split()
    if len(p)<4: continue
    if not pat.match(p[0]): continue
    try: v=float(p[-1])
    except ValueError: continue
    if best is None or v>best: best=v
print(f'{eid} '+('NONE' if best is None else str(int(best))))
" 2>/dev/null || echo "$EID ERROR"
}
export -f scan_one
export WINDOW_START NOW_EPOCH

[ -f "$MODELS_FILE" ] || { echo "ERROR: models.md not found at $MODELS_FILE" >&2; exit 2; }
EIDS=$(grep -oP 'entity_id=\K\d+' "$MODELS_FILE" | sort -u)
TOTAL=$(echo "$EIDS" | grep -c . || true)
[ "$JSON_ONLY" = 1 ] || echo "[1/4] ONLINE: pulling example age for $TOTAL tracked models (${WINDOW_HOURS}h, ${CONCURRENCY}-way)..." >&2

# fan out the per-model ODS pulls
SCAN_OUT=$(echo "$EIDS" | xargs -P "$CONCURRENCY" -I{} bash -c 'scan_one "$@"' _ {} 2>/dev/null)

# ── aggregate the fleet snapshot + run the correlation (single python pass) ───
export SCAN_OUT
python3 - "$OUTDIR" "$TODAY" "$BREACH_MS" "$BREACH_MIN" "$NEED_POINTS" "$WINDOW_HOURS" \
         "$HIST_AGE" "$HIST_OFFLINE" "$SEV_DIR" "$DB" "$TOTAL" "$JSON_ONLY" <<'PY'
import sys, os, json, re, glob, datetime, subprocess, statistics as st
(outdir, today, breach_ms, breach_min, need_pts, win_h,
 hist_age, hist_offline, sev_dir, db, total, json_only) = sys.argv[1:]
breach_ms=int(breach_ms); breach_min=int(breach_min); need_pts=int(need_pts)
total=int(total); json_only=int(json_only)
scan=os.environ.get('SCAN_OUT','').splitlines()

# ---- 1. ONLINE fleet snapshot --------------------------------------------------
ages_min=[]; breaching=0; errors=0; nodata=0
for line in scan:
    line=line.strip()
    if not line: continue
    parts=line.split()
    if len(parts)!=2: continue
    eid,val=parts
    if val=='ERROR': errors+=1; continue
    if val=='NONE': nodata+=1; continue
    try: ms=int(val)
    except ValueError: errors+=1; continue
    ages_min.append(ms/60000.0)
    if ms>breach_ms: breaching+=1
scanned=len(ages_min)
def pct(xs,q):
    if not xs: return None
    xs=sorted(xs); k=(len(xs)-1)*q; f=int(k); c=min(f+1,len(xs)-1)
    return round(xs[f]+(xs[c]-xs[f])*(k-f),2)
snap={
  'date': today,
  'models_scanned': scanned,           # models that returned a rollup datapoint
  'models_total': total,
  'no_data': nodata, 'errors': errors,
  'breaching': breaching,              # >breach_min example age
  'breach_min': breach_min,
  'breach_rate': round(breaching/scanned,4) if scanned else None,
  'p50_age_min': pct(ages_min,0.50),
  'p90_age_min': pct(ages_min,0.90),
  'max_age_min': round(max(ages_min),2) if ages_min else None,
}

# append the accruing prod ground-truth series (idempotent per day — last run wins)
def upsert(path,row,key='date'):
    rows=[]
    if os.path.exists(path):
        for l in open(path):
            l=l.strip()
            if not l: continue
            try: d=json.loads(l)
            except json.JSONDecodeError: continue
            if d.get(key)!=row[key]: rows.append(d)
    rows.append(row)
    rows.sort(key=lambda d:d.get(key,''))
    open(path,'w').write('\n'.join(json.dumps(r) for r in rows)+'\n')
upsert(hist_age, snap)

# ---- 2. OFFLINE composite series ----------------------------------------------
off=[]
if os.path.exists(hist_offline):
    for l in open(hist_offline):
        l=l.strip()
        if not l: continue
        try: d=json.loads(l)
        except json.JSONDecodeError: continue
        # normalize date (some rows use a '2026-06-12b' suffix for re-runs) → day
        raw=str(d.get('date','')); day=raw[:10]
        if 'composite' in d and day:
            off.append({'date':day,'raw_date':raw,'composite':d['composite']})

# ---- 3. INCIDENT RECURRENCE ---------------------------------------------------
# (a) freshness-related resolved SEVs per day (archive filenames encode YYYY-MM-DD)
FRESH=re.compile(r'example.age|stale|fresh|not.*updat|expired|dpp.starv|scribe', re.I)
sev_by_day={}
for f in glob.glob(os.path.join(sev_dir,'2026-*','*.md')):
    m=re.search(r'(2026-\d{2}-\d{2})', os.path.basename(f))
    if not m: continue
    d=m.group(1)
    try: body=open(f,encoding='utf-8',errors='ignore').read()
    except OSError: continue
    fresh = 1 if FRESH.search(body) else 0
    rec=sev_by_day.setdefault(d,{'sev':0,'fresh_sev':0})
    rec['sev']+=1; rec['fresh_sev']+=fresh
# (b) triaged events per day (substrate)
tri_by_day={}
try:
    out=subprocess.run(['sqlite3','-separator','|',db,
        "SELECT date(ts_notified), COUNT(*) FROM triage_events GROUP BY 1;"],
        capture_output=True,text=True,timeout=20).stdout
    for l in out.splitlines():
        if '|' in l:
            d,c=l.split('|',1)
            if d.strip(): tri_by_day[d.strip()]=int(c)
except Exception:
    pass

# ---- 4. CORRELATE -------------------------------------------------------------
# Join offline-composite days with the prod example-age series (the accruing one).
age_by_day={}
for l in open(hist_age):
    l=l.strip()
    if not l: continue
    try: d=json.loads(l)
    except json.JSONDecodeError: continue
    age_by_day[d['date']]=d
off_by_day={o['date']:o['composite'] for o in off}
joined=[]
for day in sorted(set(age_by_day)&set(off_by_day)):
    a=age_by_day[day]
    joined.append({'date':day,'composite':off_by_day[day],
                   'breach_rate':a.get('breach_rate'),'p90_age_min':a.get('p90_age_min'),
                   'fresh_sev':sev_by_day.get(day,{}).get('fresh_sev'),
                   'triaged':tri_by_day.get(day)})

def pearson(xs,ys):
    pairs=[(x,y) for x,y in zip(xs,ys) if x is not None and y is not None]
    if len(pairs)<3: return None
    xs=[p[0] for p in pairs]; ys=[p[1] for p in pairs]
    try:
        if st.pstdev(xs)==0 or st.pstdev(ys)==0: return None
        return round(st.correlation(xs,ys),3)
    except Exception:
        return None

n_join=len(joined)
# hypothesis: better offline composite should track LOWER prod example-age breach/p90
# → expect NEGATIVE correlation(composite, breach_rate) and (composite, p90_age_min)
corr_breach=pearson([j['composite'] for j in joined],[j['breach_rate'] for j in joined])
corr_p90   =pearson([j['composite'] for j in joined],[j['p90_age_min'] for j in joined])
corr_fresh =pearson([j['composite'] for j in joined],[j['fresh_sev'] for j in joined])
accruing = n_join < need_pts or corr_breach is None
status = (f'ACCRUING — {n_join} overlapping day(s), need {need_pts}'
          if accruing else
          'COMPUTED')

result={
  'date':today,'status':status,'accruing':accruing,
  'overlapping_days':n_join,'need_points':need_pts,
  'online_snapshot':snap,
  'offline_points':len(off),'incident_days':len(sev_by_day),
  'correlation':{
     'composite_vs_breach_rate':corr_breach,   # expect <0 (good offline → fewer breaches)
     'composite_vs_p90_age_min':corr_p90,       # expect <0
     'composite_vs_fresh_sev':corr_fresh,       # expect <0
  },
  'joined':joined,
}
json.dump(result, open(f'{outdir}/eval-online-correlation.json','w'), indent=1)

# ---- report .md ---------------------------------------------------------------
L=[]
L.append(f'# Offline↔Online Eval Correlation — training-example-age ground truth ({today})')
L.append('')
L.append('_Generated by `tools/eval-online-correlate.sh`. Closes the eval Hard-constraint '
         '"offline composite ≠ prod quality (until correlation matures)" by tracking the offline '
         'eval composite against the production ground-truth the operator named: **training example age** '
         '(`dpp_worker.scribe_example_age_ms.avg.60`, KM-T1 / Q-001) — high example-age = stale model = '
         'the core OT failure this lane prevents._')
L.append('')
L.append(f'## Status: **{status}**')
L.append('')
if accruing:
    L.append(f'> Not enough OVERLAPPING history yet to report a real correlation. The offline composite '
             f'series has **{len(off)}** point(s); the prod example-age series gains **1 point per run** '
             f'(this run added today). A coefficient is reported once **≥{need_pts}** days overlap. '
             f'This is the standing check that builds the correlation over time — the value is the tracker, '
             f'not a number today.')
    L.append('')
L.append('## 1. Production ground truth — fleet example-age snapshot (this run)')
L.append('')
L.append(f'| Metric | Value |')
L.append(f'|---|---|')
L.append(f'| models with data / total tracked | {snap["models_scanned"]} / {snap["models_total"]} |')
L.append(f'| breaching >{breach_min}min (stale) | {snap["breaching"]} ({"" if snap["breach_rate"] is None else f"{snap["breach_rate"]:.1%}"}) |')
L.append(f'| p50 example age | {snap["p50_age_min"]} min |')
L.append(f'| p90 example age | {snap["p90_age_min"]} min |')
L.append(f'| max example age | {snap["max_age_min"]} min |')
L.append(f'| no-data / errors | {snap["no_data"]} / {snap["errors"]} |')
L.append('')
L.append(f'Appended to `example-age-history.jsonl` (the accruing prod series).')
L.append('')
L.append('## 2. Offline composite series (read from `eval-flow-history.jsonl`)')
L.append('')
if off:
    L.append('| date | composite |')
    L.append('|---|---|')
    for o in off[-10:]:
        L.append(f'| {o["raw_date"]} | {o["composite"]} |')
else:
    L.append('_no offline composite history found_')
L.append('')
L.append('## 3. Correlation (offline composite vs prod ground truth)')
L.append('')
L.append(f'Overlapping days: **{n_join}** (need ≥{need_pts}). Hypothesis: a better offline composite '
         f'should track a HEALTHIER fleet → **negative** correlation with breach-rate / p90-age / freshness-SEVs.')
L.append('')
L.append('| pair | Pearson r | enough data? |')
L.append('|---|---|---|')
L.append(f'| composite ↔ example-age breach-rate | {("n/a" if corr_breach is None else corr_breach)} | {"yes" if corr_breach is not None else "no"} |')
L.append(f'| composite ↔ p90 example age | {("n/a" if corr_p90 is None else corr_p90)} | {"yes" if corr_p90 is not None else "no"} |')
L.append(f'| composite ↔ freshness-SEVs/day | {("n/a" if corr_fresh is None else corr_fresh)} | {"yes" if corr_fresh is not None else "no"} |')
L.append('')
if joined:
    L.append('### Overlapping rows')
    L.append('| date | composite | breach_rate | p90_age_min | fresh_sev | triaged |')
    L.append('|---|---|---|---|---|---|')
    for j in joined:
        L.append(f'| {j["date"]} | {j["composite"]} | {j["breach_rate"]} | {j["p90_age_min"]} | {j["fresh_sev"]} | {j["triaged"]} |')
    L.append('')
L.append('## 4. How to read this once it matures')
L.append('')
L.append('- **r ≤ −0.4 (breach-rate / p90):** offline gains DO track real prod freshness — the eval is '
         'a trustworthy optimization target; keep evolving against composite.')
L.append('- **r near 0 / positive:** offline composite is decoupled from prod freshness — the eval is '
         'overfitting the gold set; HALT mutation-by-composite and re-anchor the gold set on freshness cases.')
L.append('- This is exactly the "what would trigger a halt" check in `online-signal-2026-06-11.md` §5, made '
         'continuous and quantitative against the operator-named ground-truth metric.')
L.append('')
L.append(f'_Window: {win_h}h ODS lookback · breach line: {breach_min} min (KM-T1 / scan-scribe-age parity) · '
         f'metric: `dpp_worker.scribe_example_age_ms.avg.60` rollup entity._')
open(f'{outdir}/eval-online-correlation.md','w').write('\n'.join(L)+'\n')

if not json_only:
    print(f'ONLINE snapshot: {snap["models_scanned"]}/{snap["models_total"]} models, '
          f'{snap["breaching"]} breaching >{breach_min}min, p90={snap["p90_age_min"]}min')
    print(f'CORRELATION: {status} (overlapping={n_join}, offline_pts={len(off)})')
    if not accruing:
        print(f'  composite↔breach_rate r={corr_breach}  composite↔p90 r={corr_p90}')
    print('wrote eval-online-correlation.md + .json + appended example-age-history.jsonl')
PY
