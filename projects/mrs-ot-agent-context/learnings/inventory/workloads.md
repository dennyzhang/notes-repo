# OT Prod Workload Inventory

_Seeded 2026-05-20 thread `pjTRT7ubzUs` from models surfaced in 2026-05-19/20 session triages + historical SEV evidence. Manually seeded 2026-05-20. Update during triage when new models surface._

## Schema

```yaml
- model_id: <numeric>
  model_type: <string from flow_model_type>
  role: trainer | holdout | baseline | stus | retrieval | unknown
  pg: IG | Facebook | Threads | Production | infra-cross-pg | Video | Ads(out-of-scope)
  product: Feed | Reels | Stories | Mixed_IFR | Explore | Search | CFR | IFR | Video | Time-spent | Push | ...
  oncall_modeling: <oncall handle>
  oncall_snapshot: <oncall handle on model.instance entries>
  owner: <unixname>
  mast_job: mvai-training-online-<id>
  runtime: MAST | FBLEARNER_FLOW
  tier: 1 | 2 | 3 | 4 | unknown
  status: active | retired | stuck | preempted | unknown
  current_attempt: <vNN status time>
  notable: <free-form recent history>
```

## Models

### IG / Feed

```yaml
- model_id: 878102693
  model_type: ig_organic_feed_mtml
  role: holdout
  pg: IG
  product: Feed
  oncall_modeling: ig_feed_modeling
  owner: wenkai
  mast_job: mvai-training-online-878102693
  runtime: MAST
  tier: 1
  status: active
  notable: "P58/CL-003 ZippyDB cascade victim 2026-05-19 (S665163); chronic noisy per noisy-trends.md § Alerts (4 alerts/7d)"

- model_id: 2134319967
  model_type: ig_organic_feed_mtml
  role: baseline
  pg: IG
  product: Feed
  oncall_modeling: ig_feed_modeling
  owner: wenkai
  runtime: MAST
  tier: 1
  status: active
  notable: "Paired with m878102693 holdout; identical scribe lag alert during S665163 window"

- model_id: 2130324780
  model_type: ig_textpost_feed_m2m_retrieval
  role: stus
  pg: IG
  product: Feed
  oncall_modeling: p92_relevance_retrieval_oncall
  owner: ronghuang
  mast_job: mvai-training-online-2130324780
  runtime: MAST
  tier: 2
  status: active
  current_attempt: v42 attempt 1 (recovered 2026-05-20 ~07:30 PT after kmeans corpus restore)
  notable: "M-013 STUS kmeans corpus underflow (R-031): T2I corpus 22K→1,315 collapse 2026-05-20 04:00-07:30 PT; A1009946182010606 fired 3× in 3 days before bot recognized PAGE class"

- model_id: 2143737814
  model_type: ig_textpost_push_notification_x_selection
  role: baseline
  pg: IG
  product: Push
  owner: markgluzman
  runtime: MAST
  tier: unknown
  status: active
  notable: "S657071 in progress 21d (since 2026-05-08); snapshot transition pending tasks; flagged 'no update since 2026-05-08' by morning daily-brief"
```

### IG / Reels

