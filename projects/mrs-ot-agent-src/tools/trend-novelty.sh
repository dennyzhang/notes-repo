#!/usr/bin/env bash
# trend-novelty.sh — the TREND / NOVELTY substrate for the eval scoreboard (Problem #4:
# "catch novel patterns — and noise"). Sibling of escalation-rate.sh; reads the same
# triage_events table and TRENDS the SHAPE of the incoming incident stream instead of a
# single rate.
#
# Over a rolling window it groups every triaged item into a stable SIGNATURE
# (signal_class + a normalized failure-type token + model name) and emits TWO lists:
#
#   NOVEL / emerging  — signatures that are NEW (unseen before this window) or RISING
#                       week-over-week. These are candidates to FLAG FOR A HUMAN: a failure
#                       class the agent has little/no history on, or one accelerating. A
#                       rising-but-known signature is the early-signal substrate Problem #3
#                       will turn into proactive paging.
#
#   NOISE             — high-volume signatures that are repeatedly AUTO-HANDLED / NO_ACTION /
#                       DEDUP / self-resolved / TRANSIENT and low-value. These are candidates
#                       to SUPPRESS via a known-issue TTL so they stop costing triage cycles.
#
# READ-ONLY ON ACTION (HARD). This tool ONLY REPORTS candidates. It NEVER auto-escalates and
# NEVER auto-suppresses anything — no SEV mutation, no known-issue write, no gchat send. The
# operator reads the report and decides. A dud flag counts against the agent's signal
# precision (per the eval README: the agent owns the precision of its own signals), so the
# thresholds below are deliberately conservative and every candidate carries its evidence
# counts inline so the operator can sanity-check before acting.
#
# Writes a report .md + .json snapshot and appends one row per run to a .jsonl time-series so
# the novel/noise counts THEMSELVES trend. Runs cleanly ("no data yet") on an empty table.
#
# Usage: trend-novelty.sh [days_back]   (default 28 = 4 weeks, so WoW has ≥2 full weeks)
set -uo pipefail
DAYS="${1:-28}"
DB="$HOME/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db"
OUTDIR="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context/eval/reports"
TOPN="${TOPN:-10}"        # top-N each list
mkdir -p "$OUTDIR"

# Empty / missing table -> clean no-data path (do not error).
N_TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM triage_events;" 2>/dev/null || echo 0)
N_TOTAL=${N_TOTAL:-0}

AFTER=$(python3 -c "import datetime;print((datetime.date.today()-datetime.timedelta(days=$DAYS)).isoformat())")
TODAY=$(python3 -c "import datetime;print(datetime.date.today().isoformat())")

# Pull rows to TEMP FILES (not env vars): signal text can be large and may contain embedded
# newlines, so we use a record-separator (RS \x1e) between rows and a field-separator
# (US \x1f) between columns. Temp files avoid argv/env size limits and survive any byte in
# the free-text signal. (codex review 2026-06-12: env-blob passing can exceed limits + a
# newline in `signal` would corrupt a line-split parse.)
TMPW=$(mktemp); TMPP=$(mktemp)
trap 'rm -f "$TMPW" "$TMPP"' EXIT
# Pull the raw rows in window (ts drives WoW). Also pull FULL pre-window history so
# "novel = never-seen-before-window" is decidable.
sqlite3 -separator $'\x1f' -newline $'\x1e' "$DB" "
  SELECT date(ts_notified), COALESCE(signal_class,''), COALESCE(signal,''),
         COALESCE(sev_final_status,''), COALESCE(routed_to,'')
  FROM triage_events
  WHERE date(ts_notified) >= '$AFTER';" >"$TMPW" 2>/dev/null || true
sqlite3 -separator $'\x1f' -newline $'\x1e' "$DB" "
  SELECT COALESCE(signal_class,''), COALESCE(signal,'')
  FROM triage_events
  WHERE date(ts_notified) < '$AFTER';" >"$TMPP" 2>/dev/null || true

python3 - "$OUTDIR" "$AFTER" "$TODAY" "$DAYS" "$TOPN" "$N_TOTAL" "$TMPW" "$TMPP" <<'PY'
import sys, os, re, json, datetime, collections
outdir, after, today, DAYS, TOPN, N_TOTAL, tmpw, tmpp = sys.argv[1:]
DAYS, TOPN, N_TOTAL = int(DAYS), int(TOPN), int(N_TOTAL)
US = '\x1f'; RS = '\x1e'

rows_window = open(tmpw).read() if os.path.exists(tmpw) else ''
sigs_prior  = open(tmpp).read() if os.path.exists(tmpp) else ''

