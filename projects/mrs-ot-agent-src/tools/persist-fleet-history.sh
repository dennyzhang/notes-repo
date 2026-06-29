#!/usr/bin/env bash
# persist-fleet-history.sh — append one fleet-health run's STRUCTURED scan output
# to an append-only history store so we can do trend retros later (chronic vs
# transient models, age-distribution drift, regression frequency per PG, MTTR).
#
# Deterministic persistence — runs in the scan path, NOT the cron prompt (the
# LLM skips per-item compute; see memory per-item-compute-belongs-in-scan-not-prompt).
# The cron renders the human digest from the SAME JSON it persists here.
#
# We store the STRUCTURED findings, never the rendered chat message — the digest
# is for humans, the JSON is what a retro needs.
#
# Usage:
#   persist-fleet-history.sh --zombie F1 --zombie-rc R1 \
#                            --scribe F2 --scribe-rc R2 \
#                            --perf   F3 --perf-rc   R3 [--run-ts EPOCH] [--dry-run]
# where F* are files containing each scan's raw stdout (JSON lines; perf also
# carries a trailing {"summary":...} line). R* are the scans' exit codes
# (0=problems, 1=clean, 2=error/timeout).
#
# Writes one JSON object (one line) to:
#   <context>/state/fleet-health-history/YYYY-MM/runs.jsonl
# keyed by run_ts → idempotent (a re-run with the same run_ts replaces, never dups).
# notes-only runtime corpus (survives reinstall, NOT mirrored to fbcode).
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT_DIR="$(cd "${SRC_DIR}/../mrs-ot-agent-context" && pwd)"
HIST_ROOT="${CONTEXT_DIR}/state/fleet-health-history"

Z_FILE="" S_FILE="" P_FILE="" N_FILE=""
Z_RC="" S_RC="" P_RC="" N_RC=""
RUN_TS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zombie)    Z_FILE="$2"; shift 2 ;;
    --zombie-rc) Z_RC="$2";   shift 2 ;;
    --scribe)    S_FILE="$2"; shift 2 ;;
    --scribe-rc) S_RC="$2";   shift 2 ;;
    --perf)      P_FILE="$2"; shift 2 ;;
    --perf-rc)   P_RC="$2";   shift 2 ;;
    --ne)        N_FILE="$2"; shift 2 ;;
    --ne-rc)     N_RC="$2";   shift 2 ;;
    --run-ts)    RUN_TS="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# NE is optional (4th persisted scan; legacy callers omit it → recorded absent,
# never blocks the run). zombie/scribe/perf stay required.
for v in Z_FILE S_FILE P_FILE; do
  [[ -n "${!v}" ]] || { echo "missing required arg for ${v}" >&2; exit 2; }
done
# An empty scan rc (e.g. a scan that timed out / whose $? wasn't captured) must NOT drop the
# entire history entry. Coerce empty -> 2 (error): the run is still recorded, marked unhealthy
# for that scan, instead of silently no-op'd. (2026-06-10 root-fix: empty rc -> exit 2 -> the
# run-fleet-health.sh caller swallows it as "persist failed (non-fatal)" -> green-but-empty
# history; effect-monitor caught a 23h gap on the 06-09 14:06 run. A loud error entry beats a
# silent drop. Upstream: run-fleet-health.sh should always capture each scan's rc.)
for v in Z_RC S_RC P_RC; do
  [[ -n "${!v}" ]] || { echo "WARN: ${v} empty (scan rc not captured) — coercing to 2/error" >&2; printf -v "$v" '2'; }
done
# NE: only coerce-to-error when the FILE was supplied but its rc wasn't captured.
if [[ -n "${N_FILE}" && -z "${N_RC}" ]]; then
  echo "WARN: N_RC empty (ne scan rc not captured) — coercing to 2/error" >&2; N_RC=2
fi
[[ -n "${RUN_TS}" ]] || RUN_TS="$(date +%s)"

RUN_MONTH="$(date -d "@${RUN_TS}" +%Y-%m)"
RUN_ISO="$(date -d "@${RUN_TS}" -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_DIR="${HIST_ROOT}/${RUN_MONTH}"
OUT_FILE="${OUT_DIR}/runs.jsonl"

