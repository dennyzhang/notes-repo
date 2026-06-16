#!/usr/bin/env bash
# cron-ai-audit.sh — Daily AI automation reliability audit.
#
# Design doc: config/DAILY-DOCS.json key docs.ai_audit
#
# Scores AI automation health across 5 dimensions:
#   1. Cron Fleet Health — pass rates, consecutive failures, runtime trending
#   2. Output Quality — overnight outputs exist, non-empty, dated today, sized right
#   3. Rule Compliance — correction rate trending, anti-pattern detection
#   4. Learning Loop Health — entry freshness, duplicates, file sizes
#   5. Google Doc Integrity — comment counts stable, Self Eval tabs present
#
# Each dimension: GREEN (healthy), YELLOW (degrading), RED (broken).
# Fleet score = worst dimension (conservative).
#
# Output: context/cache/AI-AUDIT-REPORT.md
# Alert: ALERTS.md on RED, or YELLOW for 3+ consecutive days
#
# Crontab entry (in setup-claude.sh):
#   0 7 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 900 ai-audit ~/work/claude/scripts/cron-ai-audit.sh >> ~/logs/ai-audit.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-ai-audit.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
REPORT="$REPO_DIR/context/cache/AI-AUDIT-REPORT.md"
STATE_DIR="$REPO_DIR/context/cache/state"
JOURNAL_DIR="$REPO_DIR/context/cache/journals"
HISTORY="$STATE_DIR/AI-AUDIT-HISTORY.json"
COMMENT_COUNTS="$STATE_DIR/GDOC-COMMENT-COUNTS.json"
RUNTIME_CSV="$HOME/logs/cron-runtime.csv"
METRICS_FILE="$STATE_DIR/CLAUDE-SESSION-METRICS.md"

source "$SCRIPT_DIR/cron-alert.sh"

# Pre-check
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "ai-audit" "Workspace missing"
    exit 1
fi

# Prevent overlapping runs
LOCK_MAX_AGE_SECONDS=7200
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$LOG_PREFIX Lock held by pid $pid for ${lock_age}s — killing"
            kill "$pid" 2>/dev/null || true; sleep 2; kill -9 "$pid" 2>/dev/null || true
        else
            echo "$LOG_PREFIX Already running (pid $pid), skipping"
            exit 0
        fi
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$LOG_PREFIX === AI Audit ==="

# Initialize dimension scores
declare -A DIM_SCORE   # GREEN=0, YELLOW=1, RED=2
declare -A DIM_DETAIL
for d in fleet output compliance learning gdoc; do
    DIM_SCORE[$d]=0
    DIM_DETAIL[$d]=""
done

score_name() {
    case "$1" in
        0) echo "GREEN" ;;
        1) echo "YELLOW" ;;
        2) echo "RED" ;;
    esac
}

