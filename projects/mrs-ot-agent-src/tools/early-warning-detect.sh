#!/usr/bin/env bash
# early-warning-detect.sh — REPORT-ONLY "metric-trend-toward-threshold" early-warning detector.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT THIS IS (and is NOT)
# ─────────────────────────────────────────────────────────────────────────────
# This is the PREDICTIVE SUBSTRATE for Problem #3 ("signal before first page").
# Its job RIGHT NOW is to ACCRUE precision + lead-time data so that a proactive
# paging gate can LATER be calibrated at a bounded false-alarm rate.
#
#   IT NEVER PAGES. IT NEVER ESCALATES. IT NEVER MUTATES ANY EXTERNAL STATE.
#   It only (a) records "approaching" candidates and (b) reconciles past
#   candidates against actual outcomes to grow a precision/lead-time dataset.
#
# The page itself is a GATED boundary expansion = the operator's switch, enabled
# LATER from the accrued numbers (see eval/early-warning-loop-proposal.md). On
# ACTION this tool is READ-ONLY: only `meta ods.metric query` (read) + writes to
# its own report files under eval/reports/.
#
# ─────────────────────────────────────────────────────────────────────────────
# PRIMARY METRIC — training example age (KM-T1)
# ─────────────────────────────────────────────────────────────────────────────
#   metric key : dpp_worker.scribe_example_age_ms.avg.60          (milliseconds)
#   entity     : mast.mvai-training-online-<ENTITY_ID>.<VER>.dpp_worker  (model-level
#                ROLLUP — NOT the per-worker `.<id>.csid_N` rows)
#   bands (KM-T1): healthy <5min · elevated 5-30min · unhealthy/SEV >30min
#
# REUSE: this is the EXACT same source+query pattern as tools/scan-scribe-age.sh
# and tools/eval-online-correlate.sh (single source of truth for HOW to pull
# example age). The ONLY difference here: those take the MAX over the window for a
# breach check; we keep the full TIME SERIES so we can fit a trend (slope) and
# estimate a lead-time-to-breach BEFORE the 30-min line is crossed.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT IT DOES each run
# ─────────────────────────────────────────────────────────────────────────────
#   1. PULL example-age time series per tracked OT model (human-input/models.md)
#      over a recent window (default 4h, 5m granularity).
#   2. For each model compute: current age (latest point), trend slope
#      (min-of-age per hour, OLS over the recent window), distance to the 30-min
#      unhealthy line. FLAG **APPROACHING** when the model is in the *elevated*
#      band (5-30min) AND *rising toward* 30min (positive slope above a small
#      floor), with an estimated lead-time-to-breach = (30 - current)/slope.
#   3. APPEND each APPROACHING event to early-warning-history.jsonl
#      (idempotent per (model, day) — re-run same day overwrites that model's row).
#   4. OUTCOME RECONCILIATION (the precision engine): for PAST approaching-events
#      whose lead window has elapsed, check whether the model LATER actually
#      breached >30min (TRUE-POSITIVE) or recovered (RECOVERED = candidate
#      false-alarm), using the per-model history this tool itself records plus the
#      fleet example-age-history.jsonl. Compute running precision + median
#      lead-time — but print "ACCRUING — N events, need ~M" when there isn't
#      enough yet (there won't be on day 1).
#   5. WRITE eval/reports/early-warning.md (currently-approaching models + the
#      accruing precision/lead-time stats + a REPORT-ONLY header).
#
# Usage:
#   early-warning-detect.sh [--window-hours N] [--granularity 5m]
#                           [--elevated-min N] [--unhealthy-min N]
#                           [--min-slope N] [--need-events N]
#                           [--concurrency N] [--json-only]
#     --window-hours N   ODS lookback per model for the trend fit   (default 4)
#     --granularity G    ODS bucket granularity                     (default 5m)
#     --elevated-min N   lower edge of the elevated band, minutes    (default 5)
#     --unhealthy-min N  the unhealthy/SEV threshold, minutes        (default 30)
#     --min-slope N      min rising slope (min-age per hour) to flag (default 1.0)
#     --need-events N    reconciled events needed before precision   (default 20)
#                        is reported as a number rather than ACCRUING
#     --concurrency N    parallel ODS workers                        (default 8)
#     --json-only        emit only the summary JSON line, no human text
set -uo pipefail

