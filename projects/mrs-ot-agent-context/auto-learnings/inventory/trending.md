# Per-Slice Trending Dashboard

_Stub — auto-populated daily by `INDEX.md`. Seeded 2026-05-20 from 2026-05-19/20 session triage observations._

## Top accumulating slices (24h, sorted by total incident count)

| Slice | Alerts 24h | SEVs 24h | Top Cluster | Top P-NNN | Notable |
|---|---:|---:|---|---|---|
| IG / Reels / holdout family | 5 | 0 | CL-013 | **P-007** | m878102693 + m2145491885 + m2132766001 + m2144816217 + m2145336177 ← cross-submodel-family spike |
| Facebook / CFR / baseline | 10+ | 1 (S665902) | CL-017 + CL-001 | P-002 + R-010 | Stale NaN detectors firing 67h post-recovery; conveyor regression active |
| Threads / Retrieval / trainer | 3 | 1 (S665454) | CL-012 | **P-002** | m2124122280 + m2124793203 + m2124428748 (Layer-1 CUDA assert R-001 / R-014) |
| infra-cross-pg / conveyor | 4 | 4 (S666322, S666413, S666451, S665902) | CL-004 | P-004 | umia_v1_igr OOM cluster + mvai_ifr_main LoweringLogicException + cfr_main ModuleNotFoundError |
| IG / Reels / starsearch_t2i | 2 | 1 (S659956) | CL-013 | platform-specific (MI300) | m2126189932 baseline + m2145491885 FBLearner |
| IG / Stories / streaming | 1 | 1 (S665464) | CL-013 | P-002 + P-004 | NCCL/Gloo mixed-PG hang affects 20-58 jobs/day across multiple oncalls |
| Facebook / Video / vdd_hstu | 1 | 0 | DETECTOR_BROKEN | P-005 | D75703936 TZ formula bug false-positive |

## 7-day rolling (24h × 7 — placeholder until cron lands)

```
Schema:
| Slice | Alerts 7d | SEVs 7d | Slope | Trend |
```

## 30-day rolling (placeholder)

```
Schema:
| Slice | Alerts 30d | SEVs 30d | Slope | Status |
```

## Slope flags

When a slice's 7d count exceeds 2× the prior 30-day rolling average → trigger `⬆️ accelerating` flag in the daily brief.

When a slice's 24h count appears with zero history in prior 7d → trigger `⬆️ NEW` flag.

When a slice's 24h count is zero but 7d+ accumulated → `🔄 monitoring (recent quiet)`.

## How this differs from `noisy-trends.md`

- `noisy-trends.md` = top-3 noisiest model_ids per cron run (single-model view)
- `trending.md` = aggregated per-PG/product slice (cross-model view)
- Both updated daily; `noisy-trends.md` is finer-grained, `trending.md` is the structural-ask layer

## How this differs from `../failure-patterns.md` master table

- `failure-patterns.md` = clusters sorted by impact, no PG/product axis
- `trending.md` = same impact axis SLICED by PG/product/role
- Combined: failure-patterns answers "what's the worst cluster overall"; trending answers "where is each cluster concentrating"

## Auto-update protocol

**Status:** manual snapshot. Refresh during weekly review.

1. Cron runs daily at e.g. 09:00 PDT (after the 21:00 PT mitigated-* trio)
2. Reads `incidents/resolved-*/2026-MM/*` archives for last 30d
3. Reads active SEV list (`meta sevmanager.sev list --tags mvai-online-training --in-progress`)
4. Reads active alert list (`meta monitoring.alert list --oncall mrs_online_training --state-is ACTIVE`)
5. Joins each incident with `workloads.md` row → derives PG/product/role
6. Counts per (PG, product, role, S/M/R/P/D) tuple over 24h / 7d / 30d windows
7. Writes `trending.md` and `heatmap.md` atomically
8. Emits one alert to operator if any cell crosses hot threshold

Until cron lands: manual updates from operator session observations.
