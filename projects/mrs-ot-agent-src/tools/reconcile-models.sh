#!/bin/bash
# reconcile-models.sh — bidirectional freshness check for human-input/models.md:
#   MISSING = live online-training models not in the file (ADD them)
#   STALE   = tracked rows whose job is no longer RUNNING (consider PRUNING)
#
# WHY: models.md was historically built by hand from LOCALLY-archived incidents only,
# so it drifted stale (30 tracked while 65 were actually live — 2026-06-04 reconcile,
# thread 81e8ef35). This queries the real incident history + filters to RUNNING jobs.
#
# Method: candidate model IDs = (SEVs tagged mvai-online-training) ∪ (incident archives)
#   → minus already-tracked → keep only those whose mvai-training-online-<id> MAST job is
#   RUNNING/PENDING (live online-training model) → that's the missing set.
# Output: missing model IDs + status (enrich via `meta ai.mast-job metadata` and add to models.md).
# READ-ONLY: reports both gaps; does NOT auto-edit models.md (operator/agent reviews,
# edits, then runs tools/validate-models.py before committing).
set -uo pipefail
SRC="$(dirname "$0")/.."
CTX="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
grep -P '^\|' "$SRC/human-input/models.md" | grep -oP 'entity_id=\K\d+' | sort -u > "$TMP/tracked"
{ grep -rhoP 'mvai-training-online-\K\d+' "$CTX/incidents" "$CTX/auto-learnings" 2>/dev/null
  grep -rhoP '(?:entity_id|model[_-]?id|model_entity_id)["=:[:space:]]+\K\d{9,10}' "$CTX/incidents" 2>/dev/null
} | sort -u > "$TMP/incident"
comm -23 "$TMP/incident" "$TMP/tracked" > "$TMP/cand"
echo "tracked=$(wc -l <$TMP/tracked) incident=$(wc -l <$TMP/incident) candidates=$(wc -l <$TMP/cand)" >&2

# job_status <id> -> echoes the MAST status (RUNNING/PENDING/.../<empty if no job>)
job_status() {
  timeout 25 meta ai.mast-job metadata --name="mvai-training-online-$1" -o json 2>/dev/null \
    | python3 -c "import sys,json;print(json.load(sys.stdin).get('status',''))" 2>/dev/null
}
export -f job_status

# --- MISSING: incident-known models that are LIVE but NOT in models.md (ADD them) ---
echo "## MISSING (live online-training, untracked — ADD to models.md):"
cat "$TMP/cand" | xargs -P 12 -I {} bash -c '
  st=$(job_status "$1"); case "$st" in RUNNING|PENDING|SCHEDULED) echo "$1|$st";; esac' _ {} | sort

# --- STALE: tracked in models.md but the job is NO LONGER running (consider PRUNE) ---
# Closes the inverse gap: the file says "Excluded: DEAD jobs" but nothing detected a
# tracked model going dead. Bidirectional reconcile = the file stays fresh both ways.
echo "## STALE (tracked but job not RUNNING — consider PRUNING from models.md):"
cat "$TMP/tracked" | xargs -P 12 -I {} bash -c '
  st=$(job_status "$1"); case "$st" in RUNNING|PENDING|SCHEDULED) : ;; *) echo "$1|${st:-NO_JOB}";; esac' _ {} | sort
