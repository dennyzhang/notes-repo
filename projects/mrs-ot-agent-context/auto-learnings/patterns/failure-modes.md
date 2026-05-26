# Failure Modes (M-NNN)

_Intermediate causal step between symptom and root cause. "How is the system broken right now?" — distinguished from "what specific bug" (root_causes.md) and "what we see" (symptoms.md)._

## 🔥 Hot 3 right now (2026-05-20)

1. **M-001** Elastic agent zombie — 974+ GPU-hr; CL-012 chronic; dispositive signature = AITO `NOT_APPLICABLE` + KILLED_BY_USER
2. **M-011** Holdout periodic data-cycle stall — NEW 2026-05-20; m2145336177 + 4 sibling holdouts firing on `scribe_read_proxy` in <24h; 25min/hr stall with snapshot cadence intact (snapshot ≠ training-compute liveness)
3. **M-012** Conveyor regression — S665902 IN PROGRESS; `ModuleNotFoundError` in `online_train_publish` blocks ALL FS publish while trainer RUNS healthy; trainer-alive + FS-missing ≠ STUS-normal

## 📑 Index (17 entries)

| M-NNN | Failure mode | Family signal | Linked CL |
|---|---|---|---|
| **M-001** | Elastic agent zombie (D-state subprocess) | TRAINER_CRASH cascade | CL-012 |
| **M-002** | DPP starvation | DATA_STARVATION | CL-003 |
| **M-003** | Trainer NaN cascade | TRAINER_CRASH (self-recovers) | CL-017 |
| **M-004** | OT auto-start silent stall | LAUNCHER_CONTAINMENT | CL-009 |
| **M-005** | ALLREDUCE barrier rank desync | TRAINER_CRASH (collective layer) | CL-014 |
| **M-006** | Snapshot transition / bad_sparse fallback | PUBLISH_BROKEN | CL-013 |
| **M-007** | Downstream-infra reliability cascade | DATA_STARVATION (infra) | CL-003 |
| **M-009** | Cogwheel publish failure class | FLOW_DISCIPLINE | CL-004 |
| **M-010** | MAST scheduling / capacity preemption | CAPACITY_EXCEEDED | CL-006 |
| **M-011** | Holdout periodic data-cycle stall | PUBLISH_BROKEN ↔ TRAINER (hot) | — |
| **M-012** | Conveyor regression (online_train_publish broken) | PUBLISH_BROKEN | CL-001 (P61) |
| **M-013** | STUS kmeans corpus underflow | DATA_STARVATION (upstream corpus) | — (P63) |
| **M-014** | STUS-normal-cadence misclassification | bot-rule gap | L20/L22 |
| **M-015** | bloom_index_b overflow deadlock | CAPACITY_EXCEEDED | — |
| **M-016** | Detector misconfiguration | DETECTOR_BROKEN | CL-018 |
| **M-017** | Detector-no-auto-clear after recovery | DETECTOR_BROKEN | CL-018 |
| **M-018** | Freshness regression cascade (training→serving) | PUBLISH_BROKEN | — |

_Ordered by ID for stable refs; "Hot 3" callout above replaces impact-order need. Drill into individual entries below._

Each entry: failure-mode name → causal description → falsifier (how to distinguish from siblings) → cross-references.

---

## M-001 — Elastic agent zombie (D-state subprocess)

**Description:** Worker subprocess dies for any reason → PyTorch elastic agent (torchrun launcher) catches `ChildFailedError` → tries to terminate remaining subprocesses → at least one stuck in D-state (uninterruptible kernel sleep, usually GPU/NCCL driver) → unkillable by any signal including SIGKILL → agent blocks forever in `subprocess.wait()` → MAST sees launcher PID alive → reports RUNNING. Training stopped but system reports healthy.

**Falsifier:** Verify by checking `meta ai.mast-job error` returns ONLY user-kill (no AITO classification), `mvai_metrics` shows stale samples, but `meta ai.mast-job describe` returns `status: RUNNING`. If AITO classifies the error → different failure mode (worker death propagated cleanly).

**Maps from symptoms:** S-002 (FS missing), S-003 (QPS=0), S-005 (StuckJobException), S-006 (mvai_metrics flatline)

