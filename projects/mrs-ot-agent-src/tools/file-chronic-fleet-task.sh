#!/usr/bin/env bash
# file-chronic-fleet-task.sh — file ONE durable, deduped follow-up task for a
# CHRONIC fleet-health finding, so a persistent breach gets a tracked fix instead
# of being re-surfaced in the digest every 4h forever.
#
# Generalizes ot-alert-monitor's recurrence→auto-fix-task pattern (step 7.g/3b) to
# the fleet-health scans (zombie / training-age / perf) — the 14c class-sweep that
# was missing (operator 2026-06-05: "why doesn't your auto-fix step file a meta task
# for this?"). Same discipline: owner=dennyzhang (NEVER assign others), tag
# mrs-ot-reliability, dedup via a state file so it files EXACTLY ONCE per
# (model, signal), TASK only (never auto-land a config/code fix).
#
# Usage:
#   file-chronic-fleet-task.sh --eid <id> --signal <zombie|training-age|qps_down> \
#       --evidence "<one-line chronic evidence>" [--owner-unixname <model owner>] \
#       [--mast-url <url>] [--dry-run]
#
# Dedup: state file state/fleet-chronic-tasks.json maps "<eid>|<signal>" → {task, epoch}.
# If an entry exists, SKIP (print it). First time → create + record.
set -uo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${SRC_DIR}/state"
STATE="${STATE_DIR}/fleet-chronic-tasks.json"

EID="" SIGNAL="" EVIDENCE="" OWNER_UNIX="" MAST_URL="" CLASS="chronic" DRY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --eid) EID="$2"; shift 2 ;;
    --signal) SIGNAL="$2"; shift 2 ;;
    --evidence) EVIDENCE="$2"; shift 2 ;;
    --owner-unixname) OWNER_UNIX="$2"; shift 2 ;;
    --mast-url) MAST_URL="$2"; shift 2 ;;
    --class) CLASS="$2"; shift 2 ;;   # chronic | trending | new-noisy
    --dry-run) DRY=true; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$EID" && -n "$SIGNAL" ]] || { echo "need --eid and --signal" >&2; exit 2; }
mkdir -p "${STATE_DIR}"
[[ -f "$STATE" ]] || echo '{}' > "$STATE"

KEY="${EID}|${SIGNAL}"

# ---- dedup: already filed? ---------------------------------------------------
EXISTING=$(KEY="$KEY" python3 -c "import json,os;print(json.load(open('$STATE')).get(os.environ['KEY'],{}).get('task',''))" 2>/dev/null)
if [[ -n "$EXISTING" ]]; then
  echo "DEDUP: ${KEY} already tracked by ${EXISTING} — not refiling" >&2
  echo "$EXISTING"
  exit 0
fi

# §19 provenance: lead the title with the FILING JOB id (ot-fleet-health), not just
# the class — so an orphan task traces back to which cron filed it (+ searchable for dedup).
TITLE="[ot-fleet-health] ${CLASS}: mvai-training-online-${EID} — ${SIGNAL}"
DESC="Chronic OT fleet-health finding (auto-filed by ot-fleet-health).
Model: mvai-training-online-${EID}${MAST_URL:+  ($MAST_URL)}
Signal: ${SIGNAL}
Evidence: ${EVIDENCE:-persistent breach across recent fleet-health runs}
${OWNER_UNIX:+Suggested model owner (for the operator to route to — NOT yet subscribed): ${OWNER_UNIX}}

This is a TRACKING task — the fix is the model owner's call. HANDHOLD-FIRST (operator
2026-06-05: "all tasks go to me as handhold first"): owner=dennyzhang and NO other
person is subscribed/looped in — the operator reviews and routes to the owner. Closes
when the model holds within SLO; re-opens via the next chronic detection if it regresses."

if $DRY; then
  echo "[dry-run] would file task:" >&2
  echo "  title: ${TITLE}" >&2
  echo "  owner: dennyzhang  tags: mrs-ot-reliability, mvai-online-training  subscriber: NONE (handhold-first)" >&2
  echo "DRYRUN"
  exit 0
fi

# ---- create (owner=dennyzhang ALWAYS; HANDHOLD-FIRST: no other subscriber — the
# operator is the first/only touch and routes to the owner himself. 2026-06-05.) --
CREATE_ARGS=(--title="$TITLE" --description="$DESC" --owner=dennyzhang --priority=LOW
             --add-tag=mrs-ot-reliability --add-tag=mvai-online-training)
OUT=$(meta tasks.task create "${CREATE_ARGS[@]}" -o json 2>&1)
TID=$(printf '%s' "$OUT" | python3 -c "import sys,json
try:
 d=json.load(sys.stdin); print(d.get('number') or d.get('task') or d.get('id') or '')
except: print('')" 2>/dev/null)

if [[ -z "$TID" ]]; then
  echo "TASK CREATE FAILED: $(printf '%s' "$OUT" | head -2)" >&2
  echo "FAILED"
  exit 1
fi

# record in state (dedup for future runs)
NOW=$(date +%s)
KEY="$KEY" TID="$TID" NOW="$NOW" STATE="$STATE" python3 - <<'PY'
import json, os
s = json.load(open(os.environ['STATE'])) if os.path.exists(os.environ['STATE']) else {}
s[os.environ['KEY']] = {"task": os.environ['TID'], "epoch": int(os.environ['NOW'])}
json.dump(s, open(os.environ['STATE'], 'w'), indent=2)
PY
echo "filed ${TID} for ${KEY}" >&2
echo "$TID"
