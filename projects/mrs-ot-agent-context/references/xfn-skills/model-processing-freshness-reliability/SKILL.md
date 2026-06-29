---
name: freshness-reliability
description: "Query publish success rates for Ads models on APS + IEN. Checks full snapshot, sparse delta, and dense delta reliability via Scuba, with failure breakdown diagnostics."
tools:
  - Read
  - Bash
  - Skill
  - scuba
---

# Freshness Reliability Queries

Query publish success rates and failure breakdowns for Ads models using **APS + IEN**.

## Input

- **Model ID** (required) -- used to filter Scuba queries.
- **Days** (optional, default 7) -- time window for queries.

## Prerequisites

```bash
feature install mast_cli
```

The `scuba` CLI must be available.

## Key Conventions

- **Online training MAST job name**: `aps-training-online-{model_id}`
- Always filter `node_name = '0'` to avoid double-counting from multi-rank distributed training.

---

## Reliability Check

Query success rates for each publish type using the `inference_enablement` Scuba table.

### Full Snapshot + Dense Delta (use `Orchestrator` event)

```bash
scuba -e "
SELECT snapshot_type, event_status, COUNT(*) as cnt
FROM inference_enablement
WHERE model_entity_id = {model_id}
  AND snapshot_type IN ('FullSnapshot', 'DenseDelta')
  AND event_type = 'Orchestrator'
  AND node_name = '0'
  AND time >= $(( $(date +%s) - {days}*86400 ))
GROUP BY snapshot_type, event_status
" --format csv
```

### Sparse Delta (use `DeltaPublishSparseWeightProcessingE2E`)

There is no Orchestrator event for sparse delta, so use the E2E event instead:

```bash
scuba -e "
SELECT event_status, COUNT(*) as cnt
FROM inference_enablement
WHERE model_entity_id = {model_id}
  AND snapshot_type = 'SparseDelta'
  AND event_type = 'DeltaPublishSparseWeightProcessingE2E'
  AND node_name = '0'
  AND time >= $(( $(date +%s) - {days}*86400 ))
GROUP BY event_status
" --format csv
```

### Thresholds

Success rate = Success count / Start count * 100%

| Status | Criteria |
|--------|----------|
| Pass | success rate >= 90% |
| Warning | 80-89.99% |
| Fail | < 80% |

---

## Failure Breakdown (diagnostic)

When failures are detected, query error details:

```bash
scuba -e "
SELECT snapshot_type, event_type, error_type, COUNT(*) as failure_count
FROM inference_enablement
WHERE model_entity_id = {model_id}
  AND event_status = 'Failure'
  AND time >= $(( $(date +%s) - {days}*86400 ))
GROUP BY snapshot_type, event_type, error_type
ORDER BY failure_count DESC
LIMIT 20
" --format csv
```

To get specific error messages for a snapshot type:

```bash
scuba -e "
SELECT error_message, error_type, COUNT(*) as cnt
FROM inference_enablement
WHERE model_entity_id = {model_id}
  AND event_status = 'Failure'
  AND snapshot_type = '{FullSnapshot|DenseDelta|SparseDelta}'
  AND node_name = '0'
  AND time >= $(( $(date +%s) - {days}*86400 ))
GROUP BY error_message, error_type
ORDER BY cnt DESC
LIMIT 5
" --format csv
```

---

## Recent Activity (context)

Show last 20 publish events for general context:

```bash
scuba -e "
SELECT time, snapshot_type, event_type, event_status, duration_ms, root_workflow_run_id
FROM inference_enablement
WHERE model_entity_id = {model_id}
  AND time >= $(( $(date +%s) - {days}*86400 ))
ORDER BY time DESC
LIMIT 20
" --format csv
```

---

## Output Format

Present findings in this table:

| Check | Metric | Value | Status | Notes |
|-------|--------|-------|--------|-------|
| Reliability | Full snapshot success rate | X% | Pass/Warning/Fail | >=99% pass |
| Reliability | Sparse delta success rate | X% | Pass/Warning/Fail | >=99% pass |
| Reliability | Dense delta success rate | X% | Pass/Warning/Fail | >=99% pass |

If failures exist, also show the failure breakdown table grouped by snapshot type.

---

## Escalation

For further questions or issues not covered here, reach out to **model_processing oncall**.
