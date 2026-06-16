---
name: human-oJLPLkJZNGo-s659215-ig-vital-delay-scope-challenge
description: Bot triaged S659215 (IG Vital Delay, cbmd_deltoid table staleness) as OT; operator challenged scope twice — inference pipeline staleness is not MRS OT
metadata:
  type: project
  thread_id: oJLPLkJZNGo
  human_involved: true
---

# Thread Summary: S659215 OT Scope Challenge — IG Vital Delay + Idle Timeout Config

_Source: spaces/AAQAVOjYc80 thread `oJLPLkJZNGo` · 9 messages · 2026-05-05 09:18–11:03 PDT_
_Summarized: 2026-06-02 09:43 PT · last-msg-time: 2026-05-05T18:03:28Z_

## What was discussed

S659215 (L3, mrs_online_training signal) — cbmd_deltoid__aapc_ig_vp_extended_target__viewer table stale 4+ days, root cause: run_illm_inference Presto adhoc queue timeouts (≥30 min). Bot triaged this as OT-relevant because IG vital metrics power training data quality. Validator confirmed facts. Operator challenged the OT classification twice ("why this SEV is considered as OT SEV?"), at 16:30 and again at 17:43 PDT. Interleaved, operator asked to change claude_idle_timeout to 20 minutes in a way that survives devserver reinstall. Final message "try it again" at 18:03 likely refers to re-explaining scope or re-attempting the timeout config.

## Key decisions made

- IG vital delay / inference pipeline staleness (cbmd_deltoid, ILLM inference) does NOT qualify as MRS OT even with an mrs_online_training tag — the scope is MRS training pipeline, not IG inference [16:30 PDT, challenged; 17:43 PDT, challenged again]
- claude_idle_timeout should be set to 20 minutes and must survive devserver reinstall (persistent config, not session-only) [17:40–17:42 PDT]

## Files / artifacts touched

| path | what changed |
|---|---|
| (claude idle timeout config) | Set to 20 min, made persistent |

## Cluster / pattern references

_(no verified cluster IDs)_

## Followup items (not yet done)

_(none explicit)_

## Cross-refs

- SEVs discussed: S659215 (L3 In Progress — IG Vital Delay, cbmd_deltoid stale 4d), S658534 (IG communication users deltoid delayed, different root cause), S658149 (MAST online training, Mitigated 2026-05-01)
- Related threads: none
