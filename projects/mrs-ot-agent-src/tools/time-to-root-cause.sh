#!/usr/bin/env bash
# time-to-root-cause.sh — METRIC #1 on the eval scoreboard ("Instrument the three blind metrics",
# README → Next → gap #2). Today this is NOT measured at all; this is the instrument.
#
# WHAT IT MEASURES: for each triaged incident that has a root-cause-identified timestamp
# (ts_root_cause, written by record-triage-event.sh --root-cause-at), the elapsed wall-clock from
# first-notified (ts_notified) to root-cause-identified. The headline cut is RECURRING / KNOWN-
# PATTERN hits — events whose signal or notification_text cites a P-row / R-rule (regex P/R + digits).
# Those are exactly the "same failure ≥3×" incidents that Problem #1 says must reach root cause in
# ≤5 min via P-row LOOKUP (not a re-debug). So the bar we score against is **≤5 minutes**.
#
# OUTPUT: reports/time-to-root-cause.md (median + p90 + n + ≤5-min share, for ALL events and for
# the known-pattern subset) + .json + an idempotent-per-day history .jsonl so it TRENDS.
#
# PLUMBING-READY, AWAITING DATA: ts_root_cause is a brand-new column. Until the monitors start
# passing `record-triage-event.sh --root-cause-at "<time>"` on each verdict, no row has it set and
# this tool reports "no data yet (awaiting ts_root_cause capture)" — cleanly, no error. To FULLY
# wire metric #1, the three monitor crons that already call record-triage-event.sh per verdict
# (ot-sev-monitor, ot-alert-monitor, ot-post-monitor) must add `--root-cause-at "$(date '+%F %T')"`
# (or 'now') at the moment they reach a confident verdict / P-row match. That is a separate pass
# (this build does not edit cron prompts).
#
# Usage: time-to-root-cause.sh [days_back]   (default 90)
set -uo pipefail
DAYS="${1:-90}"
DB="$HOME/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db"
OUTDIR="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context/eval/reports"
BAR_MIN="5"   # the goal: recurring-issue root cause in <=5 min (Problem #1)

# additive column may not exist yet on an un-migrated db (matches escalation-rate.sh pattern)
sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('triage_events') WHERE name='ts_root_cause';" 2>/dev/null | grep -q 1 \
  || sqlite3 "$DB" "ALTER TABLE triage_events ADD COLUMN ts_root_cause TEXT;" 2>/dev/null || true

AFTER=$(python3 -c "import datetime;print((datetime.date.today()-datetime.timedelta(days=$DAYS)).isoformat())")
TODAY=$(python3 -c "import datetime;print(datetime.date.today().isoformat())")

