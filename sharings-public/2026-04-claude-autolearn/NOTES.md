# Online Training Knowledge Sharing — Reference Notes

Deep-dive reference notes for the MRS Training Infra PE team session on online training workflows. Organized by session section, with poll questions mapped to each section.

---

## Why This Session, Why Now

### Context

This session distills one month of OT ramp-up — building GPU E2E snapshot tests, decomposing ATS latency across 7 IG models, debugging delta publish failures hands-on — into the mental models PE needs for effective oncall triage, capacity planning, and reliability work.

**Why now**: We're building ATS SLOs for IG models for the first time. PE owns the reliability of a system most of us inherited without deep understanding. This gap shows up in oncall — slow triage, missed root causes, escalations that could have been self-served.

### The Business Case

Recommendation models are only as good as the data they've seen. A model trained on yesterday's data misses today's trends — a new viral Reel, a breaking news event, a seasonal shift in shopping behavior. The gap between "when an event happens" and "when the model reflects it" is called **Activity-to-Serve (ATS) latency**. Reducing ATS directly improves model quality (measured by Normalized Entropy, NE) and user engagement.

```
Model staleness vs NE improvement:

  12h → 1h ATS:     ~0.4% NE gain
   1h → 5min ATS:   ~0.15% NE gain

  At Meta's scale, each 0.1% NE = material revenue impact
```

### What You'll Walk Away With

1. **Mental model** of the full OT pipeline — enough to diagnose any failure in the chain
2. **The 5 failure modes** that cause 80% of OT incidents, ranked by blast radius
3. **A triage decision tree**: "something broke, where do I look?"
4. **Architectural intuition**: why this design, what tradeoffs were made, where the sharp edges are

### The Three Types of Delta — Quick Reference

Before diving into architecture, here's the mental model for the three delta types that enable low-latency model updates:

```
┌─────────────────────────────────────────────────────────────────┐
│                    FULL SNAPSHOT (baseline)                      │
│              Complete model: 1.5-2.7 TB, every 1-2h             │
│    All weights, all embeddings, all parameters                  │
└──────────┬──────────────────┬──────────────────┬────────────────┘
           │                  │                  │
           ▼                  ▼                  ▼
   ┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
   │ SPARSE DELTA │   │ DENSE DELTA  │   │ ITEM EMB DELTA   │
   │              │   │              │   │                  │
   │ Embedding    │   │ MLP layers,  │   │ Pre-computed     │
   │ table rows   │   │ attention,   │   │ item embeddings  │
   │ (hot rows)   │   │ normalization│   │ for ANN search   │
   │              │   │              │   │                  │
   │ 60-200 GB    │   │ 1-2 GB       │   │ Varies           │
   │ Every 3-5min │   │ Every 15-20m │   │ Every 3-5min     │
   │              │   │              │   │                  │
   │ → Hedwig     │   │ → Manifold   │   │ → Hedwig         │
   │   (streaming)│   │   (paced)    │   │   (streaming)    │
   └──────────────┘   └──────────────┘   └──────────────────┘
```

All deltas use **absolute values** (not relative diffs) — if one is lost, the next self-corrects. This design choice enables eventual consistency and simplifies failure recovery.

---

## Section 1: OT Architecture & Lifecycle (10 min)

**Covers**: Poll Q3 (How does Scribe work into OT? — 3 votes), Poll Q4 (Does OT always mean streaming? — 2 votes)

### 1.1 End-to-End OT Pipeline

Online Training is a continuous, streaming-based ML training approach where models are incrementally trained on real-time data from Scribe, rather than from batch sources like Hive. It is the final and most latency-sensitive step in model productionization: **Offline → Recurring → Online**.

| Aspect | Offline Training | Recurring Training | Online Training |
|---|---|---|---|
| Data Source | Hive (batch) | Hive (batch) | Scribe (streaming) |
| Lifetime | Until all data is read | Cron-scheduled (daily/hourly) | Forever, continuous |
| Scheduler | FBLearner on Bumblebee | FBLearner / MAST | MAST (PyPer) |
| Snapshot Frequency | Initial (v0) | Daily | Every 30-60 min |

**The data flow**:

```
┌──────────────────────────────────────────────────────────────────────┐
│                         DATA GENERATION                              │
│  User Action ──→ Events Infra ──→ Scribe (raw events)               │
│                                      │                               │
│  Feature Joining (AdTailer/AdLoggerStore/FeatureAgg/AdLoggerLite)    │
│       ──→ Data Forwarder ──→ Scribe Categories (also → Hive)        │
└──────────────────────────────────────┬───────────────────────────────┘
                                       │
                                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          TRAINING                                    │
│  DPP / Scribe Readers ──→ MAST-scheduled Trainer (continuous)       │
│                                │              │                      │
│                          Checkpoint      Model Weights               │
└──────────────────────────────┬───────────────┬───────────────────────┘
                               │               │
        ┌──────────────────────┘               │
        ▼                                      ▼
┌────────────────────┐             ┌───────────────────────────────────┐
│      STORAGE       │             │          PUBLISHING               │
│                    │             │                                   │
│ Manifold (blobs)   │◄────────────│ TGIF / GMPP (full snapshots)     │
│  • Checkpoints     │             │ DeltaPublisher (deltas)           │
│  • Full snapshots  │             │                                   │
│  • Delta artifacts │             │          ┌─────────────┐          │
│                    │             │          │ Hedwig (P2P) │          │
│ UMM (metadata)     │◄────────────│          │ (streaming)  │          │
│  • Version IDs     │             │          └──────┬──────┘          │
│  • Snapshot state  │             └──────────┬──────┼─────────────────┘
│  • Delta metadata  │                       │      │
│                    │                       │      │
│ Hive (batch data)  │                       ▼      ▼
│  • Training logs   │             ┌───────────────────────────────────┐
│  • Item pools      │             │           SERVING                 │
└────────────────────┘             │ IPNext (polls UMM every ~30s)     │
                                   │   ──→ Predictor (hot-swap model)  │
                                   │         ──→ User sees results     │
                                   └───────────────────────────────────┘
```

### 1.2 How Scribe Works Into OT

**Scribe** is Meta's distributed messaging system (~5 TB/s ingress, ~13.5 TB/s egress at peak). It is the primary real-time data transport for online training.

1. User events (impressions, clicks, conversions) are logged to Scribe categories by Events Infrastructure
2. Events flow through feature joining and labeling (Data Forwarder outputs labeled rows to specific Scribe categories)
3. Each model reads from a specific Scribe category (e.g., `mix_mimo_ig_5min_fix_hp1`)
4. The same data written to Scribe is also dumped to Hive tables — online and offline training use the same data, one reads streaming, the other reads batch

**Failure points in the data path**:

| Failure | SEV Evidence | Detection | Recovery |
|---|---|---|---|
| **Scribe quota exceeded** | S555616 (SEV2), S559678 (SEV2), S530581 | Scribe quota dashboard | Manual quota increase, no auto-scaling |
| **UDF bugs → NaN features** | S559940 (SEV3) | Not crashes — silent corruption. Manual bisect required | Manual rollback of DPP package |
| **DPP split gen bug** | S552593 (SEV3) | OT job unexpectedly COMPLETES (looks like success) | DPP fix + restart |
| **DPP release entangled** | S512573 (SEV3) | Jobs fail, but rollback blocked by entangled hotfix | 45+ hours manual investigation |
| **No Scribe checkpointing** | Design-level gap | Not detectable until restart | Data between last checkpoint and restart is permanently lost |

**Two reader technologies**:

| | Scribe Readers (Legacy) | DPP Readers (Newer) |
|---|---|---|
| Location | Co-located on trainer hosts | Standalone hosts (master + workers) |
| Correspondence | 1:1 with trainer | Any trainer can fetch from any worker |
| Privacy | No built-in enforcement | Built-in privacy checks |
| CPU impact | Higher trainer CPU | ~50% less trainer CPU |
| Init time | Earlier (less data loss on crash) | Later (more data-loss-vulnerable on crash) |

