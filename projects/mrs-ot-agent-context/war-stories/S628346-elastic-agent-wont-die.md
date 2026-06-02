# War Story #2 — Elastic Agent Won't Die (S628346)

**SEV:** S628346 — MB7 models OT sporadic stuck (4 models)
**Level:** L3 | **Owner:** Dave Kotfis (dkotfis)
**Duration:** Feb 25 → May 12, 2026 (76 days open, 41 days to mitigation)
**GChat:** spaces/AAQAhVAJDko
**Impact:** 4 MB7 OT jobs hung sporadically, idling 6–28h per incident. No auto-restart. Manual kill required each time. Prequel to S665454 (same failure class, different trigger).

---

## The problem in one sentence

When MVAI training workers crash, `exit_w_cleanup()` only runs on the success path — on the failure path (`ChildFailedError`), non-daemon C++ threads (NCCL, DPP, publisher) keep the agent process alive indefinitely, MAST never detects the failure, and the job sits idle.

## Why this is a war story

This is the **prequel** to S665454 (War Story #1). Same failure class — "process won't exit, MAST thinks it's alive" — but a different mechanism. S628346 taught the team how the exit chain works (and doesn't) and produced the key fix (D98638473) that later proved insufficient for the CUDA SIGABRT variant in S665454. Understanding this SEV is prerequisite context for the zombie-jobs problem.

## The cast

- **Dave Kotfis (dkotfis)** — SEV owner, OT escalation owner. Confirmed the SIGABRT handler hang on rank 0.
- **Armand Sauzay (armandsauzay)** — Confirmed fix on natural failure. Carved follow-up tasks.
- **Paul Lu (lupaul)** — SIGKILL escalation in SJD (D97199931).

## The failure chain

```
TGIF publish failure (Manifold race condition)
  → Worker-level NCCL deadlock (ranks waiting on stalled publish)
  → SJD detects stuck → sends SIGKILL to workers
  → Workers die, but elastic agent process survives
  → WHY? exit_w_cleanup() only on success path in light.py
  → On ChildFailedError: Python's threading._shutdown() blocks
    on stuck C++ threads (NCCL, DPP, publisher)
  → Agent hangs → MAST reports RUNNING → no restart
```

### The second failure path (SIGABRT handler)

Even when the agent tried to die, a separate bug prevented it: torch elastic's watchdog timer resets the default SIGABRT handler, then calls SIGALRM. The SIGALRM invokes a registered SIGABRT handler (from `initFacebook`) that hangs. Rank 0 gets stuck in signal handler limbo.

## Investigation timeline

### Phase 1 — Detection gap (Feb 25 – Mar 2)

Jobs start sporadically hanging on Feb 25. Nobody notices for 4 days. Detected Mar 1 by employee observation. SEV filed Mar 2. The 4-day detection gap itself is a lesson: there was no alerting for "job running but not training."

### Phase 2 — Root cause hunt (Mar 2 – Apr 1, ~30 days)

The NCCL timeout in logs was a **red herring** — already in known_patterns.md's ruled-out list. NCCL timeout was a symptom of rank stall during publish, not the root cause. The real question: why doesn't the agent exit after workers are killed?

Root cause confirmed Apr 1: `exit_w_cleanup()` in light.py was only called on the success path. On `ChildFailedError`, the agent's Python interpreter tried `threading._shutdown()`, which blocks on stuck C++ threads that will never join.

### Phase 3 — Fix and validation (Apr 1–7)

**D98638473 (key fix):** Adds `exit_w_cleanup()` on the error path. Agent calls `os._exit(1)` on `ChildFailedError` regardless of thread state. Brute-force but correct — if workers died, the agent must die too.

**Validation (Apr 2):** Natural failure on job `mvai-training-online-2132645607` v17: SJD fires → `exit_w_cleanup` called → agent exits code 1 → recovery confirmed. Armand Sauzay: *"exit_w_cleanup is called and agent exits with code 1... recovery confirmed."*

**Supporting fixes:**
- D97199931 — SIGKILL escalation in SJD: after SIGABRT to rank 0, wait 30s then escalate to SIGKILL
- D96542699 — JK rule: switch watchdog to SIGALRM path (bypasses broken SIGABRT handler)
- D95294551 + D95541181 — Hardened Manifold publish path (fix the most common trigger)

## Code paths that matter

- **The gap:** `light.py` main → `mast_error_handling_entrypoint()` → `run()`. On `ChildFailedError`, the exception propagates but `exit_w_cleanup()` was not on this path.
- **The fix:** D98638473 adds `exit_w_cleanup(1)` to the `ChildFailedError` handler, ensuring `os._exit(1)` runs regardless.
- **The thread hang:** `threading._shutdown()` iterates all non-daemon threads and calls `.join()`. NCCL communicator threads, DPP reader threads, and TGIF publisher threads are C++-backed and never set daemon=True. If any are stuck, `.join()` blocks forever.

## Durable lessons

1. **`exit_w_cleanup()` must run on EVERY exit path.** The original code assumed the success path was the only path that needed cleanup. Wrong — the failure path is the one that needs it most, because that's when threads are stuck.

2. **NCCL timeout is almost always a symptom, not a root cause.** When you see NCCL timeout in OT job logs, look upstream: what caused the ranks to stall? In this case it was Manifold publish race conditions.

3. **Non-daemon C++ threads are the silent killer.** Python's `threading._shutdown()` will block on them indefinitely. Any C++ thread that can hang (NCCL, DPP, CUDA driver) must either be daemon-flagged or killed explicitly during shutdown.

4. **4-day detection gap → alerting was missing.** There was no "job running but not training" alert. Follow-up task T265777779 (OT stuck alerting) was carved but marked NO_PROGRESS at SEV close. The gap persisted into S665454.

5. **This fix was necessary but not sufficient.** D98638473 handles the Python-exception-path hang. S665454 showed that SIGABRT (which kills the process before any Python handler runs) needs a different mechanism entirely — a watchdog outside the process.

## Relationship to other war stories

- **S665454 (War Story #1):** Same class, different trigger. S628346 = Python threads won't join. S665454 = CUDA driver locks prevent process exit. The D98638473 fix from this SEV doesn't help when SIGABRT kills the process before Python handlers run.
- **S622829:** Same class again. py-spy subprocess ignores SIGTERM → trainer can't exit. Three SEVs, three mechanisms, one lesson: the exit chain is fragile.

## Status

**Closed.** Fix landed and validated. Follow-up tasks for alerting (T265777779) and SIGABRT→SIGKILL escalation (T260751351) carved but marked NO_PROGRESS at close.

## References

- SEV: https://www.internalfb.com/sevmanager/view/628346
- Key fix: D98638473 (`exit_w_cleanup` on error path)
- Supporting: D97199931 (SIGKILL escalation), D96542699 (JK watchdog), D95294551 + D95541181 (Manifold race)
- Follow-ups: T265777384, T260751351, T265777779
- Related SEVs: S665454 (zombie jobs), S622829 (py-spy hang)
