# Thread Summary: Triage Format Improvements — Standing Hypothesis Before Ruled-Out, Add PG Field

_Source: spaces/AAQAVOjYc80 thread `O_kKd7ADe5g` · 8 messages · 2026-05-17_
_Summarized: 2026-05-29 07:45 PT · last-msg-time: 2026-05-17T14:11:37Z_

## What was discussed

A triage report for IFR MTML 886797001 (DENSE_DELTA cadence gap, auto-resolved) was posted. Denny flagged two format issues: (1) "Standing hypothesis" section appeared after "Ruled out" instead of immediately after "Ground-truth"; (2) the Model line lacked the product group (PG) field. Bot shipped both fixes as commit 9b83798880e7 across all 3 monitor crons.

## Key decisions made

- (2026-05-17T14:11:05Z) Denny: "standing hypothesis should come right after ground truth. Model part should show which pg (product group)" — reader must see the conclusion before alternatives.
- (2026-05-17T14:11:37Z) Bot shipped: new section order (Ground-truth → Standing hypothesis → Ruled out) + `pg: <PG>` on Model line; lint regex updated in sev + alert monitors.

## Files / artifacts touched

| path | what changed |
|---|---|
| ot-sev-monitor, ot-alert-monitor, ot-post-monitor cron prompts | section-order constraint + PG field requirement added |

## Cluster / pattern references

_(omitted — failure-patterns.md not present)_

## Followup items (not yet done)

_(none discussed)_

## Cross-refs

- SEVs discussed: S664499
- Posts: none
- Related threads: none