WINDOW_HOURS=4
GRANULARITY=5m
ELEVATED_MIN=5
UNHEALTHY_MIN=30
MIN_SLOPE=1.0
NEED_EVENTS=20
CONCURRENCY=8
JSON_ONLY=0
SCAN_ONE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --window-hours) WINDOW_HOURS="$2"; shift 2;;
    --granularity)  GRANULARITY="$2";  shift 2;;
    --elevated-min) ELEVATED_MIN="$2"; shift 2;;
    --unhealthy-min)UNHEALTHY_MIN="$2";shift 2;;
    --min-slope)    MIN_SLOPE="$2";    shift 2;;
    --need-events)  NEED_EVENTS="$2";  shift 2;;
    --concurrency)  CONCURRENCY="$2";  shift 2;;
    --json-only)    JSON_ONLY=1; shift;;
    --scan-one)     SCAN_ONE="$2"; shift 2;;   # hidden worker mode
    -h|--help) sed -n '1,75p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
CTX="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context"
OUTDIR="$CTX/eval/reports"
MODELS_FILE="$HERE/../human-input/models.md"
HIST_EW="$OUTDIR/early-warning-history.jsonl"       # accruing approaching-event series (this tool)
HIST_AGE="$OUTDIR/example-age-history.jsonl"        # fleet snapshot series (eval-online-correlate.sh)
HIST_OBS="$OUTDIR/early-warning-observations.jsonl" # per-model age trace (ground truth for reconciliation)
OBS_RETAIN_DAYS=14                                  # ring-buffer retention for the obs trace

NOW_EPOCH=$(date +%s)
WINDOW_START=$(( NOW_EPOCH - WINDOW_HOURS * 3600 ))
TODAY=$(python3 -c "import datetime;print(datetime.date.today().isoformat())")

# ── hidden per-model worker ──────────────────────────────────────────────────
# Pulls the example-age time series for one model and reduces it (in python, same
# rollup-entity regex as scan-scribe-age.sh) to a single compact line:
#   "<EID> <json>"  where json = {ts:[...],vals_min:[...]} (chronological) OR
#   "<EID> NONE"    (no rollup datapoints) OR "<EID> ERROR" (query failed).
scan_one() {
  local EID="$1"
  local RAW
  RAW=$(timeout 60 meta ods.metric query \
    -e "regex(mast.mvai-training-online-${EID}.*.dpp_worker.*)" \
    -k 'dpp_worker.scribe_example_age_ms.avg.60' \
    --start-time "$WINDOW_START" --end-time "$NOW_EPOCH" --granularity "$GRANULARITY" 2>/dev/null) || {
      echo "$EID ERROR"; return; }
  echo "$RAW" | EID="$EID" python3 -c "
import sys, os, re, json
eid=os.environ['EID']
# model-level ROLLUP entity only: <prefix>.<EID>.<VER>.dpp_worker (3 dot-segments,
# no per-worker .<id>.csid_N suffix). Identical gate to scan-scribe-age.sh.
pat=re.compile(r'^mast\.mvai-training-online-'+re.escape(eid)+r'\.\d+\.dpp_worker\$')
# ODS line shape: '<entity> <metric_key> <ts> <value>' (ts in epoch seconds).
# We keep (ts, value_ms) for rollup rows, merge across versions by ts (max), and
# emit a chronological series in minutes.
by_ts={}
for line in sys.stdin:
    p=line.split()
    if len(p)<4: continue
    if not pat.match(p[0]): continue
    try:
        ts=int(float(p[-2])); v=float(p[-1])
    except (ValueError, IndexError):
        continue
    # keep the max age at each timestamp if multiple version rows coincide
    if ts not in by_ts or v>by_ts[ts]:
        by_ts[ts]=v
if not by_ts:
    print(f'{eid} NONE'); raise SystemExit
ts_sorted=sorted(by_ts)
out={'ts':ts_sorted,'vals_min':[round(by_ts[t]/60000.0,3) for t in ts_sorted]}
print(f'{eid} '+json.dumps(out,separators=(',',':')))
" 2>/dev/null || echo "$EID ERROR"
}
export -f scan_one
export WINDOW_START NOW_EPOCH GRANULARITY

# hidden worker entrypoint
if [ -n "$SCAN_ONE" ]; then
  scan_one "$SCAN_ONE"
  exit 0
fi