```yaml
- model_id: 2132766001
  model_type: ig_reels_tab_mtml
  role: holdout
  pg: IG
  product: Reels
  oncall_modeling: ig_rec_modeling_lsr
  owner: jakubbester
  mast_job: mvai-training-online-2132766001
  runtime: MAST
  tier: unknown
  status: active
  current_attempt: v11 RUNNING since 2026-05-11
  notable: "M-007 / M-016 sub-mechanism: scribe spike + AGG noise. 1 of 5 IG retrieval-family holdouts firing E2E latency alerts 2026-05-19/20"

- model_id: 2144816217
  model_type: ig_reels_tab_ss_omni_retrieval
  role: holdout (sister)
  pg: IG
  product: Reels
  oncall_snapshot: igr_retrieval
  owner: shuyaoli
  runtime: MAST
  tier: unknown
  status: active
  notable: "A1480195820275950 2026-05-16 2h self-resolve; 2nd 2026-05-20 AGG-7; both CL-003 transient. 1 of 5 family today."

- model_id: 2145491885
  model_type: ig_reels_starsearch_t2i_retrieval
  role: (FBLEARNER_FLOW; role ambiguous, alert labeled holdout)
  pg: IG
  product: Reels
  oncall_snapshot: igr_retrieval
  owner: weiz
  runtime: FBLEARNER_FLOW (no MAST job)
  tier: unknown
  status: active (publish blocked)
  notable: "SPARSE_DELTA stopped 2026-05-19 13:58 PDT, ~13h gap by 02:50 next morning. Upstream SEVs S660677 + S659877 + ARM disabled in igml::entrepot_cache_starsearch. ITEM_EMB_DELTA detector misconfig: 0 in 500 history → M-016 false-alarm."

- model_id: 2126189932
  model_type: ig_reels_starsearch_t2i_retrieval
  role: baseline
  pg: IG
  product: Reels
  oncall_snapshot: igr_retrieval
  owner: yjfu
  runtime: MAST
  tier: unknown
  status: active
  notable: "A1201406268614142 [Invalid Detector - No Data] re-fire 2026-05-20 (3-day-old archive); model publishing 2-min cadence; M-016 confirmed"

- model_id: 2132070936
  model_type: facebook_reels_ifu_i2i
  role: trainer (per role inference)
  pg: Facebook  # Reels VDD is FB-side
  product: Video
  owner: zihengq
  runtime: MAST
  tier: 1
  status: stuck
  notable: "S665214: silent checkpoint save failure - retry JK disabled + Manifold throttling. A1186271076863909 MAJOR active 2026-05-20 (missing SPARSE_DELTA + DENSE_DELTA)"

- model_id: 2132537419
  model_type: facebook_reels_ifu_i2i
  role: baseline (reranker)
  pg: Facebook
  product: Video
  owner: zihengq
  runtime: MAST
  tier: 1
  status: stuck
  notable: "A1530150995193297 CRITICAL active for 12 DAYS (since 2026-05-08) missing FULL_SNAPSHOT — bot's `diagnosed_ids` empty: 288 hourly cron runs missed it (default recency window). Highest-leverage discovery from 2026-05-20 session."

- model_id: 2123154171
  model_type: ig_reels_tab_mtml (MB9)
  role: trainer
  pg: IG
  product: Reels
  owner: xingjiama
  runtime: MAST
  tier: unknown
  status: was-stuck (S665478 mitigated path)
  notable: "S665478 + cluster — NCCL collective timeout → elastic agent zombie (M-001 / P-002). Fix-in-flight D105606893 / D105652547 in new light_cli."

- model_id: 2123153585
  model_type: ig_reels_tab_mtml (MB9)
  role: trainer
  pg: IG
  product: Reels
  owner: xingjiama
  runtime: MAST
  tier: unknown
  status: was-stuck
  notable: "Sibling of m2123154171 in S665478"
```

### IG / Stories

```yaml
- model_id: 2145993395
  model_type: ig_stories_tray_esr (streaming)
  role: trainer (streaming model)
  pg: IG
  product: Stories
  owner: arafatm
  runtime: MAST
  tier: unknown
  status: active
  notable: "S665464 — D103046213 NCCL/Gloo mixed-PG dist.barrier hang (P-002 + P-004 reland of S656635). 20-58 MVAI streaming jobs/day affected by same MID."

- model_id: 875799562
  model_type: ig_stories_tray_mtml
  role: holdout
  pg: IG
  product: Stories
  owner: johnbriggs
  runtime: MAST
  tier: unknown
  status: active
  notable: "S661843 in progress 10d (since 2026-05-10); inference error rate elevated"

- model_id: 1082814831
  model_type: IG HIM PT (heavyweight CTR)
  role: trainer
  pg: IG
  product: Stories
  owner: mehrdadsh
  runtime: MAST
  tier: 1
  status: was-stuck
  notable: "S666282 ~45min — Opsmate root: PMTS lifecycle state (65d ago) not in QRT_START_ELIGIBLE_STATUSES; 7-day managed training expiration; both checks silently blocked reactivation. Form fields empty; agent-feed has Opsmate RCA."
```

### IG / Mixed_IFR

