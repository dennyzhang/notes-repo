# Online Training Knowledge Sharing — Slide Deck

**Audience**: MRS Training Infra PE Team
**Duration**: 45 minutes
**Speaker**: Denny Zhang

---

## Slide 1: Title

**Online Training: How It Actually Works**

_Deep-dive knowledge sharing for the PE team_

Denny Zhang | MRS Training Infra Reliability
February 2026

---

## Slide 2: Why This Session, Why Now

**Context**: I've spent the last month ramping on OT — building GPU E2E snapshot tests, decomposing ATS latency, debugging delta publish failures. This session distills what I learned into the mental models PE needs for effective oncall triage, capacity planning, and reliability work.

**Why now**: We're building ATS SLOs for IG models for the first time. PE owns the reliability of a system most of us inherited without deep understanding. This gap shows up in oncall — slow triage, missed root causes, escalations that could have been self-served.

**The business case for understanding OT**:
```
Model staleness directly impacts engagement and revenue:

  12h → 1h ATS:    ~0.4% NE gain
   1h → 5min ATS:  ~0.15% NE gain

  At Meta's scale, each 0.1% NE = material revenue impact
```

**What you'll walk away with**:
1. Mental model of the full OT pipeline — enough to diagnose any failure in the chain
2. The 5 failure modes that cause 80% of OT incidents
3. A triage decision tree: "something broke, where do I look?"

---

## Slide 3: The Three Types of Delta — Quick Intro

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

All deltas use **absolute values** (not relative diffs) — if one is lost, the next self-corrects.

---

## Slide 4: Agenda

| # | Topic | Time |
|---|-------|------|
| 1 | OT Architecture & Lifecycle | 8 min |
| 2 | Snapshot Versioning & Recovery | 8 min |
| 3 | Delta Health, Failures & Triage | 8 min |
| 4 | Update Application & Item Delta Flow | 5 min |
| 5 | Streaming vs Batch Reliability | 4 min |
| 6 | Operational Challenges (SEV data) | 7 min |
| | Q&A | 5 min |

_Questions covered: all 8 from the Workplace poll, plus operational guidance_

---

## Slide 5: What Is Online Training?

```
         Offline              Recurring              Online
      ┌───────────┐        ┌───────────┐        ┌───────────────┐
      │ Hive data │        │ Hive data │        │ Scribe stream │
      │ (batch)   │        │ (batch)   │        │ (real-time)   │
      └─────┬─────┘        └─────┬─────┘        └──────┬────────┘
            │                    │                      │
            ▼                    ▼                      ▼
      ┌───────────┐        ┌───────────┐        ┌───────────────┐
      │ FBLearner │        │ FBL/MAST  │        │ MAST (PyPer)  │
      │ one-shot  │        │ cron jobs │        │ runs FOREVER  │
      └─────┬─────┘        └─────┬─────┘        └──────┬────────┘
            │                    │                      │
            ▼                    ▼                      ▼
       v0 snapshot          Daily snapshots       Every 30-60 min
                                                  + deltas every 3-5 min
```

Online Training = the most latency-sensitive step in model productionization

---

## Slide 6: End-to-End Pipeline — With Failure Points

