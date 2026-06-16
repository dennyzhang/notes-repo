#!/usr/bin/env bash
# ai-health-gdoc-template.sh — Bash glue for AI Playbook gdoc table widths.
#
# CANONICAL SOURCE: workflows/templates/AI-PLAYBOOK-TEMPLATE.html
#   The template HTML is the human-readable spec for the AI Playbook gdoc:
#   table count, column count/names, widths, and style constants. Mirrored
#   in config/GDOC-TABLE-WIDTHS.json under doc_key "ai_playbook" for tools
#   that read JSON. Edit the template first, then mirror values here + JSON.
#   FOLLOWUPS tracks "make this file read widths from the template at runtime".
#
# Used by cron-ai-health.sh `apply_compact_widths` after every doc replace.
#
# Tables applied to tab t.0 (in order — see apply_compact_widths comment block):
#   1. Action Required (3 cols): Status=78pt | Signal=100pt | Value=290pt
#   2. AI Impact (5 cols):       #=25pt | Metric=125pt | 7d=40pt | All Time=110pt | Evidence=200pt
#   3. Health Signals (3 cols):  Status=78pt | Signal=100pt | Value=290pt
#   4. Cron Fleet (7 cols):      Job=100pt | Status=55pt | LastRun=65pt | PassRate=55pt | Runs=40pt | Detail=105pt | Duration=48pt
#
# Other widths defined below (changelog3, fix5, fleet5 legacy) are kept for
# backwards compat with archived call sites; not applied by current cron.
#
# Google Doc ID: externalized to config/DAILY-DOCS.json (docs.ai_playbook)
# Tab ID: t.0

# Resolve doc ID from config (load helper if this file is run standalone).
command -v get_doc_id >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/cron-alert.sh"
GDOC_ID="$(get_doc_id ai_playbook)"
GDOC_TAB="t.0"

# Table style constants
HEADER_BG="#C9DAF8"          # Light blue header rows
HEADER_RGB='{"red":0.788,"green":0.855,"blue":0.973}'
GREEN_BG="#c6efce"
YELLOW_BG="#ffeb9c"
RED_BG="#ffc7ce"
FONT_SIZE="12px"             # Compact — matches ai-health-push.py inline style
CELL_PADDING="4px 8px"       # Compact — not 6px 10px

# Column width definitions (in PT, total ~468pt = letter width minus margins)
# 3-column Status/Signal/Value tables (Status first for quick scanning)
COL3_STATUS=78
COL3_SIGNAL=100
COL3_VALUE=290

# 5-column Cron Fleet table (legacy): Job | Status | Runs | Last Run (Detail) | Pass Rate (Duration)
COL5_JOB=90
COL5_STATUS=60
COL5_RUNS=40
COL5_LASTRUN_DETAIL=160
COL5_PASSRATE_DUR=118

# 7-column Cron Fleet table (current, as of 2026-04-18):
# Job | Status | Last Run | Pass Rate | Runs | Detail | Duration — sums to 468pt
COL7_JOB=100
COL7_STATUS=55
COL7_LASTRUN=65
COL7_PASSRATE=55
COL7_RUNS=40
COL7_DETAIL=105
COL7_DURATION=48

# 5-column Fix Effectiveness table
COL5F_CATEGORY=80
COL5F_ATTEMPTS=72
COL5F_SUCCESSES=72
COL5F_RATE=54
COL5F_ACTION=190

# 5-column AI Impact table: # | Metric | 7d | All Time | Evidence
COL_IMPACT_NUM=25
COL_IMPACT_METRIC=125
COL_IMPACT_7D=40
COL_IMPACT_ALLTIME=110
COL_IMPACT_EVIDENCE=200

