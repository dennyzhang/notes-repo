# Thread Summary: Full Ownership Principle P-016 — Enforcement in OT Master Agent

_Source: spaces/AAQAVOjYc80 thread `wf45Cu8OLzc` · 10 messages · 2026-05-18T20:30–T20:57Z_
_Summarized: 2026-05-19 00:41 PT · last-msg-time: 2026-05-18T20:57:21Z_

## What was discussed

Denny established a standing generic principle: "whenever you fix a diff or an issue, you should have full ownership." The bot initially mis-read the thread (replied in the wrong parent thread three times). After correction, the principle was codified as P-016 and enforced in 4 places. The thread also surfaced that a QE-model two-axes triage discipline (Axis 1: prod-baseline-parallel check for model-vs-infra; Axis 2: sibling-recurring-training-flow check for OT-specific vs generic-MVAI) was separately landed, and a tooling-gap task (T271983239) was filed for reliable QE→prod-baseline-model_id lookup.

## Key decisions made

- **2026-05-18T20:54Z** — P-016 (full ownership on every fix) defined as a standing rule. 8-step chain: diagnose end-to-end → land without confirmation-gating → verify → push → monitor consequence → close the loop explicitly → update docs → don't write "want me to..." for obvious yeses.
- **2026-05-18T20:54Z** — P-016 is generic (cross-domain), not OT-specific. Placed in `human-input-generic/principles/` and indexed.
- **2026-05-18T20:57Z** — `team_bot/CLAUDE.md` correctly references P-016 as a cross-cutting principle (not OT-specific lane claim). Commit `2f8be5b66e64`.
- **2026-05-18T20:54Z** — Commit `fdd3f61df582` enforces P-016 in: principles/P-016 file, principles/INDEX.md, `~/.myclaw-ot-bot/RULES.md`, `team_bot/CLAUDE.md`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `human-input-generic/principles/P-016-full-ownership-on-every-fix.md` | Created: 8-step chain, decision tree, anti-patterns |
| `human-input-generic/principles/INDEX.md` | P-016 indexed under Agent-behavior principles |
| `~/.myclaw-ot-bot/RULES.md` | New section: "Full ownership on every fix" after "Act, don't ask" |
| `team_bot/CLAUDE.md` | P-016 added to auto-loaded-principles list and READ BEFORE EDITING trigger |
| `ot-alert-monitor.md` step i-a.4 | QE-model two-axes triage (Axis 1 + Axis 2) rewritten; commit `ca5f9e25a703` |

## Cluster / pattern references

- [CL-009] — QE model silent stall; cited in Axis 2 (sibling recurring-training-flow check)
- [CL-013] — training-example-age detector; cited in Axis 1 context (prod baseline is the reference job)

## Followup items (not yet done)

1. T271983239 — Reliable QE→prod-baseline-model_id lookup tooling. Owner: dennyzhang. Status: filed/open. When resolved: re-edit `ot-alert-monitor.md` i-a.4 Check A, add regression test fixture (5 known QE→prod-baseline mappings).

## Cross-refs

- SEVs discussed: S665478 (QE model triage context)
- Posts: none
- Related threads: `GYc3DyFl2pU` (nested-fallback call-out that preceded this thread)
