#!/bin/bash
# GPU Test Queue Runner
# Persistent test queue that runs on a GPU server under nohup.
# Survives session disconnects. Auto-starts next test when one finishes.
#
# Usage from ds1:
#   1. Write a queue file:
#      echo "cs_omni|fbcode//path:target|3600" > /tmp/gpu-test-queue.txt
#      echo "feed_u2i|fbcode//path:target|3600" >> /tmp/gpu-test-queue.txt
#
#   2. SCP this script + queue to GPU server:
#      scp scripts/gpu-test-queue.sh /tmp/gpu-test-queue.txt gpu-server:/tmp/
#
#   3. Start it:
#      ssh gpu-server 'cd /data/repos/fbsource && nohup bash /tmp/gpu-test-queue.sh \
#        --queue /tmp/gpu-test-queue.txt \
#        --results-dir /tmp/gpu-test-results \
#        --checkout <commit-hash> \
#        > /tmp/gpu-test-queue-runner.log 2>&1 &'
#
#   4. Check status:
#      ssh gpu-server 'cat /tmp/gpu-test-results/STATUS'
#
#   5. Check all results:
#      ssh gpu-server 'cat /tmp/gpu-test-results/SUMMARY'
#
# Queue file format (one test per line):
#   test_name|buck2_target|timeout_seconds
#   # Lines starting with # are skipped
#
# Example queue file:
#   cs_omni|fbcode//minimal_viable_ai/models/ig_retrieval/gpu_tests:ss_cs_omni_online_training_delta_publish_e2e_test|3600
#   feed_u2i|fbcode//minimal_viable_ai/models/ig_retrieval/gpu_tests:ss_feed_u2i_online_training_delta_publish_e2e_test|3600
#   mtml|fbcode//minimal_viable_ai/models/ig_ranking/gpu_tests:ig_reels_tab_mtml_online_training_delta_publish_e2e_test|3600

set -uo pipefail
# Note: no -e — test failures (non-zero exit) must not abort the queue

# --- Parse arguments ---
QUEUE_FILE=""
RESULTS_DIR="/tmp/gpu-test-results"
CHECKOUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --queue) QUEUE_FILE="$2"; shift 2 ;;
        --results-dir) RESULTS_DIR="$2"; shift 2 ;;
        --checkout) CHECKOUT="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

if [ -z "$QUEUE_FILE" ]; then
    echo "Usage: bash gpu-test-queue.sh --queue <queue-file> [--results-dir <dir>] [--checkout <hash>]"
    exit 1
fi

if [ ! -f "$QUEUE_FILE" ]; then
    echo "Queue file not found: $QUEUE_FILE"
    exit 1
fi

# --- Setup ---
mkdir -p "$RESULTS_DIR"
cd /data/repos/fbsource

STATUS_FILE="$RESULTS_DIR/STATUS"
SUMMARY_FILE="$RESULTS_DIR/SUMMARY"
HOSTNAME=$(hostname -s)

echo "QUEUE_RUNNER=started" > "$STATUS_FILE"
echo "HOSTNAME=$HOSTNAME" >> "$STATUS_FILE"
echo "STARTED=$(date '+%Y-%m-%d %H:%M:%S')" >> "$STATUS_FILE"
echo "QUEUE_FILE=$QUEUE_FILE" >> "$STATUS_FILE"
echo "PID=$$" >> "$STATUS_FILE"

echo "=== GPU Test Queue Results ===" > "$SUMMARY_FILE"
echo "Host: $HOSTNAME" >> "$SUMMARY_FILE"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# --- Checkout if specified ---
if [ -n "$CHECKOUT" ]; then
    echo "Checking out: $CHECKOUT" >> "$SUMMARY_FILE"
    sl goto "$CHECKOUT" >> "$SUMMARY_FILE" 2>&1
    echo "At: $(sl log -r . -T '{node|short} {phabdiff} {desc|firstline}')" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
fi

# --- Count total tests ---
TOTAL_EXPECTED=0
while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    TOTAL_EXPECTED=$((TOTAL_EXPECTED + 1))
done < "$QUEUE_FILE"
echo "Tests queued: $TOTAL_EXPECTED" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# --- Run tests ---
PASSED=0
FAILED=0
TEST_NUM=0

while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    TEST_NUM=$((TEST_NUM + 1))

    TEST_NAME=$(echo "$line" | cut -d'|' -f1)
    BUCK2_TARGET=$(echo "$line" | cut -d'|' -f2)
    TIMEOUT_SECS=$(echo "$line" | cut -d'|' -f3)

    LOG_FILE="$RESULTS_DIR/${TEST_NAME}.log"
    START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    START_EPOCH=$(date +%s)

    # Update status
    echo "CURRENT_TEST=$TEST_NAME" > "$STATUS_FILE"
    echo "TEST_NUM=$TEST_NUM/$TOTAL_EXPECTED" >> "$STATUS_FILE"
    echo "BUCK2_TARGET=$BUCK2_TARGET" >> "$STATUS_FILE"
    echo "TIMEOUT=$TIMEOUT_SECS" >> "$STATUS_FILE"
    echo "STARTED=$START_TIME" >> "$STATUS_FILE"
    echo "PASSED=$PASSED" >> "$STATUS_FILE"
    echo "FAILED=$FAILED" >> "$STATUS_FILE"

    echo "[$TEST_NUM] $TEST_NAME starting at $START_TIME (timeout=${TIMEOUT_SECS}s)" >> "$SUMMARY_FILE"

    # Run the test
    PYTHONUNBUFFERED=1 timeout "$TIMEOUT_SECS" buck2 run "$BUCK2_TARGET" > "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    echo "EXIT_CODE=$EXIT_CODE" >> "$LOG_FILE"

    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    END_EPOCH=$(date +%s)
    DURATION=$(( END_EPOCH - START_EPOCH ))
    DURATION_MIN=$(( DURATION / 60 ))

    if [ "$EXIT_CODE" -eq 0 ]; then
        RESULT="PASS"
        PASSED=$((PASSED + 1))
    elif [ "$EXIT_CODE" -eq 124 ]; then
        RESULT="TIMEOUT"
        FAILED=$((FAILED + 1))
    else
        RESULT="FAIL (exit=$EXIT_CODE)"
        FAILED=$((FAILED + 1))
    fi

    echo "    -> $RESULT in ${DURATION_MIN}m (${DURATION}s) at $END_TIME" >> "$SUMMARY_FILE"

done < "$QUEUE_FILE"

# --- Final status ---
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo "" >> "$SUMMARY_FILE"
echo "=== DONE ===" >> "$SUMMARY_FILE"
echo "Finished: $END_TIME" >> "$SUMMARY_FILE"
echo "Total: $TOTAL_EXPECTED | Passed: $PASSED | Failed: $FAILED" >> "$SUMMARY_FILE"

echo "QUEUE_RUNNER=done" > "$STATUS_FILE"
echo "FINISHED=$END_TIME" >> "$STATUS_FILE"
echo "TOTAL=$TOTAL_EXPECTED" >> "$STATUS_FILE"
echo "PASSED=$PASSED" >> "$STATUS_FILE"
echo "FAILED=$FAILED" >> "$STATUS_FILE"
