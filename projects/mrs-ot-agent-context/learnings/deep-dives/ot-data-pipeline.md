# OT Data Pipeline Reference

End-to-end data flow from user actions to trainer consumption.

## Pipeline Stages

```
[1] User Actions / Shadow Traffic Generator
         ↓ writes events with logging_source tag
[2] Scribe Categories (separate streams per data type)
         ↓ DPP reads via Koski training sets
[3] DPP (assigns to numbered buckets, preprocesses)
         ↓ delivers batches (only for buckets in trainer's list)
[4] Preproc — filter_before_unpack (downsampling, upsampling, ESR-specific logic)
         ↓ filtered batches
[5] Trainer (consumes batches, computes loss per task, logs effective_sample_cnt)
         ↓ publishes deltas/snapshots
[6] Model Store / SilverTorch (serving)
```

## Key Concepts

| Concept | What it is |
|---|---|
| **Scribe Category** | Time-ordered stream (like Kafka topic). Each data type has its own. Independent — one can break without affecting others. |
| **Training Set** | Koski abstraction mapping to a Scribe category. Trainer config specifies which to read. |
| **Logging Source** | Field INSIDE each event. Multiple sources within one training set (e.g., real views vs shadow traffic). |
| **Bucket** | DPP assigns each (training_set, logging_source) pair to a numbered slot. Trainer config has a `buckets` list — unlisted buckets = silent drop. |
| **Partition Filter** | Config string defining which (training_set, logging_source) combos to read. `SC_PARTITION_FILTER` for OT. |
| **filter_before_unpack** | Preproc function (~370 lines) — 6 downsampling scenarios + 4 post-filters. |
| **effective_sample_cnt** | Trainer metric — how many examples each task actually consumed. Definitive "did data reach trainer" signal. |

## Failure Mode Catalog

| # | Failure | Stage | Symptoms | Detection |
|---|---|---|---|---|
| 1 | Shadow traffic generator stops | Source | Zero events in monitoring table | `monitoring_clips_star_search_shadow_uuid` count → 0 |
| 2 | Scribe category down | Scribe | DPP can't read, starvation spikes | DPP dashboard starvation metric |
| 3 | Bucket not in trainer's list | DPP | Zero samples, zero errors, DPP looks healthy | Check `buckets` in `trainer_config.py` |
| 4 | Configerator bucket mapping changed | DPP | Wrong data in wrong bucket or no data | Check `dynamic_partition_category_bucket_mapping_config.cconf` |
| 5 | logging_source_id null in shadow data | Preproc | Examples hit wrong filter branch, get dropped | Check feature values in preproc logs |
| 6 | filter_str mismatch | Preproc | SQL filter doesn't match actual logging_source | Compare filter_str to actual scribe data |
| 7 | Task config missing shadow tasks | Trainer | Loss=0, effective_sample_cnt=0 for shadow tasks | Check task list in model's run_config |

## Key Code Paths

| Component | File |
|---|---|
| Bucket selection | `minimal_viable_ai/models/ig_ranking/*/prod/trainer_config.py` |
| filter_str | `minimal_viable_ai/core/dataloader/dataloader_configs.py` |
| Bucket mapping | `configerator: data_preproc/unified_online/dynamic_partition_category_bucket_mapping_config.cconf` |
| Preproc filtering | `minimal_viable_ai/core/preproc/koski_filtering_utils.py` |