**DPP operational risk**: DPP changes are not tested against OT workloads (21% of SEVs). A bad DPP release has unbounded blast radius because DPP changes can't be selectively rolled back per model — they affect all OT jobs simultaneously.

### 1.3 Does OT Always Mean Streaming? No.

"Online Training" = training on streaming data from Scribe. But the mechanism for getting model updates to serving is a separate question with multiple modes:

| Update Mode | Transport | Latency | Used For |
|---|---|---|---|
| Out-of-place | Manifold → IPNext → TW restart | 1.5-2+ hours | Legacy models |
| Paced in-place | Manifold → Blob Distribution + Pacer | 10-30 min | Most production models |
| Paced delta | Manifold → Blob Distribution + Pacer | 10-30 min | Dense deltas |
| **Streamed delta** | **Hedwig (P2P streaming)** | **O(1-5 min)** | **Sparse + item deltas for freshness-critical models** |

**Key insight**: Many OT models use paced (non-streaming) updates. Streaming is an optimization for freshness-critical models (IG Reels ranking, high-value Ads models). A model can be "online trained" (reading from Scribe) but still use paced snapshot delivery.

### 1.4 Key Systems Overview

| System | Role |
|---|---|
| **MAST** | ML Application Scheduler on Tupperware. Schedules distributed training jobs (200K jobs/day, 225K GPUs). |
| **MRS** | Modern Recommendation Systems. Owns model architectures (HSTU), training frameworks (MVAI), publishing (TGIF). |
| **DPP** | Data PreProcessing Service. Fetches from Scribe/Hive, preprocesses, serves to trainers. Disaggregated from training. |
| **UMM** | Unified Model Management. Central metadata store for all snapshots/checkpoints. Single source of truth. |
| **Manifold** | Distributed blob storage (like S3). Stores model checkpoints, snapshots, and delta artifacts. |
| **TGIF** | Torch General Inference Flow. Transforms trained PyTorch models into inference-optimized formats (quantization, sharding, lowering). |
| **Hedwig** | P2P distribution and streaming platform (8 EB/day, 1400+ Tbps). Transport layer for real-time delta updates. |
| **ZCH** | Zero Collision Hashing. Maps sparse feature IDs to embedding rows without collisions. Critical for HSTU models. |
| **IPNext** | Inference Platform Next. Central control plane for model lifecycle, snapshot transitions, health checks. |
| **SilverTorch** | Service for retrieval model publishing. Handles full snapshot + item streaming for retrieval models. |

### 1.5 Retrieval vs Ranking Models

IG recommendation models fall into two fundamental categories that drive different OT publishing approaches:

```
Billions of items              Thousands                    Tens
      │                            │                          │
      ▼                            ▼                          ▼
┌─────────────┐            ┌──────────────┐           ┌────────────┐
│  RETRIEVAL  │ ────────→  │   RANKING    │ ───────→  │  User sees │
│             │            │              │           │  results   │
│ Two-tower:  │            │ Cross-feature│           └────────────┘
│ User embed  │            │ interaction: │
│   ·         │            │ User x Item  │
│ Item embed  │            │ features     │
│ (dot prod)  │            │ (neural net) │
│             │            │              │
│ ANN search  │            │ Real-time    │
│ Precomputed │            │ scoring      │
│ embeddings  │            │              │
└─────────────┘            └──────────────┘
Feed U2I, Reels T2I,       Feed LSR, Reels LSR,
Reels CS Omni               Reels ESR
```

