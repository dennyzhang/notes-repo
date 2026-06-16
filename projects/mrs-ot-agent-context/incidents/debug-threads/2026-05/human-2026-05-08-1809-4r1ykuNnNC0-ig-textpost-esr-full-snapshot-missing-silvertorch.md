---
name: ig-textpost-esr-full-snapshot-missing-silvertorch
description: ig_textpost_feed_esr m2133142909 FULL_SNAPSHOT missing 9.6h+; bot missed SilverTorch architecture — operator corrected multiple times
metadata:
  type: project
  thread_id: "4r1ykuNnNC0"
  space: spaces/AAQAVOjYc80
  human_involved: true
---

# Thread Summary: ig_textpost_feed_esr — FULL_SNAPSHOT Missing (SilverTorch OT Job)

_Source: spaces/AAQAVOjYc80 thread `4r1ykuNnNC0` · 8 messages · 2026-05-08–05-09_
_Summarized: 2026-05-08 18:09–19:25 PT · last-msg-time: 2026-05-09T02:25:04Z_

## What was discussed

Alert: ig_textpost_feed_esr model 2133142909 missing FULL_SNAPSHOT for 9.6h. Bot diagnosed a trainer-side scheduling issue; operator corrected repeatedly that this is a SilverTorch (STUS) OT job — no trainer, STUS is downstream. Bot also failed to explain WHY the full snapshot wasn't generating (only confirmed the gap, not the mechanism) and did not surface that the alert fired 9.6h after the gap opened (alert cadence failure).

## Key decisions made

- **Bot's initial hypothesis was wrong (2026-05-09T01:22):** "in-process trainer scheduler stuck" — FALSIFIED by operator: this is a SilverTorch OT job, there is NO trainer. STUS is the downstream publisher.
- **Operator rule established (2026-05-09T02:25):** "check the model architecture first" before triage — SilverTorch OT jobs require different diagnosis path than standard MVAI OT jobs.
- **Alert cadence gap:** FULL_SNAPSHOT stopped at ~07:42 UTC (00:42 PT), alert fired at ~17:20 PT = 16.6h gap (validator noted UTC/PT mismatch in bot's reported 9.6h). Alert should fire within 1-2h of missing snapshot.
- **Operator action (2026-05-09T02:02):** file a meta task to improve alert cadence.

## Files / artifacts touched

| path | what changed |
|---|---|
| OneDetection alert | mrs_online_training, "Publishing Stability" |
| MAST job mvai-training-online-2133142909 | v18 att-0 RUNNING — not the failure point |
| Snapshots | last FULL_SNAPSHOT 07:42 UTC, subsequent deltas (SPARSE_DELTA, ITEM_EMB_DELTA) healthy |

## Cluster / pattern references

_(No existing cluster ID confirmed — new pattern: SilverTorch OT jobs have no trainer; bot must check model architecture first before applying standard trainer-centric diagnosis path.)_

## Followup items (not yet done)

1. File meta task: improve alert cadence for FULL_SNAPSHOT missing — should page within 1-2h, not 16h.
2. OT agent improvement: add SilverTorch model detection step (check model type via `meta ai.model-series`) before hypothesizing trainer-side root causes.

## Cross-refs

- SEVs discussed: S661169 (L3, AMD hardware rejects IG MTML snapshots — different model, possible FULL_SNAPSHOT infra overlap)
- Related threads: none
