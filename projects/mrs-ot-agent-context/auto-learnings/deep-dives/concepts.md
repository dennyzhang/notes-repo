# OT Concepts Glossary

Distilled reference for OT triage and debugging. For procedures, see the upstream MVAI OT skill.

## Architecture — Data Flow

```
User Activity → Scribe → DPP → Trainer (MAST)
    → Publisher → Hedwig (sparse) / Manifold (dense/snapshot) → Predictor (IPnext)
```

| Component | Owner | Purpose |
|---|---|---|
| **Scribe** | MLDP | Real-time training data streams |
| **DPP** | MLDP (`dpp_distributed_data_reading`) | Read Scribe + preprocess |
| **Trainer** | MVAI (`minimal_viable_ai`) | GPU training on MAST |
| **TMS** | AI Infra (`managed_training_service`) | Register + auto-restart OT jobs |
| **UMM / Model Store** | `model_store` | Checkpoints + snapshot versions |
| **SilverTorch** | `home_ml_platform` | Model publishing + predictor serving |
| **Hedwig** | Streaming Infra (`downloads`) | Sparse delta transport |
| **IPnext** | Inference (`ip_runtime_freshness`) | Serving runtime |
| **Multicast** | `home_ml_platform` | Root model → N subscriber inference models via `MRS_DELTA_UPDATE_SUBSCRIBER` sitevar |

## OT vs Recurring Training

| Aspect | Recurring Training (RT) | Online Training (OT) |
|---|---|---|
| Data source | Hive | Scribe |
| Frequency | Every 1.5–2 hrs | Continuous |
| ATS | ~2 hrs | **3–6 min** |
| Publish types | FULL_SNAPSHOT only | FULL_SNAPSHOT + SPARSE_DELTA + DENSE_DELTA |
| Lifetime | Until data read | Forever (continuous) |
| Scheduler | FBLearner | MAST + TMS |

## Three Independent Config Types

| Config | Defines | Key contents |
|---|---|---|
| **Trainer** | HOW to train | `is_online_training`, batch size, LR, optimizer |
| **Model** | WHAT to train | Architecture, layers, embeddings, features |
| **Publisher** | HOW to publish | Delta types, intervals, destinations |

## Publish Types & Transport

| Publish Type | Frequency | Content | Size | Transport |
|---|---|---|---|---|
| **FULL_SNAPSHOT** | 30–120 min | All parameters | 1.5–2.7 TB | Manifold |
| **SPARSE_DELTA** | 2–5 min | Embedding table updates | 60–200 GB | Hedwig streaming |
| **DENSE_DELTA** | 15–30 min | Non-embedding weights | 1–2 GB | Manifold |

Thrift `PublishMode` enum: `FULL_SNAPSHOT`, `DENSE_ONLY_DELTA`, `SPARSE_ONLY_DELTA`, `BULK_EVAL`.

## Key Metrics & SLOs

| Metric | Meaning | Target |
|---|---|---|
| **ATS** | End-to-end freshness (user action → model serves the update) | Model-dependent |
| **Training Example Age** | Age of oldest training example in current batch | Model-dependent |
| **Streaming Success Rate** | % of sparse-delta messages applied by predictor | ≥ 99%/hr, 95% hrs/week |
| **Latency (Sparse)** | Hourly p90 (Scribe delay + model age) | ≤ 10 min, 95% hrs/week |
| **Latency (Dense)** | Hourly p90 | ≤ 30 min, 95% hrs/week |

## Model Entity Types

| Entity | Description | Example |
|---|---|---|
| **Root Model** | Primary training entity | `938983947` |
| **ST (SilverTorch) Model** | Published serving model (retrieval) | `946808046` |
| **Checkpoint** | Intermediate training save | version number |
| **Snapshot** | Finalized, ready-to-serve version | snapshot ID |

> **Resolving model_type → entity IDs:** query `ig_latency_model_ids_per_stage` for stages `Scribe`, `Training`, `Inference`. The **Scribe SPARSE** `model_id` is the canonical entity ID used in MAST job names and TMS commands.

## Two Scuba Tables — Know the Difference

| Aspect | `dai_modelstore` (V1) | `gmpp` (V2) |
|---|---|---|
| Primary use | Alert investigation, historical | Real-time delta status |
| Events | `ModelPublishSuccess`, `UMMCommitModelInstance` | `TensorStreamingSessionEnd`, `OperatorRun_Success` |
| Snapshot type | `additional_fields` array + `any_contains` | `publish_mode` column directly |
| Model key | `model_entity_id` | `model_entity_id` |

### GMPP Staleness Thresholds

