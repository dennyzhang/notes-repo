# OT Prod-Workload Inventory

_Created 2026-05-20 thread `pjTRT7ubzUs`. The WHERE axis to complement the WHAT axis in `../patterns/`._

The patterns/ knowledge graph captures what kinds of failures exist. This directory captures **what OT actually runs** — the prod inventory — sliced by Product Group / product / model_type / role. Together they enable: per-PG trending, cross-model spreading-detection, and structural prioritization.

**Status:** manually-seeded snapshots from 2026-05-20. No automated cron maintains these files yet — update manually when triage reveals changes.

## Files

| File | Contents |
|---|---|
| `workloads.md` | One row per OT prod model — model_id, model_type, PG, oncall, owner, role, status, notable history |
| `taxonomy.md` | PG → product → model_type → role hierarchy |
| `trending.md` | Per-slice alert/SEV count rates (manual snapshot 2026-05-20) |
| `heatmap.md` | PG × pattern (S/M/R/P/D) accumulation matrix (manual snapshot 2026-05-20) |

## How this complements patterns/

| Question | patterns/ answers | inventory/ answers |
|---|---|---|
| What kind of failure? | S-001 example_age spike | n/a |
| What's the mechanism? | M-011 holdout periodic data-cycle stall | n/a |
| What's the immediate cause? | R-025 FS publish boundary blocking | n/a |
| What's the systemic cause? | P-007 periodic sync-op vs training | n/a |
| What's the defense? | D-001 external liveness probe | n/a |
| **Which model is affected?** | n/a (entities mention model IDs in evidence) | `workloads.md` row + status |
| **Which PG/product?** | n/a | `taxonomy.md` |
| **How many siblings affected?** | n/a | `heatmap.md` cell + `trending.md` window |
| **Is this PG accelerating?** | n/a | `trending.md` slope per slice |

## Maintenance

- **`workloads.md`** — canonical inventory; update rows when status changes during triage.
- **`taxonomy.md`** — human-curated; refresh when new product lines emerge.
- **`trending.md`** + **`heatmap.md`** — manual snapshots; refresh during weekly review.
- When a model retires (status=closed): keep the row, mark `status: retired`, don't delete (historical reference).
