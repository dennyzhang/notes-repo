---
name: team-chat-audit-false-alarm-step12-bug
description: 14:05 audit showed 60% precision. Bot verified it was a false alarm (LLM judgment mis-bucketed interactive thread as cron noise). Identified step-12 bug: folds interactive into precision denominator; script exists but not wired in.
metadata:
  type: project
  human_involved: false
---

# Thread Summary: Team-chat audit false alarm — step-12 cron/interactive split bug

_Source: spaces/AAQAVOjYc80 thread `8GImC-FVbrY` · 17 messages · 2026-06-15_
_Summarized: 2026-06-17 10:04 PT · last-msg-time: 2026-06-15T14:17:41Z_

## What was discussed

Operator posted a 14:05 audit showing 60% precision, attributing 2 leaks to `ot-team-chat-self-audit` and `ot-prompt-change-validator`. Bot investigated using job_runs + team-space readback (authoritative ground truth). Finding: `ot-team-chat-self-audit` had 0 deliveries in 24h — it cannot have leaked. The one real `ot-prompt-change-validator` leak was already handled the prior day. The "60%" was a false alarm caused by the auditor's step-12 classifying interactive `!ot-bot` Q&A threads (which discussed cron names) as cron-authored posts — a miscount flagged twice before, now the third recurrence.

Bot also discovered that `team-space-precision.sh` (the deterministic partition script) exists but (a) is not wired into step-12's execution path, and (b) folds `interactive_myclaw_ot` into the precision denominator, directly contradicting the step-12 scope note. The real partition requires fingerprint-matching team-space posts against `delivered` cron `job_runs` — the only reliable way to distinguish a cron leak from an interactive reply that shares the same `🛟` prefix.

## Key decisions made

- The "60% precision" reading was a false alarm: 1 handled real cron leak + 1 misattribution. True precision ≈ 75%. (2026-06-15T14:17:41Z)
- Fix must be deterministic (script-wired, fingerprint-match), not more prose in step-12. Third recurrence triggers code fix. (2026-06-15T14:15:41Z)
- `ot-team-chat-self-audit` missing `channel` field is a separate in-lane lever — not the source of this miscount but a contributing precondition. (2026-06-15T14:10:10Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| _(none committed this thread — investigation only)_ | Next session built and landed the fix |

## Cluster / pattern references

_(No confirmed cluster IDs in failure-patterns.md — omitted)_

## Followup items (not yet done)

_(None explicit — the fix was built in the subsequent `l7DblxcOh7Q` session)_

## Cross-refs

- Related threads: `zLLsV9Hnyz0` (same-day real 60% audit), `l7DblxcOh7Q` (where the fix was built)
