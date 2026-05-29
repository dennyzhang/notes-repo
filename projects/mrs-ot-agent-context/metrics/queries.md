# Key Queries — Canonical Reference

Exact queries for each key metric. The bot uses these during triage instead of reinventing them.
Seeded from known-good queries, evolved when the bot discovers corrections or better alternatives.

---

## Schema

```
- id: Q-NNN
  metric_ref: <KM-XX from slo-recovery-metrics.md>
  type: <scuba|cli|slick|log|umm|hive>
  query: <exact command or SQL>
  gotchas: <known pitfalls>
  provenance: <human_doc|incident_discovered|bot_corrected>
  confidence: <confirmed|corrected|proposed>
  discovered: <date>
  last_verified: <date>
```

**Confidence levels:**
- `confirmed` — query returns correct data, verified by human or cross-checked
- `corrected` — original query was wrong, bot discovered the fix during triage
- `proposed` — bot wrote this query but hasn't validated the output yet

---

## Pre-Triage: Model Resolution

### Q-000: Resolve model_entity_id from model_type_name

- type: cli + scuba
- query:
  ```bash
  # Step 1: Find busiest model_entity_ids
  meta scuba.dataset query --dataset=dai_modelstore \
    -a count -g model_entity_id \
    --where='[{"column":"ml_model_model_type_name","op":"eq","values":["<MODEL_TYPE_NAME>"]}]' \
    --hours=168 --limit=10

  # Step 2: Confirm which is the OT prod model (TMS state ONLINE_READY)
  meta ai.managed-training status --model-id=<CANDIDATE_ID>
  ```
- model_family_routing:
  ```
  If model_type contains hstu, i2i, umia, retrieval → retrieval family (use Q-011, not Q-010)
  If model_type contains mtml, esr, lsr → MTML ranking family (use Q-010)
  If unsure → run both and compare
  ```
- gotchas: Multiple model_entity_ids may exist for one model_type (eval, QE, served variants). The OT prod model is the one with `tms_training_state=ONLINE_READY`.
- provenance: human_doc (snapshot-query-canonical.md)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## Trainer Queries

### Q-001: Training Example Age (KM-T1)

- type: scuba (Canvas)
- query:
  ```
  Canvas: https://fburl.com/canvas/x5jdk9f3
  Filter by model_entity_id
  ```
- alt_query (CLI):
  ```bash
  # MLHub Overview tab (quickest visual check)
  # URL: https://www.internalfb.com/mlhub/models/model_series/<model_entity_id>?tab=overview
  ```
- gotchas: None known
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-002: Training QPS (KM-T2)

- type: scuba (Canvas)
- query:
  ```
  Canvas: https://fburl.com/canvas/fndv64j6
  Filter by model_entity_id
  ```
- gotchas: None known
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-003: MAST Job Attempts (KM-T3)

- type: cli
- query:
  ```bash
  meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID> -o json
  ```
- gotchas: None known
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-004: MAST Job Errors

- type: cli
- query:
  ```bash
  meta ai.mast-job error --name=mvai-training-online-<MODEL_ID> --no-truncate
  ```
- gotchas: Walk the exception chain bottom-up. The outermost wrapper (killReason, "non-retryable") is the consequence, not the cause. Stop at the lowest concrete error with a real subsystem name.
- provenance: human_doc (triage.md Rule 0)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-005: Training Iteration Progress

- type: log
- query:
  ```bash
  # Via MCP tool:
  fetch_mast_job_logs_via_logarithm_tool(
    job_name="mvai-training-online-<MODEL_ID>",
    message_regex="iteration|train_step|Memory usage at iteration"
  )
  ```
- gotchas: Log window is limited. For root models with many trainers (16+), filter on Rank 0 to reduce noise.
- provenance: incident_discovered (root model 2125081911, 2026-05-23)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## Publisher Queries

### Q-010: Full Snapshot Status — MTML Models (KM-P1)

- type: scuba
- query:
  ```sql
  SELECT publish_mode, event, instance_type, COUNT(1) AS cnt
  FROM dai_modelstore
  WHERE time >= NOW() - 86400 * 7
    AND model_entity_id = <MODEL_ENTITY_ID>
  GROUP BY publish_mode, event, instance_type
  ORDER BY cnt DESC
  LIMIT 30
  ```
- gotchas: Use bare integer for model_entity_id, not a quoted string — Scuba rejects strings on integer columns.
- provenance: human_doc (snapshot-query-canonical.md)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-011: Full Snapshot Status — Retrieval Models (KM-P1)

- type: umm
- query:
  ```
  # dai_modelstore.publish_mode is NULL for retrieval models — DO NOT USE Q-010
  # Use UMM checkpoint metadata instead:
  get_last_n_checkpoint_metadata_tool(
    model_entity_id=<ID>,
    model_stage="SNAPSHOT",
    model_instance_state="VALID",
    last_n=5
  )
  ```
