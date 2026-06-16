# OT Models Derived From Production Issues

OT models **discovered by reconciling past OT incidents** (SEVs tagged `mvai-online-training` ∪ alert/post archives) and filtered to currently-RUNNING online-training MAST jobs — see `tools/reconcile-models.sh`. This is **incident-derived coverage, NOT an authoritative roster of every in-scope OT model**: a healthy OT model that has never had an incident won't appear here until it does (or until someone adds it manually). Treat it as "models we've seen break in prod," not "all models we own." Sorted by MVAI Tier (TIER_1 first); within each tier by IMPORTANCE — production before QE, then GPU count descending.

**Metadata last refreshed:** 2026-06-04 (owners/GPUs/base-layer fields). Re-fetch via `meta ai.mast-job metadata --name=mvai-training-online-<ENTITY_ID> -o json`.
**Liveness last verified:** 2026-06-09 — full status sweep; pruned 4 DEAD (2141016310, 2139637572, 2124038092, 2124793203); 2128413703 kept (PENDING, coming up). Re-verify with `python3 tools/validate-models.py --enrich`. Validator WARNs when the metadata-refresh date is >7d old.

**PG classification rule (prgzz + operator, 2026-06-04, space `AAQAR1xHaQU`):** model_type containing
`textpost` OR `threads` → **THREADS** PG, *not* Instagram. The `ig_`-prefix on these is a legacy
naming artifact ; classify PG by this rule, not by the `ig_` prefix.

## Overview

**61 models · 2,980 GPUs** — incident-derived, currently-RUNNING OT online-training models (see title; not a full roster).
Breakdowns below are DERIVED from the per-tier tables; regenerate after any edit with
`python3 tools/validate-models.py --fix-overview` (the validator also fails if they drift).

### By tier
| Tier | Models | GPUs |
|------|-------:|-----:|
| TIER_1 | 37 | 1,900 |
| TIER_2 | 11 | 352 |
| TIER_3 | 11 | 704 |
| TIER_4 | 2 | 24 |
| **Total** | **61** | **2,980** |

### By PG (Product Group)
| PG | Models | GPUs | T1 | T2 | T3 | T4 |
|----|-------:|-----:|---:|---:|---:|---:|
| FEED | 14 | 1,352 | 9 | 1 | 4 | 0 |
| INSTAGRAM | 21 | 864 | 13 | 6 | 2 | 0 |
| VIDEO | 13 | 608 | 10 | 0 | 1 | 2 |
| THREADS | 13 | 156 | 5 | 4 | 4 | 0 |
| **Total** | **61** | **2,980** | 37 | 11 | 11 | 2 |

### By hardware
| Hardware | Models | GPUs |
|----------|-------:|-----:|
| GRAND_TETON | 28 | 1,688 |
| B200 | 9 | 784 |
| A100 | 24 | 508 |

## TIER_1 (37 models)

