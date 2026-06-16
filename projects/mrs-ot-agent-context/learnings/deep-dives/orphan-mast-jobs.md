# Orphan MAST Jobs — Taxonomy & Detection

_Researched 2026-05-26. This is a living document — new orphan types surface as incidents that don't match existing patterns._

## What is an orphan MAST job?

A MAST training job that is running (consuming GPU resources) but shouldn't be — because the training process is dead, stuck, unauthorized, expired, or abandoned.

## Known types (8 as of 2026-05-26)

| # | Type | How it happens | Detection mechanism | Detection gap |
|---|---|---|---|---|
| 1 | **TMS/MAST desync** | fire launches MAST but TMS stays PAUSED (UNAUTHORIZED ACL, TTL expiry, recurring→online transition mismatch) | TMS Reconciler (5-min async cycle, prod job 2151523) | 5-min blind window; only covers TMS-registered models |
| 2 | **Elastic agent zombie** | Worker crashes (CUDA assert, NCCL deadlock), launcher stuck due to D-state subprocesses or cleanup hang | TW HealthCheck + TorchElastic Watchdog | HealthCheck not universally enabled (JK-gated); D-state processes defeat both |
| 3 | **Sidecar keeps container alive** | Main process exits, but VipInjector/py-spy/DPP sidecar keeps TW container running | Zero SM Reaper (6hr threshold) | 6-hour delay; 3,511 GPU-hr waste observed in 3 weeks from py-spy alone |
| 4 | **In-trainer stuck** | Deadlocked NCCL collective, hung DPP pipeline, PT2 compilation stuck, checkpoint save timeout | StuckJobDetector (soft 10min / hard 30min) | Blind when trainer process is dead; not 100% fleet coverage |
| 5 | **MAST/TW allocation zombie** | MAST thinks job finished but TW allocation still running (allocator crash-loop, scheduler desync) | MAST HPC Reconciler (orphaned TW task notifications) | Enforcement gated by gflag |
| 6 | **Zero utilization** | Any of above, or user-abandoned job | MAST Reaper + ML Guardian (kills after 6hr zero SM util) | 6-hour threshold; allowlist management |
| 7 | **Forgotten adhoc** | User launches adhoc job, never productionizes or kills | TMS TTL (7-day expiry + 3-day warning) | Only `fire`-launched MVAI jobs; MAST-direct launches bypass |
| 8 | **Checkpoint eval orphan** | Eval job active in MAST but checkpoint eval DB record INACTIVE | GarbageCollector (chronos job, 5-min grace period) | Specific to checkpoint eval pipeline |

## The structural root cause

MAST does not distinguish "main training process alive" from "TW container alive." From S665454 SEV analysis: _"TMS relies on MAST status=RUNNING. MAST does not distinguish main-process-exit from container alive."_ Until MAST can independently track main-command PID liveness, types 2+3 have no real-time detection.

## Detection layers (defense in depth)

| Layer | Scope | Latency | Limitation |
|---|---|---|---|
| **StuckJobDetector** | In-process (trainer) | 10-30 min | Dead when trainer dies |
| **TorchElastic Watchdog** | In-process (launcher) | Minutes | D-state defeats it |
| **TW HealthCheck** | Container-level | Minutes | Not universally enabled |
| **TMS Reconciler** | TMS-registered models | 5 min | Only TMS state mismatches |
| **MAST HPC Reconciler** | MAST/TW allocation | Minutes | Gated by gflag |
| **Zero SM Reaper** | Fleet-wide | 6 hours | Long delay; last resort |
| **ML Guardian** | Fleet-wide ML analysis | Hours | Allowlist management |

## How to query for orphan jobs

```bash
# Check MAST job status
meta ai.mast-job describe --name=mvai-training-online-<MODEL_ID>

# Check TMS state vs MAST state
meta ai.managed-training job describe --model=<MODEL_ID>

# Check training progress (should see recent samples)
meta scuba.dataset query -d mvai_metrics \
  -g model_entity_id -a count --hours=1 \
  -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' \
  -r "Check if model is producing training metrics"

# Check GPU utilization
meta scuba.dataset query -d gpu_dyno_stats \
  -a avg -c sm_utilization --hours=6 \
  -w '[{"column":"job_name","op":"substr","values":["mvai-training-online-<MODEL_ID>"]}]' \
  -r "Check SM utilization for orphan detection"
```

## Key references

- TMS Reconciler: `fbcode/ai_infra/training_management_system/lib/tms_mast_reconciler.py`
- StuckJobDetector: `fbcode/aiplatform/stuck_job_detection/stuck_job_detector_core`
- D106193941: fix for type 1 (TMS UNAUTHORIZED desync)
- S665454: type 2 (elastic agent zombie, CUDA assert → 13hr orphan)
- S665478: type 2 (D-state subprocess, NCCL deadlock)
- D97165868: fix for type 3 (py-spy sidecar, 3,511 GPU-hr waste)
- CL-012 in `patterns/failure-patterns.md`: StuckJobDetector coverage gaps

## Open questions (this list is not exhaustive)

- Are there orphan types from FBLEARNER_FLOW-launched jobs? (Different launch path than `fire`)
- Can TMS reconciler miss models during state transitions (e.g., ONLINE_READY → PAUSED race)?
- What happens when MAST scheduler itself crashes mid-allocation?
- Are there orphan types specific to multi-tenant GPU sharing (MIG/MPS)?
- What about orphans from infra events (datacenter drains, network partitions)?
