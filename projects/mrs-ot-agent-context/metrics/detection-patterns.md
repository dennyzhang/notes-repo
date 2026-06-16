# Detection Patterns — Temporal Anomalies

Threshold checks catch "is this metric bad right now?" but miss "has this metric been bad for too long?" or "is this metric trending toward failure?"

This file encodes **temporal patterns**: metric + duration + context = detection.
The bot should propose new patterns when it encounters incidents that thresholds alone couldn't catch.

---

## Schema

```
- id: DP-NNN
  name: <human-readable name>
  category: <zombie|slow_start|cliff|stall|creep|desync|silent_failure>
  detection_rule:
    metric: KM-XX
    condition: <what to check>
    duration: <how long before firing>
    context: <when this pattern is vs isn't a problem>
  severity: <critical|warning|info>
  user_journey: UJ-NNN
  query_sequence: [Q-NNN steps]
  auto_discovery_hint: <how the bot would notice this pattern is missing>
  provenance: <incident_ref|human_proposed|bot_inferred>
  confidence: <confirmed|inferred|proposed>
  discovered: <date>
```

**Categories:**
- `zombie` — resource alive but producing nothing
- `slow_start` — resource started but not reaching expected throughput
- `cliff` — sudden drop from healthy to unhealthy, sustained
- `stall` — expected output stops arriving
- `creep` — metric slowly drifting toward a failure threshold
- `desync` — two systems disagree on resource state
- `silent_failure` — no error logged but output is wrong or missing

**Auto-discovery hints:** When the bot triages an incident and thinks "I should have caught this earlier," it should check whether a detection pattern exists. If not, propose one.

---

## Active Patterns

### DP-001: Zombie Training Job (QPS = 0)

- category: zombie
- detection_rule:
  - metric: KM-T2 (Training QPS)
  - condition: QPS = 0 or effectively zero (<1% of expected baseline)
  - duration: >1 hour after job reaches RUNNING state
  - context: Normal during first 10-15 min of job startup (model loading, checkpoint restore, DPP warmup). Abnormal after that.
