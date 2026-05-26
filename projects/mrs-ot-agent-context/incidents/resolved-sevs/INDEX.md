# Mitigated SEVs

Per-incident SEV archives written by `ot-daily-learning-mitigated-sevs` cron (daily ~21:30 PT).

## Convention

- **Path:** `<YYYY-MM>/<level>-<date>-S<id>.md` (level = `L0..L4`)
- **Trigger:** SEV moves to `Mitigated` status AND was previously triaged by bot
- **Retention:** none — `sl` history preserves all
- **Cross-refs:** `../../auto-learnings/patterns/failure-patterns.md` (CL-NNN), `../../auto-learnings/noisy-trends.md § SEVs`, `../../auto-learnings/deep-dives/ot-sev-scope-rejections.md` (scope-rejection fixture)
- **Sibling archives:** `../resolved-posts/`, `../resolved-alerts/`, `../fbpkg-audits/`
- **Regenerate this table:** `bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/regen-archive-indexes.sh`

<!-- AUTO-GENERATED TABLE BELOW — do not edit below this line -->

**Total:** 62 · **Mapped:** 29 · **Unmapped:** 33

| Date | Level | SEV | Error pattern | Title |
|---|---|---|---|---|
| 2026-05-19 | L4 | [S666007](2026-05/L4-2026-05-19-S666007.md) | CL-004 | [mvai/light_cli] fbpkg version cap exhausted — RESOLVED 2026-05-19 13:18 PT |
| 2026-05-19 | L4 | [S665607](2026-05/L4-2026-05-19-S665607.md) | (unmapped) | [silvertorch/ifr_prospector] online_train DPP PERMISSION_DENIED on feed_recommen |
| 2026-05-19 | L4 | [S651873](2026-05/L4-2026-05-19-S651873.md) | (unmapped) | [mvai/mvai_ifr_main] online_train_publish fails TGIF publish hung R9149.1 |
| 2026-05-18 | L4 | [S665707](2026-05/L4-2026-05-18-S665707.md) | CL-004 | mvai/light_cli fbpkg build OOM 11h — RESOLVED 2026-05-18 20:28 PT |
| 2026-05-18 | L3 | [S665323](2026-05/L3-2026-05-18-S665323.md) | (unmapped) | IG LSR MB10 prod snapshots stale 68h — RESOLVED 2026-05-18 14:59 PT |
| 2026-05-17 | L4 | [S665222](2026-05/L4-2026-05-17-S665222.md) | CL-004 | U2A TIFU Retrieval publish failure — RESOLVED 2026-05-17 19:04 PT |
| 2026-05-16 | L4 | [S665135](2026-05/L4-2026-05-16-S665135.md) | CL-017 | QE Model - TIFU ESR PNUA Model Train + Publish failure (root:2132407738,st:21324 |
| 2026-05-15 | L4 | [S664494](2026-05/L4-2026-05-15-S664494.md) | (unmapped) | [mvai/umia_v1_igr] IGR Tab T2I publish blocked by PyTorch unique_consecutive JIT |
| 2026-05-15 | L3 | [S664296](2026-05/L3-2026-05-15-S664296.md) | (unmapped) | [Threads][Permalink] DPP oscillation |
| 2026-05-15 | L3 | [S661936](2026-05/L3-2026-05-15-S661936.md) | CL-004 | [mvai/mvai_ig_ranking] cogwheel_ig_ranking_lsr_test publish SIGKILL — timeout er |
| 2026-05-14 | L4 | [S664365](2026-05/L4-2026-05-14-S664365.md) | CL-004 | [mvai/light_cli] fbpkg Build Node failure — trunk build break in fbcode//common/ |
| 2026-05-14 | L3 | [S664106](2026-05/L3-2026-05-14-S664106.md) | CL-009 | Threads Feed teacher model 2128461099 online training cannot get started |
| 2026-05-13 | L4 | [S659604](2026-05/L4-2026-05-13-S659604.md) | CL-010 | Organic downstream model mvai migration launch |
| 2026-05-13 | L3 | [S659243](2026-05/L3-2026-05-13-S659243.md) | CL-003 | IG / FB TIXU calibration instability due to S659167 |
| 2026-05-12 | L4 | [S663211](2026-05/L4-2026-05-12-S663211.md) | (unmapped) | [mvai/umia_v1_igr] IGR Tab Omni online training fails on checkpoint save |
| 2026-05-12 | L4 | [S662705](2026-05/L4-2026-05-12-S662705.md) | CL-001 | IG HI Snapshot Transition Stuck |
| 2026-05-12 | L3 | [S663027](2026-05/L3-2026-05-12-S663027.md) | (unmapped) | Root model 2126294150 (SilverTorch model 2126294138) (ig_feedrec_esr_ttsn launch |
| 2026-05-12 | L3 | [S662719](2026-05/L3-2026-05-12-S662719.md) | (unmapped) | Online training job for vm mtml model 2128024482 stopped  |
| 2026-05-12 | L3 | [S654235](2026-05/L3-2026-05-12-S654235.md) | (unmapped) | [MB8] OldTrunk Combo OT Issue + Publish Err |
| 2026-05-12 | L3 | [S652049](2026-05/L3-2026-05-12-S652049.md) | CL-001 | Sequantial teacher model online training cannot restart (2nd occurance) |
| 2026-05-12 | L3 | [S650816](2026-05/L3-2026-05-12-S650816.md) | (unmapped) | Model 2131550324 (ig_explore_posts_mtml baseline) inference error rate |
| 2026-05-12 | L3 | [S635390](2026-05/L3-2026-05-12-S635390.md) | CL-013 / CL-003 | Threads U2M OP Example Age Spike due to EDPP resize blocked |
| 2026-05-12 | L3 | [S628346](2026-05/L3-2026-05-12-S628346.md) | (unmapped) | MB7 models OT sporadic stuck (2136101745, 2136148608, 2134319249, 2134319967) |
| 2026-05-11 | L4 | [S661987](2026-05/L4-2026-05-11-S661987.md) | CL-004 | light_cli fbpkg at 800/800 version cap (recurrence of S657811) |
| 2026-05-11 | L4 | [S661983](2026-05/L4-2026-05-11-S661983.md) | CL-004 | light_cli conveyor blocked (TorchScript compile error) |
| 2026-05-05 | L4 | [S659474](2026-05/L4-2026-05-05-S659474.md) | CL-013 | threads feed m2m model reranker online training job (mvai-training-online-213032 |
| 2026-05-01 | L4 | [S657920](2026-05/L4-2026-05-01-S657920.md) | CL-006 | mvai-training-online-2126520686 pending despite crit priority and enough machine |
| 2026-05-01 | L3 | [S658035](2026-05/L3-2026-05-01-S658035.md) | CL-006 | IG Feed ESR prod OT models are pending without entitlement over-quota |
| 2026-05-01 | L3 | [S657977](2026-05/L3-2026-05-01-S657977.md) | CL-006 | Prod T2I OT Job Stuck in Pending State3 |
| 2026-04-25 | L4 | [S641880](2026-04/L4-2026-04-25-S641880.md) | (unmapped) | Terminate MAST OT jobs with resource access violations |
| 2026-04-23 | L3 | [S604433](2026-04/L3-2026-04-23-S604433.md) | CL-010 | [Preemptive] IFR LSR MainMTML MC11 |
| 2026-04-21 | L3 | [S652481](2026-04/L3-2026-04-21-S652481.md) | (unmapped) | Model 2143272283 (threads_feed_mtml experimental/non-prod) inference error rate  |
| 2026-04-15 | L3 | [S649277](2026-04/L3-2026-04-15-S649277.md) | CL-013 | Threads Retrieval Models Online Training Example Age Capped |
| 2026-04-15 | L3 | [S647391](2026-04/L3-2026-04-15-S647391.md) | CL-004 | fire-app-fbr-preranker, fbr_hstu, cfr_main_feed_mtml_roo_hstu cogwheel blocked — |
| 2026-04-14 | L3 | [S647178](2026-04/L3-2026-04-14-S647178.md) | CL-009 | [u2i] multiple online-training-job fail to auto-restart |
| 2026-04-09 | L3 | [S647168](2026-04/L3-2026-04-09-S647168.md) | (unmapped) | Stories Secondary MTML model 877553271 NE spike |
| 2026-04-03 | L3 | [S644248](2026-04/L3-2026-04-03-S644248.md) | CL-015 | IG reels retreival Omni Root model online training QPS frequently drops to 0 sin |
| 2026-03-30 | L3 | [S640642](2026-03/L3-2026-03-30-S640642.md) | (unmapped) | QE VM MTML Model 2132390988 Error Rate Increased |
| 2026-03-27 | L4 | [S640231](2026-03/L4-2026-03-27-S640231.md) | (unmapped) | [mvai][online-training-mgr] adhoc jobs with different customer failing when regi |
| 2026-03-27 | L3 | [S640633](2026-03/L3-2026-03-27-S640633.md) | (unmapped) | Infra error too high due to VM MTML CPU model throttling in eag |
| 2026-03-26 | L1 | [S639956](2026-03/L1-2026-03-26-S639956.md) | CL-013 | Threads Online Training Data Breakage |
| 2026-03-25 | L3 | [S639824](2026-03/L3-2026-03-25-S639824.md) | (unmapped) | · Model 923448586 (ig_explore_chaining_mtml baseline) inference error rate |
| 2026-03-24 | L3 | [S639187](2026-03/L3-2026-03-24-S639187.md) | CL-013 | Threads Feed ESR prod OT model 2134165587 increased training example age |
| 2026-03-18 | L3 | [S635931](2026-03/L3-2026-03-18-S635931.md) | (unmapped) | ig_reels_tab_hstu_retrieval production OT job 2139735525 has been dead for 7 day |
| 2026-03-17 | L3 | [S635335](2026-03/L3-2026-03-17-S635335.md) | (unmapped) | Model 2138521890 (threads_feed_mtml) Calibration Out Of Range |
| 2026-03-16 | L3 | [S635172](2026-03/L3-2026-03-16-S635172.md) | (unmapped) | IFR LSR Main MTML model stale |
| 2026-03-14 | L4 | [S622275](2026-03/L4-2026-03-14-S622275.md) | (unmapped) | [mvai/video_ifu_lsr] online_train_publish + serving_eval metric regressions |
| 2026-03-14 | L3 | [S634407](2026-03/L3-2026-03-14-S634407.md) | (unmapped) | Model 2138521890 (threads_feed_mtml) not publishing |
| 2026-03-12 | L4 | [S631731](2026-03/L4-2026-03-12-S631731.md) | (unmapped) | IFR MainMTML `StuckJobException` Failures in MC11.4 |
| 2026-03-06 | L4 | [S619335](2026-03/L4-2026-03-06-S619335.md) | CL-004 | [mvai/minimal_viable_ai] cogwheel fblearner fbpkg job validation failure |
| 2026-03-04 | L3 | [S627389](2026-03/L3-2026-03-04-S627389.md) | CL-004 | [mvai/mvai_ig_ranking] R6993.2 cogwheel_ig_ranking_esr_test Model requires a low |
| 2026-03-03 | L3 | [S629210](2026-03/L3-2026-03-03-S629210.md) | (unmapped) | Online Training Impacted by S628942 |
| 2026-02-27 | L3 | [S627484](2026-02/L3-2026-02-27-S627484.md) | (unmapped) | [mvai/video_udd_lsr] online_train_publish step fails w/ StuckJobException |
| 2026-02-23 | L4 | [S625743](2026-02/L4-2026-02-23-S625743.md) | (unmapped) | [mvai/minimal_viable_ai] blocked: Contbuild Tracking Node |
| 2026-02-20 | L3 | [S622829](2026-02/L3-2026-02-20-S622829.md) | (unmapped) | [Silvertorch][MVAI] Jobs not shutting down correctly due to py-spy hanging |
| 2026-02-19 | L3 | [S624367](2026-02/L3-2026-02-19-S624367.md) | (unmapped) | [mvai/video_udd_lsr] Serving eval failed with response_generator exit -11. |
| 2026-02-16 | L3 | [S618129](2026-02/L3-2026-02-16-S618129.md) | CL-014 | [mvai/video_ifu_lsr] online_train_publish failing due to NCCL timeout |
| 2026-02-13 | L4 | [S621833](2026-02/L4-2026-02-13-S621833.md) | (unmapped) | [silvertroch/ifr_prospector] online_train_publish_delta_only w/ StuckJobExceptio |
| 2026-02-10 | L3 | [S620416](2026-02/L3-2026-02-10-S620416.md) | CL-017 | Online training hosts removed from IFR_TC_PROD tenant causes Tier 1 model traini |
| 2026-02-09 | L3 | [S620281](2026-02/L3-2026-02-09-S620281.md) | (unmapped) | Multifeed high SR fatal rate due to spiked cpu usage of VM MTML legacy model 899 |
| 2026-01-30 | L3 | [S607776](2026-01/L3-2026-01-30-S607776.md) | (unmapped) | IG Stories Model 875799562 (ig_stories_tray_mtml baseline) Impacted recommendati |
| 2026-01-29 | L4 | [S615796](2026-01/L4-2026-01-29-S615796.md) | (unmapped) | mvai/minimal_viable_ai conveyor python 3.12 forced upgrade |
