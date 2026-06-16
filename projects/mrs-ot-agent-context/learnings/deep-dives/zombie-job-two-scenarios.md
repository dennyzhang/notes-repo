# OT Zombie Job — Two Failure Scenarios

Learned 2026-05-23 during triage of reranker model 2125081901 (S667567).
Two distinct failure paths produce the same zombie outcome: MAST RUNNING,
training dead, no auto-restart.

## Scenario A: Elastic agent fails to shutdown

```
Rank crashes (SIGSEGV, CUDA assert, NCCL timeout, etc.)
→ elastic agent catches ChildFailedError
→ cleanup runs (error file, fuse-overlayfs, host info)
→ Python shutdown hangs on non-daemon threads
  (ServiceRouter fibers, folly EventBase, fb303 callbacks)
→ elastic agent process still alive but silent (no more logs)
→ TW sees process alive → container alive → MAST RUNNING
→ zombie
```

Root cause: error path uses normal Python shutdown, which calls
threading._shutdown() and waits for all non-daemon threads to join.
The success path already has os._exit() (added for S388433) but
the error path did not.

Fix: D105606893 (Paul Lu, Unpublished as of 2026-05-23)
  Wraps elastic agent entrypoint with terminate_thread_safe
  → guarantees os._exit() on BOTH success and error paths.
  Only 13 lines. Would have prevented today's 8+ hour zombie.

Prior SEVs: S665478 (10.5h zombie), S628346, S665454

## Scenario B: Elastic agent exits, TW doesn't tear down

```
Rank crashes → elastic agent exits cleanly via os._exit()
→ main command PID gone
→ sidecars (VipInjector) still running in container
→ TW sees container has live processes → keeps container alive
→ MAST sees container alive → reports RUNNING
→ zombie
```

Status: UNCONFIRMED. We haven't observed this in the wild yet because
Scenario A catches all current zombies before the elastic agent exits.
After D105606893 lands, if zombies still happen, Scenario B is confirmed
and the fix is in TW/MAST (not elastic agent).

Fix (if confirmed):
  Option 1: TW "primary process" concept — kill container when
    main command exits, regardless of sidecars
  Option 2: MAST tracks main command PID separately from container
  Option 3: External liveness probe (mvai_metrics staleness → force kill)

## Trigger T-OOM: GPU memory leak from publish path → CUDA OOM → rank death

Learned 2026-06-03 (S670887, IFR MainMTML prod 2125752019). Scenarios A/B
describe what the elastic agent does *after* a rank dies; this is a specific,
**recurring and preventable** trigger that kills the rank in the first place —
distinct from a one-off SIGSEGV/CUDA-assert.

```
Full-snapshot publish reads embeddings GPU→host to build snapshot
→ GPU allocations from the publish path are NOT freed (empty_cache before
  publish did NOT help — S670887)
→ GPU memory steps UP at each full-snapshot publish, accumulates over hours
→ one rank reaches ~99.88% mem util → CUDA OOM → that rank gets SIGTERM
→ surviving ranks block on the in-flight NCCL collective → QPS=0
→ zombie (then Scenario A or B for the elastic-agent shutdown)
```

Evidence shape (S670887, v35): GPU first >99.5% at 07:43:53, last >99% at
07:48:53, SIGTERM on the OOM'd trainer at 07:49, QPS=0 07:49→09:49, human
kill at 09:49. Two episodes in <24h → recurrence, not a fluke.

Distinguishing trigger T-OOM from a generic crash: probe #2 (GPU mem util,
gpu_dyno_stats) shows a slow climb to ~100% correlated with full-snapshot
publish events — a clean crash shows no such ramp. Confirm via probe set
below.

**Why SJD didn't auto-kill it (refines "no automated system catches this"):**
the lease-renewal thread keeps renewing `mvai_monitor` independently of the
stuck *training* thread — so the stuck-job detector sees a fresh lease and
never fires. Heartbeat ≠ training progress. The only progress-aware signal is
mvai_metrics staleness (probe #1).

## Fact-gathering probe set

Before classifying any zombie, run the OBSERVE probe set in
`cheatsheets/oncall/mast-debugging.md` § "Fact-Gathering Signature Catalog"
(probes #1 trainer-liveness, #2 GPU-mem/OOM, #3 SIGTERM, #6 NCCL-hang,
#7 publish-path accumulation, #8 SJD-blindness). S670887 was first mis-triaged
because GPU memory (#2) was never probed — the OOM signal was never fetched.

## How to distinguish A vs B on a live zombie

    ssh <host>
    ps aux | grep <elastic_agent_pid>

    PID alive → Scenario A (elastic agent hung in Python shutdown)
    PID gone  → Scenario B (TW keeping container alive for sidecars)

## Current detection: dual-signal liveness check

    Signal 1: mvai_metrics Scuba last sample timestamp
    Signal 2: TensorBoard qps/global/lifetime last timestamp
    Signal 3: tw log stderr — only sidecar output (VipInjector)

    Both signals stale >30 min + MAST RUNNING = zombie confirmed.
    Manual kill required — no automated system catches this.

## Paul's diff stack (all Unpublished as of 2026-05-23)

    D105606893  terminate_thread_safe on elastic agent error path (Scenario A fix)
    D106022978  Harden process_wrapper shutdown against subprocess crash
    D106022977  Check publish failure threshold before subprocess shutdown
    D104310163  Fix ShutdownHandler to flush events before old signal handler

## Related

- SEV S670887 — GPU-OOM zombie (IFR MainMTML prod 2125752019), trigger T-OOM; publish-path GPU leak; 2 episodes <24h
- SEV S667567 — 2026-05-23 incident (reranker 2125081901 zombie)
- SEV S665478 — 10.5h zombie, motivated D105606893
- SEV S628346 — light.py threading._shutdown() deadlock
- SEV S665454 — CUDA CachingAllocator SIGABRT zombie
- Known patterns P44 (trainer hang), CL-012 (SJD coverage gap)
- Pastes: P2349062759 (alert triage), P2349068641 (architecture), P2349071994 (manual kill)
