# Symptoms (S-NNN)

_Observable signals the bot/operator sees first. Indexed by alert/metric keywords. Add new symptoms when triage encounters a novel observable not covered here._

Each entry: keyword index → description → typical metric/alert form → cross-references to mechanisms (via `_data/edges.md` S→M edges).

---

## S-001 — Training example-age spike

**Keywords:** `example_age`, `training_data_age`, `client_lag_in_seconds`, `scribe_read_proxy`, `e2e latency sparse delta`, `e2e latency`

**Description:** The lag between when an event was generated upstream and when the trainer consumes it. Spikes from minutes to hours indicate freshness regression — the direct proxy for OT freshness.

**Alert forms:**
- `[holdout] online training e2e latency sparse delta`
- `scribe_read_proxy.client_lag_in_seconds` MAJOR / CRITICAL
- `mvai_metrics` `checkpoint_training_data_age_mins`
- `[Invalid Detector - No Data]` prefix (detector-broken sub-class — see S-007)

**Why it matters:** When age spikes, model quality degrades immediately. Multiple SEV2s in history. Top recurring OT symptom (CL-013 status: 🔴 chronic, 4wk count = 4).

**Currently maps to mechanisms (see `_data/edges.md`):** M-001 elastic agent zombie, M-002 DPP starvation, M-007 downstream-infra reliability cascade, M-003 trainer NaN cascade (alert can be stale-fire after recovery), M-011 holdout periodic data-cycle stall

**Linked CL-NNN:** CL-013 (this is the user-visible layer)

**Evidence (recent):**
- 2026-05-20: m2145336177 holdout 25min/hr training stall (mvai-training-online v18) — SM util p50=0.92% vs fleet 36.52%
- 2026-05-19/20 cluster: m878102693, m2145491885, m2132766001, m2144816217, m2145336177 (5 IG retrieval-family holdouts in <24h, scribe_read_proxy)
- S659917 (Feed LSR), S659474, S656875, S635390

---

## S-002 — Snapshot stuck CREATING

**Keywords:** `missing snapshot types`, `FULL_SNAPSHOT missing`, `Publishing Stability`, `dai_modelstore`, `state=CREATING` not progressing

**Description:** Snapshot freezes in CREATING state (model.instance shows entry but never transitions to VALID), or alert fires that a snapshot type is "missing" for the model.

**Alert forms:**
- `Publishing Stability: <model> missing snapshot types FULL_SNAPSHOT|SPARSE_DELTA|DENSE_DELTA`
- `model.instance list` shows `state=CREATING` older than typical creation duration

**Maps to failure modes (see `_data/edges.md`):** M-001 elastic agent zombie, M-003 trainer NaN cascade, M-009 cogwheel publish failure class, M-012 conveyor regression (FS publish blocked), M-013 STUS kmeans corpus underflow, M-014 STUS-normal-cadence misclassification

**Linked CL-NNN:** CL-001 (routed by R17, but 3+ unfixed root mechanisms remain)

**Critical falsifier:** "0 FULL_SNAPSHOT in last N instances" is NOT sufficient evidence of STUS-normal-cadence (mistake made 2026-05-20 05:51 PDT on m2130324780 — actual 19.5h gap on a 80-min-cadence STUS = real failure). Require: gap-since-last-FS within 2× model's historical FS cadence, OR zero FS in extended history (≥100 instances).

**Evidence (recent):**
- 2026-05-20 05:30 m2130324780 (STUS kmeans corpus collapse 22K→1,315 below 64,077 min) — PAGE-class
- 2026-05-19 evening m2134801434 (NaN cascade then self-recovery)
- 2026-05-20 m1530150995193297 (12-day-old CRITICAL alert, never triaged by bot)
- S665902 (cfr_main_feed_mtml Conveyor regression ModuleNotFoundError)

---

## S-003 — Training QPS = 0

**Keywords:** `training QPS`, `qps falling`, `QPS to 0`, `mvai_metrics qps`

**Description:** Training QPS drops to zero or near-zero. Can persist for minutes-to-hours. Often paired with example_age climbing (S-001).

**Maps to failure modes:** M-001 elastic agent zombie, M-002 DPP starvation, M-003 trainer NaN cascade, M-005 ALLREDUCE barrier rank desync, M-011 holdout periodic data-cycle stall, M-006 snapshot transition

**Linked CL-NNN:** CL-015a (sudden mid-training drop)

**Critical observation:** Snapshot-publish cadence is a LIE about training-compute health for STUS-role models. m2145336177 (2026-05-20) published snapshots every ~3 min while SM utilization stayed at p50=0.92% — training was idle ~25min/hr while snapshot path looked clockwork. Always cross-check SM utilization + mvai_metrics QPS, not just snapshot cadence.

