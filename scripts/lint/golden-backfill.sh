#!/usr/bin/env bash
# golden-backfill.sh — seed the cheatsheet-flywheel golden set from existing history.
#
# The golden set is the eval answer key: (situation, wrong, right) cases. We don't
# hand-author it — the diff learnings-log's "Common Mistakes" table already records
# exactly that (what happened = wrong | correct approach = right | source cite). This
# backfill parses those rows into golden cases so the eval isn't empty on day one
# (cold-start fix). Ongoing cases accrete from corrections via golden-collect (Phase 2).
#
# Usage: golden-backfill.sh [--dry-run]
set -uo pipefail
exec python3 - "$@" <<'PY'
import json, re, sys
from pathlib import Path

ROOT = Path.home() / "notes" / "users" / "dennyzhang"
SRC = ROOT / "cheatsheets" / "diff" / "diff-learnings-log.md"
OUT_DIR = ROOT / "projects" / "cheatsheet-flywheel" / "golden"
DRY = "--dry-run" in sys.argv[1:]

CITE = re.compile(r"\b(D\d{5,}|S\d{5,}|T\d{5,}|P\d{5,})\b")
DATE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
SENSITIVE = re.compile(r"\b(comp|salary|level target|1:1|performance review|PIP)\b", re.I)

def rows(text):
    in_section = False
    for line in text.splitlines():
        if line.startswith("## "):
            in_section = line.strip() == "## Common Mistakes"
            continue
        if not in_section or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 2:
            continue
        wrong, right = cells
        if wrong.lower().startswith("what happened") or set(wrong) <= {"-", " "}:
            continue
        yield wrong, right

if not SRC.exists():
    sys.exit("source not found: %s" % SRC)
cases, skipped = [], 0
for i, (wrong, right) in enumerate(rows(SRC.read_text()), 1):
    if SENSITIVE.search(wrong + " " + right):
        skipped += 1
        continue
    cite = CITE.search(right) or CITE.search(wrong)
    date = DATE.search(right) or DATE.search(wrong)
    cases.append({
        "id": "diff-bf-%03d" % i, "domain": "diff",
        "situation": wrong, "wrong": wrong, "right": right,
        "source": {"file": "cheatsheets/diff/diff-learnings-log.md",
                   "cite": cite.group(1) if cite else None,
                   "date": date.group(1) if date else None},
        "origin": "backfill:diff-learnings-log", "status": "candidate",
    })
print("parsed %d golden case(s); skipped %d (sensitive guard)" % (len(cases), skipped))
if DRY:
    print(json.dumps(cases[0], indent=2)[:300] if cases else "(none)")
    sys.exit(0)
OUT_DIR.mkdir(parents=True, exist_ok=True)
out = OUT_DIR / "diff.jsonl"
out.write_text("".join(json.dumps(c, ensure_ascii=False) + "\n" for c in cases))
print("wrote %d -> %s" % (len(cases), out.relative_to(ROOT)))
PY
