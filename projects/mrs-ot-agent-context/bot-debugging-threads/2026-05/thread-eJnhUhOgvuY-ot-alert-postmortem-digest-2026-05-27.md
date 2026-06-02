# Thread Summary: OT Alert Postmortem Digest 2026-05-27

_Source: spaces/AAQAVOjYc80 thread `eJnhUhOgvuY` · 3 messages · 2026-05-28 04:28–04:30 PT_
_Summarized: 2026-06-01 03:45 PT · last-msg-time: 2026-05-28T04:30:40Z_

## What was discussed

Automated alert postmortem digest for 2026-05-27: 2 alerts cleared. A1009946182010606 (ig_textpost_feed_m2m_retrieval STUS model 2130324780, FULL_SNAPSHOT missing, ~7d open, acked-only resolution) and A27534791649462484 (facebook_reels_ifu_i2i model 2132070936, FULL_SNAPSHOT, ~3.5h, acked-only). Validator was unavailable in cron context so digest published unvalidated. Third message included top-3 noisy model rankings (models 2130305043, 2144816217, 2130324780).

## Key decisions made

- [04:28:17] Two alerts archived: A1009946182010606 → `incidents/resolved-alerts/2026-05/critical-2026-05-22-A1009946182010606.md` (existing, not overwritten); A27534791649462484 → `incidents/resolved-alerts/2026-05/critical-2026-05-27-A27534791649462484.md` (new).

## Files / artifacts touched

| path | what changed |
|---|---|
| notes/.../incidents/resolved-alerts/2026-05/critical-2026-05-27-A27534791649462484.md | new postmortem archive created |

## Cluster / pattern references

_(failure-patterns.md not found — cluster IDs omitted)_
- A1009946182010606: hypothesis = DPP DataClientStuckException on getNextBatch (v47 died 2026-05-27 00:26 UTC); v48 RUNNING live.
- A27534791649462484: hypothesis = upstream reranker 2125081901 stall blocked FULL_SNAPSHOT 8h+ (recurring pattern per S667567).

## Followup items (not yet done)

_(none explicit — both alerts acked-only; lupaul requested to confirm/correct archive entries)_

## Cross-refs

- SEVs discussed: S667567 (prior similar pattern reference)
- Alerts: A1009946182010606, A27534791649462484, A1392856276009518 (excluded — ig_feed_retrieval out of scope)