# ---- signature extraction -------------------------------------------------------------
# A signature must be STABLE across re-phrasings of the "same kind of incident" yet specific
# enough that a genuinely-new failure class gets its own bucket. We combine:
#   signal_class  (the coarse lane: mrs_online_training / mvai_publish_pipeline / ...)
#   FAILURE-TYPE  (a controlled-vocab token scanned from the free-text signal)
#   MODEL         (the model/family name token, IDs and versions normalized away)
# Model IDs (long digit runs) and snapshot versions (v61) are normalized OUT so the same
# model across versions/instances collapses to ONE signature.

# Controlled failure-type vocabulary (ordered: first match wins for the primary type).
# Each entry: (label, regex). Curated from the live triage_events corpus.
FAILTYPES = [
    ('SPARSE_DELTA',    r'sparse[_ ]?delta'),
    ('FULL_SNAPSHOT',   r'full[_ ]?snapshot'),
    ('ITEM_EMB_DELTA',  r'item[_ ]?emb[_ ]?delta'),
    ('STALE_SNAPSHOT',  r'stale (?:snapshot|delta)|snapshots?\s*>?\s*\d|no snapshots'),
    ('INVALID_DETECTOR',r'invalid detector|no data source|detector[_ ]?broken'),
    ('NCCL',            r'nccl|collective mismatch|missing rank'),
    ('SCRIBE',          r'scribe|client_lag'),
    ('STUS',            r'\bstus\b'),
    ('TMS_BLOCKPLAN',   r'tms|blockplan|block plan'),
    ('MAST_DEAD',       r'mast dead|trainer .*dead|job dead|launch fail'),
    ('NE_REGRESSION',   r'\bne\b.*(regress|surge|calibrat)|calibration'),
    ('EXAMPLE_AGE',     r'example age|training example age'),
    ('PUBLISH_GAP',     r'publish gap|publish.*stall|no(?:t)? publish'),
    ('UNIT_TEST',       r'unit test|test_\w+ .*fail'),
    ('QUOTA',           r'quota'),
    ('THRESHOLD_MISFIT',r'threshold[_ ]?misfit'),
]
def fail_type(s):
    low = s.lower()
    for label, rx in FAILTYPES:
        if re.search(rx, low):
            return label
    return 'OTHER'

# Model/family token: pick the first underscore-joined lowercase token of decent length that
# is NOT one of the known infra/metric tokens (those are failure descriptors, not models).
NON_MODEL = {
    'scribe_read_proxy', 'client_lag_in_seconds', 'sev_type', 'mrs_online_training',
    'predictor_streaming_model_update', 'vm_rule', 'block_plan',
}
MODEL_RX = re.compile(r'\b([a-z][a-z0-9]+(?:_[a-z0-9]+){2,})\b')
def model_token(s):
    for m in MODEL_RX.findall(s):
        if m in NON_MODEL:
            continue
        return m
    return 'unknown_model'

def signature(signal_class, signal):
    sc = (signal_class or 'unknown').strip()
    return f'{sc} | {fail_type(signal)} | {model_token(signal)}'

# ---- noise vs flaggable classification of each ROW ------------------------------------
# A row is "auto-handled / low-value" (noise-contributing) if its status or signal carries a
# no-action / dedup / self-resolved / transient marker AND it was not popped to a human.
NOISE_RX = re.compile(
    r'no_action|auto.?resolved|self.?recover|self.?resolv|dedup|transient|'
    r'threshold_misfit|oos\b|invalid detector|detector_broken', re.I)
def is_auto_handled(status, signal, routed_to):
    if (routed_to or '').lower() == 'human':
        return False
    return bool(NOISE_RX.search(status or '') or NOISE_RX.search(signal or ''))

# ---- parse ----------------------------------------------------------------------------
def parse_window(blob):
    out = []
    for rec in blob.split(RS):
        if not rec.strip():
            continue
        parts = rec.split(US)
        if len(parts) < 5:
            parts += [''] * (5 - len(parts))
        d, sc, sig, status, routed = parts[:5]
        out.append((d.strip(), sc, sig, status, routed))
    return out

def parse_prior(blob):
    seen = set()
    for rec in blob.split(RS):
        if not rec.strip():
            continue
        parts = rec.split(US)
        if len(parts) < 2:
            continue
        sc, sig = parts[0], parts[1]
        seen.add(signature(sc, sig))
    return seen

W = parse_window(rows_window)
prior_sigs = parse_prior(sigs_prior)