| Aspect | Retrieval | Ranking |
|---|---|---|
| **Stage** | First (candidate generation) | Second (final ordering) |
| **Input size** | Billions of items | Thousands of candidates |
| **Output size** | Thousands | Tens |
| **Latency budget** | ~10ms for all candidates | ~10ms per batch |
| **Architecture** | Two-tower (user tower + item tower, dot product similarity) | Cross-feature interaction (user x item features through complex network) |
| **Optimization** | Recall (don't miss relevant items) | Precision / Business metrics (engagement, revenue) |
| **Inference** | Precomputed embeddings + ANN search | Real-time scoring |
| **Example models** | Feed U2I, Reels T2I, Reels CS Omni | Feed LSR, Reels LSR, Reels ESR |
| **OT code entry point** | `train.py` | `launch.py` |
| **Model family** | `IgReelsUMIAv1` | `IGRankingModelFamily` |
| **Training data** | Item pools, negative sampling | Request-level logs |
| **Delta config** | `--delta-only-publisher-config-fqn` | `--delta-publish-config-fqn` or via mixin |

**Key infra difference**: Retrieval models leverage item embedding deltas more heavily because they rely on precomputed item embeddings for ANN search. Ranking models care more about weight deltas (sparse + dense) since they compute scores in real-time.

**Item pools** (retrieval-only):
- **Item pool**: What items exist — loaded from Hive for negative sampling during training
- **User Interaction History (UIH) item pool**: What users watched — also from Hive, used for personalization

### 1.6 IG Model Architecture Patterns

From the IG OT Reliability Planning doc and OT learning notes, IG models fall into distinct patterns:

| Pattern | Models | OT Job Structure | Publisher |
|---|---|---|---|
| **Single OT job, no item streaming** | Feed LSR, Reels LSR | One job handles training + full snapshot + sparse/dense delta | TGIF/SilverTorch |
| **Single OT job with item streaming** | Reels ESR | One job: training + full snapshot + item streaming via memory layer + raw embedding streaming | In-trainer |
| **Collocated jobs** | Feed U2I, Reels T2I, Reels CS Omni | Full snapshot job + separate item streaming job, both producing artifacts for the same model ID | SilverTorch (STUS) |
| **SilverTorch service** | Reels ESR VM, Feed ESR | SilverTorch service handles item streaming + full snapshot publishing | SilverTorch service |

**Ranking models (LSR)** — single job does everything:
```
Scribe ──→ DPP ──→ MAST Trainer ──→ TGIFInTrainerPublisher
                        │                  │           │
                        │            FULL_SNAPSHOT  SPARSE_DELTA + DENSE_DELTA
                        │            (Manifold)    (Hedwig streaming)
                        │                  │           │
                        ▼                  ▼           ▼
                   Checkpoint ──→     UMM ──→ IPNext ──→ Predictor
```

**Retrieval models (ESR/U2I)** — hybrid: trainer + separate SilverTorch job:
```
Scribe ──→ DPP ──→ MAST Trainer ──→ DeltaOnlyPublisher (in-trainer)
                        │                  │                │
                        │            SPARSE_DELTA    ITEM_EMB_DELTA
                        │            (Hedwig)        (Hedwig)
                        ▼                  │                │
                   Checkpoint ──→ UMM      ▼                ▼
                        │          └───→ IPNext ──→ Predictor
                        ▼
              SilverTorch Update Service (separate job)
                        │
                  FULL_SNAPSHOT (Manifold) ──→ UMM ──→ IPNext
```

**Key nuance**: When SilverTorch generates a full snapshot, no item delta will be generated during that window. Collocated jobs (2 jobs for one model ID) were hacked in 2024 — need `managed_training_service` support for true parallel job support.

### 1.7 Publisher Architecture

The publishing system has a layered architecture. All in-trainer publishers inherit from a common base:

```
InTrainerPublisher (abstract base)
├── TGIFInTrainerPublisher        — Full snapshots via TGIF (most common)
│   ├── TGIFInTrainerPublisherAsync  — Async version with subprocess
│   └── SilverTorchInTrainerPublisher — Adds SilverTorch-specific handling
├── GMPPInTrainerPublisher        — Full snapshots via GMPP
└── DeltaOnlyPublisher            — Delta-only (no full snapshot)
    ├── WeightsDeltaPublisher      — Sparse + dense model weight deltas
    └── ItemDeltaPublisher         — Item embedding deltas
```

**Publisher config types** (both inherit from `DeltaPublisherConfigMixin`):

| Config Type | Used By | What It Does |
|---|---|---|
| `DeltaOnlyPublisherConfig` | ESR, UMIA models | Publishes only delta snapshots and checkpoints (no full model to predictor) |
| `TGIFPublisherConfig` | LSR | Publishes full TGIF model to predictor AND delta snapshots for embedding updates |

**SilverTorch vs TGIF publishing**:

| Aspect | SilverTorch Standalone | TGIF In-Trainer |
|---|---|---|
| Execution | Separate, periodic job | During the training process |
| Checkpoint source | UMM (pre-existing checkpoint) | Live training model |
| Bulk evaluation | Supported (runs on Hive data) | Not supported |
| Serving optimizations | Full (quantization, indices) | Basic |
| Primary use case | ESR production, retrieval | LSR, testing |

**Key insight**: ESR and retrieval models use a hybrid approach — delta updates are published in-trainer for low latency, while full snapshots are published by a separate SilverTorch job to avoid blocking training. LSR publishes both full snapshots and deltas from the same training job via TGIF.

### 1.8 OT Data Flow: Two Publishing Paths

OT data flows through two parallel paths from trainer to predictor:

```
Scribe (streaming data)
  → MVAI Online Trainer
      │
      ├── Training Side (in-trainer)
      │   └── DeltaOnlyPublisher
      │       ├── SPARSE_DELTA → Hedwig → Predictor
      │       └── DENSE_DELTA → Manifold → Predictor
      │
      └── Checkpoint (root model) → UMM
              │
              └── SilverTorch Update Service (STUS) [separate job]
                  ├── Model lowering (prune, quantize)
                  ├── FULL_SNAPSHOT → Manifold → Predictor
                  └── ITEM_EMBEDDING_DELTA → Hedwig → Predictor
```

**Publishing components summary**:

| Component | What It Publishes | Destination | Use Case |
|---|---|---|---|
| ItemDeltaPublisher | Item embeddings only | Hedwig → Predictor | Fresh item representations for new/trending items |
| WeightsDeltaPublisher | Sparse embeddings + dense weights | Hedwig/Manifold → Predictor | Full model weight updates between snapshots |
| GMPPInTrainerPublisher | Full snapshots via GMPP | Manifold → SilverTorch → Predictor | Complete model checkpoint publishing |
| TGIFInTrainerPublisher | Full snapshots + delta support | Manifold → SilverTorch → Predictor | Most common publisher with delta capability |

---

## Section 2: Snapshot Versioning & Recovery (10 min)

**Covers**: Poll Q1 (Resume OT from snapshot 1 — 4 votes, highest), Poll Q5 (Is UMM the SOT for delta snapshot versions? — 2 votes)

### 2.1 Snapshot Types

| Type | Contains | Size | Cadence | Purpose |
|---|---|---|---|---|
| **FULL_SNAPSHOT** | Complete model (all params) | 1.5-2.7 TB | Every 1-2 hours | Baseline for predictors. Reset point for delta chains. |
| **DENSE_DELTA** | Dense layers (MLP, attention, normalization) | 1-2 GB | Every 15-20 min | Keeps dense params fresh. Published as full tensor replacement (not relative diff). |
| **SPARSE_DELTA** | Subset of embedding table rows (top N% most changed) | 60-200 GB | Every 3-5 min | Embedding freshness. Uses optimizer momentum to select hot rows. Absolute values. |
| **ITEM_EMBEDDING_DELTA** | Pre-computed item embeddings | Varies | Every 3-5 min | Item embedding freshness. From STUS or in-trainer ItemDeltaPublisher. |

**Critical design choice**: All deltas use **absolute values**, not relative diffs. `[1, 2, 3, 4] + [_, _, 5, 3] = [1, 2, 5, 3]`. This enables eventual consistency — if a delta is lost, the next one self-corrects.

### 2.2 Version Chain Walkthrough

Full snapshots and deltas share a single, monotonically increasing version line in UMM:

```
Version 0:  FULL_SNAPSHOT    ← base
Version 1:  SPARSE_DELTA     ← delta on v0
Version 2:  DENSE_DELTA      ← delta on v0
Version 3:  SPARSE_DELTA     ← delta on v0
...
Version 11: FULL_SNAPSHOT    ← new base
Version 12: SPARSE_DELTA     ← delta on v11
Version 13: DENSE_DELTA      ← delta on v11
...
```

**Applying the poll example (1-a-b-c-2-d-e-3)**:

To reach version `e` (between full snapshots 2 and 3):
1. Load full snapshot 2
2. Apply deltas d, then e, in order

To reach version `c` (between full snapshots 1 and 2):
1. Load full snapshot 1
2. Apply deltas a, b, c in order

**Predictor scenarios**:
- **Cold start at version 15**: Load full snapshot 11, apply deltas 12-15
- **Running version 8, target 15**: Load full snapshot 11, apply deltas 12-15
- **Running version 13, target 15**: Only apply deltas 14-15
- **Rollback from version 17 to 15**: Load full snapshot 11, apply deltas 12-15

### 2.3 How OT Resumes — Watermark & Data Loss

When an OT job restarts (crash, preemption, or intentional restart):

**Model weights**: Resume from the **anchor checkpoint** linked to the latest valid snapshot. The checkpoint contains model weights, optimizer state, and training metadata. The system queries UMM for the latest valid snapshot, then loads the corresponding anchor checkpoint.

**Data cursor (the key gap)**: Currently, DPP for online training does **NOT** support Scribe checkpointing. Upon restart, the data cursor jumps to Scribe's "now". This means:
- Training data between the last checkpoint and restart time is **lost** (skipped)
- Maximum catch-up window in MVAI: ~2 hours
- Scribe retention: 3 days

**Impact**: A 5% data loss can significantly harm NE for key Ads models. A 50% data loss over 26 hours was estimated at ~$49K revenue impact (2021 SEV analysis).

**Mitigation strategies** (in progress):
1. Training Launch Service reads last Scribe watermark from UMM checkpoint metadata, converts to `start_time` for DPP
2. For extended outages (>2 hours): switch temporarily to recurring training with Hive data, then switch back
3. Watermark-checkpoint integration: design proposes embedding watermark state in the checkpoint itself

### 2.4 UMM as Source of Truth

**Yes, UMM is the source of truth for delta snapshot versions.**

**What UMM tracks (metadata)**:
- Model series ID and all version numbers
- SnapshotType (FULL_SNAPSHOT, DENSE_DELTA, SPARSE_DELTA, ITEM_EMBEDDING_DELTA)
- Model instance state (CREATING → VALID → INVALID)
- Delta metadata: `based_snapshot_id`, `file_metadata_list`, `validation_result`
- Training metadata: `trained_end_ts`, training stage
- Custom metadata (key-value pairs)

**What UMM does NOT store**:
- Actual model weights/artifacts (those live on **Manifold**)
- Training data or data cursors
- Runtime serving state

**Key property**: Snapshots in UMM are immutable with monotonically increasing version numbers. IPNext polls UMM every ~30 seconds to discover new snapshots.

**Tools**: `bunnylol ummmeta <model_entity_id>`, `bunnylol mlhub model <model_id>`, `trmgr`, `mvai online-training-mgr`

### 2.5 From the Trenches: UMM Snapshot Lifecycle for Delta Tests

(From snapshot-test-flakiness project)

Creating a UMM snapshot programmatically requires two steps:

1. **`gen_new_delta_version(model_entity_id, snapshot_type)`** — Creates instance in PENDING state
2. **`commit_model_instance(version, commit_info)`** — Transitions PENDING → VALID

**Common mistake**: Only calling `gen_new_delta_version` without `commit_model_instance`. The query in `assert_*_exists` filters by `model_instance_state=VALID`, so PENDING instances are invisible.

**Common mistake**: `commit_info` (a Thrift struct) MUST be converted with `._to_py_deprecated()` because `_update_metadata_on_commit` mutates `size_in_bytes`, which fails on immutable Thrift structs.

---

## Section 3: Delta Health & Validation (8 min)

**Covers**: Poll Q2 (How would we tell a delta snapshot is healthy? — 3 votes)

### 3.1 UMM Snapshot State Lifecycle

```
CREATING → VALID    (normal happy path)
CREATING → VALID → INVALID    (validation failure or manual ban)
```

States: `UNKNOWN(0)`, `CREATING(1)`, `VALID(2)`, `INVALID(3)`, `PURGED(4)`, `CREATED(5)`, `SOFT_DELETED(6)`

**Cascading invalidation**: If a full snapshot is marked INVALID, all delta snapshots based on it AND deltas leading to it from the previous full snapshot are also invalidated.

### 3.2 Validation Pipeline

| Validation Type | What It Checks | Latency |
|---|---|---|
| **Full Snapshot Validation (MSV)** | NE, Calibration, MSE, RMSE against thresholds (~1M samples) | ~40 minutes |
| **Delta Validation** | Health checks only: fallback rate, NaN check, serving errors >10% (~10k samples) | ~6 minutes |
| **IPNext Bake Time** | Continuous health during paced deployment; auto-revert on failure | Part of push |

Delta validation does NOT check prediction metrics (NE/Calibration). It performs sanity checks:
- Can the delta be loaded without crashing?
- Does the model return NaN or INF results?
- Is the fallback/error rate acceptable?

**Trend**: Delta validation through MSV is being phased out in favor of IP delta push bake time (less overhead, same coverage for critical issues).

### 3.3 Key Monitoring Dashboards

| Dashboard | Scuba Table | Purpose |
|---|---|---|
| MSV History | `snapshot_validator_job_status` | Validation results per model |
| Sparse Delta Streaming | `gmpp` | Publisher-side delta generation |
| Prod Tier Delta Metrics | `sigrid_model_manager` | Predictor-side delta loading |
| Hedwig Streaming Investigator | `hedwig_streaming_investigator` | P2P streaming health |
| Predictor Streaming Model Update | `predictor_streaming_model_update` | Updates applied on predictors |

### 3.4 Failure Modes Ranked by Impact

The failure modes below are ordered by blast radius, not frequency. This ranking is what matters for oncall prioritization.

| # | Failure | Blast Radius | Frequency | Self-Healing? |
|---|---------|-------------|-----------|---------------|
| 1 | **OT job crash + data loss** | Single model, permanent NE harm | Weekly per model | NO — data is lost forever |
| 2 | **Hedwig outage** | ALL streaming models simultaneously | Rare but catastrophic | Partially — paced path is fallback |
| 3 | **Delta publisher init failure** | Single model, 1h stale | Common (3 external deps) | YES — next init attempt may succeed |
| 4 | **commit_version (XDB lag)** | Single delta dropped | Common | YES — next delta self-corrects |
| 5 | **Weight incompatibility** | Single model rollback | Rare (arch changes) | NO — requires code fix |

**Correlated failure risk**: Hedwig P2P outage is the highest-severity scenario because it's not model-isolated. ALL streaming models — sparse deltas and item deltas for every IG model — go stale simultaneously. This is why paced delivery exists as a safety net, and why dense deltas are still paced rather than streamed.

**Detailed failure descriptions**:

**1. OT job crash + data loss**:
- When an OT job restarts, the data cursor jumps to Scribe's "now" — all data between last checkpoint and restart is lost
- No Scribe checkpointing for OT (see Section 2.3). This is the biggest reliability gap in the system
- A 5% data loss significantly harms NE for key models

**2. Hedwig outage**:
- Affects all models using streaming delivery simultaneously
- No single-model isolation — Hedwig is shared infrastructure
- Mitigated by absolute-value deltas (next delta after recovery self-corrects) and paced fallback for critical models

**3. Delta publisher init failure**:
- Delta publisher is a separate subprocess from trainer. It requires 3 external dependencies: FULL_SNAPSHOT in UMM, model_param_config from Manifold, and weight ID mappings
- If any dependency is unavailable, publisher crashes during initialization. Trainer continues but deltas stop
- From snapshot-test-flakiness: `WeightsDeltaPublisher` takes ~90-100s to initialize. Tests must account for this window

**4. commit_version failures (UMM)**:
- XDB replication lag: snapshot registered (CREATING) but commit to VALID happens within ~100ms, record not yet readable
- Error: `DeltaPublishRuntimeException: Failed to commit delta version ID 15235 to UMM ... ModelStoreDBRecordNotFound`
- Fix: retry with backoff (D76431882). Self-healing because next delta self-corrects

**5. Weight incompatibility**:
- `c10::Error: New weights are not compatible` — dense delta weight shapes don't match the full snapshot
- Happens when model architecture changed between training iterations
- Requires code fix — not self-healing

**Additional failure modes** (lower severity):

**ModelDeltaTracker not initialized** (from snapshot-test-flakiness project):
- ig_ranking tests use `SparseEmbeddingsSelectionMode.ID_ONLY`, which relies on TorchRec's `ModelDeltaTracker` to identify hot embedding rows
- If tracker is not initialized: all ~70+ embedding FQNs skipped with `Skipping fqn=<fqn> because it has no tracked status`
- Zero rows selected → zero chunks written → `commit_version` fails: "No chunks provided for commit of blob"
- This is primarily a test environment limitation (tracker initialized by MAST/Pyper in production)

**Manifold 404s**:
- Delta artifacts stored at paths like `ads_storage_fblearner/tree/user/facebook/fblearner/predictor/<model_id>/delta/`
- 404s when: artifacts garbage-collected, path incorrect, or write failures during publishing

### 3.5 Oncall Triage — 8 Failure Type Classification

The first step in any OT triage is **classify the failure type**, then investigate. This determines which data sources to query and dramatically reduces MTTR. 70% of failures fall into Types 1, 5, and 8.

| # | Failure Type | Key Signals | Priority Data Sources |
|---|-------------|-------------|----------------------|
| 1 | **Job crash / OOM** | CUDA OOM, segfault, exit code ≠ 0 | Job logs, `nvidia-smi`, GPU memory timeline |
| 2 | **Job stuck** | INITIALIZING > 30 min, no progress | Job logs, checkpoint availability, Manifold |
| 3 | **Training divergence** | NaN loss, loss spike, gradient explosion | Loss/gradient charts, recent config changes |
| 4 | **Latency regression (ATS)** | ATS > baseline, model staleness | SLICK SLIs, Hedwig publisher, artifact size |
| 5 | **Data pipeline issue** | Zero data, high filter ratio, stale data | DPP `dpp_operator_stats` (rows_in vs rows_out) |
| 6 | **Checkpoint failure** | Checkpoint save/load errors, Manifold 404 | Manifold logs, checkpoint producer job |
| 7 | **Infrastructure** | Host unreachable, network timeout, ZippyDB | Host status, network health, service deps |
| 8 | **Config / rollout** | Failure after config change or flag rollout | Recent diffs, feature flag timeline, config diff |

**Investigation steps per type**:

**Type 1 (Job crash / OOM)**:
1. Get job logs — look for the final error/exception
2. Check GPU memory: was it OOM? Which GPU? How much was requested vs available? (GPU 80GB limit, CPU ~190GB peak)
3. Check recent config changes: batch size, model size, sequence length changes?
4. Check if the job was running fine before — when did it start failing?

**Type 2 (Job stuck)**:
1. What state is the job in? (INITIALIZING, RUNNING but no progress)
2. If waiting on checkpoint: is the checkpoint available in Manifold?
3. If waiting on resources: check scheduler queue, GPU availability
4. Check dependency services: is everything the job needs up and running?

**Type 3 (Training divergence)**:
1. Pull loss curve — when exactly did it diverge?
2. Check gradient norm — explosion before NaN?
3. Correlate with timeline: config changes, feature flags, data changes in the 30 min before divergence
4. Check learning rate schedule and data distribution for anomalies

**Type 4 (Latency regression / ATS)**:
1. Query SLICK for the ATS SLI — current value vs baseline
2. Check Hedwig publisher — are publishes succeeding? What's the artifact size?
3. Check DPP pipeline — is data flowing? Any filtering anomalies?
4. Check model size — did it grow? New features or embedding tables?

**Type 5 (Data pipeline issue)**:
1. Query `dpp_operator_stats` in Scuba — rows_in vs rows_out for each operator
2. If high filtering: what's the filter expression? Is it correct?
3. Check data source freshness — is upstream data being produced?
4. Check for schema changes in input data

**Type 6 (Checkpoint failure)**:
1. Check Manifold for the checkpoint path — does it exist?
2. Check checkpoint producer job status
3. Look for disk space issues, Manifold quota, or write permission errors
4. Check if a corrupt checkpoint is propagating (S507549 pattern)

**Type 7 (Infrastructure)**:
1. Check host status — is the machine reachable?
2. Network health — any datacenter-level issues?
3. Service dependencies — ZippyDB, MAST scheduler, auth services
4. Cross-reference with ongoing infra incidents

**Type 8 (Config / rollout)**:
1. List recent config changes and feature flag changes (last 24 hours)
2. Correlate failure start time with change timestamps
3. Identify the specific change that matches the failure timeline
4. Check if reverting the change fixes the issue

### 3.5.1 Quick Triage Decision Tree

For faster routing, this decision tree narrows to the right failure type:

```
Alert fires
│
├── Is the OT job running?
│   ├── NO → Type 1 (crash) or Type 2 (stuck)
│   │   ├── Exit code present? → Type 1. Check OOM, segfault, code error
│   │   └── No exit, just not running? → Type 2. Check scheduler, Manifold
│   │
│   └── YES → Is training progressing?
│       ├── NO → Type 3 (divergence) or Type 5 (data pipeline)
│       │   ├── NaN/INF in loss? → Type 3. Check gradients, recent changes
│       │   └── Loss flat / no data? → Type 5. Check dpp_operator_stats
│       │
│       └── YES → Are deltas reaching predictors?
│           ├── Check UMM: new versions committed?
│           │   ├── NO → Type 6 (checkpoint) or Type 7 (infra)
│           │   └── YES → Type 4 (latency). Check delivery path:
│           │       ├── Streaming? → Hedwig health (3 Scuba tables)
│           │       └── Paced? → IPNext/ICSP Pacer UI
│           │
│           └── Did this start after a change? → Type 8 (config/rollout)
```

**Key tools**:
- `bunnylol ummmeta <model_entity_id>` — UMM snapshot state
- MAST job UI — job health, restarts, errors
- `nvidia-smi` — GPU memory and process status
- Scuba: `dpp_operator_stats` (data pipeline), `gmpp` (publisher), `hedwig_streaming_investigator` (transport), `predictor_streaming_model_update` (consumer)
- SLICK — SLI/SLO metrics for ATS
- ICSP Pacer UI — paced deployment progress

**Key principles**:
1. **Classify first, investigate second** — knowing the type focuses your queries
2. **Correlate with time** — most OT failures correlate with a recent change; find it
3. **Check the obvious first** — OOM, stale checkpoint, bad config cover 70% of failures
4. **Data over guessing** — always show the evidence that supports the diagnosis
5. **5-minute target** — if you can't diagnose in 5 minutes, escalate with what you've found

### 3.6 From the Trenches: Delta Publisher Dependencies

(From snapshot-test-flakiness L7)

The `WeightsDeltaPublisher` requires 3 external dependencies to initialize:
1. **A FULL_SNAPSHOT in UMM** — created by MAST publish steps
2. **model_param_config from Manifold** — created by inference predictor when loading a full snapshot
3. **Weight ID mappings** — derived from UMM + model_param_config

Without these, the delta publisher crashes during initialization. The delta publisher subprocess also takes ~90-100 seconds to initialize (L11). Tests must run enough training iterations to keep training alive past this init window.

---

## Section 4: Update Application & Item Delta Flow (10 min)

**Covers**: Poll Q6 (How is update actually applied — balancing inference vs training? — 1 vote), Poll Q8 (Item delta update flow — 1 vote)

### 4.1 How Updates Reach Predictors

**In-place snapshot transition**: Predictors hot-swap model weights without restarting the serving process. No traffic disruption, no cold-start latency, no extra capacity needed.

How it works per update type:
- **Sparse delta**: Selected embedding rows overwritten at their global indices in the existing table
- **Dense delta**: Full dense parameter tensors swapped (for AOTI models: `SwapConstantBuffer` on AOTInductor engine)
- **Item embedding delta**: `EmbeddingCache` updated with new item IDs and values (ZCH models use `ZCH_UPDATE_MODEL_OP_FUNC`)

### 4.2 IPNext Control Plane

1. **Polls UMM** every ~30 seconds for new snapshots (`get_last_n_snapshots`)
2. **Determines version to serve** based on validation results and configuration
3. **Orchestrates delivery**: paced updates via ICSP Pacer (staged rollout), streaming via Hedwig
4. **Monitors health**: triggers rollback on health check failure

Pacing policies: `NO_PACING`, `ALL_TASKS_AT_ONCE`, `ONE_THEN_THIRTY_FIVE_THEN_ALL` (1% → 35% → 100%)

### 4.3 Item Delta End-to-End Flow

```
Scribe (recently updated items)
    → ItemDeltaPublisher reads via AsyncDataReader
    → RankingBulkEvalLite runs GPU inference using CURRENT training model weights
    → Computes fresh item embeddings
    → ItemEmbTensorStreamingWriteClient publishes via Hedwig streaming
    → UMM registration (ITEM_EMBEDDING_DELTA snapshot type)
    → Predictor receives via Hedwig subscription
    → EmbeddingCache hot-patched in-place (no restart)
```

**Key advantage of in-trainer item delta**: Uses current training model weights (not a stale checkpoint). The older standalone `st_update_service` used an anchored checkpoint. In-trainer approach saved 23.8% OT capacity (40 GPU cards) by eliminating the standalone job.

**Key code**: `fbcode/minimal_viable_ai/core/item_delta_publisher/item_delta_publisher.py`

### 4.4 Item Delta vs Weight Delta

| Property | Item Delta | Sparse Weight Delta | Dense Weight Delta |
|---|---|---|---|
| What updates | Pre-computed item embeddings | Embedding table rows (user/item IDs) | MLP, attention, merge net |
| Source | Scribe (recently seen items) | Trainer optimizer momentum (hot rows) | Full copy of dense params |
| Computation | RankingBulkEvalLite GPU inference | CPU copy + row selection | CPU copy |
| Delivery | Hedwig streaming | Hedwig streaming OR Manifold paced | Manifold paced |
| Publisher class | `ItemDeltaPublisher` | `WeightsDeltaPublisher` | `WeightsDeltaPublisher` |

### 4.5 From the Trenches: Item Delta Challenges

(From snapshot-test-flakiness project)

**Mocking in subprocesses**: ESR's `IGRankingESRROOFeatureConfig` uses `ro_id_list_features` instead of `id_list_features`, causing `ItemDeltaPublisher.__init__` to crash with `AttributeError`. The fix is to mock `ItemDeltaPublisher` entirely in `invoke_launcher` (subprocess), then create the UMM snapshot in `validate_after_train` (main process). Side-effect-based mocks don't work in spawned subprocesses (`multiprocessing_method="spawn"`).

**Collocated jobs**: When full snapshot and item streaming are separate jobs for the same model ID, they were hacked to allow parallel execution in 2024. Need `managed_training_service` support for true parallel job handling.

---

## Section 5: Reliability — Streaming vs Batch (5 min)

**Covers**: Poll Q7 (Differences in reliability for streaming vs small batch? — 1 vote)

### 5.1 Streaming (Hedwig)

| Aspect | Detail |
|---|---|
| **Latency** | O(1-5 min). With flow control: sparse streaming reduced from 6 min to 3 min. |
| **Throughput** | Up to ~4.5 GB/s with dynamic flow control. |
| **Failure modes** | Message loss (buffer overflow), buffer OOM on large models, shard imbalance, paused during full snapshot transitions, root node churn. |
| **Debugging** | HIGH difficulty. Must correlate across `gmpp` (publisher), `hedwig_streaming_investigator` (P2P), `predictor_streaming_model_update` (consumer). No single end-to-end view. |
| **Self-healing** | Absolute-value deltas mean skipped messages auto-correct on next delta. |
| **Blast radius** | **CORRELATED** — a Hedwig outage affects ALL streaming models simultaneously. This is not model-isolated. Sparse deltas + item deltas for every IG model go stale at once. |

**Streaming failure diagnostics** (from ot-debug skill):

| Symptom | Likely Cause | Investigation |
|---|---|---|
| ATS spike across multiple models | Hedwig infrastructure issue | Check Hedwig oncall, `hedwig_streaming_investigator` for global errors |
| ATS spike for single model | Publisher subprocess crashed | Check if delta publisher is alive, check init dependencies |
| Deltas in UMM but not on predictors | Hedwig transport failure | Correlate `gmpp` (published) → `hedwig_streaming_investigator` (transported?) → `predictor_streaming_model_update` (applied?) |
| Intermittent delta gaps | Buffer overflow / msg loss | Check Hedwig buffer OOM, shard imbalance. Self-heals with next delta |
| Streaming paused | Full snapshot transition in progress | Expected behavior during TGIF/SilverTorch publish. Resumes after |

### 5.2 Paced/Batch (Manifold + IPNext)

| Aspect | Detail |
|---|---|
| **Latency** | O(10-30 min). 3-phase push with 5-min bake: ~20 minutes total. |
| **Observability** | GOOD. ICSP UI shows deployment state machine. Pacer UI shows release progress. |
| **Rollback** | Strong. IPNext auto-reverts on health check failure. Only 10% of tasks affected in 2-phase mode. |
| **Failure modes** | Timeout on large models (default ~35 min), Manifold download failures (mitigated by Hedwig P2P caching), weight incompatibility. |

### 5.3 When to Use Which

| Use Case | Approach | Rationale |
|---|---|---|
| Sparse deltas (large tables) | Streaming | Lowest latency; too large for frequent paced delivery |
| Item embedding deltas | Streaming | Real-time content discovery needs sub-minute freshness |
| Dense deltas | Paced | Small size, benefits from validation before deployment |
| Full snapshots | Paced | Too large to stream; needs validation + staged rollout |
| New model launches | Start paced, enable streaming after validation | Reduce risk during initial deployment |

### 5.4 Business Impact

Delta publishing reduced Activity-to-Serving (ATS) latency from **~12 hours → ~30 minutes** (paced deltas) and further to **O(minutes)** (streaming). NE gain: ~0.4% from 8 hours to 1 hour ATS, ~0.15% from 60 minutes to 5 minutes.

### 5.5 From the Trenches: Shutdown & Reliability Lessons

(From snapshot-test-flakiness project)

**os._exit() required for clean shutdown** (L3): Delta publisher's worker thread blocks in unbounded `message_queue.get()`. When training ends, atexit handlers try to join ThreadPoolExecutor threads but worker is stuck. Additionally, MTIA library's static destructor triggers CHECK failure on non-MTIA GPU hosts. Fix: `os._exit()` bypasses atexit handlers and C++ destructors.

**DeltaPublishTestTrainer guards** (L4): Without shutdown guards, `RankingTrainer.shutdown()` hangs indefinitely waiting for the delta publisher subprocess. Two patterns exist: force-terminate (push `None` to unblock queue) or wait-with-timeout (nullify publisher if not ready).

**Delta publisher subprocess takes ~90-100s to initialize** (L11): Tests must run enough training iterations to keep training alive past this window. If training finishes before the subprocess initializes, no deltas are published.

---

## Current IG OT SLO Context

From the IG OT Reliability Planning doc (2026-02-12):

### Model Freshness SLI

| Metric | Criteria | Target |
|---|---|---|
| Sparse streaming latency (hourly P90) | ≤ 10 minutes | 95% hours in a week |
| Item embedding latency (hourly P90) | ≤ 10 minutes | 95% hours in a week |
| Streaming success rate (hourly avg) | ≥ 99% | 95% hours in a week |

### Current State (Retrieval Models)

| Model | Sparse Latency (P90) | Sparse Success | Item Latency (P90) | Item Success | Key Issue |
|---|---|---|---|---|---|
| Feed U2I | 4 min | 100% | 25 min | 100% | Scribe delay + inference > 10 min |
| Reels T2I | 3 min | 100% | Not stable | Pending | Pending launch |
| Reels CS Omni | 2 min | 100% | 25 min | 100% | High scribe delay |
| Reels OmniUV | 3 min (not stable) | >95% (not stable) | 50 min | 100% | High scribe delay |

### Current State (ESR + LSR Models)

| Model | Sparse Latency (P90) | Sparse Success | Item Latency | Item Success | Key Issue |
|---|---|---|---|---|---|
| Feed LSR | 8 min | 98% | / | / | |
| Reels ESR | 30 min | Not stable | Pending | Pending | High scribe delay variation |
| Reels LSR | 30 min | Not stable | 97% (not stable) | / | Scribe delay |

### MGS (Model Generation Stability) — Current MRS Metric

**Definition**: At any sampled time point, can MRS ML Infra produce a fresh model snapshot within the expected publish cycle?

**Relationship to ATS**: MGS covers T1 (most of it) + T2 (training) + T3 (publishing). It is necessary but not sufficient for ATS — scribe delays in T1 and T4 (streaming to serving) are not captured.

### Capability Gaps (Red/Yellow)

| Team | Yellow (Best effort) | Red (Cannot commit without major changes) |
|---|---|---|
| MVAI | Address issues in structured trainer and WeightsDeltaPublisher | N/A |
| SilverTorch | | No item delta during full snapshot generation |
| Hedwig | Cover streaming reliability (message loss, latency) | SLO only guaranteed with training package patches for new fixes |
| PE | Eliminating ephemeral fbpkgs; reducing user config errors | No committed support for QE/Holdout models; OT reads from Scribe without purchased Hive storage |

---

## Section 6: Operational Challenges — What the SEVs Tell Us

Source: [OT SEV Study](https://docs.google.com/document/d/1N--uN6he5L_elurqBC3IcOonBAMEIX3olVB3oRmxaK4/) — systematic analysis of 19 OT SEVs over 6 months (H2 2025), plus extended analysis of 42+ SEVs from Jan 2025 - Feb 2026.

### 6.1 SEV Distribution

Over 6 months, 19 confirmed OT SEVs were identified across 6 root cause categories:

| # | Category | Count | % | Trend |
|---|----------|-------|---|-------|
| 1 | Quota / Admission Control | 7 | 37% | Increasing — spike in Aug 2025 |
| 2 | DPP / Data Pipeline | 4 | 21% | Stable |
| 3 | Infrastructure / Configuration | 3 | 16% | Stable |
| 4 | Job State Management | 3 | 16% | Emerging in H2 2025 (0 in H1) |
| 5 | Publishing Failures | 2 | 11% | Active |
| 6 | Resource / Capacity | 2 | 11% | Stable |

**By product group**: IG accounts for 42% of SEVs (8), followed by Multi-PG at 37% (7). IG has ~4x more SEVs than any single-surface PG — driven by a larger OT model fleet competing for shared Scribe quota.

**Cross-team ownership**: 40% of OT SEVs are owned by teams other than MRS Online Training. Tag-only search approaches miss ~40% of OT SEVs — multi-source triangulation required.

### 6.2 Top Operational Pain Points

**Pain Point 1: Scribe Quota Is the Single Biggest OT Reliability Threat**

9 SEVs (21% of all OT SEVs), including both SEV-2s. OT growth outpaces Scribe provisioning.

| SEV | Severity | What Happened |
|---|---|---|
| S555616 | SEV2 | FB/MRS OT Scribe quota exceeded → all OT jobs affected |
| S559678 | SEV2 | IG OT preemptions → Scribe thrash → 1K+ preemptions |
| S530581 | SEV3 | Global Scribe capacity hit 97% of 30 TB/s |
| S585965 | SEV3 | Conveyor blocked by Scribe quota → model releases stalled |

Pattern: Jobs start without guaranteed resources → preemption cascades → model staleness. No admission control checks GPU + Scribe + machine type BEFORE job start. No automated scaling, no cross-PG isolation.

**Pain Point 2: DPP Is a Fragile, Tightly-Coupled Dependency**

8 SEVs (19%). Bad DPP releases have outsized blast radius because DPP changes can't be selectively rolled back.

| SEV | Severity | What Happened |
|---|---|---|
| S552593 | SEV3 | DPP split generation bug → OT jobs unexpectedly COMPLETE |
| S559940 | SEV3 | UDF bug in DPP package → NaN errors (not crashes) → manual bisect required |
| S512573 | SEV3 | DPP release code bug → couldn't rollback (hotfix entangled) → 45+ hours |
| S587954 | SEV3 | DPP flag rollout → PES traffic spike → 259 sessions failed |

Pattern: DPP changes not tested against OT workloads → silent failures or crashes. UDF bugs cause NaN (wrong answers, not crashes) — the hardest type of failure to detect.

**Pain Point 3: Publishing Is Fragile and Errors Are Generic**

8 SEVs (19%). Generic error messages, fixed timeouts, corrupt checkpoints.

| SEV | Severity | What Happened |
|---|---|---|
| S507549 | SEV1 | ads_token_service throttling → 99%+ publishing jobs failed |
| S613560 | SEV3 | Fleet-avg streaming success 96% masked 11 models below 90% |
| S552736 | SEV3 | TGIF publisher stuck during coordinated publish |
| S537257 | SEV3 | Lowering duration exceeded publish timeout (nondeterministic) |

Pattern: Per-model publishing SLOs don't exist. Fleet averages hide individual model failures — S613560 showed fleet at 96% while 11/61 models were below 90%.

### 6.3 Why OT Is Operationally Harder Than Recurring Training

| Dimension | Recurring Training | Online Training |
|---|---|---|
| Lifetime | Finite (until data exhausted) | Forever (continuous) |
| Failure tolerance | Retry/rerun next cycle | Every minute of downtime = stale models in prod |
| Dependencies | Hive (batch, stable) | Scribe + DPP + Hedwig + MAST + TMS (all real-time) |
| Publish modes | FULL_SNAPSHOT only | FULL + SPARSE_DELTA + DENSE_DELTA + streaming |
| Cost multiplier | 1x | 2.3-2.6x |
| Error pattern | Crash → retry → succeed | Silent degradation → fleet avg masks it → discovered days later |

### 6.4 Cross-Cutting Themes From 42+ SEVs

1. **Blast radius is unbounded** — a single bad DPP release or auth failure affects hundreds of jobs simultaneously
2. **Errors are non-retryable when they should be transient** — permission/auth errors kill jobs permanently instead of retry-with-backoff
3. **Fleet averages mask individual failures** — per-model monitoring doesn't exist; problems hide behind "healthy" fleet averages
4. **Error messages are generic** — root cause analysis requires deep manual investigation ("Async publish process creation failed!" tells you nothing)
5. **Recovery is manual and slow** — restores, republishing, and bulk restarts all require human intervention

### 6.5 High-Leverage Opportunities (from SEV analysis)

| Priority | Opportunity | Evidence | Expected Impact |
|---|---|---|---|
| P0 | Admission Control Enforcement | 37% of SEVs + both SEV-2s are quota-related | Prevent 7 SEVs, eliminate SEV-2 risk |
| P0 | Per-Model Publishing SLOs | S613560: fleet avg masked 11 failing models | Early detection of publishing failures |
| P1 | DPP OT-Aware Validation | 4 SEVs from DPP changes without OT testing | Prevent DPP-induced OT failures |
| P1 | Cross-Team SEV Visibility | 40% of SEVs not tagged mvai-online-training | Faster triage, complete SEV tracking |
| P2 | Job State Transition Alerts | 3 emerging job state SEVs in H2 2025 | Catch stuck/terminated jobs early |
| P2 | OT-Aware Infra Rollout Canaries | 3 SEVs from infra changes without OT validation | Prevent infra-induced OT failures |

**Impact projection**: P0 only → ~45% SEV reduction | P0+P1 → ~70% | All → ~85%

### 6.6 Observability Gap Details (from codebase analysis)

The OT SEV study also included a deep codebase analysis (18 parallel research agents, 15 iterative rounds) that found:

- **1 ODS metric** across 2,000+ lines of delta publishing code — the entire pipeline has exactly one metric
- **47 logger.error() calls** in the publishing path, but **zero** emit ODS counters — errors are logged to files but never surfaced to dashboards
- **7 stages in the E2E pipeline, timestamps at only 2** — no distributed tracing, no request/trace ID propagation
- **Multiple dist.all_gather_object() calls with no timeout** — distributed operations can hang indefinitely
- **Fleet metrics mask individual model failures** — the system's reliability measurement is fundamentally flawed

### 6.7 Tier-1 Support Cost (Q4 2025)

- 16 Tier-1 OT models
- Total engineering hours: 546.8 (1.95 HC)
  - SEV support: 480.8 hrs (87.9%) — 6 Tier-1 SEVs
  - User support: 66 hrs (12.1%) — 66 Workplace posts (~1 hr/post avg)
- Cost per model: ~0.13 HC per half for operational support

---

## Architectural Tradeoffs — Why This Design?

Understanding the "why" behind the architecture is as important as understanding the "what." These design decisions shape the system's failure modes and operational characteristics.

| Decision | Alternative Considered | Why We Chose This |
|---|---|---|
| **Absolute-value deltas** | Relative diffs (smaller payload) | Eventual consistency — if a message is lost, the next delta self-corrects. No ordering dependency between deltas. Dramatically simplifies failure recovery. |
| **Separate delta publisher subprocess** | In-process publishing thread | Fault isolation — publisher crash doesn't kill training. Training continues producing checkpoints even if delta publishing fails. Subprocess can be restarted independently. |
| **UMM as metadata-only SOT** | UMM stores artifacts too | Separation of concerns at scale. Manifold is optimized for blob storage (TB-scale artifacts). UMM is optimized for metadata queries (version lookups, state transitions). Coupling them would create a single point of failure. |
| **Hedwig P2P for streaming** | Direct trainer→predictor push | P2P scales to thousands of predictors without trainer becoming a bottleneck. Hedwig handles 8 EB/day, 1400+ Tbps. Direct push would require O(predictors) connections from trainer. |
| **DeltaOnly + SilverTorch hybrid** | Single job for everything | Full snapshot generation (TGIF lowering, quantization, sharding) takes 10-40 minutes and is CPU/memory intensive. Running it in the trainer blocks training. Separate SilverTorch job decouples the two. |
| **Paced rollout (1%→35%→100%)** | All-at-once push | Limits blast radius. If a bad delta passes validation, only 1% of traffic sees it before health checks trigger rollback. |

**Fundamental architectural tension**: Latency vs safety. Every optimization for freshness (streaming, skip validation, wider delta windows) reduces safety margins. The system is tuned per model based on business criticality — high-value Ads models get more safety checks, while freshness-critical Reels models accept more risk for lower latency.

---

## Systemic Gaps & Opportunities

### Current Gaps (where we're exposed)

1. **No Scribe checkpointing for OT** — Data loss on every OT restart. OT jobs restart roughly weekly per model (preemption, code pushes, infrastructure issues). Each restart loses all training data between the last checkpoint and restart time. At scale across ~10 IG models, this means data loss events multiple times per week. The watermark-checkpoint integration is in design phase but not yet implemented. This is the single biggest reliability gap — and the single biggest potential NE improvement available.
2. **No item delta during full snapshot generation** — SilverTorch limitation creates freshness holes every 1-2 hours for every retrieval model. During full snapshot generation (10-40 minutes), item embeddings go stale. This is a periodic, predictable freshness regression.
3. **No sparse user embedding delta** — Only item embeddings get streamed via ItemDeltaPublisher. User embeddings wait for the next full snapshot (1-2 hours). This means the user tower in retrieval models is always 1-2 hours stale.
4. **Config sprawl** — Too many control surfaces for the same behaviors: throttling, disable preloading, trainer config, publisher config, model config, CLI arguments. Multiple ways to do the same thing (TGIF vs GMPP). This causes user configuration errors and makes debugging harder. When oncall gets a config-related page, determining which of 6+ config surfaces to check is itself a triage problem.
5. **Streaming observability gap** — No single E2E view from trainer publish → Hedwig transport → predictor apply. Debugging requires correlating 3+ Scuba tables manually (`gmpp`, `hedwig_streaming_investigator`, `predictor_streaming_model_update`). This is the #1 source of slow triage on oncall.
6. **MGS metric incompleteness** — MGS (Model Generation Stability) doesn't capture Scribe delays (T1) or streaming-to-serving latency (T4). It is necessary but not sufficient for ATS SLOs. We're building new SLIs to cover the full pipeline.

### Forward-Looking Opportunities

- **Watermark-checkpoint integration**: Eliminate data loss on restart — potentially the biggest NE improvement available in the OT reliability space
- **Unified publisher config**: Reduce control surfaces from 6+ to 1-2 canonical configs per model type
- **E2E streaming observability**: Single dashboard from trainer publish → Hedwig → predictor apply, with latency breakdown per hop
- **Streaming by default for all delta types**: Dense deltas are still paced — streaming them would further reduce ATS
- **Managed training service**: True parallel job support for collocated training + publishing jobs, replacing the 2024 hack

---

## Common Confusions Clarified

| Confusion | Clarification |
|---|---|
| "Delta" vs "Full" | Delta = incremental changes only. Full = complete model snapshot. Deltas are applied on top of a base full snapshot. |
| "Item Publish" vs "Weight Publish" | Two types of delta publishing: Item publish handles item embeddings only; Weight publish handles all model weights (sparse + dense). |
| "Sparse" vs "Dense" deltas | Sparse = embedding table rows (user/item IDs). Dense = MLP layers, attention weights. Sparse deltas publish a percentage of changed rows; dense deltas publish full tensors. |
| "Training Side" vs "Item Side" Streaming | Training side = deltas from trainer (sparse params). Item side = deltas from STUS (item embeddings). Both use Hedwig but originate from different sources. |
| "In-Trainer" vs "Two-Step" | In-Trainer = publish directly from the trainer process. Two-Step = trainer writes checkpoint, STUS reads and publishes. |
| "TGIF" vs "GMPP" | TGIF: Standard choice for most models, simpler setup, full model snapshots. GMPP: When you need delta publishing for OT with large embedding tables that change frequently. |
| "DeltaOnlyPublisher" vs "TGIFInTrainerPublisher" | DeltaOnly publishes weight deltas without full snapshots (ESR, UMIA). TGIF publishes both full snapshots and deltas (LSR). |

---

## References

### Internal Wikis
- [Online Training Architecture](https://www.internalfb.com/wiki/Users/shakeeb/TDI/Online-Training-Architecture/)
- [Model Publishing Comprehensive Guide](https://www.internalfb.com/wiki/MRS_Serving/Experimental/Model_Publishing_for_ML_Inference_at_Meta_%E2%80%94_A_Comprehensive_Guide/)
- [Delta Publish Overview](https://www.internalfb.com/wiki/Real-TimePublishing/Delta_Publish_Overview/)
- [IPNext Streaming Guide](https://www.internalfb.com/wiki/Inference/Inference%3A_Internal/IP_Next%3A_Internal/Snapshot_Transition/Streaming/IPnext_Streaming_Guide/)
- [Scribe Readers vs DPP Readers](https://www.internalfb.com/wiki/Ads_Production_Model_Training_Home_Page/Knowledge_Docs/Online_Training_Knowledge_Sharing_Series/Scribe_Readers_vs_DPP_Readers/)
- [Delta Troubleshooting Tutorial](https://www.internalfb.com/wiki/ML_Freshness/Model_Freshness/Delta_Update:_Troubleshooting_Tutorial_for_Production_Models/)
- [UMM User Guide](https://www.internalfb.com/wiki/AIMetadata/UMM_Overview/UMM_User_Guide/)

### Key Code Paths

**Publisher base classes**:
- `fbcode/minimal_viable_ai/core/publisher/publisher.py` — InTrainerPublisher (abstract base)
- `fbcode/minimal_viable_ai/core/publisher/publisher_config.py` — PublisherConfig
- `fbcode/minimal_viable_ai/core/publisher/delta_publisher_config_mixin.py` — DeltaPublisherConfigMixin

**Delta publishers**:
- `fbcode/minimal_viable_ai/core/item_delta_publisher/item_delta_publisher.py` — ItemDeltaPublisher
- `fbcode/minimal_viable_ai/core/item_delta_publisher/item_delta_publisher_config.py` — ItemDeltaPublisherConfig
- `fbcode/minimal_viable_ai/core/item_delta_publisher/item_delta_update_task_handler.py` — Subprocess handler for Hedwig streaming
- `fbcode/minimal_viable_ai/core/model_weights_delta_publisher/weights_delta_publisher.py` — WeightsDeltaPublisher
- `fbcode/minimal_viable_ai/core/model_weights_delta_publisher/weights_delta_publisher_config.py` — WeightsDeltaPublisherConfig
- `fbcode/minimal_viable_ai/core/publisher/delta_only_publisher.py` — DeltaOnlyPublisher

**Full snapshot publishers**:
- `fbcode/minimal_viable_ai/core/ranking_common/tgif_publisher.py` — TGIFInTrainerPublisher + async version
- `fbcode/minimal_viable_ai/core/ranking_common/gmpp_in_trainer_publisher.py` — GMPPInTrainerPublisher

**Streaming and infrastructure**:
- `fbcode/aiplatform/gmpp/delta_publish/streaming/clients/` — ItemEmbTensorStreamingWriteClient (Hedwig)
- `fbcode/silvertorch/experimental/st_update_service/delta_update_utils.py` — SilverTorch Hedwig utilities
- `fbcode/aiplatform/modelstore/umm/if/model_metadata.thrift` — UMM SnapshotType enum

**Production configs**:
- `fbcode/minimal_viable_ai/models/ig_ranking/esr/ig_reels_tab_esr_ttsn/prod/run_config.py` — IG Reels ESR prod
- `fbcode/minimal_viable_ai/models/ig_ranking/lsr/ig_reels_tab_mtml/prod/run_config.py` — IG Reels LSR prod

### Project References
- [IG OT Reliability Planning](https://docs.google.com/document/d/1qf33fN0AsdIYRPViXV-lulFhlr1gipkAFwajiQvQgRk/) — Source for SLO targets and current state
- [Workplace Poll](https://fb.workplace.com/groups/1298528517372911/posts/2019640618595027) — Team questions
- `projects/snapshot-test-flakiness/SUMMARY.md` — Hands-on learnings from GPU E2E test development