# Generate batch-update JSON for compact column widths
# Usage: generate_width_json TABLE_START_INDEX TABLE_TYPE
# TABLE_TYPE: "signal3" (3-col), "fleet5" (5-col cron fleet), "fix5" (5-col fix)
generate_width_json() {
    local idx="$1" type="$2"
    case "$type" in
        signal3)
            cat <<EOF
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL3_STATUS},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL3_SIGNAL},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL3_VALUE},"unit":"PT"}},"fields":"widthType,width"}}
EOF
            ;;
        fleet5)
            cat <<EOF
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5_JOB},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5_STATUS},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5_RATE},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[3],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5_RUNS},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[4],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5_DURATION},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[5],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5_DETAIL},"unit":"PT"}},"fields":"widthType,width"}}
EOF
            ;;
        fix5)
            cat <<EOF
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5F_CATEGORY},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5F_ATTEMPTS},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5F_SUCCESSES},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[3],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5F_RATE},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[4],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL5F_ACTION},"unit":"PT"}},"fields":"widthType,width"}}
EOF
            ;;
        fleet7|cronfleet5)
            # Cron Fleet table (7 cols, current): Job | Status | Last Run | Pass Rate | Runs | Detail | Duration.
            # Note: legacy name "cronfleet5" retained for backwards compat with
            # older apply_compact_widths callers, but body emits 7 column updates.
            # If a table with only 5 cols receives these, Google Docs ignores
            # out-of-range columnIndices (safe no-op).
            cat <<EOF
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL7_JOB},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL7_STATUS},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL7_LASTRUN},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[3],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL7_PASSRATE},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[4],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL7_RUNS},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[5],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL7_DETAIL},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[6],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL7_DURATION},"unit":"PT"}},"fields":"widthType,width"}}
EOF
            ;;
        impact5)
            # AI Impact: # | Metric | 7d | All Time | Evidence
            cat <<EOF
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL_IMPACT_NUM},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL_IMPACT_METRIC},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL_IMPACT_7D},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[3],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL_IMPACT_ALLTIME},"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[4],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":${COL_IMPACT_EVIDENCE},"unit":"PT"}},"fields":"widthType,width"}}
EOF
            ;;
        changelog3)
            cat <<EOF
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":72,"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":100,"unit":"PT"}},"fields":"widthType,width"}},
{"updateTableColumnProperties":{"tableStartLocation":{"index":${idx}},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":296,"unit":"PT"}},"fields":"widthType,width"}}
EOF
            ;;
    esac
}

# Apply compact widths to all dashboard tables after a gdocs replace
# Usage: apply_compact_widths DOC_ID
#
# WHY "Runs column not compact" keeps recurring:
# Three independent causes have been found and fixed:
# 1. Missing --tab-id t.0 on get-structure (fixed 2026-04-12): without it, tables
#    from ALL 5 tabs are returned, making positional mapping wrong — the Cron Fleet
#    table (t5 in tab t.0) gets mapped to a table in another tab.
# 2. data-col-widths HTML attribute (banned): if present in inserted HTML, Google Docs
#    overrides batch-update column widths with the attribute's values. Prevented by
#    post-generation grep assertion in cron-ai-health.sh.
# 3. width:100% on <table> tag (removed from generate-ai-health-html.sh): causes the
#    table to stretch to full page width, negating compact column widths.
apply_compact_widths() {
    local doc_id="$1"
    local tables
    tables=$(gdocs content get-structure "$doc_id" --tab-id t.0 2>&1 | grep "TABLE:")

    # Skip if user has disabled auto-widths (they set widths manually and want them preserved)
    # Create the flag with: touch ~/work/claude/state/ai-health-widths-manual
    if [ -f "$HOME/work/claude/state/ai-health-widths-manual" ]; then
        echo "    [widths] Manual widths flag set — skipping template widths (user edits preserved)" >&2
        return 0
    fi

    local t1 t2 t3 t4
    t1=$(echo "$tables" | sed -n '1p' | grep -o '^\[[0-9]*' | tr -d '[')
    t2=$(echo "$tables" | sed -n '2p' | grep -o '^\[[0-9]*' | tr -d '[')
    t3=$(echo "$tables" | sed -n '3p' | grep -o '^\[[0-9]*' | tr -d '[')
    t4=$(echo "$tables" | sed -n '4p' | grep -o '^\[[0-9]*' | tr -d '[')

    # Table order in today's section (tab t.0): 1=Action Required (3-col),
    # 2=AI Impact (5-col), 3=Health Signals (3-col, consolidated from Ops + Fleet),
    # 4=Cron Fleet (5-col: cronfleet5)
    local json="["
    [ -n "$t1" ] && json+="$(generate_width_json "$t1" signal3),"
    [ -n "$t2" ] && json+="$(generate_width_json "$t2" impact5),"
    [ -n "$t3" ] && json+="$(generate_width_json "$t3" signal3),"
    [ -n "$t4" ] && json+="$(generate_width_json "$t4" cronfleet5)"
    json="${json%,}]"

    echo "$json" > /tmp/compact-tables.json
    gdocs batch-update "$doc_id" --data @/tmp/compact-tables.json -q 2>/dev/null
}
