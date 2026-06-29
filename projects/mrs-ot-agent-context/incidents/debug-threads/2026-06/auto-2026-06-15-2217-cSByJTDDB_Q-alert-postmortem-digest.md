---
name: alert-postmortem-digest-2026-06-15
description: Alert postmortem digest for 5 alerts (Jun 15); 2 pattern proposals (AMD GPU reset, scribe quota blocking retrieval OT); validator 3/5 confirmed, 2 unverifiable
metadata:
  type: project
  thread_id: cSByJTDDB_Q
  human_involved: false
---

# Thread Summary: Alert Postmortem Digest — Jun 15 (5 Alerts, 2 Pattern Proposals)

_Source: spaces/AAQAVOjYc80 thread `cSByJTDDB_Q` · 6 messages · 2026-06-15_
_Summarized: 2026-06-17 11:15 PT · last-msg-time: 2026-06-16T05:19:54Z_

## What was discussed

Alert postmortem cron processing 5 alerts from Jun 15. Three tasks already filed (T275863995, T275881538, T275918888) plus D108645461 in flight for the FULL_SNAPSHOT false-alert fix. Two proposed P-rows for the pattern distillation pipeline. Validator ran and flagged 2 alerts unverifiable (EntityNotFoundException on feed IDs) while confirming 3.

## Key decisions made

- **AMD P-row → ledger candidate only** (05:18:07): AMD MI300X GPU reset → NE regression has 1 source (A1515914886994080); <3 sources → cannot land as P-row per ≥3-source invariant. Should be logged to learnings-ledger.md pending more data.
- **Scribe quota P-row → valid proposal** (05:18:35 validator): "Scribe tenant quota exhaustion blocking retrieval OT flows" cites 3+ alerts (A1485851106147880, A1728833178491353, A1010861974743054) — meets threshold. CL-003 Quick-Match Table entry still missing.
- **Unverifiable ≠ false** (05:19:40): 2 alerts where feed ID returns EntityNotFoundException correctly marked uncertain (not asserted as confirmed or refuted).

## Files / artifacts touched

| path | what changed |
|---|---|
| ~/notes/.../resolved-alerts/2026-06/high-2026-06-15-A1515914886994080.md | written |
| ~/notes/.../resolved-alerts/2026-06/high-2026-06-15-A1485851106147880.md | written |
| ~/notes/.../resolved-alerts/2026-06/unknown-2026-06-15-A2072111036680190.md | written |
| ~/notes/.../resolved-alerts/2026-06/low-2026-06-15-A1905268493426452.md | written |
| ~/notes/.../resolved-alerts/2026-06/low-2026-06-15-A27033006496339561.md | written |

## Cluster / pattern references

- [CL-003] — scribe-quota blocking retrieval OT flows; proposal needs Quick-Match Table entry under CL-003

## Followup items (not yet done)

1. Add scribe-quota-blocking-retrieval-OT to CL-003 Quick-Match Table (owner: oncall, needed before next distillation run)
2. AMD GPU reset P-row ledger candidate: log to learnings-ledger.md pending 2+ more matching incidents

## Cross-refs

- SEVs discussed: S674838, S669133
- Related threads: `ByPlnIGg0ks`, `D1nJtPfn66Q` (same cron run window)
