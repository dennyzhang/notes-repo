#!/usr/bin/env bash
# add-known-issue.sh — append/refresh an entry in the OT known-issues registry.
# A known issue annotates a (model_eid, signal) so the fleet-health renderer marks
# that finding KNOWN (owner already on it) instead of re-alerting it as new — until
# it EXPIRES, after which a still-present finding re-surfaces loudly for re-triage.
#
# Usage:
#   add-known-issue.sh --eid 2123944781 --signal training-age \
#       --owners haosha3 [--cause trainer-behind] [--summary "..."] \
#       [--ttl-days 14] [--ref "url-or-note"]
#   signal ∈ zombie | training-age | qps_down | '*'   (* = any signal for that model)
#
# Re-running for the same (eid, signal) REPLACES the entry (re-arms the timer) —
# that's the deliberate "extend a known issue after re-triage" path.
set -euo pipefail
REG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../mrs-ot-agent-context/state/known-issues" && pwd)/registry.json"

EID="" SIGNAL="" OWNERS="" CAUSE="" SUMMARY="" REF="" TTL=14
while [[ $# -gt 0 ]]; do
  case "$1" in
    --eid) EID="$2"; shift 2 ;;
    --signal) SIGNAL="$2"; shift 2 ;;
    --owners) OWNERS="$2"; shift 2 ;;        # comma-separated
    --cause) CAUSE="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --ttl-days) TTL="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$EID" && -n "$SIGNAL" ]] || { echo "need --eid and --signal" >&2; exit 2; }

SYNCED=$(date +%Y-%m-%d)
EXPIRES=$(date -d "+${TTL} days" +%Y-%m-%d)

EID="$EID" SIGNAL="$SIGNAL" OWNERS="$OWNERS" CAUSE="$CAUSE" SUMMARY="$SUMMARY" \
REF="${REF:-owner-synced ${SYNCED}}" SYNCED="$SYNCED" EXPIRES="$EXPIRES" REG="$REG" \
python3 - <<'PY'
import json, os
reg = os.environ["REG"]
with open(reg) as fh:
    d = json.load(fh)
e = {
    "model_eid": os.environ["EID"],
    "signal": os.environ["SIGNAL"],
    "cause": os.environ["CAUSE"],
    "summary": os.environ["SUMMARY"],
    "owners": [o for o in os.environ["OWNERS"].split(",") if o],
    "synced": os.environ["SYNCED"],
    "expires": os.environ["EXPIRES"],
    "ref": os.environ["REF"],
    "status": "active",
}
# replace any existing entry for the same (eid, signal) — re-arms the timer
d["issues"] = [i for i in d["issues"]
               if not (i["model_eid"] == e["model_eid"] and i["signal"] == e["signal"])]
d["issues"].append(e)
with open(reg, "w") as fh:
    json.dump(d, fh, indent=2)
    fh.write("\n")
print(f"known-issue set: {e['model_eid']} / {e['signal']} → @{','.join(e['owners']) or '?'} "
      f"expires {e['expires']} ({len(d['issues'])} active)")
PY
