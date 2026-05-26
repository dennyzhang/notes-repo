# Delta Publishing Failure Modes

Granular failure modes inside the WeightsDeltaPublisher and ItemDeltaPublisher pipelines. Complements the job-level failure taxonomy in `known-patterns.md` § Failure-Mode Taxonomy (A-F classes).

Source: Deep dive on delta key sets (T259394647 task 2.20), 16 SEV history.

## Architecture

```
Training Loop (every batch)
  │
  ├─ Forward pass: ModelDeltaTracker.record_lookup(kjt, states)
  │     Records which embedding row IDs were accessed + their states
  │
  └─ After batch: DeltaOnlyPublisher.try_push_delta_update_on_train_batch_end()
       │
       ├─ WeightsDeltaPublisher._should_push_delta()
       │     ├─ Max delta check (test mode)
       │     ├─ Timer check: FullSyncPeriodicTimer.check()
       │     └─ Full publish check: all_gather_object(full_pub_ongoing)
       │
       ├─ ModelDeltaTracker.get_unique(consumer="delta_publisher")
       │     Returns Dict[fqn, UniqueRows(ids, states)]
       │     DELETE-ON-READ: clears tracked state after read
       │
       ├─ tracker_based_select_embeddings_cpu_copy()
       │     Per table: data-parallel / KV-ZCH / model-parallel handling
       │
       ├─ _check_and_prepare_dense_cpu_copy()
       │     NaN/Inf check: silently drops dense delta if corrupted
       │
       └─ _async_execute_task() → ThreadPool(1) → subprocess
             └─ WeightsDeltaUpdateTaskHandler
                   ├─ Quantize embeddings
                   ├─ Upload tensors to Manifold
                   └─ commit_delta_update_metadata() (rank 0 only)
```

## Sparse Embeddings Selection Modes

| Mode | Enum | Tracker UpdateMode | Selection logic |
|---|---|---|---|
| `DELTA_NORM` (0) | Legacy | `FIRST` (stores initial embedding) | L2 norm of (current - initial), top-K in subprocess |
| `MOMENTUM` (1) | Recommended | `LAST` (stores latest momentum) | Top-K by momentum magnitude, done in trainer |
| `ID_ONLY` (2) | Simple | `NONE` (just track IDs) | Publish ALL tracked rows, no filtering |

Config: `embedding_delta_percentage` (global) or `embedding_delta_percentage_per_table`. JustKnob: `mrs/publish/delta_publish#embedding_delta_percentage`.

## Failure Modes

### A. Gating / Skip Failures (delta never attempted)

| ID | Failure | Silent? | Code |
|---|---|---|---|
| FM-1 | Full publish ongoing → delta skipped | Logged | `weights_delta_publisher.py:688` |
| FM-2 | Timer not configured (`publish_interval_secs <= 0`) or not fired | **Yes** | `weights_delta_publisher.py:663-664` |
| FM-3 | Timer cadence misalignment (IEN bug, D74599667) | **Yes** | `FullSyncPeriodicTimer` |
| FM-4 | Max delta published (test mode cap) | No | `weights_delta_publisher.py:655-657` |

### B. Initialization Failures (delta attempted but blocked)

| ID | Failure | Silent? | Code |
|---|---|---|---|
| FM-5 | No full snapshot exists → can't init task handler | Logged | `weights_delta_publisher.py:270-273` |
| FM-6 | Subprocess creation failure | No (crashes) | `weights_delta_publisher.py:423-442` |
| FM-7 | DI sharding plan download failure or mismatch | No (assertion) | `weights_delta_publisher.py:833-845` |

### C. Data Preparation Failures (delta has zero content)

| ID | Failure | Silent? | Code |
|---|---|---|---|
| FM-8 | NaN/Inf in dense weights → dense delta **silently dropped** | Partial (warn) | `weights_delta_publisher.py:492-495` |
| FM-9 | Zero tracked rows from ModelDeltaTracker for all tables | Logged per table | `sparse_weight_selection.py` |
| FM-10 | All rows have zero L2 norm (DELTA_NORM mode) | Logged | `weights_delta_update_task_handler.py:2413-2417` |
| FM-12 | Data-parallel table on non-rank-0 silently skipped | **Yes** | `sparse_weight_selection.py:81-84` |

### D. Task Execution Failures (delta prepared but publish fails)

| ID | Failure | Silent? | Code |
|---|---|---|---|
| FM-13 | Exception in handler (quantization/upload/metadata) → FAILURE returned, **no retry** | Logged | `weights_delta_update_task_handler.py:272-276` |
| FM-14 | Task timeout (previous delta not complete) → **current data discarded** | Partial (ODS) | `weights_delta_publisher.py:706-715` |
| FM-15 | Subprocess config missing → immediate FAILURE | Logged | `weights_delta_update_task_handler.py:233-235` |
| FM-16 | Tensor upload to Manifold fails | Caught by FM-13 | `weights_delta_update_task_handler.py:1327-1397` |
| FM-17 | Metadata commit failure (rank 0 only) → data exists but **invisible** | Logged | `weights_delta_update_task_handler.py:1877-1909` |

