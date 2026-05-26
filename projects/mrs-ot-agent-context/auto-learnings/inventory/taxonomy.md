# PG / Product / Model-Type / Role Taxonomy

_Derivation rules for slicing the OT prod inventory. See `workloads.md` for the inventory itself._

## Top-level PGs

Per `../patterns/failure-patterns.md` PG reference:

| PG | What's in scope | Approx % (4wk) |
|---|---|---:|
| **IG** | Instagram-side OT models | ~48% |
| **infra-cross-pg** | mvai / cogwheel / light_cli — affects multiple PGs | ~45% |
| **Threads** | Threads ranking + retrieval OT | ~10% |
| **Facebook** | Facebook Feed / CFR / IFR / Video VDD OT | ~3-6% |
| **Production** | TIXU / IFR / Mimicry / Time-spent | ~3% |
| **Ads** | Ads-team OT models | R18 drop (out-of-scope) |
| **Wearables / WhatsApp / other** | sev_type sibling-org leaks | R18 drop |

## PG → Product hierarchy

### IG
- **Feed** — `ig_organic_feed_mtml`, `ig_feed_mtml`, `ig_textpost_feed_*`
- **Reels** — `ig_reels_tab_mtml`, `ig_reels_tab_ss_omni_retrieval`, `ig_reels_starsearch_t2i_retrieval`, `ig_reels_lsr` (MB8/MB9/MB10), `ig_reels_ifu_i2i`
- **Stories** — `ig_stories_tray_mtml`, `ig_stories_ranking` (ESR), `ig_stories_him` (HIM PT heavyweight CTR), `ig_stories_secondary_model`
- **Mixed_IFR** — `ig_mixed_ifr_u2i_combined_omni_retrieval`
- **Explore** — `ig_explore_chaining_mtml`
- **Search** — SilverTorch IFR Prospector / Search variants
- **Push** — `ig_textpost_push_notification_x_selection`

### Threads
- **Feed_U2M (Ranking)** — `threads_feed_mtml` (m2129246926)
- **Retrieval_U2M** — `ig_textpost_feed_u2m_retrieval` (m2124122280, m2124793203, m2124428748)
- **ESR (teacher)** — Threads Feed teacher (m2128461099)
- **LSR** — Threads LSR (prod teacher m_haoyuwu per S663484)
- **Elastic** — m878976345, m876104295, m2144714031 (per S665343)

### Facebook
- **CFR** — `facebook_cfr_main_mtml` (m878858380 cfr_hstu_online, m2134801434), `facebook_cfr_main_feed_mtml_roo_hstu`
- **Feed** — `feed_recommendation_ranking_modeling` cluster
- **IFR** — `facebook_ifr_main_mtml_second` (m875961478)
- **Video** — `facebook_reels_vdd_hstu_v0` (m877766932), `facebook_reels_vdd_sparse_mtml_v0`

### Production
- **Time-spent** — `TIMESPENT_MTML` (m2137644003)
- **IFR** — `mvai_ifr_main` conveyor
- **Mimicry** — Mimicry Sourcing models (per S653888)
- **TIXU** — 61 models in S659243 calibration impact

### infra-cross-pg
- `mvai / umia_v1_igr` conveyor (S666322, S666413)
- `mvai / mvai_ifr_main` conveyor (S666451, S661284, S651873)
- `mvai / cfr_main_feed_mtml_roo_hstu` (S665902)
- `silvertorch / ifr_prospector` (S665607)
- `light_cli`, `tms`, `model_processing` cross-cutting infra

## Role classification rules

When attributing role to a model_id, use **PRECEDENCE ORDER** (top-down — first match wins):

```
1. Title contains "holdout" (alert/SEV) → role: holdout
2. Title contains "baseline" → role: baseline
3. flow_entitlement = "threads_online_training_retrieval_prod" → role: trainer (retrieval)
4. entrypoint contains "st_update_service" → role: stus (R14)
5. entrypoint contains "ig_retrieval/train.py" → role: trainer (retrieval)
6. entrypoint contains "ig_ranking/launch.py" → role: trainer (ranking)
7. flow_model_type contains "teacher" → role: trainer (teacher)
8. flow_model_type contains "adapter" → role: adapter (Time-spent class)
9. runtime_platform = FBLEARNER_FLOW → role: unknown (no MAST signal)
10. otherwise → role: unknown
```

**Note:** a model can be BOTH `holdout` AND `stus` (e.g., m2145336177). Record both; use the dominant role per the alert that fires.

## Product-to-model-type derivation

When new model_type strings appear (e.g., from `flow_model_type` of a new MAST job), the operator should attempt regex match:

```
ig_organic_feed_* → IG / Feed
ig_textpost_feed_* → IG / Feed (push if push_notification in name)
ig_reels_tab_* → IG / Reels
ig_reels_starsearch_* → IG / Reels
ig_reels_lsr_* → IG / Reels
ig_reels_ifu_* → IG / Reels (or Facebook/Video if facebook_reels prefix)
ig_stories_* → IG / Stories
ig_mixed_ifr_* → IG / Mixed_IFR
ig_explore_* → IG / Explore
ig_search_* → IG / Search

threads_feed_mtml → Threads / Feed_U2M
threads_*_u2m_retrieval → Threads / Retrieval_U2M
threads_lsr → Threads / LSR

facebook_cfr_* → Facebook / CFR
facebook_ifr_* → Facebook / IFR
facebook_reels_vdd_* → Facebook / Video
facebook_reels_ifu_* → Facebook / Video  # note: facebook_reels_ifu (not ig_)

TIMESPENT_MTML, *adapter* → Production / Time-spent
*ipnext*, *umm* → Production (varied)

mvai/* → infra-cross-pg
silvertorch/* → infra-cross-pg
```

When no rule matches: flag as `pg: unknown`, `product: unknown` for operator review.

## Tier classification

Best-effort heuristic from observed evidence (not all models have explicit tiers):

| Tier | Definition | Examples |
|---|---|---|
| 1 | Top-traffic prod (>200k QPS) | m878858380, m2134801434 (CFR ~700k QPS), m875961478 (IFR 400-600k QPS), facebook_reels_ifu_i2i |
| 2 | Mid-traffic prod | m2130324780 (textpost m2m), most IG retrieval models |
| 3 | Lower-traffic prod / holdouts | m878102693, m2144816217, m2145336177 holdouts |
| 4 | Test / pre-prod / staging | conveyor cogwheel-tests; out-of-scope per R18 |

## Maintenance

- When a new product line appears (e.g., a new IG sub-feature): add to PG → product hierarchy + add regex to derivation
- When a new model_type appears that doesn't match: flag for operator categorization
- When role rules change (e.g., new entrypoint pattern): update precedence ladder
- The discovery cron runs the rules deterministically; manual overrides go in the `notable:` field on `workloads.md` rows
