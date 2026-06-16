#!/usr/bin/env bash
# new-project.sh — Scaffold a new project under projects/<slug>/.
#
# Creates the 5-layer enrichment scaffolding consumed by:
#   - cron-project-context-refresh.sh (reads META.yaml workstreams)
#   - cron-project-gdoc-sync.sh (reads SNAPSHOT.md)
#   - CLAUDE.md routing table (manual step printed at the end)
#
# Usage:
#   scripts/new-project.sh <slug> [description]
#
# Example:
#   scripts/new-project.sh ranking-quality-gates "Pre-launch quality gates for ranking models"
#
# Exits non-zero on: bad slug, existing project, registry write failure.
# Does NOT register in CLAUDE.md routing table — printed as a follow-up step
# so the human picks the right code paths and reviewer set.

set -eo pipefail

REPO_DIR="$HOME/work/claude"
PROJECTS_DIR="$REPO_DIR/projects"
REGISTRY="$PROJECTS_DIR/_registry.json"
TODAY=$(date '+%Y-%m-%d')

slug="${1:-}"
description="${2:-Add a one-paragraph description here.}"

if [ -z "$slug" ]; then
    echo "usage: $0 <slug> [description]" >&2
    exit 2
fi

# kebab-case validator: lowercase letters, digits, hyphens; must start with a letter.
if ! [[ "$slug" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "[error] slug must be kebab-case (lowercase letters, digits, hyphens, leading letter): '$slug'" >&2
    exit 2
fi

project_dir="$PROJECTS_DIR/$slug"
if [ -e "$project_dir" ]; then
    echo "[error] $project_dir already exists — refusing to overwrite" >&2
    exit 1
fi

if [ ! -f "$REGISTRY" ]; then
    echo "[error] registry missing: $REGISTRY" >&2
    exit 1
fi

# Confirm slug is not already in active or archived list.
already=$(python3 -c "
import json, sys
r = json.load(open('$REGISTRY'))
for k in ('projects', 'archived'):
    if '$slug' in r.get(k, []):
        print(k)
        sys.exit(0)
")
if [ -n "$already" ]; then
    echo "[error] slug '$slug' already exists in _registry.json under '$already'" >&2
    exit 1
fi

mkdir -p "$project_dir/context/signals"

cat > "$project_dir/META.yaml" <<EOF
name: $slug
slug: $slug
phase: discovery
tier: active
created: $TODAY
owner: dennyzhang
protocol_mode: Lite
description: >
  $description
workstreams:
  # name: fbsource-relative path. Read by cron-project-context-refresh.sh.
  # Add one entry per code area. Example:
  #   pe_mrs_ml: fbcode/pe_mrs_ml
EOF

cat > "$project_dir/context/SNAPSHOT.md" <<EOF
# $slug — Snapshot

*Curated, verified context. AI reads this first before doing work.*
*Last verified: $TODAY*
*Distilled through: $TODAY*  <!-- Bump this date after digesting fresh signals into SNAPSHOT. Dashboard counts entries newer than this as "undigested". -->


## Goal

$description

## Code Paths

| Path | Purpose |
|------|---------|
| _TBD_ | _Fill from META.yaml workstreams_ |

## Reviewers

| Person | Area | Notes |
|--------|------|-------|

## Title prefix

\`[<TBD>]\`

## Summary / Test plan style

_What conventions does this project follow? Pull from \`signals/reviews.md\` once 3+ landings exist._

## Gotchas

_Surprises, footguns, hidden constraints. Empty until learned._
EOF

cat > "$project_dir/context/QUALITY.md" <<EOF
# Quality Guardrails

## Staleness tracking

| Section | Last verified | Status |
|---------|--------------|--------|
| Reviewers | $TODAY | unverified |
| Diff patterns | $TODAY | unverified |
| People | $TODAY | unverified |
| Active diffs/tasks | $TODAY | unverified |

## Contradiction log

| Date | Signal | Contradicts | Resolution |
|------|--------|------------|------------|

## External References

| Source | URL | Purpose | Refresh cadence |
|--------|-----|---------|----------------|

## Auto-improvement rules

1. After every diff lands: update diff patterns in SNAPSHOT
2. After every diff review: append reviewer feedback to signals/reviews.md
3. After relevant meetings: append decisions to signals/meetings.md
4. After SEV involvement: append lessons to signals/reviews.md
5. Monthly: re-verify staleness table
EOF

# Empty signal files — cron and Claude append to these.
: > "$project_dir/context/signals/reviews.md"
: > "$project_dir/context/signals/meetings.md"

# Atomically add slug to registry (preserves existing ordering, places new slug at end of projects).
tmp_registry=$(mktemp -t registry.XXXX.json)
python3 - "$REGISTRY" "$slug" "$tmp_registry" <<'PY'
import json, sys
path, slug, out = sys.argv[1], sys.argv[2], sys.argv[3]
r = json.load(open(path))
r.setdefault('projects', []).append(slug)
with open(out, 'w') as f:
    json.dump(r, f, indent=2)
    f.write('\n')
PY
mv "$tmp_registry" "$REGISTRY"

cat <<EOF

[ok] scaffolded projects/$slug/
       META.yaml, context/SNAPSHOT.md, context/QUALITY.md, context/signals/{reviews,meetings}.md
[ok] registered '$slug' in _registry.json

Next steps (manual):
  1. Edit $project_dir/META.yaml — fill in 'workstreams:' dict (name → fbsource path).
  2. Add a routing row to ~/work/claude/CLAUDE.md (search for "Project context routing"):
       | <code-path>/ | projects/$slug/context/SNAPSHOT.md | [<prefix>] | <reviewers> |
  3. Run scripts/cron-project-context-refresh.sh to harvest the first auto-discover signal.
  4. Edit context/SNAPSHOT.md as evidence accumulates.
EOF
