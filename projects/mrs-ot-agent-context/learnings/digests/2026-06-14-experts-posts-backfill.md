# 2026-06-14 — OT key-people Workplace posts BACKFILL (30-day seed, FULL bodies)

_Backfill (operator 2026-06-13). Roster: key-people.json (`posts` surface). Bodies kept up to 2500 chars (was 500 — fixed 2026-06-13 after ~90% of weekly-status posts were being dropped). Window: last 30 days._

**31 OT-relevant posts** with full bodies.

## Per-person digest

### dennyzhang (Denny Zhang, trust 3) — 11 posts · OT dev (operator)

#### [## Oncall Summary for mrs\_online\_training: 02 Jun - 09 Jun](https://fb.workplace.com/groups/mrs.ot/permalink/1347037760724300/)
_2026-06-09 · MRS Online Training Users_ · refs: D107207628, D107594279, D107651869, D107678546, D107687417, D98638473, S665454, S668542, S668980, S669019, S669785, S670229, S670344, S670538, S670795

> ## Oncall Summary for mrs\_online\_training: 02 Jun - 09 Jun
>
> Next oncall → Li Lu
>
> ### Items in Summary
>
> No items
> [See more in Oncall Hub](https://www.internalfb.com/omh/view/mrs_online_training/shift_summary?report=3840279046280738)
>
> # **MRS Online Training Oncall Summary**
>
> Heavy week — **4 HIGH-TOUCH SEVs** (IFR zombie, U2M closed, IGR delta publish, Reels OOMs), 6 pages, 66 alerts. [S670887](https://www.internalfb.com/sevmanager/view/670887) zombie and ifu\_i2i FULL\_SNAPSHOT active at handover.  
>
> ## 🚨 SEVs and Alerts Oncall Got Paged
>
> - **Paged this shift: 6 — 1 SEV robocall, 5 critical alerts**
> - Wed 06-03 04:13 — [A1201406268614142](https://www.internalfb.com/monitoring/alerts/?alert_instance=1201406268614142%40#$1729017291786319:model%202126189932%20online%20tzvq4jso5slbmh) (critical) starsearch\_t2i sparse delta — source\_not\_actionable
> - Wed 06-03 11:08 — [S670887](https://www.internalfb.com/sevmanager/view/670887) (L3 robocall) IFR MainMTML 2125752019 zombie — **In Progress at handover**
> - Thu 06-04 15:55 — [A902257976006165](https://www.internalfb.com/monitoring/alerts/?alert_instance=902257976006165%40#$dai_modelstore@#$%7Bcolumn:count%7D@#$vdd_hstu_v0%20877766818%20missing%20full_snapshot) (critical) vdd\_hstu\_v0 FULL\_SNAPSHOT — resolved
> - Fri 06-05 04:22 — [A1455336899399360](https://www.internalfb.com/monitoring/alerts/?alert_instance=1455336899399360%40#$dai_modelstore@#$%7Bcolumn:count%7D@#$m2m_retrieval%202130324780%20missing%20full_snapshot) (critical) m2m\_retrieval FULL\_SNAPSHOT — resolved
> - Mon 06-08 14:11+14:34 — [A1014037717816039](https://www.internalfb.com/monitoring/alerts/?alert_instance=1014037717816039%40#$avg@#$scribe_age_mins@#$ifr_main_mtml%20scribe%20example%20age%202125752019) (critical ×2) IFR scribe example age — source\_not\_actionable
> - *Page-eligible: ig\_organic\_feed CL-003 cascade (878102693, 2134319967, 2133008573) — root* [*S668542*](https://www.internalfb.com/sevmanager/view/668542)
>
> ## Overview
>
> - **SLICK —** [Instagram](https://fburl.com/monitoring/gmdu02yq): ⚠️ 1/49 breached (ig\_textpost\_feed\_m2m\_retrieval Reranker 0%) | [Discovery](https://fburl.com/monitoring/rkhcqpuj): 🔴 7/168 breached (facebook\_ifr\_main\_mtml\_main ×3, ifr\_main\_i2i, vdd\_hstu\_v0, ifu\_mtml\_v0, IFR T1 Gen Stability)
> - **SEVs (HIGH-TOUCH):** 4 — [S670887](https://www.internalfb.com/sevmanager/view/670887) (IFR zombie, paged, open), [S665454](https://www.internalfb.com/sevmanager/view/665454) (U2M, closed Jun 4 ✓), [S668980] …[truncated]

#### [# [Action needed] OT job for ig_textpost_feed_u2m_retrieval (Threads) became zombie — needs manual kill + base-layer patch](https://fb.workplace.com/groups/mrs.ot/permalink/1344542434307166/)
_2026-06-06 · MRS Online Training Users_ · refs: D98638473, S665454, S670887

> # [Action needed] OT job for ig_textpost_feed_u2m_retrieval (Threads) became zombie — needs manual kill + base-layer patch
>
> The OT job **mvai-training-online-2124428748** (Threads u2m_retrieval, model 2124428748, owner @wenping) is stuck — training QPS has been at 0 since ~13:44 PT on 6/5 (~12.5h). The job shows RUNNING in MAST but is no longer training.
>
> **What we found: **a worker (rank 6) hit a CUDACachingAllocator INTERNAL ASSERT FAILED (free_block, CUDACachingAllocator.cpp:3316) → terminate()/SIGABRT, which the stuck-job detector correctly caught. However, a known base-layer bug prevents the process from exiting cleanly after the crash, so MAST does not recognize the failure and creates no new attempt — even though 100 retries are configured.
>
> **Suggested actions:**
>
> 1. Short-term — kill the stuck job so MAST creates a new attempt and resumes training
>
> 2. Prevent recurrence — upgrade the base layer to include the fix ([D98638473](https://www.internalfb.com/diff/D98638473?entry_point=20)). The current base light_cli:5315 predates it; without the upgrade, future worker crashes get stuck the same way.
>
> Context: same root cause as [S665454](https://www.internalfb.com/intern/sevmanager/view/s/665454) and [S670887](https://www.internalfb.com/intern/sevmanager/view/s/670887), and the 6/4 zombie on sibling Threads model 2124793203.
>
> **This is a Tier-3 model.** If it's critical to Threads, please reach out to MRS (Li Lu / Denny) to align on infra-support SLA.

#### [# [Action needed] OT job for ig_textpost_feed_u2m_retrieval become zombie - need manual kill and patch the diff](https://fb.workplace.com/groups/mrs.ot/permalink/1342215704539839/)
_2026-06-03 · MRS Online Training Users_ · refs: D98638473, S665454, S670887

> # [Action needed] OT job for ig_textpost_feed_u2m_retrieval become zombie - need manual kill and patch the diff
>
> Hi team,
>
> The OT job mvai-training-online-2124793203 appears to be stuck — training QPS has been at 0 since 09:39 today. The job shows as RUNNING in MAST but is no longer training.
>
> What we found: A worker hit a CUDACachingAllocator assertion error, which was correctly detected and logged. However, a known issue in the base layer prevents the process from exiting cleanly after the error, so MAST does not recognize the failure and no new attempt is created — even though 100 retries are available.
>
> **Suggested actions:**
>
> **1. Short-term: Killing the stuck job** will allow MAST to create a new attempt and resume training.
>
> **2. Prevent recurrence: **When convenient, upgrading the base layer to include the fix ([D98638473](https://www.internalfb.com/diff/D98638473?entry_point=20)). The current base layer light_cli:5308 (upstream 2026-05-02) predates the fix. Without the upgrade, future worker crashes may get stuck in the same way.
>
> Context: This is the same root cause behind [S665454](https://www.internalfb.com/intern/sevmanager/view/s/665454) and [S670887](https://www.internalfb.com/intern/sevmanager/view/s/670887). Full investigation details: [P2362425568](https://www.internalfb.com/intern/paste/P2362425568)
>
> Happy to answer any questions or help with the upgrade.

#### [# 📣 Shift-Left Triage: Early-Warning OT Oncall Alerts](https://fb.workplace.com/groups/4239452842845159/permalink/24952837091080098/)
_2026-06-02 · PE MRS ML FYI_ · refs: D106755615, D10690302, D106903024, D10727754, D107277546, D10728303, D107283032, D107283156, S627484, S630911

> # 📣 Shift-Left Triage: Early-Warning OT Oncall Alerts
>
> **TL;DR** — Added WARNING tiers to all 5 MRS OT alert families (60+ models) so the OT debug agent auto-triages *before* oncall is paged — an ~80 min–2h head-start. Targets: ≥30% fewer MAJOR pages and ≤5 min to diagnosis. **Shift-left is a reusable pattern, not a one-off: the agent triages ~100× the alert volume a human oncall can.**
> ## Problem
>
> OT reliability alerts jump straight from **silent → MAJOR (pages oncall)**. There is no window for the OT debug agent to auto-investigate before a human is paged. Result: oncall gets woken up for transient issues that resolve themselves, and the agent can only react *after* a page — never *before*.
>
> Today that gap is expensive: ~30–60 min just to find the owning component, median ~24h to triage (worst case [S627484](https://www.internalfb.com/intern/sevmanager/view/s/627484): 262h), and SEV1s like [S630911](https://www.internalfb.com/intern/sevmanager/view/s/630911) (~20% dwell-time drop) lose 30+ min to wrong-team paging.
> ## What this unlocks
> * **Autonomous remediation:** With WARNING → agent → auto-triage proven, the next step is agent auto-mitigation (restart stuck jobs, file follow-up tasks, apply known-pattern fixes).
> * **Fleet-wide coverage:** All 5 MRS OT alert families now have WARNING tiers — the shift-left pattern is complete across the monitoring surface.
> * **Oncall quality of life:** Fewer pages for issues the agent can handle. Oncall focuses on genuinely novel problems.
> ## What we shipped
>
> Added **WARNING tiers** to 5 alert families across 60+ OT models, plus wired the OT debug agent to poll WARNING alerts for autonomous pre-page triage.
> | # | Alert family | Diff | WARNING fires at | Agent head-start | Models |
> | --- | --- | --- | --- | --- | --- |
> | 1 | Publishing stability (FS/delta gap) | [D106755615](https://www.internalfb.com/diff/D106755615) | 1.2× cycle windo | w~80 mi | n3 |
> | 0 | 2IFR Watchtower (too few delta snapshots | [)D10690302](https://www.internalfb.com/diff/D106903024) | 4count < threshold+ | 2~2 | h |
> | 2 | 3Scribe example age (training data freshness | [)D10727754](https://www.internalfb.com/diff/D107277546) | 68 min (SLO=10 min | )~2 mi | n2 |
> | 2 | 4VideoFM scribe example ag | [eD10728315](https://www.internalfb.com/diff/D107283156) | 68 min (SLO=5 min | )~2 mi | n |
> | 1 | 5Trunk stability (SLI violation hours | [)D10728303](https://www.internalfb.com/diff/D107283032) | 20.8× MAJOR thresho | ld~20% headro | om13 conveyors × 3 t …[truncated]

#### [# [OT triage] mvai-training-online-2125752019 (IFR Main MTML) — scribe example age spike + NCCL zombie at 08:10 PT](https://fb.workplace.com/groups/mrs.ot/permalink/1341029697991773/)
_2026-06-02 · MRS Online Training Users_

> # [OT triage] mvai-training-online-2125752019 (IFR Main MTML) — scribe example age spike + NCCL zombie at 08:10 PT
>
> **Model**: facebook_ifr_main_mtml_main (id 2125752019) | arch: in-trainer | importance: prod | owner: yucheng
>
> **PROBLEM**: IFR Main MTML OT job hit two issues today — (1) scribe example age spike 05:15–06:34 PT (auto-resolved after peak traffic), then (2) NCCL watchdog stall at ~08:10 PT killed all ranks, training
>
> QPS dropped to 0 and has not recovered.
>
> **LIKELY CAUSE**: [INFERRED] Peak traffic overloaded scribe pipeline causing stale training data; separately, a Hedwig publisher rate timeout (RECV_TIMEOUT at 07:24 PT) may have triggered the NCCL watchdog
>
> stall across all 80 GPUs.
>
> Detail reporting: [Everpaste](https://fburl.com/everpaste/op7az60g)
>
> **ASK**: @yucheng — please kill the zombie MAST job to trigger auto-retry and recover training. Follow-up: enable flow control or increase publish rate limit on scribe category
>
> `feed_learning_examples_raas_in_feed_reco_request_level` to prevent example age recurrence.

#### [## Oncall Summary for mrs\_online\_training: 20 May - 26 May](https://fb.workplace.com/groups/mrs.ot/permalink/1335147105246699/)
_2026-05-26 · MRS Online Training Users_ · refs: D104339726, D105054082, D105862249, D105881418, D105890355, D105916880, D106018122, D106022977, D106022978, D106191904, D106193584, D106194663, D106195444, D106197380, D88508586

> ## Oncall Summary for mrs\_online\_training: 20 May - 26 May
>
> Next oncall → Paul Lu
>
> Items in Summary
>
> No items
>
> [See more in Oncall Hub](https://www.internalfb.com/omh/view/mrs_online_training/shift_summary?report=960502573484474)
>
> # **MRS Online Training Oncall Summary**
>
> # Overview
>
> ## OT SLICK SLI:
>
> Discovery Online Models: [https://fburl.com/monitoring/rkhcqpuj](https://fburl.com/monitoring/rkhcqpuj)  
>
> Instagram Online Models: [https://fburl.com/monitoring/gmdu02yq](https://fburl.com/monitoring/gmdu02yq)  
>
> Outgoing → **Denny**  |  Incoming → **Paul Lu**  
>
> **Heavy week — 23 SEVs touched (7 HIGH-TOUCH),** dominated by training job zombie pattern (S665478+S665454) and DPP restart investigation. Three concurrent conveyor/publish failures unresolved.  
>
> ## Overview
>
> * **SEVs (HIGH-TOUCH): 7 —** **[S667567](https://www.internalfb.com/intern/sevmanager/view/s/667567)** **(filed + robocalled by oncall)** — [S665454](https://www.internalfb.com/intern/sevmanager/view/s/665454) L3, [S667567](https://www.internalfb.com/sevmanager/view/667567) L4, [S666451](https://www.internalfb.com/sevmanager/view/666451) L4, [S666546](https://www.internalfb.com/sevmanager/view/666546) L4, [S665902](https://www.internalfb.com/sevmanager/view/665902) L4,[S667668](https://www.internalfb.com/sevmanager/view/667668) L4, [S665478](https://www.internalfb.com/sevmanager/view/665478) L3
> * **SEVs (observe-only):** 12 — Reels/IG model staleness ([S666880](https://www.internalfb.com/intern/sevmanager/view/s/666880), [S667736](https://www.internalfb.com/intern/sevmanager/view/s/667736), [S665214](https://www.internalfb.com/intern/sevmanager/view/s/665214)): 3; ESR/LSR calibration+launch ([S667572](https://www.internalfb.com/intern/sevmanager/view/s/667572), [S666468](https://www.internalfb.com/intern/sevmanager/view/s/666468)): 2; CFR conveyor ([S667541](https://www.internalfb.com/intern/sevmanager/view/s/667541), [S666788](https://www.internalfb.com/intern/sevmanager/view/s/666788)): 2; Threads OT ([S665454](https://www.internalfb.com/intern/sevmanager/view/s/665454)): 1; LSR streaming ([S667222](https://www.internalfb.com/intern/sevmanager/view/s/667222)): 1; misc ([S667332](https://www.internalfb.com/intern/sevmanager/view/s/667332), [S667453](https://www.internalfb.com/intern/sevmanager/view/s/667453), [S663485](https://www.internalfb.com/intern/sevmanager/view/s/663485)): 3
> * **Alerts:** 3 actionable of 9 total (4 auto-resolved)
> * **WP user reports: 8** — Hongzhang Yin, Wei Zheng, D …[truncated]

#### [# FBR IFU I2I model 2132070936 missing FULL_SNAPSHOT 8+ hours — reranker model 2125081901 hung since 04:27 PDT](https://fb.workplace.com/groups/mrs.ot/permalink/1332867342141342/)
_2026-05-23 · MRS Online Training Users_

> # FBR IFU I2I model 2132070936 missing FULL_SNAPSHOT 8+ hours — reranker model 2125081901 hung since 04:27 PDT
>
> **TLDR**: Model 2132070936 (facebook_reels_ifu_i2i, PROD) has not published a FULL_SNAPSHOT for 8+ hours. The ST model's T2I update service triggers FS only when the upstream reranker model (2125081901) produces a new checkpoint. Reranker model 2125081901 is hung: MAST reports RUNNING but last mvai_metrics sample was 04:27 PDT, and checkpoint 609 has been stuck in CREATING (size=0) since 04:29 PDT. This is a P44-class trainer hang (process alive, Python frozen, no exception, no NCCL watchdog trip). It will not self-recover.
>
> Confirm: check UMM at [https://www.internalfb.com/ummmeta/cq?entity_id=2125081901](https://www.internalfb.com/ummmeta/cq?entity_id=2125081901) — checkpoint 609 should show CREATING, size=0.
>
> **ACTION REQUIRED: **Restart reranker job mvai-training-online-2125081901 (kill v4, TMS auto-restarts from checkpoint 608).
>
> **NEXT STEP: **Model owner fengzhang1 / oncall mrs_relevance_retrieval_i2i restarts the reranker. Once a new VALID checkpoint appears, the T2I service on 2132070936 will automatically publish a FULL_SNAPSHOT and the dai_modelstore alert clears.
>
> Full investigation + reproduction: [P2349062759](https://www.internalfb.com/intern/paste/P2349062759)

#### [#  ~280 non-actionable example-age dips with UBN/SEV risk per half — planned DPP restarts](https://fb.workplace.com/groups/mrs.ot/permalink/1332798372148239/)
_2026-05-23 · MRS Online Training Users_ · refs: S667544

> #  ~280 non-actionable example-age dips with UBN/SEV risk per half — planned DPP restarts
>
> **Summary: **Every ~20 days, DPP automatically restarts each OT job's data session. During the restart, training pauses for a few minutes and example age spikes — often enough to fire UBN/SEV alerts. This affects all OT models. [~280 non-actionable dips](https://fburl.com/scuba/ai_mlu/fjh5vmsk) per half across 50+ models. Self-recovers, but creates oncall noise for both model owners and infra.
>
> **Confirm you're affected: **meta ai.mast-job error --name=<job> --no-truncate — look for:
>
>   "Session <ID> has been running for <N> seconds which is higher than limit: 1728000 seconds. Triggering a new attempt. NOTE: This restart is necessary to prevent the session from running in bad state. It should NOT be considered as a failure."
>
> **Next step: **loop in DPP team (`dpp_distributed_data_reading`) for graceful session rotation.
>
> Full investigation: [P2349020385](https://www.internalfb.com/intern/paste/P2349020385)
>
> Related: SEV [S667544](https://www.internalfb.com/intern/sevmanager/view/s/667544)

#### [🚨 Threads U2M retrieval trainer was stuck for 14 hours — and nobody noticed until a human killed it](https://fb.workplace.com/groups/mrs.ot/permalink/1332046782223398/)
_2026-05-22 · MRS Online Training Users_ · refs: S665454

> 🚨 Threads U2M retrieval trainer was stuck for 14 hours — and nobody noticed until a human killed it
>
> **Model** 2124122280 · ig_textpost_feed_u2m_retrieval · owner @mlygao
> **SEV** S665454 · **Date** May 16 · **Tier** TIER_3
>
> ## What happened
>
> May 16, 04:01 PDT — trainer hung. MAST said RUNNING. QPS was zero. **No alert fired.** 13 hours later, wenping manually killed it.
>
> - **Last mvai_metrics sample:** 04:00:48
> - **Next sample:** 18:10:23
> - **Total gap: 14h 9m**
>
> ## Root cause
>
> Trainer process alive at OS level, but Python interpreter stopped progressing — known pattern P44/P45/P46 (GIL hang, C++ deadlock, or storage stall). No py-spy captured, so exact sub-class unknown.
>
> ## Detection gap
>
> SJD checks if the process is **alive**, not if it is **training**. Hung-but-alive trainers are invisible. This is recurring (SEV S665454).
>
> ## Questions
>
> 1. Anyone else seen trainer RUNNING but zero QPS on their OT models?
> 2. Should we add an **mvai_metrics staleness check** to SJD/TMS?
>
> 📎 **Full investigation:** [P2347911341](https://www.internalfb.com/intern/paste/P2347911341/) · **SEV:** [S665454](https://www.internalfb.com/sevmanager/view/665454)

#### [# 🚨**Publish-path fragility on IG OT models -- recurring FULL_SNAPSHOT SLO violations**](https://fb.workplace.com/groups/mrs.ot/permalink/1331638558930887/)
_2026-05-21 · MRS Online Training Users_

> # 🚨**Publish-path fragility on IG OT models -- recurring FULL_SNAPSHOT SLO violations**
>
> Create the post to track a major risk for cross team visibility. The immediate UBN got auto-recovered.
>
> 4-day analysis (model`878858380`,`facebook_cfr_main_mtml` holdout, owner`yzqian`) shows**25% of FULL_SNAPSHOT intervals miss the 100-min SLO**; tail gaps of 4-11h. Today's 11.5h gap is the worst sample but the pattern is daily, not a one-off.
>
> Two reproducible failure modes:
> •**Mode A --****`CREATING`**** zombies**: snapshots stuck at`state=CREATING, size=0` forever, no GC.**5 zombies in 4 days.** Every >180-min publish gap in the dataset immediately follows a zombie.
> •**Mode B -- silent skips**: publish process spawn fails, snapshot IDs never register in model store, no alert emitted (only the downstream freshness gap eventually trips).
>
> Today's 11.5h breakdown: ~6h40m CL-017 Shampoo-NaN cascade (also hit cfr_main baseline`2134801434` same day =**family-wide event**, not per-model) + ~3h9m mode-B publish-spawn failure (`Async publish process creation failed!`) + ~1h42m normal fresh-attempt recovery.
>
> **Full investigation + reproduction + open questions for****`model_store`**** /****`mvai`**** /****`feed_ecosystem_core_modeling`**: [P2347269408](https://www.internalfb.com/intern/paste/P2347269408)

#### [# FULL_SNAPSHOT ig_textpost_feed_m2m_retrieval (model 2130324780) stuck 4+ h](https://fb.workplace.com/groups/mrs.ot/permalink/1330685625692847/)
_2026-05-20 · MRS Online Training Users_

> # FULL_SNAPSHOT ig_textpost_feed_m2m_retrieval (model 2130324780) stuck 4+ h
>
> Last FULL_SNAPSHOT: 5/20 1:16 PM PDT ([MLHub](https://www.internalfb.com/mlhub/models/model_series/2130324780?artifactTableTab=snapshots). Major alert [link](https://www.internalfb.com/monitoring/alert/?alert_id=1455336899399360%40%23%24dai_modelstore%40%23%24%7Bcolumn%3Acount%7D%40%23%24publishing%20stability%3A%20ig_textpost_feed_m2m_retrieval%20model%202130324780%20missing%20snapshot%20types%20full_snapshot&alert_created_time=1779318565))
>
> * v41 crashed with AssertionError: At least 64077 embs needed for kmeans, but got 1315 — upstream T2I corpus (agg_threads_star_search_common_pool_with_replies_by_ts_48h) collapsed. 
> * v42 hitDPP stuck. 
> * v43 is RUNNING in bulk eval phase but hasn't reached kmeans index build yet — if corpus is still depleted, it will crash the same way.
>
> root trainer and reranker jobs looks good
>
> Owner: ronghuang / p92_relevance_retrieval_oncall

### lupaul (Paul Lu, trust 3) — 2 posts · OT dev (MRS)

#### [# [S669019](https://www.internalfb.com/intern/sevmanager/view/s/669019) - MVAI Python Upgrade causing OT jobs to OOM](https://fb.workplace.com/groups/mrs.ot/permalink/1348865413874868/)
_2026-06-11 · MRS Online Training Users_ · refs: S669019

> # [S669019](https://www.internalfb.com/intern/sevmanager/view/s/669019) - MVAI Python Upgrade causing OT jobs to OOM
>
> `tldr:` if your OT job is running a light_cli version built using Python 3.12 (Upgrade from 3.10 on Apr 24) and your job is doing in-trainer publishing - you may observe a memory leak leading to an OOM after 40+ hrs.
>
> We are actively working on root causing what is causing the leak; and evaluating if this can be resolved in Python 3.14.
>
> **Conditions for OOM:**
> * running a light_cli version built after Apr 24 (likely using 3.12)
> * running in-trainer publishing for your online training job (generating full snapshot or deltas)
> * host memory shows RSS climbing (example: [https://fburl.com/canvas/5z3atv9v](https://fburl.com/canvas/5z3atv9v))
>
> **Guidance on how to check and mitigate:**
>
> See the following doc for how to mitigate and rebuild light_cli using 3.10 [https://docs.google.com/document/d/1Nf13iSjWG3TZnGKJz4Ec9vcJxjwSGsH7IgoN2wx6vJk/edit?tab=t.0](https://docs.google.com/document/d/1Nf13iSjWG3TZnGKJz4Ec9vcJxjwSGsH7IgoN2wx6vJk/edit?tab=t.0)
>
> Feel free to reach out in this post comments if you have additional questions or need help.  
>
> cc Li Lu (mrs ot oncall), Andrew Mao (mrs release)

#### [## Oncall Summary for mrs\_online\_training: 26 May - 02 Jun](https://fb.workplace.com/groups/mrs.ot/permalink/1340724948022248/)
_2026-06-02 · MRS Online Training Users_ · refs: D105652547, D106474860, D106554476, D106566401, D106588525, D106718379, D106833162, D106873154, D106873155, D106873156, D106873157, D106912787, D107167718, D98638473, S665454

> ## Oncall Summary for mrs\_online\_training: 26 May - 02 Jun
>
> Next oncall → Denny Zhang
>
> ### Items in Summary
>
> No items
> [See more in Oncall Hub](https://www.internalfb.com/omh/view/mrs_online_training/shift_summary?report=3924955117797781)
>
> -   
>
> # **MRS Online Training Oncall Summary**
>
> # Overview
>
> ## OT SLICK SLI:
>
> Discovery Online Models: https://fburl.com/monitoring/rkhcqpuj  
> Instagram Online Models: https://fburl.com/monitoring/gmdu02yq  
>
> **Theme**: High-volume shift Multiple SEV-3s in streaming/publish failures, model staleness, hung jobs and expired fire-app app-layers. Significant proactive work on DeltaPublisher memory optimization and SLICK model discovery improvements.  
>
> ## **Ongoing issues**
>
> [S665478](https://www.internalfb.com/sevmanager/view/665478) - Reels LSR MB9 — OT jobs hanging - fix [D98638473](https://www.internalfb.com/diff/D98638473)  applied - monitor  
> [S665454](https://www.internalfb.com/sevmanager/view/665454) - Threads Retrieval U2M — OT jobs stuck sporadically - They may need our help patching light\_cli with [D98638473](https://www.internalfb.com/diff/D98638473)  
> [S668980](https://www.internalfb.com/sevmanager/view/668980) - IGR ESR MB7 — QPS anomaly during delta publish - monitor to see if Flow control enabled improves things  
> S669019: Reels LSR MB9 - OOMs on OT jobs - investigation still in progress  
>
> ## **SEVs**
>
> | SEV | Level | Model/Area | Our Contribution |
> | --- | --- | --- | --- |
> | [S670542](https://www.internalfb.com/sevmanager/view/S670542) | 3 | : OT restart issue of Kappa feature deprecation teacher model 2128873883 | Possibly job name change affected TMS being able to restart. managed\_training\_service oncall looped into to investigate |
> | [S668272](https://www.internalfb.com/sevmanager/view/668272) | 3 | IG Feed ESR — Sparse Streaming OT failure | Transient network error led to repeated failure - extending staleness - follow up: reduced max-app-retries |
> | [S668980](https://www.internalfb.com/sevmanager/view/668980) | 3 | IGR ESR MB7 — QPS anomaly during delta publish | Suspect streaming publishing rate throttling leading to longer time to stream full delta; trainer stuck waiting for prev delta to finish before starting on next delta - this has a consequence of blocking training; Flow Control being enabled to mitigate |
> | [S670233](https://www.internalfb.com/sevmanager/view/670233) | 3 | FB IFR Prospector model 886351377 — no snapshots | Recurring Job for Full Publish Snapshot expiration date set in MLHu …[truncated]

### llu6 (Li Lu, trust 3) — 1 posts · OT dev (MRS)

#### [## Oncall Summary for mrs\_online\_training: 12 May - 19 May](https://fb.workplace.com/groups/mrs.ot/permalink/1329661585795251/)
_2026-05-19 · MRS Online Training Users_ · refs: D105606893, D105652547, D98079189, D98861780, S635390, S640723, S660017, S660220, S663027, S663484, S663485, S664106, S664296, S664460, S664484

> ## Oncall Summary for mrs\_online\_training: 12 May - 19 May
>
> Next oncall → Yabin Zhang
>
> ### Items in Summary
>
> No items
> [See more in Oncall Hub](https://www.internalfb.com/omh/view/mrs_online_training/shift_summary?report=1508508230928662)
>
> # **MRS Online Training Oncall Summary**
>
> # Overview
>
> **OT SLICK SLI:**  
>
> - Discovery Online Models: https://fburl.com/monitoring/rkhcqpuj
> - Instagram Online Models: https://fburl.com/monitoring/gmdu02yq
>
> ## Ongoing issues
>
> **S665214** — SEV3, In Progress  
> Silent checkpoint save failure on tier-1 model facebook\_reels\_ifu\_i2i (model 2132070936)  
> Checkpoint saves fail silently due to Manifold timeouts (S664484/S664460). Retry JK `minimal_viable_ai/enable_retryable_error_checkpointing:enable_by_entitlement` disabled for `fb_reels_prod_online`. Job gets stuck without auto-restarting. Hit 3x in 48h (05/12–05/14).  
> (OT oncall: investigated failure chain (P2341095840), looped in model\_store oncall who confirmed root cause is upstream S664460. Mitigation: manual restart.)  
> Next oncall: Monitor S664460 resolution. Manual restart if reranker fails. Follow up on enabling the retry JK for `fb_reels_prod_online`.  
>
> **S665478** — SEV3, In Progress  
> Reels LSR MB9 OT jobs hanging (model 2123153585)  
> NCCL deadlock → worker enters Linux D-state → elastic agent hangs → MAST job never terminates. Hit 2 models during MB9 launch. Candidate fixes: D105606893 (Paul Lu) and D105652547 (Tushar Jain), both require base layer rebuild.  
> (OT oncall: shared analysis P2338625112, coordinated with MVAI and pytorch\_distributed\_infra oncalls on root cause and fixes.)  
> Next oncall: Check if D105652547 or D105606893 land in a new light\_cli. Follow up with model owners on testing.  
>
> **S665454** — SEV3, In Progress  
> Threads Retrieval U2M OT jobs get stuck sporadically (models 2124122280, 2124793203, 2124428748)  
> Jobs appear running but QPS drops to zero. TMS doesn't restart because job is technically alive. Seen 4x in past week, manually killed each time. Likely same root cause as S665478.  
> (OT oncall: linked to S665478, shared analysis P2341568201 with two-layer fix recommendations.)  
> Next oncall: Same fixes as S665478. Monitor if model owners spin up test jobs.  
>
> **S663485** — SEV4, In Progress (Preemptive)  
> MPZCH enablement on Threads T2I SilverTorch Publishing  
> Publish step crashes at full snapshot creation with MPZCH enabled. MPZCH team recommends migrating to KVZCH instead (MPZCH no longer actively supported).  
> (OT oncall: sha …[truncated]

### shugye (Shuguang Ye, trust 3) — 3 posts · OT eng manager (MRS)

#### [# [Launch] [Thread Search] STAR powered Agentic Semantic Aware User-to-Media Retrieval for Search](https://fb.workplace.com/groups/399626961860250/permalink/1566545631835038/)
_2026-06-11 · MRS Change Log_

> # [Launch] [Thread Search] STAR powered Agentic Semantic Aware User-to-Media Retrieval for Search
>
> FYI We collaborated with Threads developed agentic semantic aware user-to-media (U2M) retrieval on top of *[STAR](https://fb.workplace.com/groups/228479108798071/permalink/1378998653746105/)* , customized Text Embedding and Engagement based **RAG** with agentic evaluation, and *[Threads Feed User-to-Media (U2M) retrieval](https://fb.workplace.com/groups/2391483437696577/permalink/3280967962081449/)* model for personalization.  
>
> This is also first Model Launched powered by ST Prime. 
> #

#### [# Welcome Sankaet Cheemalamarri to MRS Core Modeling SilverTorch Team!](https://fb.workplace.com/groups/206665645550478/permalink/976733591877009/)
_2026-06-02 · MRS Social_

> # Welcome Sankaet Cheemalamarri to MRS Core Modeling SilverTorch Team!
>
> Please join me welcome Sankaet to SilverTorch Foundation team!
>
> Sankaet is a returning intern and join us from Georgia Tech after graduation in May,  He will be based on MPK and will working on the ST Publish area as he ramping up.
>
> Here are his own words:
>
> *"Hi, my name is Sankaet and I am super excited to join the team! I am from Stockholm, Sweden and did my BSMS from Georgia Tech and graduated this May. I interned at Meta last summer based out of Bellevue and am super happy to be back at the company. I am looking forward to get to know and work with all of you!"*
>
> Welcome to the team Sankaet!

#### [# Discussion Post | [[SEV2] S662569: m2133379243 (facebook_reels_udd_hstu_expert, tier 1, 1.3M qps) -- up to 100% global error rate, region-](https://fb.workplace.com/groups/816959721216296/permalink/975655502013383/)
_2026-05-22 · MRS Main SEV Review_ · refs: S662569

> # Discussion Post | [[SEV2] S662569: m2133379243 (facebook_reels_udd_hstu_expert, tier 1, 1.3M qps) -- up to 100% global error rate, region-by-region](https://www.internalfb.com/sevreview/present?review_id=823176990484434&review_item_id=829419919860141)
> ## Review Agenda: [[May 28 2026] MRS Main SEV Review](https://www.internalfb.com/sevreview/present?review_id=823176990484434)
>
> __Please ask your questions in the comments below__
>
> Presenter: Aditya Priyadarshi
> Champion: Xinyao Hu
> Required attendees: Bandish Chheda
> Optional attendees: Anthony Foiani
>
> ## SEV Manager: [S662569](https://www.internalfb.com/sevmanager/view/662569)
> __Stack__: Production
> __Status__: MITIGATED
> __Time created__: Mon May 11, 2026 22:16 PDT
> __Incident Impact__: Metric Impact
> No error rate increases but occasional model crashes on m2133379243
> Production model m2133379243 (facebook_reels_udd_hstu_expert OT) experienced:
> 0-5% error rate / fallback for (2026/05/08 10:20pm  - 2026/05/11 7:15am)
> ~10% error rate / fallback for ~2 hours (2026/05/11 9:00pm - 2026/05/11 11:15pm)
> 100% error rate / fallback for ~4 hours (2026/05/11 11:15pm– 2026/05/12 4:15am)
> Due to crashes on predictor
> User Experience
> Users on fb_shorts and Reels VDD surfaces experienced degraded ranking quality due to model fallback
> Ranking fell back to non-personalized or degraded models during the ~3.5-hour incident window
> __Impacted Areas__: Inference, FB Reels, SIGRID Predictor, Video Ranking Platform
> __Root Cause Areas__: RaaS
> __Overview__: Overview
> 2026/05/05 5:00pm - RIS infra QE tier ramps up in VLL, 1% of traffic regionally
> 2026/05/08 12:00am - RIS infra QE global rollout complete across all remaining regions, 1% of traffic globally
> Saw sporadic crashes due to 2-task predictor routing
> 2026/05/11 ~08:00am-4:00pm - 2-task predictor cap disabled.
> 2026/05/11 ~11:00am - RIS infra QE disabled for FB shorts to "rule out" RIS as the source of crashes
> 2026/05/11 ~2:00pm - RIS infra QE re-enabled for FB shorts
> 2026/05/11 9:00pm - Crashes start
>
> Learnings
> Key Discussion Points
> Predictor shard 0 routing works and should be leveraged for high risk rollouts
> Errors that are input driven should be validated for a long time before ruling out causes
> In this case the bad inputs were essentially 0% of RIS traffic from ~7:00am to ~9:00pm
> We ran a single region canary for vll for ~2 days with 0 bad requests logged
> There are 3 different people who own different part of this logic
> Someone initially wrote the code to enable this in RaaS
> Another …[truncated]

### ziqiliu (Ziqi Liu, trust 3) — 0 OT-relevant posts in 30d

### dkotfis (Dave Kotfis, trust 3) — 7 posts · IG OT POC

#### [## Oncall Summary for IG Training Prod: 02 Jun - 09 Jun](https://fb.workplace.com/groups/3367638473354337/permalink/27024632580561594/)
_2026-06-11 · IG Relevance Oncall_ · refs: D102017103, S662798, S668980, S669019, S670229, S671908

> ## Oncall Summary for IG Training Prod: 02 Jun - 09 Jun
>
> Next oncall → Pushpak Raj Gautam
>
> ### Items in Summary
>
> No items
> [See more in Oncall Hub](https://www.internalfb.com/omh/view/ig_training_job_infra/shift_summary?report=2485351281911462)
>
> # **Overview**
>
> [Temporary Mitigation] S669019 - Reels LSR MB9 OOM - memory leak triggered by python 3.10->3.12 upgrade in MVAI. Verified safe rollback by patching to multiple QE arms run over the weekend. Will unblock launch but needs continued investigation to resolve 3.12 issues (3.10 removed from fbsource).  
> [Temporary Mitigation] S668980 - Reels ESR MB7 has delta publish / streaming slowness. Both H100 and GB200. Impacted training QPS, mitigated by increasing sparse publishing interval 6->10 minutes, but this will regress freshness and must be mitigated before launch.  
> S662798 Feed LSR MB8 QEs have slow QPS warm up. Prod refresh and combo 1 are fast warmup, determined that regression is introduced by change in proposals contained in combo 2.5. Ablated the individual proposals but did not see significant differences in ramp up. Added instrumentation to profile training warmup, slowness appeared in check\_publish\_failure, so tested with removal of [D102017103](https://www.internalfb.com/diff/D102017103) (added from previous MB8 SEV mitigation) and slowness was still present but moved to main training update stage. Continuing to improve instrumentation to investigate further.  
> [Mitigated] S670229 - Stories ESR holdout model used silvertorch package too old for DPP, mitigated by updating ST publishing job by 60 days (small enough change to maintain training job compatibility)  
> [Mitigated] S671908 - Feed LSR SUMv2 prod bulk model had long wait time due to data availability (24 hour replication SLO). Job is on high priority tenant and alerts when not scheduled within 3 hours.  
>
> **Comment**:   
> **How difficult was your shift? 1-5 (1 - Easy/Lightweight/Relaxed, 5 - Difficult/Busy/Stressful)**  
> 3  
>
> **What contributed to the difficulty of your shift?**  
> SEVs/Firefighting Noisy alerts

#### [# Feed LSR - QPS Cap and Data Upsampling](https://fb.workplace.com/groups/441319728374485/permalink/1024922460014206/)
_2026-06-10 · IG Feed Relevance Experiment Reviews_ · refs: S659917

> # Feed LSR - QPS Cap and Data Upsampling
>
> **IG:** Dave Kotfis Justin Lin Pushpak Raj Gautam Sophia Jiang Zichun Zhang Radhika Kulkarni Josie Gao Bingjun Sun William Pei Yun Mao
>
> **MRS:** Nikita Loginov
>
> ## Motivation
>
> This proposal will address improvements to the current production Feed LSR model in both freshness and data loss.
>
> Freshness:
> * Current OT model has [2 hour sparse latency](https://ig-data-apps.internalmeta.com/ig/relevance-foundations/online-training-slo/model-performance#feed-mtml-latency-slo) driven by high training example age, above our 10 minute SLO required to hit our H1 freshness goals.
> * Root cause is insufficient training QPS given the current peak data rate - Introduced by MB7 which increased the previous 5 minute scribe lookback window to 2 hours to reduce data loss during peak.
> * This proposal will address [S659917](https://www.internalfb.com/intern/sevmanager/view/s/659917) which has been open for 2 months.
>
> Data Loss:
>
> This proposal will leverage recovered [training data loss](https://fb.workplace.com/groups/233247545227463/permalink/1381149477103925/) from the following sources:
> * Scribe quota restoration
> * Non-vpvd data recovery
>
> ## technical details
>
> **QPS Cap **
>
> To address freshness, we enable the [MaxQPS](https://fb.workplace.com/groups/892580671575274/permalink/2085986925567970/) cap technique that will downsample training data in OT when the data rate exceeds a defined limit. This will ensure freshness is bound by appropriately setting the QPS cap limit based upon the max sustained training QPS of OT.
>
> For the current prod Feed LSR OT, we observe this max training QPS to be 330k. This is applied by updating the ScribeDataSourceConfig in the OT trainer config for the model. This value will need to continue to be set for future LSR launches based on the latest updates to peak training QPS.
>
> **Upsample Data**
>
> As this proposal is now reducing training data during peak traffic through sampling, we couple it together with the upsample data partition to achieve the net effect of off-peak upsampling. During off-peak, the data QPS is under the QPS cap limit and we experience data starvation and opportunity for training to leverage more data. We enable the additional training data source by adding the ig_feed_ifr_upsample logging source to the scribe partition filter in the model's run config.
>
> The QPS cap is applied pre-filtering, so the value that is set is based on the raw scribe data rate, not the data rate received by the t …[truncated]

#### [# OT Reliability - Weekly Status 6/8](https://fb.workplace.com/groups/1676744619923718/permalink/2063145464616963/)
_2026-06-08 · IG Relevance Reliability Working Group_ · refs: S656663, S659917, S662798, S665478, S667222, S668980, S669019

> # OT Reliability - Weekly Status 6/8
>
> Through ongoing launches, we have closed out 2/3 open risks to meeting our H1 goal with no new regressions this week. Our main open risk is Feed LSR sparse latency, which is moving forward with a new MB8-based QE. Beyond the H1 SLO goal, we continue making progress on major SEVs which may block upcoming launches due to OT health.
>
> ## progress
> * Reels ESR MB6.5 launched 6/5, and see sparse latency trending upwards at 32.1% success rate. We expect to see 95% SLO hit next week.
> * [S656663](https://www.internalfb.com/intern/sevmanager/view/s/656663) Reels CS Omni Retrieval Example Age - [MB5.1 launch](https://fb.workplace.com/groups/586002598779789/permalink/1923337671712935/) expected today which will improve QPS and close the SEV.
> * Reels StarSearch Omni Retrieval - small regression in Item Latency improved w/w (70.8%->81.5%). Initial launch with ST job running on A100 hosts, QPS stablization has been happening since pinning to H100 training hosts. Continuing to monitor.
>
> ## pending launches
> * Feed T2I Retrieval - Item Latency + Success Rate Pending Item Streaming Launch
> * Mixed IFR U2I Combined - Item Latency Pending Decoupled Full Snapshot / Item Streaming Launch Shuguang Ye
>
> ## risks
> * [S659917](https://www.internalfb.com/intern/sevmanager/view/s/659917) - Feed LSR - Sparse Latency at 19.6% - Justin Lin launched additional QE based on MB8 LC including 2 candidates that address training example age:
>    * Upsample Data + QPS Cap at 330k (previously demonstrated TS wins on prod/MB7)
>    * Upsample Data + 10% Negative Downsample + QPS Cap at 418k
>
> ## active sevs
> * [S669019](https://www.internalfb.com/intern/sevmanager/view/s/669019) - Reels LSR MB9 OT OOMs
>    * Python 3.10 -> Python 3.12 identified as the source of memory leak regression in recent base layers
>    * Testing Python 3.10 revert across multiple arms to de-risk
>    * Continuing to investigate and identify fix for python 3.12, which will become a blocker for future launches
> * [S667222](https://www.internalfb.com/intern/sevmanager/view/s/667222) - Feed LSR MB8 QEs with Low Streaming Success
>    * Most arms now healthy
>    * 3 arms at 85-95% success due to low streaming threads per channel, Gufan Yin is addressing memory pressure with table offloading to increase threads
> * [S665478](https://www.internalfb.com/intern/sevmanager/view/s/665478) - Reels LSR MB9 OT Jobs Hanging
>    * Mitigated via base layer patch
> * [S662798](https://l.workplace.com/l.php?u=https%3A%2F%2Fww …[truncated]

#### [# OT Reliability - Weekly Status 6/2](https://fb.workplace.com/groups/1676744619923718/permalink/2057653955166114/)
_2026-06-02 · IG Relevance Reliability Working Group_ · refs: S651765, S656663, S659917, S662798, S665478, S667222, S668980, S669019

> # OT Reliability - Weekly Status 6/2
>
> This week has had progress on all fronts, with sparse streaming success passing SLO on all models for the first time in the same week. We've burned down the most significant risk for Feed LSR's example age issues by demonstrating the viability of the QPS cap approach, but the risk is still high that it will converge with MB8 LC and land before code freeze.
>
> ## progress
> 1. Reels StarSearch Omni Retrieval - MB5 Launched with Weight Manager on 5/27 and sparse streaming success has since increased ~62->100%
> 2. Reels VM ESR - Launch Candidate w/ Weight Manager [under review](https://docs.google.com/presentation/d/1ulUSJo_aNc87TAY_XxvYh1_2le4Ao1wW9VjdwGUSwQI/edit?slide=id.g13524e59445_0_1280#slide=id.g13524e59445_0_1280). Kang Du
> 3. [S656663](https://www.internalfb.com/intern/sevmanager/view/s/656663) Reels CS Omni Retrieval Example Age XuZhe (XZ) Zhang
>    1. Promising 5d results for QE on MB6 LC, launch expected 6/5. Decided not to increase training hosts in the meantime as this introduces measurement risk that could block MB6 launch.
>    2. Ran an experiment back-porting logging optimizations to prod, but improvement was smaller than expected.
>
> ## pending launches
> * Feed T2I Retrieval - Item Latency + Success Rate Pending Item Streaming Launch
> * Mixed IFR U2I Combined - Item Latency Pending Decoupled Full Snapshot / Item Streaming Launch Shuguang Ye
>
> ## risks
> 1. [S659917](https://www.internalfb.com/intern/sevmanager/view/s/659917) - Feed LSR - Sparse Latency at 54.2% - **must be resolved to meet our freshness SLO goal for H1. **Justin Lin Dave Kotfis
>    1. QE Results from two models that mitigate freshness SLO violation without capacity regression:
>       1. 5 minute scribe lookback - most metrics neutral
>       2. QPS Cap + Upsample Data - **positive TS metrics**, regression on comments
>    2. Reviewing QPS Cap + Upsample Data candidate this week, but MB8 launch review is ongoing.
>       3. If we choose to launch MB8 this week, it will replace the QPS Cap launch and regress the SLO again. Kicking off an MB8-based QE to rebase this work on the new launch candidate. Risk that it may not be ready before code freeze.
>       4. If MB8 is not launched, we may launch the current proposal as is and close the SEV.
> 2. Reels ESR - Sparse Latency at 0.0% - **must be resolved to meet our freshness SLO goal for H1. **Yiming Sun Yiming Liao
>    3. [S651765](https://www.internalfb.com/intern/sevmanager/view/s/651765) has been closed
>    4. MB6.5 …[truncated]

#### [# Examining the Operational Efficiency Impact of OT Reliability](https://fb.workplace.com/groups/256795070510485/permalink/965909769599008/)
_2026-06-01 · IG Relevance GPU Efficiency Working Group_ · refs: S616501, S628346, S651642, S654235, S654768, S665478, S668980, S669019

> # Examining the Operational Efficiency Impact of OT Reliability
>
> To drive freshness and catch up with competitors, OT is being used more broadly in our fleet in H1 spanning more than 12 models across Reels and Feed. Once onboarded to OT, a significant amount of training capacity available for development of these models is dedicated to OT to drive QEs.
>
> We've experienced numerous SEVs in H1 affecting OT QEs that have slowed down MB cycles across multiple models ([S616501](https://www.internalfb.com/intern/sevmanager/view/s/616501), [S628346](https://www.internalfb.com/intern/sevmanager/view/s/628346), [S654768](https://www.internalfb.com/intern/sevmanager/view/s/654768), [S654235](https://www.internalfb.com/intern/sevmanager/view/s/654235), [S651642](https://www.internalfb.com/intern/sevmanager/view/s/651642), [S669019](https://www.internalfb.com/sevmanager/view/669019), [S665478](https://www.internalfb.com/google_autolink/S665478), [S668980](https://www.internalfb.com/intern/sevmanager/view/s/668980)). Beyond the dev velocity impact of these SEVs, this post attempts to quantify the efficiency cost to our training GPU fleet of this broader class of OT Reliability issues affecting models in QE.
>
> # Methodology
>
> The primary value of using OT for development is to drive QEs and measure topline metrics that cannot be measured with offline training. NE can be measured more cost-effectively via offline runs. The assumption made is that OT is always providing meaningful value when it is updating a model that is serving downstream QE traffic. We will focus **only on the non-serving time**, making the assumption that during serving OT is sufficiently reliable to produce useful QE results. When determining whether a model is serving, we check not only the model but any downstream ST model.
>
> While all non-serving time is a form on inefficiency, not all of it is attributable to OT Reliability. There is overhead where models are warming up and converging on NE before QE is started. So we will focus on cases where we consider OT to be in an **unhealthy state** - we've defined this as days where we experience at least 3 OT failures (app/infra failures, not pre-emption or manual stopping) per day. During these times, we assume that while OT may be active and producing seemingly useful work, the frequent failures are likely to be blockers to starting QE that are actively being debugged. 
>
> This may be a conservative measurement, as it does not include other forms of OT unhea …[truncated]

#### [# OT Reliability - Weekly Status 5/26](https://fb.workplace.com/groups/1676744619923718/permalink/2051317135799796/)
_2026-05-26 · IG Relevance Reliability Working Group_ · refs: D105840367, S651765, S656663, S659917, S664657

> # OT Reliability - Weekly Status 5/26
>
> Since last week, we've recovered our SLO health for **Feed U2I Retrieval Sparse Latency** and **Reels StarSearch T2I Sparse Streaming Success**, with no new SLO regressions. 
>
> This week's post will keep the previous format and focus on status towards directly attaining the SLO for all prod OT models for H1, but future updates will be expanded to include additional defensive workstreams and OT SEVs beyond prod models.
>
> ## progress
> 1. [S664657](https://www.internalfb.com/sevmanager/view/664657) - Mixed IFR U2I Combined - Sparse Latency 84.7->100%. Validated that A100->H100 training host change is sufficient to remove daily example age peaks and closed the SEV. Xin Wu Tony Ivchenko
> 2. Reels StarSearch T2I - Sparse Streaming Success 59.0->100%. Confirmed available CPU memory headroom on inference hosts and [increased streaming client buffer size 10GB->40GB](https://www.internalfb.com/diff/D105840367). Hongbo Qin Calvin Sanghera
> 3. [S656663](https://www.internalfb.com/intern/sevmanager/view/s/656663) - Reels CS Omni Retrieval - Sparse Latency at 75%. This week will revisit MB6 launch timeline to decide whether an accelerated mitigation via training capacity increase is needed. XuZhe (XZ) Zhang Yang Lu
>
> ## pending launches
> 1. Feed T2I Retrieval - Item Latency + Success Rate Pending Item Streaming Launch
> 2. Mixed IFR U2I Combined - Item Latency Pending Decoupled Full Snapshot / Item Streaming Launch Shuguang Ye
> 3. Reels SS Omni Retrieval - Streaming Success Pending Weight Manager Launch on MB5 Jack Zhao
> 4. Reels VM ESR - Sparse Latency + Streaming Success Pending Sparse Streaming Launch Kang Du
>
> ## risks
> 1. [S659917](https://www.internalfb.com/intern/sevmanager/view/s/659917) - Feed LSR - Sparse Latency at 20.8%
>    1. [QE is ongoing](https://www.internalfb.com/intern/qe2/ig_one_feed_model_universe/ig_one_feed_2026_mb7_freshness_v0/setup/config) with nearly 2 weeks of data, to make launch decision this week
>    2. Next step - incorporate change into MB8 LC
> 2. Reels ESR - Sparse Latency at 0.0% (further regression)
>    3. [S651765](https://www.internalfb.com/sevmanager/view/651765) - MB6.5 not yet launched Yiming Sun Yiming Liao
>    4. Resolving QPS cap and streaming setting issues for launch Xinyuan Zhang Pushpak Raj Gautam
>    5. May need to increase back 15->18 H100 training hosts on the prod job if further delays
>
> Arun Singh Radhika Kulkarni Guangdeng Liao Yun Mao Richard Huang Brian Banbrook Haoxun Luo William Pei Bingjun Sun …[truncated]

#### [# OT Reliability - Weekly Status 5/18](https://fb.workplace.com/groups/1676744619923718/permalink/2044577953140381/)
_2026-05-18 · IG Relevance Reliability Working Group_ · refs: S621928, S651765, S656663, S659917, S662001, S664657

> # OT Reliability - Weekly Status 5/18
>
> We'll be sharing weekly updates for progress and risks towards our OT SLO Goal through the end of H1. As a reminder, our target is to achieve 95% hours/week meeting these thresholds:
> * Latency (Sparse + Item) < 10 minutes across (training) example age and (inference) model age.
> * Streaming Success Rate (Sparse + Item) > 99% successfully applied updates
>
> You can track the latest status of all metrics on the [SLO dashboard](https://ig-data-apps.internalmeta.com/ig/relevance-foundations/online-training-slo).
>
> ## progress
> 1. [S656663](https://www.internalfb.com/sevmanager/view/656663): Reels CS Omni Retrieval - Sparse Latency at 79.2% 
>    1. Root Cause: Training QPS Regression on MB5 Launch
>    2. Current [LC](https://fburl.com/canvas/w2xytonq) for MB6 in QE will mitigate via efficiency wins.
>    3. Will revisit launch schedule week of 5/25 to make decision on whether to accelerate mitigation via trainer increase. Yang Lu
> 2. [S664657](https://www.internalfb.com/sevmanager/view/664657) - Mixed IFR U2I Combined - Sparse Latency at 84.7%
>    4. Root Cause: Training QPS Regression on [MB2 Launch](https://fb.workplace.com/groups/353618119088178/permalink/1641763260273651/)
>    5. Mitigated via training capacity increase (4xA100 -> 4xH100)
>    6. We have observed example age peaks recovering and expect the SEV to be closed by 5/19
> 3. [S662001](https://www.internalfb.com/intern/sevmanager/view/s/662001) - Sparse Latency spike on Feed T2I Retrieval
>    7. Discovered issue in dashboard calculation for bad_sparse fallback calculation using average instead of p50 full snapshot age - triggered by p99 full snapshot increases.
>    8. Josef Cohen backfilled correction across models to 4/22, resulted in significant improvements in sparse latency across Feed T2i, Feed ESR, Feed ESR SMSL, and Reels LSR
> ## 
> pending launches
> 1. Feed T2I Retrieval - Item Latency + Success Rate Pending Item Streaming Launch
> 2. Mixed IFR U2I Combined - Item Latency Pending Decoupled Full Snapshot / Item Streaming Launch Shuguang Ye
> 3. Reels SS Omni Retrieval - Sparse Streaming Success at 54.9%, pending launch of [Weight Manager on MB5](https://docs.google.com/document/d/1T0eNXvTbOUrb4J4GVKYsZoUjkSZeIcEMM0ukYwoE3x0/edit?tab=t.0#bookmark=kix.vpfcolabycd9) Jack Zhao
> 4. Reels VM ESR - Sparse Latency + Streaming Success pending parse streaming launch Kang Du
> ## risks
> 1. [S659917](https://www.internalfb.com/sevmanager/view/659917) - Feed LSR - Sparse Latency at 30.6%
>    1. …[truncated]

### prgzz (Pushpak Raj Gautam, trust 3) — 7 posts · IG OT POC

#### [# [Press Release] Online Training with Dynamic Resizing](https://fb.workplace.com/groups/710550224249570/permalink/1373980641239855/)
_2026-06-10 · Online Training and Recurring Training User FYI_

> # [Press Release] Online Training with Dynamic Resizing 
> ## TL;DR
>
> Online Training (OT) jobs are sized for peak incoming data, so they waste GPUs during the many hours each day when traffic sits below peak. Dynamic Resizing solves this: it automatically switches an OT job between tuned presets (varying trainer counts and EMO memory settings) as traffic rises and falls — scaling up ahead of the daily peak and back down afterward.
>
> The result is an estimated **10–45% GPU** savings on benchmarked models, with NE, QPS, data age, and model freshness all on par with baseline,** ~6 min of training downtime **per switch (≈2 switches/day), and no data loss. No changes to model architecture, training data, or your existing launch flow.
>
> Dynamic Resizing is production-ready and rolling out model-by-model. To onboard, see How to Onboard ([#how-to-onboard](https://docs.google.com/document/d/13kTNgHPX7aN8htw8IpnH9NClJbL-nLO0RIWnAR1J0T4/edit?kh_source=GDOCS&tab=t.da78qqqs9229#bookmark=id.o7geq08zdh2k)). [[design doc](https://www.internalfb.com/intern/px/p/9x2Jj/)]
>
> ## What is Dynamic Resizing ? 
>
> **The problem**. An OT job must keep pace with the maximum incoming data rate to meet its SLO, so it is provisioned for peak QPS around the clock. Live traffic, however, fluctuates throughout the day, leaving the extra GPUs underutilized during off-peak hours.
>
>
>
>
> **The solution** — variable trainers via presets. A preset is a job configuration (trainer count plus memory settings such as [EMO](https://www.internalfb.com/wiki/Embedding_Offloading/)) known to sustain a given QPS. Presets are generated offline by our auto-tuning pipeline ([AxSweep](https://www.internalfb.com/wiki/AE/AxSweep/)) and are numerically equivalent: switching presets changes how many GPUs the job uses and how EMO manages memory across HBM and host memory — not what the model learns. Based on the traffic pattern either 1 / 2 presets may be generated.  (1 preset means a simple static tuning is recommended, 2 presets means dynamic resize is recommended.)
>
> **How dynamic resize happens**. TMS schedules roughly two resizes per day — scaling up ahead of the daily peak, back down afterward. Each switch is a single atomic MAST in-place restart that applies the new trainer count and re-specs the Tupperware (TW) job in one step, orchestrated by the TMS reconciler/switcher and the TLS launcher.
>
>
> ## Why does it matter for OT ? 
> | Win | Detail |
> | --- | --- |
> | **GPU efficiency** | 10~45% estimated GPU savings. |
> | …[truncated]

#### [## Oncall Summary for IG Training Health: 01 Jun - 08 Jun](https://fb.workplace.com/groups/3367638473354337/permalink/26984078227950363/)
_2026-06-08 · IG Relevance Oncall_ · refs: D105319509, D105319531, D107152023, S665674, T273810444

> ## Oncall Summary for IG Training Health: 01 Jun - 08 Jun
>
> Next oncall → Shardul Kothapalli
>
> - **S665674**: IG/Threads Online/Offline quota split ongoing. Phase 1 completed. In [Phase 2 (this week)](https://fb.workplace.com/groups/training.ig/permalink/1896127304414495/), we will cover Reels and Feed, and that's the last phase.
> - **GB200 delivery**: 461 MACHINE\_TYPE\_T20\_CIC\_GB200\_186GB\_HBM3E\_NVLSO\_DSF\_HPs delivered and mostly donated to Reels ESR, by Gary Huang.
> - **ZippyDB alerts are firing too much (noisy)** for our sequence storage tier.
>     - Alerts:
>         - https://fburl.com/monitoring/0lj5xw05
>         - https://fburl.com/monitoring/66u81yth
>     - They are generally not actionable (like finding jobs to kill) as they clear up within the day
>     - Parichay Kapoor mentioned that a lot more headroom has been created on this tier, so this is likely a false positive. Need to follow up with ZippyDB oncall.
> - **Pending TUO diffs**
>     - [D105319531](https://www.internalfb.com/diff/D105319531) - Pinged owner
>     - [D105319509](https://www.internalfb.com/diff/D105319509) - TODO: followup (cc: Shardul Kothapalli)
> - [**T273810444**](https://www.internalfb.com/T273810444): A SEV followup task to ensure QE/prod OT jobs are not preempted
>     - Explained how to do this correctly in task comments
> - **Followups needed on our alerting**:
>     - [DONE] **Change in MINOR and below alert escalation**: Not logging to our oncall chat anymore, as it created noise
>     - [IN PROGRESS] Per-PG alerting for this alert -https://www.internalfb.com/monitoring/detector/918523016850096
>         - Shardul wrote [D107152023](https://www.internalfb.com/diff/D107152023). In review and need to sync with PG capacity admins.
>     - [PLANNED] Change this [MLGK policy ](https://www.internalfb.com/code/fbsource/fbcode/admarket/ml_gatekeeper/mlgk_policies/ml_training_workload_policies/product_groups/instagram/quota_check/quota_check_policy.py)to allow some buffer over quota for recurring training tenants
>         - POC: Me
>     - Scribe/DPP over-quota alerting per model type
>         - POC: Ferris Li

#### [# Phase 2 of Online/Offline Training GPU Split: Reels and Feed](https://fb.workplace.com/groups/training.ig/permalink/1896127304414495/)
_2026-06-08 · IG Training FYI_ · refs: S665674

> # Phase 2 of Online/Offline Training GPU Split: Reels and Feed
>
> As announced in the Phase 1 [post](https://fb.workplace.com/groups/training.ig/permalink/1874785149882044/), **IG and Threads are explicitly splitting GPU quotas into offline and online types for each hardware type**. For example, from here on, there will be T20_GRAND_TETON and T20_GRAND_TETON_ONLINE. To gather more context, please read the original [post](https://fb.workplace.com/groups/training.ig/permalink/1874785149882044/). Note that this does not mean that model owners need to start explicitly setting this in their model configs today. MAST will just auto-figure that based on job type being online or otherwise.
>
> In Phase 1, we have finished this migration for Threads, Explore, Stories, Search, Infra. In Phase 2, we are covering the remaining L3s, and the heavyweights - **Reels and Feed**. After Phase 2 the split will be 100% complete. The work is being tracked in [S665674](https://www.internalfb.com/sevmanager/view/665674).
>
> So here’s how it looks for the Reels and Feed leaf tenants ([dashboard to track OT cost](https://ot-cost-dashboard.internalmeta.com/ot-cost)):
>
> **Reels **cc: Andrew Ton, Nathan Berrebbi, Yiwei Shen, Qi Yang
>
> Raise any disputes [here](https://docs.google.com/spreadsheets/d/1Rce40902gjD7gY4x0j9ltpe8W_-VEDFXSc5oS1rPUCY/edit?gid=268904567#gid=268904567)
> | **Tenant Path** | **GPU Type** | **Current Quota (GPUs)** | **Required OT Quota (p90 GPUs)** |
> | --- | --- | --- | --- |
> | root/Instagram/reels/lige/reels_lige_mb_online | T20_GTV1_5_B200_180GB_HBM3E_DSF | 480 | 378 |
> | root/Instagram/reels/ranking_esr/reels_core_modeling_esr_dedicated | T20_GRAND_TETON | 1136 | 117 |
> | root/Instagram/reels/ranking_esr/reels_core_modeling_esr_offline_mb | T20_GRAND_TETON | 552 | 142 |
> | root/Instagram/reels/ranking_esr/reels_core_modeling_esr_online_dedicated | T20_GRAND_TETON | 2976 | 3308 (capped at 2976) |
> | root/Instagram/reels/ranking_esr/reels_core_modeling_esr_online_dedicated | T20_CIC_GB200_186GB_HBM3E_NVLSO_DSF_HP | 0 | 567 (capped at 0) |
> | root/Instagram/reels/ranking_esr/reels_core_modeling_esr_online_launched | T20_GRAND_TETON | 272 | 272 |
> | root/Instagram/reels/ranking_esr/reels_core_modeling_esr_online_shared | T20_GRAND_TETON | 360 | 360 |
> | root/Instagram/reels/ranking_esr/reels_core_modeling_esr_shared | T20_GRAND_TETON | 264 | 116 |
> | root/Instagram/reels/ranking_lsr/reels_core_modeling_lsr_dedicated | T20_GTV1_5_B200_180GB_HBM3E_DSF | 960 | 84 |
> | root/Instagram/re …[truncated]

#### [# [[Jun 02 2026] IG Relevance Reading SEV Review](https://www.internalfb.com/sevreview/present?review_id=1697108311467610)](https://fb.workplace.com/groups/3367638473354337/permalink/26907039252320928/)
_2026-06-02 · IG Relevance Oncall_ · refs: S650418, S660091, S662738, S663230, S663354, S664373, S664498, S664562, S664657, S664997, S665345, S665766

> # [[Jun 02 2026] IG Relevance Reading SEV Review](https://www.internalfb.com/sevreview/present?review_id=1697108311467610)
>
> ## Scheduled by Pushpak Raj Gautam for [Jun 02 2026] IG Relevance Reading SEV Review review on Tue Jun 2, 2026 16:00 EDT
>
> ---
> ## Discussion order
> - **[[SEV3] S664997](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731854564659651): FSR drop due to laser request pileup using all available memory on open bar ig_esr_clips**
>     - Presenter: Kevin Yang
>     - Champion: Brian Banbrook
>     - Required attendees: 
>     - Optional attendees: Hans Li
> - **[[SEV3] S665345](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731854561326318): ig_clips prod fragment package over 4 hours old**
>     - Presenter: Stephen Fink
>     - Champion: Guangdeng Liao
>     - Required attendees: 
>     - Optional attendees: 
> - **[[SEV3] S662738](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731854571326317): [Feed][LSR][MB8] INPLACE_UPDATE_CONVERGENCE_ERROR**
>     - Presenter: Tony Ivchenko
>     - Champion: Lan Gao
>     - Required attendees: 
>     - Optional attendees: 
> - **[[SEV3] S664657](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731854567992984): Feed U2I Prod OT Daily Example Age Peaks Over 40 min**
>     - Presenter: Tony Ivchenko
>     - Champion: Lan Gao
>     - Required attendees: 
>     - Optional attendees: Dave Kotfis
> - **[[SEV3] S664498](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731854554659652): Intermittent PSR drops due to filter filtering out all media**
>     - Presenter: Hans Li
>     - Champion: William Pei
>     - Required attendees: 
>     - Optional attendees: Igor Afonov
> - **[[SEV3] S664373](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731854557992985): [ig_rec_consumption] Clips PSR dropped due to LSR QE**
>     - Presenter: Hans Li
>     - Champion: William Pei
>     - Required attendees: 
>     - Optional attendees: 
> - **[[SEV3] S663230](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731859334659174): Model 2131444573 inference latency**
>     - Presenter: Junchao Zheng
>     - Champion: Gedi Zhou
>     - Required attendees: 
>     - Optional attendees: 
> - **[[SEV3] S663354](https://www.internalfb.com/sevreview/present?review_id=1697108311467610&review_item_id=1731859331325841): Feed FSR dr …[truncated]

#### [# User's business account is blocked and I have no idea how to report an issue](https://fb.workplace.com/groups/accessxfn/permalink/31860001013621776/)
_2026-05-22 · User Account Access - Questions & Feedback (not Ad Accounts or Biz Manager)_

> # User's business account is blocked and I have no idea how to report an issue
>
> Hi,
>
> I asked Metamate on how to escalate an incorrect business account block on my friend's IG account.
>
> First suggestion was the OOPS form. That requires an SRT. My friend reported an issue through the IG app, but I don't know where to get an SRT from that.
>
> Second suggestion was to try this form - [https://www.intern.facebook.com/help/contact/598898936886928](https://www.intern.facebook.com/help/contact/598898936886928). It is deprecated and the form it redirects to wouldn't open.
>
> My friend also tried the Meta AI assistant in Accounts center. That didn't help either. Kept going in circles.
>
> Now I'm trying this 4th approach (posting to this group) and hope this works.
>
> What should I do?
>
> Thanks!

#### [# Should QE models also get snapshot delay alerts from Centralized Alerting Framework?](https://fb.workplace.com/groups/1250930069637151/permalink/2174828927247256/)
_2026-05-21 · IG Training Discussions_ · refs: S635499

> # Should QE models also get snapshot delay alerts from Centralized Alerting Framework?
>
> A followup of [S635499](https://www.internalfb.com/sevmanager/view/635499) is to see why the detection was insufficient. We have snapshot delay alerts like these - [https://fburl.com/monitoring/c8oqu8fb](https://fburl.com/monitoring/c8oqu8fb), which should have fired if our prod models were impacted by the SEV.
> Some of the models that were reported to be impacted were QE models, [example](https://www.internalfb.com/sevmanager/view/635499?commentID=969714695711204).
> So my question is whether QE models should have these delay alerts.
>
> cc: Pei Zhang, Brian Banbrook

#### [# Why is there such a big discrepancy between gpu_dyno_stats and Pytorch Memory Visualizer?](https://fb.workplace.com/groups/2039331519542045/permalink/3926671477474697/)
_2026-05-19 · AI Training Investigations_

> # Why is there such a big discrepancy between gpu_dyno_stats and Pytorch Memory Visualizer?
>
> I'm looking at this job - [mvai-training-online-2130305053](https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-2130305053?version=14&env=PRODUCTION)
> Its mem snapshots are here - [https://fburl.com/ai_infra/7oba01z9](https://fburl.com/ai_infra/7oba01z9)
>
> And peak gpu mem util as per gpu_dyno_stats is here - [https://fburl.com/scuba/gpu_dyno_stats/wt5jikuq](https://fburl.com/scuba/gpu_dyno_stats/wt5jikuq)
>
> There's a big discrepancy. [Former](https://www.internalfb.com/pytorch_memory_visualizer/mvai_gpu_traces/tree/gpu_snapshot/mvai-training-online-2130305053/1/rank-0_itrn-3.May_18_18_31_12.6101.snapshot.pickle) thinks peak usage is less than 30 GiB HBM.
>
>
>
> While latter (gpu_dyno_stats) puts it at 82 GiB+.
>
> I'm wondering why. Is the training job bottlenecked on mem or not?
>
> Thanks!

### peiyangy (Peiyang Yu, trust 3) — 0 OT-relevant posts in 30d

