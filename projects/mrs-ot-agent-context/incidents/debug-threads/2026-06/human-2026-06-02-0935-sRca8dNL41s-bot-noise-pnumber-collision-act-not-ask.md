---
thread_id: sRca8dNL41s
space: spaces/AAQAVOjYc80
messages: 8
date_range: 2026-06-02T16:35–16:42 UTC
summarized: 2026-06-03 01:44 PT
last_msg_time: 2026-06-02T16:42:29Z
human_involved: true
---

# Thread Summary: Bot noise, P-number collision fix, week's learnings after 24-day downtime

_Source: spaces/AAQAVOjYc80 thread `sRca8dNL41s` · 8 messages · 2026-06-02 09:35–09:42 PT_
_Summarized: 2026-06-03 01:44 PT · last-msg-time: 2026-06-02T16:42:29Z_

## What was discussed

Denny opened with "why I need to care about this msg?" — flagging a bot message as noise. Bot responded by summarizing the week's learnings (OT flywheel was dark 24 days, came back that morning), then asked the operator "Want me to do (a) or (b)?" — a P-001 violation. Denny replied "why ask" (2026-06-02T16:41:10Z), triggering course-correction: bot executed both tasks (P-number de-dup + burst-guard diagnosis) without further questions.

## Key decisions made

- **P-number collision fixed** (2026-06-02T16:41:53Z): concurrent postmortem runs each grabbed "next = P59" with no lock; de-duped into P59–P62 each distinct, each for a separate candidate pattern.
- **Candidates not landed** (N<3 for all 4): logged in ledger per ≥3-sample rule; ID-less until land-time is now the durable design.
- **Noise diagnosed as cold-start artifact** (2026-06-02T16:42:29Z): the 07:47 daemon restart re-fired the whole backlog before dedup state advanced — one-time, already self-suppressing. Real fix = burst-guard (skip cron if same job fired <N min ago).
- **P-001 re-confirmed as hard rule** (operator correction "why ask" at 2026-06-02T16:41:10Z): even a two-option question is a P-001 violation; just do both.

## Files / artifacts touched

| path | what changed |
|---|---|
| `learnings-ledger.md` (notes repo) | P-number de-dup: P59–P62 now distinct, L78 added for concurrent-run collision root cause |

## Cluster / pattern references

- [P-001] — act-don't-ask; directly violated by the "want me to do (a) or (b)?" line; operator correction closed the loop.

## Followup items (not yet done)

1. Implement burst-guard for cron jobs (skip run if same cron fired <N min ago) — diagnosed here, not yet built (dennyzhang, open).

## Cross-refs

- SEVs discussed: S669486, S668285, S667601, S666044, S669147, S663166
- Related threads: `RBT3wZo_bLc` (same session — operator also flagged noise there)
