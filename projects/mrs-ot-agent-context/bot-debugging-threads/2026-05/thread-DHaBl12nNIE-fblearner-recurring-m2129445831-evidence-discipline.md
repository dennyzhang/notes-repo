# Thread Summary: Evidence Discipline — FBLearner Recurring Claim for m2129445831

_Source: spaces/AAQAVOjYc80 thread `DHaBl12nNIE` · 11 messages · 2026-05-26T22:58–23:04Z_
_Summarized: 2026-05-28 21:45 PT · last-msg-time: 2026-05-26T23:04:21Z_

## What was discussed

Denny challenged a bot claim that "FBLearner recurring_train workflow for m2129445831 stopped ~May 24 21:38 PDT" — asking for solid evidence. Bot ran the 3-command verification chain and discovered the claim was fabricated: the workflow was firing hourly, all runs SUCCEEDED through May 24 and beyond. Additionally, no MAST OT job exists for m2129445831 (never successfully created). Root cause of the original claim: the cron that produced it skipped the recurring-flow-history evidence check.

## Key decisions made

- [22:58Z] Denny established rule: "key claims like this" require verification evidence before publishing. Bot must cite workflow_run_id + history before any "stopped at T" claim.
- [23:04Z] Root cause diagnosis: fabricated "stopped" claim on two axes — (1) FBLearner recurring is HEALTHY (hourly SUCCEEDED), (2) no OT MAST job exists; OT was never successfully created (Tetris-arg errors from 2026-05-22 Keir/Liuyi session).

## Files / artifacts touched

| path | what changed |
|---|---|
| `memory/feedback_known-pattern-validation.md` | Added: time-anchored "stopped" claims require 3-command verification chain |

## Cluster / pattern references

_(no failure cluster — this thread is about bot evidence-discipline)_

## Followup items (not yet done)

_(none — the cron that produced the fabricated claim was identified but no prompt amendment was issued in this thread; it may need a separate fix)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Model: m2129445831 (ig_textpost_tifu_esr, owner halin, oncall p92_relevance_growth, runtime_platform FBLEARNER_FLOW — no MAST OT job)
