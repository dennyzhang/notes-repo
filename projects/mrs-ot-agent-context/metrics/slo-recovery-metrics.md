# SLO & Recovery Metrics — Auto-Discovered

User journeys and key metrics that ground triage verdicts and SEV recovery.
Seeded from human sources, evolved by the flywheel as it triages incidents.

---

## Schema

Every entry carries provenance so the bot knows what's confirmed vs inferred.

```
- metric: <name>
  id: KM-XX
  component: <trainer|publisher|serving|tms|upstream|dependency|quality|freshness|package|checkpoint>
  surface: <ig|fb|retrieval|all>
  thresholds: { healthy: <val>, elevated: <val>, unhealthy: <val> }
  query_ref: Q-NNN (from queries.md)
  provenance: <human_dashboard|slick_config|incident_CL-NNN|triage_gap>
  confidence: <confirmed|inferred|proposed>
  discovered: <date>
  last_verified: <date>
  notes: <free text>
```

**Confidence levels:**
- `confirmed` — human-validated or from an authoritative source (dashboard, SLICK config)
- `inferred` — bot observed this metric was the decisive signal in ≥2 triage sessions
- `proposed` — bot identified a gap during one triage but hasn't validated yet

**Discovery triggers:**
- Triage verdict couldn't anchor to any user journey → propose new journey
- SEV recovery was ambiguous because no metric clearly confirmed resolution → propose new health indicator
- Existing threshold proved wrong (metric was "healthy" by threshold but system was broken) → adjust threshold

---

## User Journeys

**Owned by [user-journeys.md](user-journeys.md).** This file maps metrics to journeys via cross-references:

| Journey | Primary Metrics |
|---|---|
| UJ-001: Model Freshness | KM-T1, KM-T2, KM-S1, KM-F1, KM-F2, KM-F3 |
| UJ-002: Model Availability | KM-P1, KM-D1, KM-CK1, KM-PKG1 |
| UJ-003: Silent Quality Drift | KM-Q1, KM-Q2, KM-T2 |
| UJ-004: Infra Cost Waste | KM-P4, KM-TMS2, KM-PKG1, KM-SYNC1, KM-SYNC2 |

---

## Key Metrics by Component

### Trainer

#### KM-T1: Training Example Age
- thresholds: { healthy: <5 min, elevated: 5-30 min, unhealthy: >30 min }
- check: MLHub Overview tab, Canvas (fburl.com/canvas/x5jdk9f3)
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-T2: Training QPS
- thresholds: { healthy: stable non-zero, elevated: declining/unstable, unhealthy: zero }
- check: MLHub Overview tab, Canvas (fburl.com/canvas/fndv64j6)
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-T3: MAST Job State
- thresholds: { healthy: RUNNING + 0 recent restarts, elevated: RUNNING + restarting, unhealthy: DEAD/crash-looping }
- check: `meta ai.mast-job attempts --name=<job> -o json`
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Publisher

#### KM-P1: Full Snapshot Cadence
- thresholds: { healthy: within model SLO cycle, elevated: 1.5x cycle, unhealthy: >2x cycle or zero }
- check: `get_last_n_checkpoint_metadata_tool` (model_stage=SNAPSHOT, model_instance_state=VALID)
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-P2: Streaming Success Rate
- thresholds: { healthy: ≥99%, elevated: 95-99%, unhealthy: <95% }
- query_ref: Q-012
- check: IG OT SLO Dashboard (ratio = messages_applied / messages_sent). gmpp event count is a proxy only — see Q-012 gotchas.
- provenance: human_dashboard (IG OT SLO)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-P3: Delta Publish Cadence
- thresholds: { healthy: continuous (sparse ~2 min), elevated: gaps >10 min, unhealthy: stopped }
- check: gmpp Scuba by publish_mode
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-P4: Hedwig Publisher Activity
- thresholds: { healthy: isActive=true + queue flowing, elevated: isActive=true + queue backed up, unhealthy: isActive=false }
- check: Trainer logs (`ChunkStreamCache.cpp getPublisherStatus`)
- provenance: incident_CL (reranker 2125081901 zombie, 2026-05-23)
- confidence: inferred
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: Discovered during triage — reranker job ran 6 days with isActive=false, zero queue, no training output. SJD didn't kill it because process was alive. Hedwig `hedwig.streaming.flow.tracker` had no SMC hosts.

### Model Quality

#### KM-Q1: NE (Normalized Entropy)
- thresholds: { healthy: stable within ±0.5% of baseline, elevated: >0.5% regression, unhealthy: >1% regression or NaN }
- check: TensorBoard (`ne/local/lifetime/train`), MLHub
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: Primary signal for UJ-003 (silent quality drift). NE regression without an alert = the worst failure mode. NaN = immediate revert-and-ban.

