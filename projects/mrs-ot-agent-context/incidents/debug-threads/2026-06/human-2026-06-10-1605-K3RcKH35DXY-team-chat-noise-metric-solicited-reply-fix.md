---
name: human-2026-06-10-1605-K3RcKH35DXY
description: Team-chat precision metric was counting solicited bot replies as noise; operator caught it; bot fixed classifier in both metric tool and cron audit to be thread-aware
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Noise metric fix — solicited bot replies excluded from precision denominator

_Source: spaces/AAQAVOjYc80 thread `K3RcKH35DXY` · 13 messages · 2026-06-10 23:05–23:12 UTC_
_Summarized: 2026-06-10 23:06 PT · last-msg-time: 2026-06-10T23:12:39Z_

## What was discussed

Operator asked if bot replies to operator `!ot-bot` prompts count as noise in the team-chat precision metric. Bot confirmed: they did, and it was a real metric flaw. A bot `[🛟]` reply in a thread that contains an operator prompt is *solicited* — it's not bot send-discipline failure, it's the conversation location being wrong (operator routing choice). Bot implemented a two-pass thread-aware fix: link bot replies to threads containing operator prompts, exclude those as `solicited_interactive_excluded`. Implemented in both the one-off metric tool and the `ot-bot-volume-watch` cron classifier. Verified: 2 solicited replies excluded on live 24h run.

## Key decisions made

- [23:08 UTC] Solicited bot replies (bot `[🛟]` in a thread where operator posted `!ot-bot`) are excluded from noise count AND precision denominator. Only unprompted bot output counts as noise. [OPERATOR IDENTIFIED — not bot self-caught]
- [23:12 UTC] Fix applied to BOTH the metric shell script (team-space-precision.sh lines 77-81/96 area) AND `ot-bot-volume-watch` cron classifier (sqlite). Verified via test run: `solicited_interactive_excluded: 2`.
- [23:12 UTC] Bigger reframe: much of the reported "10-18% precision" was operator↔bot active session traffic being scored as bot spam. Genuine residual (unprompted cron/narration leaks → T275122535) is real but far smaller than the headline number implied.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/...` or local metric scripts | `team-space-precision.sh`: added two-pass solicited-reply exclusion |
| sqlite `cron_jobs` | `ot-bot-volume-watch` classifier updated (propagated, verified) |

## Cluster / pattern references

_(none — this is bot metric calibration, not a failure cluster)_

## Followup items (not yet done)

_(none explicit in thread — the fix was complete and verified)_

## Cross-refs

- Tasks: T275122535 (interactive reply routing upstream), T275142534 (core daemon default gate)
- Related threads: `GeRtSWIzjBE` (same-day earlier thread — precision audit, daemon root proved)
