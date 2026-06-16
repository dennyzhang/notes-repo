#!/bin/bash
# ot-fleet-health.sh — MRS OT fleet health scanner
# Identifies unhealthy OT models: dead jobs, package errors, stuck TMS retries
#
# Usage:
#   bash scripts/ot-fleet-health.sh [--customer CUSTOMER] [--days DAYS] [--json] [--check-mast]
#
# All data from Scuba by default (fast, ~5s). Use --check-mast to also verify
# MAST job status per model (slow, ~2s per model).
#
# Data source: Scuba training_platform_model_events

set -euo pipefail

CUSTOMER_FILTER="'INSTAGRAM','MRS','FEED'"
LOOKBACK_DAYS=7
OUTPUT_JSON=false
CHECK_MAST=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --customer) CUSTOMER_FILTER="'$2'"; shift 2 ;;
    --days) LOOKBACK_DAYS="$2"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    --check-mast) CHECK_MAST=true; shift ;;
    --help) echo "Usage: $0 [--customer CUSTOMER] [--days DAYS] [--json] [--check-mast]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

START_TS=$(date -d "-${LOOKBACK_DAYS} days" +%s)
PKG_ERROR_TS=$(date -d "-30 days" +%s)
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== MRS OT Fleet Health Report ===" >&2
echo "Date: $(date '+%Y-%m-%d %H:%M %Z')" >&2
echo "Lookback: ${LOOKBACK_DAYS} days | Customer filter: ${CUSTOMER_FILTER}" >&2
echo "" >&2

# Step 1: Get all active OT models from TMS events (models TMS tried to manage)
echo "[1/4] Querying active OT models from Scuba..." >&2
scuba -e "
SELECT model_entity_id, data_project, customer, ai_stack, COUNT(*) as tms_events
FROM training_platform_model_events
WHERE service_component IN ('TrainingLaunchService')
  AND training_environment IN ('PROD')
  AND event IN ('FinishLaunchTrainingSuccess', 'ReceiveStartTrainingRequest')
  AND customer IN (${CUSTOMER_FILTER})
  AND time >= ${START_TS}
GROUP BY model_entity_id, data_project, customer, ai_stack
ORDER BY tms_events DESC
LIMIT 500
" 2>/dev/null | grep -E '^\|' | grep -v 'model_entity_id' | while IFS='|' read -r _ mid dp cust stack events _; do
  mid=$(echo "$mid" | xargs)
  dp=$(echo "$dp" | xargs)
  cust=$(echo "$cust" | xargs)
  stack=$(echo "$stack" | xargs)
  events=$(echo "$events" | xargs)
  [[ -z "$mid" ]] && continue
  echo "${mid}|${dp}|${cust}|${stack}|${events}"
done > "$TMPDIR/active_models.txt"

ACTIVE_COUNT=$(wc -l < "$TMPDIR/active_models.txt")
echo "  Found ${ACTIVE_COUNT} active OT models" >&2

# Step 2: Get models with package errors (last 30 days)
echo "[2/4] Querying package errors (30d) from Scuba..." >&2
scuba -e "
SELECT model_entity_id, exception_type, COUNT(*) as error_count
FROM training_platform_model_events
WHERE service_component IN ('TrainingLaunchService')
  AND training_environment IN ('PROD')
  AND severity IN ('Error', 'Warning')
  AND exception_type LIKE '%PACKAGE%'
  AND customer IN (${CUSTOMER_FILTER})
  AND time >= ${PKG_ERROR_TS}
GROUP BY model_entity_id, exception_type
ORDER BY error_count DESC
LIMIT 200
" 2>/dev/null | grep -E '^\|' | grep -v 'model_entity_id' | while IFS='|' read -r _ mid etype ecount _; do
  mid=$(echo "$mid" | xargs)
  etype=$(echo "$etype" | xargs)
  ecount=$(echo "$ecount" | xargs)
  [[ -z "$mid" ]] && continue
  echo "${mid}|${etype}|${ecount}"
done > "$TMPDIR/pkg_errors.txt"

PKG_ERROR_COUNT=$(wc -l < "$TMPDIR/pkg_errors.txt")
echo "  Found ${PKG_ERROR_COUNT} models with package errors" >&2

# Step 3: Get models with ONLY errors (no recent successful launches) — indicates stuck/dead
echo "[3/4] Querying models with recent successful launches..." >&2
scuba -e "
SELECT model_entity_id, COUNT(*) as success_count
FROM training_platform_model_events
WHERE service_component IN ('TrainingLaunchService')
  AND training_environment IN ('PROD')
  AND event IN ('FinishLaunchTrainingSuccess')
  AND customer IN (${CUSTOMER_FILTER})
  AND time >= ${START_TS}
GROUP BY model_entity_id
ORDER BY success_count DESC
LIMIT 500
" 2>/dev/null | grep -E '^\|' | grep -v 'model_entity_id' | while IFS='|' read -r _ mid scount _; do
  mid=$(echo "$mid" | xargs)
  [[ -z "$mid" ]] && continue
  echo "$mid"
done > "$TMPDIR/successful_models.txt"

SUCCESS_COUNT=$(wc -l < "$TMPDIR/successful_models.txt")
echo "  Found ${SUCCESS_COUNT} models with successful launches" >&2

# Step 4: Optionally check MAST status for unhealthy models only
echo "[4/4] Building health report..." >&2