# Pull every windowed row's (notified, root_cause, is_known_pattern) so python does the stats.
# A "known pattern" hit = signal OR notification_text cites a P-row / R-rule (P12 / P-12 / R7 / R-7).
# Emit TSV: notified<TAB>root_cause<TAB>kp(0|1). NULL root_cause => empty 2nd field.
ROWS=$(sqlite3 -separator $'\t' "$DB" "
  SELECT
    ts_notified,
    COALESCE(ts_root_cause,''),
    CASE WHEN (
      COALESCE(signal,'')||' '||COALESCE(notification_text,'')
    ) GLOB '*[PpRr][-_]*[0-9]*' OR (
      COALESCE(signal,'')||' '||COALESCE(notification_text,'')
    ) GLOB '*[PpRr][0-9]*' THEN 1 ELSE 0 END
  FROM triage_events
  WHERE date(ts_notified) >= '$AFTER';" 2>/dev/null)

# Stage the SQL rows in a temp file so the python heredoc stays a QUOTED <<'PY' (no shell
# expansion inside the source — the sibling-tool-safe pattern). Pass its path as argv[6].
ROWS_TSV="$(mktemp)"
trap 'rm -f "$ROWS_TSV"' EXIT
printf '%s\n' "$ROWS" > "$ROWS_TSV"

python3 - "$OUTDIR" "$AFTER" "$TODAY" "$DAYS" "$BAR_MIN" "$ROWS_TSV" <<'PY'
import json,sys,os,datetime
outdir,after,today,DAYS,BAR_MIN,rows_tsv=sys.argv[1:]
DAYS=int(DAYS); BAR_MIN=float(BAR_MIN); BAR_S=BAR_MIN*60

rows=[]
raw=open(rows_tsv).read()
for line in raw.splitlines():
    if not line.strip(): continue
    parts=line.split('\t')
    if len(parts)<3: continue
    notified,rc,kp=parts[0],parts[1],parts[2]
    rows.append((notified,rc.strip(),kp.strip()=='1'))

N_total=len(rows)
N_kp=sum(1 for _,_,kp in rows if kp)

def parse(t):
    for f in ('%Y-%m-%d %H:%M:%S','%Y-%m-%dT%H:%M:%S'):
        try: return datetime.datetime.strptime(t[:19],f)
        except Exception: pass
    return None

def stats(pairs):
    # pairs: list of (notified, rc) with rc non-empty; returns dict or None
    deltas=[]
    for notified,rc in pairs:
        a,b=parse(notified),parse(rc)
        if a and b:
            d=(b-a).total_seconds()
            if d>=0: deltas.append(d)
    if not deltas: return None
    deltas.sort()
    n=len(deltas)
    def pct(p):
        if n==1: return deltas[0]
        i=p*(n-1); lo=int(i); hi=min(lo+1,n-1); frac=i-lo
        return deltas[lo]+(deltas[hi]-deltas[lo])*frac
    med=pct(0.5); p90=pct(0.9)
    within=sum(1 for d in deltas if d<=BAR_S)
    return {'n':n,'median_s':round(med,1),'median_min':round(med/60,2),
            'p90_s':round(p90,1),'p90_min':round(p90/60,2),
            'within_bar':within,'within_bar_share':round(within/n,3)}

all_pairs=[(nt,rc) for nt,rc,_ in rows if rc]
kp_pairs =[(nt,rc) for nt,rc,kp in rows if rc and kp]
s_all=stats(all_pairs)
s_kp =stats(kp_pairs)
measured=len(all_pairs)

def fmtmin(x): return 'n/a' if x is None else f'{x:.1f} min'
def fmtshare(x): return 'n/a' if x is None else f'{x:.0%}'

L=[f'# Time-to-root-cause — metric #1 ({after} → {today}, {DAYS}d)','',
   '_Generated by `tools/time-to-root-cause.sh` from the `triage_events` substrate. Elapsed from '
   'first-notified (`ts_notified`) to root-cause-identified (`ts_root_cause`). The headline cut is '
   f'**recurring / known-pattern** hits (signal cites a P-row/R-rule) — those must reach root cause '
   f'in **≤{int(BAR_MIN)} min** via P-row lookup (Problem #1).',
   '',
   f'> **Wiring status:** `ts_root_cause` is captured via `record-triage-event.sh --root-cause-at`. '
   f'To fully wire this metric the three monitor crons (`ot-sev-monitor`, `ot-alert-monitor`, '
   f'`ot-post-monitor`) must pass `--root-cause-at "$(date \'+%F %T\')"` at the moment they reach a '
   f'confident verdict / P-row match. (Not edited in this pass.)','']

if measured==0:
    L+=['## Status','',
        f'**No data yet (awaiting `ts_root_cause` capture).** {N_total} triage events are in the '
        f'window ({N_kp} cite a known pattern), but none has a root-cause timestamp set, so '
        f'time-to-root-cause cannot be computed yet. The instrument is plumbing-ready; it will '
        f'populate as soon as a monitor passes `--root-cause-at`.','']
    verdict='no-data'
else:
    def block(title,s):
        if s is None:
            return [f'### {title}','','_no measurable datapoints in window_','']
        return [f'### {title}','',
                f'- n = **{s["n"]}**',
                f'- median = **{fmtmin(s["median_min"])}** · p90 = **{fmtmin(s["p90_min"])}**',
                f'- within ≤{int(BAR_MIN)}-min bar = **{s["within_bar"]}/{s["n"]} ({fmtshare(s["within_bar_share"])})**','']
    L+=['## Metric','',
        f'- triage events in window: **{N_total}** · with root-cause timestamp: **{measured}** · '
        f'known-pattern (recurring) hits: **{N_kp}**','']
    L+=block('Recurring / known-pattern hits (the ≤5-min target population)',s_kp)
    L+=block('All measured triages',s_all)
    verdict=('PASS' if (s_kp and s_kp['within_bar_share']>=0.9) else
             'BELOW target' if s_kp else 'no known-pattern datapoints yet')
    L+=[f'**Verdict (known-pattern ≤{int(BAR_MIN)}-min bar): {verdict}**','']

open(f'{outdir}/time-to-root-cause.md','w').write('\n'.join(L)+'\n')

out={'window':[after,today],'window_days':DAYS,'bar_min':BAR_MIN,
     'events_in_window':N_total,'known_pattern_events':N_kp,'measured':measured,
     'all':s_all,'known_pattern':s_kp}
json.dump(out,open(f'{outdir}/time-to-root-cause.json','w'),indent=1)

# time-series append (idempotent per day) — track the trend even while empty
hist=f'{outdir}/time-to-root-cause-history.jsonl'
row={'date':today,'window_days':DAYS,'events_in_window':N_total,
     'known_pattern_events':N_kp,'measured':measured,
     'kp_median_min':(s_kp['median_min'] if s_kp else None),
     'kp_p90_min':(s_kp['p90_min'] if s_kp else None),
     'kp_within_bar_share':(s_kp['within_bar_share'] if s_kp else None)}
lines=[l for l in (open(hist).read().splitlines() if os.path.exists(hist) else [])
       if l.strip() and json.loads(l).get('date')!=today]
lines.append(json.dumps(row))
open(hist,'w').write('\n'.join(lines)+'\n')

if measured==0:
    print(f'no data yet (awaiting ts_root_cause capture) | {N_total} events in window, '
          f'{N_kp} known-pattern')
else:
    kp=f'{s_kp["median_min"]:.1f}min med, {fmtshare(s_kp["within_bar_share"])} within {int(BAR_MIN)}min' if s_kp else 'no kp datapoints'
    print(f'measured {measured}/{N_total} | known-pattern: {kp} -> {verdict}')
print('wrote time-to-root-cause.md + .json + time-to-root-cause-history.jsonl')
PY