**Evidence:** S660507, S659671, S662535, S644248, m2145336177-2026-05-20

---

## S-004 — Training QPS slow ramp-up / chronically slow

**Keywords:** `slow training QPS`, `ramp up`, `MB warmup`, `slow QPS ramp`

**Description:** Training QPS doesn't reach steady-state after job start; remains chronically below expected. Distinct from S-003 (sudden drop) — this is "never reaches healthy" rather than "drops from healthy."

**Maps to failure modes:** M-002 DPP starvation, M-007 downstream-infra reliability, M-010 MAST scheduling/capacity, model-config-side (not in this graph)

**Linked CL-NNN:** CL-015b (slow ramp-up sub-class)

**Known noise:** Feed LSR MB8 warmup takes 3+ hours to reach optimal QPS (team_context heuristic). QPS-low alerts within 3h of restart → MONITOR, not PAGE.

**Evidence:** S662798 (Feed LSR MB8), S559672 historical

---

## S-005 — StuckJobException raised

**Keywords:** `StuckJobException`, `job got stuck`, `stuck for hours`

**Description:** Job goes hours without progress while MAST reports RUNNING. Operator manually kills with reason "STUCK" because automatic detection failed.

**Maps to failure modes:** M-001 elastic agent zombie (primary), M-005 ALLREDUCE barrier rank desync, M-015 bloom_index_b overflow deadlock

**Linked CL-NNN:** CL-012 (mitigation gap layer also implicated)

**Diagnostic signature (counter-intuitive — bot must memorize):**
- `meta ai.mast-job error` shows ONLY user-kill, no underlying failure
- `meta ai.mast-job query-error-context` → `failure_type: KILLED_BY_USER`, `aito_error_classification: NOT_APPLICABLE`
- The absence of any AITO error class = the dispositive signature

**Evidence:** S665454, S665478, S665464, S628346, S658165

---

## S-006 — mvai_metrics flatline (no fresh sample)

**Keywords:** `mvai_metrics`, `latest_sample`, no recent sample, `metric is nan` aged

**Description:** mvai_metrics samples cease to update for a job — gap between latest_sample and current_time grows without trainer restart. Often paired with stale NaN-detector alerts that don't auto-clear (S-007).

**Maps to failure modes:** M-001 elastic agent zombie, M-003 trainer NaN cascade

**Evidence:** stale CFR family NaN alerts firing 67h+ after trainer recovery (m878858380, m2134801434 on 2026-05-19/20)

---

## S-007 — Detector self-reports invalid / stale-fires

**Keywords:** `[Invalid Detector - No Data]` alert prefix, alert age > 7d while ACTIVE, repeated fire on same detector_id without state change

**Description:** Detector is broken (no data source) OR alert fired and entered chronic-firing without state change. Three sub-classes:

1. **`[Invalid Detector - No Data]`** prefix → detector itself broken (false-positive). Model publishing healthy ⇒ DETECTOR_BROKEN class.
2. **Stale fire** → alert created days/weeks ago, still ACTIVE, model has recovered. Detector didn't auto-clear after recovery.
3. **Repeated fire on same detector_id** → STUS-style chronic, owner has not acked/retuned. Per L20 rule: 2nd+ fire → explicit suppress/retune recommendation.

**Maps to failure modes:** M-016 detector misconfig, M-017 detector-no-auto-clear

**Linked CL-NNN:** CL-018 (alert noise — AGG/dead-detector/TEST rules)

**Evidence:** A1530150995193297 (12 days CRITICAL, never bot-triaged), A1009946182010606 (3rd fire in 3d on STUS m2130324780), m878858380 NaN sub-alerts (67h stale-firing)

---

## S-008 — High serving error rate

**Keywords:** `error rate`, `non-zero error rate`, `tier 1 error rate`

**Description:** Serving-side error rate elevated on a prod model. Different layer from training health; can be triggered by training-side issues (publish path producing bad snapshots) or pure serving issues (capacity, downstream calls).

**Maps to failure modes:** M-007 downstream-infra reliability, M-018 freshness regression cascade

**Note:** Often out-of-OT-scope (T4 serving stage). Apply R18 routing.

**Evidence:** S660507 (m2134801434), S659671 (m875961478), S661843 (m875799562 holdout)

---

## S-009 — Conveyor / cogwheel test failure

**Keywords:** `cogwheel_*_test`, `conveyor blocked`, `online_train_publish`, `publish_all`, `publish_offline_st2`, `LoweringLogicException`, `ModuleNotFoundError`

**Description:** Pre-prod conveyor test step fails, blocking new releases. Trainer/publish path in prod still works; new code can't ship.

**Maps to failure modes:** M-009 cogwheel publish failure class, M-012 conveyor regression (a sub-class)

