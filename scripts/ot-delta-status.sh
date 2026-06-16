#!/bin/bash
# ot-delta-status.sh — Check last sparse delta, dense delta, and full snapshot for an OT model
#
# Usage:
#   ot-delta-status.sh <model_type>
#   ot-delta-status.sh <mast_job_name>
#
# Examples:
#   ot-delta-status.sh ig_reels_tab_esr_ttsn
#   ot-delta-status.sh mvai-training-online-876773473
#
# Data source: gmpp Scuba table
# Publish modes: SPARSE_ONLY_DELTA, ITEM_EMB_DELTA, PublishMode.FULL_SNAPSHOT

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: ot-delta-status.sh <model_type_or_mast_job_name>"
    exit 1
fi

INPUT="$1"

# If input looks like a MAST job name (contains "training-online-"), resolve model_type via MCP
if [[ "$INPUT" == *"training-online-"* ]]; then
    echo "Note: Pass model_type directly for fastest results."
    echo "MAST job name resolution not supported in this script."
    echo "Use: mcp__plugin_Meta-ML_mlmate__ai_infra_mast_job_load to get model_type first."
    exit 1
fi

MODEL_TYPE="$INPUT"

echo "=== OT Delta Status: $MODEL_TYPE ==="
echo ""

# Single query: last event time, snapshot ID, and event count per publish mode
QUERY="SELECT
  publish_mode,
  MAX(time) as last_time,
  MAX(model_snapshot_id) as last_snapshot_id,
  COUNT(*) as total_events
FROM gmpp
WHERE model_type = '$MODEL_TYPE'
  AND (
    (publish_mode = 'SPARSE_ONLY_DELTA' AND event_type = 'TensorStreamingSessionEnd')
    OR (publish_mode = 'ITEM_EMB_DELTA' AND event_type = 'TensorStreamingSessionEnd')
    OR (publish_mode = 'PublishMode.FULL_SNAPSHOT' AND event_type = 'OperatorRun_Success')
  )
GROUP BY publish_mode
ORDER BY last_time DESC;"

RESULT=$(scuba -e "$QUERY" 2>/dev/null)

if echo "$RESULT" | grep -q "0 row"; then
    echo "No delta publish events found for model_type: $MODEL_TYPE"
    echo ""
    echo "Possible issues:"
    echo "  - Model type name is incorrect"
    echo "  - Model is not publishing deltas"
    echo "  - Job hasn't started publishing yet"
    exit 1
fi

echo "$RESULT"
echo ""

# Convert timestamps to human-readable and compute age
echo "--- Age Summary ---"
NOW=$(date +%s)
while IFS='|' read -r _ mode last_time _ _; do
    mode=$(echo "$mode" | tr -d ' ')
    last_time=$(echo "$last_time" | tr -d ' ')
    [[ -z "$last_time" || "$last_time" == "last_time" ]] && continue
    [[ "$mode" == "publish_mode" ]] && continue

    age_sec=$((NOW - last_time))
    age_min=$((age_sec / 60))
    last_human=$(date -d "@$last_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$last_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")

    if [[ $age_min -lt 60 ]]; then
        age_display="${age_min}m ago"
    elif [[ $age_min -lt 1440 ]]; then
        age_display="$((age_min / 60))h $((age_min % 60))m ago"
    else
        age_display="$((age_min / 1440))d $((age_min % 1440 / 60))h ago"
    fi

    # Flag stale deltas
    flag=""
    if [[ "$mode" == "SPARSE_ONLY_DELTA" && $age_min -gt 30 ]]; then
        flag=" !! STALE (>30min)"
    elif [[ "$mode" == "ITEM_EMB_DELTA" && $age_min -gt 60 ]]; then
        flag=" !! STALE (>1h)"
    elif [[ "$mode" == "PublishMode.FULL_SNAPSHOT" && $age_min -gt 1440 ]]; then
        flag=" !! STALE (>24h)"
    fi

    printf "  %-30s %s (%s)%s\n" "$mode" "$last_human" "$age_display" "$flag"
done <<< "$(echo "$RESULT" | tail -n +4 | head -5)"

# Check for recent failures
echo ""
echo "--- Recent Failures (last 24h) ---"
FAIL_QUERY="SELECT
  publish_mode,
  event_type,
  COUNT(*) as fail_count
FROM gmpp
WHERE model_type = '$MODEL_TYPE'
  AND (event_type LIKE '%Failure%' OR event_type LIKE '%Error%')
GROUP BY publish_mode, event_type
ORDER BY fail_count DESC
LIMIT 10;"

FAIL_RESULT=$(scuba -e "$FAIL_QUERY" 2>/dev/null)
if echo "$FAIL_RESULT" | grep -q "0 row"; then
    echo "  None"
else
    echo "$FAIL_RESULT"
fi