#### KM-Q2: Loss Value
- thresholds: { healthy: stable non-NaN, elevated: spike >2x baseline, unhealthy: NaN }
- check: TensorBoard (`loss/train`), trainer logs (`message_regex="loss|NaN"`)
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: NaN loss triggers metric validation error path (see reliability/diagnostics/metric-validation-errors.md).

### Per-Delta-Type Freshness

#### KM-F1: Dense Parameter Age
- thresholds: { healthy: <30 min, elevated: 30-60 min, unhealthy: >60 min }
- check: IG OT SLO Dashboard, sigrid_predictor Scuba
- provenance: human_dashboard (IG OT Reliability Dashboard — ESR dense delta ~30 min)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-F2: Sparse Parameter Age
- thresholds: { healthy: <10 min, elevated: 10-30 min, unhealthy: >30 min }
- check: IG OT SLO Dashboard, sigrid_predictor Scuba
- provenance: human_dashboard (IG OT Reliability Dashboard — LSR ~8 min, ESR ~10 min)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-F3: Item Embedding Age
- thresholds: { healthy: model-specific, elevated: >2x baseline, unhealthy: stopped }
- check: IG OT SLO Dashboard
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: ESR/retrieval models only. Threshold varies by model.

### Package Health

#### KM-PKG1: App Layer / Base Layer Expiration
- thresholds: { healthy: >7 days until expiry, elevated: <7 days, unhealthy: expired }
- check: `fbpkg info <pkg>` — look for `Ephemeral: Version expires <date>`
- provenance: incident_CL (CL-009, fbpkg expiry kills OT jobs silently)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: OT jobs run continuously — package expiration is a unique OT failure mode. Recurring training jobs get fresh packages each run. See reliability/operations/preserve-app-layer.md.

### Checkpoint

#### KM-CK1: Checkpoint Publish Cadence
- thresholds: { healthy: within model config interval, elevated: 1.5x interval, unhealthy: >2x or zero }
- check: `get_last_n_checkpoint_metadata_tool` (model_stage=CHECKPOINT)
- provenance: human_dashboard (IG OT Reliability Dashboard)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: Distinct from full snapshot cadence (KM-P1). Checkpoints are training-side; snapshots are publish-side. Checkpoint stall can cause full snapshot stall.

### Serving (Predictor)

#### KM-S1: ATS (Activity-to-Serving Latency)
- thresholds: { healthy: <10 min, elevated: 10-30 min, unhealthy: >30 min }
- check: IG OT SLO Dashboard
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### TMS

#### KM-TMS1: TMS State
- thresholds: { healthy: ONLINE_READY, elevated: ONLINE_READY + high restarts, unhealthy: EXPIRED/PAUSED }
- check: `mvai online-training-mgr print -m <model_id>`
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-TMS2: Restart Count (24h)
- thresholds: { healthy: 0-2, elevated: 3-5, unhealthy: >5 }
- check: TMS status (`numRestarts` field)
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Upstream Data

#### KM-U1: Scribe QPS
- thresholds: { healthy: stable at expected volume, elevated: >20% drop, unhealthy: >50% drop or zero }
- check: Scribe dashboard (`bunnylol scribe <category>`)
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-U2: DPP Worker Health
- thresholds: { healthy: all workers active, elevated: some starvation, unhealthy: widespread starvation }
- check: DPP Dashboard (fburl.com/unidash/tv4cxmm0)
- provenance: human_dashboard
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

#### KM-U3: DPP Data Starvation (ODS)
- thresholds: { healthy: ~0% starvation, elevated: intermittent starvation, unhealthy: sustained high starvation % }
- check: DPP starvation ODS canvas (fburl.com/canvas/pzoyunzx) — the component-level DPP starvation signal
- provenance: human_dashboard (S674219, 2026-06-10)
- confidence: confirmed
- discovered: 2026-06-10
- last_verified: 2026-06-10
- notes: **This ODS is PER-MAST-JOB-ID** (filter by mast job id) — it is the strong, per-job DPP-starvation evidence to hand DPP oncall, NOT just a fleet aggregate. Pair it with **scribe token ingress** (Scuba `dpp_stats_v2`): a scribe-ingress drop = upstream scribe/region drain feeding the starvation. The trainer INFO-log `DataClient.cpp "Current output queue size is: N"` is a useful CORROBORATION (persistently 0 ⇒ starved), but **a single short queue snapshot can look healthy during a REAL fleet starvation — trust the per-job ODS + scribe-ingress trend over one queue read.** S674219 (2026-06-10): EAG/DR scribe drain → ~75% drop in DPP scribe-token ingress → 0 ingress for EAG-reading jobs → fleet OT QPS collapse; tracked S674227, mitigated by D94521578 (undrain EAG scribe). Job 2144239965's queue snapshot looked fed — a misleading single sample, not a refutation (host-preemption S674182 was a concurrent red herring, NOT the root).

