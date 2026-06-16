#!/usr/bin/env bash
# generate-dashboard.sh — Generate a Markdown project dashboard
# Usage: bash scripts/generate-dashboard.sh
# Output: DASHBOARD.md in the workspace root

set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECTS_DIR="$WORKSPACE_DIR/projects"
REGISTRY="$PROJECTS_DIR/_registry.json"
IMPACT_FILE="$WORKSPACE_DIR/IMPACT.md"
OUTPUT="$WORKSPACE_DIR/DASHBOARD.md"
TODAY=$(date +%Y-%m-%d)

# --- Data extraction helpers ---

get_yaml_field() {
    local file="$1" field="$2"
    local val
    val=$(grep "^${field}:" "$file" 2>/dev/null | head -1 || true)
    [ -z "$val" ] && return
    echo "$val" | sed "s/^${field}:[[:space:]]*//" | sed 's/[[:space:]]*$//'
}

get_project_list() {
    awk '
        /"projects"/ { in_projects=1; next }
        in_projects && /\]/ { exit }
        in_projects && /"[a-z]/ { gsub(/[^a-z0-9-]/, ""); if (length > 0) print }
    ' "$REGISTRY"
}

get_milestones() {
    local file="$1"
    [ -f "$file" ] || return
    (grep -E '^### [0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" 2>/dev/null || true) | sed 's/^### //' | head -10
}

get_phase_durations() {
    local file="$1"
    [ -f "$file" ] || return
    awk '/^\| Phase \| Started/,/^$/' "$file" 2>/dev/null | (grep '^|' || true) | (grep -v 'Phase.*Started' || true) | (grep -v '^|--' || true)
}

get_impact_diff_count() {
    local project_name="$1"
    [ -f "$IMPACT_FILE" ] || { echo 0; return; }
    awk -v name="$project_name" '
        /^### / { in_section = (index($0, name) > 0) }
        in_section && /^\- \*\*D[0-9]+\*\*/ { count++ }
        END { print count+0 }
    ' "$IMPACT_FILE"
}

# Build a text progress bar: [████████░░] 80%
progress_bar() {
    local pct="$1" width=20
    local filled=$(( (pct * width) / 100 ))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo "[${bar}] ${pct}%"
}

# Phase emoji
phase_badge() {
    case "$1" in
        discovery) echo "🔵 Discovery" ;;
        planning) echo "🟡 Planning" ;;
        execution) echo "🟢 Execution" ;;
        complete) echo "⚪ Complete" ;;
        *) echo "❓ $1" ;;
    esac
}

# --- Collect all project data ---

declare -a PROJ_SLUGS=()
declare -A PROJ_NAMES=()
declare -A PROJ_PHASES=()
declare -A PROJ_CREATED=()
declare -A PROJ_DONE=()
declare -A PROJ_INPROG=()
declare -A PROJ_BLOCKED=()
declare -A PROJ_READY=()
declare -A PROJ_NOTSTARTED=()
declare -A PROJ_SKIPPED=()
declare -A PROJ_DEFERRED=()
declare -A PROJ_TOTAL=()
declare -A PROJ_HAS_TASKS=()
declare -A PROJ_HAS_LAUNCH=()
declare -A PROJ_MILESTONES=()
declare -A PROJ_IMPACT_DIFFS=()
declare -A PROJ_DESCRIPTIONS=()

