# Thread Summary: f831018319 T2I holdout MAST STOPPING — incomplete triage (model-id unresolvable)

_Source: spaces/AAQAVOjYc80 thread `iFdQV3t9ux4` · 3 messages · 2026-05-23T19:58–19:59Z_
_Summarized: 2026-05-23 22:50 PT · last-msg-time: 2026-05-23T19:59Z_

## What was discussed

Bot filed a triage for SEV 667565 (xtliao / Instagram Feed T2I holdout): model identifier `f831018319` returned "not found" via `ai.model-series` and MAST lookup. Error pattern was "Timeout of 2100s exceeded in state STOPPING" (a job stuck in MAST STOPPING, preventing restart and causing publish staleness). Bot invoked the model-id guard and correctly degraded to `NEEDS_INVESTIGATION / confidence: low` rather than fabricating a root cause. SEV overview was empty 56 minutes post-open.

## Key decisions made

- [2026-05-23T19:59Z] Bot correctly punted: `f831018319` is likely a publish-pipeline-internal flow/snapshot ID (not a model entity ID), the `mvai-training-online-831018319` MAST job doesn't exist, and the gchat space (AAQAr5vdd9E) had 0 messages. No action taken.
- [2026-05-23T19:59Z] This is xtliao's SEV on Instagram Feed — out of MRS PE scope unless escalated. Bot standing by for re-triage on next cron pass if xtliao populates the SEV overview with a valid model entity ID + STUS job name.

## Files / artifacts touched

| path | what changed |
|---|---|
| SEV 667565 | Opened by xtliao; no bot action taken |

## Cluster / pattern references

_(Model-id unresolvable — cannot map to a cluster with confidence. MAST STOPPING timeout is surface-level consistent with [CL-001] snapshot-stuck but root mechanism unverified.)_

## Followup items (not yet done)

_(No explicit followup discussed — bot degraded cleanly and is waiting on xtliao to populate SEV overview.)_

## Cross-refs

- SEVs discussed: S667565
- Posts: none
- Related threads: none
