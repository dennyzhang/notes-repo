# Thread Summary: Holdout Periodic Stall + 5-Layer S/M/R/P/D Ontology Migration

_Source: spaces/AAQAVOjYc80 thread `MQwOLaC3jLc` · 24 messages · 2026-05-20_
_Summarized: 2026-05-21 00:41 PT · last-msg-time: 2026-05-20T22:37:21Z_

## What was discussed

Started with a THRESHOLD_MISFIT triage for ig_mixed_ifr_u2i_combined_omni_retrieval (2145336177). Denny challenged the verdict by pointing to MAST system metrics showing QPS drops to 0 for ~25 min/hr on a regular cycle. Discussion expanded to the QE validity implications of holdout-specific periodic freshness degradation, the structural gap in current top-error-pattern registry, and the design of a 5-layer S/M/R/P/D ontology for OT failure knowledge. Concluded with Denny approving Proposal G and asking to finish the migration — bot committed all 5 layers including patterns-beyond.md.

## Key decisions made

- (2026-05-20T22:11Z) m2145336177 has **real periodic 25min/hr training stalls**: system metrics show p50 SM utilization = 0.92% (fleet avg 36.52%), p25 GPU device util = 0.0%, max = 99.99% — trainer alternates between full-speed bursts and full idle. THRESHOLD_MISFIT verdict was wrong; this is [CL-013] (training example-age spike) with underlying periodic stall mechanism.
- (2026-05-20T22:09Z) **Periodic spikes ≠ random noise for holdouts**: holdout periodic freshness stalls contaminate QE measurements (holdout vs baseline delta is biased by freshness gap, not just treatment effect). "36% chronically noisy" holdout heuristic in team_context may have been mis-labeling real periodic freshness degradation as noise.
- (2026-05-20T22:15Z) **failure-patterns.md registry-first triage discipline added to Proposal F**: bot should grep failure-patterns.md for symptom keywords before emitting any verdict; top error patterns are catalogued, re-deriving them from scratch is a discipline failure.
- (2026-05-20T22:19Z) **Two-layer root-cause model**: root causes have (1) immediate bad change that introduced the problem AND (2) the structural error pattern behind it (e.g., main thread blocked in heavy op → nickel timeout; stalker didn't handle event; Python GIL). Bot should identify the structural pattern, not just the immediate recourse.
- (2026-05-20T22:22Z) Denny approved migration of failure-patterns.md to 4-layer S/M/R/D → then to **5-layer S/M/R/P/D** (patterns-beyond layer P-α through P-θ).
- (2026-05-20T22:34Z) Migration committed: `auto-learnings/patterns/` directory with symptoms.md, mechanisms.md, root-causes.md, defenses.md, edges.md, patterns-beyond.md, README.md.

## Files / artifacts touched

| path | what changed |
|---|---|
| `auto-learnings/patterns/symptoms.md` | NEW — S-001..S-009 |
| `auto-learnings/patterns/mechanisms.md` | NEW — M-001..M-018 |
| `auto-learnings/patterns/root-causes.md` | NEW — R-001..R-036, two-layer model |
| `auto-learnings/patterns/defenses.md` | NEW — D-001..D-025 |
| `auto-learnings/patterns/edges.md` | NEW — S↔M↔R↔P↔D weighted graph |
| `auto-learnings/patterns/patterns-beyond.md` | NEW — P-α..P-θ structural pattern layer |
| `auto-learnings/patterns/README.md` | NEW — 5-layer architecture + triage flow |
| `auto-learnings/failure-patterns.md` | Updated: Type column added; header points to patterns/ |
| `IMPROVEMENT-PROPOSALS.md` | Proposal F: registry-first triage; Proposal G: ontology design |

## Cluster / pattern references

- [CL-013] Training example-age spike — m2145336177 is a live instance; this is the #1 OT symptom with no dashboard
- [CL-003] Downstream-infra reliability — DPP data starvation 1.94% flat (ruled out as cause of 25min stall; other mechanism)

## Followup items (not yet done)

1. Phase 3-4 of ontology migration: full edge weight population from historical archives + cron-prompt rewrite to traverse S→M→R→P→D explicitly
2. Denny mentioned push was still wedged (Bundle2 server-side error) — auto-sync cron carries commits

## Cross-refs

- SEVs discussed: S665902, S665454, S665478, S661645
- Related threads: `4u3oOvwSD30` (elastic-agent zombie class), `jrXXZbszX8E` (enforcement hooks)
