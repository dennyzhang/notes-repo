---
name: autonomous-workflow-gap-nudge-required
description: Bot built the step-12 deterministic precision fix only after operator nudged. Operator flagged the autonomy gap. Bot identified 4 improvements needed for self-triggering closed-loop auto-improvement.
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Autonomous workflow gap — bot waited for nudge to build known fix

_Source: spaces/AAQAVOjYc80 thread `l7DblxcOh7Q` · 19 messages · 2026-06-15_
_Summarized: 2026-06-17 10:04 PT · last-msg-time: 2026-06-15T16:17:49Z_

## What was discussed

Operator asked "build one: need to confirm - you will build it with nothing blocked by me, right?" — referring to the step-12 precision-script wiring identified in `8GImC-FVbrY`. Bot confirmed and built the fix: rewrote `team-space-precision.sh` to use fingerprint-match against `delivered` job_runs (not prefix heuristic), and wired step-12 to call the script verbatim. Backtested on real data: `cron_precision 0.75` (correct — 3 signal + 1 validator cron-leak surfaced). Committed + synced to sqlite.

Operator then corrected: *"so you only build it after my nudge. We need autonomous workflow for this auto-improvements. what improvements are needed to reach that."* Bot explained the 4-part gap in the closed-loop: (1) recurrence→auto-fix trigger (≥2 detections → act, not re-report), (2) validator/auditor findings feed the same drafter that fixes alert misconfigs, (3) scope-classifier as autonomy gate (notes-only → land autonomously; fbcode → draft+escalate), (4) backtest-as-acceptance-gate automated. Bot committed to spec the rails (notes-only blast radius, mandatory backtest, change cap, audit log, kill-switch) before building — one because a self-modifying loop is the one place where showing the shape before it's live is correct.

**Hazard encountered mid-build:** a concurrent notes-writer reverted uncommitted edits once (exact `commit-notes-edits-or-they-revert` hazard). Bot caught it via `sl status`, re-applied, committed same-turn.

## Key decisions made

- Bot waited for nudge to build a notes-only, autonomous-scope, already-specified fix — that is the autonomy gap to close. (2026-06-15T16:07:50Z operator correction)
- 4 improvements identified to close the loop: recurrence-trigger, drafter-wiring, scope-classifier, backtest-gate. (2026-06-15T16:17:12Z)
- Spec rails before building the self-modifying loop — the one correct "ask first" case (architecture, not reversible one-off). (2026-06-15T16:17:12Z)
- `commit-notes-edits-or-they-revert` hazard confirmed in the wild; mitigation = commit same-turn, verify via real run. (mid-build)

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../tools/team-space-precision.sh` | Rewritten: fingerprint-match against `delivered` job_runs |
| `notes/.../team_bot/cron-jobs/ot-bot-volume-watch.md` | Step-12 wired to call script; old LLM-judgment removed |
| sqlite `myclaw.db` | Updated via setup-cron-jobs.sh, verified present |
| notes repo | Committed + cloud-synced |

## Cluster / pattern references

_(No confirmed cluster IDs in failure-patterns.md — omitted)_

## Followup items (not yet done)

1. Spec + build the self-modifying autofix loop (recurrence-trigger → scope-classify → backtest-gate → land autonomously for notes-only scope) — bot committed to spec rails before wiring.

## Cross-refs

- Related threads: `8GImC-FVbrY` (investigation that preceded this build)