| Publish Mode | Healthy | Stale |
|---|---|---|
| `SPARSE_ONLY_DELTA` | < 30 min | > 30 min |
| `ITEM_EMB_DELTA` | < 1 hr | > 1 hr |
| `FULL_SNAPSHOT` | < 24 hr | > 24 hr |

## DPP Diagnostic Metrics

### DPP Starvation

DPP starvation measures the fraction of time the trainer is ready to consume data but has to **wait idle** because DPP can't deliver fast enough. It answers: "Is the trainer starved for data?"

| Starvation Level | Meaning | Bottleneck |
|---|---|---|
| **HIGH (>5%)** | Trainer is fast, DPP can't keep up | DPP / Scribe (upstream) |
| **LOW (<5%)** | DPP has data ready, trainer isn't pulling fast enough | Trainer (downstream) |

**Scuba metric:** `dpp.dpp_master.dynamic_unified_starvation_duration_us` in `dpp_stats_v2` (divide by 600000 to get percentage).

### DPP Bottleneck

Measures the fraction of time DPP workers are the limiting factor. Starvation tells you IF the trainer is waiting; bottleneck tells you if DPP workers specifically are the cause.

| Bottleneck Level | Meaning | Next Step |
|---|---|---|
| **HIGH (>5%)** | DPP workers can't process data fast enough | Check T1 cap, contact MLDP |
| **LOW (<5%)** | DPP workers are fine; if starvation is also high, check Scribe ingestion | Check Scribe category QPS |

**Scuba metric:** `dpp.unified_online_dpp_bottleneck.avg.60` in `dpp_stats_v2` (divide by 600000 to get percentage).

### Combined Interpretation

| Starvation | Bottleneck | Diagnosis |
|---|---|---|
| HIGH | HIGH | DPP workers are the bottleneck — check T1 cap |
| HIGH | LOW | DPP workers fine but data still late — check Scribe ingestion QPS |
| LOW | LOW | Trainer is the bottleneck — data available but trainer consumes slowly |
| LOW | HIGH | Rare — DPP workers slow but trainer doesn't notice (trainer even slower) |

### QPS Throttling

When `QPS_THROTTLING_ENABLED` tag is present in `dpp_stats_v2.job_attribute_tags`, DPP rate-limits Scribe row dequeue via `maxScribeRowsRead` / `scribe_rows_per_second_limit_session_mutable`.

| Scenario | Starvation | Meaning |
|---|---|---|
| Actual QPS ≈ throttle QPS | Any | Throttling working as intended |
| Actual QPS < throttle QPS | LOW | Trainer can't keep up with the throttled rate |
| Actual QPS < throttle QPS | HIGH | DPP-side issue even below the throttle cap |

### Training Example Age Drivers

Training example age = time from user event to when the trainer processes it.

| Scenario | Starvation | Dequeue Rate | Root Cause |
|---|---|---|---|
| Trainer slowed down (publish blocking, PT2 recompile, checkpoint) | LOW (0%) | Drops / oscillates | Data accumulates while trainer is blocked |
| DPP can't deliver fast enough | HIGH (>5%) | At DPP capacity | Upstream bottleneck — DPP workers or Scribe |
| Scribe ingestion dropped | HIGH (>5%) | Drops | No data flowing in — check Scribe category owner |
| Job was down / restarting | N/A | Zero | No training during gap — age spikes, recovers after restart |

### Quick Diagnostic Queries

```bash
# DPP Starvation
scuba -e "SELECT FLOOR(CAST(time AS double) / 300) * 300 AS time_bucket,
  AVG(\`dpp.dpp_master.dynamic_unified_starvation_duration_us\`) / 600000 AS starvation_pct
FROM dpp_stats_v2 WHERE mast_job_name = '<JOB_NAME>'
  AND time >= <START> AND time <= <END>
GROUP BY FLOOR(CAST(time AS double) / 300) * 300 ORDER BY time_bucket;"

# DPP Bottleneck
scuba -e "SELECT FLOOR(CAST(time AS double) / 300) * 300 AS time_bucket,
  AVG(\`dpp.unified_online_dpp_bottleneck.avg.60\`) / 600000 AS bottleneck_pct
FROM dpp_stats_v2 WHERE mast_job_name = '<JOB_NAME>'
  AND time >= <START> AND time <= <END>
GROUP BY FLOOR(CAST(time AS double) / 300) * 300 ORDER BY time_bucket;"

# Training Example Age (DPP-side)
scuba -e "SELECT FLOOR(CAST(time AS double) / 300) * 300 AS time_bucket,
  AVG(\`dpp.online.dpp_worker.scribe_example_age_ms.avg.60.avg.60\`) / 1000 / 60 AS avg_example_age_minutes
FROM dpp_stats_v2 WHERE mast_job_name = '<JOB_NAME>'
  AND time >= <START> AND time <= <END>
GROUP BY FLOOR(CAST(time AS double) / 300) * 300 ORDER BY time_bucket;"

# DPP Dequeue Rate (rows/sec)
scuba -e "SELECT FLOOR(CAST(time AS double) / 300) * 300 AS time_bucket,
  AVG(\`dpp.master.scribe_token_num_rows.sum.60\`) / 60 AS actual_rows_per_sec
FROM dpp_stats_v2 WHERE mast_job_name = '<JOB_NAME>'
  AND time >= <START> AND time <= <END>
GROUP BY FLOOR(CAST(time AS double) / 300) * 300 ORDER BY time_bucket;"
```

