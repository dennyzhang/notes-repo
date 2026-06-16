#!/bin/bash
# confirm-upstream-scribe.sh — CONFIRM from ground truth whether an OT model's
# scribe-lag symptom is actually CAUSED by upstream Scribe-quota admission-control
# throttling (the CL-003 / P57 UPSTREAM_INFRA class) — vs an inferred "a Scribe SEV
# is open, so blame it."
#
# WHY (operator rule, 2026-06-12 thread e78lVJptOAI): a high-confidence UPSTREAM_INFRA
# verdict must be backed by a metric that CONFIRMS THE LINK. The old P57 confirmation
# was "scribe lag exists + a Scribe/ZippyDB SEV is open" — coexistence, not causation.
# It mis-fires: 2026-06-12 the bot called 878102693 (ig_organic_feed_mtml) UPSTREAM_INFRA
# under S669133 ("root/Facebook/Feed over scribe quota"), but that model runs on
# root/Instagram/... and was NEVER scribe-quota-rejected → S669133 is not its cause.
#
# DECISIVE GROUND TRUTH: Scuba `mast_admission_control_decisions` logs every OT job's
# admission decision. A row with rejected=1 AND policy_name=ONLINE_TRAINING_SCRIBE_USAGE
# for this model's job = [VERIFIED] the job WAS scribe-quota-throttled (carries the
# tenant_path + the human "exceeds quota" reason). No such row = the scribe-quota SEV
# did NOT throttle this model → the UPSTREAM_INFRA attribution is [INFERRED] → cap
# confidence and look in-lane / for the real cause.
#
# Usage:
#   confirm-upstream-scribe.sh --model <ENTITY_ID> [--hours N] [--sev-tenant <substr>]
# --sev-tenant: optional; the throttled tenant from the SEV (e.g. "root/Facebook/Feed").
#   When given, also reports whether the model's own tenant matches (scope check).
#
# Output: one JSON line: {model, window_hours, verdict, scribe_quota_rejections,
#   tenant_path[], rejected_tenants[], note}.  verdict ∈ CONFIRMED | REFUTED | INCONCLUSIVE
set -uo pipefail

MODEL=""; HOURS=72; SEV_TENANT=""
while [ $# -gt 0 ]; do case "$1" in
  --model)      MODEL="$2";      shift 2 ;;
  --hours)      HOURS="$2";      shift 2 ;;
  --sev-tenant) SEV_TENANT="$2"; shift 2 ;;
  -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "{\"error\":\"unknown arg: $1\"}" >&2; exit 2 ;;
esac; done
[ -n "$MODEL" ] || { echo '{"error":"--model <ENTITY_ID> required"}'; exit 2; }

RAW=$(meta scuba.dataset query --dataset=mast_admission_control_decisions \
  --group-by=policy_name,rejected,tenant_path \
  --where="[{\"column\":\"hpc_job_name\",\"op\":\"substr\",\"values\":[\"${MODEL}\"]}]" \
  --hours="${HOURS}" -o json 2>/dev/null) || RAW=""
[ -z "${RAW}" ] && { echo "{\"model\":\"${MODEL}\",\"verdict\":\"INCONCLUSIVE\",\"note\":\"scuba query empty/failed (fail-open)\"}"; exit 0; }

printf '%s' "${RAW}" | MODEL="${MODEL}" HOURS="${HOURS}" SEV_TENANT="${SEV_TENANT}" python3 -c '
import sys, json, os
try:
    rows = json.load(sys.stdin)
except Exception:
    print(json.dumps({"model": os.environ["MODEL"], "verdict": "INCONCLUSIVE", "note": "unparseable scuba output"}))
    raise SystemExit
rows = rows if isinstance(rows, list) else rows.get("data", [])
model, hours, sev_tenant = os.environ["MODEL"], int(os.environ["HOURS"]), os.environ["SEV_TENANT"]

def hits(r):
    try: return int(r.get("Hits") or r.get("count") or r.get("Samples") or 0)
    except Exception: return 0

tenants = sorted({r.get("tenant_path") for r in rows if r.get("tenant_path") and r.get("tenant_path") != "null"})
rej = [r for r in rows if str(r.get("rejected")) == "1" and r.get("policy_name") == "ONLINE_TRAINING_SCRIBE_USAGE"]
rej_count = sum(hits(r) for r in rej)
rej_tenants = sorted({r.get("tenant_path") for r in rej if r.get("tenant_path")})

out = {"model": model, "window_hours": hours, "tenant_path": tenants, "scribe_quota_rejections": rej_count}
if rej_count > 0:
    out["verdict"] = "CONFIRMED"
    out["rejected_tenants"] = rej_tenants
    out["note"] = f"[VERIFIED] {rej_count} ONLINE_TRAINING_SCRIBE_USAGE rejection(s) in {hours}h on tenant {rej_tenants} -> scribe-quota throttling of THIS model is confirmed. UPSTREAM_INFRA high-confidence is earned."
elif not tenants:
    out["verdict"] = "INCONCLUSIVE"
    out["note"] = f"no admission-control rows for this model in {hours}h (idle / wrong window / job-name mismatch) -> cannot confirm; do not assert high confidence."
else:
    out["verdict"] = "REFUTED"
    out["note"] = (f"NO scribe-quota rejection for this model in {hours}h; it runs on tenant {tenants} and was never "
                   f"ONLINE_TRAINING_SCRIBE_USAGE-rejected -> a scribe-quota SEV is NOT the confirmed cause. "
                   f"Cap UPSTREAM_INFRA confidence to [INFERRED]/medium and look in-lane / for the real root.")
if sev_tenant:
    match = any(sev_tenant in t for t in tenants)
    out["sev_tenant"] = sev_tenant
    out["sev_tenant_match"] = match
    if not match and tenants:
        out["note"] += f" SCOPE MISMATCH: SEV tenant {sev_tenant!r} != model tenant {tenants}."
print(json.dumps(out, separators=(",", ":")))
'
