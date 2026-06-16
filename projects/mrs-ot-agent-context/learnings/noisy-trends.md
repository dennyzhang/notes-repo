# Noisy Trends — Chronic-Repeat Signal Tracking

Unified view of chronic-noisy models/sources across all three incident surfaces. Each section is append-only (newest first), maintained by its respective daily-learning cron.

---

## SEVs (top-3 models by SEV count, 7d, floor ≥2)

_Written by `ot-daily-learning-mitigated-sevs` cron._

| Run Timestamp PT | Rank | Model (type) | SEV Count (7d) | Signal Breakdown | Notes |
|---|---|---|---|---|---|
| 2026-06-10 21:00 PT | — | (no chronic-SEV models) | 0 | — | tools/incident-pareto.py not found; chronic-model surfacing unavailable this run |

---

## Alerts (top-3 models by alert count, 7d, floor ≥3)

_Written by `ot-daily-learning-mitigated-alerts` cron._

| Run Timestamp PT | Rank | Model (type) | Alert Count (7d) | Signal Breakdown | Notes |
|---|---|---|---|---|---|
| 2026-06-13 22:05 PT | 1 | 2144816217 (ig_reels_tab_ss_omni_retrieval) | 4 | scribe_read_proxy×3 + CLIPS_AGG×1 (S668542) | persistent upstream; owner: igr_retrieval; 15+ local archives |
| 2026-06-13 22:05 PT | 2 | 2133008573 (ig_reels_tab_mtml) | 3 | CL-003 scribe_read_proxy×3 | recurring; owner: jiaweihuang |
| 2026-06-13 22:05 PT | 3 | 878102693 (ig_organic_feed_mtml) | 3 | UPSTREAM_INFRA/CL-003×3 | active alerts 918757231077640, 1467553315121130 still open |
| 2026-06-12 22:05 PT | 1 | 2144816217 (ig_reels_tab_ss_omni_retrieval) | 4 | scribe_read_proxy×4 (CL-003) | persistent scribe lag; owner: igr_retrieval |
| 2026-06-12 22:05 PT | 2 | 2133008573 (ig_reels_tab_mtml) | 3 | CL-003_scribe_read_proxy×3 | recurring; owner: jiaweihuang |
| 2026-06-12 22:05 PT | 3 | 878102693 (ig_organic_feed_mtml holdout) | 3 | UPSTREAM_INFRA/CL-003×3 | ⚠ signal still degraded (active alerts 918757231077640, 1467553315121130) |
| 2026-06-08 22:05 PT | 1 | 878102693 (ig_organic_feed_mtml holdout) | 5 | UPSTREAM_INFRA×3+NE anomaly×1+pfollow instability×1 | S668542 scribe+S672461 serving feature coverage; last: A1045212924760033 today; owner: wenkai; all 3 top models are S668542-driven |
| 2026-06-08 22:05 PT | 2 | 2144816217 (ig_reels_tab_ss_omni_retrieval) | 3 | CL-003_scribe_read_proxy×3 | S668542 persistent root; last: A1946819640036823 today; owner: igr_retrieval |
| 2026-06-08 22:05 PT | 3 | 2133008573 (ig_reels_tab_mtml baseline) | 3 | CL-003_scribe_read_proxy×3 | S668542; 2nd consecutive day for this model in top-3; last: A983491247848676 today; owner: jiaweihuang |
| 2026-06-04 22:05 PT | — | (no chronic-noisy models) | 0 | — | 1 model at ≥3: 878102693 (ig_organic_feed_mtml) at 3 alerts (A986215410966822 Jun4 + A1306814721539638 Jun2 + A1421314379760011 Jun1); only 1 model ≥3, below top-3 Pareto floor |
| 2026-06-03 22:05 PT | — | (no chronic-noisy models) | 0 | — | max 2 alerts/7d: 878102693 at 2 (A1306814721539638 Jun2 AGG + A1421314379760011 Jun1), 877766818 at 2 (A978986517964596 Jun2 + A902257976006165 Jun3); <3 threshold |
| 2026-06-02 22:05 PT | — | (no chronic-noisy models) | 0 | — | top: 2144816217 at ~5 alerts (per 07:59 run, not re-counted); 878102693 at 2 alerts (A1020303910488347 May 28 + A1421314379760011 Jun 1); <3 models at ≥3 threshold |
| 2026-06-02 07:59 PT | — | (no chronic-noisy models) | 0 | — | top model 2144816217 (ig_reels_tab_ss_omni_retrieval) at 5 alerts in 7d; only 1 model at ≥3 threshold, below top-3 floor |
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
| 2026-06-04 21:00 PDT | — | (no chronic-SEV models) | 0 | — | 2 models found (2143912626 ×1, 2126653325 ×1); none ≥2 threshold |
| 2026-06-02 21:00 PDT | — | (no chronic-SEV models) | 0 | — | All 6 models ≤1 SEV in last 7d |
| 2026-05-28 21:00 PT | — | (no chronic-SEV models) | 0 | — | — |
| 2026-05-27 21:00 PDT | — | (no chronic-SEV models) | 0 | — | No model_id appeared in ≥2 distinct resolved-SEV archives in last 7d |
| 2026-05-26 21:00 PDT | — | (no chronic-SEV models) | 0 | — | — |
| 2026-05-19 21:00 PT | — | (no chronic-SEV models) | 0 | — | No model_id appeared in ≥2 resolved-SEV archives in last 7d |

