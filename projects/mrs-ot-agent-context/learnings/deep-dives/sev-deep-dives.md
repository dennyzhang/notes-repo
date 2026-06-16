# SEV Deep Dives — Failure Chain Analysis

Completed deep dives with full failure chains and mental models for triage.
Source: `mrs-ml-training-reliability` project (T259394647).

---

## S613570 — IGR OmniUV CPEntity/Delos AUTH Failure → Multicast Deadlock (Jan 2026, SEV3)

**Failure chain:**
```
Blob Distribution rolls out "reliable END message" feature
  → Trainers must write END metadata to CPEntity via Delos cluster
    → Fetching auth token from AAS fails intermittently
      → CPEntity write fails
        → Bug: soft-fail exception NOT absorbed, propagates to trainer
          → rank0 fails at commit_version()
            → rank0 exits before reaching all_gather_object()
              → all other ranks hang forever at collective ops
                → DISTRIBUTED DEADLOCK → delta publishing halted
                  → sparse streaming fails for OmniUV prod model 2144816226
                    → multicast subscribers (2141707735, 2144816217) also fail
```

**Detection:** Automated alert on inference streaming update delay. ~6h detection lag.

**Fixes:**
- D92103897: Soft-fail exception handling bug (`.value()` called on error result)
- D92171972: Distributed deadlock fix (rank0 try/except + broadcast exception to all ranks)
- D91967569: Multicast UMM registration restricted to rank0 (`invoke_on_rank_and_broadcast_result`)

**Mental models for future triage:**

1. **Multicast amplifies single-rank failures** — rank0 failure during rank0-only operation → all other ranks waiting at next collective op deadlock. More multicast subscribers = higher blast radius.

2. **Soft-fail is only as good as its test coverage** — soft-fail mechanism existed but had a bug. Without a unit test exercising the exception path, soft-fail is theater.

3. **OT publishing depends on a deep dependency chain** — Trainer → GMPP → Blob Distribution Writer → CPEntity → Delos → AAS auth tokens. Any link can fail; failure mode depends on which layer handles it.

4. **rank0 is a single point of failure in distributed publishing** — UMM registration, commit_version, multicast registration all run on rank0 only. Fix pattern: try on rank0 → broadcast result/exception → all ranks act together.

5. **Feature rollouts from dependency teams create blind spots** — "reliable END message" was a Blob Distribution feature, not OT. OT oncall had no visibility into the rollout. Cross-team feature rollouts on OT hot path need coordination.

---

## S628346 — MB7 OT Sporadic Stuck — Exit Code Collapse (Mar 2026, recurred Apr 2026)

**Failure chain:**
```
SJD detects stuck training workers
  → sends SIGABRT to rank 0 (exit code 6), SIGKILL to other ranks
    → torchelastic catches as ChildFailedError
      → ChildFailedError.failures[rank].exitcode = 6
        → terminate_thread_safe catches ChildFailedError
          → exit_w_cleanup(1) — hardcoded, ignores real exit code
            → MAST sees exit code 1, cannot make correct restart decision
```

**Fix:** D96502828 — propagate real exit codes from `ChildFailedError.get_first_failure()` and `MVAIRetryableException.system_exit_code` instead of collapsing to 1.

**Apr 2026 recurrence:** D93634569 (light_cli:4971) delta-publish timeout masks stuck state → QPS→0 with no SJD trigger. SJD masked because upstream cause (full snapshot blocking) prevents the training loop from appearing stuck.

**Mental models:**

1. **Exit code propagation chain**: Worker exit N → torchelastic `ChildFailedError` → `terminate_thread_safe` → `os._exit()` → MAST. Every link must preserve the exit code.

2. **`ChildFailedError.get_first_failure()`** returns `(rank, ProcessFailure)` tuple sorted by smallest timestamp — the first failure is the root cause.

3. **SJD can be masked** — if the upstream cause (delta-publish timeout, full snapshot) blocks training indirectly, SJD may not fire because `refresh_last_live_ts()` is still called in the outer loop.

---

## S627484 — video_udd_lsr Delta Publish Failure (Feb 2026)

**Root cause:** No delta publish E2E test → publish failure undetected until prod.

**Pipeline insight:** OT has 4 stages: T1 Scribe → T2 Training → T3 Publishing → T4 Streaming. `DeltaOnlyPublisher` separates full snapshot from delta publishing; `TGIFPublisher` does both. `allow_concurrent_delta_during_full_publish` flag prevents sparse deltas from being blocked during full snapshot.

**Diffs:** D96206983 (E2E test), D96214620 (conveyor), D96212230 (logging), D96222753 (blocking warning), D96229466 (guardrails.md)

**Gap surfaced:** T259376083 — DeltaOnlyPublisher vs TGIF+concurrent for 10-min sparse delta SLO.

---

## Deep Dive Template

For each new SEV:
1. **Root cause** — trace the full failure chain
2. **Detection** — how found? What monitoring existed/was missing?
3. **Mitigation** — what stopped the bleeding?
4. **Gaps:** Small → create diff; Big → write project idea
5. **Knowledge** — new patterns, failure modes, mental models
