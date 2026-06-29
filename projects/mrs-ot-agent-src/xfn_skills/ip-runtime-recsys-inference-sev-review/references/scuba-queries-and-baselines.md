# Scuba Queries & Metrics Baselines

Load this reference when investigating specific metrics, building Scuba queries, or assessing metric severity.

## Table of Contents

- [Snapshot Transition Status](#snapshot-transition-status)
- [Error Rates by Hardware Type](#error-rates-by-hardware-type)
- [Binary Version on Tasks](#binary-version-on-tasks)
- [ZCH Cache Hit Rate](#zch-cache-hit-rate)
- [Metrics Baselines & Severity Assessment](#metrics-baselines--severity-assessment)

## Snapshot Transition Status

- **Dataset**: `runtime_freshness`
- **Columns**: `model_id`, `snapshot_id`, `transition_type`, `transition_duration_ms`, `status`
- **Filters**: `model_id = {MODEL_ID}`, `time >= NOW() - INTERVAL 7 DAY`

## Error Rates by Hardware Type

- **Dataset**: `service_router`
- **Columns**: `model_id`, `hardware_type`, `error_rate`, `p99_latency`
- **Filters**: `model_id = {MODEL_ID}`, `time >= NOW() - INTERVAL 24 HOUR`
- **Group by**: `hardware_type` (AMD vs NVIDIA)

## Binary Version on Tasks

- **Dataset**: `sigrid_predictor`
- **Columns**: `model_id`, `binary_version`, `task_id`, `region`
- **Filters**: `model_id = {MODEL_ID}`

## ZCH Cache Hit Rate

- **Dataset**: `sigrid_predictor`
- **ODS metric**: `sigrid_predictor.zch.cache_miss_rate`
- **Filters**: `model_id = {MODEL_ID}`

## Metrics Baselines & Severity Assessment

When a metric value appears in SEV comments, use this table to assess severity. All values are derived from actual SEV evidence. Source SEVs are cited. Update this table as new SEVs provide additional data points. Values marked "TBD" have no SEV-derived data yet -- report the raw number without severity judgment.

| Metric | Normal | Warning | Critical | Source |
|--------|--------|---------|----------|--------|
| Warmup latency (per operator) | ~100-200ms | TBD | >5s | S622516: good binary ~100ms; bad binary 8s |
| In-place transition time | ~1 hr | TBD | >5 hrs | S622516: normal was 1hr; stale at >5hrs |
| Out-of-place transition time | ~3 hrs | TBD | TBD | S622516: 3hr with in-place OFF |
| Error rate (steady state) | TBD | ~1% | >10% | S622516: ~1% flagged as concerning; 40% triggered S624473 |
| Model staleness (age) | TBD | TBD | >5 hrs | S622516: SEV filed when stale >5hrs |
| Demand multiplier | 1.0 | 1.15 | >1.3 | S622516: escalation 1.0->1.15->1.2->1.3 |
| P99 latency | ~75ms | TBD | TBD | S622516: "pre-SEV 75ms" (one model, may not generalize) |
| Warmup regression ratio | 1x | TBD | >50x | S622516: 80x regression confirmed SEV-causing |
| ZCH cache miss rate | <1% | >5% | >10% | S619839/S617600: 25.8% peak caused Feed metric regressions (20% like/lvv60, 5% vpv, 15% vvs) |
| Throughput (KFS estimate) | 1.0x | >1.15x overestimate | >1.3x overestimate | S619839/S616620: 35% KFS overestimation caused overload and inference errors |
