# Known Failure Patterns

Load this reference when performing root cause analysis, pattern matching against past SEVs, or generating hypotheses for active investigations.

## Table of Contents

- [Pattern 1: Binary Regression -> Warmup Slowdown -> Snapshot Staleness](#pattern-1)
- [Pattern 2: Code Change -> Dormant Branch Activation -> Silent Data Corruption](#pattern-2)
- [Pattern 3: GPU Capacity Shortage -> Error Rate Spike -> Misdiagnosed as Root Cause](#pattern-3)
- [Pattern 4: AMD-Specific GPU Issues -> Deadlocks, Crashes, HSA Exceptions](#pattern-4)

## Pattern 1: Binary Regression -> Warmup Slowdown -> Snapshot Staleness

- **Example**: S622516 (Threads Feed LSR)
- **Symptoms**: Model staleness alerts, in-place snapshot transition stuck, warmup taking 8s instead of 100ms
- **Root Cause**: ROCm debug agent (`librocm-debug-agent.so.2`) enabled in binary v1167 via prerun script caused 80x warmup regression on AMD GPUs
- **Detection**: Model age alerts, Scuba `runtime_freshness` showing transition time regression
- **Mitigation**: Binary revert (v1167 -> v1139), disable debug agent via JK (`ipnext/system_perf/amd:enable_rocm_debug_agent`)
- **Key Insight**: The debug agent's HSA interception caused CPU-side overhead during GPU operations. Only manifested in production TW containers, not reproducible locally. Vanguard tests confirmed root cause.

## Pattern 2: Code Change -> Dormant Branch Activation -> Silent Data Corruption

- **Example**: S619839 (6 downstream SEVs)
- **Symptoms**: ZCH cache misses, NE spikes, 100% inference errors, capacity overloads -- all different symptoms from one root cause
- **Root Cause**: D91150779 activated a 2-year-old dormant code branch (D47393522) that copied old predictors into new containers during in-place transitions. This caused serving and streaming to use different ZCH instances.
- **Detection**: Multiple independent teams filed SEVs with different symptoms over 2 weeks
- **Mitigation**: Forward fix D92545390 restoring conditional guard for non-AOTI models
- **Key Insight**: Silent corruption (stale weights, diverged ZCH instances) is harder to detect than crashes. Each downstream SEV looked like a different problem. The three failure modes were:
  1. Multi-forward models losing `remote_request_only` predictor
  2. ZCH models with diverged cache instances
  3. U2I/omni models outputting incorrect results

## Pattern 3: GPU Capacity Shortage -> Error Rate Spike -> Misdiagnosed as Root Cause

- **Symptoms**: High error rates during snapshot transition, capacity alerts
- **Root Cause**: Often a red herring -- capacity issues mask the real problem (binary regression, warmup failure)
- **Key Insight**: If error rates drop after capacity increase but snapshots still can't load, capacity is NOT the root cause

## Pattern 4: AMD-Specific GPU Issues -> Deadlocks, Crashes, HSA Exceptions

- **Symptoms**: `HSA_STATUS_ERROR_EXCEPTION`, GPU hangs, memory access faults on AMD partitions only
- **Root Cause**: Various -- bad request inputs, ROCm driver issues, stream prioritization problems
- **Detection**: Crash dumps, rocm-debug-agent output, bad request recording
