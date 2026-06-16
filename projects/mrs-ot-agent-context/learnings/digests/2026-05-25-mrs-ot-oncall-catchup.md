# 2026-05-25 — MRS Online Training Oncall catch-up (gchat `spaces/AAQATpEgSyk`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 98 human messages spanning 2026-05-19T13:29 → 2026-05-23T10:49 in **MRS Online Training Oncall** (18 members; primary contributors: Denny Zhang (40), Anthony Foiani (36), Paul Lu (8), Catalin Toda (8), Hongzhang Yin (5))._

_Window: 7d delta (last_msg_create_time: 2026-05-12T12:08:14 PDT, prior window was thin). Skip-until: not set (active polling)._

---

## P0 — bot-integration-blocking items

### P0-1: Raw Embedding Streaming (RES) — new publish path, interaction with sparse delta unresolved

**RES = Raw Embedding Streaming**: new technique from AI Infra team, launched to ESR (IG Feed ranking). Runs in a **dedicated OS process separate from delta publish**. Causes ~3x sparse delta per minute even when model's publish interval is set to 6 min.

Symptom observed (2026-05-22, Hongzhang Yin): `mvai-training-online-2122065673-mrs_cog-test-ede30c` generating huge number of sparse updates. Both test run and baseline job showed the same behavior. Denny confirmed: "there is definitely something off."

**Open questions:**
- How do RES and the existing delta publish path interact?
- If no reconciliation: how is quality assured when two sparse_delta paths run concurrently?