```
┌────────────────────────────────────────────────────────────────────────┐
│ T1: DATA GENERATION                                                    │
│                                                                        │
│ User Action ──→ Events Infra ──→ Scribe (raw events)                  │
│                                      │                                 │
│ Feature Joining ──→ Data Forwarder ──→ Scribe Categories              │
│  (AdTailer/FeatureAgg/                   │           (also → Hive)     │
│   AdLoggerStore/AdLoggerLite)            │                             │
│                                          │                             │
│  ⚠ FAIL: Scribe quota exceeded (37% of SEVs)                         │
│  ⚠ FAIL: UDF bugs → NaN features (silent corruption)                 │
│  ⚠ FAIL: No Scribe checkpointing → data loss on restart              │
│  📊 Monitor: Scribe quota dashboard, dpp_operator_stats (Scuba)       │
└──────────────────────────────────────┬─────────────────────────────────┘
                                       │
                                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ T2: TRAINING                                                           │
│                                                                        │
│ DPP Readers ──→ MAST-scheduled Trainer (runs FOREVER)                 │
│  (standalone      │              │               │                     │
│   hosts)          │         Checkpoint      Model Weights              │
│                   │         (Manifold)      (in-memory)                │
│                   │                                                    │
│  ⚠ FAIL: DPP split gen bug → job COMPLETES unexpectedly              │
│  ⚠ FAIL: OOM (GPU 80GB limit, CPU ~190GB peak)                       │
│  ⚠ FAIL: Job stuck in INITIALIZING (checkpoint load, Manifold 404)   │
│  ⚠ FAIL: Training divergence (NaN loss, gradient explosion)          │
│  ⚠ FAIL: NCCL timeout (distributed training, network)                │
│  📊 Monitor: MAST job UI, loss/gradient charts, nvidia-smi            │
└──────────────────────────┬──────────────────┬──────────────────────────┘
                           │                  │
        ┌──────────────────┘                  │
        ▼                                     ▼
┌────────────────────┐          ┌─────────────────────────────────────────┐
│ STORAGE            │          │ T3: PUBLISHING                           │
│                    │          │                                          │
│ Manifold (blobs)   │◄─────── │ TGIF / GMPP ─→ FULL_SNAPSHOT            │
│  • Checkpoints     │          │   (10-40 min, blocks trainer if sync)   │
│  • Full snapshots  │          │                                          │
│  • Delta artifacts │          │ DeltaPublisher subprocess                │
│  (TB-scale)        │          │   ├─ WeightsDeltaPublisher              │
│                    │          │   │   ├─ SPARSE → Hedwig (60-200 GB)    │
│ UMM (metadata)     │◄─────── │   │   └─ DENSE → Manifold (1-2 GB)     │
│  • Version IDs     │          │   └─ ItemDeltaPublisher                  │
│  • Snapshot state  │          │       └─ ITEM_EMB → Hedwig (varies)     │
│  • Delta metadata  │          │                                          │
│  (1 ODS metric     │          │  ⚠ FAIL: Publisher init (3 deps, ~90s) │
│   across 2000+     │          │  ⚠ FAIL: commit_version (XDB lag)      │
│   lines of code)   │          │  ⚠ FAIL: TGIF timeout (nondeterministic│
│                    │          │  ⚠ FAIL: ads_token_service throttle    │
│ Hive (batch data)  │          │  ⚠ FAIL: Corrupt checkpoint propagation│
│  • Training logs   │          │  📊 Monitor: gmpp (Scuba) — BUT only   │
│  • Item pools      │          │     1 ODS metric, 47 errors logged      │
└────────────────────┘          │     with 0 emitting metrics             │
                                └────────┬──────────┬─────────────────────┘
                                         │          │
                                         ▼          ▼
┌────────────────────────────────────────────────────────────────────────┐
│ T4: SERVING                                                            │
│                                                                        │
│ IPNext (polls UMM ~30s) ──→ Predictor (hot-swap in-place)             │
│   │                              │                                     │
│   ├─ Paced: Manifold → Pacer    │  Sparse: overwrite embedding rows   │
│   │   1% → 35% → 100%          │  Dense: SwapConstantBuffer           │
│   │   (bake 5 min each phase)   │  Item: EmbeddingCache hot-patch     │
│   │                              │                                     │
│   └─ Streaming: Hedwig P2P     │  No restart. No traffic disruption.  │
│       (msg loss possible)       │                                     │
│                                                                        │
│  ⚠ FAIL: Weight incompatibility (arch change between iterations)      │
│  ⚠ FAIL: Hedwig msg loss / OOM (correlated across ALL models)         │
│  ⚠ FAIL: Pacing timeout on large models (~35 min default)            │
│  📊 Monitor: ICSP/Pacer UI (paced), hedwig_streaming_investigator +   │
│     predictor_streaming_model_update (streaming) — 3 tables, no E2E   │
└────────────────────────────────────────────────────────────────────────┘

8 team boundaries in this pipeline. Nobody owns the E2E latency metric.
```

---

## Slide 7: How Scribe Works Into OT — With Failure Points (Q3)

```
User clicks/views/buys
        │
        ▼
┌───────────────┐     ┌─────────────────┐     ┌──────────────────┐
│ Events Infra  │ ──→ │ Feature Joining  │ ──→ │ Scribe Category  │
│ (raw events)  │     │ (AdTailer/       │     │ (per model)      │
│               │     │  FeatureAgg/     │     │                  │
│               │     │  Data Forwarder) │     │ ⚠ Quota: 37%    │
│               │     │                  │     │   of all SEVs    │
│               │     │ ⚠ UDF bugs →    │     │                  │
│               │     │   NaN features   │     │ ⚠ No checkpoint │
│               │     │   (silent!)      │     │   → data loss on │
└───────────────┘     └─────────────────┘     │   every restart  │
                                               └────────┬─────────┘
                                          ┌─────────────┼────────────┐
                                          ▼             │            ▼
                                    ┌──────────┐        │     ┌──────────────┐
                                    │   Hive   │        │     │ DPP Readers  │
                                    │ (batch)  │        │     │              │
                                    └──────────┘        │     │ ⚠ Split gen  │
                                                        │     │   bug → job  │
                                                        │     │   COMPLETES  │
                                                        │     │ ⚠ Bad release│
                                                        │     │   → 45h outage│
                                                        │     └──────────────┘
                                                        │
                                              Two reader options:
                                              • Scribe Readers (legacy, co-located)
                                              • DPP Readers (newer, -50% CPU)
                                                BUT: DPP changes not tested
                                                against OT → 21% of SEVs
```

