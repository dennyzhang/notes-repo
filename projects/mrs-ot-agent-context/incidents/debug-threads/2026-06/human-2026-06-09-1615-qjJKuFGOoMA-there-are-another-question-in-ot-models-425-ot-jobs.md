---
human_involved: true
---

# Thread Summary: OT fleet-scale metrics — 425 vs 61, scope distinction clarified

_Source: spaces/AAQAVOjYc80 thread `qjJKuFGOoMA` · 6 messages · 2026-06-09 16:15–16:25 PT_
_Summarized: 2026-06-10 01:04 PT · last-msg-time: 2026-06-09T23:25:48Z_

## What was discussed

Operator asked about a doc with a line "OT models 425 → ? | OT jobs/day ~1k → ?" — two fleet-scale metrics that needed updating. The bot initially over-deflected, claiming the numbers were out-of-lane platform metrics. Operator corrected: the OT master agent context already tracks the current OT job count.

## Key decisions made

- [2026-06-09T23:24:00Z] Operator correction: "you should know how many training jobs in total from OT master agent context, right?" — bot over-deflected when it should have cited from models.md.
- [2026-06-09T23:25:48Z] Correct answer from OT context: 61 currently-RUNNING OT training jobs/models, 2,980 GPUs, split FEED 14 / VIDEO 13 / INSTAGRAM 21 / THREADS 13. Matches operator's own "~60 across 4 PGs."
- The 425 figure is a different scope (all OT-enabled platform-wide, all-time) vs. the bot's tracked/incident-derived 61 — they are 7× apart by definition. Conflating them would be wrong; the doc cell needs to clarify which scope it wants.
- "OT jobs/day ~1k" is throughput (run-events/day), not concurrent models — a different unit the OT inventory doesn't track; needs a MAST/Scuba daily-run count query.

## Files / artifacts touched

| path | what changed |
|---|---|
| — | read-only; no files modified |

## Cluster / pattern references

_(none applicable)_

## Followup items (not yet done)

_(none — question answered; optional fleet-census query offered but not committed to)_

## Cross-refs

- Related: models.md (human-input/models.md — the tracked 61 source)