**Maps to root causes:** R-001 (CUDA allocator assert), R-002 (exit_w_cleanup gap), R-003 (NCCL/Gloo mixed-PG), R-004 (NCCL collective timeout), R-005 (TCPStore binding race), R-006 (bloom_index static capacity), R-014 (ALLREDUCE rank desync via DPP slowness)

**Maps to mitigations:** D-001 (external liveness probe), D-002 (hard exit timeout), D-003 (cgroup force-kill)

**Linked CL-NNN:** CL-012 (StuckJobDetector coverage gaps is the mitigation-gap framing of this mechanism)

**Evidence:** S665478, S665454, S665464, S628346, S658165, S661645 (6 instances spanning Jan-May 2026)

---

## M-002 — DPP starvation

**Description:** DPP workers cannot keep pace with training consumption → GPUs idle waiting for data → training QPS drops → example_age climbs. Distinct from M-001 in that DPP is the bottleneck, trainer is fine; the elastic agent isn't zombie.

**Falsifier:** Check `DPP Data Starvation %` in `meta ai.mast-job system-metrics`. If >10% sustained → DPP-bound; if <2% → not DPP, look at other failure modes.

**Maps from symptoms:** S-001 (example_age spike), S-003 (QPS=0), S-004 (slow ramp-up)

**Maps to root causes:** R-007 (Scribe overload), R-008 (ZippyDB throttle / CAS), R-009 (DPP worker config — buffer-size/num-threads/preload), R-012 (preload_item_pool blocking startup)

**Maps to mitigations:** D-005 (`ot-timeout-monitor` cron), D-007 (D104947534 SJD publisher-shutdown — DPP QPS watchdog scope)

**Linked CL-NNN:** CL-003 sub-mechanism

**Evidence:** W1324864999608243 (`_preload_item_pool` deadlock), CL-003 cascades

---

## M-003 — Trainer NaN cascade

**Description:** Trainer step produces NaN in optimizer state (Shampoo factor_matrix corruption) → step crashes → MAST auto-restart from clean checkpoint succeeds → training resumes. Symptoms persist for a window: stale NaN detector alerts continue firing even after recovery.

**Falsifier:** Check `meta ai.mast-job attempts` — if v_N → v_N+1 restart succeeded with clean checkpoint → NaN cascade + auto-recovery. Trainer current attempt RUNNING with fresh mvai_metrics = recovered. Persistent NaN alerts AFTER recovery = stale detector, not active failure.

**Maps from symptoms:** S-002 (FS missing during outage window), S-006 (mvai_metrics flatline during outage), S-007 (stale NaN alerts post-recovery)

**Maps to root causes:** R-010 (Shampoo NaN factor_matrix corruption), R-011 (second-moment matrix corruption)

**Maps to mitigations:** D-010 (P56 NaN mitigation playbook), D-011 (R-VC4 family-SEV escalation)

**Linked CL-NNN:** CL-017 (Not OT-owned; routed via R21 to model owners)

**Evidence:** m878858380, m2134801434 (CFR family, 2026-05-19/20)

---

## M-004 — OT auto-start silent stall

**Description:** OT job stops launching / stops producing OT-diff with no MAST failure event. Roots: (a) MVAI manual expiration silently passed; (b) FBLearner recurring flow `is_enabled=false` OR `skip_recurring=True` early-return; (c) parent FBLearner workflow stopped → child MAST killed by `QuickAppOrphanJobCleanerObserver`. Detection only when downstream notices.

**Falsifier:** Probe `intent==active` model: if `(now - last_mast_attempt_start) > 2× expected_launch_interval` OR `online_train_publish step SUCCEEDED` while no TLS config diff in last interval → silent stall.

**Maps from symptoms:** S-001 (example_age climbs without limit), S-006 (mvai_metrics gradually flattens)

**Maps to root causes:** R-013 (MVAI expiration), R-014a (recurring flow disabled), R-014b (skip_recurring=True), R-014c (parent FBLearner stopped)

**Maps to mitigations:** D-006 (`ot-autostart-liveness` cron — 1 week agent work, owner dennyzhang)

**Linked CL-NNN:** CL-009

**Evidence:** S664106, W1215710353808301, S665135 (initially mis-attributed)

---

## M-005 — ALLREDUCE barrier rank desync

