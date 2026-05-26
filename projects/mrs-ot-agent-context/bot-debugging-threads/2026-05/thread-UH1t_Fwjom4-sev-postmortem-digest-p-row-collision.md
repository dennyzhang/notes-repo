# Thread Summary: SEV Postmortem Digest — Dual-Cron P-Row Label Collision

_Source: spaces/AAQAVOjYc80 thread `UH1t_Fwjom4` · 9 messages · 2026-05-20T04:09–05:39 UTC_
_Summarized: 2026-05-20 23:45 PT · last-msg-time: 2026-05-20T05:39:53Z_

## What was discussed

Two independent SEV postmortem digest crons ran overnight and both proposed new P-row entries for S651873 (TGIF TCPStore/Gloo rendezvous timeout) and S665607 (Koski PERMISSION_DENIED DPP ACL missing). Because neither cron shared state, they collided on P-row numbers — one picked P59/P60 (already reserved), the other derived P62/P63. The validator pass at 22:30 PT identified the collision and flagged the resolution.

## Key decisions made

- **S651873 (TGIF rendezvous) → P20 partial amend, NOT a new row** (2026-05-20T05:39:53Z validator): S651873 TCPStore/Gloo timeout in TGIF publish path partially matches existing P20 ("Concurrent delta + in-trainer TGIF conflict"). Amend P20 with IFR-trunk variant; don't mint a new row.
- **S665607 (Koski DPP ACL) → P62 NEW** (2026-05-20T05:39:53Z validator): P59 is reserved for "IFR Watchtower DENSE_DELTA false alarm" (2026-05-17), P60 is dead-detector, P61 is Conveyor regression. The Scribe ACL pattern is genuinely novel; assign P62.
- **S666282 stub-skipped** (04:09 UTC): postmortem fields empty, Opsmate data not checked. Confirmed correct skip by this cron; separate thread (dfL20Dft3XU) later discovered fix via agent-feed.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-sevs/2026-05/L4-2026-05-19-S651873.md` | Created by cron; label P20-partial pending amend |
| `incidents/resolved-sevs/2026-05/L4-2026-05-19-S665607.md` | Created by cron; label P62 pending land |

## Cluster / pattern references

- [CL-003] — S665607 Koski PERMISSION_DENIED on Scribe table is a DPP/Scribe cascade variant

## Followup items (not yet done)

1. Land P20 amendment (IFR-trunk TGIF variant) in known-patterns.md — deferred to Friday batch (owner: Denny)
2. Land P62 (Scribe ACL missing → Koski exitcode 100) in known-patterns.md — deferred to Friday batch (owner: Denny)

## Cross-refs

- SEVs discussed: S651873, S665607, S666282
- Related threads: `dfL20Dft3XU` (parallel cron run with conflicting P-row proposals)
