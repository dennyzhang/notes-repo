#!/bin/bash
# check-zombie-ki001.sh — Diagnose whether a zombie training job was caused by
# KI-001 (elastic agent hung on error path, missing exit_w_cleanup / D98638473).
#
# Usage: bash check-zombie-ki001.sh <job_name> [version]
# Example: bash check-zombie-ki001.sh mvai-training-online-2125752019 35
#
# If version is omitted, uses the latest version.
#
# Diagnostic: compares task reply file timestamps against job end time.
# A large gap (>30 min) = elastic agent wrote the failure but couldn't exit = KI-001.
#
# Exit codes:
#   0 = KI-001 confirmed
#   1 = Not KI-001
#   2 = Usage error or data fetch failure

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <job_name> [version]"
  echo "Example: $0 mvai-training-online-2125752019 35"
  exit 2
fi

JOB_NAME="$1"
THRESHOLD_SECS=1800  # 30 min gap = KI-001 signature

echo "=== KI-001 Zombie Diagnostic ==="
echo "Job: ${JOB_NAME}"
echo ""

# Step 1: Get job metadata
echo "[1/4] Fetching job metadata..."
if [ $# -ge 2 ]; then
  VERSION="$2"
  JOB_META=$(meta ai.mast-job metadata --name="${JOB_NAME}" --version="${VERSION}" -o json 2>&1)
else
  JOB_META=$(meta ai.mast-job metadata --name="${JOB_NAME}" -o json 2>&1)
  VERSION=$(echo "${JOB_META}" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['version'])" 2>/dev/null)
fi
echo "  Version: ${VERSION}"

JOB_STATUS=$(echo "${JOB_META}" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['status'])" 2>/dev/null)

# For RUNNING jobs, we can still check if reply files exist (active zombie detection)
IS_RUNNING=false
if [ "${JOB_STATUS}" = "RUNNING" ]; then
  IS_RUNNING=true
  echo "  Status: RUNNING (checking for active zombie — reply files written but process alive)"
else
  echo "  Status: ${JOB_STATUS}"
fi

ATTEMPT_META=$(meta ai.mast-job attempts --name="${JOB_NAME}" --version="${VERSION}" -o json 2>&1)
TASK_COUNT=$(echo "${ATTEMPT_META}" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())[0]['task_count'])" 2>/dev/null)
echo "  Tasks: ${TASK_COUNT}"

