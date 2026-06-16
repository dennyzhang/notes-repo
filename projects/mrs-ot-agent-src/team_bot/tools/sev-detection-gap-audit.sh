#!/usr/bin/env bash
# sev-detection-gap-audit.sh — INDEPENDENT detection-coverage audit.
#
# OT analog of the PE MRS ML team's "SEV audit for lightweight-test gap"
# (Andrew Mao / Ezra Khuzadi, 2026-06-08): for each resolved OT SEV, ask
# "did automated detection catch this — and if not, that's the gap to close."
#
# Standalone by design (operator directive 2026-06-08, thread S-j4aTzRKng:
# "build independent job to avoid dependencies"): own script, own state, own
# schedule. No coupling to the distillation pipeline or its corpus.
#
# Signal = the SEV's OWN `auto_detected` field (always available, no substrate
# dependency — unlike alert-firing history, which is too young to be reliable):
#   COVERED — auto_detected=true  (an alarm/detector opened the SEV)
#   GAP     — auto_detected=false (human-filed via employee-reports / dashboards
#             / manual → NO automated detector caught it = detection gap)
#
# Usage: sev-detection-gap-audit.sh [--days=N] [--max=M]
# Final line: GAPAUDIT resolved=N covered=C gap=G skipped=S

set -uo pipefail
DAYS=14
MAX=40
for a in "$@"; do case "$a" in
  --days=*) DAYS="${a#--days=}" ;;
  --max=*)  MAX="${a#--max=}" ;;
  *) echo "unknown arg: $a" >&2; exit 1 ;;
esac; done
export DAYS MAX

SEV_JSON="$(mktemp -t sev-gap-audit.XXXXXX)"
trap 'rm -f "$SEV_JSON"' EXIT
meta sevmanager.sev list --tags=mvai-online-training --limit=150 -o json >"$SEV_JSON" 2>/dev/null

python3 - "$SEV_JSON" <<'PY'
import os, json, sys, re, datetime, subprocess
DAYS=int(os.environ["DAYS"]); MAX=int(os.environ["MAX"])
raw=open(sys.argv[1]).read()
i=raw.find("["); j=raw.rfind("]")
try: sevs=json.loads(raw[i:j+1]) if i!=-1 and j>i else json.loads(raw)
except Exception:
    print("GAPAUDIT resolved=0 covered=0 gap=0 skipped=0 err=sev_list_parse"); sys.exit(0)

def epoch(s):
    s=str(s or "")[:19].replace("T"," ")
    try: return datetime.datetime.strptime(s,"%Y-%m-%d %H:%M:%S").timestamp()
    except Exception: return None

RESOLVED={"closed","mitigated","resolved"}
now=datetime.datetime.now().timestamp(); cutoff=now-DAYS*86400
# Candidate = resolved + created within window. Newest first; cap at MAX describe calls.
cand=[]
for s in sevs:
    if str(s.get("status","")).strip().lower() not in RESOLVED: continue
    c=epoch(s.get("created"))
    if c is None or c<cutoff: continue
    cand.append((c, s.get("sev_number") or s.get("number"), str(s.get("title",""))))
cand.sort(reverse=True); cand=cand[:MAX]

cov=gap=skip=0; gaps=[]
for _, num, title in cand:
    if not num: skip+=1; continue
    try:
        out=subprocess.run(["meta","sevmanager.sev","describe","--sev",str(num)],
                           capture_output=True, text=True, timeout=30).stdout
    except Exception:
        skip+=1; continue
    mauto=re.search(r"auto_detected:\s*(\w+)", out)
    mdet=re.search(r"detection_method_tags:[ \t]*([^\n]*)", out)
    if not mauto: skip+=1; continue
    method=(mdet.group(1).strip() if mdet else "").split("/")[0].strip() or "unknown"
    if mauto.group(1).lower()=="true":
        cov+=1
    else:
        gap+=1; gaps.append(f"{num} [{method}]: {title[:64]}")

if gaps:
    print(f"DETECTION GAPS — resolved OT SEV with NO automated detector (last {DAYS}d):")
    for g in gaps: print("  •", g)
print(f"GAPAUDIT resolved={len(cand)} covered={cov} gap={gap} skipped={skip}")
PY