---

## Slide 8: Does OT Always Mean Streaming? (Q4)

**No.** OT = streaming data. But model *delivery* has 4 modes with different risk profiles:

```
                    TRAINING                              DELIVERY
               (always streaming)                    (4 different modes)

                                          ┌─ Out-of-place    1.5-2+ hrs   (legacy)
Scribe ──→ Trainer ──→ Model weights ─────┤   ⚠ TW restart required. Capacity spike.
                                          │
                                          ├─ Paced in-place  10-30 min    (most models)
                                          │   ✓ Auto-revert on failure. ICSP/Pacer UI.
                                          │
                                          ├─ Paced delta     10-30 min    (dense deltas)
                                          │   ✓ Validated before deploy. Small blast radius.
                                          │
                                          └─ Streamed delta  1-5 min ★    (sparse + item)
                                              ⚠ Hedwig outage = ALL models stale.
                                              ⚠ 3 Scuba tables to debug. No E2E view.
                                              ✓ Self-heals via absolute values.
```

Most OT models use paced (non-streaming) delivery. Streaming is for freshness-critical models.
**The tradeoff**: Lower latency = harder debugging + higher correlated failure risk.

---

## Slide 9: Key Systems

| System | Role |
|---|---|
| **MAST** | ML job scheduler (200K jobs/day, 225K GPUs) |
| **DPP** | Data preprocessing — fetches from Scribe/Hive |
| **UMM** | Central metadata store for all snapshots |
| **Manifold** | Blob storage for model artifacts |
| **TGIF** | Torch model → inference-optimized format |
| **Hedwig** | P2P streaming (8 EB/day, 1400+ Tbps) |
| **IPNext** | Control plane for model lifecycle on predictors |
| **ZCH** | Zero Collision Hashing for sparse embeddings |
| **SilverTorch** | Retrieval model publishing service |

---

## Slide 10: Recommendation Pipeline — Two Stages

```
Billions of items                    Thousands                          Tens
      │                                  │                               │
      ▼                                  ▼                               ▼
┌─────────────┐                  ┌──────────────┐                ┌────────────┐
│  RETRIEVAL  │ ──────────────→  │   RANKING    │ ────────────→  │  User sees │
│             │                  │              │                │  results   │
│ Two-tower:  │                  │ Cross-feature│                └────────────┘
│ User embed  │                  │ interaction: │
│   ·         │                  │ User x Item  │
│ Item embed  │                  │ features     │
│ (dot prod)  │                  │ (neural net) │
│             │                  │              │
│ ANN search  │                  │ Real-time    │
│ Precomputed │                  │ scoring      │
│ embeddings  │                  │              │
└─────────────┘                  └──────────────┘
Feed U2I, Reels T2I,             Feed LSR, Reels LSR,
Reels CS Omni                    Reels ESR
```

