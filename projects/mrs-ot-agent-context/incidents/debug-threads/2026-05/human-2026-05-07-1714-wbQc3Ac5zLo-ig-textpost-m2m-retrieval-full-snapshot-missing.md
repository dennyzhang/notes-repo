---
name: wbQc3Ac5zLo
human_involved: true
type: human
date: 2026-05-07
---

# Thread Summary: IG ig_textpost_feed_m2m_retrieval FULL_SNAPSHOT Missing Triage

_Source: spaces/AAQAVOjYc80 thread `wbQc3Ac5zLo` · 5 messages · 2026-05-07–08_
_Summarized: 2026-06-02 13:43 PT · last-msg-time: 2026-05-08T01:23Z_

## What was discussed

Bot triaged an alert for model `ig_textpost_feed_m2m_retrieval` (model ID 2130324780) showing 0/30 FULL_SNAPSHOT instances with all deltas healthy. Root cause identified: SilverTorch `FreshIndexInitializer` kmeans assertion at `fresh_index_initializer.py:91` requires ≥64,077 embeddings but only found 6,740 — blocking FULL_SNAPSHOT while deltas pass unaffected. Validator confirmed with one minor sourcing discrepancy (verified via error API). Alert auto-mitigated, but operator flagged the underlying issue as real and asked for a meta task with improvement suggestions and a polished user post for sharing.

## Key decisions made

- [2026-05-08T01:16Z] Despite auto-mitigation, root cause (kmeans threshold vs actual embedding count) is real — track in meta task
- [2026-05-08T01:22Z] Task must be concise, show critical details for SilverTorch oncall, include MAST log link
- [2026-05-08T01:23Z] Polish task as a user post for easy sharing

## Files / artifacts touched

| path | what changed |
|---|---|
| fbcode/silvertorch/experimental/realtime/fresh_index_initializer.py:91 | FreshIndexInitializer kmeans min-embedding assertion — identified as root cause, no code change |
| (meta task, id not captured) | Created for SilverTorch kmeans threshold follow-up |

## Cluster / pattern references

- [CL-001] — FULL_SNAPSHOT missing / snapshot-stuck pattern; here caused by kmeans assertion rather than publish deadlock

## Followup items (not yet done)

1. SilverTorch oncall: confirm whether `n_min_embeddings_required=64077` is configurable per-model — owner: ronghuang + p92_relevance_retrieval_oncall, status: task created
2. Confirm if FULL_SNAPSHOT is expected for this model (may be delta-only by design — would make alert a false-positive)

## Cross-refs

- SEVs discussed: S660677 (in-progress, explore retrieval publish delay)
- Alert: model 2130324780 FULL_SNAPSHOT missing (auto-mitigated)
