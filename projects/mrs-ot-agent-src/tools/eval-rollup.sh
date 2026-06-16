#!/usr/bin/env bash
# eval-rollup.sh — combine today's per-shard PARTIAL eval rows into ONE full-corpus composite (gap #1).
#
# The daemon evolve-loop can't run the whole ~57-case eval in one tick (each triage agent reads ~141KB
# then reasons, blowing the 180s/agent cap; iter5/12/13 stalled at conc 4/2/1). So each tick grades one
# small shard (eval-flow.js args.shard) and appends a `partial:true` row. eval-stats.sh EXCLUDES those
# from the baseline. This script is the other half: once EVERY shard for today's gold_version is present,
# it folds them into ONE `partial:false` full-corpus row (n-weighted means) — the trustworthy daemon
# composite the daily-baseline gate owes. Idempotent: skips if a full row for today+gold_version exists.
#
# It reads/writes the same jsonl directly (the Workflow sandbox can't write files, but the cron caller
# can — same path as `eval-stats.sh append`). NO fabrication: if shards are missing it reports what's
# missing and writes nothing.
#
# Modes:
#   status [gold_version] [date]   report which shards are present/missing for the day (no write)
#   rollup [gold_version] [date]   if all shards present (and no full row yet), append the rollup row
#
# gold_version / date default to: the most-recent partial row's gold_version, and today (%F).
set -uo pipefail
MODE="${1:-status}"
GV="${2:-}"; DATE_ARG="${3:-}"
HIST="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context/eval/reports/eval-flow-history.jsonl"

MODE="$MODE" GV="$GV" DATE_ARG="$DATE_ARG" HIST="$HIST" python3 - <<'PY'
import os, json, datetime
hist = os.environ["HIST"]; mode = os.environ["MODE"]
gv_arg = os.environ["GV"].strip(); date_arg = os.environ["DATE_ARG"].strip()
rows = []
if os.path.exists(hist):
    for l in open(hist).read().splitlines():
        l = l.strip()
        if l:
            try: rows.append(json.loads(l))
            except Exception: pass

today = date_arg or datetime.date.today().strftime("%F")

# pick gold_version: explicit arg, else the gold_version of the most-recent partial row
def is_partial(r): return r.get("partial") is True
partials_all = [r for r in rows if is_partial(r)]
if not gv_arg:
    gv = next((r.get("gold_version") for r in reversed(partials_all) if r.get("gold_version")), None)
else:
    gv = gv_arg
if not gv:
    print("no gold_version found among partial rows; nothing to roll up"); raise SystemExit(0)

# A rollup is per (date, gold_version). `date` keys to the daemon-local %F that eval-stats.sh stamps —
# same TZ basis as the baseline gate, so no UTC/PT skew. We match rows whose date STARTS WITH today
# (eval-stats append may suffix a letter, e.g. "2026-06-12b").
def same_day(r): return str(r.get("date", "")).startswith(today)
todays_partials = [r for r in partials_all if same_day(r) and r.get("gold_version") == gv]

if not todays_partials:
    print(f"no partial shards for date={today} gold_version={gv} — nothing to roll up"); raise SystemExit(0)

# num_shards: from the rows (they all carry it); take the max seen (defensive if a stale smaller value slipped in)
num_shards = max((r.get("num_shards") or 0) for r in todays_partials)
if not num_shards:
    print("partial rows carry no num_shards — cannot determine completeness; aborting"); raise SystemExit(0)

# keep the LATEST row per shard index (a re-run of a shard supersedes the earlier attempt)
by_shard = {}
for r in todays_partials:
    si = r.get("shard")
    if si is None: continue
    by_shard[si] = r  # later rows overwrite earlier -> latest wins

present = sorted(by_shard.keys())
expected = list(range(num_shards))
missing = [i for i in expected if i not in by_shard]

# already-rolled-up guard: a full (partial false) row for today+gv
def is_full_today(r):
    return (not is_partial(r)) and same_day(r) and r.get("gold_version") == gv and r.get("source") == "daemon"
already = any(is_full_today(r) for r in rows)

print(f"gold_version={gv} date={today} num_shards={num_shards} present={present} missing={missing} full_row_exists={already}")

if mode != "rollup":
    raise SystemExit(0)

if already:
    print("ROLLUP SKIPPED: a full daemon composite for today already exists (idempotent)"); raise SystemExit(0)
if missing:
    print(f"ROLLUP NOT READY: {len(missing)} shard(s) missing: {missing} — wrote nothing (no fabrication)"); raise SystemExit(0)

# All shards present -> n-weighted combine. A shard with n==0 (out-of-range/empty) contributes nothing.
shards = [by_shard[i] for i in expected]
def wmean(key):
    num = 0.0; den = 0
    for r in shards:
        v = r.get(key); n = r.get("n") or 0
        if isinstance(v, (int, float)) and n:
            num += v * n; den += n
    return (round(num / den, 3) if den else None)

total_n = sum((r.get("n") or 0) for r in shards)
roll = {
    "date": today,
    "source": "daemon",
    "wf": None,
    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "composite": wmean("composite"),
    "calibration": wmean("calibration"),
    "owner": wmean("owner"),
    "decisiveness": wmean("decisiveness"),
    "hallucination": wmean("hallucination"),
    "root_cause": wmean("root_cause"),
    "n": total_n,
    "gold_version": gv,
    "partial": False,            # THIS is a full-corpus composite -> counts toward baseline/noise band
    "shard": None,
    "shard_size": None,
    "num_shards": num_shards,
    "rolled_up_from": num_shards,  # provenance: built by folding N shards, not a single eval run
}
open(hist, "a").write(json.dumps(roll) + "\n")
print("ROLLED UP:", json.dumps(roll))
PY