# Build the run object deterministically in python (robust JSON assembly;
# pulls findings = lines that parse as a JSON object, splits perf's summary line).
RUN_OBJ="$(
  RUN_TS="${RUN_TS}" RUN_ISO="${RUN_ISO}" \
  Z_FILE="${Z_FILE}" Z_RC="${Z_RC}" \
  S_FILE="${S_FILE}" S_RC="${S_RC}" \
  P_FILE="${P_FILE}" P_RC="${P_RC}" \
  N_FILE="${N_FILE}" N_RC="${N_RC}" \
  python3 - <<'PY'
import json, os

def rc_label(rc):
    return {"0": "problems", "1": "clean", "2": "error"}.get(str(rc).strip(), "unknown")

def parse(path):
    findings, summary, bad = [], None, 0
    try:
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if not line or not line.startswith("{"):
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    bad += 1
                    continue
                if isinstance(obj, dict) and "summary" in obj and len(obj) == 1:
                    summary = obj["summary"]
                else:
                    findings.append(obj)
    except FileNotFoundError:
        pass
    return findings, summary, bad

def scan(path, rc):
    findings, summary, bad = parse(path)
    s = {"rc": int(rc) if str(rc).strip().lstrip("-").isdigit() else None,
         "status": rc_label(rc),
         "count": len(findings),
         "findings": findings}
    if summary is not None:
        s["summary"] = summary
    if bad:
        s["unparsed_lines"] = bad
    return s

z = scan(os.environ["Z_FILE"], os.environ["Z_RC"])
s = scan(os.environ["S_FILE"], os.environ["S_RC"])
p = scan(os.environ["P_FILE"], os.environ["P_RC"])
# NE is optional: persist it only when a file was supplied (back-compat with
# callers that don't pass --ne). Absent → not in scans/totals, not in healthy.
n_file = os.environ.get("N_FILE", "")
n = scan(n_file, os.environ.get("N_RC", "2")) if n_file else None

scans = {"zombie": z, "scribe_age": s, "perf": p}
totals = {"zombie": z["count"], "training_age": s["count"], "perf": p["count"]}
healthy_parts = [z, s, p]
if n is not None:
    scans["ne"] = n
    totals["ne"] = n["count"]
    healthy_parts.append(n)

healthy = all(x["rc"] == 1 for x in healthy_parts)
run = {
    "run_ts": int(os.environ["RUN_TS"]),
    "run_iso": os.environ["RUN_ISO"],
    "healthy": healthy,
    "totals": totals,
    "scans": scans,
}
print(json.dumps(run, separators=(",", ":")))
PY
)"

if [[ -z "${RUN_OBJ}" ]]; then
  echo "persist failed: empty run object" >&2
  exit 2
fi

if ${DRY_RUN}; then
  echo "${RUN_OBJ}"
  echo "[dry-run] would append to ${OUT_FILE}" >&2
  exit 0
fi

mkdir -p "${OUT_DIR}"
# Idempotent on run_ts: drop any existing line with the same run_ts, then append.
if [[ -f "${OUT_FILE}" ]]; then
  tmp="$(mktemp)"
  RUN_TS="${RUN_TS}" python3 - "${OUT_FILE}" >"${tmp}" <<'PY'
import json, os, sys
keep, target = [], int(os.environ["RUN_TS"])
with open(sys.argv[1]) as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line.strip():
            continue
        try:
            if json.loads(line).get("run_ts") == target:
                continue
        except json.JSONDecodeError:
            pass  # keep malformed lines untouched rather than dropping data
        keep.append(line)
# Write each kept line with its own newline; emit NOTHING when empty so we
# never leave a blank line behind (the idempotency-rewrite bug, 2026-06-05).
sys.stdout.write("".join(l + "\n" for l in keep))
PY
  mv "${tmp}" "${OUT_FILE}"
fi
printf '%s\n' "${RUN_OBJ}" >> "${OUT_FILE}"

echo "persisted run ${RUN_ISO} → ${OUT_FILE} ($(grep -c '^{' "${OUT_FILE}") runs in ${RUN_MONTH})" >&2