## Common Failure-Mode Matrix

| Failure Mode | Scribe Lag | Model Age | Streaming Rate | Root Cause |
|---|---|---|---|---|
| Training QPS can't keep up | ↑ | Stable | Stable | Scribe volume spike, DPP starvation |
| Predictor can't apply updates | Stable | Stable | ↓ | Slow predictor processing |
| Publisher queue buildup | Stable | Stable | ↓ | Hedwig rate limit |
| Trainer stuck (full snapshot) | ↑ | ↑ | No data | Full snapshot blocking deltas |
| Trainer crashed/killed | ↑ | ↑ | No data | Job failure, preemption |
| Snapshot transition stopped | Depends | ↑ | No data | Revert-and-ban, NE regression |

## Fleet Health Categories

| Category | Meaning | Action |
|---|---|---|
| `HEALTHY` | Recent successful TMS launches, no package errors | None |
| `DEAD` | MAST job confirmed DEAD/FAILED | Investigate crash |
| `PKG_STUCK` | >100 pkg errors / 30d, zero successful launches | Package expired |
| `PKG_FAILING` | <100 pkg errors / 30d, zero successful launches | Recently expired; may self-resolve |
| `PKG_WARN` | Pkg errors present but model still launching OK | Monitor |
| `NO_LAUNCHES` | TMS events exist but no successes in lookback | Check launch errors in Scuba |
| `NO_JOB` | No MAST job found for model entity | Deregistered / non-standard job name |

## Cross-Org Oncall Map

| Component | Oncall | Workplace |
|---|---|---|
| SilverTorch / publishing / item embedding | `home_ml_platform` | Silvertorch |
| In-Trainer Publisher (GMPP/TGIF) | `model_processing` | Model Processing Q&A |
| DPP frontend | `mldp_oncall` | MLDP Users |
| DPP backend | `dpp` | — |
| Checkpoints / UMM | `model_store` | UMM |
| Publishing IEN (lowering) | `gpu_lowering` | — |
| TMS / launch | `managed_training_service` | TMS Users |
| Hedwig transport | `downloads` | — |
| MLHub / IROC | `mlhub` | MLHub Users |

### Alert Routing by Snapshot Type

| Alert Snapshot Type | Paged Oncall | Escalate to |
|---|---|---|
| Full Snapshot (LSR + OT) | `mrs_online_training` | `model_processing`, `model_store` |
| Full Snapshot (ESR/Retrieval) | `home_ml_platform` | `model_processing`, `model_store` |
| Dense/Sparse delta (`misc_deltas`) | `mrs_online_training` | `model_processing`, `streaming_infra_oncall` |
| **Item embedding delta (`item_embed_delta`)** | **`home_ml_platform`** | `streaming_infra_oncall`, `model_processing` |

> **Pitfall:** `item_embed_delta` routes to `home_ml_platform`, NOT `mrs_online_training`.

## Key Dashboards

