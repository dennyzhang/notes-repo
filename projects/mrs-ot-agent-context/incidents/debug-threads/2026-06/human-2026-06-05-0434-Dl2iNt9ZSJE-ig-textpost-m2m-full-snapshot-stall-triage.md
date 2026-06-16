---
name: Dl2iNt9ZSJE-ig-textpost-m2m-full-snapshot-stall
description: Root cause triage of ig_textpost_feed_m2m_retrieval FULL_SNAPSHOT stall; bot initially proposed a wrong detector fix; human self-correction
metadata:
  type: project
  human_involved: true
---

# Thread Summary: ig_textpost_feed_m2m_retrieval FULL_SNAPSHOT stall — root cause + wrong detector proposal retracted

_Source: spaces/AAQAVOjYc80 thread `Dl2iNt9ZSJE` · 33 messages · 2026-06-05T11:34–12:17 UTC_
_Summarized: 2026-06-05 04:50 PT · last-msg-time: 2026-06-05T12:17:49Z_

## What was discussed

Denny asked the bot to execute "Next actions" from a prior cron triage and answer why the alert fired 16.4h late instead of 1.3h. The bot investigated `ig_textpost_feed_m2m_retrieval` (MAST job 2130324780): confirmed trainer healthy (SPARSE/DENSE fresh), FULL_SNAPSHOT dead since 2026-06-04 16:29:36 PDT. Root: active S663485 (MPZCH enablement on Threads T2I SilverTorch Publishing). The bot also initially claimed the detector (R23) was miscalibrated (widened to ~7.5h) — then, when trying to author the fix diff, discovered via configerator source that the pager threshold is already 180m/270m (correctly calibrated), and retracted the proposal.

## Key decisions made

- **Trainer healthy, SilverTorch publish path broken** (2026-06-05T11:38 UTC): deltas-alive + full-dead → STUS/SilverTorch corpus rebuild stopped, not the trainer. Confirmed by logs and instance history.
- **ITEM_EMB_DELTA stopped ~4.5h before alert** (validator catch, 2026-06-05T11:48): bot initially overstated item-emb as fresh; validator caught it. Item-emb stream feeds the corpus the SilverTorch rebuild indexes.
- **"Why 16.4h late" → NOT a detector bug** (Denny self-correction, 2026-06-05T12:17 UTC): bot claimed R23 widened the pager to ~7.5h cadence → wrong. Configerator shows `FULL_SNAPSHOT = 180m MAJOR / 270m CRITICAL` unchanged since 2026-03-27. The 16.4h gap is likely a routing artifact (fast pager goes to `p92_relevance_retrieval`, not MRS OT; what MRS OT saw at 02:08 was a later/AGG alert). No diff to land.

## Files / artifacts touched

| path | what changed |
|---|---|
| N/A | Read-only triage; no files written |

## Cluster / pattern references

_(Omitted — cluster IDs not verified against failure-patterns.md)_

## Followup items (not yet done)

1. Confirm whether the 3h fast pager (180m MAJOR) fired to `p92_relevance_retrieval` at ~19:29 PDT 06-04 and MRS OT only received the later AGG alert — closes the "16.4h" question definitively. (Owner: Denny / p92; unresolved as of thread close)

## Cross-refs

- SEVs discussed: S663485 (MPZCH Threads T2I SilverTorch Publishing, In Progress L4), S665454
- Related threads: `Bjipz5nNjzw` (detector fix diff for a sibling model, authored same day)