### State Desync Detection

#### KM-SYNC1: TMS/MAST State Desync (Orphan Job)
- thresholds: { healthy: TMS ONLINE_READY + MAST RUNNING, elevated: TMS PAUSED + MAST RUNNING (orphan — reconciler will kill in ≤5 min), unhealthy: crash-looping due to desync }
- query_ref: Q-080
- provenance: incident_CL (D106193941 — model 2128686073 crash-looped 21x due to fire swallowing TMS UNAUTHORIZED, 2026-05-11)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: Fire previously swallowed TMS UNAUTHORIZED exceptions and launched MAST jobs anyway. TMS reconciler (5-min cycle) then kills the orphan job. D106193941 fixes the fire path, but the detection pattern remains valuable for other desync causes (manual TMS pause while job runs, ACL changes, TMS state corruption). The general pattern: any time two systems manage the same resource's lifecycle independently, desync = silent waste.

#### KM-SYNC2: Swallowed Exception Detection
- thresholds: { healthy: no error-then-continue patterns in critical paths, elevated: error logged + swallowed + resource launched anyway, unhealthy: swallowed error causes crash-loop }
- query_ref: Q-081
- provenance: incident_CL (D106193941 — swallowed UNAUTHORIZED created orphan jobs)
- confidence: inferred
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: General pattern — when the bot sees a crash-loop with short attempt durations (< 10 min), check for swallowed exceptions in the launch path. The job launches successfully (no launch error) but gets killed shortly after by an external system (TMS reconciler, SJD, preemption). The kill reason in MAST logs reveals the desync.

### Dependency Chain (Retrieval-specific)

#### KM-D1: Root Model Snapshot Production
- thresholds: { healthy: producing snapshots at expected cadence, elevated: no snapshot >2x cadence, unhealthy: zero VALID snapshots or crash-looping }
- check: `get_last_n_checkpoint_metadata_tool` on root model + `meta ai.mast-job attempts`
- provenance: incident_CL (root model 2125081911 crash-loop, 2026-05-23)
- confidence: inferred
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: Downstream I2I model's full snapshot is gated on `root_model_snapshot_id` in trainer logs. If root model is crash-looping, downstream never triggers full snapshot — but stream publishes continue masking the issue in gmpp.

---

## Using in Triage

Every triage verdict should include:

```
**User journey impact:** <UJ-N: name> — <metric> at <current_value> vs <threshold>
**Recovery metrics:** confirmed when:
  1. <KM-XX: name> returns to <healthy threshold>
  2. <KM-XX: name> returns to <healthy threshold>
```

---

## Evolution Log

Track what was added/changed and why, so the flywheel's learning is auditable.

| Date | Change | Trigger | Confidence |
|---|---|---|---|
| 2026-05-26 | Seeded all entries from IG OT SLO Dashboard + triage session | Initial creation + facebook_reels_ifu_i2i investigation | confirmed (dashboard), inferred (incident) |
| 2026-05-26 | Added UJ-4 (Retrieval Index Freshness) | Triage gap — no user journey covered retrieval full snapshot vs stream publish distinction | inferred |
| 2026-05-26 | Added KM-P4 (Hedwig Publisher Activity) | Triage gap — reranker zombie undetected for 6 days | inferred |
| 2026-05-26 | Added KM-D1 (Root Model Snapshot Production) | Triage gap — dependency chain not surfaced in any existing metric | inferred |
| 2026-06-10 | Added KM-U3 (DPP Data Starvation ODS, per-mast-job-id) + scribe-token-ingress pairing | S674219 RCA = EAG/DR scribe drain → ~75% DPP ingress drop → fleet OT QPS=0 (S674227, fix D94521578). Per-job ODS is the strong DPP-oncall evidence; output-queue is corroboration only (a single snapshot misled on job 2144239965) | confirmed |
| 2026-05-26 | Added KM-Q1 (NE), KM-Q2 (Loss/NaN) | Audit — UJ-003 had no detection metrics | confirmed |
| 2026-05-26 | Added KM-F1/F2/F3 (dense/sparse/item embedding age) | Audit — IG dashboard tracks per-delta-type freshness, not just aggregate | confirmed |
| 2026-05-26 | Added KM-PKG1 (package expiration), KM-CK1 (checkpoint cadence) | Audit — CL-009 fbpkg expiry + checkpoint vs snapshot distinction | confirmed |
| 2026-05-26 | Removed duplicate user journey section — now owned by user-journeys.md | Audit — single source of truth | structural |
