# SLICK Data Pipeline — reliability + known data gaps (OT SLO/SLI source)

What SLICK is, how its data is filled, why it has gaps, and who owns it. SLICK is
the data system behind many OT SLO/SLI signals (model-stability metrics, Hedwig
streaming-success SLI, etc.). **A gap or 0 in a SLICK-sourced metric is often a
SLICK *data-pipeline* artifact, NOT a real OT regression — rule that out before
triaging it as an incident.**

Source: OT-SLICK GChat space `spaces/AAQATpEgSyk`, Clement Chang's walkthrough to
Li Lu, 2026-06-12. Backfill monitoring dashboard: `fburl.com/monitoring/kd4z0nog`.

## Ownership (as of 2026-06-12)
- **POC: Clement Chang** (cchang) — new primary POC for OT SLICK.
- **Backup: Anthony Foiani** (ajfoiani).
- Team: `pe_mrs_ml`. See [`../human-input/knowledge/ownership.md`](../human-input/knowledge/ownership.md).

## How the fill works
- SLICK runs its data fill on a **daily cadence**.
- The daily run **frequently hits OOM** — a **fixed per-query Velox pool limit**
  (the same limit that constrains the backfill). When it OOMs, recent data is
  left unfilled.
- **Workaround in place:** Clement started a **manual backfill script on a 6-hour
  cadence** to fill in newer data between/around the failing daily runs.

## Two buckets of missing data (don't conflate them)
1. **New / recent missing data** = the daily-fill **OOM (Velox pool limit)** above.
   Mitigated by the 6h manual backfill, but recent gaps can still appear until a
   backfill pass covers them. → a fresh gap is likely THIS, not an OT outage.
2. **Old missing data** = **mapping / definition problems, not backfill failures:**
   - `model_id` ↔ `model-type` mapping issues.
   - SLO / SLI definition issues.
   An **audit is running** to address these.

## Triage implications for the OT agent
- Before treating a SLICK-sourced metric hole/0 as an OT incident, check the
  backfill dashboard (`kd4z0nog`) and consider the two buckets above. A recent
  gap during/after a failed daily fill is a data artifact.
- If the gap is real-data-pipeline (OOM or mapping/def), route to **Clement Chang**
  (backup Anthony Foiani), not to an OT component oncall.
- This is part of the broader **dependent-SLA** theme (give the owning team strong
  evidence that the problem is theirs) — see
  [`dependency-sla.md`](dependency-sla.md) and the DPP-starvation analog
  [[reference_dpp-starvation-ods-vs-consumer-queue]].