- severity: critical
- user_journey: UJ-004 (Infra Cost Waste), UJ-001 (Model Freshness)
- query_sequence:
  1. Q-003 — check MAST job state (confirm RUNNING)
  2. Q-002 — check Training QPS (confirm zero)
  3. Q-005 — check trainer logs for last iteration number (confirm not advancing)
  4. Q-004 — check for errors (what's blocking training)
- what_causes_this:
  - DPP workers all dead / unreachable (data starvation)
  - Model stuck in checkpoint restore (corrupt or huge checkpoint)
  - Deadlock in training loop (NCCL hang without timeout)
  - Hedwig publisher blocking training thread (full queue backpressure)
  - Job running but Python process hung (no error, no output)
- auto_discovery_hint: Bot sees a job that's been RUNNING for hours but MLHub shows zero QPS. Existing thresholds only flag "unhealthy=zero" without the time dimension.
- provenance: human_proposed (operator example, 2026-05-26)
- confidence: confirmed
- discovered: 2026-05-26
- example: Reranker 2125081901 (2026-05-23) — job ran 6 days, publisher inactive, zero training output. SJD didn't kill it.

### DP-002: Slow Start (QPS << Expected)

- category: slow_start
- detection_rule:
  - metric: KM-T2 (Training QPS)
  - condition: QPS < 30% of expected baseline for this model type
  - duration: >1 hour after first training iteration logged
  - context: Some ramp-up is normal (10-30 min for large models). But if QPS is still <30% of baseline after 1 hour, something is throttling.
- severity: warning
- user_journey: UJ-001 (Model Freshness — training too slow to keep model fresh)
- query_sequence:
  1. Q-005 — check iteration count (confirm training started but slow)
  2. Q-002 — check Training QPS trend
  3. Q-001 — check Training Example Age (if rising, data pipeline can't keep up)
  4. Check DPP dashboard — is data pipeline the bottleneck?
  5. Check GPU utilization — is compute the bottleneck?
- what_causes_this:
  - DPP workers underprovisioned (data pipeline can't feed GPUs fast enough)
  - PT2 compilation in progress (first N iterations are slow while torch.compile runs)
  - Checkpoint restore still streaming embeddings from Manifold
  - Shared cluster contention (network bandwidth, storage IOPS)
  - Wrong hardware allocation (e.g., got A100 instead of expected H100)
- auto_discovery_hint: Bot sees training example age climbing even though job is RUNNING and QPS is non-zero. The job isn't dead — it's just too slow.
- provenance: human_proposed (operator example, 2026-05-26)
- confidence: confirmed
- discovered: 2026-05-26

### DP-003: QPS Cliff (Sudden Sustained Drop)

- category: cliff
- detection_rule:
  - metric: KM-T2 (Training QPS)
  - condition: QPS drops >50% from rolling 1-hour average, stays down >30 min
  - duration: >30 min sustained after drop
  - context: Brief dips during checkpoint save, full snapshot publish, or DPP buffer refill are normal (1-5 min). Sustained >30 min is not.
- severity: warning
- user_journey: UJ-001 (Model Freshness)
- query_sequence:
  1. Q-002 — confirm QPS drop in trend
  2. Q-005 — check if iterations are still advancing (slow vs stuck)
  3. Q-004 — check for errors around the drop time
  4. Check if a full snapshot publish started (expected temporary dip)
- what_causes_this:
  - One or more GPUs failed (training continues on remaining GPUs at reduced throughput)
  - NCCL partial hang (some ranks blocked, others proceeding slowly)
  - DPP lost workers mid-training
  - Memory pressure causing GC pauses
  - PT2 recompilation triggered by a graph break
- auto_discovery_hint: Training example age starts climbing while job is RUNNING and QPS is non-zero but degraded.
- provenance: bot_inferred
- confidence: inferred
- discovered: 2026-05-26

### DP-004: Checkpoint Stall

- category: stall
- detection_rule:
  - metric: KM-CK1 (Checkpoint Publish Cadence)
  - condition: No new checkpoint for >2x the expected checkpoint interval
  - duration: Continuous (no checkpoint since last one)
  - context: Expected interval varies by model config. Typical: 30-90 min.
- severity: warning (→ critical if >4x interval)
- user_journey: UJ-002 (Model Availability — no checkpoint = no snapshot = stale model)
- query_sequence:
  1. Q-011 or Q-010 — check last checkpoint/snapshot time
  2. Q-005 — check if training is still advancing (stall vs slow)
  3. Check trainer logs for checkpoint save errors (Manifold timeout, disk full)
- what_causes_this:
  - Manifold write timeout during checkpoint save
  - Checkpoint size too large for configured timeout
  - Training iteration time regressed (takes longer to reach checkpoint interval)
  - Full snapshot publish blocking checkpoint path (some models)
- auto_discovery_hint: Full snapshot alert fires, but root cause is upstream: no checkpoint produced to publish.
- provenance: bot_inferred (from UJ-002 investigation pattern)
- confidence: inferred
- discovered: 2026-05-26

### DP-005: Memory Creep (Trending Toward OOM)

- category: creep
- detection_rule:
  - metric: GPU Memory Utilization
  - condition: GPU memory trending up >1% per hour over rolling 6-hour window
  - duration: >6 hours of continuous upward trend
  - context: Some memory growth is normal during embedding table warmup (first 1-2 hours). After warmup, memory should plateau.
- severity: info (→ warning if >90% utilized)
- user_journey: UJ-004 (eventual OOM crash = waste), UJ-002 (crash disrupts model availability)
- query_sequence:
  1. Check GPU memory via MAST system metrics or TensorBoard
  2. Q-005 — correlate with iteration count (memory per iteration increasing?)
  3. Check for embedding table growth (new features being added?)
- what_causes_this:
  - Memory leak in custom training code
  - Embedding table growing without eviction
  - PT2 inductor cache growth
  - Accumulating gradient buffers from failed backward passes
- auto_discovery_hint: Job eventually OOMs after running fine for hours/days. Retrospective check shows memory was climbing linearly.
- provenance: bot_inferred
- confidence: proposed
- discovered: 2026-05-26

### DP-006: TMS/MAST Desync Crash-Loop

- category: desync
- detection_rule:
  - metric: KM-SYNC1 (TMS/MAST State Desync)
  - condition: MAST RUNNING + TMS not ONLINE_READY, OR ≥3 consecutive DEAD attempts with duration <10 min and kill by TMS reconciler
  - duration: >10 min desync, or ≥3 crash-loop iterations
  - context: Brief desync during normal TMS state transitions is expected (≤5 min).
- severity: critical
- user_journey: UJ-004 (crash-loop = GPU waste)
- query_sequence: Q-080, Q-081
- what_causes_this: See D106193941 — fire swallowing TMS UNAUTHORIZED
- provenance: incident_CL (D106193941, model 2128686073)
- confidence: confirmed
- discovered: 2026-05-26

### DP-007: Silent Publisher Death

- category: silent_failure
- detection_rule:
  - metric: KM-P4 (Hedwig Publisher Activity)
  - condition: isActive=false AND queueSizeBytes=0 across all ranks
  - duration: >30 min
  - context: Brief publisher inactivity during snapshot transition is normal (1-5 min).
- severity: critical
- user_journey: UJ-003 (Silent Quality Drift — job running, no output), UJ-004 (waste)
- query_sequence: Q-014
- what_causes_this:
  - Hedwig streaming tracker SMC has no hosts
  - Publisher channel authentication failure
  - Publisher initialization failed silently at startup
- auto_discovery_hint: Job RUNNING, training QPS non-zero, but no delta/streaming events in gmpp for >30 min.
- provenance: incident_CL (reranker 2125081901, 2026-05-23 — 6 days silent)
- confidence: confirmed
- discovered: 2026-05-26

### DP-008: DPP Starvation Onset

- category: creep
- detection_rule:
  - metric: KM-T1 (Training Example Age)
  - condition: Example age trending up >1 min per hour over rolling 3-hour window
  - duration: >3 hours of continuous upward trend
  - context: Spikes during Scribe maintenance or DPP worker restarts are normal (recover in <30 min).
- severity: warning
- user_journey: UJ-001 (Model Freshness)
- query_sequence:
  1. Q-001 — confirm example age trend
  2. Q-040 — check Scribe QPS (is upstream data drying up?)
  3. KM-U3 — check the per-mast-job DPP starvation ODS (fburl.com/canvas/pzoyunzx) + scribe token ingress (Scuba dpp_stats_v2); a scribe-ingress drop = upstream scribe/region drain. Corroborate with the trainer INFO log `DataClient.cpp "Current output queue size is: N"` (one short snapshot can mislead — trust the per-job ODS/ingress trend). S674219 root = EAG/DR scribe drain (S674227, fix D94521578).
  4. Q-002 — check training QPS (is training consuming data faster than pipeline can supply?)
- what_causes_this:
  - Scribe category throughput decreased (upstream logging change)
  - DPP workers lost due to capacity rebalance
  - Training QPS increased (model update made training faster, pipeline now bottleneck)
  - Scribe category hit rate limiter
- auto_discovery_hint: Model freshness SLO starts missing but job is healthy — the bottleneck is upstream.
- provenance: bot_inferred (from CL-013 pattern)
- confidence: inferred
- discovered: 2026-05-26

---

### DP-009: Upstream DPP Failure (Data Pipeline Down)

- category: silent_failure
- detection_rule:
  - metric: KM-U2 (DPP Worker Health) + KM-T1 (Training Example Age)
  - condition: Training example age rising AND (DPP workers showing starvation OR DPP error rate >5%)
  - duration: >15 min
  - context: DPP workers restart occasionally (normal, recovers in <5 min). Sustained starvation = DPP outage.
- severity: critical
- user_journey: UJ-001 (Model Freshness), UJ-P1 (Upstream Cascade)
- query_sequence:
  1. Q-001 — training example age trend (is it rising?)
  2. DPP Dashboard (fburl.com/unidash/tv4cxmm0) — worker health, error rate
  3. Q-004 — trainer logs for DPP errors (`data_preproc_service_settings`, `Connection refused`, `RECV_EOF`)
  4. Check if multiple models are affected (fleet-wide = DPP infra, single model = model-specific config)
- what_causes_this:
  - DPP service deployment in progress
  - DPP workers OOM on a specific table/partition
  - Network partition between trainer and DPP workers
  - Warm Storage throttling (WSE_CP_ADM_CTRL_THROTTLED)
- cross_check: If multiple OT models show rising example age simultaneously → DPP infra issue, not model-specific. Route to `dpp_distributed_systems` oncall.
- provenance: incident_CL (CL-003 downstream infra cascade, root model 2125081911 DPP connection errors 2026-05-23)
- confidence: confirmed
- discovered: 2026-05-26

### DP-010: Upstream Scribe Failure (Data Source Dry)

- category: silent_failure
- detection_rule:
  - metric: KM-U1 (Scribe QPS) + KM-T1 (Training Example Age)
  - condition: Scribe category QPS dropped >50% from 24h baseline AND training example age rising
  - duration: >30 min
  - context: Scribe QPS varies by time of day (diurnal pattern). Compare against same hour yesterday, not rolling average.
- severity: warning (→ critical if QPS = 0)
- user_journey: UJ-001 (Model Freshness)
- query_sequence:
  1. Q-040 — Scribe QPS for the model's scribe category
  2. Q-001 — training example age (confirm downstream impact)
  3. `di.scribe_category_meta` — check category owner and any known outages
  4. Check if category was recently renamed, merged, or deprecated
- what_causes_this:
  - Upstream logging pipeline change (feature logging stopped)
  - Scribe category renamed without updating OT job config
  - Scribe rate limiter throttling
  - Logging infrastructure outage
- cross_check: Model's `--scribe-categories` flag in fire command tells you which category to check.
- provenance: incident_CL (S660546 Scribe drought → stale full snapshot)
- confidence: confirmed
- discovered: 2026-05-26

### DP-011: MAST Scheduling Failure (Job Can't Start)

- category: stall
- detection_rule:
  - metric: KM-T3 (MAST Job State)
  - condition: Job in PENDING state for >30 min, or job keeps getting preempted and re-queued
  - duration: >30 min PENDING, or >3 preemptions in 2 hours
  - context: Brief PENDING during capacity rebalance is normal (5-10 min). Sustained = capacity issue.
- severity: warning (→ critical if >2 hours)
- user_journey: UJ-001 (Model Freshness — can't train if can't schedule)
- query_sequence:
  1. Q-003 — MAST job attempts (check for PENDING status, preemption patterns)
  2. Check entitlement/attribution from fire command — is it on borrowed capacity?
  3. Check if hardware type is available in the target region
  4. `meta ai.mast-job describe` — check `onElasticCapacity`, `preemptionInfo`
- what_causes_this:
  - GPU capacity exhausted for the entitlement
  - Job requesting hardware type not available in region
  - Elastic capacity borrowed and reclaimed
  - MAST scheduler issue
- provenance: human_doc (triage.md data-first workflow)
- confidence: confirmed
- discovered: 2026-05-26

### DP-012: Manifold/Storage Failure (Checkpoint Can't Write)

- category: stall
- detection_rule:
  - metric: KM-CK1 (Checkpoint Cadence) + trainer error logs
  - condition: No new checkpoint AND trainer logs show Manifold write errors (TIMED_OUT, StorageServiceClientV2 errors)
  - duration: >1x expected checkpoint interval
  - context: Transient Manifold errors (1-2 retries) are normal. Persistent failure blocks checkpointing, which blocks snapshot publishing.
- severity: warning
- user_journey: UJ-002 (Model Availability — no checkpoint → no snapshot)
- query_sequence:
  1. Q-010/Q-011 — check last checkpoint time
  2. Q-004 — check for storage errors (`StorageServiceClientV2`, `TIMED_OUT`, `Manifold`)
  3. Check Manifold bucket health if errors persist
- what_causes_this:
  - Manifold bucket at capacity
  - Storage service overloaded
  - Network issue between trainer host and Manifold
  - Checkpoint size exceeded timeout (model too large for configured timeout)
- provenance: incident_CL (reranker 2125081901 had StorageServiceClientV2 TIMED_OUT errors, 2026-05-23)
- confidence: confirmed
- discovered: 2026-05-26

### DP-013: TMS Auto-Pause After Crash-Loop

- category: desync
- detection_rule:
  - metric: KM-TMS1 (TMS State) + KM-T3 (MAST Job State)
  - condition: TMS state = PAUSED AND MAST job = DEAD AND no manual pause was issued
  - duration: Immediately upon detection
  - context: TMS auto-pauses a model after excessive crash-loops to prevent runaway resource consumption. This is protective but means the model stays offline until someone manually un-pauses.
- severity: critical
- user_journey: UJ-002 (Model Availability — model stuck offline until human intervenes)
- query_sequence:
  1. Q-030 — TMS state (confirm PAUSED)
  2. Q-003 — MAST attempts (confirm crash-loop history)
  3. Q-004 — error from last crash (what killed the job repeatedly?)
  4. Check TMS events in Scuba for auto-pause event
- what_causes_this:
  - Crash-loop exceeds TMS retry limit → auto-pause
  - Root cause of crash-loop unfixed → un-pausing will just restart the loop
  - Fix root cause first, then `mvai online-training-mgr -m <id> -s online`
- provenance: incident_CL (D106193941 — model 2128686073 crash-looped 21x, TMS auto-paused)
- confidence: confirmed
- discovered: 2026-05-26

---

## Proposed Patterns (need more incident evidence)

### DP-P1: Iteration Time Regression

- category: creep
- condition: Iteration time increasing >10% over 24-hour window with stable batch size
- causes: PT2 recompilation, embedding table growth, DPP latency increase
- needs: 2+ incidents to confirm detection threshold

### DP-P2: Partial Rank Failure

- category: silent_failure
- condition: N-1 of N ranks reporting metrics, 1 rank silent
- causes: Single GPU failure, NCCL ring broken on one rank
- needs: Incident data — currently theoretical

### DP-P3: Recurring Preemption

- category: zombie (effective)
- condition: Job preempted >3x in 24 hours on borrowed capacity
- causes: Low-priority entitlement, capacity crunch
- needs: Preemption frequency data

---

## How the Bot Proposes New Patterns

When triaging an incident, if the bot thinks "I should have caught this earlier," apply this checklist:

1. **Was there a metric that was abnormal BEFORE the incident escalated?** → That metric + the time it was abnormal = a detection pattern.
2. **What temporal condition would have triggered?** → Encode as: metric + condition + duration.
3. **What's the false positive risk?** → Add context (when this pattern is vs isn't a problem).
4. **Does an existing DP-NNN already cover this?** → If yes, update. If no, propose new DP-P.
5. **After 2+ incidents match the proposed pattern** → promote from DP-P to DP-NNN (active).

---

## Evolution Log

| Date | Change | Trigger |
|---|---|---|
| 2026-05-26 | Seeded DP-001 through DP-008 from operator examples + session incidents | Initial creation |
| 2026-05-26 | Proposed DP-P1/P2/P3 from theoretical analysis | Pattern brainstorm |
