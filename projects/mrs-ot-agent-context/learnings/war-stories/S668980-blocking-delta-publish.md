# War Story #4 — Blocking Delta Publish Stalls Training QPS (S668980)

**SEV:** S668980 — [IGR][ESR][Mb7] 2nd round QE models combo7 abnormal training QPS during delta publish
**Level:** L3 | **Owner:** Qi Yang (qiyang0310)
**Duration:** May 28, 2026 → ongoing
**GChat:** spaces/AAQAX8BWfqc
**Impact:** Abnormal (low) training QPS during delta publish cycles across 6 newly launched 2nd-round ESR Mb7 QE models on GB200 NVL72 hardware. combo7-2-3 job failed after 60h from XDB connection exhaustion.

---

## The problem in one sentence

When FULL_SNAPSHOT Phase 2 (async CPU publish via Hedwig/Manifold) is still running when the next delta timer fires, `may_wait_for_ongoing_task_done()` blocks the training thread until Phase 2 completes — causing 20+ minute QPS drops per cycle.

## Why this is a new pattern

This is NOT P01 (FS blocking deltas — FS prevents delta creation) and NOT P02 (publish deadlock — publish never completes). Here, deltas DO publish and the wait DOES eventually complete. The problem is a **blocking wait in the delta timer's call path** that stalls training. No NCCL timeout fires (P19), no deadlock (P02) — just silent QPS degradation during each publish cycle.

## Multi-factor root cause

### 1. Primary — Blocking delta publish (new pattern candidate)
- `may_wait_for_ongoing_task_done()` in the delta-publish timer path blocks the training thread when Phase 2 of a prior publish is still running
- For models with slow FS publishes (30+ min Phase 2), training blocks for 20+ min per cycle
- **Fix:** D107207628 by llu6 (non-blocking skip) — replaces blocking wait with `try_cleanup_if_ongoing_task_done()`, which checks if the previous task is done without blocking

### 2. Contributing — DPP cold-start starvation (P16/F-class)
- Opsmate confirmed 91-94% DPP starvation at trainer-consumption layer for all 6 QE models
- Baseline model (warm pipeline, MAST v2) at 0%
- DPP backend healthy — cold-start warmup issue, self-resolving

### 3. Contributing — XDB connection exhaustion
- combo7-2-3 attempt 0 FAILED after 60h38m: `max_user_connections` exceeded on `dai_model_platform_prod`
- Error path: `metrics_progress → verify_metrics → _read_commit_time_from_cp → UMM get_model_instance_metadata → XDB`
- 6 concurrent QE model launches overwhelmed the MySQL shard

## Key artifacts

| Artifact | Link |
|----------|------|
| SEV | https://www.internalfb.com/sevmanager/view/668980 |
| MAST combo7 | https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-2121422712 |
| MAST combo7-2-3 | https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-2121426259 |
| Fix diff | https://www.internalfb.com/diff/D107207628 |
| Opsmate investigation | OM811806 / OM811808 |

## Observations at triage time (2026-06-02)

- Both jobs RUNNING, SPARSE_DELTA publishing hourly (VALID)
- **36h+ FULL_SNAPSHOT gap** on both models (last FS: 2026-05-30)
- Several historical FULL_SNAPSHOT instances stuck in CREATING state
- No DENSE_DELTA since job v9 launched (2026-05-29)

## Core lesson

**Blocking waits in publish paths silently degrade training QPS without triggering any existing monitors.** No NCCL timeout, no SJD kill, no MAST FAILED transition — just periodic QPS dips that look like noise until you correlate them with the publish timer. Existing patterns (P01, P02, P19) all assume a harder failure. This gap let the issue persist across 6 QE models undetected until manual inspection.

## Durable fix

D107207628 replaces the blocking wait with a non-blocking check — if the prior publish is still running, the current delta cycle is skipped with a warning log. Training never blocks. Time-based log escalation (WARNING below 30 min, ERROR above) provides visibility without stalling the training loop.
