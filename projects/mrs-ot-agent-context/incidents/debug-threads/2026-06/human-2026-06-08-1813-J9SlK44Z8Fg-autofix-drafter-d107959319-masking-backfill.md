---
name: J9SlK44Z8Fg-autofix-drafter-backfill-masking
description: ot-autofix-diff-drafter activation, backfill, D107959319 masking catch, P-016 task lifecycle contract
metadata:
  type: project
  human_involved: true
---

# Thread Summary: ot-autofix-diff-drafter — activation, backfill, masking catch, lifecycle contract

_Source: spaces/AAQAVOjYc80 thread `J9SlK44Z8Fg` · 125 messages · 2026-06-08 18:13–2026-06-09 21:34 PT_
_Summarized: 2026-06-10 21:04 PT · last-msg-time: 2026-06-10T04:34Z_

## What was discussed

Operator activated `ot-autofix-diff-drafter` and extended scope. Bot dry-ran against 16 open `[OT auto-fix]` tasks (dedup guards caught issue-level duplicates), then submitted D107959319 (cs_omni e2e-latency-sparse-delta) reporting "no-mask PASSED." A backfill run (0 diffs, 12 tasks commented) revealed D107959319 was MASKING — bot's first no-mask check misread "max 3 pts/run" as no-data; real data + 194 violations exist. Bot self-corrected, drafted D107966514 (genuine t2i holdout builder fallback fix). Operator challenged the 0/12 ratio; bot diagnosed that the drafter only selected `[OT auto-fix]`-titled tasks (title-prefix filter, not diagnosis-class), leaving T274815280 and 4 others invisible. Bot broadened selection to diagnosis-class. Pushed T274815280 via diff-subagent → D108105695, which caught that the task premise was wrong (model publishes fine; real bug was detector window too narrow for retrieval cadence). Operator codified the operating contract: fire task → drive to close; only genuine human-gated blockers fly up.

## Key decisions made

- **D107959319 = DO_NOT_LAND** (2026-06-09 03:07 PT): backfill ground-truth overturned first no-mask check; detectors are real (194 violations).
- **no-mask gate hardened** (2026-06-09 03:14 PT): remove only if `invalidDetectorAlertCount>0 AND numViolatingTS=0 AND newDataPoints=0`; any `numViolatingTS>0` → masking → reject. Memory saved.
- **Drafter selection: title-prefix → diagnosis-class** (2026-06-10 04:07 PT): any bot-filed task whose root is a config/code change the bot can author, regardless of filing cron.
- **Task lifecycle contract (P-019)** (2026-06-10 04:10 PT): bot owns from file through verify/close; escalates only write/land/page blockers.

## Files / artifacts touched

| path | what changed |
|---|---|
| ot-autofix-diff-drafter.md (sqlite) | scope, dedup, no-mask gate definition, selection logic |
| memory / autonomous-action-allowlist | P-019 task lifecycle rule |

## Cluster / pattern references

- [CL-003] — Scribe/ZippyDB upstream SEVs were the triggering alerts that created many `[OT auto-fix]` tasks in scope

## Followup items (not yet done)

1. D108105695 — operator review + land (T274815280 retrieval detector window fix). Status: draft.
2. Remaining ~9 open `[OT auto-fix]` tasks with real guardrail blockers — drafter to work through on next daily run.
3. Fix triage-time premise test: filing crons should run data-presence check (`invalidDetectorAlertCount`) before asserting "no-data" and opening a fix task.

## Cross-refs

- Diffs: D107959319 (DO_NOT_LAND/masking), D107966514 (draft), D108105695 (draft)
- Tasks: T274437397, T274437439, T274725797, T274264882, T274873470, T274815280
