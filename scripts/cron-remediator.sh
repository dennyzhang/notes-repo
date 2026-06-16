#!/bin/bash
# cron-remediator.sh — auto-remediate chronic cron failures.
# Reads recent CRON-HEALTH-METRICS.md rows with Fix Applied=none and result=failure,
# classifies via patterns from config/cron-remediator-patterns.json, applies remediation,
# writes Fix Applied cell.
#
# STATUS: scaffolding. Patterns file ships empty — populate as non-self-healing failure
# modes are observed (auth-token-expired, network-down-N-min, doc-locked-by-other-session).
#
# Cron: */15 * * * *  (run every 15min — idempotent; no-op when no failure rows or empty patterns)

set -uo pipefail

CLAUDE_DIR="$HOME/work/claude"
METRICS_FILE="$CLAUDE_DIR/state/CRON-HEALTH-METRICS.md"
PATTERNS_FILE="$CLAUDE_DIR/config/cron-remediator-patterns.json"
LOG_DIR="$HOME/logs"
SCRIPT_NAME="cron-remediator"

# shellcheck source=/dev/null
source "$CLAUDE_DIR/scripts/cron-alert.sh" 2>/dev/null || true

LOG_PREFIX="$(date '+%Y-%m-%d %H:%M') [$SCRIPT_NAME]"

# Heartbeat watchdog — detects jobs that silently STOPPED firing (absence, not failure).
# Runs unconditionally, BEFORE the metrics/patterns early-exits below, because a job that
# never runs leaves no metrics row for the pattern-based remediator to see. This is the gap
# that let diff-signal-monitor (+ a cluster) go dark for 12 days after the 2026-06-01 sync.
bash "$CLAUDE_DIR/scripts/cron-heartbeat-watchdog.sh" 2>&1 || true

# ── Remediation gate (primary path) — process typed proposals intent->validate->apply.
# See cron/remediation-gate-design.md. Runs before the legacy metrics/patterns block
# (which early-exits when no patterns file exists).
if [ -f "$CLAUDE_DIR/private_scripts/remediation-gate.py" ]; then
    /usr/bin/python3 "$CLAUDE_DIR/private_scripts/remediation-gate.py" 2>&1 | sed "s/^/$LOG_PREFIX [gate] /"
fi

if [ ! -f "$METRICS_FILE" ]; then
    echo "$LOG_PREFIX [INFO] no metrics file yet — legacy patterns skipped"
    exit 0
fi
if [ ! -f "$PATTERNS_FILE" ]; then
    echo "$LOG_PREFIX [INFO] no patterns file at $PATTERNS_FILE — legacy patterns skipped"
    exit 0
fi

TODAY=$(date '+%Y-%m-%d')
YESTERDAY=$(date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d' 2>/dev/null || echo "$TODAY")

/usr/bin/python3 - "$METRICS_FILE" "$PATTERNS_FILE" "$TODAY" "$YESTERDAY" <<'PY'
import json, re, sys, os, subprocess

metrics_path, patterns_path, today, yesterday = sys.argv[1:5]
recent_dates = {today, yesterday}
log_dir = os.path.expanduser("~/logs")

with open(patterns_path) as f:
    patterns_cfg = json.load(f)
PATTERNS = patterns_cfg.get("patterns", [])

if not PATTERNS:
    print("classified=0 remediated=0 (no patterns configured)")
    sys.exit(0)

with open(metrics_path) as f:
    lines = f.readlines()

modified = False
classified = 0
remediated = 0

for i, line in enumerate(lines):
    if not line.startswith("| "): continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) < 6: continue
    date, time, job, result, duration, fix = cells[:6]
    if date not in recent_dates: continue
    if result != "failure": continue
    if fix != "none": continue

    log_file = f"{log_dir}/{job}.log"
    if not os.path.exists(log_file): continue

    try:
        with open(log_file) as lf:
            log = lf.read()
        m = re.search(r"END\s+" + re.escape(job) + r".+?" + re.escape(time[:5]) + r":\d{2}.+?exit=(\d+)", log)
        if not m: continue
        exit_code = m.group(1)
    except Exception:
        continue

    matched = None
    for p in PATTERNS:
        if p.get("job") != job: continue
        if str(p.get("exit_code", "")) != exit_code: continue
        sig = p.get("log_signature", "")
        if sig and sig not in log: continue
        matched = p
        classified += 1
        break

    if not matched: continue
    cmd = matched.get("remediation_cmd", "")
    label = matched.get("label", "remediated")
    if not cmd:
        applied = f"{label}-noop"
    else:
        try:
            rc = subprocess.run(cmd, shell=True, timeout=300,
                              capture_output=True, text=True).returncode
            applied = label if rc == 0 else f"{label}-failed"
            if rc == 0: remediated += 1
        except Exception:
            applied = f"{label}-error"

    new_line = f"| {date} | {time} | {job} | {result} | {duration} | {applied} |\n"
    lines[i] = new_line
    modified = True

if modified:
    with open(metrics_path, "w") as f:
        f.writelines(lines)

print(f"classified={classified} remediated={remediated}")
PY

echo "$LOG_PREFIX [DONE]"

# Heartbeat
type write_heartbeat &>/dev/null && write_heartbeat "cron-remediator" || true
