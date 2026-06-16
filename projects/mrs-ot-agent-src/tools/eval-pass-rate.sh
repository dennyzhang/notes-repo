#!/usr/bin/env bash
# eval-pass-rate.sh — measure the eval LOOP's own reliability (its "passing rate").
#
# You can't improve a passing rate you don't measure. This dogfoods the eval system on
# itself: of the ot-evolve-loop ticks in a window, how many actually COMPLETED a run vs
# missed / errored / ran suspiciously long (a likely stall-but-returned-HEARTBEAT_OK).
#
# Source of truth: the job_runs table (status, duration_ms). v1 is a heuristic proxy (a long
# `ok` run ~= stall); it becomes exact once eval-flow.js writes a structured per-run outcome.
# Writes a report + appends a time-series row.
#
# Usage: eval-pass-rate.sh [days_back]   (default 7)
set -uo pipefail
export EPR_DAYS="${1:-7}"
export EPR_DB="$HOME/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db"
export EPR_OUTDIR="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context/eval/reports"
export EPR_STALL=1500   # >25min ok-run ~= likely stalled-but-returned (tune as real timings land)

python3 - <<'PY'
import os, sqlite3, json
days  = int(os.environ["EPR_DAYS"])
db    = os.environ["EPR_DB"]
outdir= os.environ["EPR_OUTDIR"]
stall = int(os.environ["EPR_STALL"])
con = sqlite3.connect(db)
rows = con.execute(
    "SELECT run_at, duration_ms, status FROM job_runs "
    "WHERE job_id='ot-evolve-loop' AND run_at >= datetime('now', ?) ORDER BY run_at",
    (f"-{days} days",)).fetchall()
def secs(ms):
    try: return float(ms)/1000.0
    except Exception: return 0.0
n        = len(rows)
missed   = sum(1 for r in rows if r[2] == "missed")
errored  = sum(1 for r in rows if r[2] == "error")
ok       = [r for r in rows if r[2] == "ok"]
slow     = [r for r in ok if secs(r[1]) >  stall]   # ran but suspiciously long -> likely stall
clean    = [r for r in ok if secs(r[1]) <= stall]   # completed in a normal window
attempted= n - missed
passed   = len(clean)
rate     = (passed / attempted) if attempted else None
durs     = sorted(secs(r[1]) for r in ok)
med      = durs[len(durs)//2] if durs else 0.0
rate_s   = ("%.0f%%" % (rate*100)) if rate is not None else "n/a"
stall_m  = stall // 60

L = [f"# Eval loop passing rate ({days}d) — ot-evolve-loop", "",
     f"_From `job_runs` (ground truth). v1 heuristic: an `ok` run > {stall_m}min is counted a likely STALL "
     "(returned HEARTBEAT_OK after a timeout). Exact once eval-flow.js writes a structured outcome marker._", "",
     "## Rate",
     f"- ticks in window: **{n}** · daemon-attempted {attempted} · missed {missed}",
     f"- **passing rate: {rate_s}**  ({passed} clean / {attempted} attempted)",
     f"- likely-stalled (ok but > {stall_m}min): {len(slow)} · errored: {errored}",
     (f"- run duration: median {med/60:.1f}min, max {durs[-1]/60:.1f}min" if durs else "- run duration: n/a"),
     "", "## Recent ticks", "| run_at | mins | status | verdict |", "|---|---|---|---|"]
for r in rows[-12:]:
    s = secs(r[1]); st = r[2]
    v = "missed" if st == "missed" else "errored" if st == "error" else ("likely-stall" if s > stall else "clean")
    L.append(f"| {str(r[0])[:16]} | {s/60:.1f} | {st} | {v} |")
open(f"{outdir}/eval-pass-rate.md", "w").write("\n".join(L) + "\n")

hist = f"{outdir}/eval-pass-rate-history.jsonl"
today = (str(rows[-1][0])[:10] if rows else "unknown")
row = {"date": today, "window_days": days, "ticks": n, "attempted": attempted, "clean": passed,
       "passing_rate": (round(rate,3) if rate is not None else None),
       "likely_stalled": len(slow), "missed": missed, "errored": errored}
keep = [l for l in (open(hist).read().splitlines() if os.path.exists(hist) else [])
        if l.strip() and json.loads(l).get("date") != today]
keep.append(json.dumps(row))
open(hist, "w").write("\n".join(keep) + "\n")
print(f"passing rate: {rate_s} ({passed} clean / {attempted} attempted) | missed {missed} | likely-stall {len(slow)} | errored {errored}")
print("wrote eval-pass-rate.md + eval-pass-rate-history.jsonl")
PY