check_mast_status() {
  local mid=$1
  local stack=$2
  local prefix
  case "$stack" in
    MVAI) prefix="mvai-training-online" ;;
    APS)  prefix="aps-training-online" ;;
    *)    prefix="mvai-training-online" ;;
  esac
  local job_name="${prefix}-${mid}"
  local result
  result=$(meta ai.mast-job attempts --name="$job_name" -o json < /dev/null 2>/dev/null) || true
  if [[ -z "$result" || "$result" == "[]" ]]; then
    echo "NO_JOB"
    return
  fi
  local status
  status=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['status'] if d else 'UNKNOWN')" 2>/dev/null) || status="PARSE_ERROR"
  echo "$status"
}

# Build the report
{
  echo "model_entity_id|data_project|customer|ai_stack|tms_events|has_recent_success|pkg_error_type|pkg_error_count_30d|mast_status|health"

  while IFS='|' read -r mid dp cust stack events; do
    [[ -z "$mid" ]] && continue

    # Check if model had recent successful launches
    has_success="NO"
    grep -q "^${mid}$" "$TMPDIR/successful_models.txt" 2>/dev/null && has_success="YES"

    # Check package errors
    pkg_error_type=""
    pkg_error_count="0"
    if grep -q "^${mid}|" "$TMPDIR/pkg_errors.txt" 2>/dev/null; then
      pkg_line=$(grep "^${mid}|" "$TMPDIR/pkg_errors.txt" | head -1)
      pkg_error_type=$(echo "$pkg_line" | cut -d'|' -f2)
      pkg_error_count=$(echo "$pkg_line" | cut -d'|' -f3)
    fi

    # Optionally check MAST status (only for suspected-unhealthy models, or if --check-mast)
    mast_status="-"
    if [[ "$CHECK_MAST" == "true" ]]; then
      mast_status=$(check_mast_status "$mid" "$stack")
      echo -n "." >&2
    elif [[ "$has_success" == "NO" && "$pkg_error_count" -gt 0 ]]; then
      # Spot-check models that have errors but no successes
      mast_status=$(check_mast_status "$mid" "$stack")
      echo -n "!" >&2
    fi

    # Determine health
    health="HEALTHY"
    if [[ "$mast_status" == "DEAD" || "$mast_status" == "FAILED" ]]; then
      health="DEAD"
    elif [[ "$mast_status" == "NO_JOB" ]]; then
      health="NO_JOB"
    elif [[ "$has_success" == "NO" && "$pkg_error_count" -gt 100 ]]; then
      health="PKG_STUCK"
    elif [[ "$has_success" == "NO" && "$pkg_error_count" -gt 0 ]]; then
      health="PKG_FAILING"
    elif [[ "$has_success" == "NO" ]]; then
      health="NO_LAUNCHES"
    elif [[ "$pkg_error_count" -gt 100 ]]; then
      health="PKG_WARN"
    fi

    echo "${mid}|${dp}|${cust}|${stack}|${events}|${has_success}|${pkg_error_type}|${pkg_error_count}|${mast_status}|${health}"
  done < "$TMPDIR/active_models.txt"

  echo "" >&2
} > "$TMPDIR/report.txt"

# Output report
if [[ "$OUTPUT_JSON" == "true" ]]; then
  python3 -c "
import csv, json, sys
reader = csv.DictReader(open('$TMPDIR/report.txt'), delimiter='|')
rows = []
for r in reader:
    r['tms_events'] = int(r['tms_events'])
    r['pkg_error_count_30d'] = int(r['pkg_error_count_30d'])
    rows.append(r)
json.dump(rows, sys.stdout, indent=2)
print()
"
else
  # Unhealthy models first
  echo ""
  echo "=== UNHEALTHY MODELS ==="
  echo ""
  unhealthy_count=0
  while IFS='|' read -r mid dp cust stack events success pkg_type pkg_count mast health; do
    [[ "$health" == "HEALTHY" || "$health" == "health" ]] && continue
    [[ -z "$mid" ]] && continue
    unhealthy_count=$((unhealthy_count + 1))
    echo "  [$health] model=$mid  pkg_errors_30d=$pkg_count  mast=$mast"
    echo "           data_project=$dp  customer=$cust  stack=$stack"
    [[ -n "$pkg_type" ]] && echo "           error_type=$pkg_type"
    echo ""
  done < "$TMPDIR/report.txt"

  if [[ $unhealthy_count -eq 0 ]]; then
    echo "  (none — all models healthy)"
    echo ""
  fi

  # Summary
  total=$(( $(wc -l < "$TMPDIR/report.txt") - 1 ))
  healthy=$(grep -c '|HEALTHY$' "$TMPDIR/report.txt" || true)
  dead=$(grep -c '|DEAD$' "$TMPDIR/report.txt" || true)
  pkg_stuck=$(grep -c '|PKG_STUCK$' "$TMPDIR/report.txt" || true)
  pkg_failing=$(grep -c '|PKG_FAILING$' "$TMPDIR/report.txt" || true)
  pkg_warn=$(grep -c '|PKG_WARN$' "$TMPDIR/report.txt" || true)
  no_launches=$(grep -c '|NO_LAUNCHES$' "$TMPDIR/report.txt" || true)
  no_job=$(grep -c '|NO_JOB$' "$TMPDIR/report.txt" || true)

  echo "=== SUMMARY ==="
  echo "  Total models:     $total"
  echo "  Healthy:          $healthy"
  echo "  Dead (MAST):      $dead"
  echo "  Pkg stuck:        $pkg_stuck (>100 pkg errors, no successful launches)"
  echo "  Pkg failing:      $pkg_failing (<100 pkg errors, no successful launches)"
  echo "  Pkg warning:      $pkg_warn (pkg errors but still launching ok)"
  echo "  No launches:      $no_launches (TMS events but no successful launches)"
  echo "  No MAST job:      $no_job"
fi
