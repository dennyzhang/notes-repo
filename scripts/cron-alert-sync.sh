#!/usr/bin/env bash
# cron-alert-sync.sh — LLM-powered daily alert dashboard → Google Doc.
#
# Combines ALERTS.md + AI-AUDIT-REPORT.md into a smart daily dashboard
# in the "Alerts" tab of the AI Feedback Log Google Doc. Claude LLM
# prioritizes, diagnoses root causes, and generates the HTML.
#
# Three phases:
#   1. Data collection — parse ALERTS.md, audit report, cron stats (bash, ~5s)
#   2. LLM synthesis — Claude analyzes + generates HTML dashboard (sonnet, ~60s)
#   3. Google Doc push — delete+insert tab rewrite (bash, ~5s)
#
# Output: Alerts tab in AI Feedback Log Google Doc
# History: context/cache/state/ALERT-SYNC-HISTORY.json (rolling 7 days)
#
# Crontab entry (in setup-claude.sh):
#   15 6 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 300 alert-sync ~/work/claude/scripts/cron-alert-sync.sh >> ~/logs/alert-sync.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-alert-sync.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/gdocs_lib.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Google Doc config — read from centralized config
DOC_ID="$(get_doc_id ai_feedback_log)"
TAB_ID="$(get_doc_tab ai_feedback_log alerts)"

# Address open comments BEFORE adding the new day's content (operator rule 2026-06-14)
gdoc_address_comments_first "$DOC_ID"

# Source files
ALERTS_FILE="$REPO_DIR/ALERTS.md"
AUDIT_REPORT="$REPO_DIR/context/cache/AI-AUDIT-REPORT.md"
RUNTIME_CSV="$HOME/logs/cron-runtime.csv"
STATE_DIR="$REPO_DIR/context/cache/state"
HISTORY_FILE="$STATE_DIR/ALERT-SYNC-HISTORY.json"

source "$SCRIPT_DIR/cron-alert.sh"

# ═══════════════════════════════════════════════════════════════════════════
# PRE-CHECKS
# ═══════════════════════════════════════════════════════════════════════════

if [ ! -f "$ALERTS_FILE" ]; then
    echo "$LOG_PREFIX [FAIL] ALERTS.md not found"
    exit 1
fi

# Prevent overlapping runs
LOCK_MAX_AGE_SECONDS=600
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

# Check google-mux health (retry once after restart — daemon is flaky at cron time)
if ! ensure_gmux_healthy; then
    echo "$LOG_PREFIX [WARN] google-mux unhealthy — restarting and retrying..."
    pkill -9 -f "google-mux daemon" 2>/dev/null || true
    rm -f /tmp/gmux-${USER}*.sock 2>/dev/null || true
    sleep 3
    if ! ensure_gmux_healthy; then
        echo "$LOG_PREFIX [FAIL] google-mux not healthy after restart — cannot write to Google Doc"
        cron_alert "alert-sync" "google-mux not healthy"
        exit 1
    fi
    echo "$LOG_PREFIX [OK] google-mux recovered after restart"
fi

# ═══════════════════════════════════════════════════════════════════════════
# COMMENT SAFETY CHECK — never rewrite tab if unresolved comments exist
# ═══════════════════════════════════════════════════════════════════════════
# deleteContentRange destroys comment anchors. If Denny has unresolved comments
# on the Alerts tab, skip the rewrite — his comments are more important than
# a fresh dashboard. Comments get processed by cron-gdoc-comments.sh every 30 min.

unresolved_on_alerts=$(gdocs get "$DOC_ID" --tab-id "$TAB_ID" 2>/dev/null \
    | grep -c 'data-id="[^"]*".*data-author.*data-quote' || true)
resolved_on_alerts=$(gdocs get "$DOC_ID" --tab-id "$TAB_ID" 2>/dev/null \
    | grep -c 'data-resolved="true"' || true)
active_comments=$(( unresolved_on_alerts - resolved_on_alerts ))

if [ "$active_comments" -gt 0 ]; then
    echo "$LOG_PREFIX [SKIP] $active_comments unresolved comments on Alerts tab — skipping rewrite to preserve comment anchors"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: DATA COLLECTION (~5s)
# ═══════════════════════════════════════════════════════════════════════════

# Tier 3: capture pre-push revision for rollback-safe alerts.
gdocs_capture_prepush_revision "$DOC_ID" "alert_sync" || true

echo "$LOG_PREFIX [1] Collecting data"

WORK_DIR=$(mktemp -d /tmp/cron-alert-sync-XXXXX)
trap 'rm -f "$LOCK_FILE"; rm -rf "$WORK_DIR"' EXIT

