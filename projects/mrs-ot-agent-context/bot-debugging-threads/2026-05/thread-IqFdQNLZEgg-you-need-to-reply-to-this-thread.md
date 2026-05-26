# Thread Summary: auto-learnings/patterns Reorganization + Standard SRE Vocabulary

_Source: spaces/AAQAVOjYc80 thread `IqFdQNLZEgg` · 46 messages · 2026-05-21 00:01–00:52 UTC_
_Summarized: 2026-05-24 16:51 PT · last-msg-time: 2026-05-21T00:52:02Z_

## What was discussed

A long working session reorganizing `auto-learnings/patterns/`. Bot added `INDEX.md` with a hot-symptoms table, triage paths, and an R-family × D-family coverage matrix that surfaced "0 of 8 systemic causes have a landed structural mitigation." Folder `mega/` → `summaries/`. Bespoke layer names replaced with standard SRE vocabulary. Denny asked whether the 5-layer model and term "Pattern-Beyond" were industry-standard — they weren't; bot proposed mapping to standard terms.

## Key decisions made

- **2026-05-21T00:03Z** — Execute A+B+C+E+F: create `INDEX.md`, add S-010/S-011 symptoms, move `edges.md` to `_data/`, renumber Greek P-letters → P-001–P-008, rename `README.md` → `DESIGN.md`. Commits `ddb36bd120b4`, `039612203d9d`.
- **2026-05-21T00:28Z** — Rename `mega/` → `summaries/`. Commits `11cc37298fe2` + `7c5ce33f1e06`.
- **2026-05-21T00:48Z** (Denny: "go") — Rename entity-type files to standard SRE vocab: `mechanisms.md` → `failure-modes.md`, `patterns-beyond.md` → `systemic-causes.md`, `defenses.md` → `mitigations.md`. Entity IDs (S/M/R/P/D-NNN) kept. Commit `f1f0a52eeca7`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `auto-learnings/patterns/INDEX.md` | Created with Failure Landscape tables |
| `mechanisms.md` / `patterns-beyond.md` / `defenses.md` | Renamed to `failure-modes.md` / `systemic-causes.md` / `mitigations.md` |
| `auto-learnings/README.md` → `DESIGN.md` | Renamed; terminology-note section added |
| `auto-learnings/mega/` → `auto-learnings/summaries/` | Dir rename + ~40 cross-refs updated |

## Cluster / pattern references

- [P-001] cited as walkthrough example showing why systemic-cause layer exists (multiple R-NNNs share one systemic cause)

## Followup items (not yet done)

1. Proposal H: per-entity hot-tables from `_data/hot-counts.yaml` daily cron — not executed; bot asked, no operator approval yet.
2. Cron-source rename: 8 `mega-learning` refs in `fbcode/pe_mrs_ml/mrs_ot_agent/` — deferred.

## Cross-refs

- SEVs discussed: S665478, S665454, S658165 (evidence examples for S-010/S-011)
- Related threads: `MQwOLaC3jLc` (origin of Proposal G / patterns-beyond concept)