**Description:** Multi-rank training group performs synchronized reduce; one rank delays (DPP slow, NCCL flap, GPU IO) → other ranks wait at barrier → timeout (3h default) → barrier fails → can cascade to M-001 zombie. Distinct from M-001 in that the mechanism is at the COLLECTIVE/barrier layer; the zombie behavior may follow but is separate.

**Falsifier:** Check `mvai-training-online-* error` for `WatchdogTimeout`, `ALLREDUCE`, or `NCCL.*timeout`. ASH/trace shows one rank slower than peers.

**Maps from symptoms:** S-002, S-003, S-005

**Maps to root causes:** R-014 (DPP-driven rank desync), R-003 (NCCL/Gloo mixed-PG barrier), R-004 (NCCL collective timeout from unrelated cause)

**Maps to mitigations:** D-005 (`ot-timeout-monitor` cron — timeout-aware bot rule)

**Linked CL-NNN:** CL-014

**Evidence:** S661645 (DPP-slow → rank desync → 3h ALLREDUCE timeout), S665464 (mixed-PG dist.barrier hang)

---

## M-006 — Snapshot transition / bad_sparse fallback

**Description:** Sparse delta path degrades (data quality, latency) → sigrid_predictor falls back to full-snapshot ingestion → predictor reads larger FS files more frequently → tail-latency spikes. Trainer publishes both SPARSE_DELTA and FULL_SNAPSHOT; the failure is on the predictor-side fallback.

**Falsifier:** Query BOTH `p50_sparse_min` AND `bad_sparse %` from sigrid_predictor. If sparse is healthy but bad_sparse is high → M-006. If sparse latency itself is high → likely M-002 or M-007.

**Maps from symptoms:** S-001 (sparse delta e2e latency alerts), S-008 (serving error rate cascading)

**Maps to root causes:** R-015 (sparse data quality regression), R-016 (FS read tail latency)

**Linked CL-NNN:** CL-013 sub-mechanism (added 2026-05-18 per team_context)

**Evidence:** Recent IG ATS alerts where bad_sparse % was the discriminator

---

## M-007 — Downstream-infra reliability cascade (DPP / ZippyDB / Scribe)

**Description:** Upstream-of-OT infra (ZippyDB CAS throttle, Scribe overload, DPP worker shortage) causes cascading effects in OT pipeline. ~1 cascade per week observed; multi-PG.

**Falsifier:** Active in-progress SEV matching ZippyDB/Scribe/Koski/DPP infra. If sibling holdout/baseline models in different families ALL show similar timing → cascade. If isolated to one model → not M-007.

**Maps from symptoms:** S-001, S-003, S-004, S-005 (when via M-005)

**Maps to root causes:** R-007 (Scribe overload), R-008 (ZippyDB CAS throttle), R-017 (Koski PERMISSION_DENIED scribe ACL)

**Maps to mitigations:** D-012 (downstream-infra SLA conversation with ZippyDB/Scribe/DPP leads), D-013 (OT-side graceful-degradation design)

**Linked CL-NNN:** CL-003

**Evidence:** S665163 (ZippyDB CAS, 2026-05-19), S665607 (Koski ACL, 2026-05-19), S659917 (Feed LSR)

---

## M-009 — Cogwheel publish failure class

**Description:** mvai / light_cli build-and-publish conveyor fails at cogwheel test step. Roots: CUDA OOM, ImportError, TorchScript annotation, transitive C++ ABI breaks, TGIF timeouts, Sandcastle preemption, AOTI lowering bugs. ~2/week cadence by trunk-health workstream scope.

**Maps from symptoms:** S-009 (cogwheel/conveyor test failures)

**Maps to root causes:** R-018 (CUDA OOM at lowering), R-019 (TorchScript class annotation), R-020 (LoweringLogicException incomplete refactor), R-021 (Sandcastle I7_XLARGE OOM), R-024 (TGIF rendezvous timeout)

**Maps to mitigations:** D-008 (post-revert reland-block CI gate), D-015 (host-memory ceiling check)

**Linked CL-NNN:** CL-004 (Not OT-owned; trunk-health workstream owns)

**Evidence:** S666451, S651873, S665607, S666322, S666413, 26+ prior-month archives

---

## M-010 — MAST scheduling / capacity preemption

**Description:** Job preempted or fails to schedule due to capacity / quota / scheduler state. Particularly relevant since 2026-05-18 GPU quota split (Online Scribe-based vs Offline non-Scribe). Wrong-quota-bucket placement → preemption root cause.

