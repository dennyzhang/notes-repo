#!/bin/bash
# normalize-shift-timeline-fonts.sh — DETERMINISTIC fix for the recurring shift-doc
# "font mess up" bug (T275803195). The ot-shift-summary mid-shift incremental uses
# `gdocs content insert-html --after-heading`, which makes inserted Daily-Timeline
# entries INHERIT the day-heading's paragraph style (HEADING_3/4 = big font) instead
# of NORMAL_TEXT (11pt). The cron had a PROSE "mandatory post-insert font read-back"
# rule that kept getting skipped → the bug recurred (operator: "why font mess up
# again?" on tabs 6/9 and 6/16). This script makes the normalization DETERMINISTIC:
# every Daily-Timeline ENTRY paragraph (everything that is NOT a `M/D (Weekday)` day
# heading) is forced to NORMAL_TEXT; day headings stay HEADING_4.
#
# It is also a LINT: with --check it exits non-zero if any entry is mis-styled
# (wire into the render gate so a run cannot finish "clean" while the bug is present).
#
# DAEMON NUANCE (cheatsheets/gdocs/rules.md): on this large untrusted doc, FETCHES
# (`get-structure`) hang under the daemon → use --no-daemon; small WRITES
# (`batch-update`) hang under --no-daemon → use the daemon. This script does exactly that.
#
# Usage:
#   normalize-shift-timeline-fonts.sh <DOC_ID> <TAB_ID> [--apply | --check]
#     (default = dry-run: print what WOULD change, exit 0)
#     --apply : apply the NORMAL_TEXT batch-update, then re-verify (exit 1 if any remain)
#     --check : lint only — exit 1 if any entry is mis-styled, change nothing
set -uo pipefail

DOC="${1:?DOC_ID required}"; TAB="${2:?TAB_ID required}"; MODE="${3:---dry-run}"
GFLAGS="--untrusted-authors-mode"

get_struct() { timeout 120 gdocs content get-structure "$DOC" --tab-id "$TAB" $GFLAGS --no-daemon 2>/dev/null; }

# Emit JSON: {"ranges":[[s,e],...]} of Daily-Timeline ENTRY paragraphs that are NOT NORMAL_TEXT.
find_misstyled() {
  get_struct | python3 -c '
import sys, re, json
pat_line = re.compile(r"^\[(\d+)-(\d+)\]\s+([A-Z0-9_]+):\s*\"(.*)\"\s*$")
pat_day  = re.compile(r"^\s*\d{1,2}/\d{1,2}\s*\(")          # "6/11 (Thursday)"
in_tl = False
ranges = []
for ln in sys.stdin:
    m = pat_line.match(ln.rstrip("\n"))
    if not m: continue
    s, e, style, text = int(m.group(1)), int(m.group(2)), m.group(3), m.group(4)
    if not in_tl:
        if style.startswith("HEADING") and text.strip() == "Daily Timeline":
            in_tl = True
        continue
    # End the section at the "Local notes (Bot" terminal label or a new top-level heading
    if text.strip().startswith("Local notes"):
        break
    if pat_day.match(text):
        continue                      # day heading — leave as-is (HEADING_4)
    if style != "NORMAL_TEXT":
        ranges.append([s, e])         # mis-styled entry → normalize
print(json.dumps({"ranges": ranges}))
'
}

RANGES_JSON="$(find_misstyled)"
COUNT=$(printf '%s' "$RANGES_JSON" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["ranges"]))' 2>/dev/null || echo "ERR")
[ "$COUNT" = "ERR" ] && { echo "ERROR: could not parse doc structure (fetch failed?)"; exit 2; }

echo "[normalize-shift-timeline-fonts] mis-styled Daily-Timeline entries: $COUNT"
[ "$COUNT" = "0" ] && { echo "OK: all timeline entries are NORMAL_TEXT."; exit 0; }

if [ "$MODE" = "--check" ]; then
  echo "LINT FAIL: $COUNT timeline entry paragraph(s) are not NORMAL_TEXT (run with --apply to fix)."
  printf '%s\n' "$RANGES_JSON"
  exit 1
fi
if [ "$MODE" = "--dry-run" ]; then
  echo "DRY-RUN: would normalize $COUNT range(s) to NORMAL_TEXT. Re-run with --apply."
  printf '%s\n' "$RANGES_JSON"
  exit 0
fi
if [ "$MODE" != "--apply" ]; then echo "unknown mode: $MODE"; exit 2; fi

# --apply: build the batch-update requests and apply via the DAEMON (writes hang under --no-daemon).
REQ=$(printf '%s' "$RANGES_JSON" | TAB="$TAB" python3 -c '
import sys, json, os
tab = os.environ["TAB"]
rs = json.load(sys.stdin)["ranges"]
reqs = [{"updateParagraphStyle": {
    "range": {"startIndex": s, "endIndex": e, "tabId": tab},
    "paragraphStyle": {"namedStyleType": "NORMAL_TEXT"},
    "fields": "namedStyleType"}} for s, e in rs]
print(json.dumps(reqs))
')
echo "$REQ" > /tmp/normalize-shift-fonts-req.json
timeout 120 gdocs batch-update "$DOC" --data @/tmp/normalize-shift-fonts-req.json $GFLAGS >/dev/null 2>&1
rc=$?
[ $rc -ne 0 ] && { echo "ERROR: batch-update failed (rc=$rc)"; exit 2; }

# Re-verify (idempotent): re-fetch and assert zero remain.
REMAIN=$(find_misstyled | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["ranges"]))' 2>/dev/null || echo ERR)
echo "[normalize-shift-timeline-fonts] applied $COUNT; remaining after re-verify: $REMAIN"
[ "$REMAIN" = "0" ] && { echo "OK: normalized."; exit 0; }
echo "WARN: $REMAIN still mis-styled after apply — investigate."; exit 1
