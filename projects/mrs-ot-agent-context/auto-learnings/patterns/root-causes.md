# Root Causes (R-NNN)

_Terminal explanation — the specific bug, config, or condition. "What's broken?" — distinguished from "how is it broken right now" (failure-modes.md) and "what we observe" (symptoms.md)._

Each entry: short name → specific signature → triggering diff/condition → fix-in-flight if any → evidence.

---

## 🗂️ Family map — 32 R-NNNs consolidated into 8 families

Use this to scan; drill into the detailed entries below by anchor.

| R-family | Brief | R-NNN entries | Top mechanism |
|---|---|---|---|
| **TRAINER_CRASH** | Worker process dies (NCCL/CUDA/Shampoo/Gloo) | R-001, R-003, R-004, R-005, R-010, R-018, R-024 | M-005 / M-001 |
| **LAUNCHER_CONTAINMENT** | Death event not propagated to MAST | R-002 | M-001 |
| **CAPACITY_EXCEEDED** | Static limit hit by organic growth | R-006, R-021, R-022 | M-015 / M-010 |
| **DATA_STARVATION** | DPP / Scribe / ZippyDB / corpus upstream | R-007, R-008, R-009, R-012, R-015, R-017, R-031 | M-002 / M-007 / M-013 |
| **PUBLISH_BROKEN** | FS path broken while trainer healthy | R-016, R-025\*, R-029 | M-012 / M-011 |
| **FLOW_DISCIPLINE** | Cogwheel/workflow regression (incl. reland) | R-013, R-014, R-019, R-020 | M-009 |
| **PERIODIC_STALL\*** | M-011 sub-hypotheses (unverified) | R-026\*, R-027\*, R-028\* | M-011 |
| **DETECTOR_BROKEN** | Detector misconfig / no-auto-clear / role-mismatch | R-032, R-033, R-034, R-035 | M-016 / M-017 |

`*` = unverified hypotheses pending evidence.

_Numbering gaps (R-011, R-023, R-030) are retired/withdrawn IDs. Reserved; do not reuse._

---

## R-001 — CUDA allocator state corruption (`CUDACachingAllocator.cpp:3316 free_block`)

**Signature:** `c10::Error: inserted INTERNAL ASSERT FAILED at "fbcode/caffe2/c10/cuda/CUDACachingAllocator.cpp":3316`; SIGABRT exitcode -6 on a worker rank; reproducible across multiple jobs in same family suggests not random hardware.

**Triggers M-001** (elastic agent zombie via subprocess D-state) and a different failure shape vs other allocator bugs (must check `free_block` specifically).

**Fix-in-flight:** None identified at C10 level. Mitigations D-001/D-002/D-003 address the Layer-2 consequence.

**Evidence:** S665454 (3 affected jobs simultaneously — m2124122280, m2124793203, m2124428748), Li Lu paste P2341568201

---

## R-002 — `exit_w_cleanup()` absent on `ChildFailedError` path in light.py

**Signature:** Worker dies (any reason); `torch.distributed.elastic.multiprocessing.errors.ChildFailedError` propagates; light.py launcher catches but doesn't call cleanup → agent hangs in shutdown.

**Triggers M-001** (one of the upstream code-path bugs producing zombie state).

**Fix-in-flight:** **T265777384** (armandsauzay) — NO_PROGRESS as of 2026-05-20 morning brief; partial scope (covers light.py path only, not PyTorch elastic agent upstream path).