---

## Posts (top chronic post sources, 7d)

_Written by `ot-daily-learning-mitigated-posts` cron._

| Run (PT) | Rank | Grouping | Key | Post count | Breakdown | Notes |
|---|---|---|---|---|---|---|
| 2026-06-13 21:30 PDT | — | — | — | — | — | (no chronic-post sources this week) — 2 new archives today (W1350388963722513 mast_job_id/check-7, W1344542434307166 sev_id/check-8); pareto tool not found; manual count: <3 per model/lane in 7d window |
| 2026-06-11 21:30 PDT | 1 | lane | ot_general | 5 | W1348853410542735 W1347152497379493 W1347227230705353 W1342215704539839 W1341029697991773 | top authors: Denny Zhang×2, Yubo Wang×1, Hanzhao Wang×1, Rong Huang×1; P61×2 (zombie), P63×1 (CPU OOM/py upgrade), P04+P07+P19×1; no model ≥3 |
| 2026-06-10 21:30 PDT | 1 | lane | ot_general | 3 | W1342971631130913 W1346326357462107 W1336148551813221 | top authors: xiaozang, Jamey Zhang, Sanket Karnik (1× each); no model_id ≥3 |
| 2026-06-08 21:30 PDT | — | — | — | — | — | (no chronic-post sources) |
| 2026-06-04 21:30 PT | (no chronic-post sources) | — | — | — | — | 6 archives in 7d window (1 new: W1336148551813221 HOWTO/ot_general); 2 stub-guard skips; max 2 per lane (ot_general); ≥3 floor not met per model/lane |
| 2026-06-03 21:30 PT | (no chronic-post sources) | — | — | — | — | 4 archives in 7d window (2 new: W1332046782223398 CL-012, W1336024098492333 CL-013); 3 stub-guard skips; ≥3 floor not met per model/lane |
| 2026-06-02 21:30 PT | (no chronic-post sources) | — | — | — | — | 2 heuristic stubs (W1332046782223398, W1331638558930887, check-8 aged-7d) — stub-content guard; 0 archives; 1 archive in 7d window (W1337733828321360 May 29); ≥3 floor not met |
| 2026-06-02 07:59 PT | (no chronic-post sources) | — | — | — | — | 1 archive in 7d window (W1337733828321360 May 29); 4 check-8 stubs this run (all stub guard, 0 archives); ≥3 floor not met |
| 2026-05-31 21:30 PT | (no chronic-post sources) | — | — | — | — | 2 posts in last 7d (W1332867342141342, W1337733828321360); below ≥3 floor; 0 new archives this run (4 check-8 stubs, 3 unresolved) |
| 2026-05-30 21:30 PT | (only 1 category ≥3 posts — no Top-3 this week) | lane | mast_job/mast_job_id | 5 | W1218910203488316 W1321547686606641 W1324864999608243 W1326387856122624 W1332867342141342 | +1 ot_general today (W1337733828321360, ACL provisioning); mast_job dominance unchanged; no model_id chronic sources |
| 2026-05-26 21:30 PT | (only 1 category ≥3 posts — no Top-3 this week) | lane | mast_job_id | 6 | W1326387856122624 W1218910203488316 W1321547686606641 W1324864999608243 W1324845696276840 W1332867342141342 | All MAST job reference posts; no single model_id ≥3; elastic-agent SIGSEGV added today (P58 class) |
| 2026-05-23 14:30 PT | 1 | lane | mast_job_id | 5 | W1326387856122624 W1218910203488316 W1321547686606641 W1324864999608243 W1324729222955154 | Top clusters: CL-001 (snapshot-stuck), CL-013 (example-age), CL-009 (auto-start) |
| 2026-05-23 14:30 PT | (no model_id chronic sources — max 1 post per model in 7d) | | | | | |
| 2026-05-22 21:30 PT | 1 | lane | mast_job | 4 | W1326387856122624 W1218910203488316 W1321547686606641 W1324864999608243 | First run; 4/5 posts are mast_job lane; no prior baseline for Pareto comparison |
| 2026-05-22 21:30 PT | (no chronic model_id sources — max 1 post per model) | | | | | |

## Alerts
| Run timestamp | Rank | Model | Alert count | Signal class breakdown | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-06-11 22:05 PDT | 1 | 2144816217 (ig_reels_tab_ss_omni_retrieval) | 4 | UPSTREAM_INFRA×4 (scribe_read_proxy/CL-003) | owner: shuyaoli; 14 local archives; P57 match |
| 2026-06-11 22:05 PDT | 2 | 878102693 (ig_organic_feed_mtml) | 4 | MISCONFIG_AGG×4 (t4/eval quality) | owner: wenkai; 22+ local archives; task T275458692 |
| 2026-06-11 22:05 PDT | 3 | 2133008573 (ig_reels_tab_mtml) | 3 | UPSTREAM_INFRA×3 (scribe_read_proxy/CL-003) | owner: jiaweihuang; prior archives exist |
