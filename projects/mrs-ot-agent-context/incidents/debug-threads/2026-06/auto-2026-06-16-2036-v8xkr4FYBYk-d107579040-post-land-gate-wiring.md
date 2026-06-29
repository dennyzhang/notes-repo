---
human_involved: false
thread_id: v8xkr4FYBYk
space: spaces/AAQAVOjYc80
msg_count: 32
date_range: 2026-06-16 20:36 to 20:54 PDT
summarized: 2026-06-17 21:06 PT
last_msg_time: 2026-06-17T03:54:21Z
---

# Thread Summary: D107579040 post-land analysis — why it didn't stop leaks + reinstall-durable gate wiring

_Source: spaces/AAQAVOjYc80 thread `v8xkr4FYBYk` · 32 messages · 2026-06-16 20:36–20:54 PDT_
_Summarized: 2026-06-17 21:06 PT · last-msg-time: 2026-06-17T03:54:21Z_

## What was discussed

Operator asked why D107579040 (route interactive bot replies to operator 1:1) being landed didn't stop team-chat leaks. Bot diagnosed: D107579040 put the routing decision in the wrong layer (OT-agent repo, which myclaw-core can't import), so classify_delivery_route() was never wired into the live send path. D108690697 (gate in myclaw-core) is the correct gate. Operator said "do it + survive reinstall." Bot executed: (1) added team_space_allowed_sources to team_bot_config.yaml (durable source); (2) added apply_send_gate_config() to bootstrap.sh so it seeds gate config on every reinstall; (3) applied live to config.json; (4) committed + cloud-synced; (5) drafted D108836346 to remove the now-superseded dead classify_delivery_route() code.

## Key decisions made

- D107579040 is declared-but-unwired (wrong layer) — its classify_delivery_route() is superseded dead code (2026-06-17T03:37Z bot diagnosis)
- Reinstall-survival mechanism: team_bot_config.yaml = durable source; bootstrap.sh seeds config.json on every reinstall (2026-06-17T03:43Z)
- D108836346 (draft) removes dead code; D108690697 (core gate) + package deploy remain operator's land steps

## Files / artifacts touched

| path | what changed |
|---|---|
| notes team_bot_config.yaml | added team_space_allowed_sources (durable gate allow-list) |
| notes team_bot/bootstrap.sh | added apply_send_gate_config() — seeds gate config on reinstall |
| D108836346 (draft fbcode) | removes superseded classify_delivery_route() + constants/helpers/tests |

## Cluster / pattern references

_(none — no CL-NNN IDs verified in failure-patterns.md)_

## Followup items (not yet done)

1. Land D108690697 (core gate) + deploy myclaw package — operator's action; gate is built, not yet live
2. Land D108836346 (dead-code cleanup) — draft, ready for review
3. T276085069 (ghost-cron daemon scheduler fix) — separate from routing, drives phantom fires

## Cross-refs

- Related threads: `Yn5pEwT82ZI` (precision audit showing continuing leaks this gate addresses)
- Diffs: D107579040 (wrong-layer, superseded), D108690697 (correct gate), D108836346 (cleanup)