| | Retrieval | Ranking |
|---|---|---|
| **Optimization** | Recall (don't miss relevant items) | Precision / business metrics |
| **Inference** | Precomputed embeddings + ANN search | Real-time scoring per item |
| **Key delta type** | Item embedding deltas (ANN freshness) | Weight deltas (sparse + dense) |

---

## Slide 11: IG OT Data Flows — With Failure Points

**Ranking models (LSR)** — single job does everything:
```
Scribe ──→ DPP ──→ MAST Trainer ──→ TGIFInTrainerPublisher
  │          │          │                  │           │
  │          │          │            FULL_SNAPSHOT  SPARSE + DENSE DELTA
  │          │          │            (Manifold)    (Hedwig streaming)
  │          │          │                  │           │
  │          │          ▼                  ▼           ▼
  │          │     Checkpoint ──→     UMM ──→ IPNext ──→ Predictor
  │          │
  ⚠ Quota   ⚠ Split gen      ⚠ Publisher init     ⚠ Hedwig msg
    exceeded   bug → job        needs 3 deps,        loss =
              COMPLETES         ~90s startup          ALL models
                                                      stale
```

**Retrieval models (ESR/U2I)** — hybrid: trainer + SilverTorch:
```
Scribe ──→ DPP ──→ MAST Trainer ──→ DeltaOnlyPublisher (in-trainer)
                        │                  │                │
                        │            SPARSE_DELTA    ITEM_EMB_DELTA
                        │            (Hedwig)        (Hedwig)
                        ▼                  │                │
                   Checkpoint ──→ UMM      ▼                ▼
                        │          └───→ IPNext ──→ Predictor
                        ▼
              SilverTorch (separate job)
                        │
                  FULL_SNAPSHOT (Manifold) ──→ UMM ──→ IPNext

    ⚠ KNOWN GAP: No item delta while SilverTorch generates full snapshot
       → predictable freshness hole every 1-2h for ALL retrieval models
```

---

## Slide 12: Publisher Architecture

```
InTrainerPublisher (abstract base)
├── TGIFInTrainerPublisher       ← Full snapshots (LSR)
├── GMPPInTrainerPublisher       ← Full snapshots via GMPP
├── SilverTorchInTrainerPublisher ← Extends TGIF for retrieval
└── DeltaOnlyPublisher           ← Delta-only (ESR, UMIA)
    ├── WeightsDeltaPublisher     ← Sparse + dense weights
    └── ItemDeltaPublisher        ← Item embeddings
```

| Config Type | Used By | Publishes |
|---|---|---|
| `DeltaOnlyPublisherConfig` | ESR, UMIA | Deltas + checkpoints only |
| `TGIFPublisherConfig` | LSR | Full snapshots + deltas |

**Hybrid pattern**: ESR/retrieval use in-trainer for deltas, separate SilverTorch job for full snapshots.

---

## Slide 13: Version Chain — The Poll Question (Q1)

Full snapshots and deltas share a **single monotonic version line** in UMM:

```
Poll example: 1-a-b-c-2-d-e-3

  [1]────a────b────c────[2]────d────e────[3]
   ▲     ▲    ▲    ▲     ▲     ▲    ▲     ▲
  FULL  SP   DN   SP   FULL   SP   DN   FULL
        │    │    │            │    │
        └────┴────┘            └────┘
        deltas on [1]       deltas on [2]

SP = SPARSE_DELTA    DN = DENSE_DELTA
```

**To reach version `e`**: Load full snapshot **[2]**, apply **d** then **e**
**To reach version `c`**: Load full snapshot **[1]**, apply **a**, **b**, **c**
**Cold start at `e`**: Must load **[2]** first — cannot skip full snapshot

---

## Slide 14: Resuming OT — The Data Loss Gap (Q1 continued)

```
        Training normally                    Crash & Restart
        ─────────────────                    ───────────────

Scribe: ──A──B──C──D──E──F──G──H──I──J──K──L──M──N──O──P──→
              │                    │              │
              ▼                    ▼              ▼
         Checkpoint             CRASH          Restart
         (saved at B)                        (jumps to N)

         ████████████████████████
         ▲ C through M = LOST ▲
         No Scribe checkpointing for OT
```

**Model weights**: Resume from anchor checkpoint linked to latest valid UMM snapshot.

**Data cursor**: Jumps to Scribe's "now" — everything in between is **permanently lost**.

**Impact**: 5% data loss → significant NE harm. Restarts happen ~weekly per model.

**Mitigations**: Watermark-checkpoint integration (design phase), fallback to Hive for extended outages.

---

## Slide 15: UMM as Source of Truth (Q5)

```
┌──────────────────────────────────────────────────────────────┐
│                         UMM (metadata)                        │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │ Version IDs │  │SnapshotType  │  │ State               │ │
│  │ v0, v1, v2..│  │FULL/SPARSE/  │  │ CREATING→VALID      │ │
│  │             │  │DENSE/ITEM    │  │        →INVALID     │ │
│  └─────────────┘  └──────────────┘  └─────────────────────┘ │
│  ┌──────────────────────┐  ┌────────────────────────┐       │
│  │ based_snapshot_id    │  │ trained_end_ts          │       │
│  │ (which full snap)    │  │ (training timestamp)    │       │
│  └──────────────────────┘  └────────────────────────┘       │
└──────────────────────────────┬───────────────────────────────┘
                               │ IPNext polls every ~30s
                               ▼
                          ┌──────────┐
                          │Predictor │
                          └──────────┘

UMM does NOT store: actual weights (→ Manifold), data cursors, serving state
```

**Tools**: `bunnylol ummmeta <id>`, `bunnylol mlhub model <id>`, `trmgr`

---

## Slide 16: Section 3 — Delta Health (Q2)

**UMM Snapshot State Lifecycle**:
```
                    ┌─────────┐    validation     ┌─────────┐
   Publish start →  │CREATING │ ───succeeds────→  │  VALID  │
                    └─────────┘                    └────┬────┘
                                                       │
                                              validation fails
                                              or manual ban
                                                       │
                                                       ▼
                                                  ┌─────────┐
                                                  │ INVALID │
                                                  └─────────┘
```

**Cascading invalidation**:
```
  [FS1]──d1──d2──d3──[FS2]──d4──d5──[FS3]
                       ▲
                  marked INVALID
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
    d1, d2, d3 INVALID      d4, d5 INVALID
    (lead to FS2)           (based on FS2)
```

---

## Slide 17: Validation Pipeline

```
FULL SNAPSHOT                      DELTA
─────────────                      ─────

Published ──→ MSV (~40 min)        Published ──→ Sanity check (~6 min)
              │                                  │
              ├─ NE threshold                    ├─ Can it load?
              ├─ Calibration                     ├─ NaN/INF check
              ├─ MSE / RMSE                      └─ Error rate < 10%?
              └─ ~1M samples                         ~10k samples
              │                                  │
              ▼                                  ▼
         VALID or INVALID                   VALID or INVALID


BOTH go through IPNext bake time during paced deployment:
  1% tasks (bake 5 min) → 35% → 100%
  Auto-revert on health check failure
```

**Trend**: MSV-based delta validation → IPNext bake time (less overhead, same coverage)

---

## Slide 18: Failure Modes Ranked by Impact

| # | Failure | Blast Radius | Frequency | Detection |
|---|---------|-------------|-----------|-----------|
| 1 | **OT job crash + data loss** | Single model, permanent NE harm | Weekly per model | MAST alerts, manual |
| 2 | **Hedwig outage** | ALL streaming models simultaneously | Rare but catastrophic | Hedwig oncall |
| 3 | **Delta publisher init failure** | Single model, 1h stale | Common (3 deps) | Publisher subprocess logs |
| 4 | **commit_version (XDB lag)** | Single delta dropped | Common, self-healing | UMM commit errors |
| 5 | **Weight incompatibility** | Model rollback | Rare (arch changes) | Predictor crash |

**Correlated failure risk**: Hedwig P2P outage affects ALL streaming models at once — sparse deltas + item deltas for every IG model go stale simultaneously. This is the highest-severity scenario because it's not model-isolated.

**Self-healing vs not**: Failures #3-4 self-heal (next delta corrects). Failure #1 causes permanent data loss — no self-healing.

---

## Slide 19: Oncall Triage — 8 Failure Types

```
Alert fires → CLASSIFY FIRST, INVESTIGATE SECOND

┌──────────────────────────────────────────────────────────────────┐
│ TYPE 1: JOB CRASH / OOM          │ TYPE 2: JOB STUCK            │
│ Signal: exit code ≠ 0, CUDA OOM  │ Signal: INITIALIZING > 30min │
│ Check: Job logs, nvidia-smi,     │ Check: Checkpoint on Manifold│
│   recent batch size changes       │   MAST scheduler queue,      │
│ Common: GPU 80GB limit,          │   dependency services         │
│   CPU ~190GB peak                │                              │
├──────────────────────────────────┼──────────────────────────────┤
│ TYPE 3: TRAINING DIVERGENCE      │ TYPE 4: LATENCY REGRESSION   │
│ Signal: NaN loss, gradient spike │ Signal: ATS > baseline       │
│ Check: Loss curve, grad norm,    │ Check: SLICK SLIs, Hedwig    │
│   correlate with config change   │   publisher, artifact size,  │
│   in last 30 min                 │   DPP data flow              │
├──────────────────────────────────┼──────────────────────────────┤
│ TYPE 5: DATA PIPELINE            │ TYPE 6: CHECKPOINT FAILURE   │
│ Signal: Zero data, high filter   │ Signal: Save/load errors     │
│ Check: dpp_operator_stats        │ Check: Manifold logs,        │
│   (rows_in vs rows_out),         │   checkpoint producer job    │
│   schema changes, UDF errors     │   status, disk space         │
├──────────────────────────────────┼──────────────────────────────┤
│ TYPE 7: INFRASTRUCTURE           │ TYPE 8: CONFIG / ROLLOUT     │
│ Signal: Host unreachable,        │ Signal: Failure after change │
│   network timeout, ZippyDB err   │ Check: Recent diffs,         │
│ Check: Host status, network,     │   feature flag timeline,     │
│   service dependencies           │   config diff in last 24h    │
└──────────────────────────────────┴──────────────────────────────┘

  70% of failures are Types 1, 5, 8 (OOM + data pipeline + bad config)
  → Check the obvious first. Correlate with time — most failures
    follow a recent change.
```

**Key tools**: MAST job UI, `nvidia-smi`, Scuba (`dpp_operator_stats`, `gmpp`, `hedwig_streaming_investigator`, `predictor_streaming_model_update`), SLICK, ICSP Pacer UI, `bunnylol ummmeta <id>`

---

## Slide 20: How Updates Reach Predictors (Q6)

```
                    ┌──────────────────────────────────────┐
                    │             IPNext                    │
                    │  (polls UMM every ~30s)               │
                    │                                      │
                    │  Pacing: 1% → 35% → 100%             │
                    │  Health check at each phase           │
                    │  Auto-rollback on failure             │
                    └────────┬────────────┬────────────────┘
                             │            │
                     ┌───────┘            └───────┐
                     ▼                            ▼
              Paced delivery               Streaming delivery
              (Manifold + Pacer)           (Hedwig P2P)
              Dense delta, Full snap       Sparse delta, Item delta
                     │                            │
                     └──────────┬─────────────────┘
                                ▼
                    ┌──────────────────────┐
                    │     Predictor        │
                    │  (hot-swap in-place) │
                    │                      │
                    │  Sparse: overwrite   │
                    │    embedding rows    │
                    │  Dense: swap tensors │
                    │    (SwapConstBuffer) │
                    │  Item: update        │
                    │    EmbeddingCache    │
                    └──────────────────────┘
```

No process restart. No traffic disruption. No extra capacity needed.

---

## Slide 21: Item Delta Flow End-to-End (Q8)

```
┌──────────┐     ┌──────────────────┐     ┌────────────────────┐
│  Scribe  │ ──→ │ItemDeltaPublisher│ ──→ │RankingBulkEvalLite │
│ (recent  │     │(AsyncDataReader) │     │  GPU inference     │
│  items)  │     └──────────────────┘     │  CURRENT weights ★ │
└──────────┘                              └─────────┬──────────┘
                                                    │
                                          Fresh item embeddings
                                                    │
                                                    ▼
┌──────────────┐     ┌─────────┐     ┌──────────────────────┐
│  Predictor   │ ◄── │ Hedwig  │ ◄── │ UMM registration     │
│              │     │  (P2P)  │     │ ITEM_EMBEDDING_DELTA  │
│ EmbeddingCache     └─────────┘     └──────────────────────┘
│ hot-patched  │
│ in-place     │
└──────────────┘
```

★ Uses CURRENT training weights, not stale checkpoint. Saved 40 GPU cards vs standalone job.

---

## Slide 22: Item Delta vs Weight Delta

| | Item Delta | Sparse Weight Delta | Dense Weight Delta |
|---|---|---|---|
| **What** | Pre-computed embeddings | Embedding rows | MLP, attention |
| **Source** | Scribe (recent items) | Optimizer momentum (hot rows) | Full dense copy |
| **Compute** | GPU inference | CPU copy + selection | CPU copy |
| **Delivery** | Hedwig streaming | Hedwig OR paced | Paced |
| **Publisher** | ItemDeltaPublisher | WeightsDeltaPublisher | WeightsDeltaPublisher |

---

## Slide 23: Section 5 — Streaming vs Batch Reliability (Q7)

```
STREAMING (Hedwig P2P)                    PACED (Manifold + IPNext)
   Latency: 1-5 min                         Latency: 10-30 min

Trainer ──→ Hedwig Root ──→ P2P tree      Trainer ──→ Manifold ──→ IPNext
                │                                                    │
          ┌─────┼─────┐                              ┌──── Pacer ────┤
          ▼     ▼     ▼                              ▼       ▼      ▼
        Pred  Pred  Pred                          1% tasks  35%   100%
                                                  (bake 5m) (bake) (done)

  ⚠ FAILURE MODES                         ⚠ FAILURE MODES
  ─────────────                           ─────────────
  • Msg loss (buffer overflow)            • Timeout on large models
  • Buffer OOM on large embeds            • Manifold download failure
  • Root node churn                       • Weight incompatibility
  • Shard imbalance                       • Pacing stalled (health check)

  ⚠ BLAST RADIUS                         ⚠ BLAST RADIUS
  ─────────────                           ─────────────
  Hedwig outage → ALL streaming           Single model only
  models stale simultaneously             (1% rollout catches it)

  📊 DEBUG: HARD                          📊 DEBUG: MODERATE
  3 Scuba tables, no E2E view            ICSP/Pacer UI, single dashboard
  gmpp → hedwig_investigator →            Clear state machine visible
  predictor_streaming_model_update
```

---

## Slide 24: When to Use Which

| Use Case | Approach | Why |
|---|---|---|
| Sparse deltas | Streaming | Lowest latency; too large for frequent pacing |
| Item embedding | Streaming | Sub-minute freshness for content discovery |
| Dense deltas | Paced | Small size; benefits from validation before deploy |
| Full snapshots | Paced | Too large to stream; needs validation + rollout |
| New model launch | Paced first | Reduce risk, enable streaming after validation |

**Business impact**: Delta publishing reduced ATS from ~12 hours → ~30 min (paced) → minutes (streaming).
NE gain: ~0.4% from 8h→1h ATS, ~0.15% from 60min→5min.

---

## Slide 25: Current IG OT Freshness State

**Retrieval Models**:
| Model | Sparse P90 | Item P90 | Key Issue |
|---|---|---|---|
| Feed U2I | 4 min | 25 min | Scribe delay + inference >10 min |
| Reels T2I | 3 min | Not stable | Pending launch |
| Reels CS Omni | 2 min | 25 min | High scribe delay |

**Ranking Models**:
| Model | Sparse P90 | Key Issue |
|---|---|---|
| Feed LSR | 8 min | — |
| Reels ESR | 30 min | High scribe delay variation |
| Reels LSR | 30 min | Scribe delay |

**SLI targets**: Sparse/item P90 ≤ 10 min, streaming success ≥ 99% (95% of hours/week)

---

## Slide 26: Section 6 — Operational Challenges (SEV Data)

**19 OT SEVs in 6 months** (H2 2025). What actually breaks in production:

```
Root Cause Distribution (19 SEVs)

  Quota / Admission Control  ████████████████████  37%  (7 SEVs, incl. both SEV-2s)
  DPP / Data Pipeline        ██████████           21%  (4 SEVs)
  Infra / Configuration      ████████             16%  (3 SEVs)
  Job State Management       ████████             16%  (3 SEVs, emerging in H2)
  Publishing Failures        █████                11%  (2 SEVs)
  Resource / Capacity        █████                11%  (2 SEVs)
```

```
Affected Product Groups

  IG (Instagram)             ████████████████████  42%  (8 SEVs)
  Multi-PG                   ████████████████      37%  (7 SEVs)
  FBR / FBV / VDD / CFR     ██████████            21%  (4 SEVs)
```

**Key insight**: IG has ~4x more SEVs than any single-surface PG — larger OT model fleet competing for shared Scribe quota.

---

## Slide 27: The Top 3 Operational Pain Points

```
#1  SCRIBE QUOTA (9 SEVs, 21% of all OT SEVs)
    ─────────────────────────────────────────
    Pattern: Jobs start without guaranteed resources
             → preemption cascades → model staleness

    S555616 (SEV2): FB/MRS OT Scribe quota exceeded → all OT jobs affected
    S559678 (SEV2): IG OT preemptions → 1K+ Scribe thrash events

    Gap: No admission control that checks GPU + Scribe + machine type BEFORE job start


#2  DPP / DATA PIPELINE (8 SEVs, 19%)
    ──────────────────────────────────
    Pattern: DPP changes not tested against OT workloads
             → silent failures or crashes

    S552593: DPP split generation bug → OT jobs unexpectedly COMPLETE
    S512573: DPP release code bug → couldn't rollback (hotfix entangled) → 45+ hours

    Gap: No OT-aware DPP validation. UDF bugs cause NaN (not crashes) — hard to detect


#3  PUBLISHING FRAGILITY (8 SEVs, 19%)
    ────────────────────────────────────
    Pattern: Generic errors, fixed timeouts, corrupt checkpoints

    S507549: ads_token_service throttling → 99%+ publishing jobs failed (SEV1)
    S613560: Fleet-avg streaming 96% masked 11 models below 90%

    Gap: Per-model publishing SLOs don't exist. Fleet averages hide individual failures
```

---

## Slide 28: Why OT Is Operationally Harder

```
                    Recurring Training              Online Training
                    ──────────────────              ───────────────

  Lifetime:         Finite (run, complete)           Forever (continuous)

  Failure cost:     Retry next cycle                 Every minute of downtime
                                                     = stale models in prod

  Dependencies:     Hive (batch, stable)             Scribe + DPP + Hedwig +
                                                     MAST + TMS (all real-time)

  Publish modes:    FULL_SNAPSHOT only                FULL + SPARSE_DELTA +
                                                     DENSE_DELTA + streaming

  Cost:             1x                               2.3-2.6x

  Error pattern:    Crash → retry → succeed          Silent degradation →
                                                     fleet avg masks it →
                                                     discovered days later
```

**Cross-cutting themes from 42+ SEVs**:
- Blast radius is unbounded (one bad DPP release → hundreds of jobs)
- Errors are non-retryable when they should be transient
- Fleet averages mask individual model failures
- Recovery is manual and slow

---

## Slide 29: Common Confusions Clarified

| Confusion | Clarification |
|---|---|
| "Delta" vs "Full" | Delta = incremental changes. Full = complete model. Deltas applied on top of a base. |
| "Item Publish" vs "Weight Publish" | Item = item embeddings only. Weight = sparse + dense model weights. |
| "Sparse" vs "Dense" deltas | Sparse = embedding rows. Dense = MLP/attention tensors. |
| "Training Side" vs "Item Side" | Training side = deltas from trainer. Item side = deltas from STUS. Both use Hedwig. |
| "In-Trainer" vs "Two-Step" | In-Trainer = publish from trainer process. Two-Step = checkpoint → STUS reads → publishes. |
| "TGIF" vs "GMPP" | TGIF: standard, full snapshots. GMPP: delta publishing for large embedding tables. |

---

## Slide 30: Design Decisions — Why This Architecture?

| Decision | Alternative Considered | Why We Chose This |
|---|---|---|
| **Absolute-value deltas** | Relative diffs (smaller size) | Eventual consistency — lost messages self-correct. No ordering dependency. |
| **Separate delta publisher subprocess** | In-process publishing | Isolates publisher failures from training. Training continues if publisher crashes. |
| **UMM as metadata-only SOT** | UMM stores artifacts too | Separation of concerns. Manifold scales for blob storage; UMM scales for metadata queries. |
| **Hedwig P2P for streaming** | Direct predictor push | P2P scales to thousands of predictors without trainer bottleneck. 8 EB/day throughput. |
| **DeltaOnly + SilverTorch hybrid** | Single job for everything | Avoids blocking training during full snapshot generation (which takes 10-40 min). |
| **Paced rollout (1%→35%→100%)** | All-at-once push | Limits blast radius. Only 1% of traffic affected if a bad delta slips through. |

**Architectural tension**: Latency vs safety. Every optimization for freshness (streaming, skip validation, larger delta windows) reduces safety margins. The system is tuned per model based on business criticality.

---

## Slide 31: Systemic Gaps & Opportunities

```
GAP                              IMPACT                    FIX STATUS
───                              ──────                    ──────────

No Scribe checkpointing ──────→ Data loss EVERY restart ── Design phase
                                 (~weekly per model)

No item delta during ──────────→ Freshness hole every ──── SilverTorch
  full snapshot generation        1-2h for retrieval        limitation

No user embedding delta ───────→ User tower always ──────── Known gap
                                  1-2h stale

Config sprawl (6+ surfaces) ───→ User errors, slow ──────── No fix planned
                                  debugging

Streaming observability ───────→ 3-table correlation ─────── No fix planned
  gap                             = slow oncall triage
```

**Biggest opportunities**: Watermark-checkpoint (eliminate data loss), E2E streaming dashboard (cut MTTR), unified publisher config (reduce 6+ surfaces to 2)

---

## Slide 32: Key Takeaways — What PE Should Do With This

**Mental models to internalize**:
1. **Full snapshot = reset point. Deltas = increments. Absolute values = self-healing.** This is the design principle that makes the system fault-tolerant.
2. **Retrieval vs ranking drives everything downstream** — different publishers, different delta types, different failure modes. Know which models are which.
3. **Hedwig is the single biggest correlated risk** — it affects all streaming models simultaneously. Paced delivery is the safety net.

**Top 3 PE priorities** (from this analysis):
1. **Build the oncall triage muscle** — use the 8 failure type classification (slide 19) and SEV patterns (slides 26-28). Classify first, investigate second. 70% of failures are OOM + data pipeline + bad config.
2. **Push for E2E streaming observability** — today's 3-table correlation requirement is the #1 source of slow triage. A single dashboard would cut MTTR significantly.
3. **Quantify data loss on restart** — we say "data loss on every restart" but don't measure it systematically. Instrumenting this would justify the watermark-checkpoint investment.

**What I'm NOT saying**: OT is broken. The system handles Meta's scale with high reliability. But the operational sharp edges — config sprawl, observability gaps, SilverTorch limitations — are where PE can have the most impact.

---

## Slide 33: References

- [OT Architecture wiki](https://www.internalfb.com/wiki/Users/shakeeb/TDI/Online-Training-Architecture/)
- [Delta Publish Overview](https://www.internalfb.com/wiki/Real-TimePublishing/Delta_Publish_Overview/)
- [UMM User Guide](https://www.internalfb.com/wiki/AIMetadata/UMM_Overview/UMM_User_Guide/)
- [Delta Troubleshooting](https://www.internalfb.com/wiki/ML_Freshness/Model_Freshness/Delta_Update:_Troubleshooting_Tutorial_for_Production_Models/)
- [IPNext Streaming Guide](https://www.internalfb.com/wiki/Inference/Inference%3A_Internal/IP_Next%3A_Internal/Snapshot_Transition/Streaming/IPnext_Streaming_Guide/)

**NOTES.md** in this repo has the full reference notes with code paths and detailed explanations.

---

_End of deck — 33 slides_