set_score() {
    local dim="$1" score="$2" detail="$3"
    if [ "$score" -gt "${DIM_SCORE[$dim]}" ]; then
        DIM_SCORE[$dim]=$score
    fi
    if [ -n "${DIM_DETAIL[$dim]}" ]; then
        DIM_DETAIL[$dim]="${DIM_DETAIL[$dim]}; $detail"
    else
        DIM_DETAIL[$dim]="$detail"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# DIMENSION 1: Cron Fleet Health
# ═══════════════════════════════════════════════════════════════════════════════
echo "$LOG_PREFIX [1] Cron Fleet Health"

if [ -f "$RUNTIME_CSV" ]; then
    # Compute pass rates over last 7 days
    seven_days_ago=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')
    total_runs=0
    total_pass=0
    failed_jobs=""

    while IFS=, read -r date job exit_code duration attempt; do
        [ "$date" = "date" ] && continue  # skip header
        run_date="${date%% *}"
        [[ "$run_date" < "$seven_days_ago" ]] && continue
        total_runs=$((total_runs + 1))
        if [ "$exit_code" = "0" ]; then
            total_pass=$((total_pass + 1))
        else
            # Track unique failed jobs
            echo "$job" >> /tmp/ai-audit-failed-jobs.$$
        fi
    done < "$RUNTIME_CSV"

    rm -f /tmp/ai-audit-failed-jobs.$$

    if [ "$total_runs" -gt 0 ]; then
        pass_rate=$((total_pass * 100 / total_runs))
        fleet_detail="${pass_rate}% pass rate (${total_pass}/${total_runs} runs, 7-day)"

        if [ "$pass_rate" -lt 90 ]; then
            set_score fleet 2 "$fleet_detail"
        elif [ "$pass_rate" -lt 95 ]; then
            set_score fleet 1 "$fleet_detail"
        else
            set_score fleet 0 "$fleet_detail"
        fi
    else
        set_score fleet 1 "No runtime data in last 7 days"
    fi

    # Check for consecutive failures (same job failing 2+ times in a row)
    prev_job=""
    prev_exit=""
    consec_count=0
    consec_alerts=""
    while IFS=, read -r date job exit_code duration attempt; do
        [ "$date" = "date" ] && continue
        if [ "$job" = "$prev_job" ] && [ "$exit_code" != "0" ] && [ "$prev_exit" != "0" ]; then
            consec_count=$((consec_count + 1))
            if [ "$consec_count" -ge 2 ]; then
                consec_alerts="${consec_alerts}${job} "
            fi
        else
            consec_count=0
        fi
        prev_job="$job"
        prev_exit="$exit_code"
    done < "$RUNTIME_CSV"

    if [ -n "$consec_alerts" ]; then
        set_score fleet 1 "Consecutive failures: $consec_alerts"
    fi
else
    set_score fleet 1 "No cron-runtime.csv found"
fi

# Check active alerts count
active_alerts=$(grep -c "^- \*\*" "$REPO_DIR/ALERTS.md" 2>/dev/null || echo "0")
if [ "$active_alerts" -gt 3 ]; then
    set_score fleet 2 "${active_alerts} active alerts"
elif [ "$active_alerts" -gt 0 ]; then
    set_score fleet 1 "${active_alerts} active alert(s)"
fi

echo "$LOG_PREFIX   Fleet: $(score_name ${DIM_SCORE[fleet]}) — ${DIM_DETAIL[fleet]}"

# ═══════════════════════════════════════════════════════════════════════════════
# DIMENSION 2: Output Quality Spot-Check
# ═══════════════════════════════════════════════════════════════════════════════
echo "$LOG_PREFIX [2] Output Quality"

CACHE="$REPO_DIR/context/cache"
quality_issues=0

check_output() {
    local name="$1" file="$2" min_bytes="${3:-100}" max_bytes="${4:-500000}"

    if [ ! -f "$file" ]; then
        set_score output 1 "$name: file missing"
        quality_issues=$((quality_issues + 1))
        return
    fi

    local size
    size=$(wc -c < "$file" 2>/dev/null || echo "0")

    # Check if file was updated today
    local file_date
    file_date=$(date -r "$file" '+%Y-%m-%d' 2>/dev/null || echo "unknown")

    if [ "$file_date" != "$TODAY" ]; then
        set_score output 1 "$name: stale (last updated $file_date)"
        quality_issues=$((quality_issues + 1))
        return
    fi

    if [ "$size" -lt "$min_bytes" ]; then
        set_score output 1 "$name: truncated (${size} bytes, min ${min_bytes})"
        quality_issues=$((quality_issues + 1))
        return
    fi

    if [ "$size" -gt "$max_bytes" ]; then
        set_score output 1 "$name: bloated (${size} bytes, max ${max_bytes})"
        quality_issues=$((quality_issues + 1))
        return
    fi
}

# Check key overnight outputs
check_output "MEETING-PREP" "$CACHE/MEETING-PREP-TODAY.md" 30
check_output "OT-TRIAGE" "$CACHE/OT-SUPPORT-TRIAGE.md" 100
check_output "AREA-MONITOR" "$CACHE/AREA-MONITOR.md" 100

if [ "$quality_issues" -ge 2 ]; then
    set_score output 2 "${quality_issues} outputs failed checks"
elif [ "$quality_issues" -eq 0 ]; then
    set_score output 0 "All outputs present and sized correctly"
fi

echo "$LOG_PREFIX   Output: $(score_name ${DIM_SCORE[output]}) — ${DIM_DETAIL[output]:-all good}"

# ═══════════════════════════════════════════════════════════════════════════════
# DIMENSION 3: Rule Compliance Sampling
# ═══════════════════════════════════════════════════════════════════════════════
echo "$LOG_PREFIX [3] Rule Compliance"

if [ -f "$METRICS_FILE" ]; then
    # Parse last 5 sessions for correction rate
    recent_corrections=0
    recent_sessions=0
    while IFS='|' read -r _ date tasks corrections _ _ autonomy _; do
        # Skip header and separator lines
        [[ "$date" =~ ^[[:space:]]*-+[[:space:]]*$ ]] && continue
        [[ "$date" =~ ^[[:space:]]*Date ]] && continue
        [ -z "$date" ] && continue

        # Extract date prefix
        session_date=$(echo "$date" | tr -d ' ' | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "")
        [ -z "$session_date" ] && continue

        # Only count recent sessions (last 3 days)
        three_days_ago=$(date -d '3 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-3d '+%Y-%m-%d')
        [[ "$session_date" < "$three_days_ago" ]] && continue

        corr=$(echo "$corrections" | tr -d ' ')
        if [[ "$corr" =~ ^[0-9]+$ ]]; then
            recent_corrections=$((recent_corrections + corr))
            recent_sessions=$((recent_sessions + 1))
        fi
    done < "$METRICS_FILE"

    if [ "$recent_sessions" -gt 0 ]; then
        avg_corr=$((recent_corrections * 100 / recent_sessions))  # x100 for precision
        avg_display="$((avg_corr / 100)).$((avg_corr % 100))"
        compliance_detail="Avg ${avg_display} corrections/session (last ${recent_sessions} sessions)"

        if [ "$avg_corr" -gt 400 ]; then  # >4.0 corrections avg
            set_score compliance 2 "$compliance_detail"
        elif [ "$avg_corr" -gt 200 ]; then  # >2.0
            set_score compliance 1 "$compliance_detail"
        else
            set_score compliance 0 "$compliance_detail"
        fi
    else
        set_score compliance 0 "No recent sessions to sample"
    fi

    # Check for sycophantic patterns in recent session files
    sycophancy_count=0
    for sf in $(ls -t ~/.claude/sessions/${TODAY}*.md 2>/dev/null | head -3); do
        hits=$(grep -ciE 'great question|absolutely|I.d be happy to|game.changer|excellent point' "$sf" 2>/dev/null || echo "0")
        hits=$(echo "$hits" | grep -oE '^[0-9]+' | head -1)
        hits="${hits:-0}"
        sycophancy_count=$((sycophancy_count + hits))
    done
    if [ "$sycophancy_count" -gt 5 ]; then
        set_score compliance 1 "Sycophancy detected (${sycophancy_count} instances in recent sessions)"
    fi
else
    set_score compliance 1 "No session metrics file found"
fi

echo "$LOG_PREFIX   Compliance: $(score_name ${DIM_SCORE[compliance]}) — ${DIM_DETAIL[compliance]:-all good}"

# ═══════════════════════════════════════════════════════════════════════════════
# DIMENSION 4: Learning Loop Health
# ═══════════════════════════════════════════════════════════════════════════════
echo "$LOG_PREFIX [4] Learning Loop"

# MEMORY.md size check
MEMORY_FILE="$HOME/.claude/projects/-home-dennyzhang-work-claude/memory/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    mem_lines=$(wc -l < "$MEMORY_FILE")
    if [ "$mem_lines" -gt 200 ]; then
        set_score learning 1 "MEMORY.md at ${mem_lines} lines (limit 200)"
    else
        set_score learning 0 "MEMORY.md at ${mem_lines} lines"
    fi
else
    set_score learning 0 "No MEMORY.md (expected)"
fi

# JOURNAL.md freshness — entries should exist within last 7 days
JOURNAL="$JOURNAL_DIR/JOURNAL.md"
if [ -f "$JOURNAL" ]; then
    latest_entry=$(grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$JOURNAL" | sort -r | head -1)
    if [ -n "$latest_entry" ]; then
        seven_days_ago=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')
        if [[ "$latest_entry" < "$seven_days_ago" ]]; then
            set_score learning 1 "JOURNAL.md stale (last entry $latest_entry)"
        fi
    fi
fi

# AUTO-LEARNINGS.md size check
AUTO_LEARNINGS="$REPO_DIR/config/AUTO-LEARNINGS.md"
if [ -f "$AUTO_LEARNINGS" ]; then
    al_entries=$(grep -c "^###\|^- \*\*When" "$AUTO_LEARNINGS" 2>/dev/null || echo "0")
    if [ "$al_entries" -gt 50 ]; then
        set_score learning 1 "AUTO-LEARNINGS.md has ${al_entries} entries (review needed, >50)"
    fi
fi

# PATTERNS.md — check it exists and has entries
PATTERNS="$REPO_DIR/context/myself/PATTERNS.md"
if [ -f "$PATTERNS" ]; then
    pattern_count=$(grep -c "^###" "$PATTERNS" 2>/dev/null || echo "0")
    set_score learning 0 "PATTERNS.md has ${pattern_count} entries"
fi

echo "$LOG_PREFIX   Learning: $(score_name ${DIM_SCORE[learning]}) — ${DIM_DETAIL[learning]:-all good}"

# ═══════════════════════════════════════════════════════════════════════════════
# DIMENSION 5: Google Doc Integrity
# ═══════════════════════════════════════════════════════════════════════════════
echo "$LOG_PREFIX [5] Google Doc Integrity"

# Parse daily docs from CLAUDE.md
declare -A DOCS
DOCS[routine]="$(get_doc_id routine)"
DOCS[research]="$(get_doc_id research)"
DOCS[ai_feedback]="$(get_doc_id ai_feedback_log)"
DOCS[ot_triage]="$(get_doc_id project_context)"

# Check google-mux health first
if ! ensure_gmux_healthy 2>/dev/null; then
    set_score gdoc 1 "google-mux not responsive — skipping doc checks"
    echo "$LOG_PREFIX   GDoc: YELLOW — google-mux down"
else
    # Initialize comment counts file if missing
    if [ ! -f "$COMMENT_COUNTS" ]; then
        echo '{}' > "$COMMENT_COUNTS"
    fi

    prev_counts=$(cat "$COMMENT_COUNTS")
    new_counts="{"
    gdoc_issues=0
    checked=0

    for name in "${!DOCS[@]}"; do
        doc_id="${DOCS[$name]}"

        # Get comment count
        comment_output=$(timeout 10 gdocs comments list "$doc_id" 2>/dev/null || echo "")
        if [ -n "$comment_output" ]; then
            # Count unresolved comments (lines with COMMENT_ID that don't say "resolved")
            current_count=$(echo "$comment_output" | grep -c "COMMENT_ID\|^[A-Za-z]" 2>/dev/null || echo "0")

            # Get previous count
            prev_count=$(echo "$prev_counts" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('$name', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

            # Detect comment destruction (count dropped by 3+)
            if [ "$prev_count" -gt 0 ] && [ "$current_count" -lt "$((prev_count - 2))" ]; then
                set_score gdoc 2 "$name: comment count dropped ${prev_count}→${current_count} (possible destruction)"
                gdoc_issues=$((gdoc_issues + 1))
            fi

            [ "$checked" -gt 0 ] && new_counts="${new_counts},"
            new_counts="${new_counts}\"${name}\":${current_count}"
            checked=$((checked + 1))
        fi
    done
    new_counts="${new_counts}}"

    # Save new counts
    echo "$new_counts" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))" > "$COMMENT_COUNTS" 2>/dev/null || echo "$new_counts" > "$COMMENT_COUNTS"

    if [ "$gdoc_issues" -eq 0 ] && [ "$checked" -gt 0 ]; then
        set_score gdoc 0 "${checked} docs checked, comment counts stable"
    fi

    echo "$LOG_PREFIX   GDoc: $(score_name ${DIM_SCORE[gdoc]}) — ${DIM_DETAIL[gdoc]:-all good}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# GENERATE REPORT
# ═══════════════════════════════════════════════════════════════════════════════
echo "$LOG_PREFIX [6] Generating report"

# Compute fleet score (worst dimension)
fleet_worst=0
for d in fleet output compliance learning gdoc; do
    [ "${DIM_SCORE[$d]}" -gt "$fleet_worst" ] && fleet_worst=${DIM_SCORE[$d]}
done

cat > "$REPORT" << EOF
# AI Audit Report — $TODAY

**Fleet Health**: $(score_name $fleet_worst)

**Design doc**: [AI Automation Reliability Audit](https://docs.google.com/document/d/$(get_doc_id ai_audit)/edit)

## Dimension Scores

| Dimension | Score | Detail |
|-----------|-------|--------|
| Cron Fleet | $(score_name ${DIM_SCORE[fleet]}) | ${DIM_DETAIL[fleet]:-healthy} |
| Output Quality | $(score_name ${DIM_SCORE[output]}) | ${DIM_DETAIL[output]:-all outputs present} |
| Rule Compliance | $(score_name ${DIM_SCORE[compliance]}) | ${DIM_DETAIL[compliance]:-no issues} |
| Learning Loop | $(score_name ${DIM_SCORE[learning]}) | ${DIM_DETAIL[learning]:-healthy} |
| GDoc Integrity | $(score_name ${DIM_SCORE[gdoc]}) | ${DIM_DETAIL[gdoc]:-all docs intact} |

## Alerts
EOF

# Add alerts section
has_alerts=false
for d in fleet output compliance learning gdoc; do
    if [ "${DIM_SCORE[$d]}" -ge 2 ]; then
        echo "- **RED** [$d]: ${DIM_DETAIL[$d]}" >> "$REPORT"
        has_alerts=true
    elif [ "${DIM_SCORE[$d]}" -ge 1 ]; then
        echo "- **YELLOW** [$d]: ${DIM_DETAIL[$d]}" >> "$REPORT"
        has_alerts=true
    fi
done

if ! $has_alerts; then
    echo "(none)" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT"

# ═══════════════════════════════════════════════════════════════════════════════
# ALERTING
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$fleet_worst" -ge 2 ]; then
    # RED — alert immediately
    red_dims=""
    for d in fleet output compliance learning gdoc; do
        [ "${DIM_SCORE[$d]}" -ge 2 ] && red_dims="${red_dims}${d} "
    done
    cron_alert "ai-audit" "RED on: ${red_dims}— see AI-AUDIT-REPORT.md"
else
    # Check for sustained YELLOW (3+ consecutive days)
    # Track in history file
    if [ ! -f "$HISTORY" ]; then
        echo '[]' > "$HISTORY"
    fi

    # Append today's scores
    today_entry="{\"date\":\"$TODAY\""
    for d in fleet output compliance learning gdoc; do
        today_entry="${today_entry},\"${d}\":${DIM_SCORE[$d]}"
    done
    today_entry="${today_entry}}"

    python3 -c "
import json, sys
try:
    with open('$HISTORY') as f:
        history = json.load(f)
except:
    history = []
history.append($today_entry)
# Keep last 30 days
history = history[-30:]
with open('$HISTORY', 'w') as f:
    json.dump(history, f, indent=2)

# Check for 3-day YELLOW streak on any dimension
dims = ['fleet', 'output', 'compliance', 'learning', 'gdoc']
if len(history) >= 3:
    for d in dims:
        last3 = [h.get(d, 0) for h in history[-3:]]
        if all(s >= 1 for s in last3):
            print(f'YELLOW_STREAK:{d}')
" 2>/dev/null | while read -r line; do
        if [[ "$line" == YELLOW_STREAK:* ]]; then
            dim="${line#YELLOW_STREAK:}"
            cron_alert "ai-audit" "YELLOW 3+ days on ${dim} — see AI-AUDIT-REPORT.md"
        fi
    done

    # Clear alert if all green
    if [ "$fleet_worst" -eq 0 ]; then
        cron_alert_clear "ai-audit"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Heartbeat
# ═══════════════════════════════════════════════════════════════════════════════

write_heartbeat "ai-audit"
echo "$LOG_PREFIX === AI Audit Complete ($(score_name $fleet_worst)) ==="
