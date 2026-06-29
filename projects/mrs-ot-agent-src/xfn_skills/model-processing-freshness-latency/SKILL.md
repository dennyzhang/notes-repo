---
name: freshness-latency
description: "Query publish latency metrics for Ads models on APS + IEN. Measures P50/P99 latency for full snapshot, sparse delta, and dense delta via Scuba."
tools:
  - Read
  - Bash
  - Skill
  - scuba
---

# Freshness Latency Queries

Analyze P50/P99 publish latency for Ads models using **APS + IEN**.

## Input

- **Model ID** (required) -- used to filter Scuba queries.
- **Days** (optional, default 7) -- time window for queries.

## Prerequisites

The `scuba` CLI must be available.

## Key Conventions

- Always filter `node_name = '0'` to avoid multi-rank duplicates.

---

## Full Snapshot Latency

Query via the `Orchestrator` event (has `event_status`):

```bash
scuba -e "
SELECT
  APPROX_PERCENTILE(duration_ms, 0.5) as p50_ms,
  APPROX_PERCENTILE(duration_ms, 0.99) as p99_ms,
  COUNT(*) as sample_size
FROM inference_enablement
WHERE model_entity_id = {model_id}
  AND snapshot_type = 'FullSnapshot'
  AND event_type = 'Orchestrator'
  AND node_name = '0'
  AND event_status = 'Success'
  AND duration_ms IS NOT NULL
  AND time >= $(( $(date +%s) - {days}*86400 ))
" --format csv
```

## Sparse & Dense Delta E2E Latency

Query via `DeltaPublishE2E` event (null `event_status` -- do not filter on it):

```bash
scuba -e "
SELECT
  snapshot_type,
  APPROX_PERCENTILE(duration_ms, 0.5) as p50_ms,
  APPROX_PERCENTILE(duration_ms, 0.99) as p99_ms,
  COUNT(*) as sample_size
FROM inference_enablement
WHERE model_entity_id = {model_id}
  AND snapshot_type IN ('SparseDelta', 'DenseDelta')
  AND event_type = 'DeltaPublishE2E'
  AND node_name = '0'
  AND duration_ms IS NOT NULL
  AND time >= $(( $(date +%s) - {days}*86400 ))
GROUP BY snapshot_type
" --format csv
```

---

## SV (Snapshot Validation) Latency

