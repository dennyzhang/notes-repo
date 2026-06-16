#!/bin/bash
# cron-heartbeat-watchdog.sh — detect cron jobs that have silently STOPPED firing.
#
# WHY: cron-remediator only sees FAILING runs (rows in CRON-HEALTH-METRICS.md). A job
# that stops being invoked entirely produces no row, so it's invisible — exactly how
# diff-signal-monitor went dark for 12 days after the 2026-06-01 devstable sync without
# a single alert. This watches for ABSENCE, not failure.
#
# HOW: derive the job list + cadence from the LIVE crontab (no hand-maintained registry,
# so deprecated jobs auto-drop and new jobs auto-join). For each job that writes a
# heartbeat, alert when the heartbeat is older than 2x its maximum expected inter-run gap.
#
# Invoked from cron-remediator.sh every 15 min (no separate crontab line — no sprawl).
# Standalone-safe: also runnable directly for debugging.

set -uo pipefail

CLAUDE_DIR="$HOME/work/claude"
HEARTBEAT_DIR="$CLAUDE_DIR/state/heartbeats"
SCRIPT_NAME="heartbeat-watchdog"

# shellcheck source=/dev/null
source "$CLAUDE_DIR/scripts/cron-alert.sh" 2>/dev/null || true

LOG_PREFIX="$(date '+%Y-%m-%d %H:%M') [$SCRIPT_NAME]"

# Python does the cron-schedule math and staleness comparison; it prints one line per
# stale job: "<name>\t<age_secs>\t<threshold_secs>". Recovered/healthy jobs print nothing.
STALE=$(/usr/bin/python3 - "$HEARTBEAT_DIR" <<'PY'
import os, sys, subprocess, time, datetime

heartbeat_dir = sys.argv[1]
now = time.time()

# ── pull the live crontab ────────────────────────────────────────────────
try:
    crontab = subprocess.run(["crontab", "-l"], capture_output=True, text=True).stdout
except Exception:
    sys.exit(0)

def field_matches(spec, value, lo, hi):
    """Match one cron field (supports * , */n , a-b , a,b , single)."""
    for part in spec.split(","):
        if part == "*":
            return True
        step = 1
        rng = part
        if "/" in part:
            rng, step = part.split("/"); step = int(step)
        if rng == "*":
            start, end = lo, hi
        elif "-" in rng:
            start, end = rng.split("-"); start, end = int(start), int(end)
        else:
            start = end = int(rng)
        if start <= value <= end and (value - start) % step == 0:
            return True
    return False

def fires_at(fields, dt):
    mn, hr, dom, mon, dow = fields
    # cron dow: 0=Sun..6=Sat; python weekday(): 0=Mon..6=Sun
    py_dow = (dt.weekday() + 1) % 7
    dom_ok = field_matches(dom, dt.day, 1, 31)
    dow_ok = field_matches(dow, py_dow, 0, 6)
    # standard OR semantics when both dom and dow are restricted
    if dom != "*" and dow != "*":
        day_ok = dom_ok or dow_ok
    else:
        day_ok = dom_ok and dow_ok
    return (field_matches(mn, dt.minute, 0, 59)
            and field_matches(hr, dt.hour, 0, 23)
            and field_matches(mon, dt.month, 1, 12)
            and day_ok)

# ── collect fire times per job over a 28-day window (covers monthly jobs) ──
# A job may have MULTIPLE crontab lines (e.g. diff-signal-monitor) — union their fires.
job_fires = {}   # name -> list[datetime]
WINDOW_DAYS = 28
base = datetime.datetime.fromtimestamp(now) - datetime.timedelta(days=WINDOW_DAYS)
base = base.replace(second=0, microsecond=0)

for line in crontab.splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if "cron_run" not in line:
        continue
    toks = line.split()
    if len(toks) < 5:
        continue
    fields = toks[:5]
    # job name = token right after 'cron_run' (skip its numeric timeout arg)
    try:
        ci = toks.index("cron_run")
        name = toks[ci + 2]
    except (ValueError, IndexError):
        continue
    job_fires.setdefault(name, [])
    # walk the window minute-by-minute (cheap: 28d ≈ 40k iters per distinct schedule)
    cur = base
    end = datetime.datetime.fromtimestamp(now)
    fl = job_fires[name]
    step = datetime.timedelta(minutes=1)
    while cur <= end:
        if fires_at(fields, cur):
            fl.append(cur)
        cur += step

# ── compare each job's max expected gap to its heartbeat age ──────────────
for name, fires in sorted(job_fires.items()):
    if len(fires) < 2:
        continue  # too sparse to infer a cadence safely (e.g. brand-new monthly job)
    fires.sort()
    max_gap = max((fires[i+1] - fires[i]).total_seconds() for i in range(len(fires)-1))
    threshold = 2 * max_gap

    hb_path = os.path.join(heartbeat_dir, f"cron-heartbeat-{name}")
    # Only judge jobs that DO write a heartbeat (proves the mechanism exists);
    # a missing heartbeat is ambiguous (job may not emit one) — skip to avoid false alarms.
    if not os.path.exists(hb_path):
        continue
    try:
        with open(hb_path) as f:
            last = float(f.read().strip())
    except Exception:
        last = os.path.getmtime(hb_path)

    age = now - last
    if age > threshold:
        print(f"{name}\t{int(age)}\t{int(threshold)}")
PY
)

stale_count=0
while IFS=$'\t' read -r name age thresh; do
    [ -z "$name" ] && continue
    stale_count=$((stale_count + 1))
    # human-friendly units: minutes under 2h, else hours
    if [ "$age" -lt 7200 ]; then age_s="$(( age / 60 ))m"; else age_s="$(( age / 3600 ))h"; fi
    if [ "$thresh" -lt 7200 ]; then thr_s="$(( thresh / 60 ))m"; else thr_s="$(( thresh / 3600 ))h"; fi
    msg="STALE: no successful run in ${age_s} (expected within ${thr_s}) — cron job stopped firing"
    echo "$LOG_PREFIX $name: $msg"
    cron_alert "$name" "$msg" 2>/dev/null || true
done <<< "$STALE"

if [ "$stale_count" -eq 0 ]; then
    echo "$LOG_PREFIX all scheduled jobs within expected cadence"
    cron_alert_clear "$SCRIPT_NAME" 2>/dev/null || true
else
    echo "$LOG_PREFIX $stale_count stale job(s) detected"
fi

write_heartbeat "$SCRIPT_NAME" 2>/dev/null || true
exit 0
