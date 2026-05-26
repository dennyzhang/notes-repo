# 2026-05-25 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 42 human messages spanning 2026-05-18T16:20 → 2026-05-21T14:07 in **MVAI OT Dev** (8 members; primary contributors: Anthony Foiani (17), Paul Lu (11), Denny Zhang (10), Li Lu (2))._

_Window: 7d delta (last_msg_create_time: 2026-05-18T10:36:00 PDT). Skip-until: not set (active polling)._

---

## P0 — bot-integration-blocking items

### P0-1: OT metadata in MRS Model Registry — active design work, data model owner assigned

**Decision in progress**: Denny + Anthony Foiani are designing `OTModelMetadata` to be added to the MRS Model Registry thrift. Proposed fields:

- `is_online_training: bool`
- `enabled_X_delta: bool` (where X = sparse / dense / item_embed)
- `training_paradigm_type: enum`

**Placement decision (unresolved):** Anthony Foiani: goes in `ModelMetadata` (stored in `model_id.cconf`) OR `ModelTypeMetadata` (in `model_type/model_type_metadata.cconf`). Not yet decided. SLOs in MRS MR also undecided (type-level vs id-level).

**Owners**: Anthony Foiani = data model + store. Denny = data generation + use-case integration.

**Model Registry thrift structs reference:**
`https://www.internalfb.com/code/configerator/[5733caf43c72fb7e261a6fe932f1da69814b57ac]/source/ai/model_registry/types.thrift`
*(Note: frozen hash — may need to navigate to head for current version)*

**IG MR as reference:** Anthony: *"If you don't like what you find in MRS MR, take a look at IG's MR, they have been at it longer."*

**Bot integration:** once OTModelMetadata lands, bot's triage chain can use MR as canonical source for `is_online_training`, delta types, and training_paradigm. Currently bot infers this from job names and MAST metadata. MR will be the official source.

### P0-2: Canonical snapshot type enum — 4 confirmed types, Denny to create thrift diff

Anthony Foiani confirmed 4 snapshot types:
- `FULL_SNAPSHOT`
- `SPARSE_DELTA`
- `DENSE_DELTA`
- `ITEM_EMBED_DELTA`

(Others may exist — Denny confirmed "Snapshot type - this already exists" for some; enum is being formalized.) Denny offered to create the thrift diff for the enum.

**Bot integration:** ot-alert-monitor and triage prompts should use these 4 canonical type names when classifying alert subtypes. Ensure `ITEM_EMBED_DELTA` is recognized alongside `SPARSE_DELTA` / `DENSE_DELTA`.

### P0-3: Oncall scope decision — support only 1 baseline per model_type (pending)

Paul Lu (2026-05-21): reviewed Video models in SLICK. Findings:
- Multiple baseline models per model_type (not 1)
- Holdouts and launch candidates also in monitoring scope
- **With only 3 people in oncall**: "we can only support the baselines, and even then maybe just 1 baseline per model_type"

This is unresolved — no formal decision yet. Paul scheduled a meeting with Anthony Foiani to discuss.

**Bot integration:** if this policy lands, bot's monitoring scope for Video models should restrict to `tier=baseline` only. Holdouts and LCs become low-priority (`MONITOR` at best) until scope decision is finalized.

---

## P1 — significant nuance / sub-mechanisms

### P1-1: Multiple OT jobs per inference model — bot may undercount

Paul Lu confirmed: for some models, root trainer → inference trainer pattern applies:
- Root model trainer streams SPARSE_DELTA to the inference model id
- Inference model trainer produces ITEM_EMBED_DELTA

These are separate OT jobs feeding the same inference model. Bot currently assumes 1 OT job per model. This assumption is WRONG for multi-publisher models.

**Evidence path for bot:** when `ai.model-series describe` returns multiple publisher jobs, treat them as a combined health signal — ALL must be healthy for model to be healthy.

### P1-2: MRS baselines are "a mess" vs IG's "1 baseline per model" discipline

Anthony Foiani: IG follows "one baseline per model" practice, which makes support tractable. MRS has multiple baselines per model_type, making it harder to support at scale. Paul: discussed with Archis previously.

**Bot routing note:** when triaging MRS models, verify which model_id is the *actual* baseline (via `model_type_metadata.cconf`) before assuming the first model_id encountered is baseline.

### P1-3: S665454, S665478 — stuck jobs under investigation (2026-05-19)

Paul Lu investigated two stuck jobs (S665454, S665478) on 2026-05-19. These appear related to PVR package locking (detailed in mrs-ot-oncall catchup). Paul also mentioned "reliability agent changes" as a concurrent work item.

---

## P2 — references / good-to-know

- **[WIP] MRS ML Infra Model Generation Stability doc** (Paul Lu, 2026-05-20):
  `https://docs.google.com/document/d/1g1QI0eTAigdgxroD0Sp1CTT8nFHlZkzSmnqba1S-LA8/edit`
  Tab 2 = consolidated model list to monitor. Denny left comments.
  
- Anthony Foiani (FRI context): *"FRI also lost 50+%, and we're currently figuring out what that means for support (both quantity and quality)."* → cross-team headcount reduction affecting support scope across multiple orgs.

- Paul Lu is **out today (2026-05-25, Memorial Day)** — taking day off in lieu of holiday travel.

- **"Cattle not pets" principle** (Anthony): standardizing models (same streaming intervals, same paradigm within class) would allow supporting more models with fewer people. Currently models are "snowflakes."

---

## Cross-references

- S665454, S665478 (stuck jobs) — see mrs-ot-oncall for more context on PVR package locking
- OTModelMetadata design affects ot-alert-monitor's ability to query model type metadata canonically

---

## Open coordination threads

- **OTModelMetadata placement (model_id vs model_type level)** — Anthony + Denny design call scheduled but unresolved. Operator should follow up.
- **Oncall scope for Video models** — Paul Lu + Anthony Foiani calendar meeting placed (2026-05-21 or later). Decision: baseline-only monitoring or broader? Unresolved.
- **MRS SLO final form** — Anthony: "not yet decided" on model_type vs model_id level for SLOs in MRS MR.
- **Snapshot type enum thrift diff** — Denny volunteered to create; confirm status.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | MR as canonical source for is_online_training + delta types | ot-alert-monitor: after OTModelMetadata lands, query MR before inferring from job names | 1h |
| P0 | Multi-publisher model: treat all OT jobs feeding same inference model as combined health | ot-alert-monitor triage: if model has multiple publisher jobs, ALL must be healthy | 30 min |
| P0 | 4 canonical snapshot types (incl ITEM_EMBED_DELTA) in triage vocabulary | failure-patterns.md + ot-alert-monitor: standardize on 4 type names | 20 min |
| P1 | Baseline lookup chain: model_type → model_type_metadata.cconf → baseline model_id | ot-alert-monitor investigate step: use MR chain, not first model_id seen | 30 min |
| P2 | WIP stability doc bookmarked as reference for model scope | notes/references: add gdoc link | 10 min |
