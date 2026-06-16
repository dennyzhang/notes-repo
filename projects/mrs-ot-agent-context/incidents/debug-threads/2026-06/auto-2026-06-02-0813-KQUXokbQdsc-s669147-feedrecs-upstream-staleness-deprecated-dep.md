---
name: s669147-feedrecs-upstream-staleness-deprecated-dep
description: S669147 postmortem — ig_feedrecs T2I blocked by upstream data staleness + deprecated table dep + auto-paused Dataswarm writer
metadata:
  type: project
  thread_id: KQUXokbQdsc
  human_involved: true
  summarized_at: "2026-06-02 23:43 PDT"
---

# Thread Summary: S669147 — ig_feedrecs T2I blocked by upstream staleness + deprecated table dep

_Source: spaces/AAQAVOjYc80 thread `KQUXokbQdsc` · 4 messages · 2026-06-02 08:13–08:47 PDT_
_Summarized: 2026-06-02 23:43 PDT · last-msg-time: 2026-06-02T15:47:03Z_

## What was discussed

ot-sev-postmortem cron posted S669147 digest: ig_feedrecs T2I blocked for 71.2h (2026-05-28 → 2026-06-01) by a chain of: upstream qualityfm source stopping partition production (S668546) → common-pool v7 photo writer stalled → backfill blocked by deprecated `ig_icq_media_labels_extended_v4` dependency → writer auto-paused from prior failures. A validator agent confirmed the triage. Operator replied "Why ask" — likely reacting to the bot repeatedly asking for gdoc full-replace approval.

## Key decisions made

- Pattern P60 proposed: "Deprecated table dep + auto-paused Dataswarm writer extends upstream-staleness recovery" — logged as learnings-ledger candidate (1 incident, needs ≥3 for promotion to quick-match table) (2026-06-02T15:13Z triage message; validator confirmed 15:15Z)
- P60 verified novel vs P54: P54 = multi-pipeline CDM orchestrator pause; P60 = single-pipeline deprecated-dep + auto-paused writer compounding (validator message 2026-06-02T15:15:41Z)
- Operator flagged bot behavior of repeatedly asking for gdoc go via "Why ask" — implicit feedback to stop confirmation-baiting

## Files / artifacts touched

| path | what changed |
|---|---|
| (none in this thread — cron output only) | P60 candidate logged to learnings-ledger elsewhere |

## Cluster / pattern references

_(section omitted — no verified CL-NNN cited in source messages)_

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- SEVs discussed: S669147, S668546
- Related threads: (none named)
