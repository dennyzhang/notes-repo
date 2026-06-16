# Component Ownership & Escalation

Each team owns a pipeline stage. This file is the single routing reference for "who do I page?" decisions.

**IG/Threads escalation source wiki**: https://www.internalfb.com/wiki/IGML/IGML_Eng_Guide/OnCall/IG_Training_Job_Oncalls/IGML_Model_Authoring_Oncall_Runbook/
**Sourced**: 2026-05-07
**Re-check cadence**: quarterly. Wiki edits since the sourced date may shift routing — diff this file against the live wiki before relying on stale paths.

## Component Ownership

| Stage | Component | Team | Key Contact | Agent/Skill Code | Oncall |
|-------|-----------|------|-------------|------------------|--------|
| T1 | Scribe / DPP | DPP/MLDP | Nasrin Jaleel | *TODO: add pointer* | mldp_oncall |
| T2 | Training / MVAI | MVAI | Li Lu | [mvai-ot/reliability/](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/) | mrs_online_training |
| — | TMS (Job Orchestration) | AI Infra | Paul Lu | mvai-ot/reliability/diagnostics/tms-launch-errors.md | managed_training_service |
| T3 | Publishing / SilverTorch | SilverTorch | Shuguang Ye, Ziqi Liu | [silvertorch-item-freshness](https://www.internalfb.com/claude-templates/plugins/silvertorch-item-freshness) | home_ml_platform |
| T4a | Serving / Recsys | Recsys/IP Runtime | Hongbo Qin | [investigate-success-rate/](https://www.internalfb.com/code/fbsource/fbcode/ip_runtime/model_freshness/operation/streaming/investigate-success-rate/) | ip_runtime |
| T4b | Streaming / Hedwig | Hedwig | Qiuyu Xiao | *TODO: add pointer* | hedwig |
| — | Monitoring / PE (this is us) | PE MRS | Denny Zhang, Paul Lu | this skill | mrs_online_training |
| — | Data Science (advisory) | AI Infra DS | Jessica Wang | *TODO: add pointer* | — |

## Existing MVAI OT Reliability Skill (T2/T3 deep triage)

The master agent delegates T2/T3 deep dives to this existing skill (18 files):

| File | Purpose |
|------|---------|
| [triage.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md) | SEV triage workflow (IDENTIFY → LOCATE → INVESTIGATE → RESOLVE) |
| [monitoring.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/monitoring.md) | Publishing alert analysis, delta status verification |
| [knowledge.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/reference/knowledge.md) | 20+ real SEV patterns with root cause analysis |
| [dashboards.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/dashboards.md) | All dashboards and escalation contacts |
| [log_analyzer.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/diagnostics/log_analyzer.md) | MAST job log analysis patterns |
| [architecture.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/reference/architecture.md) | OT architecture and data flow |
| [cli.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/cli.md) | Full CLI command reference |
| [live-sev.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/live-sev.md) | First 5 minutes of live SEV response |

## Delegation — How This Skill Routes to Component Skills

| Component Issue | Delegated To | What They Own |
|----------------|-------------|---------------|
| Trainer crash, deadlock, NE regression | [mvai-ot/reliability/workflows/triage.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md) | Root cause analysis, checkpoint recovery, revert-and-ban |
| Publishing stall, snapshot health | [mvai-ot/reliability/operations/monitoring.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/monitoring.md) | GMPP logs, publish mode diagnosis |
| TMS job orchestration | TMS oncall (managed_training_service) | Auto-restart, registration, fbpkg lifecycle |
| Scribe/DPP data pipeline | DPP oncall (mldp_oncall) | Scribe delay, example age, data freshness |
| Hedwig streaming | Hedwig oncall (hedwig) | Message delivery, flow control, rate limits |
| Predictor/serving | Recsys oncall (ip_runtime) | Weight manager, snapshot transition, update rate |

If a team has an existing Claude skill, the master agent loads it for deep-dive analysis. If not, it routes to the human oncall with evidence.

## Per-Failure-Type Routing (IG/Threads)

**L2 oncall**: `ig_training_job_infra` — IROC-style oncall, immediate response for IG/Threads training-job-health issues. NOT a long-horizon investigation owner. Use for crash/slowness/scheduling delay on IG or Threads training, failure-rate or example-age regression, snapshot cadence issues, or urgent capacity intervention.

Distinct from `mrs_online_training` (OT-specific MVAI orchestration) and from `routing.ig → dkotfis` (the OT-bot's existing IG escalation contact).

| Failure surface | Escalate to | Notes |
|-----------------|-------------|-------|
| GPU starvation from data loading; DPP worker; DPP session; onbox/sidecar/reader | `mldp` | Cite which: client vs worker if known |
| Training-data freshness; FBJoiner/Muddler/Hulk; compute-side training-data infra | `igml_training` | — |
| Data region placement / replication | `di_tetris` | — |
| Shared MVAI stack failures (not DPP/publish/model-code/capacity) | `minimal_viable_ai` | — |
| OT-specific MVAI orchestration / OT system behavior | `mrs_online_training` | This bot's home rotation |
| Snapshot publish / checkpoint publish / publish pipeline / model-processing post-training | `model_processing` | — |
| **Retrieval-model publishing** (HSTU, U2I, T2I) | `silvertorch` | — |
| Checkpoint persistence / model metadata / UMM | `model_store` | — |
| PyTorch runtime issues clearly in framework/runtime | `pytorch` | — |
| `torch.compile` graph breaks / inductor / compile-time regression / TLParse | `PT2` | — |
| Training-side PyTorch/framework outside PT2 scope | `pytorch_training_enablement` | — |
| Scheduler behavior / execution-environment / resource assignment | `mast_optimizer` | — |
| Workflow-level FBLearner orchestration | `fblearner_flow` | — |
| Model config / model code / launch config / product-specific change | model-owner unixname (per `meta ai.model-series metadata`) | `ig_training_job_infra` still handles immediate mitigation |

## Full Cross-Org Oncall Map

| Component | Oncall | Workplace |
|---|---|---|
| SilverTorch / publishing / item embedding | [`home_ml_platform`](https://www.internalfb.com/omh/view/home_ml_platform/oncall_profile) | [Silvertorch](https://fb.workplace.com/groups/silvertorch) |
| In-Trainer Publisher (GMPP/TGIF) | [`model_processing`](https://www.internalfb.com/omh/view/model_processing) | [Model Processing Q&A](https://fb.workplace.com/groups/254777643194247) |
| TGIF-specific | `pytorch_inference_enablement_foa` | — |
| DPP frontend | [`mldp_oncall`](https://www.internalfb.com/omh/view/mldp_oncall) | [MLDP Users](https://fb.workplace.com/groups/mldp.users) |
| DPP backend | [`dpp`](https://www.internalfb.com/omh/view/dpp/oncall_profile) | — |
| Checkpoints / UMM | [`model_store`](https://www.internalfb.com/omh/view/model_store/oncall_profile) | [UMM](https://fb.workplace.com/groups/738862774242905) |
| Publishing IEN (lowering) | [`gpu_lowering`](https://www.internalfb.com/omh/view/gpu_lowering) | — |
| TMS / launch | [`managed_training_service`](https://www.internalfb.com/omh/view/managed_training_service) | [TMS Users](https://fb.workplace.com/groups/280672176819805) |
| Hedwig transport | [`downloads`](https://www.internalfb.com/omh/view/hedwig) | — |
| Streaming infra (not IROC) | `streaming_infra_oncall` | — |
| MLHub / IROC | `mlhub` | [MLHub Users](https://fb.workplace.com/groups/mlhub.users/) |
| Model stability metrics (SLICK) | `pe_mrs_ml` — POC **Clement Chang** (cchang; new POC as of 2026-06-12), backup **Anthony Foiani** (ajfoiani) | see [`../../metrics/slick-data-pipeline.md`](../../metrics/slick-data-pipeline.md) |

## Alert Routing — By Publishing-Stability Alert Type

After initial data-first triage, route to the component oncall by alert type:

| Alert Snapshot Type | Primary Oncall | Escalate If Infra |
|---|---|---|
| Full Snapshot (LSR + OT) | `mrs_online_training` | `model_processing` (GMPP/TGIF), `model_store` (checkpoint) |
| Full Snapshot (ESR/Retrieval) | `home_ml_platform` | `model_processing`, `model_store` |
| Dense/Sparse delta (`misc_deltas`) | `mrs_online_training` | `model_processing` (publisher), `streaming_infra_oncall` (transport) |
| **Item embedding delta (`item_embed_delta`)** | **`home_ml_platform`** | `streaming_infra_oncall` (Hedwig), `model_processing` (GMPP init) |

> **Key pitfall:** `item_embed_delta` routes to `home_ml_platform`, **not** `mrs_online_training`. SilverTorch owns the item-embedding delta generation pipeline (STUS).

## Alert Systems Architecture

| System | Config Location | # Alerts | Routes To |
|---|---|---|---|
| **IFR Watchtower** | `configerator/.../multifeed/.../ifr_ranking_online_training_monitor.observer` | 14 | mrs_online_training |
| **MVAI SWM** | `configerator/.../minimal_viable_ai/models/*/structured_workflow_monitoring.cinc` | ~64 | pe_mrs_ml |
| **MVAI OT Infra** | `configerator/.../minimal_viable_ai/alerts/infra/online_training/` | 3 | mrs_online_training |
| **MVAI Template Detectors** | `configerator/.../minimal_viable_ai/alerts/observers/` | ~20 | minimal_viable_ai |
| **Piranha/Conveyor** | `configerator/.../piranha/job_detectors/dts/observers/` | ~6 | mrs_online_training |

## Priority Order (When Multiple Signals Fire)

1. Prod Online Training incidents
2. Prod recurring training incidents
3. QE incidents serving production traffic
4. Non-urgent follow-up

If prod SEV + QE SEV simultaneously, prod first.

### MB / QE Engagement

QE models running as MB jobs are treated as production for immediate health issues. The bot's MB-pattern admit (MB3/MB6/MB6.5/MB8/OldTrunk) should NOT down-prioritize these as test-only.

Non-urgent MB investigations and optimization work belong to the long-term support path (Infra Chef coordination), not `ig_training_job_infra`.

## Product-Group Leads (Fleetwide Issues)

| Product | TL | Capacity Steward |
|---|---|---|
| Video / UDD | Yanhong Wu | Patrick Cullen |
| CFR | Wanli Ma | — |
| IFR | Luyi Guo | — |
| IG Reels / Feed | Gufan Yin, Xianjie Chen | — |
| Threads | Simeng Yang, Clay Wardell | — |

## Monitoring Detectors

- [Scheduling delay detector 918523016850096](https://www.internalfb.com/monitoring/detector/918523016850096) — fires when p90 E2E wait time for prod MAST jobs > 2h in the last hour. Resolution path: check tenant-level wait time scuba (`https://fburl.com/scuba/ai_demand_control_job_score/wfcg1d0w`) → zoom tenant (`https://fburl.com/scuba/ai_demand_control_job_score/tei8qryp`) → MLHub hardware usage (`https://fburl.com/mlhub/o0zyc72v`).

## Useful Tools

- `mvai rerun` — rerun a training job
- `mvai hot-patch` — hot-patch app or base layer
- `mvai generate-model-id`
- `mvai online-training-mgr` — manage OT jobs
- `bunnylol ji <job-name>` — JobInspector
- [OT health dashboard](https://fburl.com/unidash/o1di8kfa) — example age, streaming rate, job crashes; searchable by model ID or model type
- [GPU/DPP capacity management](https://fburl.com/mlhub/uccgiigy)

## Cited Skills

- `meta-ml` — overarching MAST job questions (failure, GPU mem, SM util)
- `mvai-ot` — OT failure investigations (stuck jobs, NCCL timeouts)
- `gpu-efficiency-regression-debug` — pinpoints QPS regression component (DPP starvation, torch compile, GPU mem snapshot)
- `model-registry` — IG-specific model metadata (prod/holdout, training job per model ID)
