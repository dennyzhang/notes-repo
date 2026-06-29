# shellcheck shell=bash
# lib-enrich-model.sh — shared model-enrichment helper for OT fleet-health scans.
#
# Single source of truth for resolving a model's (model_type, pg, mvai_tier,
# owner) from an entity_id. Used by ALL THREE fleet-health scan workers
# (scan-scribe-age.sh, scan-zombie-fleet.sh, scan-perf-regression.sh) so the
# enrichment fields render identically regardless of which scan sourced an
# act-now item. The proven logic was lifted verbatim from scan-scribe-age.sh's
# per-model worker (where it was first hardened to be deterministic, not a
# fragile per-breach LLM step that silently blanked fields).
#
# Source this file, then call:
#   enrich_model <entity_id>
# It echoes exactly one pipe-separated line:
#   model_type|pg|mvai_tier|owner
#
# Resolution rules (DETERMINISTIC; NEVER rm_attribution):
#   model_type: flow_model_type (mast application_metadata)
#               → model_type_name (ai.model describe)  → 'unknown'
#   owner:      model_owner_unixname (mast)
#               → owner_unixname (registry) → oncall (registry) → '?'
#   mvai_tier:  MVAI_TIER (mast) → 'T?'
#   pg:         derived from resolved model_type
#               (textpost|threads→THREADS; facebook_reels*→VIDEO;
#                other facebook_*→FEED; other ig_*→INSTAGRAM; else unknown)
#
# Cost gate: at most TWO meta calls. The mast metadata call always runs (one
# call yields flow_model_type + model_owner_unixname + MVAI_TIER together). The
# registry `ai.model describe` fallback runs ONLY if model_type OR owner is still
# unresolved from mast (skipped entirely when mast has both → one call max).

# enrich_model <entity_id>  ->  echoes "model_type|pg|mvai_tier|owner"
enrich_model() {
  local EID="$1"
  local JOB_NAME="mvai-training-online-${EID}"

  local MAST_META MODEL_DESC
  MAST_META=$(timeout 45 meta ai.mast-job metadata --name="${JOB_NAME}" -o json 2>/dev/null) || MAST_META=""

  # Decide up-front whether the registry fallback is needed (model_type OR owner
  # unresolved from mast) so we make at most ONE ai.model describe call.
  MODEL_DESC=$(MAST_META="${MAST_META}" python3 -c "
import os, json, sys
mm = os.environ.get('MAST_META','')
appmeta = {}
try:
    appmeta = json.loads(json.loads(mm).get('application_metadata','{}')) if mm else {}
except Exception:
    appmeta = {}
ft = (appmeta.get('flow_model_type') or '').strip()
ow = (appmeta.get('model_owner_unixname') or '').strip()
# fallback needed if either model_type or owner is still empty
sys.stdout.write('NEED' if (not ft or not ow) else 'SKIP')
" 2>/dev/null)
  if [ "${MODEL_DESC}" = "NEED" ]; then
    MODEL_DESC=$(timeout 45 meta ai.model describe --model-id="${EID}" -o json 2>/dev/null) || MODEL_DESC=""
  else
    MODEL_DESC=""
  fi

  MAST_META="${MAST_META}" MODEL_DESC="${MODEL_DESC}" PG_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")" python3 -c "
import os, json, sys

mm = os.environ.get('MAST_META','')
md = os.environ.get('MODEL_DESC','')

appmeta = {}
try:
    appmeta = json.loads(json.loads(mm).get('application_metadata','{}')) if mm else {}
except Exception:
    appmeta = {}

desc = {}
try:
    desc = json.loads(md) if md else {}
except Exception:
    desc = {}

# model_type: flow_model_type (mast) → model_type_name (registry) → 'unknown'.
# NEVER rm_attribution.
model_type = (appmeta.get('flow_model_type') or '').strip()
if not model_type:
    model_type = (desc.get('model_type_name') or '').strip()
if not model_type:
    model_type = 'unknown'

# owner: model_owner_unixname (mast) → owner_unixname (registry) → oncall → '?'.
# Resolved INDEPENDENTLY of model_type.
owner = (appmeta.get('model_owner_unixname') or '').strip()
if not owner:
    owner = (desc.get('owner_unixname') or '').strip()
if not owner:
    owner = (desc.get('oncall') or '').strip()
if not owner:
    owner = '?'

# mvai_tier: MVAI_TIER (mast) → 'T?'.
mvai_tier = (appmeta.get('MVAI_TIER') or '').strip()
if not mvai_tier:
    mvai_tier = 'T?'

# pg: derive from resolved model_type via the shared single-source classifier
# (tools/pg_classify.py). Inline fallback ONLY if that module is unreachable, so
# this hot path never breaks; keep the fallback identical to pg_classify.pg_for.
sys.path.insert(0, os.environ.get('PG_LIB_DIR',''))
try:
    from pg_classify import pg_for
    pg = pg_for(model_type)
except Exception:
    mt = model_type.lower()
    if 'textpost' in mt or 'threads' in mt:
        pg = 'THREADS'
    elif mt.startswith('facebook_reels'):
        pg = 'VIDEO'
    elif mt.startswith('facebook_'):
        pg = 'FEED'
    elif mt.startswith('ig_'):
        pg = 'INSTAGRAM'
    else:
        pg = 'unknown'

print('|'.join([model_type, pg, mvai_tier, owner]))
" 2>/dev/null
}