[ -f "$MODELS_FILE" ] || { echo "ERROR: models.md not found at $MODELS_FILE" >&2; exit 2; }
EIDS=$(grep -oP 'entity_id=\K\d+' "$MODELS_FILE" | sort -u)
TOTAL=$(echo "$EIDS" | grep -c . || true)
[ "$JSON_ONLY" = 1 ] || echo "[1/4] PULL: example-age trend for $TOTAL tracked models (${WINDOW_HOURS}h @ ${GRANULARITY}, ${CONCURRENCY}-way)..." >&2

# fan out the per-model ODS pulls (each worker re-invokes this script in --scan-one)
SELF="$0"
SCAN_OUT=$(echo "$EIDS" | SELF="$SELF" WINDOW_HOURS="$WINDOW_HOURS" GRANULARITY="$GRANULARITY" \
  xargs -P "$CONCURRENCY" -I{} bash -c 'bash "$SELF" --scan-one "$1" --window-hours "'"$WINDOW_HOURS"'" --granularity "'"$GRANULARITY"'"' _ {} 2>/dev/null)

# ── detect + reconcile + report (single python pass) ─────────────────────────
export SCAN_OUT
python3 - "$OUTDIR" "$TODAY" "$NOW_EPOCH" "$ELEVATED_MIN" "$UNHEALTHY_MIN" "$MIN_SLOPE" \
         "$NEED_EVENTS" "$WINDOW_HOURS" "$GRANULARITY" "$HIST_EW" "$HIST_AGE" "$HIST_OBS" \
         "$OBS_RETAIN_DAYS" "$TOTAL" "$JSON_ONLY" <<'PY'
import sys, os, json, statistics as st
(outdir, today, now_epoch, elevated_min, unhealthy_min, min_slope,
 need_events, win_h, granularity, hist_ew, hist_age, hist_obs, obs_retain_days,
 total, json_only) = sys.argv[1:]
obs_retain_days=int(obs_retain_days)
now_epoch=int(now_epoch); elevated_min=float(elevated_min); unhealthy_min=float(unhealthy_min)
min_slope=float(min_slope); need_events=int(need_events); total=int(total); json_only=int(json_only)
scan=os.environ.get('SCAN_OUT','').splitlines()

# ── 1+2. parse series, fit slope, flag APPROACHING ──────────────────────────
def ols_slope_per_hr(ts, vals):
    """OLS slope of value(min) vs time, returned per HOUR. None if <3 points or
    degenerate. ts in epoch seconds."""
    n=len(ts)
    if n<3: return None
    # x in hours relative to first point (keeps numbers small + interpretable)
    x=[(t-ts[0])/3600.0 for t in ts]
    y=list(vals)
    mx=sum(x)/n; my=sum(y)/n
    sxx=sum((xi-mx)**2 for xi in x)
    if sxx==0: return None
    sxy=sum((xi-mx)*(yi-my) for xi,yi in zip(x,y))
    return sxy/sxx   # minutes-of-age gained per hour

approaching=[]      # this run's flagged events
this_run_obs=[]     # per-model (model, ts, max_age_min) for EVERY scanned model this
                    # run — the ground-truth trace reconciliation reads to settle past
                    # events. Recorded for ALL bands (incl. already-unhealthy), because
                    # a later breach is exactly the outcome we must observe; counting an
                    # unhealthy model and dropping it would hide the TRUE_POSITIVE.
