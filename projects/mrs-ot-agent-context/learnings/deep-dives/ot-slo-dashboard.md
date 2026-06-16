# OT SLO Dashboard — Data Source & Query Reference

_Discovered 2026-05-26. POC: Josef Cohen (jcohen1@meta.com)._

## Dashboard URL

`https://ig-data-apps.internalmeta.com/ig/relevance-foundations/online-training-slo`

Requires browser authentication — cannot be fetched via curl/API.

## Source Code

| Component | Path |
|---|---|
| Dashboard app | `nest/apps/ig_data_apps/app/(authenticated)/ig/relevance-foundations/online-training-slo/` |
| Data layer (SQL builders) | `...online-training-slo/_data.ts` |
| Constants (SLO thresholds, model defs) | `...online-training-slo/_constants.ts` |
| Upstream pipeline | `fbcode/dataswarm-pipelines/tasks/instagram/home/ig_ot_model_latency.py` |

## Data Tables

| Table | Namespace | Purpose |
|---|---|---|
| **`ig_ot_model_slo`** | `instagram` | Primary SLO table — hourly pass/fail per model × snapshot_type |
| **`ig_online_training_ats`** | `instagram` | Component-level latency (Scribe + Inference stages) |
| **`sigrid_predictor_pa`** | `ad_metrics` | Raw inference-time model ages (`sparse_delta_model_age`) |

## Sparse Latency SLO Definition

**SLO threshold:** Scribe delay (P90) + Model age (P50) ≤ 10 minutes (`LATENCY_SLO_THRESHOLD_MINS = 10`)

- **Scribe delay**: `APPROX_PERCENTILE(client_lag_in_seconds, 0.9) / 60.0` from `scribe_read_proxy`, filtered to `model_category = 'DENSE_SPARSE'`
- **Model age**: `APPROX_PERCENTILE(sparse_delta_model_age / 60.0, 0.50)` from `sigrid_predictor_pa`, with fallback to `full_snapshot_model_age` when sparse delta is zero/negative
- Snapshot type filter: `SPARSE_DELTA`

## How to Query Directly

```sql
-- Models failing sparse latency SLO (<95% pass rate, last 7 days)
presto instagram --execute "
SELECT
  model_type, snapshot_type,
  ROUND(AVG(CAST(latency_slo_met AS DOUBLE)) * 100, 1) AS latency_slo_pct,
  ROUND(AVG(end_to_end_latency_mins), 1) AS avg_e2e_latency_mins,
  COUNT(*) AS hours_measured
FROM ig_ot_model_slo
WHERE ds >= DATE_FORMAT(DATE_ADD('day', -7, CURRENT_DATE), '%Y-%m-%d')
  AND snapshot_type = 'SPARSE_DELTA'
GROUP BY model_type, snapshot_type
HAVING AVG(CAST(latency_slo_met AS DOUBLE)) * 100 < 95
ORDER BY latency_slo_pct ASC
"
```

## Snapshot (2026-05-26, last 7 days)

| Model | SLO % | Avg E2E (min) | Status |
|---|---|---|---|
| ig_reels_tab_esr_ttsn | 3.0% | 59.2 | 🔴 Critical |
| ig_organic_feed_mtml | 31.0% | 42.7 | 🔴 Critical |
| ig_reels_tab_vm_esr | 33.3% | 11.1 | 🔴 Severe |
| ig_reels_tab_cs_omni_retrieval | 74.4% | 11.1 | 🟡 Moderate |
| ig_reels_tab_ss_omni_retrieval | 96.4% | 4.5 | ✅ |
| ig_mixed_feed_smsl_esr | 97.0% | 6.3 | ✅ |
| ig_reels_tab_mtml | 97.6% | 5.0 | ✅ |
| ig_feedrec_esr_ttsn | 98.8% | 6.8 | ✅ |
| ig_feed_recs_ifr_t2i_retrieval | 99.4% | 4.4 | ✅ |
| ig_reels_starsearch_t2i_retrieval | 100.0% | 2.4 | ✅ |
| ig_mixed_ifr_u2i_combined_omni_retrieval | 100.0% | 5.8 | ✅ |