**Falsifier:** Check tenant path (`threads_online_training` vs `threads_offline`). If wrong bucket → M-010 + R-022 (quota misconfiguration). If correct bucket but preempted → R-023 (capacity contention).

**Maps from symptoms:** S-004 (slow ramp / re-launch lag), S-002 (snapshot gaps if job preempted)

**Maps to root causes:** R-022 (quota misconfig), R-023 (capacity contention)

**Maps to mitigations:** D-016 (quota-tenant-path validation in launcher)

**Linked CL-NNN:** CL-006 (Watch — possibly quiescent)

---

## M-011 — Holdout periodic data-cycle stall (training-progress vs publish-cadence gap)

**Description:** Holdout model publishes snapshots on clockwork cadence (every 3 min) while training compute is idle 25min/hr in a periodic pattern. Snapshot output ≠ training progress. The training stall isn't DPP starvation (DPP starvation % flat at 1.94%) — something else is pausing the training loop periodically.

**Falsifier:** Check GPU SM utilization vs fleet average. If avg SM util < 10% of fleet (~3-4% absolute on T20_GRAND_TETON A100/H100 systems), AND p25 GPU device util = 0%, AND DPP Data Starvation flat <2% → M-011. If DPP starvation high → M-002.

**Maps from symptoms:** S-001 (example_age spikes periodically), S-003 (QPS=0 windows)

**Maps to root causes:** R-025 (FS publish boundary blocking — hypothesis, needs verification), R-026 (periodic eval/validation pass), R-027 (periodic distributed barrier with slow rank), R-028 (GC/compaction in side process)

