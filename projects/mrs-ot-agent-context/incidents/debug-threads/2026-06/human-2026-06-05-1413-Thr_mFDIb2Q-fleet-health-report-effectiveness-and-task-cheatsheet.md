---
name: Thr_mFDIb2Q-fleet-health-effectiveness-and-task-cheatsheet
description: Operator attacks fleet-health report effectiveness; bot creates T274581215 and meta-tasks cheatsheet; two rounds of task-writing corrections from operator
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Fleet-health report effectiveness + meta-tasks cheatsheet + task T274581215

_Source: spaces/AAQAVOjYc80 thread `Thr_mFDIb2Q` · 32 messages · 2026-06-05T21:13–21:28 UTC_
_Summarized: 2026-06-05 14:13 PT · last-msg-time: 2026-06-05T21:28:14Z_

## What was discussed

Denny asked the bot to "read the msg and attack how to improve its effectiveness" (inferred as the latest 🩺 OT fleet-health report). The bot identified 6 weaknesses: (1) "9 need action" inflated — 6 of 9 had `[cause-class not probed]` punts; (2) no clustering (5 age-breaches with identical "check Scribe" action, not synthesized to 1 shared-cause line); (3) no threshold margins shown; (4) generic rather than owner-specific action; (5) coverage gap (21/65 perf-blind) buried as a footer; (6) flat snapshot, no delta framing. Bot created tracking task T274581215. Denny said it was "not scannable, not convincing" then "hard to follow" — two rounds of correction led to a plain-narrative rewrite (one idea per line, problem→fix→done). Bot also sharpened `cheatsheets/system/meta-tasks.md` (added quality standard at top, two CLI gotchas: `--priority=NORMAL` silently fails; `update` uses `--task` not `--number`) and wired the cheatsheet into CLAUDE.md routing.

## Key decisions made

- **Cluster-by-shared-cause + threshold-margins are the two highest-leverage fleet-health fixes** (2026-06-05T21:17 UTC): both scan-side per the prompt→scan rule. Baked into the scan as of today's fixes (but the scan was edited ~5× during cross-space sessions; bot deferred sequencing to avoid stacking on mid-flight churn).
- **Task quality = scannable + convincing** (Denny, 2026-06-05T21:20 UTC): BLUF → Why it matters (the convincing hook) → concrete Evidence → Scope checklist → verifiable Done-when → Refs. Structure alone isn't enough — lines must be plain, one idea each, no compound/arrow lines.
- **Meta-tasks cheatsheet existed but quality section was buried at line 177** (2026-06-05T21:21 UTC): rather than creating a duplicate, bot added the quality standard at the top and fixed the two stale CLI examples.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/users/dennyzhang/cheatsheets/system/meta-tasks.md` | Added "Task Content Quality" section at top; fixed `--priority=NORMAL` and `--number` gotchas |
| CLAUDE.md cheatsheet routing table | Added row: "About to create OR update a meta task → load meta-tasks.md § Task Content Quality" |

## Cluster / pattern references

_(Omitted — cluster IDs not verified)_

## Followup items (not yet done)

1. Fleet-health scan: land cluster-by-shared-cause + show-threshold-margins improvements (Owner: bot; deferred due to mid-flight scan churn from cross-space sessions)

## Cross-refs

- Tasks: T274581215 (OT fleet-health report improvements, MID priority)
- Related threads: _(cross-space sessions that edited the fleet-health scan cron on 2026-06-05)_
