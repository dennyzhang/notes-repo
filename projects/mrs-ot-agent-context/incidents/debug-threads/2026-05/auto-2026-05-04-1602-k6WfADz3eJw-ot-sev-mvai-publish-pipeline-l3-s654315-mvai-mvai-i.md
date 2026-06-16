---
name: k6WfADz3eJw-s654315-mvai-publish-pipeline-pg-deadlock
description: Deep triage of S654315 MVAI IFR online_train_publish TGIF hang; PG-creation deadlock; validator confirmed
metadata:
  type: thread_summary
  human_involved: false
---

# Thread Summary: S654315 — MVAI IFR online_train_publish TGIF async publish hang

_Source: spaces/AAQAVOjYc80 thread `k6WfADz3eJw` · 3 messages · 2026-05-04_
_Summarized: 2026-06-02 08:43 PT · last-msg-time: 2026-05-04T23:07:27Z_

## What was discussed

Denny forwarded the alert for S654315 (mvai_publish_pipeline, L3). The bot did a full deep triage, confirming 33 consecutive APPLICATION_FAILUREs (R9172.1–R9357.2, ~9.4 days). Root cause: latent `tgif_publisher.py` rank-0 IENWeightProcessing PG-creation deadlock amplified from intermittent to ~100% by D88207631 (MPZCH submodule count increase) + D101678676 (MC11/BS512 harness). Mitigation R9381.2 succeeded 2026-05-01; underlying bug unfixed. An independent validator re-ran all ground-truth queries and confirmed the diagnosis, noting only that S654316 separation was confirmed via `detection_narrative` field rather than overview.

## Key decisions made

- [2026-05-04T23:02:51Z] Root cause confirmed: PG-init deadlock, not IEN package issue (S654315 ≠ S654316).
- [2026-05-04T23:02:51Z] Forward fix requires gyin (D80755557 — original PG-init fix, never landed) before relanding D88207631 + D101678676. Tracked via T269178426.
- Auto-tag applied: `mvai-online-training` confirmed by sevmanager.

## Files / artifacts touched

| path | what changed |
|---|---|
| tgif_publisher.py (mvai codebase) | PG-creation deadlock — forward fix still needed |

## Cluster / pattern references

_(omitted — cluster IDs not verified against failure-patterns.md)_

## Followup items (not yet done)

_(none explicit — next steps documented in triage: contact gyin, track T269178426, verify no new failures post-R9381.2)_

## Cross-refs

- SEVs discussed: S654315, S658142 (same conveyor, packaging regression), S657606 (Threads OT colocation block)
