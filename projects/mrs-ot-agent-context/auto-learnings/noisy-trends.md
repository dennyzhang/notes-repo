# Noisy Trends — Chronic-Repeat Signal Tracking

Unified view of chronic-noisy models/sources across all three incident surfaces. Each section is append-only (newest first), maintained by its respective daily-learning cron.

---

## Alerts (top-3 models by alert count, 7d, floor ≥3)

_Written by `ot-daily-learning-mitigated-alerts` cron._

| Run Timestamp PT | Rank | Model (type) | Alert Count (7d) | Signal Breakdown | Notes |
|---|---|---|---|---|---|
| 2026-05-31 22:05 PT | — | (no chronic-noisy models) | 0 | — | top models 2144816217 and 2133008573 at 2 alerts each, below ≥3 threshold |
| 2026-05-29 22:05 PT | 1 | 2130305043 (ig_reels_tab_cs_omni_retrieval) | 5 | unknown×5 (mixed AGG+SPARSE_DELTA from archive filenames) | recurring; last: A1002291152283272 1d ago; tied for top with 2144816217 |
| 2026-05-29 22:05 PT | 2 | 2144816217 (ig_reels_tab_ss_omni_retrieval) | 5 | client_lag_in_seconds×2, other×3 | CL-003 Scribe/ZippyDB; last: A2449443538836650 1d ago |
| 2026-05-29 22:05 PT | 3 | 2130324780 (ig_textpost_feed_m2m_retrieval) | 3 | FULL_SNAPSHOT×1, other×2 | persistent STUS corpus; last: A1009946182010606 7d ago; floor count |
| 2026-05-28 22:05 PT | 1 | 2144816217 (ig_reels_tab_ss_omni_retrieval holdout/STUS) | 6 | UPSTREAM_INFRA×4, NEEDS_INVESTIGATION×1, THRESHOLD_MISFIT×1 | CL-003 ZippyDB/Scribe cascade; 6th fire in 8d; last: A2449443538836650 ~9h ago; owner: igr_retrieval |
| 2026-05-28 22:05 PT | 2 | 2130305043 (ig_reels_tab_cs_omni_retrieval baseline) | 6 | UPSTREAM_INFRA×4, TRANSIENT_NOISE×2 | recurring CL-003/AGG; S667358 persistent root; last: A1002291152283272 ~12h ago; P57 confirmed |
| 2026-05-28 22:05 PT | 3 | 2130324780 (ig_textpost_feed_m2m_retrieval/STUS) | 3 | REAL_OT_FAILURE_RECURRING×1, REAL_OT_FAILURE×1, FULL_SNAPSHOT×1 | DPP+KMEANS corpus recurring; last: A1009946182010606 ~159h ago; S665454 In Progress; owner: ronghuang |
| 2026-05-27 22:05 PDT | 1 | 2130305043 (ig_reels_tab_cs_omni_retrieval baseline) | 4 | AGG+SPARSE_DELTA×4 | recurring CL-003/AGG; tied for top |
| 2026-05-27 22:05 PDT | 2 | 2144816217 (ig_reels_tab_ss_omni_retrieval holdout/STUS) | 4 | client_lag_in_seconds×4 | CL-003 ZippyDB/Scribe cascade; DETECTOR_BROKEN classified by bot |
| 2026-05-27 22:05 PDT | 3 | 2130324780 (ig_textpost_feed_m2m_retrieval/STUS) | 3 | FULL_SNAPSHOT×3 | DPP stuck recurrent; v48 RUNNING ~18.6h 0 FULL_SNAPSHOT as of 21:15 PDT; S665454 status unconfirmed; owner: ronghuang; 886797001 tied at 3 |
| 2026-05-26 22:05 PDT | 1 | 2130324780 (ig_textpost_feed_m2m_retrieval/STUS) | 4 | FULL_SNAPSHOT×3, kmeans-collapse×1 | S665454 In Progress; persistent STUS corpus noise; owner: ronghuang; unchanged from yesterday |
| 2026-05-26 22:05 PDT | 2 | 2130305043 (ig_reels_tab_cs_omni_retrieval baseline) | 4 | AGG+SPARSE_DELTA×4 | recurring CL-003/AGG; tied for top |
| 2026-05-26 22:05 PDT | 3 | 2144816217 (ig_reels_tab_ss_omni_retrieval holdout/STUS) | 4 | client_lag_in_seconds×4 | CL-003 ZippyDB/Scribe cascade; unchanged from yesterday |
| 2026-05-25 22:05 PDT | 1 | 2130324780 (ig_textpost_feed_m2m_retrieval/STUS) | 5 | FULL_SNAPSHOT×3, kmeans-collapse×2 | S665454 In Progress; persistent STUS corpus noise; owner: ronghuang |
| 2026-05-25 22:05 PDT | 2 | 2130305043 (ig_reels_tab_cs_omni_retrieval baseline) | 5 | AGG+SPARSE_DELTA×5 | recurring CL-003/AGG; tied for top |
| 2026-05-25 22:05 PDT | 3 | 2144816217 (ig_reels_tab_ss_omni_retrieval holdout/STUS) | 5 | client_lag_in_seconds×5 | CL-003 ZippyDB/Scribe cascade; 5th fire in 9d; last: A1021144657237695 today |
| 2026-05-24 22:05 PDT | 1 | 2130324780 (ig_textpost_feed_m2m_retrieval/STUS) | 5 | FULL_SNAPSHOT×3, kmeans-collapse×2 | S665454 In Progress; persistent STUS corpus noise; owner: ronghuang |
| 2026-05-24 22:05 PDT | 2 | 878102693 (ig_organic_feed_mtml holdout) | 5 | AGG+SPARSE_DELTA×5 | ZippyDB/Scribe cascade CL-003; multi-SEV; persistent |
| 2026-05-24 22:05 PDT | 3 | 878858380 (facebook_cfr_main_mtml) | 4 | FULL_SNAPSHOT×3, Shampoo-NaN×1 | dropped from 6 (05-23); last: 2026-05-20; may be dropping off |
| 2026-05-23 22:05 PDT | 1 | 878858380 (facebook_cfr_main_mtml) | 6 | FULL_SNAPSHOT×6 | unchanged from 15:10 run; top noisy model |
| 2026-05-23 22:05 PDT | 2 | 2130324780 (ig_textpost_feed_m2m_retrieval/STUS) | 5 | FULL_SNAPSHOT×5 | S665454 In Progress; persistent STUS noise |
| 2026-05-23 22:05 PDT | 3 | 878102693 (ig_organic_feed_mtml holdout) | 5 | AGG+SPARSE_DELTA×5 | ZippyDB cascade; last: A997443402676035 22:05 PDT |
| 2026-05-23 22:05 PDT | note | 2130305043 (ig_reels_tab_cs_omni_retrieval baseline) | 4 | SPARSE_DELTA×4 | rose from 3 (15:10) to 4 (22:05) after today's A26934055329519355 |
| 2026-05-23 15:10 PDT | 1 | 878858380 (facebook_cfr_main_mtml) | 6 | FULL_SNAPSHOT×6 | top noisy model last 7d |
| 2026-05-23 15:10 PDT | 2 | 2130324780 (ig_textpost_feed_m2m_retrieval/STUS) | 5 | FULL_SNAPSHOT×5 | S665454 In Progress; persistent STUS noise |
| 2026-05-23 15:10 PDT | 3 | 878102693 (ig_organic_feed_mtml) | 5 | SPARSE_DELTA×5 | feed LSR holdout; SEVs S663987/S665692/S656066 all closed/mitigated |
| 2026-05-22 22:17 PDT | 1 | 2130324780 (ig_textpost_feed_m2m_retrieval / STUS) | 3 (May 17/19/20-22) | FULL_SNAPSHOT×3 | STUS recurring FS-missing; S665454 In Progress; owner: ronghuang; escalate to suppress/retune alert |