**Status:** Denny DMed model owner; Hongzhang posted to mrs.ot support channel (https://fb.workplace.com/groups/mrs.ot/permalink/1332204528874290/). Li Lu identified POCs: **Joey Yang** and **Zheng Qi** (AI Infra). Denny asked to loop POCs into Hongzhang's Workplace post.

**Bot integration (P0):** when triaging high-frequency sparse delta alerts, check whether **RES is enabled** for the model (`model_config.py` `raw_embedding_streaming` field). If RES is active → high sparse delta rate is EXPECTED (not a failure). Current bot has no awareness of RES. Risk: bot may page on a RES-enabled model for "abnormal sparse delta frequency" when it's by design.

**Code reference:** https://www.internalfb.com/code/fbsource/[0abad0e5b7da756938d6b1e96af86febba1b7940]/fbcode/minimal_viable_ai/models/ig_ranking/esr/ig_reels_tab_esr_ttsn/prod/model_config.py?lines=633

### P0-2: PVR (Package Version Registry) — locks TMS app-layer package, causes silent version pinning

**PVR = Package Version Registry**: a system that locks the app-layer package version for TMS (Training Management Service). When PVR has onboarded a model, TMS uses the PVR-locked version **even if the cconf tag points to a newer package.**

**Root of Catalin Toda's stuck job (2026-05-19):**
- Model `mvai_umia_v1_ifr` was failing since early May
- TMS was using old packages: app `2104`, base `5535`
- Tag `mvai_umia_v1_ifr:umia_v1_candidate` resolved to version `2038` on 4/28 (confirmed via fbpkg)
- PVR had onboarded the model (blocking newer package pickup) — but Catalin confirmed: "we plan to onboard PVR for it, but it is not enabled yet"
- Recovery: TMS relaunched as v31 with updated packages (app `2104`, base `5535`) in region `mwg`

**Related:** S655630 (prior PVR incident). PVR doc: https://docs.google.com/document/d/13cYrXCyMp4Y6NRVPhWYiHQdOC8C6vxt2SQLE_g23IF4/edit?tab=t.0

**Bot integration:** when diagnosing "wrong binary / old package version" failures where TMS is using stale packages despite a new tag:
1. Check if PVR has onboarded this model (`meta ai.* list` or managed_training_service oncall)
2. Check fbpkg resolution for the tag at the relevant date
3. Escalate to: managed_training_service user group (https://fb.workplace.com/groups/280672176819805) or tag siyuan (oncall) if urgent

### P0-3: Canonical model terminology — "baseline" not "prod"

Anthony Foiani (explicit correction, 2026-05-19): *"Please use 'baseline' — it's agreed terminology. All the models on ipnext are 'prod' models in the sense that they receive prod traffic."*

**Canonical lookup chain for OT job health:**
1. Model type → `model_type_metadata.cconf` → baseline model_id
2. Baseline model_id → `model_id.cconf` → training job refs
3. Training job → verify OT health

**Terms:**
- `baseline` = the released/blessed model_id for a model_type (not "prod", not "v0" — that's Ads terminology)
- `launch candidate (LC)` = intended replacement for baseline
- `holdout` = comparison model running alongside baseline
- `v0` = Ads-specific term for baseline equivalent (different team, different ontology)

**Wiki reference:** https://www.internalfb.com/wiki/IGML/Model_Registry/Deep_Dive:_Model_Registry_Concepts/Update_baseline_model_ID/

**Bot integration:** replace "prod OT job" → "baseline OT job" in all triage output. When user/oncall asks about "the prod job for model X", look up baseline in model_type_metadata.cconf first.

### P0-4: SLICK SLO alerting coverage gate — cannot remove SLOs via diff

**Symptom:** Diffs D105893378 and D105890355 consistently failed on `slick_sli_alerting_coverage` check. This SLICK gate blocks removal of SLOs.

**Anthony Foiani's verdict:** *"SLICK is trying to confirm that alerting is done in a way it expects, and we do our alerting differently."* → do NOT add a workaround flag (`is_non_operational`) to bypass SLICK gate. Denny abandoned D106054301 (the bypass diff).

**Resolution path:** leave to SLICK community. SLICK users group thread: https://fb.workplace.com/groups/slickusers/posts/2215468059265666

**Bot integration:** when reviewing UBN diffs for SLO decommissioning, warn operator that SLICK gate will fire and they need SLICK community guidance, not a workaround flag.

---

## P1 — significant nuance / sub-mechanisms

### P1-1: Multiple OT jobs per inference model — confirmed with concrete example

(Confirmed in both MVAI OT Dev and Oncall discussions.)

Anthony Foiani: *"I'm pretty sure I've seen one job do ITEM_EMBED_DELTA, the other do SPARSE_DELTA and DENSE_DELTA"* for a single inference model_id.

Paul Lu (concrete): root model trainer → streams SPARSE_DELTA to inference model. Inference model trainer → produces ITEM_EMBED_DELTA.

*Also possible:* two OT jobs feeding an inference model + a separate recurring training flow generating FULL_SNAPSHOTs.

**Bot check:** when triaging, do NOT stop after finding one OT job per model. Use `ai.mast-job list` filtering by model_series_id to find ALL jobs.

### P1-2: TMS package tag → version resolution — version is pinned at tag-binding time

Tag `mvai_umia_v1_ifr:umia_v1_candidate` resolved to version `2038` on 4/28. TMS cached this resolution. Later tag updates did NOT propagate.

*"TMS always used old packages and this model is broken since early May"* (Catalin Toda).

This is a distinct failure from "binary regression" — the binary was never updated, not degraded. Bot triage template: "package pinned since tag-binding date X" when TMS is running stale packages.

### P1-3: Staffing loss — ~50% capacity drop affecting oncall coverage

- Yabin left 2026-05-20
- Previously one more person left (mentioned by Li Lu: "lost 2 folks this half")
- Anthony Foiani: FRI also lost 50%+ (cross-org pattern)
- Denny: "lost about 50% of resource with the same and increased goals"

This directly affects oncall response time. Bot should apply lower urgency bar for MONITOR → PAGE escalation during this period (fewer people, slower response cadence expected).

---

## P2 — references / good-to-know

- **MRS OT support group** (Workplace): https://fb.workplace.com/groups/mrs.ot — correct channel for external users to report OT issues; oncall routes externally via this group
- **Managed Training Service user group**: https://fb.workplace.com/groups/280672176819805 — for TMS/PVR escalations; tag siyuan (oncall)
- **PVR doc**: https://docs.google.com/document/d/13cYrXCyMp4Y6NRVPhWYiHQdOC8C6vxt2SQLE_g23IF4/edit?tab=t.0
- **SLICK users group thread** (SLO removal process): https://fb.workplace.com/groups/slickusers/posts/2215468059265666
- D105893378 + D105890355 — Stop two weekly UBNs (i2i delta SLI m213207093 etc.); pending landing
- Yabin departure (2026-05-20) — third oncall team member lost this half; affects rotation coverage

---

## Cross-references

- S665521 (MAST scheduler metadata injection) — mentioned in rtinfra-ws2 catchup, confirmed in oncall space
- RES open question (Workplace post https://fb.workplace.com/groups/mrs.ot/permalink/1332204528874290/) — operator (Denny) has asked POCs Joey Yang/Zheng Qi to be looped in

---

## Open coordination threads

- **RES × sparse delta interaction** — POCs (Joey Yang, Zheng Qi) need to be looped into Hongzhang's Workplace post. Denny requested this 2026-05-23. Confirm looped in and resolution.
- **mvai_umia_v1_ifr recovery confirmed?** — TMS relaunched to v31. No follow-up in window. Confirm job is healthy.
- **D105893378 + D105890355 landing** — stopped by SLICK SLO gate. Status unclear. SLICK community guidance awaited.
- **Oncall rotation coverage with Yabin gone** — who is covering? Paul Lu is out today (2026-05-25). Li Lu + Denny carrying?

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | RES awareness: high sparse delta rate is EXPECTED on RES-enabled models | ot-alert-monitor: before paging for sparse delta frequency, check model_config for raw_embedding_streaming | 45 min |
| P0 | PVR package-pinning: add as failure class in triage | failure-patterns.md: "TMS package pinned at tag-binding date" pattern; escalate to managed_training_service oncall | 30 min |
| P0 | Terminology: replace "prod job" with "baseline job" in all triage output | All cron prompts that emit model job references | 20 min |
| P0 | SLICK SLO gate: warn on decommission diffs, no bypass workaround | ot-alert-monitor / UBN review: add SLICK gate warning | 20 min |
| P1 | Multi-OT-job check: use ai.mast-job list to find ALL jobs per model | ot-alert-monitor investigate step | 30 min |
| P2 | MRS OT support group URL in bot's "routing" knowledge | references: add https://fb.workplace.com/groups/mrs.ot as canonical support channel | 10 min |