Measures time from publish completion to snapshot validation completion.
Data source: `validation_controller_ledger` Scuba table (validation end time) joined with `inference_enablement` (publish time).
Reference notebook: [N9466764](https://www.internalfb.com/intern/anp/view/?id=9466764)

### Step 1: Get publish times (from inference_enablement)

Full snapshot publish times:
```bash
START_TIME=$(( $(date +%s) - {days}*86400 )) && END_TIME=$(date +%s)
scuba -e "
SELECT
    model_snapshot_id AS id,
    MAX(time) AS published_time
FROM inference_enablement
WHERE time >= ${START_TIME} AND time <= ${END_TIME}
    AND model_entity_id = {model_id}
    AND event_type = 'Orchestrator'
    AND snapshot_type = 'FullSnapshot'
    AND node_name = '0'
    AND event_status = 'Success'
GROUP BY id
" --format csv
```

Delta publish times:
```bash
scuba -e "
SELECT
    model_snapshot_id AS id,
    snapshot_type,
    MAX(time) AS published_time
FROM inference_enablement
WHERE time >= ${START_TIME} AND time <= ${END_TIME}
    AND model_entity_id = {model_id}
    AND event_type = 'DeltaPublishE2E'
    AND snapshot_type IN ('SparseDelta', 'DenseDelta')
    AND node_name = '0'
GROUP BY id, snapshot_type
" --format csv
```

### Step 2: Get validation end times (from validation_controller_ledger)

Snapshot validation:
```bash
scuba -e "
SELECT
    snapshot_id AS id,
    MIN(time) AS validation_ended_time
FROM validation_controller_ledger
WHERE time >= ${START_TIME} AND time <= ${END_TIME}
    AND NOT (run_mode = 'OFF')
    AND origin_service = 'SNAPSHOT_VALIDATOR'
    AND model_id = {model_id}
    AND snapshot_id > 0
GROUP BY snapshot_id
" --format csv
```

Delta validation:
```bash
scuba -e "
SELECT
    delta_id AS id,
    MIN(time) AS validation_ended_time
FROM validation_controller_ledger
WHERE time >= ${START_TIME} AND time <= ${END_TIME}
    AND NOT (run_mode = 'OFF')
    AND origin_service = 'SNAPSHOT_VALIDATOR'
    AND model_id = {model_id}
    AND delta_id > 0
GROUP BY delta_id
" --format csv
```

### Step 3: Compute SV latency

**SV latency = validation_ended_time − published_time** (per snapshot/delta ID, join on `id`).

Compute P50/P99 of the per-ID latencies in seconds, then convert to minutes.

**Important**: Use `model_id` (numeric, no quotes) for `validation_controller_ledger`, and `model_entity_id` for `inference_enablement`.

---

## Serving Latency (Time to First Prediction)

Measures time from validation completion to first prediction served, and time from publish completion to first prediction served (E2E).
Data source: `adfinder_predictor` Scuba table (first served time).
Reference notebook: [N9466764](https://www.internalfb.com/intern/anp/view/?id=9466764)

### Step 1: Get first served times (from adfinder_predictor)

Use a wider time window (±1 day) since first-served may lag behind publish/validation:

```bash
WIDE_START=$(( $(date +%s) - ({days}+1)*86400 )) && WIDE_END=$(( $(date +%s) + 86400 ))
```

Snapshot first served:
```bash
scuba -e "
SELECT
    predictor_model_snapshot AS id,
    MIN(time) AS first_served_time
FROM adfinder_predictor
WHERE ${WIDE_START} <= time AND time <= ${WIDE_END}
    AND predictor_model_entityId = {model_id}
    AND predictor_model_snapshot > 0
GROUP BY id
" --format csv
```

Dense delta first served:
```bash
scuba -e "
SELECT
    dense_delta_id AS id,
    MIN(time) AS first_served_time
FROM adfinder_predictor
WHERE ${WIDE_START} <= time AND time <= ${WIDE_END}
    AND predictor_model_entityId = {model_id}
    AND dense_delta_id > 0
GROUP BY id
" --format csv
```

Sparse delta first served:
```bash
scuba -e "
SELECT
    sparse_delta_id AS id,
    MIN(time) AS first_served_time
FROM adfinder_predictor
WHERE ${WIDE_START} <= time AND time <= ${WIDE_END}
    AND predictor_model_entityId = {model_id}
    AND sparse_delta_id > 0
GROUP BY id
" --format csv
```

### Step 2: Compute serving latencies

Two metrics per publish type:

1. **Validated → First Served** = `first_served_time − validation_ended_time` (join on ID with validation data from SV Latency step)
2. **Published → First Served (E2E)** = `first_served_time − published_time` (join on ID with publish data)

Compute P50/P99 of per-ID latencies in seconds, convert to minutes.

---

## Thresholds

| Status | Criteria |
|--------|----------|
| Normal | P99 < 2x P50 |
| Warning | P99 >= 2x P50 (high variance) |

No hard latency thresholds -- targets vary by model size. The P99/P50 ratio flags high variance.

---

## Output Format

Present findings in these tables:

### Model Processing Latency

| Check | Metric | Value | Status | Notes |
|-------|--------|-------|--------|-------|
| Latency | Full snapshot P50/P99 | Xmin / Xmin | Normal/Warning | P99/P50 ratio |
| Latency | Sparse delta P50/P99 | Xmin / Xmin | Normal/Warning | P99/P50 ratio |
| Latency | Dense delta P50/P99 | Xmin / Xmin | Normal/Warning | P99/P50 ratio |

### SV Latency

| Check | Metric | Value | Status | Notes |
|-------|--------|-------|--------|-------|
| SV Latency | Full snapshot P50/P99 | Xmin / Xmin | Normal/Warning | published → validated |
| SV Latency | Dense delta P50/P99 | Xmin / Xmin | Normal/Warning | published → validated |
| SV Latency | Sparse delta P50/P99 | Xmin / Xmin | Normal/Warning | published → validated |

### Serving Latency

| Check | Metric | Value | Status | Notes |
|-------|--------|-------|--------|-------|
| Serving | Full snapshot validated→served P50/P99 | Xmin / Xmin | Normal/Warning | validated → first served |
| Serving | Dense delta validated→served P50/P99 | Xmin / Xmin | Normal/Warning | validated → first served |
| Serving | Sparse delta validated→served P50/P99 | Xmin / Xmin | Normal/Warning | validated → first served |
| Serving (E2E) | Full snapshot published→served P50/P99 | Xmin / Xmin | -- | published → first served |
| Serving (E2E) | Dense delta published→served P50/P99 | Xmin / Xmin | -- | published → first served |
| Serving (E2E) | Sparse delta published→served P50/P99 | Xmin / Xmin | -- | published → first served |

---

## Escalation

For further questions or issues not covered here, reach out to **model_processing oncall**.
