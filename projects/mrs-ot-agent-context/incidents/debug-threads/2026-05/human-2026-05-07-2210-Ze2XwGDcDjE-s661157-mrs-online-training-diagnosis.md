---
human_involved: true
---
# Thread Summary: S661157 — ig_textpost_tifu u2m model, no full snapshots since 14:10 PT

_Source: spaces/AAQAVOjYc80 thread `Ze2XwGDcDjE` · 5 messages · 2026-05-07 22:10 – 2026-05-07 23:23 PT_
_Summarized: 2026-06-02 14:43 PT · last-msg-time: 2026-05-08T06:23Z_

## What was discussed

S661157 was active on mrs_online_training rotation: `ig_textpost_tifu_u2m_neg_sampling_retrieval` (m2128360468) not deploying full snapshots since ~14:10 PT. Bot triage identified delta snapshots as healthy but all 20 recent instances were ITEM_EMB_DELTA only (no FULL type), suggesting the full-snapshot generation job had stopped. Operator corrected that triage was too shallow — bot should have used the OT reliability skill to discover the root training job was dead and not producing checkpoints.

## Key decisions made

- **`[2026-05-08T05:55Z]` Triage depth insufficient** — operator instructed bot to call OT reliability skill, which would have shown the training job was dead (not just absence of snapshots in registry).
- **`[2026-05-08T06:19Z]` SEV gchat monitoring gap** — operator flagged a monitoring gap in the SEV chat and directed bot to confirm it, then create a fix diff.
- **`[2026-05-08T06:23Z]` File meta task + create diff** — operator confirmed both: file a task and create a diff for the monitoring gap fix.

## Files / artifacts touched

| path | what changed |
|---|---|
| (unknown — diff creation directed but not completed in thread) | fix for monitoring gap identified in S661157 SEV chat |

## Cluster / pattern references

_(no verified cluster IDs — omitted)_

## Followup items (not yet done)

1. Confirm monitoring gap from SEV gchat (AAQAGEO8rZI) — operator-flagged, bot directed to verify
2. Create fix diff for monitoring gap (fbcode or configerator TBD)
3. File meta task tracking the monitoring gap fix

## Cross-refs

- SEVs discussed: S661157
- Related threads: `hr9gJ5DUFXs` (same SEV, deeper investigation continuation, 2026-05-08 11:40 PT)