# 1a. Parse ALERTS.md — active alerts
active_alerts=""
if grep -q "^- \*\*" "$ALERTS_FILE" 2>/dev/null; then
    active_alerts=$(sed -n '/^## Active Alerts/,/^## /{ /^- \*\*/p }' "$ALERTS_FILE")
fi

# 1b. Parse ALERTS.md — resolved alerts (last 7 days)
resolved_alerts=""
if grep -q "^| 2026-" "$ALERTS_FILE" 2>/dev/null; then
    cutoff_date=$(date -d '7 days ago' '+%Y-%m-%d')
    resolved_alerts=$(awk -v cutoff="$cutoff_date" '
        /^\| Date/ { next }
        /^\|---/ { next }
        /^\| 20[0-9][0-9]-/ {
            date = $2
            if (date >= cutoff) print
        }
    ' "$ALERTS_FILE")
fi

# 1c. Read audit report
audit_content=""
if [ -f "$AUDIT_REPORT" ]; then
    audit_content=$(cat "$AUDIT_REPORT")
fi

# 1d. Cron fleet stats (last 7 days) with duration trending
# Split into recent (last 3 days) vs earlier (4-7 days ago) for trend detection
cron_stats=""
if [ -f "$RUNTIME_CSV" ]; then
    cutoff_7d=$(date -d '7 days ago' '+%Y-%m-%d')
    cutoff_3d=$(date -d '3 days ago' '+%Y-%m-%d')
    cron_stats=$(awk -F',' -v cutoff7="$cutoff_7d" -v cutoff3="$cutoff_3d" '
        NR==1 { next }
        $1 >= cutoff7 {
            job=$2; exit_code=$3; dur=$4
            total[job]++
            if (exit_code == 0) pass[job]++
            dur_sum[job] += dur
            if ($1 >= cutoff3) {
                recent_sum[job] += dur; recent_count[job]++
            } else {
                earlier_sum[job] += dur; earlier_count[job]++
            }
        }
        END {
            for (j in total) {
                p = (j in pass) ? pass[j] : 0
                avg_dur = (total[j] > 0) ? int(dur_sum[j] / total[j]) : 0
                pct = int(p * 100 / total[j])
                recent_avg = (recent_count[j] > 0) ? int(recent_sum[j] / recent_count[j]) : 0
                earlier_avg = (earlier_count[j] > 0) ? int(earlier_sum[j] / earlier_count[j]) : 0
                trend = "stable"
                if (earlier_avg > 0 && recent_avg > earlier_avg * 1.5) trend = "slower"
                else if (earlier_avg > 0 && recent_avg < earlier_avg * 0.7) trend = "faster"
                printf "%s: %d/%d (%d%%) avg=%ds trend=%s (recent=%ds earlier=%ds)\n", j, p, total[j], pct, avg_dur, trend, recent_avg, earlier_avg
            }
        }
    ' "$RUNTIME_CSV" | sort)
fi

# 1e. Load rolling history
history_content="[]"
if [ -f "$HISTORY_FILE" ]; then
    history_content=$(cat "$HISTORY_FILE")
fi

# 1f. Write collected data to JSON for LLM
cat > "$WORK_DIR/alert-data.json" <<DATAJSON
{
  "date": "$TODAY",
  "active_alerts": $(echo "$active_alerts" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),
  "resolved_alerts": $(echo "$resolved_alerts" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),
  "audit_report": $(echo "$audit_content" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),
  "cron_stats": $(echo "$cron_stats" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),
  "history": $history_content
}
DATAJSON

echo "$LOG_PREFIX [1] Data collected: $(wc -c < "$WORK_DIR/alert-data.json") bytes"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: LLM SYNTHESIS (~60s)
# ═══════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [2] LLM synthesis"
llm_start=$(date +%s)

# Load template for reference
TEMPLATE_FILE="$REPO_DIR/workflows/templates/ALERT-DASHBOARD-TEMPLATE.html"

PROMPT=$(cat <<'PROMPT_EOF'
You are generating a daily alert dashboard for a Google Doc tab. Read the collected data from $WORK_DIR/alert-data.json (path provided via environment), analyze it, and produce an HTML dashboard.

Also read the template at $REPO_DIR/workflows/templates/ALERT-DASHBOARD-TEMPLATE.html for the canonical format.

## Instructions

1. Read the data file at the path in $WORK_DIR/alert-data.json
2. Read the template file for format reference
3. Analyze the alerts and audit data:
   - Prioritize active alerts by severity and actionability
   - Identify root-cause correlations (e.g., multiple alerts from same underlying issue like cert expiry)
   - Classify each alert: ACTION_REQUIRED (human must act), SELF_HEALING (will resolve), INFORMATIONAL (just noise)
   - Summarize audit dimension scores into a compact table
4. Write the HTML dashboard to $WORK_DIR/alert-dashboard.html

## HTML Structure — Day-by-Day Format

The dashboard is organized DAY BY DAY. Today gets full detail; previous days get one-line summaries.

```html
<h1>Daily Alert Dashboard</h1>
<p><i>Generated by cron-alert-sync.sh (daily 6:15am) | Last updated: TIMESTAMP</i></p>

<h2>YYYY-MM-DD (Today)</h2>

<h3>1. P0 Asks</h3>
<p><!-- FIRST subsection — most important. Extract from active alerts: what specific human actions
     are BLOCKED and needed from Denny RIGHT NOW. Ultra-short: 1-3 bullet points max.
     If no P0 asks: "(none — all self-healing or informational)" --></p>

<h3>2. Fleet Health</h3>
<table>
  <tr><td style="background-color: #C9DAF8"><b>Dimension</b></td><td style="background-color: #C9DAF8"><b>Score</b></td><td style="background-color: #C9DAF8"><b>Issue Breakdown</b></td></tr>
  <!-- SORT ORDER: RED rows first, then YELLOW, then GREEN. Important things first.
       Rename "GDoc Integrity" → "Dependency Reliability" (covers google-mux, FBID cert, daemon health). -->
</table>

<h3>3. Active Alerts</h3>
<table>
  <tr><td style="background-color: #C9DAF8"><b>Time</b></td><td style="background-color: #C9DAF8"><b>Source</b></td><td style="background-color: #C9DAF8"><b>Issue + Root Cause</b></td><td style="background-color: #C9DAF8"><b>Action</b></td></tr>
  <!-- 4 columns (not 5). "Issue + Root Cause" merged: issue paragraph, blank line, root cause paragraph.
       Time: HH:MM only. Do NOT bold entire rows — use normal weight for all data rows.
       Only table headers are bold. -->
</table>
<p>If no active alerts: <i>(none — all clear)</i></p>

<h3>4. Cron Fleet Stats</h3>
<table>
  <tr><td style="background-color: #C9DAF8"><b>Job</b></td><td style="background-color: #C9DAF8"><b>Pass Rate</b></td><td style="background-color: #C9DAF8"><b>Avg Duration</b></td><td style="background-color: #C9DAF8"><b>Trend</b></td></tr>
  <!-- Sorted by pass rate ascending. Color: RED <80%, YELLOW 80-95%, GREEN >95%.
       Trend column: compare current avg duration vs previous period. Show arrow:
       "↑ 2x slower" if current avg > 1.5x previous avg,
       "↓ faster" if current avg < 0.7x previous,
       "→ stable" otherwise. This surfaces jobs silently degrading in runtime. -->
</table>

<h3>5. Resolved Today</h3>
<table>
  <tr><td style="background-color: #C9DAF8"><b>Alert</b></td><td style="background-color: #C9DAF8"><b>Resolution</b></td></tr>
</table>
<p>If none: <i>(no resolutions today)</i></p>

<!-- Previous days from history — one h2 + one-line summary each -->
<h2>YYYY-MM-DD-1</h2>
<p>Fleet: RED | 4 active alerts | Key: FBID cert expiry cascade</p>

<h2>YYYY-MM-DD-2</h2>
<p>Fleet: GREEN | 0 active alerts | All clear</p>
```

## Rules
- Do NOT use <th> tags — Google Docs does not render them. Use <td> with background-color and <b> instead.
- Do NOT use data-col-widths attributes.
- Do NOT use <br> or <p> inside table cells — use actual newline characters for line breaks within cells.
- Color-code score cells: GREEN=#D9EAD3, YELLOW=#FFF2CC, RED=#F4CCCC
- Keep the HTML compact — no unnecessary whitespace or comments.
- Time column: HH:MM only. No year, no full date — the date is already in the h2 heading above.
- Column "Issue Breakdown" (NOT "Detail"): break compound info into separate lines. Include the REASON for each failure.
- "Issue + Root Cause" is ONE merged column (not two). Issue is the first paragraph, root cause is the second paragraph, separated by a blank line.
- The "Action" column: specific steps, one per line: "Renew FBID cert", "Restart google-mux", etc.
- Rename "GDoc Integrity" dimension to "Dependency Reliability" — it covers google-mux, FBID cert, daemon health, not just docs.
- P0 Asks subsection: extract the 1-3 most urgent human actions from active alerts. Ultra-short bullets.
- Fleet Health table: SORT rows by severity — RED first, then YELLOW, then GREEN. Important things first.
- Cron Fleet Stats: add a "Trend" column showing if jobs are getting slower. Use "↑ slower" / "→ stable" / "↓ faster" based on recent vs earlier avg duration from the data.
- Subsections numbered: "1. P0 Asks", "2. Fleet Health", "3. Active Alerts", "4. Cron Fleet Stats", "5. Resolved Today".
- P0 Asks is FIRST (most important). Put it before Fleet Health.
- Do NOT bold entire data rows in tables. Only table HEADERS get bold. Data rows use normal weight.
PROMPT_EOF
)

# Set WORK_DIR for Claude to use
export WORK_DIR

run_llm "alert-sync" 540 "$WORK_DIR/llm-output.log" "WORK_DIR=$WORK_DIR

$PROMPT" -- \
    --allowedTools Read Write Bash \
    --max-turns 5 \
    --output-format text

llm_exit=$?
llm_end=$(date +%s)
llm_duration=$((llm_end - llm_start))

if [ $llm_exit -ne 0 ]; then
    echo "$LOG_PREFIX [FAIL] LLM exited with code $llm_exit after ${llm_duration}s"
    tail -20 "$WORK_DIR/llm-output.log"
    cron_alert "alert-sync" "LLM synthesis failed (exit $llm_exit, ${llm_duration}s)"
    exit 1
fi

echo "$LOG_PREFIX [2] LLM synthesis complete (${llm_duration}s)"

# Verify HTML output exists
if [ ! -s "$WORK_DIR/alert-dashboard.html" ]; then
    echo "$LOG_PREFIX [FAIL] LLM did not produce alert-dashboard.html"
    cron_alert "alert-sync" "LLM produced no HTML output"
    exit 1
fi

echo "$LOG_PREFIX HTML output: $(wc -c < "$WORK_DIR/alert-dashboard.html") bytes"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: GOOGLE DOC PUSH (~5s)
# ═══════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [3] Pushing to Google Doc"

# Step 3a: Get tab content range for delete
end_idx=$(gdocs content get-structure "$DOC_ID" --tab-id "$TAB_ID" 2>/dev/null \
    | grep '^\[' | tail -1 | grep -oP '\d+' | tail -1 || echo "")

if [ -z "$end_idx" ] || [ "$end_idx" -lt 2 ]; then
    echo "$LOG_PREFIX [WARN] Could not get Alerts tab structure (end_idx=$end_idx) — tab may be empty"
    end_idx=2
fi

# Step 3b: Delete existing content (if any)
delete_end=$((end_idx - 1))
if [ "$delete_end" -gt 1 ]; then
    if ! echo "[{\"deleteContentRange\":{\"range\":{\"startIndex\":1,\"endIndex\":$delete_end,\"tabId\":\"$TAB_ID\"}}}]" \
        | gdocs batch-update "$DOC_ID" --data - 2>/dev/null; then
        echo "$LOG_PREFIX [WARN] Failed to delete tab content — inserting anyway"
    fi
fi

# Step 3c: Insert HTML
if gdocs content insert-text "$DOC_ID" @"$WORK_DIR/alert-dashboard.html" --html --tab-id "$TAB_ID" --index 1 2>/dev/null; then
    echo "$LOG_PREFIX [OK] Alerts tab updated successfully"
else
    echo "$LOG_PREFIX [FAIL] Failed to insert HTML into Alerts tab"
    cron_alert "alert-sync" "Failed to insert HTML into Google Doc"
    exit 1
fi

# Step 3d: Set proportional column widths on all tables (single batched API call)
echo "$LOG_PREFIX [3d] Setting table column widths"
structure=$(gdocs content get-structure "$DOC_ID" --tab-id "$TAB_ID" 2>/dev/null || true)
table_starts=$(echo "$structure" | grep 'TABLE:' | grep -oP '^\[\K\d+' || true)
table_idx=0
batch_json="["
for tstart in $table_starts; do
    table_idx=$((table_idx + 1))
    case $table_idx in
        1) # Fleet Health: 3 cols (130, 70, 268)
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":130,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":70,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":268,"unit":"PT"}},"fields":"widthType,width"}},'
            ;;
        2) # Active Alerts: 4 cols (50, 90, 230, 98)
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":50,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":90,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":230,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[3],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":98,"unit":"PT"}},"fields":"widthType,width"}},'
            ;;
        3) # Cron Fleet Stats: 4 cols (130, 100, 100, 138)
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":130,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":100,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":100,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[3],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":138,"unit":"PT"}},"fields":"widthType,width"}},'
            ;;
        4) # Resolved Today: 2 cols (200, 268)
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":200,"unit":"PT"}},"fields":"widthType,width"}},'
            batch_json+='{"updateTableColumnProperties":{"tableStartLocation":{"index":'$tstart',"tabId":"'$TAB_ID'"},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":268,"unit":"PT"}},"fields":"widthType,width"}},'
            ;;
    esac
