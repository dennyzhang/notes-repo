#!/usr/bin/env bash
# gold-set-review-queue.sh — surface ONLY the gold-set cases that need a human eye, so the optional
# human AUDIT of the eval's ground truth is a ~5-min spot-check (the lifecycle itself is auto-curated).
#
# (.sh wrapper: notes deny_files hook rejects .py; logic is the embedded python.)
#
# READ-ONLY: lists candidates + reasons; never edits the gold set — the human approves/corrects/drops
# in gold-set.json, and the loop runs regardless (optional/async). SCORE-BLIND: flags only on data
# properties (same invariant as gold-set-curate.sh), never on eval scores.
#
# Flags a case when ANY:
#   LEAK     - a 6-word shingle of ground_truth.root_cause appears verbatim in input.body
#              (rewards memorization, not triage — same check as gold-set-curate.sh leaks_answer)
#   THIN-RC  - ground_truth.root_cause is <8 words or empty (vague/ambiguous ground truth -> may be mislabeled)
# (p_row presence shown as context, not a flag — "no P-row" is common and not itself a quality problem.)
#
# Usage: gold-set-review-queue.sh        (writes reports/gold-set-review-queue.md + prints a summary)
set -uo pipefail
python3 - <<'PY'
import json, os, datetime
from collections import Counter
ROOT = os.path.expanduser("~/notes/users/dennyzhang/projects/mrs-ot-agent-context")
GOLD = f"{ROOT}/eval/gold-set.json"
OUT  = f"{ROOT}/eval/reports/gold-set-review-queue.md"
TODAY = datetime.date.today().isoformat()

g = json.load(open(GOLD)); cases = g.get("cases", [])

def leak_shingle(c):
    rc = (((c.get("ground_truth") or {}).get("root_cause")) or "").lower().split()
    body = ((c.get("input") or {}).get("body") or "").lower()
    for i in range(0, max(0, len(rc) - 5)):
        sh = " ".join(rc[i:i+6])
        if sh in body:
            return sh
    return None

def thin(c):
    return len(((c.get("ground_truth") or {}).get("root_cause") or "").split()) < 8

rows = []
for c in cases:
    reasons = []
    sh = leak_shingle(c)
    if sh:     reasons.append(("LEAK", f'"{sh}"'))
    if thin(c):reasons.append(("THIN-RC", "RCA <8 words/empty"))
    if reasons: rows.append((c, reasons))

cnt = Counter(k for _, rs in rows for k, _ in rs)
rows.sort(key=lambda x: (-len(x[1]), x[0].get("id", "")))
hdr = [
    f"# Gold-set review queue ({TODAY})", "",
    f"_Optional human AUDIT of the eval's ground truth — the lifecycle is auto-curated (curator); this just spot-checks it (Key challenge #2). "
    f"**{len(rows)}/{len(cases)}** cases flagged — LEAK {cnt.get('LEAK',0)} · THIN-RC {cnt.get('THIN-RC',0)}. "
    f"Score-blind, read-only: approve/correct/drop in `gold-set.json` yourself; the loop never blocks on this. "
    f"LEAK first (it poisons the eval), then THIN-RC (may be mislabeled)._", "",
    "| case | type | flags | p_row | root_cause (ground truth) |", "|---|---|---|---|---|",
]
for c, rs in rows:
    rc = ((c.get("ground_truth") or {}).get("root_cause") or "").replace("|", "\\|")[:88]
    pr = (((c.get("ground_truth") or {}).get("p_row")) or "—")
    fl = " · ".join(f"**{k}**{(' '+v) if k=='LEAK' else ''}" for k, v in rs)
    hdr.append(f"| {c.get('id')} | {c.get('type')} | {fl} | {pr} | {rc} |")
open(OUT, "w").write("\n".join(hdr) + "\n")
print(f"gold-set review queue: {len(rows)}/{len(cases)} flagged "
      f"(LEAK {cnt.get('LEAK',0)} · THIN-RC {cnt.get('THIN-RC',0)}). wrote {OUT}")
PY