scanned=0; nodata=0; errors=0
healthy=0; elevated_stable=0; already_unhealthy=0
for line in scan:
    line=line.strip()
    if not line: continue
    sp=line.split(' ',1)
    if len(sp)!=2: continue
    eid, payload = sp
    if payload=='ERROR': errors+=1; continue
    if payload=='NONE':  nodata+=1; continue
    try:
        d=json.loads(payload)
    except json.JSONDecodeError:
        errors+=1; continue
    ts=d.get('ts',[]); vals=d.get('vals_min',[])
    if not vals: nodata+=1; continue
    scanned+=1
    cur=vals[-1]
    slope=ols_slope_per_hr(ts, vals)   # min-age per hour
    # record the post-event ground-truth observation: use the MAX age over this
    # model's window (most conservative — a single >30min bucket counts as a breach,
    # parity with scan-scribe-age.sh), stamped at now so reconciliation sees it.
    this_run_obs.append({'model_entity_id':eid,'ts':now_epoch,
                         'age_min':round(max(vals),3)})
    # band classification on the CURRENT value
    if cur < elevated_min:
        healthy+=1; continue
    if cur >= unhealthy_min:
        already_unhealthy+=1; continue   # past the line — not a *pre*-breach signal
    # in the elevated band (elevated_min <= cur < unhealthy_min)
    if slope is None or slope < min_slope:
        elevated_stable+=1; continue     # elevated but not rising → not approaching
    # rising toward 30min → APPROACHING. estimate lead-time to breach.
    est_lead_min = (unhealthy_min - cur) / slope * 60.0  # (min gap)/(min per hr)*60 = minutes
    est_lead_min = round(est_lead_min, 1)
    approaching.append({
        'date': today,
        'model_entity_id': eid,
        'ts': now_epoch,
        'age_min': round(cur,2),
        'slope_min_per_hr': round(slope,2),
        'dist_to_unhealthy_min': round(unhealthy_min-cur,2),
        'est_lead_min': est_lead_min,
        'unhealthy_threshold_min': unhealthy_min,
        'elevated_threshold_min': elevated_min,
        # outcome reconciliation fields — filled in later runs
        'outcome': None,           # TRUE_POSITIVE | RECOVERED | PENDING
        'reconciled_at': None,
        'observed_breach_min': None,
    })

# ── 3. append to early-warning-history.jsonl, idempotent per (model, date) ────
def load_jsonl(path):
    rows=[]
    if os.path.exists(path):
        for l in open(path):
            l=l.strip()
            if not l: continue
            try: rows.append(json.loads(l))
            except json.JSONDecodeError: pass
    return rows

ew_rows = load_jsonl(hist_ew)
# index existing rows by (model, date); preserve any already-reconciled outcome so
# a same-day re-run does not wipe a verdict written by an earlier run.
existing={}
for r in ew_rows:
    existing[(r.get('model_entity_id'), r.get('date'))]=r
for ev in approaching:
    key=(ev['model_entity_id'], ev['date'])
    prev=existing.get(key)
    if prev and prev.get('outcome') in ('TRUE_POSITIVE','RECOVERED'):
        # keep the settled verdict; just refresh the live trend fields
        prev.update({k:ev[k] for k in
                     ('age_min','slope_min_per_hr','dist_to_unhealthy_min','est_lead_min','ts')})
    else:
        existing[key]=ev
ew_rows=list(existing.values())

# ── 3b. append this run's per-model age observations to the obs ring ──────────
# This is the per-model ground-truth trace reconciliation reads. Without it, a
# model that has already gone unhealthy is counted-and-dropped, so the breach that
# settles a past approaching-event as TRUE_POSITIVE would never be seen.
obs_rows=load_jsonl(hist_obs)
obs_rows.extend(this_run_obs)
# ring-buffer: drop observations older than the retention window (bounds file size)
cutoff = now_epoch - obs_retain_days*86400
obs_rows=[o for o in obs_rows if (o.get('ts') or 0) >= cutoff]
obs_rows.sort(key=lambda o:(o.get('ts',0), str(o.get('model_entity_id',''))))
with open(hist_obs,'w') as f:
    for o in obs_rows:
        f.write(json.dumps(o, separators=(',',':'))+'\n')

# ── 4. OUTCOME RECONCILIATION ────────────────────────────────────────────────
# For each PAST approaching-event whose lead window has fully elapsed and is not
# yet settled, decide TRUE_POSITIVE vs RECOVERED using the per-model trace we
# have recorded since (this tool's own rows) PLUS the fleet snapshot series
# (example-age-history.jsonl: per-day max_age_min / p90 / breach counts give a
# coarse corroboration that *some* model breached, but is not per-model). Because
# per-model post-event traces are sparse on day 1, the honest default for an
# elapsed-but-unobserved event is PENDING — we do NOT guess a verdict we cannot
# see. precision is only over SETTLED events.
#
# Reconciliation rule (per-model, ground-truth from this tool's own later rows):
#   For event E (model m, ts t0, est_lead L): look at THIS tool's later rows for
#   model m with ts in (t0, t0 + max(L, min_observe)+grace]. If any later row for
#   m shows age_min >= unhealthy_min → TRUE_POSITIVE (observed_breach=that age).
#   Else if we HAVE at least one later observation for m in-window and none
#   breached → RECOVERED. Else → PENDING (no post-event observation yet).
GRACE_MIN=60.0          # allow breach slightly past the estimated lead
MIN_OBSERVE_MIN=30.0    # always give at least this long to observe an outcome
age_min_thr=unhealthy_min

