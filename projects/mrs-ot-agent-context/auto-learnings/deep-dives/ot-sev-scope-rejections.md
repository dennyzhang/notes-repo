# OT SEV Scope Rejections — out-of-scope SEVs (NOT archived, by design)

_Rewritten 2026-05-17 thread `6i0LDKZxIR8` after operator: "these are not OT SEVs, let's debug what's off" — refined classification rule (was admitting too many sev_type=Instagram SEVs that have no 'online' keyword in title)._

_Extended 2026-05-17 thread `7wZB1nUQH8Y` to cover April + March backfill (33 new archived, 67 new rejected per same refined rule)._

## OT-SEV identification rule (canonical)

Per operator (2026-05-17 thread `6i0LDKZxIR8`):


> _If the SEV has `mrs_ml_release_oncall` tag, this is highly unlikely to be OT SEV, unless the SEV page has "online" keywords._


**Generalized rule** (validated 36/36 against operator-flagged false-positives):


A SEV is OT-scope if and only if its title contains:

- `online train` / `online training` / `online_train` / `online_training`

- `mvai-training-online-<id>` (explicit MAST job prefix)

- `OT job` / `OT jobs` / `OT model` / `OT models` / `OT training`

- `teacher model … online`


**EXCEPT** when the title is cogwheel-prefixed (`cogwheel_*` / `cogwheel failure` / `[mvai/light_cli]` build/test / `Tag fbpkgs` / `silvertorch_test`) — those are release-pipeline tests, NOT OT, even if they happen to mention `online_train_publish`.


Anything else is NOT OT — serving SEVs, publish-flow SEVs, snapshot-deployment SEVs, inference-error SEVs, IPNext/queue SEVs, cogwheel/release-pipeline SEVs all live under MVAI or sibling-team scope.

## What changed in archive set

**Before (2026-05-17 14:30 PT, first backfill pass):** 46 archives written from `scope_check` output. Operator flagged 36 as not-OT. Investigation showed `scope_check`'s step 7 (`sev_type=Instagram admitted by default`) was too permissive — admits any Instagram SEV without requiring 'online' keyword.

**After May refinement pass (2026-05-17 ~17:00 PT):** **10 May archives** retained (true OT SEVs with 'online'/'OT job'/'mvai-training-online-' in title). 36 false-positive archives moved to `/tmp/sev-archive-trash/` for safety. **57 May out-of-scope SEVs** listed below with rejection rationale.

**After April+March backfill (2026-05-17 ~21:00 PT, thread `7wZB1nUQH8Y`):** **33 additional archives** retained (April: 14, March: 19) using the same refined rule. **67 additional out-of-scope SEVs** (April: 20, March: 47) added below the May rejection table. Running total: 67 archives kept, 124 rejected and tracked as regression fixture.

## True OT SEVs archived (10)

| SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|
| [S663211](https://www.internalfb.com/sevmanager/view/663211) | L4 | Mitigated | Production | [mvai/umia_v1_igr] IGR Tab Omni online training fails on checkpoint save |
| [S663027](https://www.internalfb.com/sevmanager/view/663027) | L3 | Mitigated | Instagram | Root model 2126294150 (SilverTorch model 2126294138) (ig_feedrec_esr_ttsn launch candidate) online training QPS |
| [S664296](https://www.internalfb.com/sevmanager/view/664296) | L3 | Mitigated | Instagram | [Threads][Permalink] online training has DPP oscillation |
| [S662719](https://www.internalfb.com/sevmanager/view/662719) | L3 | Mitigated | Instagram | Online training job for vm mtml model 2128024482 stopped  |
| [S658149](https://www.internalfb.com/sevmanager/view/658149) | L3 | Mitigated | AI Infra | [mast][online training] Jobs pre-empted even while under quota. |
| [S658035](https://www.internalfb.com/sevmanager/view/658035) | L3 | Closed | Instagram | IG Feed ESR prod OT models are pending without entitlement over-quota |
| [S657977](https://www.internalfb.com/sevmanager/view/657977) | L3 | Closed | Instagram | Prod T2I OT Job Stuck in Pending State3 |
| [S664106](https://www.internalfb.com/sevmanager/view/664106) | L3 | Mitigated | Instagram | Threads Feed teacher model 2128461099 online training cannot get started |
| [S657920](https://www.internalfb.com/sevmanager/view/657920) | L4 | Closed | Production | mvai-training-online-2126520686 pending despite crit priority and enough machines |
| [S659474](https://www.internalfb.com/sevmanager/view/659474) | L4 | Mitigated | Instagram | threads feed m2m model reranker online training job (mvai-training-online-2130324829) - training example age spike |

## April + March backfill — True OT SEVs archived (33)

_Backfilled 2026-05-17 thread `7wZB1nUQH8Y` per operator: "for mitigated SEVs, we have May data. we should also backfill for April and March, right?" Same OT-SEV identification rule as the May pass. April pulled 34 candidates → 14 kept. March pulled 66 candidates → 19 kept._

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| 2026-04-25 | [S641880](https://www.internalfb.com/sevmanager/view/641880) | L4 | Closed | Production | Terminate MAST OT jobs with resource access violations |
| 2026-04-23 | [S604433](https://www.internalfb.com/sevmanager/view/604433) | L3 | Closed | Production | [Preemptive] IFR LSR MainMTML MC11 |
| 2026-04-21 | [S652481](https://www.internalfb.com/sevmanager/view/652481) | L3 | Closed | Instagram | Model 2143272283 (threads_feed_mtml experimental/non-prod) inference error rate due to a bad task |
| 2026-04-15 | [S649277](https://www.internalfb.com/sevmanager/view/649277) | L3 | Closed | Instagram | Threads Retrieval Models Online Training Example Age Capped |
| 2026-04-15 | [S647391](https://www.internalfb.com/sevmanager/view/647391) | L3 | Closed | Production | fire-app-fbr-preranker, fbr_hstu, cfr_main_feed_mtml_roo_hstu cogwheel blocked — TMS ONLINE_READY rejects test jobs (cro |
| 2026-04-14 | [S647178](https://www.internalfb.com/sevmanager/view/647178) | L3 | Closed | Production | [u2i] multiple online-training-job fail to auto-restart |
| 2026-04-09 | [S647168](https://www.internalfb.com/sevmanager/view/647168) | L3 | Closed | Production | Stories Secondary MTML model 877553271 NE spike |
| 2026-04-03 | [S644248](https://www.internalfb.com/sevmanager/view/644248) | L3 | Closed | Instagram | IG reels retreival Omni Root model online training QPS frequently drops to 0 since 9:45 pm PDT, April 2 |
| 2026-03-30 | [S640642](https://www.internalfb.com/sevmanager/view/640642) | L3 | Closed | Production | QE VM MTML Model 2132390988 Error Rate Increased |
| 2026-03-27 | [S640633](https://www.internalfb.com/sevmanager/view/640633) | L3 | Closed | Instagram | Infra error too high due to VM MTML CPU model throttling in eag |
| 2026-03-27 | [S640231](https://www.internalfb.com/sevmanager/view/640231) | L4 | Closed | Production | [mvai][online-training-mgr] adhoc jobs with different customer failing when registering prod |
| 2026-03-26 | [S639956](https://www.internalfb.com/sevmanager/view/639956) | L1 | Closed | Instagram | Threads Online Training Data Breakage |
| 2026-03-25 | [S639824](https://www.internalfb.com/sevmanager/view/639824) | L3 | Closed | Production | · Model 923448586 (ig_explore_chaining_mtml baseline) inference error rate |
| 2026-03-24 | [S639187](https://www.internalfb.com/sevmanager/view/639187) | L3 | Closed | Instagram | Threads Feed ESR prod OT model 2134165587 increased training example age |
| 2026-03-18 | [S635931](https://www.internalfb.com/sevmanager/view/635931) | L3 | Closed | Instagram | ig_reels_tab_hstu_retrieval production OT job 2139735525 has been dead for 7 days |
| 2026-03-17 | [S635335](https://www.internalfb.com/sevmanager/view/635335) | L3 | Closed | Production | Model 2138521890 (threads_feed_mtml) Calibration Out Of Range |
| 2026-03-16 | [S635172](https://www.internalfb.com/sevmanager/view/635172) | L3 | Closed | Production | IFR LSR Main MTML model stale |
| 2026-03-14 | [S634407](https://www.internalfb.com/sevmanager/view/634407) | L3 | Closed | Production | Model 2138521890 (threads_feed_mtml) not publishing |
| 2026-03-14 | [S622275](https://www.internalfb.com/sevmanager/view/622275) | L4 | Closed | Production | [mvai/video_ifu_lsr] online_train_publish + serving_eval metric regressions |
| 2026-03-12 | [S631731](https://www.internalfb.com/sevmanager/view/631731) | L4 | Closed | Production | IFR MainMTML `StuckJobException` Failures in MC11.4 |
| 2026-03-06 | [S619335](https://www.internalfb.com/sevmanager/view/619335) | L4 | Closed | Production | [mvai/minimal_viable_ai] cogwheel fblearner fbpkg job validation failure |
| 2026-03-04 | [S627389](https://www.internalfb.com/sevmanager/view/627389) | L3 | Closed | Production | [mvai/mvai_ig_ranking] R6993.2 cogwheel_ig_ranking_esr_test Model requires a lowered snapshot (AOTI) but it wasn't found |
| 2026-03-03 | [S629210](https://www.internalfb.com/sevmanager/view/629210) | L3 | Closed | Production | Online Training Impacted by S628942 |
| 2026-02-27 | [S627484](https://www.internalfb.com/sevmanager/view/627484) | L3 | Closed | Production | [mvai/video_udd_lsr] online_train_publish step fails w/ StuckJobException |
| 2026-02-23 | [S625743](https://www.internalfb.com/sevmanager/view/625743) | L4 | Closed | Production | [mvai/minimal_viable_ai] blocked: Contbuild Tracking Node |
| 2026-02-20 | [S622829](https://www.internalfb.com/sevmanager/view/622829) | L3 | Closed | Production | [Silvertorch][MVAI] Jobs not shutting down correctly due to py-spy hanging |
| 2026-02-19 | [S624367](https://www.internalfb.com/sevmanager/view/624367) | L3 | Closed | Production | [mvai/video_udd_lsr] Serving eval failed with response_generator exit -11. |
| 2026-02-16 | [S618129](https://www.internalfb.com/sevmanager/view/618129) | L3 | Closed | Production | [mvai/video_ifu_lsr] online_train_publish failing due to NCCL timeout |
| 2026-02-13 | [S621833](https://www.internalfb.com/sevmanager/view/621833) | L4 | Closed | Production | [silvertroch/ifr_prospector] online_train_publish_delta_only w/ StuckJobException |
| 2026-02-10 | [S620416](https://www.internalfb.com/sevmanager/view/620416) | L3 | Closed | Production | Online training hosts removed from IFR_TC_PROD tenant causes Tier 1 model training / publish outage |
| 2026-02-09 | [S620281](https://www.internalfb.com/sevmanager/view/620281) | L3 | Closed | Instagram | Multifeed high SR fatal rate due to spiked cpu usage of VM MTML legacy model 899940323 |
| 2026-01-30 | [S607776](https://www.internalfb.com/sevmanager/view/607776) | L3 | Closed | Instagram | IG Stories Model 875799562 (ig_stories_tray_mtml baseline) Impacted recommendation metrics and training NEs |
| 2026-01-29 | [S615796](https://www.internalfb.com/sevmanager/view/615796) | L4 | Closed | Production | mvai/minimal_viable_ai conveyor python 3.12 forced upgrade |


## Out-of-scope SEVs (57, excluded by design)

Grouped by rejection reason:

### sev_type=Ads, no 'online' keyword in title (1)

| SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|
| [S662589](https://www.internalfb.com/sevmanager/view/662589) | L2 | Mitigated | Ads | Ads IPNext Solver failed globally due to traffic demand query failure caused by the inefficient ODS query |

### sev_type=Instagram but title has no 'online'/'OT job'/'OT model'/mvai-training-online keyword (serving/publishing SEV, not OT) (25)

| SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|
| [S658034](https://www.internalfb.com/sevmanager/view/658034) | L4 | Mitigated | Instagram | [mast][tetris] Debug GTR inconsistent response |
| [S658369](https://www.internalfb.com/sevmanager/view/658369) | L3 | Closed | Instagram | Model m2147179183 not deploying new snapshots |
| [S658426](https://www.internalfb.com/sevmanager/view/658426) | L4 | Closed | Instagram | Publish Jobs failing for model 2147179183  |
| [S658462](https://www.internalfb.com/sevmanager/view/658462) | L3 | Mitigated | Instagram | Threads Notification M2M Retrieval Model 877194839 Recurring Publish Flow Error Too High |
| [S658534](https://www.internalfb.com/sevmanager/view/658534) | L3 | Closed | Instagram | [IG Direct DE] ig_communication_users_deltoid delayed >2 days - IG Vital Tier 0/1 metric impact |
| [S658691](https://www.internalfb.com/sevmanager/view/658691) | L3 | Mitigated | Instagram | Reels FSR down due to MVAI + MTIA migration for Save + Follow 7d LTV LSR model |
| [S659097](https://www.internalfb.com/sevmanager/view/659097) | L4 | Closed | Instagram | [MB8] Inplace Snapshot Update OOM |
| [S659167](https://www.internalfb.com/sevmanager/view/659167) | L1 | Mitigated | Instagram | Shots Optimizer QE Backtest causes Shots SLI to drop to 84% and Threads FSR to drop below 50% |
| [S659215](https://www.internalfb.com/sevmanager/view/659215) | L3 | Closed | Instagram | [IG Vital Delay] cbmd_deltoid__aapc_ig_vp_extended_target__viewer  |
| [S660251](https://www.internalfb.com/sevmanager/view/660251) | L4 | Closed | Instagram | Streaming success rate drop in IG Reel ESR MB6.5 LC  |
| [S660484](https://www.internalfb.com/sevmanager/view/660484) | L3 | Mitigated | Instagram | Threads LSR MB4 candidate publishing failure |
| [S661157](https://www.internalfb.com/sevmanager/view/661157) | L3 | Mitigated | Instagram | TIFU Prod Neg Sampling U2M Retrieval Model 2131533016  Expired |
| [S661169](https://www.internalfb.com/sevmanager/view/661169) | L3 | Closed | Instagram | mtml_ctr_instagram_model QRT candidate f1073480259 snapshots rejected on AMD hardware |
| [S661170](https://www.internalfb.com/sevmanager/view/661170) | L3 | Mitigated | Instagram | Prod Pristine model 920261872 and 920261873 publish job failed due to GPU quota rejection |
| [S661523](https://www.internalfb.com/sevmanager/view/661523) | L3 | Closed | Instagram | Prod T2I model 2136306074 failed to load model snapshot  |
| [S661752](https://www.internalfb.com/sevmanager/view/661752) | L3 | Closed | Instagram | IG Vital Delay si:cbmd_deltoid__aapc_ig_vp_extended_target__viewer |
| [S661783](https://www.internalfb.com/sevmanager/view/661783) | L3 | Mitigated | Instagram | TIXU ESR Prod Primary Model m876104295 Not loading Snapshots  |
| [S662279](https://www.internalfb.com/sevmanager/view/662279) | L4 | Mitigated | Instagram | [Reels MB8.5] Recurring publishing failing for QE models |
| [S662458](https://www.internalfb.com/sevmanager/view/662458) | L4 | Mitigated | Instagram | Preemptive SEV for IG Feed LSR LTV O3 CPU -> MVAI CPU Model Migration |
| [S662497](https://www.internalfb.com/sevmanager/view/662497) | L4 | Mitigated | Instagram | [Feed][LSR][MB8] Streaming delta updates for 2125053533 |
| [S662694](https://www.internalfb.com/sevmanager/view/662694) | L2 | Mitigated | Instagram | mtml_ctr_instagram_model staleness due to validation |
| [S663866](https://www.internalfb.com/sevmanager/view/663866) | L3 | Mitigated | Instagram | Threads Notif Prod ESR Snapshot Deployment Fail |
| [S664024](https://www.internalfb.com/sevmanager/view/664024) | L3 | Mitigated | Instagram | Stories ESR Holdout Model Publish Failure Due to Common Pool Pipeline Failure |
| [S664258](https://www.internalfb.com/sevmanager/view/664258) | L3 | Mitigated | Instagram | Pipeline Delay Alert: instagram.recostream.ig_feed.ig_feed_esr_snapshot.tasks[ig_feed_esr_snapshot] (IGF) |
| [S665135](https://www.internalfb.com/sevmanager/view/665135) | L4 | Closed | Instagram | QE Model - TIFU ESR PNUA Model Train + Publish failure (root:2132407738,st:2132407717) |

### sev_type=Integrity, no 'online' keyword in title (1)

| SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|
| [S661239](https://www.internalfb.com/sevmanager/view/661239) | L3 | Closed | Integrity | AIIMd 5/5 is not landing due to broken change in torchx_cli:stable fbpkg |

### sev_type=Production, no positive OT marker (likely mrs_ml_release_oncall pipeline SEV) (27)

| SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|
| [S657827](https://www.internalfb.com/sevmanager/view/657827) | L4 | Closed | Production | [mvai/video_udd_lsr] & [mvai/video_ifu_lsr] & [mvai/cfr_main_feed_mtml_roo_hstu] serving_eval failing — vanguard predict |
| [S658142](https://www.internalfb.com/sevmanager/view/658142) | L4 | Mitigated | Production | [mvai/mvai_ifr_main] cogwheel_ifr_mtml_trunk_metrics_test publish failure — D103073916 packaging pass regression |
| [S658188](https://www.internalfb.com/sevmanager/view/658188) | L3 | Closed | Production | mvai run crashes with "Set changed size during iteration" on mvai_cli:7258+ |
| [S658312](https://www.internalfb.com/sevmanager/view/658312) | L4 | Closed | Production | [mvai/mvai_ig_ranking] cogwheel failure — FBLearner OOM + suffix collision |
| [S658476](https://www.internalfb.com/sevmanager/view/658476) | L4 | Closed | Production | [mvai/mvai_ifr_main] cogwheel failure — LoweringLogicException XL_WEIGHTS |
| [S658649](https://www.internalfb.com/sevmanager/view/658649) | L4 | Closed | Production | [mvai/mvai_ig_ranking] Cogwheel failure — stale cg1 lowering pkg |
| [S658769](https://www.internalfb.com/sevmanager/view/658769) | L3 | Mitigated | Production | Multi-forward models crash-looping due to strict ENFORCE in buildSparseDeltaUpdateMetaMap |
| [S659617](https://www.internalfb.com/sevmanager/view/659617) | L4 | Mitigated | Production |  [mvai/mvai_ig_ranking] cogwheel_ig_ranking_lsr_slimper_test blocked — baseline train killed, WeightsDeltaPublisher fail |
| [S659631](https://www.internalfb.com/sevmanager/view/659631) | L4 | Mitigated | Production | [mvai/mvai_ig_ranking] cogwheel_ig_ranking_lsr_test blocked — compute_meta MAST job name exceeds 76-char TW limit (78 ch |
| [S660501](https://www.internalfb.com/sevmanager/view/660501) | L4 | Closed | Production | [mvai/mvai_ig_ranking] cogwheel failure — S660017 ZippyDB outage |
| [S660546](https://www.internalfb.com/sevmanager/view/660546) | L3 | Mitigated | Production | [FBR HSTU Retrieval] ~19hr stale snapshots due to XStream crash from ZippyDB SEV1 (S660017) |
| [S660719](https://www.internalfb.com/sevmanager/view/660719) | L4 | Closed | Production | [mvai/video_ifu_lsr] cogwheel failure — jagged_unique_indices_cuda regression |
| [S660774](https://www.internalfb.com/sevmanager/view/660774) | L4 | Closed | Production | [mvai/light_cli] Check package size blocked — prod tag v5359 moved to old, local-built version |
| [S661020](https://www.internalfb.com/sevmanager/view/661020) | L4 | Closed | Production | [silvertorch/ifr_prospector] cogwheel failure — calibration threshold breach |
| [S661149](https://www.internalfb.com/sevmanager/view/661149) | L4 | Closed | Production | [mvai/light_cli] test_ifr_prospector + test_video_udd_t2i blocked — ImportError from D101665186 |
| [S661302](https://www.internalfb.com/sevmanager/view/661302) | L4 | Closed | Production | [mvai/video_udd_lsr] serving_eval blocked — preproc ImportError |
| [S661851](https://www.internalfb.com/sevmanager/view/661851) | L3 | Mitigated | Production | Engagement MTML LSR Prod Model Raas Timeout Spike Since 5/8 |
| [S661889](https://www.internalfb.com/sevmanager/view/661889) | L4 | Closed | Production | [mvai/mvai_ifr_main] cogwheel failure — missing metastore_thrift_python dep |
| [S661922](https://www.internalfb.com/sevmanager/view/661922) | L3 | Mitigated | Production | Silvertorch publish NaN failures on multiple edits sourcing models |
| [S661983](https://www.internalfb.com/sevmanager/view/661983) | L4 | Closed | Production | [mvai/light_cli] test_ifr_umia_v1_photo_publish blocking — TorchScript torch.fx.Node compile error from D104514584 |
| [S661987](https://www.internalfb.com/sevmanager/view/661987) | L4 | Closed | Production | [5 conveyors] Tag fbpkgs blocked — light_cli 800/800 cap (recurrence S657811) |
| [S662450](https://www.internalfb.com/sevmanager/view/662450) | L4 | Mitigated | Production | [mvai/mvai_ifr_main] cogwheel_ifr_mtml_trunk_metrics_test BLOCKED — Triton beta LLVM bump D104123406 breaks AOTI lowerin |
| [S662535](https://www.internalfb.com/sevmanager/view/662535) | L4 | Mitigated | Production | m886797001 (facebook_ifr_main_mtml_main, tier 1, 75k QPS) -- 0.15% error rate for 45m |
| [S662650](https://www.internalfb.com/sevmanager/view/662650) | L3 | Mitigated | Production | Model Publishing for most non-recsys tenants and model launching for recsys is broken |
| [S662679](https://www.internalfb.com/sevmanager/view/662679) | L4 | Closed | Production | [mvai/fire-app-fbr-preranker] cogwheel failure — Chronos RAM rollout |
| [S662898](https://www.internalfb.com/sevmanager/view/662898) | L4 | Mitigated | Production | [silvertorch/ifr_umia_v1] DPP filtering — 100% data filtered in predictor_eval_video (recurrence of S650966) |
| [S663166](https://www.internalfb.com/sevmanager/view/663166) | L3 | Mitigated | Production | Model 2131550324 (ig_explore_posts_mtml baseline) inference error rate |

### title has 'online_train_publish' but cogwheel-prefixed (release pipeline test, not OT) (3)

| SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|
| [S659492](https://www.internalfb.com/sevmanager/view/659492) | L4 | Fix Ready | Production | [mvai/video_udd_lsr] cogwheel NE threshold failure — online_train_publish NE=0.78 > 0.75 on cogwheel_trunk_multi_arm_met |
| [S661284](https://www.internalfb.com/sevmanager/view/661284) | L4 | Closed | Production | [mvai/mvai_ifr_main] cogwheel_ifr_mtml_trunk_metrics_test failure — online_train_publish NE metrics regression |
| [S664499](https://www.internalfb.com/sevmanager/view/664499) | L4 | Mitigated | Production | [mvai/mvai_ifr_main] [mvai/cfr_main_feed_mtml_roo_hstu] cogwheel_ifr_mtml online_train_publish — CUDA misaligned address |

## April + March backfill (2026-05-17 thread `7wZB1nUQH8Y`) — rejected SEVs

_Same OT-SEV identification rule as the May pass above. April pulled 34 candidates → 14 kept. March pulled 66 candidates → 19 kept. The 67 rejected entries are listed below as a regression-test fixture extension._

**Total rejected (April + March): 67** across 8 buckets.

### cogwheel-prefixed (release-pipeline test, not OT) (2)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| march | [S622615](https://www.internalfb.com/sevmanager/view/622615) | L4 | Closed | Production | [mvai/light_cli] Build node failure |
| march | [S630124](https://www.internalfb.com/sevmanager/view/630124) | L4 | Closed | Production | [mvai/light_cli] test_video_fbr_hstu_st2_0 unit tests failure |

### sev_type=AI Infra, no 'online' keyword in title (DPP/Sigrid infra SEV, not OT) (2)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| march | [S617743](https://www.internalfb.com/sevmanager/view/617743) | L2 | Closed | AI Infra | DPP Large SSR Drops in Several Regions (likely due to FTW Storm) |
| march | [S619839](https://www.internalfb.com/sevmanager/view/619839) | L2 | Closed | AI Infra | Investigate Sigrid errors after inplace update (ZCH cache misses, NE spikes, snapshot transition errors, capacity downsi |

### sev_type=Ads, no 'online' keyword in title (9)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| april | [S635059](https://www.internalfb.com/sevmanager/view/635059) | L1 | Closed | Ads | Batch Feature Snapshot Release of F3_BATCH_ADS_AGGREGATION_ADPUBLISHER caused $24k/min revenue strongness due to coverag |
| april | [S649194](https://www.internalfb.com/sevmanager/view/649194) | L1 | Closed | Ads | Label corruption caused bad AIOC 827288959 snapshot resulting in Revenue strongness starting 12:50PM |
| april | [S653758](https://www.internalfb.com/sevmanager/view/653758) | L2 | Closed | Ads | New HIM OC snapshot 599 causes 15k/min revenue strongness starting 4:55am 4/23 |
| march | [S617398](https://www.internalfb.com/sevmanager/view/617398) | L1 | Closed | Ads | New snapshot transition feature resulted in ARV dropping traffic and $30k/min revenue softness when new snapshot not ava |
| march | [S620111](https://www.internalfb.com/sevmanager/view/620111) | L1 | Closed | Ads | $62K/min Revenue Strongness caused by bad snapshot of oe_consolidated_offsite_cvr_view_through_model |
| march | [S627313](https://www.internalfb.com/sevmanager/view/627313) | L2 | Closed | Ads | Up to $20k strongness on OC due to stale AF OC snapshot |
| march | [S627911](https://www.internalfb.com/sevmanager/view/627911) | L1 | Closed | Ads | Bad OC HIM 829094329 snapshot (1099) led to peak ~$25k/min strongness |
| march | [S628630](https://www.internalfb.com/sevmanager/view/628630) | L1 | Closed | Ads | Bad Offsite Conversion (OC) model (mtml_offsite_cvr_model) caused peak revenue strongness of $30k/min |
| march | [S639948](https://www.internalfb.com/sevmanager/view/639948) | L2 | Closed | Ads | c. $10k strongness to forecast, associated with new HIM OC CVR v0 snapshot |

### sev_type=Instagram admitted by default, title has no 'online'/'OT job'/mvai-training-online keyword (12)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| april | [S621928](https://www.internalfb.com/sevmanager/view/621928) | L3 | Closed | Instagram | Reels ESR Daily Example Age Delays on Peak Traffic |
| april | [S630911](https://www.internalfb.com/sevmanager/view/630911) | L1 | Closed | Instagram | Broken Fireball Falco listeners breaking production models across Reels/Feed/Stories/Explore/Threads |
| april | [S632893](https://www.internalfb.com/sevmanager/view/632893) | L3 | Closed | Instagram | OmniUV error rate spikes due to IP runtime snapshot transition race-condition for atomic updates across all gpus |
| april | [S637724](https://www.internalfb.com/sevmanager/view/637724) | L3 | Closed | Instagram | Threads Feed U2M Prod Model 2133735724 Failed to load snapshot due to INPLACE_UPDATE_CONVERGENCE_ERROR |
| april | [S639895](https://www.internalfb.com/sevmanager/view/639895) | L3 | Closed | Instagram | Threads XAPP U2M prod model 2136123751 failed snapshot transition due to increased error rate in EAG |
| march | [S613939](https://www.internalfb.com/sevmanager/view/613939) | L3 | Closed | Instagram | ig_textpost_feed_m2m_retrieval baseline and holdout model 879240956 fails loading new snapshots |
| march | [S620107](https://www.internalfb.com/sevmanager/view/620107) | L3 | Closed | Instagram | Reels ESR Example Age Delay |
| march | [S620256](https://www.internalfb.com/sevmanager/view/620256) | L4 | Closed | Instagram | IG Feed ESR Main Model Root 879652881 OT Premption |
| march | [S620436](https://www.internalfb.com/sevmanager/view/620436) | L4 | Closed | Instagram | Low streaming success rates on fs for Reels and Feed LSR |
| march | [S631610](https://www.internalfb.com/sevmanager/view/631610) | L3 | Closed | Instagram | IGR Retrieval Omni & T2I models OT Koski crash loop |
| march | [S636400](https://www.internalfb.com/sevmanager/view/636400) | L1 | Closed | Instagram | Hacked lock checkpoint enrollment spikes from XDeltaSessionUpdateAutolabellerClassifierPolicy |
| march | [S638724](https://www.internalfb.com/sevmanager/view/638724) | L3 | Closed | Instagram | Error: Failed to load snapshot due to PACING_HEALTHCHECK_ERROR |

### sev_type=Instagram, scope_check rejected (no 'online'/OT keyword, no peer-team owner) (4)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| march | [S614007](https://www.internalfb.com/sevmanager/view/614007) | L3 | Closed | Instagram | Retrieval model m878841681  u2m_mb1_26h1_v1 model age increases |
| march | [S626355](https://www.internalfb.com/sevmanager/view/626355) | L3 | Closed | Instagram | Threads Feed retrieval m2m prod model m2142967377 Model Age Spike |
| march | [S627788](https://www.internalfb.com/sevmanager/view/627788) | L3 | Closed | Instagram | ig_textpost_feed_u2m_retrieval model age >3hrs |
| march | [S628026](https://www.internalfb.com/sevmanager/view/628026) | L3 | Closed | Instagram | High Model Age of M2M Model due to Wrongly Added Partition by HFO |

### sev_type=Production, no positive OT marker (cogwheel/silvertorch/release-pipeline/infra) (32)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| april | [S622516](https://www.internalfb.com/sevmanager/view/622516) | L2 | Closed | Production | Threads feed LSR prod 2138521890, LSR old prod m2143272283 and holdout model m2144239965 fails to load snapshot |
| april | [S637688](https://www.internalfb.com/sevmanager/view/637688) | L3 | Closed | Production | Threads Feed LSR Model 2138521890 (threads_feed_mtml baseline) model age |
| april | [S638758](https://www.internalfb.com/sevmanager/view/638758) | L3 | Closed | Production | Threads feed LSR old prod model 2143272283 failed to load snapshot |
| april | [S639668](https://www.internalfb.com/sevmanager/view/639668) | L3 | Closed | Production | IFR os team bt 882284613 and retrieval bt video model 2139690234 snapshot transition stuck due to prod tier out of quota |
| april | [S644864](https://www.internalfb.com/sevmanager/view/644864) | L3 | Closed | Production | [Profile Videos Tab][iOS] Incorrect MobileConfig cleanup in D97775445 hardcoded streaming behavior |
| april | [S646945](https://www.internalfb.com/sevmanager/view/646945) | L3 | Closed | Production | zippydb.whatsapp (prod) Drain SLA: shards at risk of losing quorum |
| april | [S647518](https://www.internalfb.com/sevmanager/view/647518) | L3 | Closed | Production | Threads Feed ESR Holdout Model Model Age Over 5 hours |
| april | [S651024](https://www.internalfb.com/sevmanager/view/651024) | L3 | Closed | Production | [mvai/mvai_ig_ranking] cogwheel_ig_ranking_esr_test cannot import name 'ParameterAblation' |
| april | [S656217](https://www.internalfb.com/sevmanager/view/656217) | L3 | Closed | Production | [igr_ranking_predictor] clips_discover FSR degradation -- Model 2134759102 (ig_reels_tab_preport_esr) snapshot unavailab |
| march | [S612181](https://www.internalfb.com/sevmanager/view/612181) | L3 | Closed | Production | Auth exception from Reliable END Message rollout led to training job stuck for several models |
| march | [S613560](https://www.internalfb.com/sevmanager/view/613560) | L3 | Closed | Production | Fleet-wise streaming update success rate audition |
| march | [S613570](https://www.internalfb.com/sevmanager/view/613570) | L3 | Closed | Production | IGR OmniUV Prod - CPEntity <> Delos AUTH failure leading to delta publisher and sparse-streaming failures |
| march | [S617668](https://www.internalfb.com/sevmanager/view/617668) | L3 | Closed | Production | Full snapshot age alert for IFR prod U2I models m880364937, m880367240 |
| march | [S617861](https://www.internalfb.com/sevmanager/view/617861) | L3 | Closed | Production | [silvertorch/ifr_prospector] Cogwheel Test Failure for IFR Prospector on serving eval |
| march | [S619881](https://www.internalfb.com/sevmanager/view/619881) | L3 | Closed | Production | [mvai/mvai_ifr_main] cogwheel_ifr_mtml_trunk_metrics_test NCCL timeout error |
| march | [S621700](https://www.internalfb.com/sevmanager/view/621700) | L4 | Closed | Production | [silvertorch/ifr_t2i] publish_video fails w/ KeyError: <ItemCachedTensorKey.ITEM_IDS: 'item_ids'> |
| march | [S623094](https://www.internalfb.com/sevmanager/view/623094) | L3 | Closed | Production | silvertorch/ifr_prospector \| IFR ESR Prospector Cogwheel Test failed: predictor crashes |
| march | [S625779](https://www.internalfb.com/sevmanager/view/625779) | L4 | Closed | Production | Inconsistent/Inaccurate MM API for WhatsApp Eligibility API status |
| march | [S626074](https://www.internalfb.com/sevmanager/view/626074) | L3 | Closed | Production | [GCP] Seeing perf drop for NCCL MNNVL + RDMA |
| march | [S628161](https://www.internalfb.com/sevmanager/view/628161) | L3 | Closed | Production | mvai/video_ifu_lsr trunk blocked with cogwheel error: DistBackendError: NCCL communicator was aborted on rank 0 |
| march | [S628606](https://www.internalfb.com/sevmanager/view/628606) | L3 | Closed | Production | Elevated fatals from XWhatsAppMarketingMessageIncomingMessageResponseWebhookController |
| march | [S629686](https://www.internalfb.com/sevmanager/view/629686) | L4 | Closed | Production | [silvertorch/ifr_umia_v1] release blocking by consistent dropping of training qps |
| march | [S631404](https://www.internalfb.com/sevmanager/view/631404) | L3 | Closed | Production | Link Triage Failures due to missing snapshots in self healing jerry dispatcher |
| march | [S631654](https://www.internalfb.com/sevmanager/view/631654) | L4 | Closed | Production | [mvai/video_ifu_lsr] release blocked due to inconsistent serving eval qps |
| march | [S633010](https://www.internalfb.com/sevmanager/view/633010) | L3 | Closed | Production | silvertorch/ifr_prospector blocked by long running serving eval |
| march | [S633089](https://www.internalfb.com/sevmanager/view/633089) | L3 | Closed | Production | mvai/video_udd_lsr serving eval mast job stuck but VG succeeds |
| march | [S633490](https://www.internalfb.com/sevmanager/view/633490) | L3 | Closed | Production | ThriftMeerkatStep throwing exceptions in CI |
| march | [S633551](https://www.internalfb.com/sevmanager/view/633551) | L4 | Closed | Production | silvertorch/fbr_hstu blocked by STUS failure hiveWorkItem |
| march | [S634902](https://www.internalfb.com/sevmanager/view/634902) | L3 | Closed | Production | DelosTable crash from RocksDB MVCC trim advancing past open snapshots |
| march | [S635013](https://www.internalfb.com/sevmanager/view/635013) | L4 | Closed | Production | multiple MVAI cogwheel tests blocked by ACL removal |
| march | [S639454](https://www.internalfb.com/sevmanager/view/639454) | L4 | Closed | Production | [silvertorch/ifr_umia_v1] Transient train.qps metric regressions over the past month |
| march | [S640269](https://www.internalfb.com/sevmanager/view/640269) | L4 | Closed | Production | Spike in Access Token / Permission Errors for  WhatsApp Cloud API Tiers (coex_prod, prod, mc_prod) |

### sev_type=Wearables, off-domain (1)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| march | [S619911](https://www.internalfb.com/sevmanager/view/619911) | L2 | Closed | Wearables | SG retail demo MemstatsCollector crashloop |

### sev_type=WhatsApp, no 'online' keyword (5)

| Month | SEV | Level | Status | sev_type | Title |
|---|---|---|---|---|---|
| april | [S633897](https://www.internalfb.com/sevmanager/view/633897) | L3 | Closed | WhatsApp | Significant drop in post impressions in Whatsapp channels |
| april | [S641995](https://www.internalfb.com/sevmanager/view/641995) | L3 | Closed | WhatsApp | [Whatsapp Android] startup crashes in beta due to missing method during JNI registration |
| april | [S651886](https://www.internalfb.com/sevmanager/view/651886) | L3 | Closed | WhatsApp | WhatsApp iOS crash from WAPriorityFuture inline-resolve race fired by ios_priority_future_resolve_queue_boost experiment |
| march | [S627709](https://www.internalfb.com/sevmanager/view/627709) | L2 | Closed | WhatsApp | Use-After-Free in WhatsApp VoIP Call Waiting Replay Loop |
| march | [S638027](https://www.internalfb.com/sevmanager/view/638027) | L3 | Closed | WhatsApp | WhatsApp Web drop in critical sync success rate |


## TODO — upstream `scope_check` tightening

This MISSING.md was rewritten by applying a stricter rule POST-`scope_check`. To prevent future false positives at the source, `scope_check.py` (specifically the `_RE_EXPLICIT_OT_SIGNAL` regex AND the `admit_by_default_sev_types={Instagram}` path in `team_lane_scope.py`) should be tightened to:


1. Drop the `sev_type=Instagram admitted by default` path UNLESS title also matches the keep-regex (`online`/`OT job`/`mvai-training-online-`/`teacher.*online`).

2. Add explicit cogwheel/release-prefix exclude (already partially handled via peer-team-owner gate, but `cogwheel_*` titles WITHOUT a peer-team owner still leak).

3. Validate against this MISSING.md as the 124-SEV regression fixture (57 May + 67 April+March, via thread `7wZB1nUQH8Y`).


Tracked: needs separate diff to land changes to `fbcode//pe_mrs_ml/mrs_ot_agent/src/capabilities/team_lane_scope.py` + tests.

## See also

- `mrs-ot-agent-src/team_bot/cron-jobs/ot-daily-learning-mitigated-sevs.md` — production cron that writes future archives

- `fbcode//pe_mrs_ml/mrs_ot_agent:scope_check` — current production scope tool (needs tightening — see TODO above)

- Operator rules: thread `6i0LDKZxIR8` (2026-05-17) — `mrs_ml_release_oncall` + 'online' rule
