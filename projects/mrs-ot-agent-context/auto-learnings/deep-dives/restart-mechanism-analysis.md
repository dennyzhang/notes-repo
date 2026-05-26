# OT Job Restart Mechanism — 4-Layer Stack

Distilled from deep analysis of S628346 (MB7 OT sporadic stuck) and D96502828 (exit code propagation fix).

## The 4 Layers

### Layer 1: SJD (Stuck Job Detector)
**Location:** `fbcode/aiplatform/stuck_job_detection/` | **Oncall:** ai_infra_kd

Daemon thread inside the trainer. Monitors training loop progress via `refresh_last_live_ts()` calls. Two-tier timeout:
- **Soft:** Warning → logs to Scuba (`mvai_stuck_job_detector`)
- **Hard:** SIGABRT to rank 0, SIGKILL to all other ranks

**Detects:** Training loop hangs, NCCL timeouts, GPU hangs, delta publish stalls that block training.
**Misses:** Publishing stalls that DON'T block training, slow/degraded training (liveness ok, not progress), bad data, inference-side staleness.

### Layer 2: terminate_thread_safe (Exit Code Propagation)
**Location:** `fbcode/mvai_infra/exceptions/exceptions.py` | **Oncall:** minimal_viable_ai

Catches all exceptions, extracts real exit codes from `ChildFailedError.get_first_failure()` and `MVAIRetryableException.system_exit_code`, calls `os._exit()`.

**Misses:** SIGKILL bypasses Python cleanup. Atexit handler hangs (timeout_sec=900). Exit codes from non-Python sidecar processes.

### Layer 3: MAST Retry Policy
**Oncall:** mast_core

| Category | Exit Code | Behavior |
|---|---|---|
| System failure | OOM, preemption, infra | Free retry — doesn't count against `maxJobFailures` |
| Application failure | Exit code 1, unknown | Counts against limit, retried |
| Non-retryable | Exit code 100 | Job goes DEAD immediately |

MAST reads exit codes from the **reply file** (AI Envelope TerminationHandler), not directly from process exit. Missing reply file → falls back to container exit code.

### Layer 4: TMS Reconciliation
**Oncall:** mast_core / training_management

Maintains desired state (job should run) vs actual state (job is dead). Periodically reconciles. Handles jobs MAST stopped retrying, external kills, rolling updates.

**Misses:** Jobs RUNNING but not PROGRESSING. Stale desired state. Cross-model dependencies.

## Coverage Matrix

| Failure Scenario | SJD | Exit Code | MAST | TMS | Covered? |
|---|---|---|---|---|---|
| Training loop hang (NCCL, GPU) | YES | YES | Restart | Reconcile | **YES** |
| OOM kill | No (instant) | No (SIGKILL) | YES (cgroup) | Reconcile | **YES** |
| Preemption | No (TW) | No (signal) | YES | Reconcile | **YES** |
| Delta publish blocks training | YES | YES | Restart | Reconcile | **YES** |
| Delta publish fails, training continues | **NO** | N/A | N/A | N/A | **NO** |
| Slow/degraded training | **NO** | N/A | N/A | N/A | **NO** |
| Silent non-progress (runs, zero snapshots) | **NO** | N/A | N/A | N/A | **NO** |

## 6 Remaining Gaps

1. **Publish-phase stuckness invisible to SJD** — training loop healthy but publishing silently stuck. No snapshots reach inference. Fix: publish-progress monitor tracking `last_successful_publish_ts`.
2. **Silent non-progress** — job running, no errors, no useful output (empty batches, degenerate model). Fix: quality signal monitoring (loss trend, gradient norm).
3. **Restart latency not tracked against SLO** — SJD kill → MAST restart → checkpoint load → first publish can take 30-90 min. No metric tracks "failure to first useful output."
4. **Ambiguous exit code 1** — partially fixed by D96502828. Generic Python exceptions still collapse to 1.
5. **No cross-model dependency awareness** — upstream model fails → downstream runs on stale data silently. Seen in S613570 (OmniUV multicast).
6. **Reply file race condition** — crash between writing reply and flushing → MAST reads stale/missing file.
