#!/usr/bin/env bash
# add-expected-delta.sh — record an ACCEPTED regression/improvement (the "expected-delta" KB tier).
#
# DISTINCT from known-issues: a known-issue is NOT real (suppress noise); an expected-delta IS real
# but ACCEPTED over a bounded range (a regression we'll pay for, or an expected win). Kept in a
# SEPARATE registry so trust accounting stays honest (idea from the Shepherd KB design, 2026-06-12).
#
# READ contract (monitors apply before paging a metric move): if a finding's (model, signal) is in
# this registry, IN-RANGE, NOT expired, and within the magnitude bound → annotate
# "expected — <reason>", do NOT page. If it EXCEEDS the bound, is out of range, or expired → FIRE.
# (Bigger-than-declared still fires — that's the point of the magnitude bound.)
#
# WRITE = human-authored (launch/diff owner). Agents READ only; they never author an accepted delta.
#
# Usage:
#   add-expected-delta.sh --eid 2123944781 --signal NE \
#       --direction regression --magnitude "5%" --range "v340..v360" \
#       --reason "MB10 arch change, accepted to launch" [--ref "T123/D456"] \
#       [--marked-by dennyzhang] [--ttl-days 21]
#   --range is MANDATORY and bounded (commit/RC/version/date window) — never open-ended.
#   Re-running for the same (eid, signal) REPLACES the entry (re-arms the window).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../mrs-ot-agent-context/state" && pwd)/expected-deltas"
REG="$DIR/registry.json"
mkdir -p "$DIR"; [[ -f "$REG" ]] || echo '{"deltas": []}' > "$REG"

EID="" SIGNAL="" DIR_="" MAG="" RANGE="" REASON="" REF="" BY="${USER:-dennyzhang}" TTL=21
while [[ $# -gt 0 ]]; do
  case "$1" in
    --eid) EID="$2"; shift 2 ;;
    --signal) SIGNAL="$2"; shift 2 ;;           # counter/metric: NE, calibration, qps, …
    --direction) DIR_="$2"; shift 2 ;;          # regression | improvement
    --magnitude) MAG="$2"; shift 2 ;;           # accepted bound; beyond this still FIRES
    --range) RANGE="$2"; shift 2 ;;             # bounded: vNNN..vMMM | date..date | RC window
    --reason) REASON="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --marked-by) BY="$2"; shift 2 ;;
    --ttl-days) TTL="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$EID" && -n "$SIGNAL" && -n "$RANGE" && -n "$MAG" ]] || {
  echo "need --eid, --signal, --magnitude, and (mandatory, bounded) --range" >&2; exit 2; }
case "$DIR_" in regression|improvement) ;; *) echo "--direction must be regression|improvement" >&2; exit 2 ;; esac

SYNCED=$(date +%Y-%m-%d); EXPIRES=$(date -d "+${TTL} days" +%Y-%m-%d)
EID="$EID" SIGNAL="$SIGNAL" DIR_="$DIR_" MAG="$MAG" RANGE="$RANGE" REASON="$REASON" \
REF="${REF:-}" BY="$BY" SYNCED="$SYNCED" EXPIRES="$EXPIRES" REG="$REG" python3 - <<'PY'
import json, os
reg = os.environ["REG"]
with open(reg) as fh: d = json.load(fh)
e = {
    "model_eid": os.environ["EID"], "signal": os.environ["SIGNAL"],
    "direction": os.environ["DIR_"], "magnitude_bound": os.environ["MAG"],
    "range": os.environ["RANGE"], "reason": os.environ["REASON"],
    "ref": os.environ["REF"], "marked_by": os.environ["BY"], "marked_at": os.environ["SYNCED"],
    "expires": os.environ["EXPIRES"], "status": "active",
}
d["deltas"] = [x for x in d.get("deltas", [])
               if not (x["model_eid"] == e["model_eid"] and x["signal"] == e["signal"])]
d["deltas"].append(e)
with open(reg, "w") as fh: json.dump(d, fh, indent=2); fh.write("\n")
print(f"expected-delta set: {e['model_eid']} / {e['signal']} {e['direction']} "
      f"≤{e['magnitude_bound']} over {e['range']} — expires {e['expires']} "
      f"({len(d['deltas'])} active). Real-but-accepted; beyond bound still fires.")
PY
