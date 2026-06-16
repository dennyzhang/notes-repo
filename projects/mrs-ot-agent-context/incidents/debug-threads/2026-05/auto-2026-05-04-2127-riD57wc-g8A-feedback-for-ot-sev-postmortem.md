---
name: auto-riD57wc-g8A-ot-sev-postmortem-feedback
description: Operator feedback session on ot-sev-postmortem cron — batch-land approach, FBcode learning storage, retry-on-fail policy
metadata:
  type: project
  thread_id: riD57wc-g8A
  human_involved: false
---

# Thread Summary: Feedback for ot-sev-postmortem cron

_Source: spaces/AAQAVOjYc80 thread `riD57wc-g8A` · 6 messages · 2026-05-04 21:27–21:48 PDT_
_Summarized: 2026-06-02 09:43 PT · last-msg-time: 2026-05-05T04:48:45Z_

## What was discussed

Operator provided targeted feedback on how the ot-sev-postmortem cron should behave. Two behavioral policies were set: for correctly-processed SEVs, learnings must be tracked in FBcode (not just sqlite); for failed SEV postmortems, the cron should attempt one retry before giving up. Operator also endorsed the bot's prior suggestion to batch-land all prompt iterations in one diff after a week's trial run, and asked the bot to apply that plan to D103787689. A separate idle-timeout customization request was appended at the end.

## Key decisions made

- For correctly-processed SEVs: write learnings to FBcode (folder previously discussed), not only to sqlite — ensures durability through reinstalls [04:28 PDT]
- For failed SEV postmortems: add one retry before giving up [04:28 PDT]
- Batch-land prompt iterations: run for a week, then land all cron prompt changes in one diff (operator-endorsed approach) [04:40 PDT]
- Make changes in D103787689 (the active postmortem diff) [04:41 PDT]

## Files / artifacts touched

| path | what changed |
|---|---|
| D103787689 | Postmortem cron improvements (retry logic, FBcode learning storage, batch-land wording) |

## Cluster / pattern references

_(no verified cluster IDs — failure-patterns.md not present)_

## Followup items (not yet done)

_(none explicit)_

## Cross-refs

- SEVs discussed: none
- Related threads: `nSlz2Y8fJfg` (diff creation from D103785537)
