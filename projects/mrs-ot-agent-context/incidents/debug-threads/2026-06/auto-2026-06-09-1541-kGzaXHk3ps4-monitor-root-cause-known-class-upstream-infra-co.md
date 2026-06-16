---
human_involved: false
---

# Thread Summary: ig_reels_starsearch_t2i_retrieval scribe lag — P-017 cascade task filed

_Source: spaces/AAQAVOjYc80 thread `kGzaXHk3ps4` · 3 messages · 2026-06-09 15:41–15:46 PT_
_Summarized: 2026-06-10 01:04 PT · last-msg-time: 2026-06-09T22:46:20Z_

## What was discussed

The ot-alert-monitor cron triaged a MAJOR alert on model 2145491885 (ig_reels_starsearch_t2i_retrieval holdout) — scribe_read_proxy.client_lag_in_seconds threshold crossed at 14:59 PT. Cron matched it to S667358 (IG T20 H100 Scribe quota, open 18 days) and confirmed publishing is still fresh (latest SPARSE_DELTA 15:22:36 PT). The bot then acted on P-017 instead of re-narrating: this is the textbook recurring+upstream case, so it filed a decisive-metric task instead of leaving it as a per-model watch item.

## Key decisions made

- [2026-06-09T22:46:04Z] This alert is MONITOR / no OT action — model still publishing fresh (SPARSE_DELTA valid 22 min post-violation-start). S667358 is the upstream cause, owned by IG Relevance oncall.
- [2026-06-09T22:46:20Z] Filed T275196444 (P-017 task, owner=dennyzhang) to track the entire S667358/S668542 scribe cascade as one metric: count of OT models with active scribe lag, split lag-but-fresh vs actually-publishing-behind. Acceptance test: count → 0 when S667358 mitigates.

## Files / artifacts touched

| path | what changed |
|---|---|
| — | read-only triage + task filing; no notes files modified |

## Cluster / pattern references

- [CL-003] — scribe lag on IG retrieval model; prior incidents 2026-05-19 (S660677, S659877) on same model_id

## Followup items (not yet done)

1. T275196444 — track S667358/S668542 cascade metric; auto-closes when cascade clears. Owner: dennyzhang.

## Cross-refs

- SEVs: S667358 (IG T20 H100 Scribe quota, in-progress), S668542 (related)
- Alert: model 2145491885, violation_start=1781043316