while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    proj_dir="$PROJECTS_DIR/$slug"
    meta="$proj_dir/META.yaml"
    tasks="$proj_dir/TASKS.md"
    launch="$proj_dir/LAUNCH.md"

    [ -f "$meta" ] || continue

    PROJ_SLUGS+=("$slug")

    name=$(get_yaml_field "$meta" "name")
    phase=$(get_yaml_field "$meta" "phase")
    created=$(get_yaml_field "$meta" "created")
    desc=$(get_yaml_field "$meta" "description")

    if [ "$desc" = ">" ] || [ -z "$desc" ]; then
        desc=$(awk '/^description:/{found=1; next} found && /^[^ ]/{exit} found{gsub(/^  /,""); print; exit}' "$meta" 2>/dev/null)
    fi

    PROJ_NAMES[$slug]="${name:-$slug}"
    PROJ_PHASES[$slug]="${phase:-unknown}"
    PROJ_CREATED[$slug]="${created:-unknown}"
    PROJ_DESCRIPTIONS[$slug]="${desc:-}"

    if [ -f "$tasks" ]; then
        PROJ_HAS_TASKS[$slug]=1
        done_count=$(awk '/^\|/ && /DONE/' "$tasks" | wc -l)
        inprog_count=$(awk '/^\|/ && /IN PROGRESS/' "$tasks" | wc -l)
        blocked_count=$(awk '/^\|/ && /BLOCKED/' "$tasks" | wc -l)
        ready_count=$(awk '/^\|/ && /READY/' "$tasks" | wc -l)
        notstarted_count=$(awk '/^\|/ && /NOT STARTED/' "$tasks" | wc -l)
        skipped_count=$(awk '/^\|/ && /SKIPPED/' "$tasks" | wc -l)
        deferred_count=$(awk '/^\|/ && /DEFERRED/' "$tasks" | wc -l)
        total=$((done_count + inprog_count + blocked_count + ready_count + notstarted_count + skipped_count + deferred_count))

        PROJ_DONE[$slug]=$done_count
        PROJ_INPROG[$slug]=$inprog_count
        PROJ_BLOCKED[$slug]=$blocked_count
        PROJ_READY[$slug]=$ready_count
        PROJ_NOTSTARTED[$slug]=$notstarted_count
        PROJ_SKIPPED[$slug]=$skipped_count
        PROJ_DEFERRED[$slug]=$deferred_count
        PROJ_TOTAL[$slug]=$total
    else
        PROJ_HAS_TASKS[$slug]=0
        PROJ_DONE[$slug]=0
        PROJ_INPROG[$slug]=0
        PROJ_BLOCKED[$slug]=0
        PROJ_READY[$slug]=0
        PROJ_NOTSTARTED[$slug]=0
        PROJ_SKIPPED[$slug]=0
        PROJ_DEFERRED[$slug]=0
        PROJ_TOTAL[$slug]=0
    fi

    if [ -f "$launch" ]; then
        PROJ_HAS_LAUNCH[$slug]=1
        PROJ_MILESTONES[$slug]=$(get_milestones "$launch" | tr '\n' '|')
    else
        PROJ_HAS_LAUNCH[$slug]=0
        PROJ_MILESTONES[$slug]=""
    fi

    PROJ_IMPACT_DIFFS[$slug]=$(get_impact_diff_count "${PROJ_NAMES[$slug]}")

done < <(get_project_list)

# --- Compute summary stats ---

total_projects=${#PROJ_SLUGS[@]}
discovery_count=0
planning_count=0
execution_count=0
complete_count=0
total_done=0
total_tasks=0
total_inprog=0
total_blocked=0

for slug in "${PROJ_SLUGS[@]}"; do
    case "${PROJ_PHASES[$slug]}" in
        discovery) discovery_count=$((discovery_count + 1)) ;;
        planning) planning_count=$((planning_count + 1)) ;;
        execution) execution_count=$((execution_count + 1)) ;;
        complete) complete_count=$((complete_count + 1)) ;;
    esac
    total_done=$((total_done + PROJ_DONE[$slug]))
    total_tasks=$((total_tasks + PROJ_TOTAL[$slug]))
    total_inprog=$((total_inprog + PROJ_INPROG[$slug]))
    total_blocked=$((total_blocked + PROJ_BLOCKED[$slug]))
done

# --- Generate Markdown ---

