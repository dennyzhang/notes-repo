# Thread Summary: S665135 Shampoo NaN — CL-017 Update + P56 + CL-009 Reattribution

_Source: spaces/AAQAVOjYc80 thread `gMO2L7p9xaM` · 6 messages · 2026-05-17 04:05 – 14:05 UTC_
_Summarized: 2026-05-17 13:31 PT · last-msg-time: 2026-05-17T14:05:33Z_

## What was discussed

`ot-daily-learning-mitigated-sevs` cron produced a postmortem for S665135 (QE Model — TIFU ESR PNUA model train+publish failure, L4, ~2h3m). Root cause: NaN in Shampoo optimizer's second moment matrix (exploding gradients). Bot caught that S665135 had been previously misattributed to CL-009 (snapshot-stuck) — the real mechanism is Shampoo NaN cascade, which belongs to CL-017.

Additionally, CL-017 was updated with a weekend observation: 4 events in 18h, 2 newly identified sub-mechanisms (#5 NCCL-gradient, #6 tainted-checkpoint cascade). This accelerated CL-017's status.

Operator: "Act, don't ask" at 2026-05-17T14:05Z → bot pushed all 4 actions in one commit without seeking confirmation.

## Key decisions made

- **2026-05-17T04:05Z** — Cron output confirmed S665135 root cause = Shampoo NaN; bot self-corrected prior CL-009 misattribution in the same commit.
- **2026-05-17T14:05Z** — "Act, don't ask" → CL-017 weekend update + P56 + CL-009 correction + CL-001 evidence update all pushed in one batch.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/mega-learnings/registry/CLUSTERS.md` | CL-017 status → ACCELERATING; 2 new sub-mechanisms; CL-009 S665135 evidence corrected |
| `mrs-ot-agent-context/known_patterns.md` | P56 added: Shampoo NaN cascade (single-version + tainted-checkpoint-cascade signatures); count 51→52 |
| `mrs-ot-agent-context/mitigated-sevs/2026-05/` | S665135 archive file added |

Commit: `535ad143103f` (reattribution), `819fc7701ac2` (weekend update + P56 + CL-001 evidence).

## Cluster / pattern references

- [CL-009] — Snapshot-stuck variant; S665135 incorrectly cited here — evidence removed, corrected to CL-017
- [CL-017] — Shampoo NaN cascade (new in this session area); updated to ACCELERATING status; 4 events in 18h window; 6 sub-mechanisms now documented

## Followup items (not yet done)

_(No followups discussed.)_

## Cross-refs

- SEVs discussed: S665135
- Related threads: `gMO2L7p9xaM` is self-contained; see `ZP2y-6Bdpwk` for CL-017 genesis
