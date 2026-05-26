# Thread Summary: Starcart/TMS Concepts, OT Auto-Start Gap, Mega-Learnings Refactor

_Source: spaces/AAQAVOjYc80 thread `8LLIVF1l7Yw` · 37 messages · 2026-05-16 00:21 PT → 2026-05-16 13:21 PT_
_Summarized: 2026-05-16 21:32 PT · last-msg-time: 2026-05-16T20:21:27Z_

## What was discussed

Triage of m2124118880 (ig_reels_tab_mtml) — starcart diff landed but OT job didn't auto-restart (`online_ready` state). Validator confirmed R15 (disabled recurring flow). Thread expanded into starcart/TMS/recurring-flow architecture, creating a concepts glossary, logging the systemic OT auto-start gap as a mega-learning, refactoring mega-learnings for actionability, and creating the CLUSTERS.md registry.

## Key decisions made

- **2026-05-16T07:21Z** — Validator confirmed 8/10 velvinfu flows disabled; R15 hypothesis stands.
- **2026-05-16T18:01Z** — `references/concepts.md` created: glossary for Recurring Flow, Starcart, TMS, MAST, STUS, DPP, snapshot types, R-rules.
- **2026-05-16T18:03Z** — OT auto-start gap logged in `2026-W20.md` (N=2 with S664106); proposed liveness probe: `(now - last_mast_attempt_start) > 2× expected_launch_interval`.
- **2026-05-16T19:19Z** — `CLUSTERS.md` with [CL-001..CL-011]; TREND refactored with 3-tier action framework; CL-009 included.
- **2026-05-16T20:21Z** — 5 `sl-goto` casualty events documented; discipline: always `sl add <file>` explicitly, never `sl add <directory>`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/references/concepts.md` | NEW glossary |
| `mega-learnings/weekly/2026-W20.md` | OT auto-start gap entry appended |
| `mega-learnings/CLUSTERS.md` | NEW [CL-001..CL-011] registry |
| `mega-learnings/cross-week/TREND-4-week-2026-W17-W20.md` | 3-tier refactor |
| `mega-learnings/weekly/2026-W17.md`, `2026-W18.md` | NEW (backfill) |

## Cluster / pattern references

- [CL-009] — OT auto-start silent stall. Thread is the N=2 evidence base; drove liveness probe proposal.

## Followup items (not yet done)

1. Implement `ot-autostart-liveness` cron (deferred to `ot-knowledge-curation` D1 proposal process).

## Cross-refs

- SEVs: S664106 (Mitigated, m2128461099 cannot get started)
- Posts: W1326836659411077 (renqincai, starcart no auto-restart)
- Related threads: `pAM4x2WxE0c`