{
    echo "# Project Dashboard"
    echo ""
    echo "*Generated ${TODAY} — ${total_projects} projects*"
    echo ""

    # Summary stats
    echo "## Summary"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|------:|"
    echo "| Projects | **${total_projects}** |"
    echo "| Tasks Done | **${total_done}** |"
    echo "| In Progress | **${total_inprog}** |"
    echo "| Blocked | **${total_blocked}** |"
    echo "| 🟢 Execution | ${execution_count} |"
    echo "| 🟡 Planning | ${planning_count} |"
    echo "| 🔵 Discovery | ${discovery_count} |"
    echo "| ⚪ Complete | ${complete_count} |"
    echo ""

    # Overview table
    echo "## All Projects"
    echo ""
    echo "| Project | Phase | Progress | ✅ | 🔄 | 🚫 | Created |"
    echo "|---------|-------|----------|---:|---:|---:|---------|"

    for phase_order in execution planning discovery complete; do
        for slug in "${PROJ_SLUGS[@]}"; do
            [ "${PROJ_PHASES[$slug]}" = "$phase_order" ] || continue
            local_name="${PROJ_NAMES[$slug]}"
            local_phase=$(phase_badge "${PROJ_PHASES[$slug]}")
            local_done=${PROJ_DONE[$slug]}
            local_inprog=${PROJ_INPROG[$slug]}
            local_blocked=${PROJ_BLOCKED[$slug]}
            local_total=${PROJ_TOTAL[$slug]}
            local_created="${PROJ_CREATED[$slug]}"

            if [ "$local_total" -gt 0 ]; then
                local_pct=$(( (local_done * 100) / local_total ))
                local_progress="${local_pct}% (${local_done}/${local_total})"
            else
                local_progress="—"
            fi

            echo "| ${local_name} | ${local_phase} | ${local_progress} | ${local_done} | ${local_inprog} | ${local_blocked} | ${local_created} |"
        done
    done

    echo ""

    # Per-project details
    echo "---"
    echo ""
    echo "## Project Details"
    echo ""

    for phase_order in execution planning discovery complete; do
        for slug in "${PROJ_SLUGS[@]}"; do
            [ "${PROJ_PHASES[$slug]}" = "$phase_order" ] || continue

            name="${PROJ_NAMES[$slug]}"
            phase="${PROJ_PHASES[$slug]}"
            created="${PROJ_CREATED[$slug]}"
            desc="${PROJ_DESCRIPTIONS[$slug]}"
            done_c=${PROJ_DONE[$slug]}
            inprog_c=${PROJ_INPROG[$slug]}
            blocked_c=${PROJ_BLOCKED[$slug]}
            ready_c=${PROJ_READY[$slug]}
            notstarted_c=${PROJ_NOTSTARTED[$slug]}
            skipped_c=${PROJ_SKIPPED[$slug]}
            deferred_c=${PROJ_DEFERRED[$slug]}
            total_c=${PROJ_TOTAL[$slug]}
            has_tasks=${PROJ_HAS_TASKS[$slug]}
            has_launch=${PROJ_HAS_LAUNCH[$slug]}
            milestones="${PROJ_MILESTONES[$slug]}"
            impact_diffs=${PROJ_IMPACT_DIFFS[$slug]}
            proj_dir="$PROJECTS_DIR/$slug"

            echo "### ${name}"
            echo ""
            echo "$(phase_badge "$phase") — Created ${created}"
            echo ""

            # Description
            if [ -n "$desc" ]; then
                echo "> ${desc}"
                echo ""
            fi

            # Progress bar
            if [ "$has_tasks" = "1" ] && [ "$total_c" -gt 0 ]; then
                local_pct=$(( (done_c * 100) / total_c ))
                echo "**Progress:** \`$(progress_bar "$local_pct")\`"
                echo ""

                # Task breakdown
                echo "| Status | Count |"
                echo "|--------|------:|"
                [ "$done_c" -gt 0 ] && echo "| ✅ Done | ${done_c} |"
                [ "$inprog_c" -gt 0 ] && echo "| 🔄 In Progress | ${inprog_c} |"
                [ "$blocked_c" -gt 0 ] && echo "| 🚫 Blocked | ${blocked_c} |"
                [ "$ready_c" -gt 0 ] && echo "| 🟢 Ready | ${ready_c} |"
                [ "$notstarted_c" -gt 0 ] && echo "| ⬚ Not Started | ${notstarted_c} |"
                [ "$skipped_c" -gt 0 ] && echo "| ⏭️ Skipped | ${skipped_c} |"
                [ "$deferred_c" -gt 0 ] && echo "| ⏸️ Deferred | ${deferred_c} |"
                echo "| **Total** | **${total_c}** |"
                echo ""
            fi

            # Phase durations
            if [ "$has_tasks" = "1" ]; then
                durations=$(get_phase_durations "$proj_dir/TASKS.md")
                if [ -n "$durations" ]; then
                    echo "**Phase Timeline:**"
                    echo ""
                    echo "| Phase | Started | Completed | Duration |"
                    echo "|-------|---------|-----------|----------|"
                    echo "$durations" | while IFS='|' read -r _ phase_name started completed duration _; do
                        phase_name=$(echo "$phase_name" | xargs)
                        started=$(echo "$started" | xargs)
                        completed=$(echo "$completed" | xargs)
                        duration=$(echo "$duration" | xargs)
                        [ -z "$phase_name" ] && continue
                        echo "| ${phase_name} | ${started} | ${completed} | ${duration} |"
                    done
                    echo ""
                fi
            fi

            # Milestones
            if [ "$has_launch" = "1" ] && [ -n "$milestones" ]; then
                echo "**Milestones:**"
                echo ""
                IFS='|' read -ra ms_arr <<< "$milestones"
                for ms in "${ms_arr[@]}"; do
                    [ -z "$ms" ] && continue
                    ms_date=$(echo "$ms" | cut -d' ' -f1)
                    ms_text=$(echo "$ms" | cut -d' ' -f2-)
                    echo "- **${ms_date}** ${ms_text}"
                done
                echo ""
            fi

            # Impact
            if [ "$impact_diffs" -gt 0 ]; then
                echo "**Shipped:** ${impact_diffs} diffs landed"
                echo ""
            fi

            # Files present
            files_list=""
            for f in META.yaml TASKS.md PLAN.md LAUNCH.md WORKLOG.md SUMMARY.md DISCOVERY.md TEST_STATUS.md PROVENANCE.md; do
                [ -f "$proj_dir/$f" ] && files_list+=" \`${f}\`"
            done
            if [ -n "$files_list" ]; then
                echo "**Files:**${files_list}"
                echo ""
            fi

        done
    done

} > "$OUTPUT"

echo "Dashboard generated: ${OUTPUT}"