```yaml
- model_id: 2145336177
  model_type: ig_mixed_ifr_u2i_combined_omni_retrieval
  role: holdout (also stus per entrypoint)
  pg: IG
  product: Mixed_IFR
  oncall_modeling: ig_feed_retrieval
  oncall_snapshot: ig_feed_system
  owner: xinwu
  mast_job: mvai-training-online-2145336177
  runtime: MAST
  tier: unknown
  status: active (chronically stalled)
  current_attempt: v18 RUNNING since 2026-05-15
  notable: "**M-011 / P-007 reference instance** — 25min/hr training stall on ~1h cycle (confirmed 2026-05-20 via system-metrics: SM util p50=0.92% vs fleet 36.52%, p25 GPU device util=0%, DPP starvation flat 1.94% → NOT DPP-bound). Snapshot publishing every 3 min looked clockwork → masked the stall from cron triage."
```

### IG / Explore

```yaml
- model_id: <unknown — S661045 references ig_explore_chaining_mtml>
  model_type: ig_explore_chaining_mtml
  role: trainer
  pg: IG
  product: Explore
  owner: jaspy
  runtime: MAST
  tier: unknown
  status: active
  notable: "S661045 in progress; QPS falling (CL-015a sub-class)"
```

### Threads

```yaml
- model_id: 2124122280
  model_type: ig_textpost_feed_u2m_retrieval (Threads Retrieval U2M)
  role: trainer
  pg: Threads
  product: Retrieval_U2M
  oncall_snapshot: p92_relevance_retrieval_oncall
  oncall_modeling: p92_relevance_retrieval_oncall (per flow_entitlement)
  owner: mlygao
  mast_job: mvai-training-online-2124122280
  runtime: MAST
  tier: unknown
  status: active
  current_attempt: attempt 0 RUNNING since 2026-05-16 18:04 PDT
  notable: "**Cluster reference for S665454** — actual Threads Retrieval U2M (the cron mistakenly attributed to m2129246926). Layer 1 = CUDA allocator INTERNAL ASSERT (R-001) + Layer 2 = elastic agent zombie (M-001/P-002). Was stuck 13h on 2026-05-16; user-killed; restart healthy."

- model_id: 2124793203
  model_type: ig_textpost_feed_u2m_retrieval
  role: trainer
  pg: Threads
  product: Retrieval_U2M
  owner: mlygao
  runtime: MAST
  tier: unknown
  status: active
  current_attempt: attempt 1 RUNNING since 2026-05-18 17:55 PDT
  notable: "Sibling of m2124122280 in S665454; same Layer-1 CUDA assert; user-killed and restarted 2026-05-18"

- model_id: 2124428748
  model_type: ig_textpost_feed_u2m_retrieval
  role: trainer
  pg: Threads
  product: Retrieval_U2M
  owner: mlygao
  runtime: MAST
  tier: unknown
  status: active
  current_attempt: attempt 0 RUNNING since 2026-05-18 08:34 PDT
  notable: "Sibling of m2124122280 in S665454; same family / same bug"

- model_id: 2129246926
  model_type: threads_feed_mtml (NOT Retrieval — Ranking)
  role: trainer
  pg: Threads
  product: Feed_U2M (Ranking)
  oncall_snapshot: p92_relevance_ranking
  owner: lizichao
  runtime: MAST
  tier: unknown
  status: active
  current_attempt: attempt 1 RUNNING 9d (since 2026-05-11 18:03)
  notable: "Bloom-index deadlock 7d in attempt 0 (S665454 cron triage mis-attributed this to S665454; actual Threads Retrieval = m2124122280). Layer-1 R-006 bloom_index_b=2240 overflow. Fix tracking T271094105."

- model_id: 2128461099
  model_type: Threads Feed teacher
  role: trainer (teacher)
  pg: Threads
  product: ESR
  owner: jamey  # Jamey Zhang
  runtime: MAST
  tier: 3 # L3 SEV
  status: was-stuck (S664106 Mitigated 2026-05-14)
  notable: "S664106 — 'online training cannot get started' (CL-009 / M-004 silent stall via R-013 MVAI manual expiration); mitigated 2h21m after open. Auto-tag missed because lifecycle was within one day."
```

### Facebook / CFR