| # | Model | Model Type | Entity ID | PG | Owner | GPUs | Hardware | Region | Base Layer | Base Date |
|---|-------|-----------|-----------|----------|-------|------|----------|--------|------------|-----------|
| 1 | FB Reels UDD HSTU FM | facebook_reels_udd_hstu_fm | [2147007224](https://www.internalfb.com/ummmeta/cq?entity_id=2147007224) | FEED | jhsun | 512 | GRAND_TETON | dkl | light_cli:3715 | 2025-09-10 |
| 2 | FB Reels IFU MTML | facebook_reels_ifu_mtml_v0 | [883552231](https://www.internalfb.com/ummmeta/cq?entity_id=883552231) | VIDEO | keehwan | 128 | GRAND_TETON | maz | light_cli:3021 | 2025-09-02 |
| 3 | FB IFR MainMTML | facebook_ifr_main_mtml_main | [886797001](https://www.internalfb.com/ummmeta/cq?entity_id=886797001) | FEED | wenshunliu | 96 | GRAND_TETON | ncg | light_cli:3388 | 2025-07-25 |
| 4 | Reels LSR (new) | ig_reels_tab_mtml | [2133008573](https://www.internalfb.com/ummmeta/cq?entity_id=2133008573) | INSTAGRAM | jiaweihuang | 96 | B200 | kcm | light_cli_blackwell:323 | 2025-11-10 |
| 5 | IFR MainMTML | facebook_ifr_main_mtml_main | [2125752019](https://www.internalfb.com/ummmeta/cq?entity_id=2125752019) | FEED | yucheng | 80 | B200 | maz | light_cli_blackwell:453 | 2026-02-15 |
| 6 | FB Reels VDD HSTU | facebook_reels_vdd_hstu_v0 | [877766932](https://www.internalfb.com/ummmeta/cq?entity_id=877766932) | VIDEO | jayantadutta | 80 | A100 | pnb | light_cli:3665 | 2025-11-03 |
| 7 | Feed LSR (new) | ig_organic_feed_mtml | [2134319967](https://www.internalfb.com/ummmeta/cq?entity_id=2134319967) | INSTAGRAM | wenkai | 80 | B200 | maz | light_cli:5179 | 2026-02-12 |
| 8 | FB CFR MainMTML | facebook_cfr_main_mtml | [2134801434](https://www.internalfb.com/ummmeta/cq?entity_id=2134801434) | FEED | yufengma | 64 | GRAND_TETON | dkl | light_cli:4651 | 2025-10-26 |
| 9 | FB CFR MainMTML | facebook_cfr_main_mtml | [878858380](https://www.internalfb.com/ummmeta/cq?entity_id=878858380) | FEED | yufengma | 64 | GRAND_TETON | ncg | light_cli:3493 | 2025-07-18 |
| 10 | Reels OmniUV | ig_reels_tab_ss_omni_retrieval | [2137792444](https://www.internalfb.com/ummmeta/cq?entity_id=2137792444) | INSTAGRAM | yiliang | 64 | A100 | nha | light_cli:4443 | 2026-02-03 |
| 11 | FB Reels VDD HSTU V0 | facebook_reels_vdd_hstu_v0 | [2130289886](https://www.internalfb.com/ummmeta/cq?entity_id=2130289886) | VIDEO | kedhe | 64 | A100 | ncg | light_cli:4822 | 2026-03-19 |
| 12 | FB Reels UDD HSTU Expert | facebook_reels_udd_hstu_expert | [2133379243](https://www.internalfb.com/ummmeta/cq?entity_id=2133379243) | VIDEO | rezas | 64 | GRAND_TETON | ftw | light_cli:4703 | 2026-02-01 |
| 13 | Reels ESR VM | ig_reels_tab_vm_esr | [2141728947](https://www.internalfb.com/ummmeta/cq?entity_id=2141728947) | INSTAGRAM | kangdu | 48 | A100 | ncg | light_cli:4200 | 2026-01-05 |
| 14 | FB Reels IFU MTML V0 | facebook_reels_ifu_mtml_v0 | [2126653325](https://www.internalfb.com/ummmeta/cq?entity_id=2126653325) | VIDEO | ritamguha | 48 | GRAND_TETON | gtn | light_cli:4831 | 2026-03-19 |
| 15 | Feed Recs IFR T2I Retrieval | ig_feed_recs_ifr_t2i_retrieval | [2136304504](https://www.internalfb.com/ummmeta/cq?entity_id=2136304504) | INSTAGRAM | ruichenrong | 48 | GRAND_TETON | nha | light_cli:4509 | 2026-02-10 |
| 16 | Feed ESR | ig_feedrec_esr_ttsn | [2126294138](https://www.internalfb.com/ummmeta/cq?entity_id=2126294138) | INSTAGRAM | mingchao | 32 | A100 | ncg | light_cli:5164 | 2026-04-21 |
| 17 | Feedrec ESR TTSN | ig_feedrec_esr_ttsn | [2122112224](https://www.internalfb.com/ummmeta/cq?entity_id=2122112224) | INSTAGRAM | mingchao | 32 | A100 | pnb | light_cli:5255 | 2026-04-29 |
| 18 | Threads Feed MTML | threads_feed_mtml | [2129246926](https://www.internalfb.com/ummmeta/cq?entity_id=2129246926) | THREADS | haoyuwu | 24 | GRAND_TETON | ftw | light_cli:4799 | 2026-03-16 |
| 19 | FB Reels VDD HSTU | facebook_reels_vdd_hstu_v0 | [877766818](https://www.internalfb.com/ummmeta/cq?entity_id=877766818) | VIDEO | jayantadutta | 16 | A100 | eag | light_cli:3665 | 2025-11-03 |
| 20 | Reels CS Omni | ig_reels_tab_cs_omni_retrieval | [2143060567](https://www.internalfb.com/ummmeta/cq?entity_id=2143060567) | INSTAGRAM | hellozeyu | 16 | GRAND_TETON | ncg | light_cli:4032 | 2025-12-15 |
| 21 | FB IFR Main UMIA V1 MVAI | facebook_ifr_main_umia_v1_mvai | [2126025623](https://www.internalfb.com/ummmeta/cq?entity_id=2126025623) | FEED | chunhuigu | 16 | GRAND_TETON | ftw | light_cli:4688 | 2026-03-08 |
| 22 | FB IFR Main UMIA V1 MVAI | facebook_ifr_main_umia_v1_mvai | [2126030135](https://www.internalfb.com/ummmeta/cq?entity_id=2126030135) | FEED | chunhuigu | 16 | GRAND_TETON | gtn | light_cli:4688 | 2026-03-08 |
| 23 | FB Reels VDD HSTU V0 | facebook_reels_vdd_hstu_v0 | [2130289862](https://www.internalfb.com/ummmeta/cq?entity_id=2130289862) | VIDEO | kedhe | 16 | A100 | eag | light_cli:4822 | 2026-03-19 |
| 24 | FB Reels IFU HSTU V0 | facebook_reels_ifu_hstu_v0 | [2131554922](https://www.internalfb.com/ummmeta/cq?entity_id=2131554922) | VIDEO | kedhe | 16 | A100 | eag | light_cli:4652 | 2026-03-03 |
| 25 | Reels Tab SS Omni Retrieval | ig_reels_tab_ss_omni_retrieval | [2133539495](https://www.internalfb.com/ummmeta/cq?entity_id=2133539495) | INSTAGRAM | yiliang | 16 | GRAND_TETON | nha | light_cli:4443 | 2026-02-03 |
| 26 | FB Reels VDD HSTU V0 | facebook_reels_vdd_hstu_v0 | [877766873](https://www.internalfb.com/ummmeta/cq?entity_id=877766873) | VIDEO | jayantadutta | 16 | A100 | eag | light_cli:3665 | 2025-11-03 |
| 27 | FB Reels IFU I2I | facebook_reels_ifu_i2i | [2132070936](https://www.internalfb.com/ummmeta/cq?entity_id=2132070936) | VIDEO | fengzhang1 | 8 | A100 | eag | light_cli:5281 | 2026-05-01 |
| 28 | Reels T2I (new) | ig_reels_starsearch_t2i_retrieval | [2126189932](https://www.internalfb.com/ummmeta/cq?entity_id=2126189932) | INSTAGRAM | yjfu | 8 | GRAND_TETON | nha | light_cli:4930 | 2026-03-28 |
| 29 | Textpost M2M Ret | ig_textpost_feed_m2m_retrieval | [2130324829](https://www.internalfb.com/ummmeta/cq?entity_id=2130324829) | THREADS | ronghuang | 8 | A100 | vll | light_cli:4648 | 2026-03-02 |
| 30 | Threads In Feed FB TIFU MTML | ig_threads_in_feed_fb_tifu_mtml | [2125913074](https://www.internalfb.com/ummmeta/cq?entity_id=2125913074) | THREADS | halin | 8 | A100 | ncg | light_cli:5174 | 2026-04-20 |
| 31 | Mixed IFR U2I Omni Retrieval | ig_mixed_ifr_u2i_omni_retrieval | [2129126909](https://www.internalfb.com/ummmeta/cq?entity_id=2129126909) | INSTAGRAM | stevezhuang | 8 | A100 | nha | light_cli:5014 | 2026-04-06 |
| 32 | Textpost Feed U2M Retrieval | ig_textpost_feed_u2m_retrieval | [2139705840](https://www.internalfb.com/ummmeta/cq?entity_id=2139705840) | THREADS | akoz | 8 | GRAND_TETON | ncg | light_cli:4046 | 2025-12-16 |
| 33 | Stories Tray ESR | ig_stories_tray_esr | [2145993395](https://www.internalfb.com/ummmeta/cq?entity_id=2145993395) | FEED | arafatm | 8 | GRAND_TETON | ftw | light_cli:4006 | 2025-12-11 |
| 34 | Textpost M2M Ret (sm) | ig_textpost_feed_m2m_retrieval | [2130324780](https://www.internalfb.com/ummmeta/cq?entity_id=2130324780) | THREADS | ronghuang | 4 | A100 | vll | light_cli:4648 | 2026-03-02 |
| 35 | IFR MainMTML (QE) | facebook_ifr_main_mtml_main | [2143912626](https://www.internalfb.com/ummmeta/cq?entity_id=2143912626) | FEED | bbanavige | 64 | B200 | snb | light_cli_blackwell:244 | 2025-07-25 |
| 36 | Reels OmniUV (QE) | ig_reels_tab_ss_omni_retrieval | [2144816217](https://www.internalfb.com/ummmeta/cq?entity_id=2144816217) | INSTAGRAM | shuyaoli | 16 | A100 | eag | light_cli:3666 | 2025-11-03 |
| 37 | Reels CS Omni (QE) | ig_reels_tab_cs_omni_retrieval | [2130305043](https://www.internalfb.com/ummmeta/cq?entity_id=2130305043) | INSTAGRAM | xuzhe | 8 | A100 | vll | light_cli:4624 | 2026-02-26 |

## TIER_2 (11 models)

| # | Model | Model Type | Entity ID | PG | Owner | GPUs | Hardware | Region | Base Layer | Base Date |
|---|-------|-----------|-----------|----------|-------|------|----------|--------|------------|-----------|
| 1 | Reels ESR | ig_reels_tab_esr_ttsn | [876773473](https://www.internalfb.com/ummmeta/cq?entity_id=876773473) | FEED | houxiaochen | 120 | GRAND_TETON | ncg | light_cli:3828 | 2025-09-18 |
| 2 | Reels Tab MTML | ig_reels_tab_mtml | [2132766001](https://www.internalfb.com/ummmeta/cq?entity_id=2132766001) | INSTAGRAM | jakubbester | 80 | B200 | kcm | light_cli_blackwell:77 | 2025-09-09 |
| 3 | Feed LSR | ig_organic_feed_mtml | [878102693](https://www.internalfb.com/ummmeta/cq?entity_id=878102693) | INSTAGRAM | wenkai | 64 | B200 | maz | light_cli_blackwell:146 | 2025-10-02 |
| 4 | Feed U2I | ig_mixed_ifr_u2i_combined_omni_retrieval | [2145336287](https://www.internalfb.com/ummmeta/cq?entity_id=2145336287) | INSTAGRAM | xinwu | 32 | GRAND_TETON | nha | light_cli:3806 | 2025-11-19 |
| 5 | Threads Replies | ig_threads_replies_mtml | [2127763700](https://www.internalfb.com/ummmeta/cq?entity_id=2127763700) | THREADS | hubertliu | 8 | GRAND_TETON | ncg | light_cli:5014 | 2026-04-06 |
| 6 | Textpost Feed XAPP U2M Retrieval | ig_textpost_feed_xapp_u2m_retrieval | [2132160077](https://www.internalfb.com/ummmeta/cq?entity_id=2132160077) | THREADS | tianyic | 8 | A100 | ncg | light_cli:4648 | 2026-03-02 |
| 7 | Textpost Feed LSR | ig_textpost_feed_lsr | [2128024482](https://www.internalfb.com/ummmeta/cq?entity_id=2128024482) | THREADS | hansjhe | 8 | A100 | nha | light_cli:5034 | 2026-04-08 |
| 8 | Reels Tab Integrity ESR | ig_reels_tab_integrity_esr | [2140425308](https://www.internalfb.com/ummmeta/cq?entity_id=2140425308) | INSTAGRAM | shuang42 | 8 | A100 | ncg | light_cli:3305 | 2025-09-29 |
| 9 | Textpost Feed LSR | ig_textpost_feed_lsr | [2133882726](https://www.internalfb.com/ummmeta/cq?entity_id=2133882726) | THREADS | kewenpeng | 8 | A100 | pnb | light_cli:4656 | 2026-03-03 |
| 10 | Mixed IFR U2I Omni Retrieval | ig_mixed_ifr_u2i_omni_retrieval | [2145336177](https://www.internalfb.com/ummmeta/cq?entity_id=2145336177) | INSTAGRAM | xinwu | 8 | A100 | nha | light_cli:3806 | 2025-11-19 |
| 11 | Reels Tab CS Omni Retrieval | ig_reels_tab_cs_omni_retrieval | [880283513](https://www.internalfb.com/ummmeta/cq?entity_id=880283513) | INSTAGRAM | upandey | 8 | GRAND_TETON | maz | light_cli:2831 | 2025-08-16 |

## TIER_3 (11 models)

| # | Model | Model Type | Entity ID | PG | Owner | GPUs | Hardware | Region | Base Layer | Base Date |
|---|-------|-----------|-----------|----------|-------|------|----------|--------|------------|-----------|
| 1 | FB Reels IFU MTML V0 | facebook_reels_ifu_mtml_v0 | [2135033479](https://www.internalfb.com/ummmeta/cq?entity_id=2135033479) | VIDEO | maxlinhe | 128 | GRAND_TETON | mwg | light_cli:4563 | 2026-02-19 |
| 2 | FB CFR Main MTML | facebook_cfr_main_mtml | [2141386679](https://www.internalfb.com/ummmeta/cq?entity_id=2141386679) | FEED | cc93 | 128 | B200 | snb | light_cli_blackwell:158 | 2025-11-02 |
| 3 | Reels Tab MTML | ig_reels_tab_mtml | [2124118880](https://www.internalfb.com/ummmeta/cq?entity_id=2124118880) | INSTAGRAM | velvinfu | 112 | B200 | snb | light_cli:5150 | 2026-04-20 |
| 4 | FB IFR Main MTML Main | facebook_ifr_main_mtml_main | [2130151473](https://www.internalfb.com/ummmeta/cq?entity_id=2130151473) | FEED | wangjia | 96 | GRAND_TETON | gtn | light_cli:2561 | 2025-07-25 |
| 5 | FB IFR Main MTML Main | facebook_ifr_main_mtml_main | [2123944781](https://www.internalfb.com/ummmeta/cq?entity_id=2123944781) | FEED | haosha3 | 80 | B200 | maz | light_cli_blackwell:453 | 2026-02-15 |
| 6 | Feedrec ESR TTSN | ig_feedrec_esr_ttsn | [2126294150](https://www.internalfb.com/ummmeta/cq?entity_id=2126294150) | INSTAGRAM | mingchao | 80 | GRAND_TETON | nha | light_cli:5164 | 2026-04-21 |
| 7 | Threads Feed | threads_feed_mtml | [2128873883](https://www.internalfb.com/ummmeta/cq?entity_id=2128873883) | THREADS | jameyz | 24 | GRAND_TETON | ftw | light_cli:4799 | 2026-03-16 |
| 8 | Threads Feed MTML | threads_feed_mtml | [2128461099](https://www.internalfb.com/ummmeta/cq?entity_id=2128461099) | THREADS | haoyuwu | 24 | GRAND_TETON | ftw | light_cli:4799 | 2026-03-16 |
| 9 | Textpost Feed U2M Retrieval | ig_textpost_feed_u2m_retrieval | [2124428748](https://www.internalfb.com/ummmeta/cq?entity_id=2124428748) | THREADS | wenping | 16 | GRAND_TETON | dkl | light_cli:5315 | 2026-05-03 |
| 10 | FB IFR Main UMIA UGC CCS U2I | facebook_ifr_main_umia_ugc_ccs_u2i | [877546696](https://www.internalfb.com/ummmeta/cq?entity_id=877546696) | FEED | zifanzhu | 8 | GRAND_TETON | maz | light_cli:3389 | 2025-10-06 |
| 11 | Threads Replies (QE) | ig_threads_replies_mtml | [2123426413](https://www.internalfb.com/ummmeta/cq?entity_id=2123426413) | THREADS | hubertliu | 8 | GRAND_TETON | ncg | light_cli:5229 | 2026-04-26 |

## TIER_4 (2 models)

| # | Model | Model Type | Entity ID | PG | Owner | GPUs | Hardware | Region | Base Layer | Base Date |
|---|-------|-----------|-----------|----------|-------|------|----------|--------|------------|-----------|
| 1 | FB Reels VDD UMIA V1 | facebook_reels_vdd_umia_v1 | [2128413703](https://www.internalfb.com/ummmeta/cq?entity_id=2128413703) | VIDEO | tanfiona | 16 | A100 | vll | light_cli:4969 | 2026-04-01 |
| 2 | FB Reels IFU I2I (QE) | facebook_reels_ifu_i2i | [2125081901](https://www.internalfb.com/ummmeta/cq?entity_id=2125081901) | VIDEO | fengzhang1 | 8 | A100 | ncg | light_cli:5281 | 2026-05-01 |

## Notes

- **Source:** reconciled 2026-06-04 against ALL OT incidents — SEVs tagged `mvai-online-training`, alert archives, mrs.ot posts (`mrs-ot-agent-context/incidents/`) — filtered to currently-RUNNING online-training MAST jobs. (Prior versions only used locally-archived incidents → missed 35 live models.)
- **Excluded:** DEAD jobs (old QE/test models no longer running) + root-only models with no own training job.
- **Zombie scan:** `bash tools/scan-zombie-fleet.sh` reads this file and checks each model.
- **Runtime note:** the consuming workflows resolve `pg`/`owner`/`tier` LIVE via
  `tools/lib-enrich-model.sh enrich_model <entity_id>` (meta-keyed), NOT from this
  file's columns — so those columns are human reference. Only `entity_id` is load-bearing
  for the scans (extracted from TABLE ROWS only via the `entity_id=NNNN` link).
- **Maintenance loop (run on every edit):**
  1. `bash tools/reconcile-models.sh` — reports MISSING (live, untracked → add) and
     STALE (tracked, job not RUNNING → prune). Bidirectional freshness.
  2. Edit rows accordingly.
  3. `python3 tools/validate-models.py --fix-overview` — regenerate the ## Overview
     breakdowns from the tables (no hand-counting).
  4. `python3 tools/validate-models.py` — **MUST exit 0 before committing.** Enforces
     column/count/owner/PG-enum/same-type-consistency invariants AND that ## Overview
     matches the tables. Also runs as a preflight in `tools/run-fleet-health.sh`
     (every 4h) so drift surfaces automatically.
- **PG (Product Group):** {FEED, VIDEO, INSTAGRAM, THREADS}. Hand taxonomy finer than
  the prefix-derived `enrich_model` pg (which lumps all `ig_*` as INSTAGRAM); the
  validator WARNs where they differ. textpost/threads model_type → THREADS (rule above).
- **Liveness caveat:** rows are RUNNING only as of "Liveness last verified" above —
  jobs die/resize between sweeps. `--enrich` is the only check that compares to live
  ground truth; the default gate validates structure, not truth. See ## Overview for the
  authoritative (regenerated) counts — never hand-write a total here (it drifts).
