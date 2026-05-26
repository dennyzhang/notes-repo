# Thread Summary: failure-patterns.md Editing Session — Structure and Naming Overhaul

_Source: spaces/AAQAVOjYc80 thread `4u3oOvwSD30` · 17 messages · 2026-05-18T16:13–16:36Z_
_Summarized: 2026-05-18 23:43 PT · last-msg-time: 2026-05-18T16:36:32Z_

## What was discussed

A multi-round iterative editing session on `failure-patterns.md`. Denny provided 7 feedback rounds covering naming accuracy, scope classification, table structure, and information density. The bot landed 5 commits implementing the changes.

## Key decisions made

- (2026-05-18T16:21Z) **CL-013 renamed** "Training-age / example-age spike" → "Training example-age spike" (single canonical name; 9 locations updated; naming history note added).
- (2026-05-18T16:21Z) **IG 10-min ATS highlight added** to 30-second summary — MRS delivered IG 10-min ATS for all launched models, exceeding prior assessment at fb.workplace.com/groups/1676744619923718/posts/1972811233650387.
- (2026-05-18T16:24Z) **3-month SEV table sorted by importance** (matching scannable index); total SEV count and MoM growth added to 30-sec summary.
- (2026-05-18T16:26Z) **CL-017 (Shampoo NaN) → out-of-scope** — NaN in optimizer state is model-side (gradient stability, hyperparameter choice). Bot routes via R21 but fix belongs to model teams.
- (2026-05-18T16:26Z) **CL-003 upleveled** to "Downstream-infra reliability (DPP / ZippyDB / Scribe)" — DPP added as explicit third component.
- (2026-05-18T16:28Z) **"(Not OT-owned)" added** to CL-017 and CL-004 in all table locations.
- (2026-05-18T16:30Z) **"Leadership ask?" column dropped** from scannable index (redundant with per-cluster "What's needed"). CL-017/CL-004 sunk to bottom of 3-month table with MRS-OT-owned subtotal row (11 SEVs).
- (2026-05-18T16:34Z) **CL-018 renamed** → "Alert noise (AGG / dead-detector / TEST rules)". **CL-011 renamed** → "Linux signal handling with unexpected job kill". Scannable index tightened.
- (2026-05-18T16:35Z) **Bot held position** on CL-001/CL-003/CL-007 merge request — distinct mechanisms (real failures vs downstream cascade vs sibling-org noise); merging would lose the operational distinction.
- (2026-05-18T16:35Z) **4 classification tables → 1 master pattern table** (17 rows, status icons 🔴/🟡/🔵/⚪/⛔). Net: 7 tables → 4 total.

## Files / artifacts touched

| path | what changed |
|---|---|
| `auto-learnings/failure-patterns.md` | 5 commits: 2a640195f6aa, 5447db986476, 01de4642bc63, 0e5803540175, 5e70b12c7e83 |

## Cluster / pattern references

- [CL-001], [CL-003], [CL-004], [CL-007], [CL-011], [CL-013], [CL-014], [CL-017], [CL-018] — all restructured/renamed in this session

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- SEVs discussed: _(none specific)_
- Posts: _(none)_
- Related threads: `hzYfILxPOi0` (same day, CL-003 / S665163 archive quality fix that fed into this session)