- cross_check:
  ```bash
  # Trainer logs for stream publish activity:
  fetch_mast_job_logs_via_logarithm_tool(
    job_name="mvai-training-online-<MODEL_ID>",
    message_regex="Stream publish successfully committed snapshot|before next full snapshot publish"
  )
  ```
- gotchas:
  - `publish_mode` is NULL for ALL events in dai_modelstore for retrieval HSTU/UMIA-I2I models (known schema gap)
  - gmpp FULL_SNAPSHOT events for retrieval models are `AllocateBucket` only (preparatory step), NOT `OperatorRun_Success` (completed publish). Zero completed full snapshot events in gmpp.
  - UMM VALID snapshots (with `is_fused` tag) are the actual full fused snapshots. Stream publishes (every ~2 min) are incremental index updates — different thing.
  - "finished N before next full snapshot publish" in trainer logs = iteration counter since last full snapshot. If N keeps climbing past expected threshold, full snapshot is blocked.
- provenance: incident_discovered (facebook_reels_ifu_i2i 2132070936, 2026-05-23)
- confidence: corrected
- discovered: 2026-05-26
- last_verified: 2026-05-26
- notes: Original approach (Q-010 on dai_modelstore) returned "0 publishes" — false. Cross-checked via UMM + trainer logs to discover the schema gap. This is the corrected query path for retrieval models.

### Q-012: Streaming Success Rate (KM-P2)

- type: scuba
- query (ratio — the actual SLO metric):
  ```sql
  -- Streaming success = messages_applied / messages_sent per hour
  -- Check via IG OT SLO Dashboard: igda online-training-slo
  -- Or sigrid_predictor Scuba for per-predictor applied/sent counts
  ```
- query (event count proxy — quick check):
  ```bash
  meta scuba.dataset query --dataset=gmpp -a count -g publish_mode -g event_type \
    --where='[{"column":"model_type","op":"eq","values":["<MODEL_TYPE>"]}]' \
    --hours=24 --limit=20
  ```
- gotchas:
  - The event count proxy (second query) shows activity volume, NOT the success ratio. A model can have high event count but low success rate.
  - The actual SLO metric is `message_applied / message_sent` from trainer to predictor, evaluated hourly. The IG OT SLO Dashboard computes this correctly.
  - For retrieval models, gmpp only shows TensorStreamingSessionEnd/Start and AllocateBucket — no OperatorRun_Success.
- provenance: human_doc (corrected — original query showed count not ratio)
- confidence: corrected
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-013: Delta Publish Cadence (KM-P3)

- type: scuba
- query:
  ```bash
  meta scuba.dataset query --dataset=gmpp -a count -g publish_mode \
    --where='[{"column":"model_type","op":"eq","values":["<MODEL_TYPE>"]},{"column":"publish_mode","op":"eq","values":["SPARSE_ONLY_DELTA"]}]' \
    --hours=6 --limit=10
  ```
- gotchas: None known
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-014: Hedwig Publisher Activity (KM-P4)

- type: log
- query:
  ```bash
  fetch_mast_job_logs_via_logarithm_tool(
    job_name="mvai-training-online-<MODEL_ID>",
    message_regex="getPublisherStatus|isActive|PublishRateLimiter"
  )
  ```
- what_to_look_for: `isActive=false` + `queueSizeBytes=0` = publisher is dead. `isActive=true` + queue flowing = healthy.
- gotchas: A job with isActive=false can run for days without SJD killing it — SJD has no progress liveness check.
- provenance: incident_discovered (reranker 2125081901 zombie, 2026-05-23)
- confidence: inferred
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## Model Quality Queries

### Q-060: NE (Normalized Entropy) (KM-Q1)

- type: tensorboard
- query:
  ```bash
  # Step 1: Get TensorBoard URL from job definition
  mast get-job-definition <job_name> --json | python3 -c "
    import json,sys; print(json.loads(sys.stdin.read()).get('applicationMetadata',{}).get('tb_next_url',''))"

  # Step 2: Or via MCP tool (if available)
  get_mast_job_id_tensorboard_metrics(
    mast_job_id="mvai-training-online-<MODEL_ID>",
    metric_names=["ne/local/lifetime/train"]
  )
  ```
- what_to_look_for: Stable trend within ±0.5% of baseline. Sudden spike or NaN = alert.
- gotchas: MCP tool may fail with `No module named 'scribe.thrift'` on some devservers. Fall back to TensorBoard URL.
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-061: Loss / NaN Detection (KM-Q2)

- type: log + tensorboard
- query:
  ```bash
  # Log search for NaN:
  fetch_mast_job_logs_via_logarithm_tool(
    job_name="mvai-training-online-<MODEL_ID>",
    message_regex="NaN|nan|loss=|metric.*validation.*error"
  )

  # TensorBoard metric:
  # metric_names=["loss/train"]
  ```
