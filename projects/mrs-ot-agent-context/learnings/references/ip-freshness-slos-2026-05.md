# IP Freshness SLOs Refresh — Context for OT Master Agent

**Source:** https://fb.workplace.com/groups/1174357867890257/permalink/1365605282098847/
**Author:** Meghan Kast (AIDI Inference) | **Date:** 2026-05-27
**Distilled:** 2026-05-28 for OT triage context

---

## Why this matters to OT

OT publishes model snapshots (full + delta). IPnext/Pacer consumes them for serving. These new SLOs measure the **gap between when OT publishes and when serving finishes transition** — called Time Since Divergence (TSD). When OT publishing is slow, stale, or broken, it directly degrades these SLOs.

## Key concepts

- **Time Since Divergence (TSD):** latency from when a snapshot is published to when it is fully serving across ALL tasks. TSD=0 means up-to-date. This replaces raw model age as the freshness metric.
- **Why TSD, not model age:** TSD excludes training/publishing delays — it measures ONLY inference platform health. OT's training example age and publishing cadence are upstream of TSD.
- **Staleness thresholds:**
  - NON_INPLACE (full snapshot): 4 hours
  - INPLACE (delta): min(publishing_frequency, 1 hour)

## The 4 SLOs

| Bucket | Metric | Goal | Attainment (5/4-5/18) |
|---|---|---|---|
| FEED PACED (CRITICAL, Tier 1-2) | <5% tenants stale | 98% | 99.9% |
| FEED PACED (NON CRITICAL, Tier 3+) | <15% tenants stale | 98% | 100% |
| IG PACED (CRITICAL, Tier 1-2) | <5% tenants stale | 98% | 100% |
| IG PACED (NON CRITICAL, Tier 3+) | <15% tenants stale | 98% | 100% |

Dashboard: `bunnylol slick ipnext/freshness`

## Streaming gap (critical for OT)

- Streaming SLOs are **experimental, not enforced** — consistently violating
- Root cause: **only 5% of Critical models and 20% of Non-Critical models have up-to-date publishing packages**
- Old packages don't emit "end messages" needed for success rate reporting → runtime never reports success → SLO dips
- **OT implication:** when OT enables streaming on a model, the publishing package version matters. Old packages = invisible streaming failures.
- Next steps: block new model loads with outdated packages, send tasks to model owners to update

## What OT oncall should know

1. **When a freshness SEV fires, check TSD first** — not model age. TSD isolates inference from training/publishing.
2. **INPLACE (delta) threshold = min(publishing_frequency, 1 hour)** — this ties directly to OT's delta publish cadence. If OT publishes deltas every 100 min but inference expects 60 min, inference becomes the bottleneck.
3. **Streaming SLO is dark for most models** — don't trust streaming success rate metrics if the model has an outdated publishing package. Check package version first.
4. **The Feed Critical SLO was violating during the war room** — the new SLOs correctly detected what the old ones missed. These are the right SLOs to watch.
5. **Aspirational SLOs exist** with tighter thresholds (3%/2% for Critical) — these are where the bar is heading.

## Links

- Slick dashboard: `bunnylol slick ipnext/freshness`
- Streaming audit: https://docs.google.com/document/d/1b1Gqgu0fMa-ogIU7WPXZDtlm0v7F22JzKvlwkBpMs2o/
- Freshness incident workstream: https://docs.google.com/document/d/17Ovxga2F2_N36C7u66YeimujGJXm2l2ZqXWp9CefVHA/
- Critical models streaming coverage: https://docs.google.com/document/d/1jLy8M3fdIc5NlW80MAh7nAHZ2Z7cW1Xawak103Wr1OM/
