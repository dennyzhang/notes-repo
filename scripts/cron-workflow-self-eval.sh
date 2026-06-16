#!/usr/bin/env bash
# cron-workflow-self-eval.sh — Self-score a workflow run against its Eval tab goals.
#
# Source this file, then call: workflow_self_eval <doc_id> <eval_tab_id> <main_output_file> <workflow_name>
#
# Flow:
#   1. Claude reads Eval tab + main output → scores goals → writes updated HTML
#   2. Shell deletes eval tab content + inserts updated HTML (preserves tab ID)

# Source cron-alert.sh for run_claude_with_timeout helper
SCRIPT_DIR_SELF_EVAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! type run_claude_with_timeout &>/dev/null; then
    source "$SCRIPT_DIR_SELF_EVAL/cron-alert.sh"
fi
source "$SCRIPT_DIR_SELF_EVAL/lib/llm-dispatch.sh"
# Auto-recover google-mux before any gdocs calls (runs regardless of source path)
ensure_gmux_healthy || echo "[WARN] google-mux unhealthy — gdocs calls may fail"

workflow_self_eval() {
    local doc_id="$1"
    local eval_tab_id="$2"
    local main_output="$3"
    local workflow_name="$4"
    local today_ts
    today_ts=$(date '+%Y-%m-%d %H:%M')
    local eval_html="/tmp/cron-workflow-eval-${workflow_name}.html"
    local eval_current="/tmp/cron-eval-current-${workflow_name}.html"

    echo "$LOG_PREFIX [self-eval] Scoring $workflow_name..."

    # Validate inputs
    if [ ! -f "$main_output" ] || [ ! -s "$main_output" ]; then
        echo "$LOG_PREFIX [self-eval] Main output missing or empty ($main_output), skipping"
        return 1
    fi

    # Step 1: Read current eval tab (body only)
    gdocs get "$doc_id" --tab-id "$eval_tab_id" < /dev/null 2>/dev/null \
        | sed -n '/<body>/,/<\/body>/p' > "$eval_current"

    if [ ! -s "$eval_current" ]; then
        echo "$LOG_PREFIX [self-eval] Could not read eval tab, skipping"
        return 1
    fi

    # Step 1b: Truncate main output to reduce memory — scorer only needs
    # tables, headings, and summary text, not full HTML styling/photoLinks.
    local main_output_trimmed="/tmp/cron-eval-trimmed-${workflow_name}.html"
    python3 -c "
import re, sys
with open('$main_output') as f:
    html = f.read()
# Strip inline styles, photoLinks, and long data URIs
html = re.sub(r' style=\"[^\"]{100,}\"', '', html)
html = re.sub(r'photoLink\":\"[^\"]+\"', 'photoLink\":\"...\"', html)
html = re.sub(r'data:[^\"]{200,}', 'data:...', html)
# Truncate to 30KB max (enough for scoring, prevents OOM)
if len(html) > 30000:
    html = html[:30000] + '\n<!-- truncated for scoring -->'
with open('$main_output_trimmed', 'w') as f:
    f.write(html)
" 2>/dev/null || cp "$main_output" "$main_output_trimmed"

    # Step 2: Claude scores and produces updated HTML + per-dimension JSON
    local eval_dims_json="/tmp/cron-eval-dimensions-${workflow_name}.json"
    local eval_exit=0
    run_llm "workflow-self-eval" 600 /dev/stdout "You are scoring a workflow run. Today is $today_ts.

## INPUTS
1. Current eval tab: $eval_current
2. Main output: $main_output_trimmed

## TASK
Read both files. For each Goal (G1-G6) in the Goals table:
1. Read the Metric and Target columns
2. Examine the main output file for evidence
3. Score each goal on a 0-100 scale (0=completely missing, 50=partial, 100=fully met)
4. Determine Status: MET (score>=75), GAP (score<75), or REGRESSED (was MET, now GAP)

Scoring rules — be strict:
- G with 'all' or '100%' target: any single violation = GAP (score 0-50 based on severity)
- G with percentage target: score = estimated percentage achieved
- If you cannot verify a goal from the output, score 0 (GAP)
- If a goal was previously MET and is now GAP, status = REGRESSED (use red)

Then produce TWO outputs:

### Output 1: Per-dimension scores JSON
Write to $eval_dims_json a JSON object:
{
  \"date\": \"$today_ts\",
  \"workflow\": \"$workflow_name\",
  \"total_score\": <average of all dimension scores, 0-100>,
  \"dimensions\": {
    \"G1\": {\"name\": \"<goal name>\", \"score\": <0-100>, \"target\": 75, \"status\": \"MET|GAP|REGRESSED\", \"detail\": \"<what was found or missing>\"},
    \"G2\": { ... },
    ...
  }
}

