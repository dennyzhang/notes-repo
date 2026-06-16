# Thread Summary: SilverTorch SEV Tag Classifier in OT Monitors

_Source: spaces/AAQAVOjYc80 thread `BvPAmLCNmyk` · 52 messages · 2026-05-27 22:16–22:56 PT_
_Summarized: 2026-06-01 03:45 PT · last-msg-time: 2026-05-27T22:56:12Z_

## What was discussed

Denny requested building a training-stack classifier that identifies whether an OT SEV belongs to MVAI or SilverTorch, and automatically applies the `mrs-online-training-silvertorch` SEV tag when appropriate. The bot built the signal (`application_metadata.distributed_ai_stack` field), added it to both ot-sev-monitor and ot-alert-monitor, then ran a 7-day backtest across 34 SEVs and backfilled existing SEVs. Culminated in fbcode diff D106571152 covering ot-sev-monitor.md + ot-alert-monitor.md.

## Key decisions made

- [22:19:42] Add `training_stack` field (MVAI/SILVERTORCH/unknown) to both monitor diagnosis JSONs and verdict headers; primary signal = `application_metadata.distributed_ai_stack`.
- [22:28:04] Add title-prefix fallback (`^\[silvertorch/` → SILVERTORCH, `^\[mvai/` → MVAI) with new `training_stack_source` audit field.
- [22:28:33] Create fbcode diff for silvertorch SEV identification (became D106571152).
- [22:32:50] Backfill ALL existing OT SEVs under `mvai-online-training` tag for silvertorch classification; S666632 (`fbr_hstu`) confirmed as the only clear silvertorch SEV in 7d backtest.

## Files / artifacts touched

| path | what changed |
|---|---|
| notes/.../cron-jobs/ot-sev-monitor.md | `training_stack` field + silvertorch tag logic + title-prefix fallback |
| notes/.../cron-jobs/ot-alert-monitor.md | same changes mirrored |
| fbcode (D106571152) | 16+/6- silvertorch-identification diff on remote/master |

## Cluster / pattern references

_(failure-patterns.md not found — cluster IDs omitted)_

## Followup items (not yet done)

_(none explicit — D106571152 submitted, S666632 backfilled, notes→sqlite parity verified)_

## Cross-refs

- SEVs discussed: S666632
- Diffs: D106571152
