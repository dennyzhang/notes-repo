# Thread Summary: OT One-Pager Q&A Gdoc Editing Session

_Source: spaces/AAQAVOjYc80 thread `pQLWNSbGWO4` · 25 messages · 2026-05-18_
_Summarized: 2026-05-19 06:41 PT · last-msg-time: 2026-05-18T18:38:41Z_

## What was discussed

Denny directed MyClaw to author and iteratively refine 10 Q&A blocks in Tab 1 of the OT reliability one-pager Google Doc (doc `1EFyx6KNWaF1AxmB5zqdnPynGF3R-8SSM_Tgfxn5H7uE`, tab `t.eusr4jrjhb6b`). Questions from Denny, Shumin, Min, and Paul covered H1 SLO commitment status, dependent-service SLAs, SEV2 whitebox risk analysis, per-PG health, and reliability metric prioritization. Multiple rounds of correction were made for correctness, conciseness, in-place edits, and URL clickability.

## Key decisions made

- **CL-017 excluded from SEV2 risk list** (2026-05-18T18:02) — Denny corrected that Shampoo NaN cascades are not MRS-OT-owned. Only MRS-OT-owned failure modes belong in the whitebox analysis.
- **In-place doc edits, not bottom-appends** (2026-05-18T18:04) — Denny established that answers must replace the placeholder in-place; appending to bottom was wrong behavior.
- **ATS metric split into two rows** (2026-05-18T18:04) — "Sparse + Item ATS latency" → row 1: Sparse + Dense ATS latency (MVAI-owned); row 2: Item latency (SilverTorch-owned).
- **`insert markdown` mandatory post-insert sweeps** (2026-05-18T18:38) — Discovered `meta google.docs.insert markdown` silently strips bold from table headers AND URL linkification. Two sweep rules added to gdoc cheatsheet (commit `5ff73738132e`).

## Files / artifacts touched

| path | what changed |
|---|---|
| GDoc Tab 1 (`t.eusr4jrjhb6b`) | 10 Q&A blocks authored, corrected, and density-improved (22k → 17.8k chars, −19%) |
| gdoc cheatsheet (notes repo, commit `5ff73738132e`) | Added 2 mandatory post-insert sweep rules: bold table headers + URL/D/S/W linkification |

## Cluster / pattern references

- [CL-013] — top T1 reliability metric; cited in SEV2 risk and H1 commitment answers
- [CL-012] — SJD coverage gaps; ~512 GPU-hr/mo waste; cited as #1 SEV2 latent risk
- [CL-009] — OT auto-start silent stall; days detection lag; cited as #2 SEV2 latent risk
- [CL-001] — snapshot-stuck cascade; cited as #3 SEV2 latent risk
- [CL-003] — downstream-infra cascade; cited in dependent-SLA answer as core cascade mechanism
- [CL-017] — **explicitly excluded** as not MRS-OT-owned (model-side; Denny correction at 18:02)

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- SEVs discussed: S656663, S659917, S662001, S664657, S639386, S647178, S665163, S665185, S665236
- Posts: W2044577953140381 (Dave Kotfis OT Reliability Weekly 2026-05-18)
- Related threads: none cited