# per-model chronological observations (age over time) from the obs ring — this
# covers EVERY scanned model in every band, so a post-event breach of a model that
# went unhealthy is visible to reconciliation (the obs ring is the ground truth).
obs_by_model={}
for o in obs_rows:
    m=o.get('model_entity_id'); t=o.get('ts'); a=o.get('age_min')
    if m is None or t is None or a is None: continue
    obs_by_model.setdefault(m,[]).append((t,a))
for m in obs_by_model: obs_by_model[m].sort()

settled=0; tp=0; recovered=0; pending=0
lead_times_tp=[]
for r in ew_rows:
    if r.get('outcome') in ('TRUE_POSITIVE','RECOVERED'):
        settled+=1
        if r['outcome']=='TRUE_POSITIVE':
            tp+=1
            if r.get('est_lead_min') is not None: lead_times_tp.append(r['est_lead_min'])
        else:
            recovered+=1
        continue
    t0=r.get('ts'); L=r.get('est_lead_min') or 0.0; m=r.get('model_entity_id')
    if t0 is None: pending+=1; continue
    window_end = t0 + (max(L, MIN_OBSERVE_MIN)+GRACE_MIN)*60.0
    # A breach observed ANY time after the event (even past the predicted window) is
    # still a true positive — the prediction was directionally right, just late. So
    # search the full post-event span (t0, now] for a breach FIRST.
    later=[(t,a) for (t,a) in obs_by_model.get(m,[]) if t > t0]
    breach_obs=[a for (t,a) in later if a>=age_min_thr]
    if not breach_obs and now_epoch < window_end:
        # no breach yet AND not enough time elapsed to call it recovered → wait.
        r['outcome']='PENDING'; pending+=1; continue
    if not breach_obs and not later:
        # window elapsed but we recorded nothing about m after the event → cannot
        # claim either way (honest PENDING, not a guessed RECOVERED).
        r['outcome']='PENDING'; pending+=1; continue
    if breach_obs:
        r['outcome']='TRUE_POSITIVE'; r['observed_breach_min']=round(max(breach_obs),2)
        r['reconciled_at']=now_epoch
        settled+=1; tp+=1
        if r.get('est_lead_min') is not None: lead_times_tp.append(r['est_lead_min'])
    else:
        r['outcome']='RECOVERED'; r['reconciled_at']=now_epoch
        settled+=1; recovered+=1

# persist (sorted by date then model for stable diffs)
ew_rows.sort(key=lambda r:(r.get('date',''), str(r.get('model_entity_id',''))))
with open(hist_ew,'w') as f:
    for r in ew_rows:
        f.write(json.dumps(r, separators=(',',':'))+'\n')

# precision / median lead — honest ACCRUING when too few settled
precision = round(tp/settled,3) if settled else None
median_lead = round(st.median(lead_times_tp),1) if lead_times_tp else None
accruing = settled < need_events
prec_status = (f'ACCRUING — {settled} settled event(s), need ~{need_events} before precision is trustworthy'
               if accruing else 'COMPUTED')

summary={
  'date':today,'now':now_epoch,
  'models_scanned':scanned,'models_total':total,'no_data':nodata,'errors':errors,
  'band_counts':{'healthy':healthy,'elevated_stable':elevated_stable,
                 'approaching':len(approaching),'already_unhealthy':already_unhealthy},
  'approaching_now':len(approaching),
  'reconciliation':{'settled':settled,'true_positive':tp,'recovered':recovered,'pending':pending,
                    'precision':precision,'median_lead_min':median_lead,
                    'status':prec_status,'need_events':need_events},
  'thresholds':{'elevated_min':elevated_min,'unhealthy_min':unhealthy_min,
                'min_slope_min_per_hr':min_slope},
}

# ── 5. write early-warning.md ────────────────────────────────────────────────
L=[]
L.append(f'# OT Early-Warning — example-age trend-toward-threshold ({today})')
L.append('')
L.append('> **REPORT-ONLY. This detector NEVER pages, escalates, or mutates any external state.** '
         'It exists to ACCRUE precision + lead-time data so a *future* gated proactive-paging loop '
         '(Problem #3 — "signal before first page") can be calibrated at a bounded false-alarm rate. '
         'Enabling the page is a deliberate boundary expansion = **the operator\'s switch** '
         '(see `eval/early-warning-loop-proposal.md`). Until then this file is the entire deliverable.')
