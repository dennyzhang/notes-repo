# `auto-learnings/` — What the Bot Learned

Bot-generated pattern distillations, failure registries, and operational lessons. Everything here is produced by crons or triage sessions — not hand-written by humans (that goes in `human-input-domain/`).

## Start here for triage

→ **[`patterns/INDEX.md`](patterns/INDEX.md)** — operator entry point with Failure Landscape (bird's-eye view), top-5 hot symptoms, and 3 most-traveled S→M→R→P→D triage paths. Read this first.

## Structure

```
auto-learnings/
├── INDEX.md                           ← This file
├── daily-ledger.md                    ← Append-only operational lessons (ot-daily-learning-debugging cron)
├── noisy-trends.md                    ← Chronic-noisy tracking: alerts + SEVs + posts in one view
├── patterns/                          ← Cluster registry + knowledge graph + deep-dive catalogs
│   ├── INDEX.md                       ← Operator entry point — read first
│   ├── failure-patterns.md            ← Stable CL-NNN cluster registry (TL surface)
│   ├── sjd-coverage-map.md            ← SJD stuck-job detection gap catalog (CL-012)
│   ├── DESIGN.md                      ← Schema rationale, migration status
│   ├── symptoms.md                    ← S-NNN (11 entries) — what we observe
│   ├── failure-modes.md               ← M-NNN (17 entries) — how it's broken right now
│   ├── root-causes.md                 ← R-NNN (32 entries; 8 families) — specific bad change
│   ├── systemic-causes.md             ← P-NNN (8 entries) — recurring causal shape
│   ├── mitigations.md                 ← D-NNN (25 entries; 7 families) — landed + proposed mitigations
│   └── _data/edges.md                 ← Machine-consumed S↔M↔R↔P↔D edge graph
├── inventory/                         ← The WHERE axis (PG/product/model attribution)
│   ├── README.md                      ← How inventory complements patterns/
│   ├── workloads.md                      ← One row per OT prod model
│   ├── taxonomy.md                    ← PG → product → model_type → role hierarchy
│   ├── trending.md                    ← Per-slice alert/SEV rates
│   └── heatmap.md                     ← PG × pattern accumulation matrix
├── digests/                           ← Cross-incident synthesis (weekly + monthly in one flat dir)
│   ├── 2026-W{17..21}.md             ← Per-week digests (ot-knowledge-distillation cron)
│   └── TREND-4-week-*.md             ← Monthly synthesis (regenerate at month-end)
└── deep-dives/                        ← Incident-derived reference docs (triage examples, deep dives)
    ├── auto-learn-p27-example.md      ← Worked example: how a triage produces a P-row
    ├── worked-example-S644354.md      ← End-to-end Phase 1→3 routing example
    ├── ot-sev-scope-rejections.md     ← 124-SEV regression fixture for OT-scope rule
    ├── delta-publishing-failure-modes.md
    ├── dense-delta-shape-invariant.md
    ├── publishing-stability-alerts.md
    ├── restart-mechanism-analysis.md
    └── sev-deep-dives.md
```

## What produces what

| Cron | Output | Cadence |
|---|---|---|
| `ot-daily-learning-debugging` | `daily-ledger.md` (append) | Nightly |
| `ot-daily-learning-mitigated-alerts` | `noisy-trends.md § Alerts` (append) | Nightly |
| `ot-knowledge-distillation` | `digests/2026-W<NN>.md` | Weekday |
| `ot-knowledge-curation` | `patterns/failure-patterns.md` (review) | Nightly 23:00 PT |
| Operator promotion | `digests/TREND-*.md` | Month-end |
| Triage sessions | `deep-dives/` (ad hoc) | On discovery |

## Key relationships

- **daily-ledger.md** → proposes pattern additions (P-rows) and implementation deltas → tracked in **`../auto-fixes/YYYY-MM/`** (one file per fix)
- **digests/** → cross-incident synthesis → promoted to **patterns/failure-patterns.md** when a cluster stabilizes
- **patterns/failure-patterns.md** ← cross-linked from `incidents/resolved-*/INDEX.md` via CL-NNN IDs
- **patterns/** ← graph view of the same knowledge (S/M/R/P/D entities); CL-NNN clusters cross-linked from individual M-NNN / R-NNN entries
- **inventory/** ← the WHERE-axis; `heatmap.md` cross-cuts patterns/ entities × PG/product slices
- **deep-dives/** → worked examples and deep dives; link to `mrs-ot-agent-src/SKILL.md` and `mrs-ot-agent-src/known_patterns.md`

## Cross-references

- Cluster registry: `patterns/failure-patterns.md`
- Knowledge graph entry point: `patterns/INDEX.md`
- Known patterns (P-rows): `../../mrs-ot-agent-src/known_patterns.md`
- Triage discipline: `../human-input-domain/triage-discipline.md` (OT-specific) + `../human-input-generic/triage-methodology.md` (generic)
- SKILL.md: `../../mrs-ot-agent-src/SKILL.md`
- Human-curated domain input: `../human-input-domain/`
- Per-incident archives: `../incidents/resolved-{sevs,posts,alerts}/`