### E. Item Delta Failures

| ID | Failure | Silent? | Code |
|---|---|---|---|
| FM-18 | Bulk eval returns None → item delta skipped | Logged | `item_delta_publisher.py:410-412` |
| FM-19 | No new items in Scribe stream → empty bulk eval | Implicit | `item_delta_publisher.py:167-190` |
| FM-20 | Item delta publisher not configured → always returns False | **Silent** | `delta_only_publisher.py:127-139` |

### F. Threading / Race Conditions

| ID | Failure | Silent? | Code |
|---|---|---|---|
| FM-21 | Single-threaded executor blocking → trainer loop stalls | No | `weights_delta_publisher.py:124-126` |
| FM-22 | Race between full_pub check and actual full publish start | **Yes** | `weights_delta_publisher.py:677-692` |
| FM-23 | `dist.barrier()` in refresh_state → deadlock if one rank hangs | No (3600s timeout) | `weights_delta_update_task_handler.py:352` |

### G. Design Gaps

| ID | Failure | Code |
|---|---|---|
| FM-28 | No post-publish delivery verification | (absent) |
| FM-29 | ODS monitoring only, no auto-alerting or retry | `weights_delta_publisher.py:710-713` |

### H. Config-Never-Enabled

| ID | Failure | Silent? | Code |
|---|---|---|---|
| FM-30 | `weights_delta_publish_config` is None → WeightsDeltaPublisher never created | **Silent** | `delta_only_publisher.py:58` |
| FM-31 | `train_mode=OFFLINE` on OT job → wrong mode | **Silent** | Config-level |

## Operational Gotcha: Selection Mode + Interval + Rate Limiter

Source: S654102 (IG Reels OmniUV).

`embedding_delta_percentage=1.0` (100%) + `ID_ONLY` selection mode + 2-min publish interval generates too many sparse delta messages. Hedwig's PublishRateLimiter (2 MB/s per `push://model_<id>_sparse` channel) can't drain the queue → publish queue backs up → watchdog kills rank with SIGUSR2 after ~8h of accumulated backpressure → QPS=0.

**Fix:** Switch from `ID_ONLY` to `MOMENTUM` mode with `embedding_delta_percentage=0.1` (10%). Changing interval alone (2→5 min) does NOT fix it — volume at 100% ID_ONLY is the root cause. Validated on sibling job `mvai-training-online-2126644804`. Fix diff: D101908384.

**Triage signal:** If a model uses `ID_ONLY` selection and has periodic SIGUSR2 kills or growing publish queue, check the rate limiter math: `(total_embedding_rows × selection_percentage × row_bytes) / interval` vs rate limit.

## Recurring SEV Patterns

1. **Silent failures** (FM-8, FM-13, FM-28, FM-30): Delta publish errors not propagated to trainer — ATS regresses without alerts
2. **Auth/permission failures** (S613570, S507549): External service throttling/auth breaks delta pipeline
3. **Race conditions** (FM-22, S542714): Timer synchronization and concurrent publish races
4. **NaN corruption** (FM-8, S511666, S505062): Mixed precision quantization produces NaN deltas
5. **FQN mismatches** (S532955, S530172): Architecture refactoring breaks in-place update contracts
6. **Config gaps** (FM-30, FM-31): JKs overlooked, wrong gflags, missing config
7. **External dependencies** (S571298, S507549): Manifold, ATS, Delos failures cascade

## Critical Design Gap: Delete-on-Read

`ModelDeltaTracker.get_unique()` clears tracked rows after read. If the publish fails (FM-13, FM-14, FM-16, FM-17), those rows are **permanently lost** until they're re-accessed in training. No retry mechanism exists.

## Key Code Files

| File | Purpose |
|---|---|
| `minimal_viable_ai/core/publisher/delta_only_publisher.py` | Orchestrator |
| `minimal_viable_ai/core/model_weights_delta_publisher/weights_delta_publisher.py` | Weights delta logic |
| `minimal_viable_ai/core/model_weights_delta_publisher/sparse_weight_selection.py` | Row selection |
| `minimal_viable_ai/core/model_weights_delta_publisher/weights_delta_update_task_handler.py` | Subprocess handler |
| `torchrec/distributed/model_tracker/model_delta_tracker.py` | Row tracking |
| `minimal_viable_ai/core/item_delta_publisher/item_delta_publisher.py` | Item delta |
