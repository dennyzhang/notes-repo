# OT Publish Architectures — Triage Routing Guide

Learned 2026-05-23 during triage of model 2132070936 (facebook_reels_ifu_i2i).
Knowing the architecture upfront determines which upstream to check when
"missing FULL_SNAPSHOT" alerts fire. Without it, oncall wastes 30+ min
investigating the wrong model.

## Two architectures

RETRIEVAL I2I (e.g., facebook_reels_ifu_i2i)
  3 models, 2 trainers, 1 serving entity
  Use case: item-to-item recommendation ("find similar items")

MTML RANKING (e.g., cfr_main_mtml, ig_reels_tab_mtml)
  1 model, 1 trainer, built-in publisher
  Use case: feed ranking ("score each candidate for a user")

## How to identify which architecture

    meta ai.model list --model-id=<ID>
    # model_type_name tells you:
    #   *_i2i, *_retrieval       → Retrieval I2I
    #   *_mtml, *_ranking        → MTML ranking

    # Or from fire command:
    #   --module silvertorch.experimental.st_update_service.st_t2i_update_service
    #     → Retrieval I2I
    #   --module minimal_viable_ai.*.train (with in-trainer publisher)
    #     → MTML ranking

================================================================
ARCHITECTURE 1: RETRIEVAL I2I
================================================================

Three models, two trainers:

    Root trainer               Reranker trainer
    (UMIA HSTU retrieval)      (TTSN reranker)
    Trains: item embeddings    Trains: reranker weights
    Ckpt cadence: ~45 min      Ckpt cadence: ~45 min
            |                          |
       +-------------------------------------------+
       |  ST model (SilverTorch T2I Update Service) |
       |  (serving entity — NOT a trained model)    |
       |                                            |
       |  ITEM_EMB_DELTA: every ~2 min              |
       |    new items get root + reranker bulk eval  |
       |    results pushed into FreshIndex (KNN)     |
       |                                            |
       |  FULL_SNAPSHOT: on reranker ckpt change    |
       |    rebuild entire KNN index + reload        |
       |    reranker weights (baked into model)      |
       +-------------------------------------------+
                     |
                Serving (predictor)

What each model does:

    ROOT: produces item retrieval embeddings via UMIA HSTU.
    These embeddings power the KNN index for nearest-neighbor search.
    Updated incrementally via ITEM_EMB_DELTA (streaming new items
    through root bulk eval into the FreshIndex).

    RERANKER: produces reranker/overarch embeddings that score
    candidates after KNN retrieval. Weights are baked into the
    serving model. Can only be updated via FULL_SNAPSHOT because
    the entire model must be rebuilt with new reranker weights.

    ST MODEL: the published serving entity. NOT separately trained.
    It combines: KNN index (from root) + embedding cache (from
    reranker) + bloom filter + precomputed graph.

Why FS requires reranker ckpt (not root):

    Root embeddings can be refreshed incrementally (delta updates
    stream new items through both root + reranker bulk eval).
    But reranker WEIGHTS are embedded in the serving model — you
    can't patch them incrementally. New reranker weights require
    rebuilding the full serving model.

    Code: st_t2i_update_service.py:148-149
    "threads is using reranker version change as the trigger of
    full snapshot publish as reranker is using Online Training"

Fire command model IDs:

    --root-model-entity-id <ROOT_ID>
    --reranker-model-entity-id <RERANKER_ID>
    --st-model-entity-id <ST_ID>
    --model-entity-id <ST_ID>

Triage path for "missing FULL_SNAPSHOT":

    1. Don't investigate the alerted ST model — it only does deltas
    2. Get reranker ID: grep fire command for --reranker-model-entity-id
    3. Check reranker checkpoints (UMM web UI)
    4. Check reranker mvai_metrics liveness probe
    5. If reranker hung/dead → that's the root cause

================================================================
ARCHITECTURE 2: MTML RANKING
================================================================

One model, one trainer with built-in publisher:

    Root trainer (with in-trainer publisher)
      |
      +-- SPARSE_DELTA ----> every ~3-5 min
      |   top-N% embedding rows selected by optimizer momentum
      |   copied to shared memory, quantized, published via Hedwig
      |
      +-- DENSE_DELTA -----> every ~15-20 min
      |   all dense NN parameters copied and published
      |
      +-- FULL_SNAPSHOT ---> every ~2 hours (on checkpoint save)
          complete inference model via TGIF subprocess
          deltas are PAUSED during FS publish and resume after

What the trainer does:

    Continuously reads from Scribe, updates both sparse embedding
    tables and dense NN parameters. The in-trainer publisher
    (WeightsDeltaPublisher) runs alongside training:

    - Sparse row selection uses optimizer momentum to pick the
      most-changed embedding rows
    - Dense delta copies all dense params directly from the module
    - Copy-to-shared-memory takes seconds; actual upload is async

    FULL_SNAPSHOT runs on checkpoint save: SilverTorchTGIFPublisher
    in a subprocess produces the complete serving model.

Alternative: separate STUS publisher (same model, separate MAST job):

    Some MTML models use a separate StUpdateService MAST job that
    polls for new root model checkpoints and runs full publish.
    Same trigger: root checkpoint version change.
    Used when heavy GPU post-processing is needed.

