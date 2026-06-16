# Thread Summary: Model 2134319967 (ig_organic_feed_mtml baseline) — P02/P48 TGIF Publish Deadlock, 9-Attempt Pattern

_Source: spaces/AAQAVOjYc80 thread `jJ-go695RTY` · 3 messages · 2026-05-15T17:27–17:28 UTC_
_Summarized: 2026-05-16 14:31 PT · last-msg-time: 2026-05-15T17:28:58Z_

## What was discussed

OT alert triage: model 2134319967 (ig_organic_feed_mtml baseline). Scribe sparse-delta e2e latency alert at 06:09 UTC May 15. Model has 9 attempt failures since v37 launched 2026-05-02. Root cause confirmed: P02/P48 — TGIF in-trainer publish deadlock. att7 ran 62h before failing with StuckJobException MODEL_PUBLISHING on rank 61; `tgif_publisher.py:525 future.result(timeout_secs)` blocked indefinitely. att8 auto-started and running healthy. Validator pass confirmed all error verbatim claims.

## Key decisions made

- (2026-05-15T17:27:51Z) Root cause: P02/P48 TGIF publish deadlock; `timeout_secs` in publisher config likely exceeds 600s SJD hard limit, so SJD fires first
- (2026-05-15T17:27:51Z) Cross-ref with S664099 (B200/maz NCCL issue) warranted — same hardware/region, possible infra contribution to 9-attempt instability
- Confidence: symptom-attribution 90%, root-cause 78%

## Files / artifacts touched

_(None — read-only triage.)_

## Cluster / pattern references

- [CL-004] — conveyor/cogwheel publish failures; P02/P48 TGIF timeout is a sub-class of the publish-failure cluster
- [CL-006] — MAST scheduling/capacity as silent root; B200/maz infra (S664099) is a potential contributing factor to the 9-attempt pattern
- P02 / P48 [VERIFIED] — TGIF in-trainer publish deadlock; `tgif_publisher.py:525` is the confirmed callsite

## Followup items (not yet done)

1. Verify `timeout_secs` in `minimal_viable_ai/core/ranking_common/tgif_publisher.py:~525` is < 600s SJD hard limit — unresolved
2. Cross-ref with S664099 owner (B200/maz NCCL team) to rule out infra as contributing factor — unresolved
3. Monitor att8 for >24h without MODEL_PUBLISHING stall to confirm P02 resolved for this cycle

## Cross-refs

- SEVs discussed: S664099 (B200/maz NCCL ALLTOALL_BASE timeout — inferred co-factor, not confirmed)
- Owners: wenkai (primary), ig_feed_modeling, MAST rsoares27
- Related threads: `0DnwCD0cCII`, `kvLe-AJYdn0` (concurrent triage session — three different root causes)