if [ "${IS_RUNNING}" = "false" ]; then
  END_TIME=$(echo "${ATTEMPT_META}" | python3 -c "
import sys,json
from datetime import datetime, timezone, timedelta
d = json.loads(sys.stdin.read())[0]
end_str = d['end_time']
dt_naive = datetime.strptime(end_str.rsplit(' ', 1)[0], '%Y-%m-%d %H:%M:%S')
tz_str = end_str.rsplit(' ', 1)[1] if ' ' in end_str else 'PDT'
tz_offset = {'PDT': -7, 'PST': -8, 'UTC': 0, 'EDT': -4, 'EST': -5}.get(tz_str, -7)
dt = dt_naive.replace(tzinfo=timezone(timedelta(hours=tz_offset)))
print(int(dt.timestamp()))
" 2>/dev/null)
else
  END_TIME=$(python3 -c "import time; print(int(time.time()))")
fi
echo ""

# Step 2: Scheduling timeline
echo "[2/4] Fetching scheduling timeline..."
meta ai.mast-job scheduling --name="${JOB_NAME}" --version="${VERSION}" 2>&1 | grep -E "PENDING|RUNNING|DEAD|SHUTTING_DOWN|FAILED" | head -10
echo ""

# Step 3: Collect reply file timestamps for all tasks
echo "[3/4] Checking reply files for all ${TASK_COUNT} tasks..."
echo ""

EARLIEST_REPLY_TS=""
EARLIEST_REPLY_TASK=""
EARLIEST_REPLY_MSG=""
TASKS_WITH_REPLY=0

for task_id in $(seq 0 $((TASK_COUNT - 1))); do
  RESULT=$(timeout 15 meta ai.mast-job logs --name="${JOB_NAME}" --version="${VERSION}" \
    --task-id="${task_id}" \
    --file-path="mast_hpc_task_failure_reply_file" \
    --max-lines=5 --use-legacy-logreader 2>&1) || RESULT=""

  if [ -z "${RESULT}" ]; then
    echo "  Task ${task_id}: no reply file (or timeout)"
    continue
  fi

  PARSED=$(echo "${RESULT}" | python3 -c "
import sys, json, re
raw = sys.stdin.read().strip()
if not raw:
    print('0|NO_REPLY_FILE')
else:
    # Handle multiple concatenated JSON objects (one per attempt)
    # Find all top-level JSON objects and pick the one with the latest timestamp
    best_ts = 0
    best_msg = ''
    for match in re.finditer(r'\{', raw):
        start = match.start()
        depth = 0
        for i in range(start, len(raw)):
            if raw[i] == '{': depth += 1
            elif raw[i] == '}': depth -= 1
            if depth == 0:
                try:
                    d = json.loads(raw[start:i+1])
                    ts = d.get('timestamp', 0)
                    msg = d.get('message', '?')[:120].replace('\n', ' ')
                    if ts > best_ts:
                        best_ts = ts
                        best_msg = msg
                except:
                    pass
                break
    if best_ts > 0:
        print(f'{best_ts}|{best_msg}')
    else:
        print('0|NO_REPLY_FILE')
" 2>/dev/null)

  TS=$(echo "${PARSED}" | cut -d'|' -f1)
  MSG=$(echo "${PARSED}" | cut -d'|' -f2-)

  if [ "${TS}" != "0" ]; then
    TASKS_WITH_REPLY=$((TASKS_WITH_REPLY + 1))
    HUMAN_TIME=$(python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.fromtimestamp(${TS}, tz=timezone(timedelta(hours=-7))).strftime('%H:%M:%S PDT'))" 2>/dev/null)
    echo "  Task ${task_id}: reply at ${HUMAN_TIME} — ${MSG}"

    if [ -z "${EARLIEST_REPLY_TS}" ] || [ "${TS}" -lt "${EARLIEST_REPLY_TS}" ]; then
      EARLIEST_REPLY_TS="${TS}"
      EARLIEST_REPLY_TASK="${task_id}"
      EARLIEST_REPLY_MSG="${MSG}"
    fi
  else
    echo "  Task ${task_id}: no reply file"
  fi
done

echo ""

if [ -z "${EARLIEST_REPLY_TS}" ]; then
  echo "════════════════════════════════════════════════════════════"
  echo "  No reply files found."
  if [ "${IS_RUNNING}" = "true" ]; then
    echo "  Job is RUNNING with no task failures detected yet."
    echo "  Not a KI-001 zombie (no error written)."
  else
    echo "  Not KI-001 — elastic agent never detected an error."
    echo "  (SJD or external kill terminated the job)"
  fi
  echo "════════════════════════════════════════════════════════════"
  exit 1
fi

# Step 4: Compute gap and diagnose
echo "[4/4] Diagnosing..."

GAP=$((END_TIME - EARLIEST_REPLY_TS))
GAP_MIN=$((GAP / 60))

EARLIEST_HUMAN=$(python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.fromtimestamp(${EARLIEST_REPLY_TS}, tz=timezone(timedelta(hours=-7))).strftime('%H:%M:%S PDT'))" 2>/dev/null)

if [ "${IS_RUNNING}" = "true" ]; then
  END_HUMAN="NOW (job still RUNNING)"
else
  END_HUMAN=$(python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.fromtimestamp(${END_TIME}, tz=timezone(timedelta(hours=-7))).strftime('%H:%M:%S PDT'))" 2>/dev/null)
fi

echo ""
echo "  First reply file:  task ${EARLIEST_REPLY_TASK} at ${EARLIEST_HUMAN}"
echo "  Job end:           ${END_HUMAN}"
echo "  Gap:               ${GAP_MIN} min (${GAP}s)"
echo "  Threshold:         $((THRESHOLD_SECS / 60)) min"
echo "  Tasks with reply:  ${TASKS_WITH_REPLY}/${TASK_COUNT}"
echo ""

# Step 5: Check base layer for D98638473
echo "[Bonus] Checking base layer for D98638473 fix..."
BASE_DATE=$(echo "${JOB_META}" | python3 -c "
import sys, json
meta = json.loads(json.loads(sys.stdin.read())['application_metadata'])
print(meta.get('base_upstream_date', 'unknown'))
" 2>/dev/null)
BASE_PKG=$(echo "${JOB_META}" | python3 -c "
import sys, json
meta = json.loads(json.loads(sys.stdin.read())['application_metadata'])
print(meta.get('base_layer_pkg', 'unknown'))
" 2>/dev/null)
echo "  Base layer: ${BASE_PKG}"
echo "  Base upstream date: ${BASE_DATE}"
echo "  D98638473 landed (committed): 2026-05-21"

FIX_INCLUDED="unknown"
if [ "${BASE_DATE}" != "unknown" ]; then
  FIX_INCLUDED=$(python3 -c "
base = '${BASE_DATE}'.replace('+', ' ')[:10]
fix = '2026-05-21'
print('YES' if base >= fix else 'NO')
" 2>/dev/null)
  echo "  Fix included: ${FIX_INCLUDED}"
fi
echo ""

# Verdict
if [ "${GAP}" -gt "${THRESHOLD_SECS}" ]; then
  echo "════════════════════════════════════════════════════════════"
  echo "  ✗ KI-001 CONFIRMED"
  echo ""
  echo "  Reply file written ${GAP_MIN} min before job death."
  echo "  Elastic agent hung on exit (missing exit_w_cleanup)."
  echo "  MAST never read the reply file because task never exited."
  echo ""
  if [ "${FIX_INCLUDED}" = "NO" ]; then
    echo "  FIX: Patch D98638473 into app layer or upgrade base"
    echo "       layer to a version built after 2026-05-21."
  elif [ "${FIX_INCLUDED}" = "YES" ]; then
    echo "  ⚠ Base layer should include the fix — investigate why"
    echo "    the elastic agent still hung (possible new code path)."
  fi
  echo "════════════════════════════════════════════════════════════"
  exit 0
else
  echo "════════════════════════════════════════════════════════════"
  echo "  ✓ NOT KI-001"
  echo ""
  echo "  Reply file written ${GAP_MIN} min before job death."
  echo "  Gap is within threshold — elastic agent exited promptly."
  echo "  Look for a different root cause."
  echo "════════════════════════════════════════════════════════════"
  exit 1
fi
