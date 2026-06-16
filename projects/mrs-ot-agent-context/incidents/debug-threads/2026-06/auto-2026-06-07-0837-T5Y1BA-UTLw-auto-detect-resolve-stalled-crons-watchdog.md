---
name: auto-2026-06-07-0837-T5Y1BA-UTLw-auto-detect-resolve-stalled-crons-watchdog
description: Operator asked how to detect and auto-resolve stalled crons without manual checks. Bot found existing ot-cron-health-watch already detected the ot-shift-summary stall (Jun 5); gap is auto-resolution + escalate-until-resolved, not detection.
metadata:
  type: auto
  thread_id: T5Y1BA-UTLw
  space: spaces/AAQAVOjYc80
  human_involved: false
  first_msg_time_pt: 2026-06-07 08:37 PDT
  last_msg_time_utc: 2026-06-07T15:43:22Z
  msg_count: 5
---

# Thread Summary: Auto-Detect and Auto-Resolve Stalled Cron Jobs

_Source: spaces/AAQAVOjYc80 thread `T5Y1BA-UTLw` · 5 messages · 2026-06-07 08:37–08:43 PDT_
_Summarized: 2026-06-07 21:46 PDT · last-msg-time: 2026-06-07T15:43:22Z_

## What was discussed

Operator asked: "what could make similar issues are detected and resolved by yourself without my manual check?" — prompted by the ot-shift-summary stall that required manual intervention. Bot checked and found `ot-cron-health-watch` class-2 ("Missing run") *already fired* on Jun 5 21:41 PDT, correctly flagging ot-shift-summary as `missing`. The gap is not detection but two steps after it: (1) no auto-resolution (ot-shift-summary is not on the auto-mitigation allowlist, so the watchdog surfaces and waits), and (2) one-shot alerting (single alert, then suppressed to avoid spam — so a persistent stall gets buried). Operator confirmed root cause fix (setup-cron-jobs.sh resetting `next_run` on schedule change) was already shipped; bot proposed two additions.

## Key decisions made

- [08:43 PDT, bot] Auto-resolve proposal: when watchdog sees `missing` cron-type job with stale `next_run` vs. its schedule, auto-nudge `next_run` to fire. Mechanical and safe (nudging overdue job ≠ killing mid-flight). To build.
- [08:43 PDT, bot] Escalate-until-resolved proposal: unresolved `missing` status should re-surface on backoff cadence and land in morning human-attention-brief so multi-day stalls are impossible to miss. To build.
- [08:43 PDT, bot] Default aggressiveness: nudge-once; if still missing next audit, stop nudging and escalate hard (prevents nudge-fail loop on genuinely broken jobs).

## Files / artifacts touched

| path | what changed |
|---|---|
| `team_bot/scripts/setup-cron-jobs.sh` | already shipped: resets `next_run` on schedule change (root cause fix for this class) |

## Cluster / pattern references

_(no CL-NNN applicable — agent-design / cron-reliability topic)_

## Followup items (not yet done)

1. Build: auto-nudge `next_run` for watchdog-detected `missing` cron jobs. Owner: dennyzhang. Status: open.
2. Build: escalate-until-resolved for persistent `missing` status + surface in morning human-attention-brief. Owner: dennyzhang. Status: open.

## Cross-refs

- Related threads: none
- Crons involved: `ot-cron-health-watch`, `ot-shift-summary`, `ot-human-attention-brief`
