# Mitigated Alerts

OT alert postmortems written by `ot-daily-learning-mitigated-alerts` cron (daily ~22:05 PT). One file per alert that mitigated in the last 24h and was triaged by the bot.

## Convention

- **Path:** `<YYYY-MM>/<priority>-<YYYY-MM-DD>-A<short_id>.md`
- **Priority prefix:** `critical` / `high` / `medium` / `low` / `unknown` (OneDetection urgency values, lowercase)
- **One file per alert_id** (UPSERT discipline)
- **Retention:** none — `sl` history preserves everything
- **Cross-refs:** `../../auto-learnings/patterns/failure-patterns.md` (CL-NNN), `../../auto-learnings/noisy-trends.md § Alerts`
- **Regenerate this table:** `bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/regen-archive-indexes.sh`

<!-- AUTO-GENERATED TABLE BELOW — do not edit below this line -->

**Total:** 25 · **Mapped:** 19

| Date | Pri | Alert | Error pattern | Title |
|---|---|---|---|---|
| 2026-05-25 | high | [A1021144657237695](2026-05/high-2026-05-25-A1021144657237695.md) | CL-003 | A1021144657237695 — [AGG] Model 2144816217 (ig_reels_tab_ss_omni_retrieval) multiple alert |
| 2026-05-24 | high | [A1553698676550071](2026-05/high-2026-05-24-A1553698676550071.md) | CL-AGG | A1553698676550071 — [AGG] Model 2144816217 (ig_reels_tab_ss_omni_retrieval) multiple alert |
| 2026-05-23 | high | [A26934055329519355](2026-05/high-2026-05-23-A26934055329519355.md) | CL-013 | A26934055329519355 — Model 2130305043 (ig_reels_tab_cs_omni_retrieval baseline) online tra |
| 2026-05-23 | high | [A2218864415613563](2026-05/high-2026-05-23-A2218864415613563.md) | CL-AGG | A2218864415613563 — [AGG] Model 2144816217 (ig_reels_tab_ss_omni_retrieval) multiple alert |
| 2026-05-23 | high | [A1670185680650606](2026-05/high-2026-05-23-A1670185680650606.md) | CL-013 | A1670185680650606 — [IFR Watchtower] model 886797001 (IFR MC8 MTML) training example age > |
| 2026-05-23 | high | [A1386657526635645](2026-05/high-2026-05-23-A1386657526635645.md) | CL-001 | A1386657526635645 — Publishing Stability: facebook_ifr_main_mtml_main model 2125752019 mis |
| 2026-05-22 | high | [A1690612485438486](2026-05/high-2026-05-22-A1690612485438486.md) | (unmapped) | A1690612485438486 — [IFR Watchtower] online training monitor: model 'IFR MC8 MTML' (model: |
| 2026-05-22 | high | [A1427819186056622](2026-05/high-2026-05-22-A1427819186056622.md) | (unmapped) | A1427819186056622 — [Invalid Detector - No Data] Model 2145491885 (ig_reels_starsearch_t2i |
| 2026-05-22 | critical | [A1009946182010606](2026-05/critical-2026-05-22-A1009946182010606.md) | CL-001 | A1009946182010606 — Publishing Stability: ig_textpost_feed_m2m_retrieval model 2130324780  |
| 2026-05-19 | low | [A2149157265940350](2026-05/low-2026-05-19-A2149157265940350.md) | CL-AGG | A2149157265940350 — [AGG] Model 878102693 (ig_organic_feed_mtml) multiple alerts aggregati |
| 2026-05-17 | low | [A977255094865118](2026-05/low-2026-05-17-A977255094865118.md) | CL-013 | A977255094865118 — Model 2134319967 (ig_organic_feed_mtml baseline) online training e2e la |
| 2026-05-17 | low | [A25209897055308328](2026-05/low-2026-05-17-A25209897055308328.md) | CL-017 | A25209897055308328 — [PROD][CFR] MainPredictor baseline Online Training Tier-1 Train (8788 |
| 2026-05-17 | low | [A1703030847735006](2026-05/low-2026-05-17-A1703030847735006.md) | CL-017 | A1703030847735006 — [PROD][CFR] MainPredictor baseline Online Training Tier-1 Train (21348 |
| 2026-05-17 | high | [A799966216470487](2026-05/high-2026-05-17-A799966216470487.md) | (unmapped) | A799966216470487 — [IFR Watchtower] online training monitor: model 'IFR MC8 MTML' (model:  |
| 2026-05-17 | high | [A2387001468469120](2026-05/high-2026-05-17-A2387001468469120.md) | CL-013 | A2387001468469120 — Model 878102693 (ig_organic_feed_mtml holdout) online training e2e lat |
| 2026-05-17 | high | [A1201406268614142](2026-05/high-2026-05-17-A1201406268614142.md) | CL-013 | A1201406268614142 — [Invalid Detector - No Data] Model 2126189932 (ig_reels_starsearch_t2i |
| 2026-05-16 | low | [A708481502288258](2026-05/low-2026-05-16-A708481502288258.md) | (unmapped) | A708481502288258 — fb_reels_ifu_mtml_v0 delta staleness |
| 2026-05-16 | low | [A2382297228909438](2026-05/low-2026-05-16-A2382297228909438.md) | (unmapped) | A2382297228909438 — fb_reels_ifu_mtml_v0 delta staleness (holdout) |
| 2026-05-16 | low | [A1336064448378593](2026-05/low-2026-05-16-A1336064448378593.md) | (unmapped) | A1336064448378593 — ig_organic_feed_mtml AGG transient |
| 2026-05-16 | high | [A898952803114953](2026-05/high-2026-05-16-A898952803114953.md) | CL-001 | A898952803114953 — Publishing Stability: facebook_cfr_main_mtml [holdout] model 878858380  |
| 2026-05-16 | high | [A4366891846955592](2026-05/high-2026-05-16-A4366891846955592.md) | CL-001 | A4366891846955592 — Publishing Stability: facebook_cfr_main_mtml model 878858380 missing s |
| 2026-05-16 | high | [A2130305043](2026-05/high-2026-05-16-A2130305043.md) | CL-AGG | A2130305043 — [AGG] Model 2130305043 (ig_reels_tab_cs_omni_retrieval) multiple alerts aggr |
| 2026-05-16 | high | [A1955974545038771](2026-05/high-2026-05-16-A1955974545038771.md) | CL-001 | A1955974545038771 — Publishing Stability: facebook_reels_ifu_i2i model 2132070936 missing  |
| 2026-05-16 | high | [A1480195820275950](2026-05/high-2026-05-16-A1480195820275950.md) | CL-013 | A1480195820275950 — Model 2144816217 (ig_reels_tab_ss_omni_retrieval holdout) online train |
| 2026-05-15 | high | [A2126294138](2026-05/high-2026-05-15-A2126294138.md) | CL-AGG | A2126294138 — [AGG] Model 2126294138 (ig_feedrec_esr_ttsn) multiple alerts aggregation - 4 |
