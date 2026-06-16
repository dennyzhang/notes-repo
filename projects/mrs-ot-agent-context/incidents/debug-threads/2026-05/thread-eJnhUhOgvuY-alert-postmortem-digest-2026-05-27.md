# Thread Summary: OT Alert Postmortem Digest 2026-05-27

_Source: spaces/AAQAVOjYc80 thread `eJnhUhOgvuY` · 3 messages · 2026-05-28T04:28–04:30Z_
_Summarized: 2026-05-29 00:46 PT · last-msg-time: 2026-05-28T04:30:40Z_

## What was discussed

The ot-alert-postmortem-digest cron reported two alerts cleared in the prior 24h and published postmortem digests for each, plus a top-3 noisy model ranking for the last 7 days.

## Key decisions made

- A1009946182010606 (ig_textpost_feed_m2m_retrieval model 2130324780 missing FULL_SNAPSHOT): Resolution signal acked_only — v48 RUNNING ~18.6h with 0 FULL_SNAPSHOT (STUS cadence 7.5h → overdue 2+ cycles). Hypothesis: STUS v47 died 2026-05-27 00:26 UTC via DPP DataClientStuckException. Archive at `incidents/resolved-alerts/2026-05/critical-2026-05-22-A1009946182010606.md` (existing richer, not overwritten).
- A27534791649462484 (facebook_reels_ifu_i2i model 2132070936 missing FULL_SNAPSHOT): acked_only — MAST v70 RUNNING, 0 FULL_SNAPSHOT in 20 instances. Prior S667567 pattern (upstream reranker 2125081901 stall). New archive written.
- Validator unavailable (no Agent tool in cron context) at 2026-05-28T04:30Z — digest published unvalidated.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-alerts/2026-05/critical-2026-05-22-A1009946182010606.md` | existing, not overwritten |
| `incidents/resolved-alerts/2026-05/critical-2026-05-27-A27534791649462484.md` | new archive written |

## Cluster / pattern references

_(No CL- clusters defined yet.)_

- ig_textpost_feed_m2m_retrieval (2130324780): DPP DataClientStuckException → STUS cadence miss — recurring pattern

## Followup items (not yet done)

_(No explicit followups discussed in thread.)_

## Cross-refs

- SEVs discussed: S667567
- Posts: none
- Related threads: none
- Top noisy models flagged: 2130305043 (4 alerts), 2144816217 (4 alerts), 2130324780 (3 alerts), 886797001 (3 alerts)
