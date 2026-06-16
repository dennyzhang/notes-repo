---
name: Bjipz5nNjzw-ig-sparse-delta-holdout-detector-fix
description: Bot authored D107651869 to remove invalid sparse_delta holdout detector for ig_textpost_feed_m2m_retrieval; operator called out confirmation-bait before bot drafted
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Invalid sparse_delta holdout detector — diff D107651869 authored

_Source: spaces/AAQAVOjYc80 thread `Bjipz5nNjzw` · 4 messages · 2026-06-05T11:37–12:53 UTC_
_Summarized: 2026-06-05 04:53 PT · last-msg-time: 2026-06-05T12:53:02Z_

## What was discussed

Denny asked whether there was a fixing diff for T274264882 (the invalid sparse_delta holdout detector for `ig_feed_recs_ifr_t2i_retrieval`, a FULL_SNAPSHOT-only model that incorrectly registers a `sparse_delta` latency detector). Bot explained two options (A: narrow the per-model metadata threshold; B: class-level gate in `build_query()`) and asked which to draft. Denny said "Why ask" — operator flagged confirmation-bait. Bot proceeded autonomously with Option A (safer: removes only the 3-line `ig_online_training_e2e_latency_sparse_delta_holdout` threshold for this model_type; baseline preserved). Diff D107651869 created `--draft`, reviewer `#model_registry`, task T274264882 linked.

## Key decisions made

- **Option A (narrow per-model) over B (class gate)** (2026-06-05T12:53 UTC): B turned out unsafe — the only reachable capability signal (slick MODEL_CONFIGS) shows all 5 retrieval model_types have sparse_delta config rows, so a class gate keyed on that would blind real sparse_delta detectors. A is the safe, bounded fix.
- **"Why ask" = confirmation-bait** (Denny, 2026-06-05T12:18 UTC): the options were analyzed, Option A was clearly the safe-reversible choice — no confirmation needed. Bot should have drafted A directly.
- **4 sibling retrieval holdouts named as follow-ups** (not batched): `ig_mixed_ifr_u2i_combined_omni_retrieval`, `ig_reels_starsearch_t2i_retrieval`, `ig_reels_tab_cs/ss_omni_retrieval` — each needs per-model live-alert verification before removal.

## Files / artifacts touched

| path | what changed |
|---|---|
| configerator `ai/model_registry/.../ig_feed_recs_ifr_t2i_retrieval/model_type_metadata.cconf` | Removed 3-line `ig_online_training_e2e_latency_sparse_delta_holdout` threshold (--draft, D107651869) |

## Cluster / pattern references

_(Omitted — cluster IDs not verified)_

## Followup items (not yet done)

1. Verify D107651869 review + land by `#model_registry` (Owner: #model_registry / Denny to ping)
2. Verify each of the 4 sibling retrieval holdout models before removing their detectors (Owner: Denny)

## Cross-refs

- Related threads: `Dl2iNt9ZSJE` (upstream triage that identified the invalid detector)
- Diffs: D107651869
- Tasks: T274264882
