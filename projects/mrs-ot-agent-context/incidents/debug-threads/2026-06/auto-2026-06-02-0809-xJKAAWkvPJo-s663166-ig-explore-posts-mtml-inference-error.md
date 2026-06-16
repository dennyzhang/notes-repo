---
human_involved: false
thread_id: xJKAAWkvPJo
thread_name: spaces/AAQAVOjYc80/threads/xJKAAWkvPJo
msg_count: 3
date_range: 2026-06-02 08:09–08:12 PDT
summarized: 2026-06-03 10:43 PDT
last_msg_time: 2026-06-02T15:12:07Z
---

# Thread Summary: S663166 — IG Explore Posts MTML Inference Error Rate (Bad Task)

_Source: spaces/AAQAVOjYc80 thread `xJKAAWkvPJo` · 3 messages · 2026-06-02 08:09–08:12 PDT_
_Summarized: 2026-06-03 10:43 PT · last-msg-time: 2026-06-02T15:12:07Z_

## What was discussed

Postmortem digest for S663166 (mrs_online_training, L3, Closed after 20 days): ig_explore_posts_mtml baseline (model 2131550324) saw elevated inference error rate; a bad task/host was identified and preempted; error rate recovered in ~1h 12m. Two validators confirmed the digest with one minor clarification about follow-up tasks.

## Key decisions made

- Root cause: bad task/host → preempt → recovery (2026-06-02T15:09:32Z). Postmortem sparse; no specific failure mechanism documented beyond "bad task."
- No new P-row warranted: pattern is in the ig_predictor serving path, not OT training path; insufficient specificity for a P-row without failure mode details.
- Follow-up task note: T271942775 exists but is an auto-generated nagbot "missing fields" task (closed when report completed), not a substantive bad-host investigation task — bad-host investigation ongoing without a linked task.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — postmortem digest output only) | — |

## Cluster / pattern references

(omitted — no verified cluster IDs)

## Followup items (not yet done)

(none — investigation of automated bad-host preemption noted as ongoing per SEV owner; no explicit follow-up tracked)

## Cross-refs

- SEVs discussed: S663166
- Posts: (none)
- Related threads: (none)
