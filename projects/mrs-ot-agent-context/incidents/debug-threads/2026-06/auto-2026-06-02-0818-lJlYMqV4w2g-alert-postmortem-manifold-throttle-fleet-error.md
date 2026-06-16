---
name: alert-postmortem-manifold-throttle-fleet-error
description: Alert postmortem digest — A978986517964596 (Manifold shard throttle / 27.5h snapshot gap) + A2398498093914274 (fleet MAST error rate during OT SEV storm)
metadata:
  type: project
  thread_id: lJlYMqV4w2g
  human_involved: false
  summarized_at: "2026-06-02 23:43 PDT"
---

# Thread Summary: Alert postmortem digest — Manifold throttle + fleet MAST error rate

_Source: spaces/AAQAVOjYc80 thread `lJlYMqV4w2g` · 8 messages · 2026-06-02 08:18 PDT_
_Summarized: 2026-06-02 23:43 PDT · last-msg-time: 2026-06-02T15:18:54Z_

## What was discussed

ot-alert-postmortem cron published digest for two resolved alerts. All messages in thread are cron output; no operator interaction. The thread also includes pattern proposals and a note that the validator was unavailable (no Agent tool in cron context).

**A978986517964596** (high, ~21.6h): facebook_reels_vdd_hstu_v0 model 877766818 missing FULL_SNAPSHOT for 27.5h. Root: DCPTraitsWrapperException `kClientShardSizeThrottled` on ranks during DCP FULL_SNAPSHOT checkpoint write. Auto-recovered when v7 restarted (Jun 1 11:13 UTC). Resolution verified: FULL_SNAPSHOT 6572 published 2026-06-01T02:42Z.

**A2398498093914274** (critical, 108 min): Fleet `online_training_app_error_rate` spike (entity=mast_hpc_job_run_status). Root: Fleet-level ATS surge from cascading HPC_TASK_GROUP_APPLICATION_FAILURE across mrs_online_training jobs during concurrent OT SEV storm (10 active OT SEVs + 23 ZippyDB + 16 Scribe). Lagging indicator; self-resolved. Prior recurrence: 2026-05-26 (75 min).

## Key decisions made

- New P-row candidate from A978986517964596: Manifold per-shard throttle during DCP checkpoint write → multi-hour snapshot gap → auto-recovers on restart. Count: 1 (needs ≥3 for promotion). Logged to learnings-ledger. (2026-06-02T15:18:32Z message)
- P-fleet-error-rate pattern from A2398498093914274: fleet ATS surge during OT+infra SEV storm; 2 confirmed instances; self-resolves. No OT action needed during event. (2026-06-02T15:18:32Z message)
- Validator unavailable in cron context — digest published unvalidated (2026-06-02T15:18:46Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| ~/notes/.../resolved-alerts/2026-06/high-2026-06-02-A978986517964596.md | archived |
| ~/notes/.../resolved-alerts/2026-06/critical-2026-06-02-A2398498093914274.md | archived |

## Cluster / pattern references

_(section omitted — no verified CL-NNN cited)_

## Followup items (not yet done)

_(none — both alerts auto-resolved; pattern candidates logged but not yet promoted)_

## Cross-refs

- Alerts: A978986517964596, A2398498093914274
- Models: 877766818 (facebook_reels_vdd_hstu_v0)
- Related: A2398498093914274 prior recurrence 2026-05-26