**Linked CL-NNN:** CL-004 (Not OT-owned; trunk-health workstream owns)

**Evidence:** S665902, S666322, S666413, S666451, S661284, S651873, S665607

---

## S-010 — NCCL / distributed collective timeout in trainer log

**Keywords:** `NCCL timeout`, `Watchdog caught collective operation timeout`, `ProcessGroupNCCL`, `NCCL communicator was aborted`, `ncclSystemError`, `Gloo timeout`, `ALLREDUCE timeout`, `barrier timeout`, `TGIF rendezvous timeout`

**Description:** Trainer log emits a distributed-collective timeout: one rank failed to participate in a collective (allreduce/broadcast/barrier) within the watchdog window, NCCL ProcessGroup aborted, worker process exits with `ChildFailedError`. The collective is **not** the bug — it's the failure-detector; the cause is upstream (main thread blocked, GPU stuck, rank slow). Top symptom for `P-001` (main-thread-blocked) and a primary trigger of `M-001` (elastic agent zombie) when the launcher fails to propagate the worker death.

**Alert forms:**
- Trainer stderr: `[E ProcessGroupNCCL.cpp:N] Watchdog caught collective operation timeout: WorkNCCL(...)`
- MAST error: `ChildFailedError` with `NCCL` in stack
- AITO error class: `NCCL_TIMEOUT`, `COLLECTIVE_TIMEOUT`
- Sometimes paired with S-002 (FS missing) and S-005 (StuckJobException) when launcher zombies after the crash

**Why it matters:** Top recurring trainer-side failure class across NCCL/Gloo/TGIF — 4–6 instances per quarter, same shape (`P-001`). High GPU-hour cost when paired with M-001 (training stops but MAST reports RUNNING).

**Maps to failure modes (see `_data/edges.md`):** M-005 (ALLREDUCE barrier rank desync — the direct cause when one rank is slow), M-001 (elastic agent zombie — the cascade when launcher fails to propagate worker death after timeout), M-002 (DPP starvation — when DPP slowness blocks main thread long enough for peer to time out)

**Maps to systemic causes:** P-001 (main thread blocked → timeout-class race)

**Linked CL-NNN:** CL-014 (NCCL/Gloo timeout cluster)

**Critical falsifier:** "NCCL timeout in log" alone does NOT diagnose root cause. Must trace **why the rank didn't respond**: heavy main-thread op (R-004 sub-pattern), CUDA hang on different rank (R-001), DPP slowness (R-014), mixed-PG ordering (R-003). The timeout is the protocol's complaint, not the bug.

**Evidence:** S665478 (NCCL collective timeout w/ launcher zombie), S665454 (CUDA assert → NCCL cascade), S665464 (mixed-PG barrier), R9149.1 TGIF rendezvous (S651873), historical IFR trunk recurrences

---

## S-011 — TCPStore binding race in delta publisher / distributed init

**Keywords:** `TCPStore`, `Address already in use`, `bind() failed`, `RendezvousError`, `TCPStore connect failed`, `delta publisher subprocess`

**Description:** Subprocess (typically a delta publisher worker or distributed-init helper) fails to bind its TCPStore port — either port already in use from a stale process, OR rendezvous race where two subprocesses pick the same port. Subprocess exits silently; parent launcher doesn't always propagate the failure. Common in delta publisher path where multiple short-lived subprocesses share port-allocation logic.

**Alert forms:**
- Trainer/publisher stderr: `RuntimeError: Address already in use` from `c10d::TCPStore` init
- MAST job status: RUNNING but no FS publish progress
- `meta ai.mast-job error` shows ONLY user-kill (silent failure signature — see M-001)
- Sometimes paired with S-002 (FS missing) and S-006 (mvai_metrics flatline)

**Maps to failure modes (see `_data/edges.md`):** M-001 (elastic agent zombie — launcher catches subprocess death but cleanup hangs), M-005 (ALLREDUCE barrier desync when one rank fails init)

**Maps to root causes:** R-005 (TCPStore binding race — fix in flight)

**Maps to systemic causes:** P-002 (worker died, supervising launcher couldn't propagate exit cleanly)

**Linked CL-NNN:** CL-012 (StuckJobDetector coverage gaps)

**Critical falsifier:** Must observe **bind() failure or `Address already in use`** in trainer/publisher log. NCCL timeout alone is NOT S-011 (use S-010). If publisher subprocess just hangs without bind() error → different sub-mechanism (probably M-001 via R-002 exit_w_cleanup gap, not R-005).

**Evidence:** S658165 (IG OT jobs stuck — silent failure on delta publisher subprocess TCPStore binding — still IN PROGRESS as of 2026-05-20)
