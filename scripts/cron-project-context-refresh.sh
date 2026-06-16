#!/usr/bin/env bash
# cron-project-context-refresh.sh — Weekly orchestrator for project context harvesters.
#
# For every project in projects/_registry.json, dispatches each harvester in
# scripts/harvesters/. Each harvester self-skips if its required META.yaml fields
# are absent. Harvesters write structured signals to projects/<slug>/context/signals/<name>.md
# (atomically replaced each run).
#
# Distillation (signals → SNAPSHOT) is Claude's job on the next session that touches
# these paths (per the "Auto-improvement rules" in QUALITY.md and the CLAUDE.md
# "Project context routing" rule).
#
# Adding a new harvester:
#   1. Drop a script into scripts/harvesters/ with signature: <slug> <project_dir> <meta_file>
#   2. Make it self-skip cleanly when its META fields are absent.
#   3. Add its filename (without `.sh`) to HARVESTERS below.
#
# META.yaml fields consumed by current harvesters:
#   workstreams: dict (name → fbsource path)   → diffs-by-path
#   key_people:  list of unixnames             → diffs-by-author, posts-by-author
#
# Schedule: weekly, Monday 04:30.
# Crontab entry (registered in scripts/setup-claude.sh):
#   30 4 * * 1 source ~/work/claude/scripts/cron-alert.sh && cron_run 1800 project-context-refresh ~/work/claude/scripts/cron-project-context-refresh.sh >> ~/logs/project-context-refresh.log 2>&1

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARVESTER_DIR="$SCRIPT_DIR/harvesters"
REPO_DIR="$HOME/work/claude"
PROJECTS_DIR="$REPO_DIR/projects"
REGISTRY="$PROJECTS_DIR/_registry.json"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"

# Harvesters to dispatch per project. Add new ones here.
HARVESTERS=(
    "diffs-by-path"
    "diffs-by-author"
    "posts-by-author"
    "upstream-files"
)

# shellcheck disable=SC1091
source "$SCRIPT_DIR/cron-alert.sh"

echo "$LOG_PREFIX === Project context refresh ==="

if [ ! -f "$REGISTRY" ]; then
    cron_alert "project-context-refresh" "Registry missing: $REGISTRY"
    exit 1
fi

slugs=$(python3 -c "import json; [print(p) for p in json.load(open('$REGISTRY')).get('projects',[])]")

projects_processed=0
harvesters_run=0
harvesters_failed=0

for slug in $slugs; do
    project_dir="$PROJECTS_DIR/$slug"
    [ -d "$project_dir" ] || continue
    meta_file="$project_dir/META.yaml"
    [ -f "$meta_file" ] || continue

    project_had_any=0
    echo "$LOG_PREFIX --- project=$slug ---"

    for harvester in "${HARVESTERS[@]}"; do
        script="$HARVESTER_DIR/$harvester.sh"
        if [ ! -f "$script" ]; then
            echo "$LOG_PREFIX   [WARN] missing harvester: $script" >&2
            harvesters_failed=$((harvesters_failed + 1))
            continue
        fi

        echo "$LOG_PREFIX   harvester=$harvester"
        if bash "$script" "$slug" "$project_dir" "$meta_file" 2>&1 | sed "s/^/$LOG_PREFIX     /"; then
            harvesters_run=$((harvesters_run + 1))
            project_had_any=1
        else
            echo "$LOG_PREFIX   [WARN] harvester $harvester failed for $slug" >&2
            harvesters_failed=$((harvesters_failed + 1))
        fi
    done

    [ "$project_had_any" -eq 1 ] && projects_processed=$((projects_processed + 1))
done

write_heartbeat "project-context-refresh" 2>/dev/null || true

echo "$LOG_PREFIX Summary: $projects_processed project(s), $harvesters_run harvester run(s), $harvesters_failed failure(s)"

if [ "$harvesters_failed" -gt 0 ]; then
    cron_alert "project-context-refresh" "$harvesters_failed harvester(s) failed (see log)"
    exit 1
fi

if [ "$projects_processed" -eq 0 ]; then
    cron_alert "project-context-refresh" "No project produced signals — check META.yaml schemas"
    exit 1
fi

cron_alert_clear "project-context-refresh" 2>/dev/null || true
echo "$LOG_PREFIX === Done ==="