Triage path for "missing FULL_SNAPSHOT":

    1. Check the SAME trainer job (not a separate model)
    2. If deltas flowing but no FS → publish subprocess stuck (P01/P02)
    3. If everything missing → trainer itself is dead
    4. If using separate STUS → check the publisher MAST job

================================================================
TRIAGE ROUTING TABLE
================================================================

Alert: "missing FULL_SNAPSHOT on model X"

    Step 1: Identify architecture
      meta ai.model list --model-id=X → model_type_name
        *_i2i / *_retrieval → RETRIEVAL I2I → go to step 2a
        *_mtml / *_ranking  → MTML RANKING  → go to step 2b

    Step 2a (Retrieval I2I):
      Get reranker ID from fire command
      Check reranker checkpoint health + liveness
      Root cause is usually the RERANKER, not the alerted model

    Step 2b (MTML Ranking):
      Check the alerted model's own trainer job
      Deltas flowing? → publish subprocess stuck
      Nothing flowing? → trainer dead

================================================================
KNOWN INSTANCES
================================================================

Retrieval I2I:

    Model type              Root         Reranker     ST model
    ----------------------  -----------  -----------  -----------
    facebook_reels_ifu_i2i  2125081911   2125081901   2132070936

MTML Ranking:

    Model type              Trainer job
    ----------------------  -----------
    cfr_main_mtml           mvai-training-online-<model_id>
    ig_reels_tab_mtml       mvai-training-online-<model_id>

================================================================
RELATED
================================================================

- Investigation pastes: P2349062759, P2349068641, P2349071994
- SEV S667567 — reranker zombie blocking FS on downstream model
- D106195444 — triage skill: UMM web UI as ground truth
- FS trigger code: st_t2i_update_service.py:159-163
- In-trainer publisher: minimal_viable_ai/core/publisher/delta_only_publisher.py
- STUS publisher: silvertorch/experimental/st_update_service/st_update_service.py
- Reranker loading: st_update_service/st_t2i_reranker_util.py

================================================================
OT JOB PATTERN TAXONOMY (4 patterns)
================================================================

Distilled 2026-05-28. Every OT model falls into one of these 4 patterns.
Each pattern has different failure modes — triage must identify the
pattern FIRST before investigating.

Pattern 1: IN-TRAINER PUBLISHING (1 job)
  Jobs: 1 MAST job (trainer + publisher in same process)
  Publishing: WeightsDeltaPublisher runs alongside training.
    Sparse/dense deltas published inline.
    FULL_SNAPSHOT via SilverTorchTGIFPublisher subprocess on ckpt save.
  Examples: cfr_main_mtml, ig_reels_tab_mtml, ig_organic_feed_mtml
  Failure modes: CL-001 (publish subprocess stuck), CL-014 (NCCL in
    publish path), TGIF hang (S651873), Gloo/DistStore errors (S667668)

Pattern 2: SEPARATE STUS PUBLISHER (2 jobs)
  Jobs: trainer MAST job + StUpdateService publisher MAST job
  Publishing: Trainer produces checkpoints. STUS MAST job polls for
    new checkpoints, runs full publish (heavy GPU post-processing).
  Examples: some MTML models needing heavy publish compute
  Failure modes: CL-008 (STUS mis-classified as trainer), STUS startup
    fails (P56 — removed MTIA module), publisher job zombie (S665454
    sub-class)

Pattern 3: RETRIEVAL I2I (3 models, 2 trainers)
  Jobs: 2 trainer MAST jobs (root + reranker) + 1 ST model (serving entity)
  Publishing: Root trainer → item embeddings → ITEM_EMB_DELTA every ~2min.
    Reranker trainer → weights. ST model rebuilds KNN index →
    FULL_SNAPSHOT on reranker checkpoint change.
  Examples: facebook_reels_ifu_i2i (root=2125081911, reranker=2125081901,
    ST=2132070936)
  Failure modes: Reranker zombie blocks FULL_SNAPSHOT on ST model
    (S667567). Need to check RERANKER health, not the alerted model.

Pattern 4: RETRIEVAL STREAMING-ONLY (1 job, no FULL_SNAPSHOT)
  Jobs: 1 MAST job (trainer only, no TGIF publish)
  Publishing: Deltas streamed via Hedwig (SPARSE_DELTA + ITEM_EMB_DELTA).
    No FULL_SNAPSHOT — predictor rebuilds state from streaming delta chain.
  Examples: ig_mixed_feed_smsl_esr, ig_reels_tab_cs_omni_retrieval,
    ig_reels_tab_ss_omni_retrieval
  Failure modes: Hedwig/TCPStore silent failure (S658165), multicast
    over-subscription (S644248), streaming success rate drops (S667222).
    "Missing FULL_SNAPSHOT" alerts are FALSE POSITIVES for this pattern.

TRIAGE FIRST STEP: Identify which pattern before investigating.
  meta ai.model-series metadata --model-id=<ID>
  → model_type_name tells you:
    *_i2i, *_retrieval → Pattern 3 (Retrieval I2I)
    *_mtml, *_ranking  → Pattern 1 or 2 (check if STUS job exists)
    *_smsl_esr, *_omni_retrieval → Pattern 4 (streaming-only)
