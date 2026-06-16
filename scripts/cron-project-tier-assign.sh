#!/usr/bin/env bash
# cron-project-tier-assign.sh — Daily project tier assignment.
#
# For each active project:
#   1. Reads META.yaml for phase/status
#   2. Checks file freshness (newest file modification)
#   3. Cross-references TASKS.md for blocked/P0/done counts
#   4. Assigns tier (Active/Maintenance/Dormant)
#   5. Writes health cache for GDoc sync consumption
#
# Schedule: Daily 4:45 AM (after people-refresh, before project-gdoc-sync)
# Crontab entry:
#   45 4 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 300 project-tier-assign ~/work/claude/scripts/cron-project-tier-assign.sh >> ~/logs/project-tier-assign.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
PROJECTS_DIR="$REPO_DIR/projects"
REGISTRY="$PROJECTS_DIR/_registry.json"
CACHE_FILE="$PROJECTS_DIR/_health-cache.json"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"

source "$SCRIPT_DIR/cron-alert.sh"

if [ ! -f "$REGISTRY" ]; then
    echo "$LOG_PREFIX No project registry found"
    exit 0
fi

echo "$LOG_PREFIX === Project Tier Assignment ==="

# Extract active project slugs from registry
slugs=$(python3 -c "import json; [print(p) for p in json.load(open('$REGISTRY')).get('projects',[])]")

health_entries=""
active=0
maintenance=0
dormant=0
total=0

for slug in $slugs; do
    dir="$PROJECTS_DIR/$slug"
    [ ! -d "$dir" ] && continue
    total=$((total + 1))

    # Find newest file modification age (days)
    newest_age=999
    if newest_ts=$(find "$dir" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1); then
        newest_age=$(( ($(date +%s) - ${newest_ts%%.*}) / 86400 ))
    fi

    # Parse META.yaml
    phase="unknown"
    meta_file="$dir/META.yaml"
    if [ -f "$meta_file" ]; then
        phase=$(grep -m1 '^phase:' "$meta_file" 2>/dev/null | sed 's/phase:\s*//' | tr -d ' ' || echo "unknown")
    fi

    # Parse TASKS.md for task counts
    tasks_file="$dir/TASKS.md"
    blocked=0; p0_open=0; done_count=0; active_tasks=0
    if [ -f "$tasks_file" ]; then
        while IFS= read -r line; do
            ll=$(echo "$line" | tr '[:upper:]' '[:lower:]')
            if echo "$line" | grep -q '|'; then
                echo "$ll" | grep -q 'blocked' && blocked=$((blocked + 1))
                echo "$ll" | grep -qE 'p0.*(pending|in.progress|open|not.started)' && p0_open=$((p0_open + 1))
                echo "$ll" | grep -qE '(done|complete|✅)' && done_count=$((done_count + 1))
                echo "$ll" | grep -qE '(pending|in.progress|open|not.started)' && active_tasks=$((active_tasks + 1))
            fi
        done < "$tasks_file"
    fi

    # Assign tier
    tier="dormant"
    if [ "$newest_age" -le 7 ] && [ "$active_tasks" -gt 0 ]; then
        tier="active"
        active=$((active + 1))
    elif [ "$newest_age" -le 30 ] && [ "$active_tasks" -gt 0 ]; then
        tier="maintenance"
        maintenance=$((maintenance + 1))
    else
        dormant=$((dormant + 1))
    fi

    # Determine health status
    health="on-track"
    health_reason=""
    if [ "$blocked" -gt 0 ]; then
        health="at-risk"
        health_reason="${blocked} blocked"
    elif [ "$newest_age" -gt 30 ]; then
        health="at-risk"
        health_reason="no updates in ${newest_age}d"
    elif [ "$p0_open" -gt 2 ] || [ "$newest_age" -gt 14 ]; then
        health="needs-attention"
        health_reason="${p0_open} P0 open, ${newest_age}d since update"
    else
        health_reason="${active_tasks} active, ${done_count} done"
    fi

    echo "$LOG_PREFIX   $slug: tier=$tier health=$health ($health_reason)"

    # Build JSON entry
    health_entries="${health_entries}{\"slug\":\"$slug\",\"tier\":\"$tier\",\"health\":\"$health\",\"reason\":\"$health_reason\",\"phase\":\"$phase\",\"newest_age\":$newest_age,\"blocked\":$blocked,\"p0_open\":$p0_open,\"active_tasks\":$active_tasks,\"done\":$done_count},"
done

# Write health cache as JSON
health_entries="${health_entries%,}"  # Remove trailing comma
cat > "$CACHE_FILE" << EOF
{
  "generated": "$(date -Iseconds)",
  "summary": {"total": $total, "active": $active, "maintenance": $maintenance, "dormant": $dormant},
  "projects": [$health_entries]
}
EOF

echo "$LOG_PREFIX Summary: $active active, $maintenance maintenance, $dormant dormant (of $total)"

# Alert if any project is at-risk
at_risk_count=$(echo "$health_entries" | grep -o '"at-risk"' | wc -l || echo 0)
dormant_slugs=$(echo "$health_entries" | python3 -c "
import sys, json
entries = json.loads('[' + sys.stdin.read() + ']')
print(', '.join(p['slug'] for p in entries if p['tier'] == 'dormant'))
" 2>/dev/null || echo "")

if [ "$at_risk_count" -gt 0 ]; then
    msg="$at_risk_count project(s) at risk"
    [ -n "$dormant_slugs" ] && msg="$msg | dormant (archive?): $dormant_slugs"
    cron_alert "project-tier-assign" "$msg"
else
    cron_alert_clear "project-tier-assign"
fi

write_heartbeat "project-tier-assign"
echo "$LOG_PREFIX === Project Tier Assignment Done ==="