# ---- WoW windows: split the lookback into the most-recent 7d ("this week") vs the 7d before
# it ("last week"). The two buckets are EQUAL-LENGTH (7 calendar days each) so the WoW delta
# is fair: this_wk = [td-6, td] inclusive (7 days incl. today); last_wk = [td-13, td-7]
# inclusive (the prior 7 days). (codex review 2026-06-12: td-7 made this_wk an 8-day bucket
# and inflated RISING.) Anything older still counts toward total/first-seen but not WoW.
td = datetime.date.today()
def d(x): return datetime.date.fromisoformat(x)
this_lo = td - datetime.timedelta(days=6)    # 7-day inclusive bucket ending today
last_hi = td - datetime.timedelta(days=7)    # last_wk upper bound (inclusive)
last_lo = td - datetime.timedelta(days=13)   # last_wk lower bound (inclusive)

per_sig = collections.defaultdict(lambda: {
    'total':0, 'this_wk':0, 'last_wk':0, 'auto':0, 'human':0, 'first_seen':None,
    'examples':[]})

for (dd, sc, sig, status, routed) in W:
    s = signature(sc, sig)
    rec = per_sig[s]
    rec['total'] += 1
    try:
        day = d(dd)
    except Exception:
        day = td
    if day >= this_lo: rec['this_wk'] += 1
    elif last_lo <= day <= last_hi: rec['last_wk'] += 1
    if (routed or '').lower() == 'human': rec['human'] += 1
    if is_auto_handled(status, sig, routed): rec['auto'] += 1
    if rec['first_seen'] is None or dd < rec['first_seen']: rec['first_seen'] = dd
    if len(rec['examples']) < 2 and sig.strip():
        rec['examples'].append(sig.strip()[:90])

# ---- THRESHOLDS (documented; conservative to protect signal precision) ----------------
# NOVEL / emerging (flag-for-human candidate) — a signature qualifies if EITHER:
#   (a) NEW: never seen before the window (not in prior_sigs) AND total >= NEW_MIN in window
#       (NEW_MIN=2 so a single one-off blip doesn't get flagged as an "emerging class"); OR
#   (b) RISING: this_wk >= RISE_MIN AND this_wk >= RISE_FACTOR * max(last_wk,1)
#       (a real acceleration, not noise — needs an absolute floor AND a multiplier so a
#        1->2 wiggle does not trip it).
# Human-escalated signatures (human>0) are ALWAYS surfaced in NOVEL regardless — if a human
# was needed, the operator wants eyes on its trend.
NEW_MIN     = 2
RISE_MIN    = 3
RISE_FACTOR = 2.0
# NOISE (suppress candidate) — high volume AND overwhelmingly auto-handled AND no human ever:
#   total >= NOISE_MIN AND auto/total >= NOISE_AUTO_FRAC AND human == 0
NOISE_MIN       = 4
NOISE_AUTO_FRAC = 0.75

novel, noise = [], []
for s, r in per_sig.items():
    is_new = s not in prior_sigs
    rising = r['this_wk'] >= RISE_MIN and r['this_wk'] >= RISE_FACTOR * max(r['last_wk'], 1)
    wow = r['this_wk'] - r['last_wk']
    auto_frac = (r['auto'] / r['total']) if r['total'] else 0.0
    reasons = []
    if is_new and r['total'] >= NEW_MIN: reasons.append('NEW-class')
    if rising: reasons.append(f'RISING(+{wow} WoW, {r["last_wk"]}->{r["this_wk"]})')
    if r['human'] > 0: reasons.append(f'{r["human"]}x human-escalated')
    if reasons:
        novel.append((s, r, wow, reasons, is_new))
    if (r['total'] >= NOISE_MIN and auto_frac >= NOISE_AUTO_FRAC and r['human'] == 0):
        noise.append((s, r, auto_frac))

# rank: NOVEL by (rising magnitude, then total); NOISE by (volume, then auto fraction)
novel.sort(key=lambda x: (x[2], x[1]['total']), reverse=True)
noise.sort(key=lambda x: (x[1]['total'], x[2]), reverse=True)
novel = novel[:TOPN]
noise = noise[:TOPN]

# ---- render md ------------------------------------------------------------------------
L = [f'# Trend & novelty — emerging-vs-noise substrate ({after} → {today}, {DAYS}d)', '',
     '_Generated by `tools/trend-novelty.sh` from the `triage_events` substrate. Groups every '
     'triaged item into a stable signature (`signal_class | failure-type | model`) and trends '
     'its shape. **READ-ONLY: this report only proposes candidates — it never auto-escalates or '
     'auto-suppresses. The operator decides.**_', '',
     f'_Window rows: **{len(W)}** · distinct signatures: **{len(per_sig)}** · '
     f'prior-history signatures: {len(prior_sigs)}_', '']

