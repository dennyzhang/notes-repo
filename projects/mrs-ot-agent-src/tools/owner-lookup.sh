#!/usr/bin/env bash
# owner-lookup.sh — DETERMINISTIC model → owning-team/oncall lookup for triage.
#
# WHY THIS EXISTS: the eval's weakest fitness dimension is owner_routing (~0.36).
# Routing a model to its owning team/oncall is a LOOKUP, not a reasoning task —
# the master agent should never *guess* an owner. This resolves it from ground
# truth in two deterministic hops:
#
#   1. model_id (entity_id) OR model_type  --(human-input/models.md)-->  owner unixname
#   2. owner unixname  --(meta people.profile get)-->  { name, team, oncall }
#
# models.md is incident-derived (see its header): every model that has had an OT
# incident is in it, with a hand-curated **Owner** column (the same column that
# seeded the diff-ingest roster). That is the authoritative model→owner map for
# our in-scope fleet. The unixname→team/oncall hop is live via `meta`.
#
# OUTPUT always names its SOURCE so the caller (and the eval grader) can see the
# routing came from data, not narration (CLAUDE.md "Self-Reporting From Data").
#
# Usage:
#   owner-lookup.sh --model-id=<entity_id>
#   owner-lookup.sh --model-type=<model_type>     # first matching row wins; -o lists all
#   owner-lookup.sh --owner=<unixname>            # skip models.md, resolve a unixname directly
#   owner-lookup.sh --model-id=2130324829 -o json
#   owner-lookup.sh --model-type=threads_feed_mtml --all   # every owner for that type
#
# Flags:
#   --model-id=N     resolve by entity_id (exact, single row)
#   --model-type=S   resolve by model_type (may match >1 model; default = first row)
#   --owner=U        resolve a unixname directly (no models.md lookup)
#   --all            with --model-type: print EVERY distinct owner for that type
#   -o json|text     output format (default text)
#   --no-meta        models.md lookup only; skip the live team/oncall hop (fast/offline)
#
# Exit: 0 found · 2 not found in models.md · 3 bad usage. Always prints something.
#
# Limits (be honest with the caller):
#   - Coverage = incident-derived models only. A never-broken model is absent
#     until it has an incident; --model-id on an unknown id returns NOT_FOUND
#     (the caller should then fall back to the LIVE source: `enrich_model`
#     in lib-enrich-model.sh, which reads mast/registry — slower, but full-fleet).
#   - unixname→team/oncall depends on `meta people.profile get`; if a unixname is
#     stale/departed or meta is unreachable, team/oncall come back empty and the
#     output degrades to the unixname alone (still a valid routing target).
#   - The models.md Owner column is the model's *engineering owner* unixname. For
#     an infra-root-cause incident (ZippyDB/Scribe), the correct escalation may be
#     an UPSTREAM oncall, not the model owner — this tool answers "who owns the
#     model", which is the right default when the root cause is in-model.
set -uo pipefail

MODELS_FILE="$(dirname "$0")/../human-input/models.md"
MODEL_ID=""; MODEL_TYPE=""; OWNER=""; FMT="text"; ALL=0; NOMETA=0

for a in "$@"; do
  case "$a" in
    --model-id=*)   MODEL_ID="${a#*=}" ;;
    --model-type=*) MODEL_TYPE="${a#*=}" ;;
    --owner=*)      OWNER="${a#*=}" ;;
    -o)             FMT="__next" ;;
    -o=*|--output=*) FMT="${a#*=}" ;;
    json|text)      [ "$FMT" = "__next" ] && FMT="$a" ;;
    --all)          ALL=1 ;;
    --no-meta)      NOMETA=1 ;;
    -h|--help)      sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "owner-lookup: unknown arg '$a'" >&2; exit 3 ;;
  esac
done
[ "$FMT" = "__next" ] && FMT="text"

if [ -z "$MODEL_ID" ] && [ -z "$MODEL_TYPE" ] && [ -z "$OWNER" ]; then
  echo "owner-lookup: need --model-id, --model-type, or --owner (see --help)" >&2; exit 3
fi
if [ -z "$OWNER" ] && [ ! -f "$MODELS_FILE" ]; then
  echo "owner-lookup: models.md not found at $MODELS_FILE" >&2; exit 2
fi

# ---- step 1: resolve owner unixname(s) from models.md (deterministic) ----
# Parse only real table rows (start with '|') so stray prose tokens never match.
# Row columns (1-indexed by '|'): 2=# 3=Model 4=Model Type 5=Entity ID(link) 6=PG 7=Owner ...
# Entity ID cell is a markdown link `[NNNN](...entity_id=NNNN)`; pull the digits.
declare -a OWNERS=() SRCMODELS=()
if [ -n "$OWNER" ]; then
  OWNERS=("$OWNER"); SRCMODELS=("(direct --owner)")
