# Thread Summary: Cron schedule timezone correction — PDT, not UTC

_Source: spaces/AAQAVOjYc80 thread `wZgw9KnVgNw` · 3 messages · 2026-05-31 06:10–06:12 UTC_
_Summarized: 2026-06-01 05:45 PT · last-msg-time: 2026-05-31T06:12:08Z_

## What was discussed

Denny shared a listing of all 35 MyClaw cron jobs with a "(UTC schedule)" column header. Bot validated empirically against `next_run_epoch` (authoritative fire time) and found the scheduler fires on LOCAL (PDT), not UTC. For example, `daily-brief` at `15 7 * * *` fires at 07:15 PDT (14:15 UTC), not 07:15 UTC. This directly contradicts the standing memory `gotcha_cron-schedule-evaluated-in-utc`, which had been written after the `ot-myclaw-weekly-restart` incident but was inverted. Bot began correcting the memory.

## Key decisions made

- **2026-05-31T06:11:08Z** Bot: scheduler evaluates cron expressions in LOCAL (PDT). `next_run_epoch` is authoritative; "(UTC schedule)" header in the cron list is inverted.
- Standing memory `gotcha_cron-schedule-evaluated-in-utc` marked as contradicted by live empirical evidence.

## Files / artifacts touched

| path | what changed |
|---|---|
| Memory: `gotcha_cron-schedule-evaluated-in-utc` | Flagged for correction — scheduler is PDT-local, not UTC |

## Cluster / pattern references

_(omitted — no [CL-NNN] verified in failure-patterns.md)_

## Followup items (not yet done)

1. Confirm whether the memory was fully corrected (the thread ended mid-correction). Verify `gotcha_cron-schedule-evaluated-in-utc.md` in memory dir reflects PDT-local reality.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `ft3uqm8w20o` (original ot-myclaw-weekly-restart UTC diagnosis — now known to be inverted)