- what_to_look_for: Any NaN in loss triggers revert-and-ban path.
- gotchas: NaN can appear in auxiliary metrics without appearing in loss — check all metric validation errors.
- provenance: human_doc (reliability/diagnostics/metric-validation-errors.md)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## Package Health Queries

### Q-070: App/Base Layer Package Expiration (KM-PKG1)

- type: cli
- query:
  ```bash
  # Step 1: Get package name from job definition
  get_mast_job_definition_tool(mast_job_name="mvai-training-online-<MODEL_ID>")
  # Look for app_layer_pkg and base_layer_pkg in app_metadata

  # Step 2: Check expiry
  fbpkg info <pkg_name>:<version>
  # Look for: Ephemeral: Version expires <date>
  ```
- what_to_look_for: `Ephemeral: Version expires` date. If within 7 days, preserve. If expired, job will fail on next restart.
- gotchas: fire-app packages use a different preservation flow — see reliability/operations/preserve-app-layer.md.
- provenance: incident_CL (CL-009)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## Serving Queries

### Q-020: ATS (Activity-to-Serving) (KM-S1)

- type: dashboard
- query:
  ```
  IG OT SLO Dashboard: igda online-training-slo
  NEST: https://ig-data-apps.nest.x2p.facebook.net/ig/relevance-foundations/online-training-slo
  Unidash: https://fburl.com/unidash/ql7qxgas
  ```
- gotchas: Dashboard requires auth. CLI alternative not yet identified for ATS.
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## TMS Queries

### Q-030: TMS State (KM-TMS1)

- type: cli
- query:
  ```bash
  meta ai.managed-training status --model-id=<MODEL_ID>
  ```
- what_to_look_for: `tms_training_state`, `logical_training_state`, `killReason`, `numRestarts`
- gotchas: None known
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-031: TMS Launch Failures

- type: scuba
- query:
  ```
  Scuba: https://fburl.com/scuba/training_platform_model_events/6r21wcb9
  Filter by model_entity_id
  ```
- gotchas: None known
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## Upstream Data Queries

### Q-040: Scribe QPS (KM-U1)

- type: dashboard
- query:
  ```bash
  bunnylol scribe <scribe-category>
  # e.g., bunnylol scribe fb_reels_ifu_i2i_relevance_recopublisher_features_stream_update
  ```
- alt_query: See reliability/workflows/scribe-qps-check.md for the full Scuba query
- gotchas: None known
- provenance: human_doc
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## Dependency Chain Queries (Retrieval)

### Q-050: Root Model Snapshot Production (KM-D1)

- type: umm + cli
- query:
  ```
  # Step 1: Get root model entity ID from fire command
  get_mast_job_definition_tool(mast_job_name="mvai-training-online-<ST_MODEL_ID>")
  # Look for --root-model-entity-id in full_cmd

  # Step 2: Check root model snapshot state
  get_last_n_checkpoint_metadata_tool(
    model_entity_id=<ROOT_MODEL_ID>,
    model_stage="SNAPSHOT",
    last_n=5
  )

  # Step 3: Check root model job health
  meta ai.mast-job attempts --name=mvai-training-online-<ROOT_MODEL_ID> -o json
  ```
- cross_check:
  ```bash
  # Downstream model logs show root_model_snapshot_id — if stuck, root isn't producing
  fetch_mast_job_logs_via_logarithm_tool(
    job_name="mvai-training-online-<ST_MODEL_ID>",
    message_regex="root_model_snapshot_id|root_model"
  )
  ```
- gotchas:
  - The fire command has `--root-model-entity-id` but trainer logs may log it as `root_model_id` with a DIFFERENT entity (e.g., the reranker). Cross-check both.
  - `root_model_snapshot_id` stuck at the same value across all log entries = root model not producing new snapshots.
  - Root model having zero VALID snapshots in UMM doesn't necessarily mean it's broken — it might be a new model that hasn't completed its first publish cycle yet.
- provenance: incident_discovered (root model 2125081911 crash-loop → I2I model 2132070936 full snapshot blocked, 2026-05-23)
- confidence: corrected
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## State Desync Detection Queries

### Q-080: TMS/MAST Orphan Job Detection (KM-SYNC1)

- type: cli
- query:
  ```bash
  # Step 1: Get MAST job state
  meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID> -o json
  # Look for: status=RUNNING

  # Step 2: Get TMS state
  meta ai.managed-training status --model-id=<MODEL_ID>
  # Look for: tms_training_state

  # Step 3: Compare
  # MAST RUNNING + TMS ONLINE_READY = healthy
  # MAST RUNNING + TMS PAUSED = ORPHAN — TMS reconciler will kill within 5 min
  # MAST RUNNING + TMS EXPIRED = ORPHAN — TMS won't restart after kill
  # MAST DEAD + TMS ONLINE_READY = TMS will auto-restart (normal recovery)
  ```
