---
name: auto-2026-06-10-0006-GeRtSWIzjBE
description: Team-chat precision audit proved core (daemon default); evidence pushed to T275142534; bot stopped re-narrating
metadata:
  type: project
  human_involved: false
---

# Thread Summary: Team-chat noise audit — precision pinned at ~11%, root proven core

_Source: spaces/AAQAVOjYc80 thread `GeRtSWIzjBE` · 11 messages · 2026-06-10 07:06–10:06 UTC_
_Summarized: 2026-06-10 23:06 PT · last-msg-time: 2026-06-10T10:06:21Z_

## What was discussed

Three consecutive team-chat precision audits returned ~11% (later 0%). Bot ran the decisive check it had been skipping: per-cron send targets. Found every leaking cron (`daily-brief`, `ot-shift-summary`, all `ot-daily-learning-*`) already configured with team=0 / explicit 1:1 send / HEARTBEAT_OK. Operator posted a new 0%-precision audit result after bot committed to stopping re-narration. Bot held the line.

## Key decisions made

- [07:15 UTC] The leak is the daemon default (ships final response to team space on any non-HEARTBEAT_OK output). Prompts can't fix it. Structural root = T275142534 (myclaw-core: `classify_delivery_route()` must default to 1:1).
- [07:09 UTC] Evidence + acceptance test (precision ≥90%) pushed to T275142534. No further in-lane audit runs until the core gate ships or a non-daemon-default source appears.
- [08:12 UTC] Interactive Q&A in team room is the #1 noise class; same daemon root. Short-circuit: operator should ask in this 1:1 instead of `!ot-bot` in the team room.
- [10:06 UTC] Bot committed to silence on this metric until regression or new source. Held on the third audit result (0%), consistent with that commitment.

## Files / artifacts touched

| path | what changed |
|---|---|
| — | no files modified; evidence posted as comment on T275142534 |

## Cluster / pattern references

_(none — this is bot-internal send-discipline tracking, not a failure cluster)_

## Followup items (not yet done)

1. T275142534: wire `classify_delivery_route()` in myclaw-core so daemon default inverts to 1:1 (team requires explicit opt-in). Owner: myclaw-core team.

## Cross-refs

- Tasks: T275142534 (core gate), T275122535 (interactive reply routing)
- Related threads: none