done
batch_json="${batch_json%,}]"
if echo "$batch_json" | gdocs batch-update "$DOC_ID" --data - 2>/dev/null; then
    echo "$LOG_PREFIX   All table widths set (1 API call)"
else
    echo "$LOG_PREFIX   [WARN] Table widths failed — retrying after gmux restart"
    pkill -9 -f "google-mux daemon" 2>/dev/null || true
    rm -f /tmp/gmux-${USER}*.sock 2>/dev/null || true
    sleep 3
    if echo "$batch_json" | gdocs batch-update "$DOC_ID" --data - 2>/dev/null; then
        echo "$LOG_PREFIX   Table widths applied (retry)"
    else
        gdocs_track_error "batch-update failed (table-widths-retry) at $0:$LINENO"
    fi
fi

# Step 3e: Set 11pt body font on all tables + clean empty lines
echo "$LOG_PREFIX [3e] Formatting tables (11pt body font, cleanup empty lines)"
if [ -n "$structure" ]; then
    # Font sizing: 11pt across tables + non-empty body paragraphs.
    # Helper uses endIndex-1 on tables to prevent style bleed to next element
    # (prior inline used endIndex — swapping to endIndex-1 is a correctness fix).
    # Surfaces helper errors instead of silently swallowing to "[]".
    font_json=$(echo "$structure" | python3 "$GDOCS_HELPER_PY" body-font --tab-id "$TAB_ID" --size 11) \
        || gdocs_track_error "body-font helper failed (alert-sync) at $0:$LINENO"
    if [ -n "${font_json:-}" ] && [ "$font_json" != "[]" ]; then
        if echo "$font_json" | gdocs batch-update "$DOC_ID" --data - 2>/dev/null; then
            echo "$LOG_PREFIX   Body fonts set to 11pt"
        else
            gdocs_track_error "batch-update failed (alert-sync-body-font) at $0:$LINENO"
        fi
    fi

    # Empty line cleanup: use shared script (handles heading downgrade too)
    source ~/work/claude/scripts/gdocs-cleanup-empty-lines.sh
    gdocs_cleanup_empty_lines "$DOC_ID" --tab-id "$TAB_ID" --log-prefix "$LOG_PREFIX  "