| Purpose | Link |
|---|---|
| Fleetwide OT health | `mrs_online_training_oncall/online_training_fleetwide_health` |
| Training Example Age | [Canvas x5jdk9f3](https://fburl.com/canvas/x5jdk9f3) |
| ATS Dashboard | [Unidash aicx1ux3](https://fburl.com/unidash/aicx1ux3) |
| DPP Health | [Unidash tv4cxmm0](https://fburl.com/unidash/tv4cxmm0) |
| MAST Job Failures | [Scuba ai_mlu/hg7l3phs](https://fburl.com/scuba/ai_mlu/hg7l3phs) |
| TMS Launch Failures | [Scuba training_platform_model_events/6r21wcb9](https://fburl.com/scuba/training_platform_model_events/6r21wcb9) |
| Delta Snapshot Size | [Unidash k3e1rkbw](https://fburl.com/unidash/k3e1rkbw) |
| Unified Online Freshness | `distributed_ai_data/unified_online_freshness/?e[mast_job_name]=<JOB_NAME>` |

## Key Terminology

| Term | Definition |
|------|-----------|
| **OT** / **RT** | Online Training / Recurring Training |
| **DPP** | Data PreProcessing — pipeline that reads Scribe data and feeds it to the trainer |
| **TMS** / **Starcart** | Training Management Service (Starcart = legacy name) — auto-restart |
| **STUS** | Snapshot Transition Update Service — manages model version transitions |
| **ATS** | Activity-to-Serving — end-to-end latency from user action to model serving the update |
| **CSR** | Client-Side Rebatching — DPP sends small batches, trainer concatenates |
| **ESR** / **LSR** | Early-Stage Retrieval / Late-Stage Ranking |
| **TGIF** | Model format used by ranking models for publishing |
| **ZCH** | Zero-Collision Hashing — embedding table collision avoidance |
| **Multicast** | Delta routing from one root model's OT job → many subscriber inference models |
| **MRS_DELTA_UPDATE_SUBSCRIBER** | Sitevar for multicast routing. 3 maps: `sparse_update_subscriber`, `dense_update_subscriber`, `item_update_subscriber` |
| **dai_modelstore** | Scuba table powering publishing-stability alerts (V1) |
| **gmpp** | Scuba table for real-time delta status (V2) — faster for ops checks |

## OT-Specificity Validation (Step 0 before any triage)

Prevents wasting time on an OT-specific angle when the root cause hits all training modes.

### Decision Tree

```
Does model use OT?
├─ NO → Not OT-specific. Redirect to model's recurring training oncall.
└─ YES → Can issue reproduce in RT?
    ├─ YES → Not OT-specific. Redirect to model team / training platform oncall.
    └─ NO/UNKNOWN → Is failure in OT-only component?
        ├─ YES (Scribe, real-time DPP, streaming/delta publish, TMS) → OT-specific. Proceed.
        └─ NO (model arch, optimizer, CUDA/NCCL, MAST scheduling) → Likely NOT OT-specific.
```

### Symptom Table

| Symptom | OT-Specific? | Why |
|---|---|---|
| NaN loss during training | Usually NO | Model/optimizer/data — any training mode |
| Matrix dim mismatch | Usually NO | Model structure — affects OT and RT equally |
| High training example age / Scribe lag | **YES** | Only OT uses real-time Scribe pipeline |
| Streaming success rate drop | **YES** | Only OT publishes sparse/dense deltas via streaming |
| DPP starvation (real-time) | **YES** | Only OT uses real-time DPP from Scribe |
| TMS auto-restart failure | **YES** | Only OT jobs are TMS-registered |
| Checkpoint resume failure after code change | Maybe | Both, but OT hits it first (continuous) |
| CUDA OOM | Usually NO | Hardware/model issue |
| fbpkg expiration | **YES** | OT runs continuously; RT gets fresh pkgs per run |

### Definitive OT check

```bash
mvai online-training-mgr print -m <model_entity_id>
# "No entry found" → NOT OT
# Returns a state (ONLINE_READY, PAUSED, etc.) → IS OT
```

## Revert-and-Ban Procedure

When checkpoints are corrupted by bad training data:

```bash
mvai online-training-mgr -m <id> -s off
mvai ban-versions -m <id> --checkpoint-start-version <first_bad>
mvai ban-versions -m <id> --ban_snapshot_after_ts "<timestamp>"
mvai online-training-mgr -m <id> -s online
```

**Bulk (SEV 0):** stop all → ban per model via pastry + xargs → restart in batches of 25–50 with 30-min buffers.

## ATS Pipeline Budget (10-min target)

| # | Stage | Owner | Budget |
|---|---|---|---|
| 1 | Scribe ingestion → DPP | DPP team | <1 min |
| 2 | DPP → Trainer (sparse data dist) | MVAI | <1 min |
| 3 | Trainer step (fwd + bwd + opt) | MVAI | ~1-3 min |
| 4 | Checkpoint produced (delta or full) | MVAI / model_processing | <1 min |
| 5 | Publish to UMM (delta diff + register) | model_processing | <1-2 min |
| 6 | Hedwig delivery to predictor | SilverTorch / serving | <1 min |
| 7 | Predictor apply (Sigrid / Vanguard) | Vanguard / serving | <1 min |

Happy-path total: **~6-9 min**. A single stage doubling its budget breaks 10-min ATS.

## IG OT Pain Points (from Realtime Infra Review)

1. **Scribe Delay / Example Age Regression** — Data volume growth outpaces training QPS, causing 20-30 min scribe delay spikes during peaks. Reels ESR worst affected.
2. **QPS Degradation Over Long Uptime** — Training QPS drops ~10% after weeks without restart. Root cause unclear (memory fragmentation / resource leaks).
3. **Dashboard / Metrics Trust Gap** — ATS dashboard data sources inaccurate. Team auditing since Dec 2025.