**Maps to mitigations:** D-004 (`ot-age-spike-monitor` cron + dedicated dashboard, owner shuminwu+dennyzhang, NOT STARTED — Top action item #1)

**Linked CL-NNN:** CL-013 (this mechanism is novel as of 2026-05-20; new sub-mechanism for the cluster)

**Evidence:** m2145336177 2026-05-20 (newly-surfaced via Denny's pattern observation, confirmed via system-metrics p50 SM util 0.92%)

---

## M-012 — Conveyor regression (online_train_publish path broken)

**Description:** A change to mvai package or its dependencies breaks the `online_train_publish` step. Trainer MAST is RUNNING and producing checkpoints fresh; the publish step fails silently or with import/code errors. Distinguished from M-001/M-003 by: trainer continues running normally while NO new FULL_SNAPSHOT is published.

**Falsifier:** Trainer attempts show RUNNING, mvai_metrics fresh, but `meta ai.model.instance list` shows last FS publish hours ago AND an active CONVEYOR_REGRESSION SEV exists.

**Maps from symptoms:** S-002 (FS missing while trainer healthy)

**Maps to root causes:** R-029 (Conveyor pkg `torchdata_deprecated` ModuleNotFoundError = S665902), R-030 (Conveyor pkg incompatibility classes), R-009-conveyor-fix (D105862249 cleanup)

**Maps to mitigations:** D-008 (post-revert reland-block CI gate)

**Linked CL-NNN:** CL-001 sub-mechanism + own pattern P61

**Evidence:** S665902 (cfr_main_feed_mtml_roo_hstu pkg :350 ModuleNotFoundError, 2026-05-18/19)

---

## M-013 — STUS kmeans corpus underflow

**Description:** STUS model relies on T2I embedding corpus reaching minimum count for kmeans index build. When upstream corpus regresses below threshold (e.g., 64,077 minimum), `fresh_index_initializer.py:91` raises AssertionError → trainer dies → restart fails identically until corpus restored. Delta serving continues healthy.

**Falsifier:** Check `meta ai.mast-job error --version=<v>` for `AssertionError: At least N embs needed for kmeans, but got M`. M << N confirms.

**Maps from symptoms:** S-002 (FS missing on STUS)

**Maps to root causes:** R-031 (upstream T2I embedding corpus regression)

**Maps to mitigations:** D-017 (lower n_min_embeddings_required as stopgap), D-018 (upstream corpus health monitoring)

**Linked CL-NNN:** new pattern P63 candidate from 2026-05-20 daily-ledger

**Evidence:** m2130324780 2026-05-20 (22K→1,315 collapse, PAGE to ronghuang)

---

## M-014 — STUS-normal-cadence misclassification

**Description:** STUS-role models publish FULL_SNAPSHOT on ~hourly+ cadence (vs trainer models' ~minute cadence). FS-missing alerts threshold-tuned for trainer models fire repeatedly on STUS models without indicating a real failure.

**Falsifier:** Confirm role=STUS via R14 (entrypoint=`st_update_service/`). Compute gap-vs-cadence ratio: if gap within 2× historical cadence → THRESHOLD_MISFIT, classify per L20 escalation rule.

**Maps from symptoms:** S-002 (FS missing in detector window despite normal operation)

**Maps to root causes:** R-032 (detector threshold not STUS-aware)

**Maps to mitigations:** D-010 (L20 STUS escalation rule — 2nd+ fire = explicit owner suppress/retune recommendation)

**Linked CL-NNN:** CL-008 (routed by R14+R23)

**Evidence:** A1009946182010606 (m2130324780, 3rd fire in 3d — though this also turned out to be a real M-013 case, not pure M-014; the rule still applies for non-M-013 STUS cases)

---

## M-015 — bloom_index_b overflow deadlock

**Description:** Static bloom filter capacity (e.g., `bloom_index_b=2240`) exceeded by organic feature cardinality growth → C++ `bloom_index_build` operator deadlocks → all DPP workers hang at 0 QPS. Not a crash — deadlock. MAST sees process alive.

**Falsifier:** Check feature cardinality trend vs configured `bloom_index_b`. If cardinality > capacity AND `DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE` symptom present → M-015.

**Maps from symptoms:** S-005 (StuckJobException after operator manual-kill), S-003 (QPS=0)

**Maps to root causes:** R-006 (bloom_index_b static capacity exceeded)

**Maps to mitigations:** D-019 (raise bloom_index_b OR migrate to dynamic-sized), D-020 (bloom-filter auto-scaling)

**Linked CL-NNN:** CL-012 sub-mechanism

**Evidence:** S665454 (m2129246926 Threads Feed U2M sub-class — note that m2129246926 was wrong-model from Opsmate; m2124122280 is the true Threads Retrieval U2M with M-001 mechanism instead)

---

## M-016 — Detector misconfiguration

**Description:** Detector configured against snapshot type the model doesn't produce (e.g., ITEM_EMB_DELTA on a model that never publishes that type), or stale/dead detector still active. Fires as false-positive.

**Falsifier:** Check model.instance list for the snapshot type the detector targets. If model has 0 instances of that type in ≥500 history → detector misconfig.

**Maps from symptoms:** S-007 (`[Invalid Detector - No Data]` + sub-class detector-misconfig)

**Maps to root causes:** R-033 (detector threshold misaligned), R-034 (detector data source disconnected)

**Maps to mitigations:** D-021 (archive-match suppression rule)

**Linked CL-NNN:** CL-018 (alert noise)

**Evidence:** m2145491885 holdout ITEM_EMB_DELTA detector misconfig (2026-05-19/20)

---

## M-017 — Detector-no-auto-clear after recovery

**Description:** Detector fires on a real event; model recovers; detector keeps firing for hours-to-days because its re-evaluation cadence is too slow or the underlying metric never crosses the clear threshold cleanly.

**Maps from symptoms:** S-007 (sub-class stale-fire)

**Maps to root causes:** R-035 (detector hysteresis missing), R-036 (re-evaluation cadence too slow)

**Maps to mitigations:** D-021 (archive-match suppression rule), D-022 (detector clear-cadence tuning at source)

**Evidence:** A1530150995193297 (12 days CRITICAL active, model recovered, never cleared), m878858380 NaN sub-alerts 67h-stale

---

## M-018 — Freshness regression cascade (training-side → serving-side)

**Description:** Training-side example_age regression produces stale snapshots → serving consumes stale weights → calibration drift → serving error rate elevated. Connects M-002/M-007 to S-008.

**Maps from symptoms:** S-008 (serving error rate elevated, when caused by training-side staleness)

**Maps to root causes:** Various upstream root causes via mechanisms M-002, M-007, M-011

**Maps to mitigations:** D-018 (upstream corpus health), D-013 (graceful-degradation design)

**Evidence:** S660507 (m2134801434 chronic non-zero error rate amplified by NaN-induced FS gaps), S659243 (Shots SEV1 → 61 TIXU models calibration broken)