fi

# ═══════════════════════════════════════════════════════════════════════════
# UPDATE HISTORY
# ═══════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [4] Updating history"

# Count active alerts
active_count=0
if [ -n "$active_alerts" ]; then
    active_count=$(echo "$active_alerts" | grep -c "^- \*\*" || true)
fi

# Extract fleet health from audit report
fleet_health="UNKNOWN"
if [ -n "$audit_content" ]; then
    fleet_health=$(echo "$audit_content" | grep -oP '(?<=\*\*Fleet Health\*\*: )\w+' || echo "UNKNOWN")
fi

# Build today's history entry and merge with rolling 7-day history
python3 -c "
import json, sys
from datetime import datetime, timedelta

history_file = '$HISTORY_FILE'
today = '$TODAY'
active_count = $active_count
fleet_health = '$fleet_health'
cutoff = (datetime.strptime(today, '%Y-%m-%d') - timedelta(days=7)).strftime('%Y-%m-%d')

# Load existing history
try:
    with open(history_file) as f:
        history = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    history = []

# Remove today's entry if exists (re-run), and entries older than 7 days
history = [h for h in history if h.get('date') != today and h.get('date', '') >= cutoff]

# Add today's entry
today_entry = {
    'date': today,
    'fleet_health': fleet_health,
    'active_count': active_count,
    'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M')
}
history.append(today_entry)
history.sort(key=lambda x: x.get('date', ''), reverse=True)

with open(history_file, 'w') as f:
    json.dump(history, f, indent=2)

print(f'History updated: {len(history)} entries')
"

echo "$LOG_PREFIX === Alert sync complete ==="

# Success heartbeat BEFORE the gdocs error propagation (workflow-design.md rule 2)
write_heartbeat "alert-sync"

# Tier 1+3: propagate accumulated gdocs errors.
gdocs_exit_with_status "$(basename "$0" .sh)"
