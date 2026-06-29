# Debugging Decision Tree & Mitigation Ladder

Load this reference when actively debugging an in-progress SEV with unknown root cause, or when suggesting next investigation steps.

## Table of Contents

- [Branch A: Model Staleness / Snapshot Won't Load](#branch-a-model-staleness--snapshot-wont-load)
- [Branch B: High Error Rate During/After Snapshot Transition](#branch-b-high-error-rate-duringafter-snapshot-transition)
- [Branch C: Silent Quality Degradation](#branch-c-silent-quality-degradation)
- [Branch D: Capacity / Overload Errors](#branch-d-capacity--overload-errors)
- [Quick Mitigation Ladder](#quick-mitigation-ladder)

## Branch A: Model Staleness / Snapshot Won't Load

1. Is it AMD-only or all hardware?
   - **AMD-only** -> Check binary version, ROCm debug agent, warmup latency in logs
   - **All hardware** -> Check blob distribution, model publishing, snapshot validator
2. Does disabling in-place transition fix it?
   - **Yes** -> Root cause is in the in-place transition path (warmup, delta update, merge net)
   - **No** -> Check capacity, TW crashes, network issues
3. Is warmup taking abnormally long? (Check Logarithm for warmup timing)
   - **Yes** -> Binary regression likely. Compare warmup time between current and previous binary. Action: Revert binary first, bisect later.
   - **No** -> Check for convergence errors, tensor shape mismatches, or OOM

## Branch B: High Error Rate During/After Snapshot Transition

1. Do errors recover after a few minutes?
   - **Yes** -> Likely cold-start errors from skipped warmup or resource contention during transition
   - **No** -> Check if the new snapshot itself is bad (try loading it fresh on a canary)
2. Are errors AMD-specific?
   - **Yes** -> Check for HSA exceptions, GPU hangs, debug agent overhead
   - **No** -> Check for model incompatibility, feature mismatch, bad request patterns
3. Did a binary change recently?
   - **Yes** -> Pin previous binary and test. This is the fastest mitigation.
   - **No** -> Check for config changes (demand multiplier, gflags, solver settings)

## Branch C: Silent Quality Degradation (NE Spike, Cache Misses)

1. Did an in-place transition happen recently?
   - **Yes** -> Check if serving and streaming paths use the same model instance (the S619839 pattern -- two ZCH instances diverging)
   - **No** -> Check model freshness, feature pipeline, upstream data issues
2. Are ZCH free slots decreasing normally?
   - **No (stuck at max)** -> Serving path is using a stale predictor. Binary regression likely.
   - **Yes** -> Issue is elsewhere (eviction policy, streaming failures)

## Branch D: Capacity / Overload Errors

1. Did throughput estimates change recently?
   - **Yes** -> Check if KFS is overestimating throughput due to bad model output (S616620 pattern)
   - **No** -> Genuine capacity issue -- scale up
2. Does scaling up fix the error rate AND snapshot loading?
   - **Error rate only** -> Capacity was masking another issue. Continue investigating.
   - **Both** -> Genuine capacity shortage was the root cause.

## Quick Mitigation Ladder

Try in order:

1. **Disable in-place transition** -> Restores snapshot loading (trades freshness for stability)
2. **Revert binary** -> If a recent binary change is suspected
3. **Increase capacity multiplier** -> Buys time if overloaded
4. **Disable warmup** -> If warmup is blocking transition (temporary, causes cold-start errors)
5. **Disable streaming** -> If streaming is causing divergence or bad updates