else
  while IFS='|' read -r _ c_num c_model c_type c_eid c_pg c_owner _rest; do
    eid="$(printf '%s' "$c_eid" | grep -oP 'entity_id=\K\d+' | head -1)"
    [ -z "$eid" ] && continue
    mt="$(printf '%s' "$c_type" | xargs)"
    ow="$(printf '%s' "$c_owner" | xargs)"
    mdl="$(printf '%s' "$c_model" | xargs)"
    if [ -n "$MODEL_ID" ]; then
      if [ "$eid" = "$MODEL_ID" ]; then
        OWNERS=("$ow"); SRCMODELS=("$mdl ($mt, id=$eid)"); break
      fi
    elif [ -n "$MODEL_TYPE" ]; then
      if [ "$mt" = "$MODEL_TYPE" ]; then
        OWNERS+=("$ow"); SRCMODELS+=("$mdl (id=$eid)")
      fi
    fi
  done < <(grep -P '^\|' "$MODELS_FILE")
fi

if [ "${#OWNERS[@]}" -eq 0 ]; then
  KEY="${MODEL_ID:-$MODEL_TYPE}"
  if [ "$FMT" = "json" ]; then
    printf '{"query":"%s","found":false,"source":"models.md","note":"not in incident-derived roster; fall back to live enrich_model (lib-enrich-model.sh)"}\n' "$KEY"
  else
    echo "NOT_FOUND: '$KEY' is not in models.md (incident-derived roster)."
    echo "  source: $MODELS_FILE"
    echo "  fallback: resolve LIVE via  source tools/lib-enrich-model.sh; enrich_model <entity_id>"
  fi
  exit 2
fi

# For --model-type without --all, keep only the first distinct owner (default routing target),
# but note multiplicity so the caller knows.
if [ -n "$MODEL_TYPE" ] && [ "$ALL" -eq 0 ] && [ "${#OWNERS[@]}" -gt 1 ]; then
  # distinct owners count for the note
  DISTINCT="$(printf '%s\n' "${OWNERS[@]}" | sort -u | wc -l | xargs)"
  OWNERS=("${OWNERS[0]}"); SRCMODELS=("${SRCMODELS[0]}"); MULTI="$DISTINCT"
else
  MULTI=""
fi

# ---- step 2: unixname -> team/oncall via meta (live), unless --no-meta ----
# resolve_owner <unixname> -> echoes "name|team|oncall|resolve_source"
resolve_owner() {
  local u="$1"
  # owner cell may be empty or a non-unixname placeholder ('?'), handle cleanly
  if [ -z "$u" ] || [ "$u" = "?" ]; then echo "||| (owner missing in models.md)"; return; fi
  if [ "$NOMETA" -eq 1 ]; then echo "|||(--no-meta: unixname only)"; return; fi
  local J
  J="$(timeout 30 meta people.profile get --unixname="$u" -o json 2>/dev/null)" || J=""
  U="$u" J="$J" python3 -c "
import os,json
u=os.environ['U']; j=os.environ.get('J','')
try: d=json.loads(j) if j else {}
except Exception: d={}
name=(d.get('name') or '').strip()
team=(d.get('team') or '').strip()
onc=(d.get('oncall') or '').strip()
src='meta people.profile get' if (name or team or onc) else 'meta lookup failed (unixname only)'
print('|'.join([name,team,onc,src]))
"
}

emit_text() {
  local i u name team onc rsrc
  for i in "${!OWNERS[@]}"; do
    u="${OWNERS[$i]}"
    IFS='|' read -r name team onc rsrc <<<"$(resolve_owner "$u")"
    echo "MODEL:  ${SRCMODELS[$i]}"
    echo "OWNER:  ${u:-<none>}${name:+  (}${name}${name:+)}"
    echo "TEAM:   ${team:-<unresolved>}"
    echo "ONCALL: ${onc:-<unresolved>}"
    echo "SOURCE: models.md Owner column -> ${rsrc}"
    [ $((i+1)) -lt "${#OWNERS[@]}" ] && echo "---"
  done
  [ -n "${MULTI:-}" ] && echo "NOTE:   model_type has $MULTI distinct owners; showing first. Use --all to list every owner."
}

emit_json() {
  local i u name team onc rsrc first=1
  printf '{"query":"%s","found":true,"source":"models.md+meta","results":[' "${MODEL_ID:-${MODEL_TYPE:-$OWNER}}"
  for i in "${!OWNERS[@]}"; do
    u="${OWNERS[$i]}"
    IFS='|' read -r name team onc rsrc <<<"$(resolve_owner "$u")"
    [ "$first" -eq 1 ] || printf ','
    first=0
    U="$u" NAME="$name" TEAM="$team" ONC="$onc" RSRC="$rsrc" MDL="${SRCMODELS[$i]}" python3 -c "
import os,json
print(json.dumps({'model':os.environ['MDL'],'owner_unixname':os.environ['U'],
 'owner_name':os.environ['NAME'],'team':os.environ['TEAM'],'oncall':os.environ['ONC'],
 'resolve_source':os.environ['RSRC']}),end='')
"
  done
  printf '],"note":"%s"}\n' "${MULTI:+model_type has $MULTI distinct owners; showing first unless --all}"
}

if [ "$FMT" = "json" ]; then emit_json; else emit_text; fi
exit 0
