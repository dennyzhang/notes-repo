---
name: aCLkmyAMG0Q-team-chat-noise-prevention-gate
description: Design of team-chat noise prevention gate (classify_delivery_route); operator pushed on reliability, thread-routing correction, close-the-thread ritual
metadata:
  type: project
human_involved: true
---

# Thread Summary: Team-chat noise prevention — gate design, leak vectors, reliability proof

_Source: spaces/AAQAVOjYc80 thread `aCLkmyAMG0Q` · 15 messages · 2026-06-07 18:07–18:38 UTC_
_Summarized: 2026-06-18 01:20 PT · last-msg-time: 2026-06-07T18:38:34Z_

## What was discussed

Operator asked what mechanism could prevent future team-chat noise regressions. Bot proposed a pre-send gate (block by shape/source, not content). Operator pushed back on reliability: the gate must be wired into the actual send path, not just defined. Bot traced `classify_delivery_route()` in `team_bot.py` — the function exists and is well-designed (fail-safe: interactive→1:1; fail-open: cron→team if route unknown). Backtest against that day's actual leaks showed both would have been suppressed. Remaining blocker: function not wired into daemon path (confirmed by CLAUDE.md comment at line 250-251). Operator then asked whether a recently-landed myclaw-core diff would be sufficient.

Thread included a thread-routing correction from operator ("you need to reply to this thread per gchat cheatsheet") and ended with "close the thread" + "make the solution reliable".

## Key decisions made

- Pre-send gate by shape/source (not content-grep) is the correct architecture (2026-06-07T18:09Z); content-grep on a judgment mode causes hook false-positives (see `content-scan-sendhook-false-positives` memory)
- `classify_delivery_route()` in `team_bot.py` already implements the correct logic (2026-06-07T18:36Z); it is NOT wired into daemon path → that is the gap
- Backtest confirmed (2026-06-07T18:36Z): both that day's leaks would have been blocked; real SEV alerts still flow

## Files / artifacts touched

| path | what changed |
|---|---|
| `pe_mrs_ml/mrs_ot_agent/src/team_bot.py` | read-only analysis, ~line 250-251 identified as the unwired gap |

## Cluster / pattern references

(no cluster IDs applicable — tooling/architecture thread)

## Followup items (not yet done)

1. Wire `classify_delivery_route()` into daemon delivery path (myclaw-core integration) — open question whether recently-landed myclaw-core diff covers this

## Cross-refs

- Related threads: `u5Ix-ci7K3c` (debug-agent challenges / thread-routing, earlier that day)
- Memory: `team-chat-noise-prevention-architecture`
