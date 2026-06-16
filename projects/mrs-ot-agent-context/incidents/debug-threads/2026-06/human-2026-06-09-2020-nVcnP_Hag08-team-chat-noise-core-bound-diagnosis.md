---
name: nVcnP_Hag08-team-chat-noise-core-bound
description: Operator challenged bot on team-chat noise improvements; bot diagnosed structural core-bound root cause
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Team-chat noise — what's actually been improved?

_Source: spaces/AAQAVOjYc80 thread `nVcnP_Hag08` · 13 messages · 2026-06-09 20:20–20:26 PT_
_Summarized: 2026-06-10 21:04 PT · last-msg-time: 2026-06-10T03:26Z_

## What was discussed

Operator challenged the bot: "they are all noise — what improvements have you made?" Bot admitted the metric hadn't moved, then traced the actual root cause: prose narration-prohibition rules cannot prevent the daemon from auto-delivering cron final responses to the team space. Every prior "fix" had targeted prompt text; the structural gate (`classify_delivery_route()`) was never wired into the daemon poll loop in myclaw-core.

## Key decisions made

- **Stop prompt-patching** (2026-06-09 20:22 PT): crons carrying maximal narration-prohibition text still leaked — adding a 4th prose rule would have been the same non-fix.
- **Escalate under P-017** (2026-06-09 20:26 PT): root cause is core-bound (`cross_space.py` default delivers to team; T275142534 is the structural fix). Bot must monitor the metric but stop re-narrating each audit.
- **ot-team-chat-self-audit** scope narrowed: delivers 1:1-only, change-only — operator hears only on regression or new non-daemon-default source.

## Files / artifacts touched

| path | what changed |
|---|---|
| (analysis only — no file edits in this thread) | — |

## Cluster / pattern references

(no cluster — bot internal / tooling topic)

## Followup items (not yet done)

1. T275142534 — wire `classify_delivery_route()` into daemon poll loop. Owner: myclaw-core team. Status: open, evidence posted.

## Cross-refs

- Related threads: `GeRtSWIzjBE` (audit precision run, same root cause confirmed)