```yaml
- model_id: 878858380
  model_type: facebook_cfr_main_mtml (a.k.a. facebook_cfr_hstu_online)
  role: trainer (baseline)
  pg: Facebook
  product: CFR
  oncall_modeling: feed_ecosystem_core_modeling
  owner: yzqian
  mast_job: mvai-training-online-878858380
  runtime: MAST
  tier: 1
  status: active
  current_attempt: v137 RUNNING (multiple auto-restarts during NaN cascade window)
  notable: "**Top noisy model** — 5 alerts/7d. CL-017 Shampoo NaN cascade (R-010) + CL-001 FS gaps. S665902 Conveyor regression on cfr_main_feed_mtml_roo_hstu pkg (active). NaN detector firing stale 67h after recovery (M-017). yzqian / feed_ecosystem_core_modeling."

- model_id: 2134801434
  model_type: facebook_cfr_main_mtml
  role: trainer (baseline) — sibling of m878858380
  pg: Facebook
  product: CFR
  oncall_modeling: feed_ecosystem_core_modeling
  owner: yufengma (page actor) / yzqian (modeling)
  mast_job: mvai-training-online-2134801434
  runtime: MAST
  tier: 1 (700k QPS)
  status: active
  notable: "S660507 ongoing 14d — m2134801434 consistent non-zero error rate. 2026-05-19 P56 NaN cascade self-recovered (auditor R-EV4 caught my mis-call as compound P56+P61). v97 MAST auto-restart succeeded. FS publishing every ~45min normal post-recovery."
```

### Facebook / Video

```yaml
- model_id: 877766932
  model_type: facebook_reels_vdd_hstu_v0
  role: trainer (baseline st_root)
  pg: Facebook
  product: Video
  oncall_modeling: minimal_viable_ai
  oncall_snapshot: mrs_retrieval_u2i
  owner: charlesz
  mast_job: mvai-training-online-877766932
  runtime: MAST
  tier: unknown
  status: active
  notable: "M-016 false-positive: D75703936 checkpoint_training_data_age_mins formula bug (UTC vs PDT -7h skew) causes ~3000-min false positive at restart. Documented in 2026-W21 mega-learning. 2026-05-19 23:07 PDT CRITICAL alert was DETECTOR_BROKEN class; bot correctly recognized via mega-learnings grep."
```

### Facebook / IFR

```yaml
- model_id: 875961478
  model_type: facebook_ifr_main_mtml_second
  role: trainer
  pg: Facebook
  product: IFR
  owner: ajfoiani
  runtime: MAST
  tier: 1 (400-600k QPS)
  status: active
  notable: "S659671 ongoing 15d — 5+% error rate. Last update 22:56 PT 2026-05-19 per daily-brief 'check what changed'"
```

### Production / Time-spent

```yaml
- model_id: 2137644003
  model_type: TIMESPENT_MTML
  role: adapter (trainer)
  pg: Production
  product: Time-spent
  oncall_modeling: feed_recommendation_ranking_modeling
  owner: jiayi000xian
  mast_job: mvai-training-online-2137644003
  runtime: MAST
  tier: unknown
  status: stuck (IPNEXT publish path)
  notable: "S662459 ongoing 9d — UMM model instances created but IPNEXT serving publish silently stopped after snapshot 1460 (2026-05-10 16:16 PDT). Latest UMM instance :1155 at 2026-05-18 21:37 PDT (41h gap). Opsmate 'root cause could not be determined'. Bot at end of automation reach."
```

### Production / IFR / Mimicry / TIXU

```yaml
- model_id: 2147007224  # S635390 evidence
  model_type: ig_threads_u2m (per S635390)
  role: unknown
  pg: IG (Threads sub-PG)
  product: Threads U2M
  notable: "S635390 EDPP block 2026-03-17; CL-013 example_age spike from upstream"

- model_id: 2122272743  # S665214 / A848827930836030
  model_type: unknown (TGIF publisher target)
  notable: "A848827930836030 MAJOR active 2026-05-20: TGIF publisher non-retryable error"

- model_id: 2122381387  # S665902 cogwheel test
  model_type: cogwheel test target for cfr_main_feed_mtml
  notable: "Per S665902 description"

- model_ids_threads_elastic: [878976345, 876104295, 2144714031]  # S665343
  model_type: Threads elastic models (solver churn)
  pg: Threads
  notable: "S665343 — regional allocation instability"
```

---

## Inventory completeness

- **Total seeded**: ~32 unique model_ids
- **Source**: 2026-05-19/20 session triages + historical SEV evidence from `../patterns/failure-patterns.md` + `../noisy-trends.md`
- **Known gaps**: most Production / TIXU / Mimicry models; Search SilverTorch models; Ads-side models intentionally excluded
- **Update cadence**: manual — refresh when triage reveals new models or status changes
