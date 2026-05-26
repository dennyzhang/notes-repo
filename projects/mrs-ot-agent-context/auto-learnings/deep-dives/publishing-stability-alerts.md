# Publishing-Stability Alert System

How `dai_modelstore` publishing-stability alerts are configured, triggered, suppressed, and routed. Load this when triaging a publishing-stability alert.

## Three Observer Types per Model

Each monitored model gets up to three independent observers:

| Observer | Snapshot Types Monitored | Suppressed By | Purpose |
|---|---|---|---|
| `full_snapshot` | `FULL_SNAPSHOT` | Nothing — base health signal | Always created |
| `item_embed_delta` | `ITEM_EMB_DELTA` | `full_snapshot` failure | Suppressed during full snapshot outage (prevents alert storm) |
| `misc_deltas` | `SPARSE_DELTA` + `DENSE_DELTA` | `full_snapshot` failure | Suppressed during full snapshot outage |

Suppression formula: `if (suppressing_sum < 0.5) activating_sum else 0`. When the base signal (full_snapshot) is failing, downstream delta alerts are silenced — a full snapshot outage implies deltas won't work either.

## Thresholds

| Severity | Window | Fraction | Trigger |
|---|---|---|---|
| MAJOR | 1.2× `cycle_minutes` | 50% | > 0.5 missed events |
| CRITICAL | 3.0× `cycle_minutes` | 100% | > 0.5 missed events |

Clear window: 1.1× `cycle_minutes`. Liveness poll: 3600s.

## Observer Naming Convention

```
{safe_model_type}.{model_id}.{observer_type}.observer
```

Example: `facebook_reels_hstu_standalone_cint.841363997.full_snapshot.observer`

## Routing Pitfall

`v1.Training` defaults to **RECURRING**, not ONLINE. If a model's training type isn't explicitly `v1.Training.ONLINE` in its SLO config, `is_online_training` is False and full_snapshot alerts route to `home_ml_platform` instead of `mrs_online_training`. Root cause of `ifr_prospector_v0` misrouting (fixed in D90638628).

## Config Sources

| Source | Config | How models enter |
|---|---|---|
| Hand-maintained | `v1_all_pgs` in `discovery.slo.cconf` | Engineer manually adds |
| Model Registry | `v1_from_mr.cinc` | Auto from MR; SLI/SLO converted via `publishing_stability_via_snapshot_counts()` |

Trend: migrating toward MR-only (auto-discovery). Per Paul Lu's posts, push to deprecate `structured_workflow_monitoring` in favor of TMS + SLICK alerting (tracked under "MUMU" — MRS Unified Measurement Utility, led by Anthony Foiani).

## Alert Systems Architecture (which system owns which alerts)

| System | Config Location | # Alerts | Routes To |
|---|---|---|---|
| **IFR Watchtower** | `configerator/.../multifeed/.../ifr_ranking_online_training_monitor.observer` | 14 | mrs_online_training |
| **MVAI SWM** | `configerator/.../minimal_viable_ai/models/*/structured_workflow_monitoring.cinc` | ~64 | pe_mrs_ml |
| **MVAI OT Infra** | `configerator/.../minimal_viable_ai/alerts/infra/online_training/` | 3 | mrs_online_training |
| **MVAI Template Detectors** | `configerator/.../minimal_viable_ai/alerts/observers/` | ~20 | minimal_viable_ai |
| **Piranha/Conveyor** | `configerator/.../piranha/job_detectors/dts/observers/` | ~6 | mrs_online_training |

## Known Alert Quality Issues (from OT alert audit, H1 2026)

| Problem | Impact | Mitigation |
|---|---|---|
| IFR Watchtower 10m data-age threshold fires constantly | ~12K noisy detector runs/quarter (3 alerts) | Raise to 30m+ in `ifr_ranking_online_training_monitor.observer` |
| NaN batch fires 11 separate alerts (one per metric task) | 11× noise per NaN event | Consolidate `model_train_metrics_violation_alert.template_detector.cconf` to per-model grouping |
| IFR Watchtower vs MVAI SWM duplicate coverage on same models | Duplicate alerts on different oncalls for same incident | Consolidate — IFR Watchtower only for IFR-specific signals |
| Only 2 of ~100+ OT alerts are truly UI-only (`::STATIC` suffix) | Migration scope is tiny — alert QUALITY is the real problem, not definition type | Focus on dedup and threshold tuning, not UI→configurator migration |

## Upstream Model Dependency Tracking

D93247541 added `_get_upstream_models()` — traverses the Model Registry dependency graph via `ST_ROOT_MODEL`, `RERANKER_MODEL` metadata fields. For each upstream model, the alert system generates the same set of observers. The alert system now monitors the full dependency chain, not just direct model publishing.

## Fleetwide Application Error Monitoring

Orthogonal detector (D92646977) on `mast_hpc_job_run_status` catches correlated fleet-wide failures (shared infra issue like Manifold outage, broken dependency).

| Signal | Meaning |
|---|---|
| Publishing alert for one model | Single-model issue — investigate the model |
| Fleetwide error detector fires | Many models failing at once — escalate to infra |

## Data-First Triage Procedure (for publishing-stability alerts)

When a `dai_modelstore` alert fires, go to data first — resolves most cases in ~30s.

### Step 1 — MAST job status (~5s)
```bash
meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID> -o json
```

| Pattern | Diagnosis |
|---|---|
| Multiple short DEAD (<2h each) | **Crash-looping** — dies before publish cycle completes |
| One long (>24h) then short DEADs | **Stuck → crash-loop** |
| Single DEAD long duration, next RUNNING | **Transient — likely self-recovering** |
| All recent DEAD, no RUNNING | **Persistent** — needs manual intervention |

### Step 2 — Last successful publish (~10s)
```sql
SELECT time, event, publish_mode, model_snapshot_id
FROM dai_modelstore
WHERE ml_model_id = <MODEL_ID>
  AND event IN ('ModelPublishSuccess','ModelPublishFailure','ModelPublishTransientFailure')
ORDER BY time DESC LIMIT 20;
```

Normal cadence ≈ 90 min. Gap > 3 hr is concerning.

### Step 3 — Classify + act

| MAST Status | Last Publish | Diagnosis | Action |
|---|---|---|---|
| RUNNING, recent (<3h) | Success | Stale / self-resolved | No action |
| RUNNING, no recent (>3h) | Success or missing | **Publishing blocked** | Check logs for publish errors |
| DEAD, crash-looping | Prior success | **Training instability** | Crash logs — OOM, CUDA, data corruption |
| DEAD, single failure | Recent success | Transient | Monitor — TMS auto-restarts within 30 min |
| Not running | Old | Job not scheduled | `mvai online-training-mgr print -m <id>` |

### Step 4 — Context (ONLY after Steps 1-3)
Search related SEVs, infra changes, solver rollouts. Match system to diagnosis.

### Common False Correlations

| Looks related — isn't | Why |
|---|---|
| Active SEV for same model about **serving** | Serving infra is separate from training infra |
| Recent **config change** to inference tier | Config changes affect serving, not training |
| **Scribe volume** spike | Only relevant if training data age is also elevated |

**Rule:** Do NOT correlate by model ID alone. Only correlate when the causal mechanism makes sense.