**Evidence:** S628346 (974h impact in W21 mega-learning #5), recurrence via S665454 + S665478 family

---

## R-003 — NCCL/Gloo mixed process-group `dist.barrier()` incompatibility

**Signature:** Code introduces `dist.barrier()` using NCCL process group while other coordination uses gloo → barrier hangs at 3h timeout. Known hang pattern.

**Triggers M-005** (ALLREDUCE barrier rank desync) → may cascade to M-001.

**Triggering diff:** D103046213 (landed 2026-05-04) — reland of code previously reverted for S656635. Distributed Hive writer in SilverTorch `bulk_eval` publish loop.

**Fix-in-flight:** D105401690 (mentioned in S665464). Process gap: revert from S656635 didn't generate a CI guardrail; same code re-landed.

**Evidence:** S665464 (Stories ESR streaming, 20-58 jobs/day affected across multiple oncalls)

---

## R-004 — NCCL collective timeout (unrelated upstream cause)

**Signature:** `NCCL collective timeout` in elastic agent stderr; killed all workers; agent hangs cleaning up.

**Triggers M-001** via the most common path.

**Fix-in-flight:** D105606893, D105652547 (in new light_cli per daily-brief).

**Evidence:** S665478 (reels lsr mb9, m2123154171, m2123153585)

---

## R-005 — TCPStore binding silent failure

**Signature:** Rendezvous never completes; one rank fails to bind TCPStore; other ranks wait indefinitely.

**Triggers M-001** via rendezvous-failure path.

**Fix-in-flight:** D103808649, D103808619 (per S665454 thread reference).

**Evidence:** S658165

---

## R-006 — `bloom_index_b` static capacity exceeded

**Signature:** Configured `bloom_index_b=N` (e.g., 2240) is below current organic feature cardinality → C++ `bloom_index_build` operator deadlocks → all DPP workers hang at 0 QPS. `DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE` symptom.

**Triggers M-015** directly.

**Triggering condition:** Cardinality growth (organic, no code change required).

**Fix-in-flight:** T271094105 (lizichao). Specific config path: `fbcode/minimal_viable_ai/models/ig_ranking/threads_lsr/feed/slimper/run_config.py`.

**Evidence:** S665454 references this mechanism for m2129246926 (Opsmate's referenced model). NB: this turned out to be wrong-model attribution — actual Threads Retrieval U2M is m2124122280 with M-001 mechanism instead.

---

## R-007 — Scribe overload / capacity shortfall

**Signature:** Scribe stream lag increases across multiple consumers; `scribe_read_proxy.client_lag_in_seconds` rising. Often correlated with peak traffic events.

**Triggers M-007** (downstream-infra cascade) → M-002 (DPP starvation).

**Evidence:** Recurring across CL-003 instances

---

## R-008 — ZippyDB CAS throttle

**Signature:** ZippyDB compare-and-swap rate limit hit; throttling errors propagate to consumers; downstream lag increases.

**Triggers M-007** → cascades to M-002, M-006.

**Evidence:** S665163 (CAS throttling, mitigated 2026-05-19 16:36 PDT). Cluster CL-003 P58 sub-mechanism.

---

## R-009 — DPP worker config misalignment

**Signature:** DPP `--dpp-worker-buffer-size`, `--dpp-worker-num-threads`, `--cache-warmup-max-count` set sub-optimally for data volume. Symptoms: chronic DPP starvation, periodic capacity exhaustion.

**Triggers M-002** (DPP starvation).

**Fix:** Tune the config knobs. NB: workaround #2 (reduce `--cache-warmup-max-count` 100M→10M) declined in S661645 due to freshness impact.

**Evidence:** S661645 workaround #3 applied, partial improvement

---

## R-010 — Shampoo NaN factor_matrix corruption (`PreconditionerValueError`)

**Signature:** `PreconditionerValueError factor_matrix 31.block_0.0` at training step; second-moment matrix accumulates NaN.

**Triggers M-003** (trainer NaN cascade with auto-restart).

**Fix:** Model-side. Family-wide CL-017 mitigation needed (per W21 mega-learning + auditor R-VC4 carryover).

**Evidence:** m878858380, m2134801434 (CFR family, 2026-05-19/20)

---

## R-012 — `_preload_item_pool()` blocks DPP consumer during startup

**Signature:** `_preload_item_pool()` blocks DPP consumer thread during startup; DPP workers fill output queues; `GetDataTimeoutError 6000s` after timeout; crash loop with multiple restarts.

**Triggers M-002** (DPP starvation, specific class) → eventually CL-013 example-age spike.

**Fix:** Reduce `--preload-batch-size 2048→512`; limit `ds=*` to specific partition; long-term async item pool reload.

**Evidence:** W1324864999608243 (Rudra Barua, ig_retrieval/trainer.py 2026-05-15: 9 restarts × 2 regions, 21h)

---

## R-013 — MVAI manual expiration silently passed

**Signature:** OT job stops launching; no MAST failure; intent stays active but no new attempts start. Discovered when downstream notices QPS drop.

**Triggers M-004** (auto-start silent stall, sub-class).

**Evidence:** S664106 (model 2128461099, 2026-05-14)

---

## R-014 — FBLearner recurring flow silently disabled

**Sub-classes:**
- **a:** `is_enabled=false` early-return
- **b:** `skip_recurring=True` early-return — `online_train_publish` SUCCEEDED silently  
- **c:** parent FBLearner workflow stopped → `QuickAppOrphanJobCleanerObserver` kills child MAST job

**Triggers M-004** (auto-start silent stall, sub-classes).

**Evidence:** Renqincai 2026-05-16 post (model 2124118880, sub-class a), W1215710353808301 (sub-class b)

---

## R-015 — Sparse data quality regression

**Signature:** Sparse data inputs degrade in quality; sigrid_predictor detects via `bad_sparse %` rising; falls back to FS ingestion.

**Triggers M-006** (snapshot transition / bad_sparse fallback).

---

## R-016 — FS read tail latency on predictor side

**Signature:** Predictor reading FS files (via Manifold or warm-storage) hits tail-latency spike during high concurrency or storage degradation.

**Triggers M-006** (snapshot transition latency).

---

## R-017 — Koski `PERMISSION_DENIED` on Scribe table ACL

**Signature:** `meta ai.mast-job error` shows `KoskiUserErrorWithTraits PERMISSION_DENIED`, exitcode 100 (non-retryable), `ErrorSubSystem=KOSKI_CONNECTOR`, error message contains "use the ACL link to grant access to data_project".

**Triggers M-009** (cogwheel publish failure class — DPP sub-mechanism).

**Fix:** Grant ACL via Koski-generated AMP link in error; restart DPP.

**Evidence:** S665607 (silvertorch/ifr_prospector, 21.4h)

---

## R-018 — CUDA OOM at AOTI lowering

**Signature:** Out-of-memory during AOTI compile step; specific to model size + GPU memory budget.

**Triggers M-009** (cogwheel publish failure class).

---

## R-019 — TorchScript class annotation

**Signature:** TorchScript class annotation issue at publish time.

**Triggers M-009**. Fix: P52 (in known-patterns.md).

---

## R-020 — `LoweringLogicException` incomplete refactor (D105054082)

**Signature:** `LoweringLogicException: Could not guard on data-dependent expression Eq(u48, 0)` during AOTI lowering in `online_train_publish`.

**Triggering diff:** D105054082 (landed 2026-05-19 08:05 PDT) changed `torch._check(x.size(0) > 0)` → `torch._check_is_size()` (allowing N=0), but applied `guard_or_false(N == 0)` to only 1 of 15 bare `if N == 0:` sites. The 14 unfixed sites crash AOTI lowering.

**Fix-in-flight:** D105862249 (forward fix covering all 14 remaining sites).

**Triggers M-009/M-012** (conveyor regression sub-class).

**Evidence:** S666451 (mvai/mvai_ifr_main cogwheel test BLOCKED, 2026-05-19 23:02 PDT)

---

## R-021 — Sandcastle I7_XLARGE OOM (chronic)

**Signature:** light_cli builds hit OOM on I7_XLARGE Sandcastle hosts. 1625+ blocked hours over 60 days per W21 mega-learning #3.

**Triggers M-009** (cogwheel publish failure class).

**Fix-in-flight:** None landed. Capacity mismatch identified but unmitigated.

**Evidence:** S665707, P2341327283

---

## R-022 — GPU quota misconfiguration (Online vs Offline bucket)

**Signature:** Job placed in `threads_offline` (or non-Scribe-based) tenant when it should be in `threads_online_training` (Scribe-based). Preemption follows.

**Triggers M-010** (MAST scheduling preemption).

**Discovery date:** 2026-05-18 (per team_context note).

---

## R-024 — TGIF rendezvous timeout (transient TCPStore/Gloo)

**Signature:** `online_train_publish` step hangs at TGIF publish; TCPStore/Gloo rendezvous timeout; no code change in failing release.

**Triggers M-009** (cogwheel publish failure class, transient sub-class).

**Fix:** Wait for auto-resolution (transient); if recurrent >6h: lower TGIF publish timeout OR add per-rank heartbeat probe.

**Evidence:** S651873 (43.4h, R9149.1 → R9154.1 self-cleared)

---

## R-025 — FS publish boundary blocking training (HYPOTHESIS, unverified)

**Hypothesis:** Periodic FULL_SNAPSHOT publish writes ~36GB+; trainer may serialize during write window, producing periodic stall.

**Triggers M-011** (holdout periodic data-cycle stall) if confirmed.

**Falsifier:** Check whether 25min/hr stall windows align with FS publish boundaries (e.g., hourly publish takes ~25 min). If aligned → R-025; if not → R-026/27/28.

**Status:** Surfaced 2026-05-20 thread MQwOLaC3jLc; needs Scuba time-series correlation between FS publish timestamps and SM util drops.

---

## R-026 — Periodic eval / validation pass blocks training (HYPOTHESIS)

**Hypothesis:** Holdout runs scheduled eval/validation on a holdout split every ~hour, pausing training during eval.

**Triggers M-011** if confirmed.

**Status:** Hypothesis only; would need to inspect training script or check job logs for eval cycle.

---

## R-027 — Periodic distributed barrier with slow rank (HYPOTHESIS)

**Hypothesis:** Periodic synchronization (gradient sync, checkpoint barrier) where one rank is consistently slower, causing other ranks to wait at barrier for ~25min.

**Triggers M-011** if confirmed. Similar mechanism class to M-005 but on a different cadence.

---

## R-028 — GC / compaction in side process (HYPOTHESIS)

**Hypothesis:** A side process (warmup cache compaction, checkpoint compression, log rotation) takes ~25min/hr and contends with training compute or holds a lock.

**Triggers M-011** if confirmed.

---

## R-029 — Conveyor pkg ModuleNotFoundError (`torchdata_deprecated.datapipes.iter.transform`)

**Signature:** `ModuleNotFoundError: No module named 'torchdata_deprecated.datapipes.iter.transform'` in `online_train_publish` step at AOTI / cogwheel test time. App layer pkg `:350` (`cfr_main_feed_mtml_roo_hstu`).

**Triggers M-012** (conveyor regression — pkg path break).

**Evidence:** S665902 (Vaibhav Rahangdale, 2026-05-18 17:36 PDT)

---

## R-031 — Upstream T2I embedding corpus regression (STUS kmeans)

**Signature:** Upstream T2I embedding feed degrades from 22K → 1,315 entries (below 64,077 minimum required by `fresh_index_initializer.py:91`). STUS trainer fails identically every restart attempt.

**Triggers M-013** (STUS kmeans corpus underflow).

**Fix:** Restore corpus to >64K. Short-term: lower `n_min_embeddings_required` as stopgap.

**Evidence:** m2130324780 2026-05-20 (Threads textpost m2m retrieval)

---

## R-032 — Detector threshold not STUS-aware

**Signature:** FS-missing detector threshold (~1h) doesn't account for STUS-role models which publish FS every ~hour+. Repeated false-positive fires.

**Triggers M-014** (STUS-normal-cadence misclassification).

**Fix:** Per-model-role detector configuration OR L20-style ratchet (2nd+ fire → explicit owner suppress/retune escalation).

**Evidence:** A1009946182010606 (m2130324780, 3rd fire in 3d)

---

## R-033 — Detector threshold misalignment

**Signature:** Detector configured for one snapshot-type cadence; model produces different cadence; fires as false-positive.

**Triggers M-016** (detector misconfiguration).

---

## R-034 — Detector data source disconnected

**Signature:** Detector's metric stream broken; emits `[Invalid Detector - No Data]` prefix.

**Triggers M-016**.

**Evidence:** A1201406268614142 on m2126189932 (ig_reels_starsearch_t2i_retrieval baseline, 2026-05-19/20)

---

## R-035 — Detector hysteresis missing

**Signature:** Detector fires on threshold cross, never re-evaluates / clears even after metric recovers. Active state persists for days/weeks.

**Triggers M-017** (detector-no-auto-clear).

**Evidence:** A1530150995193297 (12 days CRITICAL, model recovered, never cleared)

---

## D75703936 — `checkpoint_training_data_age_mins` formula bug (TZ skew)

**Signature:** UTC vs -7h timezone shift in `_resolve_ts_now()` produces ~3000-min false positive for OT jobs at restart. Triggers `[VIDEO][...] training stability - training data age` alerts erroneously.

**Triggers M-016** (detector misconfiguration / architecturally invalid for OT).

**Fix:** Pending land. Catch via mega-learnings grep (2026-W21.md).

**Evidence:** m877766932 facebook_reels_vdd_hstu_v0 baseline (cron correctly diagnosed DETECTOR_BROKEN on 2026-05-19/20)