- fleet_scan_variant:
  ```bash
  # For fleet health scans, iterate all OT models:
  # 1. Get all TMS-registered models from fleet-health inventory
  # 2. For each: compare MAST state vs TMS state
  # 3. Flag any MAST RUNNING + TMS not ONLINE_READY
  ```
- gotchas:
  - TMS reconciler runs on a 5-min cycle. A brief desync during normal TMS state transitions is expected — only flag if desync persists >10 min.
  - The kill message from TMS reconciler is: "Online training for <model_id> was stopped by ...ai_infra__training_management_system" — this in the MAST job logs confirms the desync was the kill cause.
  - D106193941 fixes the fire launch path (UNAUTHORIZED now aborts), but other desync causes remain: manual `mvai online-training-mgr -m <id> -s off` while job runs, ACL changes after launch, TMS state corruption.
- provenance: incident_CL (D106193941, model 2128686073 crash-looped 21x)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

### Q-081: Crash-Loop with External Kill Pattern (KM-SYNC2)

- type: cli + log
- query:
  ```bash
  # Step 1: Check for crash-loop pattern (multiple short-lived attempts)
  meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID> -o json
  # Flag if: ≥3 consecutive DEAD attempts with duration < 10 min each

  # Step 2: Check kill reason in the last failed attempt
  meta ai.mast-job error --name=mvai-training-online-<MODEL_ID> --no-truncate
  # Look for: "stopped by ...training_management_system" (TMS kill)
  #           "preempted by" (capacity)
  #           "non-retryable" wrapper (dig deeper)

  # Step 3: If TMS kill, cross-check TMS state (Q-080)
  # If TMS PAUSED but job keeps relaunching → fire is ignoring TMS state
  ```
- auto_discovery_pattern:
  ```
  When the bot sees:
    - MAST attempts: ≥3 DEAD with duration < 10 min
    - Kill reason contains "training_management_system" or "reconciler"
    - TMS state is PAUSED or EXPIRED
  Then:
    - Root cause is TMS/MAST desync, not a training failure
    - Don't debug the trainer — debug why TMS state != ONLINE_READY
    - Check: was there a recent manual pause? ACL change? fire launched without TMS transition?
  ```
- gotchas: Not all short-lived crash-loops are desync — OOM, CUDA errors, and data corruption can also cause rapid restarts. The distinguishing signal is the kill reason pointing to an external system (TMS, SJD) rather than a training error.
- provenance: incident_CL (D106193941)
- confidence: confirmed
- discovered: 2026-05-26
- last_verified: 2026-05-26

---

## SLICK Config References

| Config | Path | What it defines |
|---|---|---|
| IG OT SLO thresholds | `configerator/source/slick/configs/mrs_ml/v1/instagram.slo.cconf` | Per-model SLO definitions for IG |
| MRS discovery SLO | `configerator/source/slick/configs/mrs_ml/v1/discovery.slo.cconf` | All PG-confirmed T1 model types + IDs |
| Publishing stability observer | `configerator/source/mrs_ml/v1/sli_detector/publishing_stability.observer.mcconf` | Alert thresholds per snapshot type |
| Pipeline phase (ESR/LSR) | `configerator/source/minimal_viable_ai/alerts/pipeline_phase.cinc` | Model classification for alert routing |
| IG OT SLO helpers | `ig/online_training/helpers.cinc` | E2E latency + streaming success formulas |

---

## Evolution Log

| Date | Change | Trigger |
|---|---|---|
| 2026-05-26 | Seeded Q-001 through Q-050 from triage.md, monitoring.md, and 2026-05-23 investigation | Initial creation |
| 2026-05-26 | Added Q-011 (retrieval snapshot query) as corrected alternative to Q-010 | dai_modelstore schema gap discovered during triage |
| 2026-05-26 | Added Q-014 (Hedwig publisher activity) | Reranker zombie undetected for 6 days |
| 2026-05-26 | Added Q-050 (root model dependency chain) | Full snapshot blocked by upstream, no existing query path |
| 2026-05-26 | Added Q-000 (model resolution + family routing) | Audit — triage needs entity ID before any query, and family determines query path |
| 2026-05-26 | Corrected Q-012 (streaming success rate) | Audit — original query showed event count, not the applied/sent ratio SLO requires |
| 2026-05-26 | Added Q-060/Q-061 (NE, loss/NaN) | Audit — UJ-003 silent quality drift had no detection queries |
| 2026-05-26 | Added Q-070 (package expiration) | Audit — CL-009 fbpkg expiry |