---

## SEVs (top-3 models by SEV count, 7d, floor ≥2)

_Written by `ot-daily-learning-mitigated-sevs` cron._

| Run date | Rank | Model | SEV count (7d) | Top class(es) | Notes |
|---|---|---|---|---|---|
| 2026-05-28 21:00 PT | — | (no chronic-SEV models) | 0 | — | — |
| 2026-05-27 21:00 PDT | — | (no chronic-SEV models) | 0 | — | No model_id appeared in ≥2 distinct resolved-SEV archives in last 7d |
| 2026-05-26 21:00 PDT | — | (no chronic-SEV models) | 0 | — | — |
| 2026-05-19 21:00 PT | — | (no chronic-SEV models) | 0 | — | No model_id appeared in ≥2 resolved-SEV archives in last 7d |

---

## Posts (top chronic post sources, 7d)

_Written by `ot-daily-learning-mitigated-posts` cron._

| Run (PT) | Rank | Grouping | Key | Post count | Breakdown | Notes |
|---|---|---|---|---|---|---|
| 2026-05-31 21:30 PT | (no chronic-post sources) | — | — | — | — | 2 posts in last 7d (W1332867342141342, W1337733828321360); below ≥3 floor; 0 new archives this run (4 check-8 stubs, 3 unresolved) |
| 2026-05-30 21:30 PT | (only 1 category ≥3 posts — no Top-3 this week) | lane | mast_job/mast_job_id | 5 | W1218910203488316 W1321547686606641 W1324864999608243 W1326387856122624 W1332867342141342 | +1 ot_general today (W1337733828321360, ACL provisioning); mast_job dominance unchanged; no model_id chronic sources |
| 2026-05-26 21:30 PT | (only 1 category ≥3 posts — no Top-3 this week) | lane | mast_job_id | 6 | W1326387856122624 W1218910203488316 W1321547686606641 W1324864999608243 W1324845696276840 W1332867342141342 | All MAST job reference posts; no single model_id ≥3; elastic-agent SIGSEGV added today (P58 class) |
| 2026-05-23 14:30 PT | 1 | lane | mast_job_id | 5 | W1326387856122624 W1218910203488316 W1321547686606641 W1324864999608243 W1324729222955154 | Top clusters: CL-001 (snapshot-stuck), CL-013 (example-age), CL-009 (auto-start) |
| 2026-05-23 14:30 PT | (no model_id chronic sources — max 1 post per model in 7d) | | | | | |
| 2026-05-22 21:30 PT | 1 | lane | mast_job | 4 | W1326387856122624 W1218910203488316 W1321547686606641 W1324864999608243 | First run; 4/5 posts are mast_job lane; no prior baseline for Pareto comparison |
| 2026-05-22 21:30 PT | (no chronic model_id sources — max 1 post per model) | | | | | |