### Output 2: Updated eval tab HTML
Write to $eval_html the COMPLETE updated eval tab HTML body.

Changes to make vs the input:
1. Update Goals table: Current and Status columns with new values. Add a Score column (0-100) if not present.
   Status colors: <span style=\"color: #006600\">MET</span> or <span style=\"color: #CC0000\">GAP</span> or <span style=\"color: #CC0000\">REGRESSED</span>
2. In Run Log table: if placeholder row exists (No runs recorded), replace it with a data row. Otherwise add a new row AFTER the header.
   Columns: $today_ts | <total_score>/100 | comma-list of MET goal IDs | comma-list of GAP goal IDs | one-line note
   Keep max 10 data rows (remove oldest if needed).
3. Do NOT change Goals section header/description, Deltas table, or Manual Eval Inbox.

## OUTPUT
Write the JSON to $eval_dims_json first, then the HTML to $eval_html.
The HTML file must start with <h1> and end with the last paragraph.
Do NOT include <html>, <head>, <body> wrapper tags.

## RULES
- Read files with the Read tool only.
- Write the output file with the Write tool.
- Do NOT run any gdocs/bash commands.
- Do NOT modify any external system." -- \
        --allowedTools Read,Write \
        --model claude-sonnet-4-6 \
        --max-turns 25 \
        --bare \
        || eval_exit=$?

    if [ $eval_exit -ne 0 ] || [ ! -s "$eval_html" ]; then
        echo "$LOG_PREFIX [self-eval] Scoring failed (exit $eval_exit)"
        rm -f "$eval_current"
        return 1
    fi

    # Step 3: Push updated content to eval tab (delete all + insert)
    # Get tab content range
    local end_idx
    end_idx=$(gdocs content get-structure "$doc_id" --tab-id "$eval_tab_id" 2>/dev/null \
        | grep '^\[' | tail -1 | grep -oP '\d+' | tail -1 || echo "")

    if [ -z "$end_idx" ] || [ "$end_idx" -lt 2 ]; then
        echo "$LOG_PREFIX [self-eval] Could not get eval tab structure"
        rm -f "$eval_current"
        return 1
    fi

    # Delete all content in the eval tab
    local delete_end=$((end_idx - 1))
    if [ "$delete_end" -gt 1 ]; then
        if ! echo "[{\"deleteContentRange\":{\"range\":{\"startIndex\":1,\"endIndex\":$delete_end,\"tabId\":\"$eval_tab_id\"}}}]" \
            | gdocs batch-update "$doc_id" --data - 2>/dev/null; then
            echo "$LOG_PREFIX [self-eval] Failed to delete eval tab content"
            rm -f "$eval_current"
            return 1
        fi
    fi

    # Insert updated HTML
    if gdocs content insert-text "$doc_id" @"$eval_html" --html --tab-id "$eval_tab_id" --index 1 2>/dev/null; then
        echo "$LOG_PREFIX [self-eval] Eval tab updated successfully"
    else
        echo "$LOG_PREFIX [self-eval] Failed to insert eval content"
        rm -f "$eval_current"
        return 1
    fi

    # Copy per-dimension scores to persistent state if available
    local state_dir="$HOME/work/claude/context/cache/state"
    if [ -f "$eval_dims_json" ]; then
        cp "$eval_dims_json" "$state_dir/SELF-EVAL-DIMENSIONS-${workflow_name}.json" 2>/dev/null || true
        echo "$LOG_PREFIX [self-eval] Per-dimension scores saved"
    fi

    # Cleanup
    rm -f "$eval_current" "$main_output_trimmed" "$eval_dims_json"
    return 0
}