if N_TOTAL == 0 or not W:
    L += ['## No data yet', '',
          'The `triage_events` table is empty for this window — no signatures to trend. '
          'This is the clean no-data path; rerun once the monitors have recorded events.', '']
else:
    # NOVEL
    L += ['## 🚩 NOVEL / emerging — candidates to FLAG FOR A HUMAN',
          f'_NEW-class (unseen before window, ≥{NEW_MIN} in-window) OR RISING '
          f'(this-wk ≥{RISE_MIN} and ≥{RISE_FACTOR:g}× last-wk) OR human-escalated. '
          f'Top {TOPN}. A human reviews before any escalation._', '']
    if not novel:
        L.append('- _none cleared the novelty thresholds this window._')
    else:
        L.append('| signature | total | last→this wk | WoW Δ | reason | example |')
        L.append('|---|---|---|---|---|---|')
        for (s, r, wow, reasons, is_new) in novel:
            ex = (r['examples'][0] if r['examples'] else '').replace('|', '\\|')
            L.append(f'| `{s}` | {r["total"]} | {r["last_wk"]}→{r["this_wk"]} | '
                     f'{"+" if wow>=0 else ""}{wow} | {", ".join(reasons)} | {ex} |')
    L.append('')
    # NOISE
    L += ['## 🔇 NOISE — candidates to SUPPRESS (known-issue TTL)',
          f'_High volume (≥{NOISE_MIN}) AND ≥{NOISE_AUTO_FRAC:.0%} auto-handled '
          f'(no_action / dedup / self-resolved / transient) AND never human-escalated. '
          f'Top {TOPN}. A human approves the TTL before any suppression._', '']
    if not noise:
        L.append('- _none cleared the noise thresholds this window._')
    else:
        L.append('| signature | total | auto-handled | auto % | example |')
        L.append('|---|---|---|---|---|')
        for (s, r, frac) in noise:
            ex = (r['examples'][0] if r['examples'] else '').replace('|', '\\|')
            L.append(f'| `{s}` | {r["total"]} | {r["auto"]} | {frac:.0%} | {ex} |')
    L.append('')
    L += ['---',
          '_Thresholds (conservative by design — a dud candidate costs signal precision): '
          f'NEW≥{NEW_MIN}, RISE≥{RISE_MIN} & ≥{RISE_FACTOR:g}×, '
          f'NOISE≥{NOISE_MIN} & ≥{NOISE_AUTO_FRAC:.0%} auto. Tune via env / args as the '
          'corpus grows._', '']

open(f'{outdir}/trend-novelty.md', 'w').write('\n'.join(L) + '\n')

# ---- json snapshot + jsonl time-series ------------------------------------------------
snap = {
    'window': [after, today], 'window_days': DAYS,
    'window_rows': len(W), 'distinct_signatures': len(per_sig),
    'novel': [{'signature': s, 'total': r['total'], 'last_wk': r['last_wk'],
               'this_wk': r['this_wk'], 'wow_delta': wow, 'reasons': reasons,
               'new_class': isnew} for (s, r, wow, reasons, isnew) in novel],
    'noise': [{'signature': s, 'total': r['total'], 'auto_handled': r['auto'],
               'auto_frac': round(frac, 3)} for (s, r, frac) in noise],
    'thresholds': {'new_min': NEW_MIN, 'rise_min': RISE_MIN, 'rise_factor': RISE_FACTOR,
                   'noise_min': NOISE_MIN, 'noise_auto_frac': NOISE_AUTO_FRAC},
}
json.dump(snap, open(f'{outdir}/trend-novelty.json', 'w'), indent=1)

hist = f'{outdir}/trend-novelty-history.jsonl'
row = {'date': today, 'window_days': DAYS, 'window_rows': len(W),
       'distinct_signatures': len(per_sig),
       'novel_count': len(novel), 'noise_count': len(noise),
       'top_novel': novel[0][0] if novel else None,
       'top_noise': noise[0][0] if noise else None}
# Idempotent per (date, window_days): a same-day rerun with a DIFFERENT --days-back keeps its
# own series row instead of clobbering the other window's row. (codex review 2026-06-12:
# de-dup by date alone let a 7d rerun overwrite the 28d row.)
def _key(o): return (o.get('date'), o.get('window_days'))
old = [l for l in (open(hist).read().splitlines() if os.path.exists(hist) else [])
       if l.strip() and _key(json.loads(l)) != (today, DAYS)]
old.append(json.dumps(row))
open(hist, 'w').write('\n'.join(old) + '\n')

print(f'window rows {len(W)} | distinct sigs {len(per_sig)} | '
      f'NOVEL {len(novel)} | NOISE {len(noise)}')
print('wrote trend-novelty.md + .json + trend-novelty-history.jsonl')
PY
