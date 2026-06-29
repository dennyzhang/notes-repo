---
human_involved: false
thread_id: Yn5pEwT82ZI
space: spaces/AAQAVOjYc80
msg_count: 7
date_range: 2026-06-15 to 2026-06-17
summarized: 2026-06-17 21:06 PT
last_msg_time: 2026-06-17T08:13:21Z
---

# Thread Summary: Team-chat precision audit — ghost cron removal + leak source analysis

_Source: spaces/AAQAVOjYc80 thread `Yn5pEwT82ZI` · 7 messages · 2026-06-15 to 2026-06-17_
_Summarized: 2026-06-17 21:06 PT · last-msg-time: 2026-06-17T08:13:21Z_

## What was discussed

Three operator team-chat self-audit posts across different time windows. First audit (06-16 06:06Z) showed 43% cron precision; bot confirmed two ghost crons (ot-cron-health-watch, ot-human-attention-brief) removed from jobs table, and remaining leaks (daily-brief, curation) classified as gate-territory under D108690697. Second audit (08:07Z) showed 50%; bot verified a notes-weekly-review-paste top-of-prompt fix was committed (not just sqlite). Third audit (06-17 08:13Z) showed 88.6% — first run tracking WIB bot replies (prior audits were cron-only), making metrics non-comparable; Q&A threads account for 57% of all bot messages.

## Key decisions made

- Ghost crons (ot-cron-health-watch, ot-human-attention-brief) removed from jobs table (2026-06-16T06:07Z)
- notes-weekly-review-paste top-of-prompt delivery rule committed (durable, not just sqlite) (2026-06-16T08:08Z)
- D108690697 (core send-gate) is the structural fix; until deployed, cron + Q&A leaks continue via LLM-variance

## Files / artifacts touched

| path | what changed |
|---|---|
| notes ot-notes-weekly-review-paste prompt | added top-of-prompt ⛔ delivery-to-operator-1:1-only rule |

## Cluster / pattern references

_(none — no CL-NNN IDs verified in failure-patterns.md)_

## Followup items (not yet done)

1. Land D108690697 (core gate) + deploy myclaw package — operator's action; precision won't recover until then
2. T275122535 (upstream interactive/cross-space leak gate) — tracked, open
3. T275142534 (structural gate for leak prevention) — tracked, open

## Cross-refs

- Related threads: `v8xkr4FYBYk` (D107579040 post-land analysis, same precision saga)
