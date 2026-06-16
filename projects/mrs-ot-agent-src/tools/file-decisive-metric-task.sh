#!/bin/bash
# file-decisive-metric-task.sh — operationalizes P-017 (upstream recurring issue
# → decisive-metric task, not narration). Shared helper any detector calls when
# it identifies a RECURRING + HIGH-CONFIDENCE + UPSTREAM issue (root cause outside
# this lane: core/another team/unlanded dep). Files ONE deduped, handhold-first
# task whose deliverable is "build a decisive ground-truth metric query that
# confirms the issue AND is the acceptance test for the upstream fix."
#
# WHY a mechanism, not prose: P-017 as a written principle won't reliably fire
# (proven 2026-06-09 — a prose self-check was skipped in the same message that
# proposed it). The detector must auto-create the task; that's the enforcement.
#
# Usage:
#   file-decisive-metric-task.sh <issue_key> <one_line_desc> [root_cause_task] [upstream_owner] [--dry-run]
#     issue_key      stable slug identifying the issue (used for dedup; e.g. "team-space-delivery-precision")
#     one_line_desc  human description of the upstream issue
#     root_cause_task optional T#### of the root-cause/fix task to link
#     upstream_owner  optional who owns the upstream fix (team/oncall/"myclaw-core")
#
# Dedup: skips if an OPEN owner=dennyzhang task tagged `ot-upstream-decisive-metric`
# already has <issue_key> in its title. Handhold-first: owner=dennyzhang ONLY,
# no other assignee/subscriber (operator routes). Output: one line — TASK_CREATED:T####
# | DEDUP_SKIP:T#### | DRY_RUN | ERROR:<reason>.
set -uo pipefail
TAG="ot-upstream-decisive-metric"

ISSUE_KEY="${1:-}"; DESC="${2:-}"; ROOT_TASK="${3:-}"; UPSTREAM_OWNER="${4:-unknown}"
DRY_RUN=0; for a in "$@"; do [ "$a" = "--dry-run" ] && DRY_RUN=1; done
[ -z "$ISSUE_KEY" ] || [ -z "$DESC" ] && { echo "ERROR:usage issue_key + one_line_desc required"; exit 2; }

# ---- dedup: any OPEN owner=dennyzhang task tagged TAG with issue_key in title ----
EXISTING="$(meta tasks.task list --owner-is=dennyzhang --status-is=Open --tags-include-any-of="$TAG" -o json 2>/dev/null \
  | ISSUE_KEY="$ISSUE_KEY" python3 -c '
import json,sys,os
key=os.environ["ISSUE_KEY"].lower()
try: rows=json.load(sys.stdin)
except: rows=[]
rows = rows if isinstance(rows,list) else rows.get("tasks",[])
for t in rows:
    if key in (t.get("title") or "").lower():
        print(t.get("number") or t.get("id")); break
' 2>/dev/null)"
# tolerate the not-yet-used-tag error (treat as none); EXISTING empty => none found
if [ -n "$EXISTING" ]; then echo "DEDUP_SKIP:${EXISTING}"; exit 0; fi

LINK=""; [ -n "$ROOT_TASK" ] && LINK="Root-cause / fix task: ${ROOT_TASK}. "
TITLE="[${TAG}] build decisive query to confirm upstream issue: ${ISSUE_KEY}"
BODY="Auto-filed per P-017 (upstream recurring + high-confidence issue → decisive-metric task, not narration). Filed by a detector that saw this issue recur with high confidence and a root cause OUTSIDE this lane (upstream owner: ${UPSTREAM_OWNER}).

Issue: ${DESC}

${LINK}DELIVERABLE (P-017):
1. Build a DECISIVE metric query — deterministic, reproducible, from an AUTHORITATIVE ground-truth source (not narration, not an ingestion/cache log); encode known confounds.
2. Run it; record the CONFIRMED baseline number in this task.
3. Set a numeric ACCEPTANCE THRESHOLD that defines 'fixed' (the task closes when the metric crosses it, not when prose says so).
4. Then MONITOR the metric — do NOT re-narrate the symptom on each recurrence.

Pattern reference: tools/team-space-precision.sh (founding instance, T275122535). Handhold-first: owner=dennyzhang; operator routes/closes."

if [ "$DRY_RUN" = "1" ]; then
  echo "DRY_RUN: would create owner=dennyzhang priority=MID tag=${TAG} title='${TITLE}'"; exit 0
fi

OUT="$(meta tasks.task create --title="$TITLE" --description="$BODY" \
  --owner=dennyzhang --priority=MID --add-tag="$TAG" -o json 2>&1)"
TID="$(echo "$OUT" | python3 -c 'import json,sys
try: d=json.load(sys.stdin); print(d.get("number") or d.get("id") or "")
except: print("")' 2>/dev/null)"
[ -n "$TID" ] && echo "TASK_CREATED:${TID}" || echo "ERROR:create_failed ${OUT:0:160}"
