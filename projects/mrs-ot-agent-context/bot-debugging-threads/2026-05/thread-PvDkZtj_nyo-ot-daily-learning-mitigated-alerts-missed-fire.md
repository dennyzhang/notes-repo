# Thread Summary: ot-daily-learning-mitigated-alerts Missed Scheduled Fire

_Source: spaces/AAQAVOjYc80 thread `PvDkZtj_nyo` · 3 messages · 2026-05-16 01:23 PT → 2026-05-16 10:37 PT_
_Summarized: 2026-05-16 21:32 PT · last-msg-time: 2026-05-16T17:37:15Z_

## What was discussed

Cron health watch reported `ot-daily-learning-mitigated-alerts` transitioned from `healthy → missing` (skipped its 21:15 PDT May 15 scheduled fire, ~25h gap). Bot analyzed daemon logs and found the scheduler missed the 21:15 tick entirely — no entry in logs for that minute, while sibling jobs at 21:05 and 21:30 fired normally. Later Denny asked where the job's definition markdown file lives.

## Key decisions made

- **2026-05-16T08:24Z** — Root: scheduler tick miss at 21:15 PDT (not a job-specific failure). Structural risk: once-daily jobs scheduled at non-standard minutes (e.g., :15) are more vulnerable than those aligned with the 5-min monitor batch (`:00`/`:05`/`:10`/`:30`). `next_run_epoch` correctly set to 2026-05-16 21:15 PT — no manual intervention needed if tonight's fire succeeds.
- **2026-05-16T08:24Z** — Side effect: `ot-knowledge-curation` ran with 0 alerts corpus that morning (caused by this miss). No urgent action; tonight's fire restores the corpus.

## Files / artifacts touched

| path | what changed |
|---|---|
| _(none)_ | Diagnostic only; no files modified in this thread |

## Cluster / pattern references

_(No cluster directly applicable — scheduler tick miss is an infrastructure-level event, not an OT failure pattern.)_

## Followup items (not yet done)

1. Optional: move `ot-daily-learning-mitigated-alerts` cron to a `:00`/`:05`/`:10` minute aligned with the 5-min monitor batch to reduce tick-miss risk.

## Cross-refs

- Related threads: `fc2seBuCux8` (validator-unavailable discussion in same timeframe)