L.append('')
L.append(f'_Metric: `dpp_worker.scribe_example_age_ms.avg.60` (KM-T1 training example age), model-level '
         f'rollup entity. Same source+query as `scan-scribe-age.sh` / `eval-online-correlate.sh`; this '
         f'tool keeps the full {win_h}h @ {granularity} series to fit a trend. Bands: healthy <{int(elevated_min)}min · '
         f'elevated {int(elevated_min)}-{int(unhealthy_min)}min · unhealthy/SEV >{int(unhealthy_min)}min._')
L.append('')
# fleet scan line
L.append(f'**Fleet this run:** {scanned}/{total} models with data · '
         f'healthy {healthy} · elevated-stable {elevated_stable} · '
         f'**approaching {len(approaching)}** · already-unhealthy {already_unhealthy} · '
         f'no-data {nodata} · errors {errors}.')
L.append('')

L.append('## Currently APPROACHING (elevated + rising toward 30min)')
L.append('')
if approaching:
    L.append('| model_entity_id | age (min) | slope (min/hr) | gap to 30min | est. lead (min) |')
    L.append('|---|---|---|---|---|')
    for ev in sorted(approaching, key=lambda e:e['est_lead_min']):
        L.append(f'| {ev["model_entity_id"]} | {ev["age_min"]} | {ev["slope_min_per_hr"]} | '
                 f'{ev["dist_to_unhealthy_min"]} | **{ev["est_lead_min"]}** |')
    L.append('')
    L.append('_Sorted by soonest estimated breach. These are CANDIDATES being recorded for precision '
             'accrual — no action is taken._')
else:
    L.append('_None this run — no model is both in the elevated band AND rising toward the 30-min line._')
L.append('')

L.append('## Precision engine (outcome reconciliation)')
L.append('')
L.append(f'**Status: {prec_status}**')
L.append('')
L.append('| metric | value |')
L.append('|---|---|')
L.append(f'| settled events (TP + recovered) | {settled} |')
L.append(f'| true positives (later breached >30min) | {tp} |')
L.append(f'| recovered (candidate false-alarm) | {recovered} |')
L.append(f'| pending (lead window not elapsed / unobserved) | {pending} |')
L.append(f'| **precision** = TP / settled | {"accruing" if precision is None else precision} |')
L.append(f'| **median lead-time** (TP events) | {"accruing" if median_lead is None else str(median_lead)+" min"} |')
L.append('')
if accruing:
    L.append(f'> Not enough SETTLED events yet to trust a precision number. The detector records '
             f'~1 candidate-set per run and settles each only after its lead window elapses, so the '
             f'dataset grows over days/weeks. A precision figure is reported once **≥{need_events}** '
             f'events have settled. **Calibrating the paging gate needs this number** — until then the '
             f'gate stays OFF. This is the standing measurement that unblocks Problem #3, not a number today.')
    L.append('')
L.append('## How this feeds the future paging gate')
L.append('')
L.append(f'1. This detector accrues `(approaching-event → actual-outcome)` pairs into '
         f'`early-warning-history.jsonl`.')
L.append(f'2. Once **≥{need_events}** events settle, precision + median-lead become trustworthy.')
L.append(f'3. The operator picks a precision floor (bounded false-alarm rate) and flips the gate ON — '
         f'at that point, and only then, an approaching-event with sufficient confidence may page. '
         f'That switch is the operator\'s, not this tool\'s.')
L.append('')
L.append(f'_Window: {win_h}h @ {granularity} ODS · slope = OLS min-age/hour · min-slope-to-flag '
         f'{min_slope} min/hr · {settled}/{need_events} events settled toward calibration._')

with open(f'{outdir}/early-warning.md','w') as f:
    f.write('\n'.join(L)+'\n')

# always emit the machine summary on stdout (last line)
print(json.dumps({'early_warning':summary}, separators=(',',':')))

if not json_only:
    sys.stderr.write(
        f'APPROACHING now: {len(approaching)} model(s) '
        f'(scanned {scanned}/{total}, elevated-stable {elevated_stable}, unhealthy {already_unhealthy})\n')
    sys.stderr.write(
        f'PRECISION: {prec_status} '
        f'(settled={settled} tp={tp} recovered={recovered} pending={pending}, '
        f'median_lead={median_lead})\n')
    sys.stderr.write('wrote early-warning.md + appended early-warning-history.jsonl\n')
PY
