# IG/Threads Training — Escalation Matrix

Routing reference for OT bot diagnoses involving IG/Threads training jobs.

**Source wiki**: https://www.internalfb.com/wiki/IGML/IGML_Eng_Guide/OnCall/IG_Training_Job_Oncalls/IGML_Model_Authoring_Oncall_Runbook/
**Sourced**: 2026-05-07
**Re-check cadence**: quarterly. Wiki edits since the sourced date may shift routing — diff this file against the live wiki before relying on stale paths.

## L2 oncall for IG/Threads training health

**`ig_training_job_infra`** — IROC-style oncall, immediate response for IG/Threads training-job-health issues. NOT a long-horizon investigation owner.

Use when the SEV is:
- Crash / slowness / scheduling delay on IG or Threads training
- Failure-rate or example-age regression
- Snapshot cadence issue
- Urgent capacity intervention needed to unblock a critical job

Distinct from `mrs_online_training` (OT-specific MVAI orchestration) and from `routing.ig → dkotfis` (the OT-bot's existing IG escalation contact).

## Per-failure-type routing

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

## MB / QE engagement

**QE models running as MB jobs are treated as production** for immediate health issues. The bot's MB-pattern admit (MB3/MB6/MB6.5/MB8/OldTrunk) should NOT down-prioritize these as test-only.

Non-urgent MB investigations and optimization work belong to the long-term support path (Infra Chef coordination), not `ig_training_job_infra`.

## Priority order (when multiple signals fire)

1. Prod Online Training incidents
2. Prod recurring training incidents
3. QE incidents serving production traffic
4. Non-urgent follow-up

If prod SEV + QE SEV simultaneously, prod first.

## Useful tools cited in runbook

- `mvai rerun` — rerun a training job
- `mvai hot-patch` — hot-patch app or base layer
- `mvai generate-model-id`
- `mvai online-training-mgr` — manage OT jobs
- `bunnylol ji <job-name>` — JobInspector
- [OT health dashboard](https://fburl.com/unidash/o1di8kfa) — example age, streaming rate, job crashes; searchable by model ID or model type
- [GPU/DPP capacity management](https://fburl.com/mlhub/uccgiigy)

## Cited monitoring detectors

- [Scheduling delay detector 918523016850096](https://www.internalfb.com/monitoring/detector/918523016850096) — fires when p90 E2E wait time for prod MAST jobs > 2h in the last hour. Resolution path: check tenant-level wait time scuba (`https://fburl.com/scuba/ai_demand_control_job_score/wfcg1d0w`) → zoom tenant (`https://fburl.com/scuba/ai_demand_control_job_score/tei8qryp`) → MLHub hardware usage (`https://fburl.com/mlhub/o0zyc72v`).

## Cited skills

- `meta-ml` — overarching MAST job questions (failure, GPU mem, SM util)
- `mvai-ot` — OT failure investigations (stuck jobs, NCCL timeouts)
- `gpu-efficiency-regression-debug` — pinpoints QPS regression component (DPP starvation, torch compile, GPU mem snapshot)
- `model-registry` — IG-specific model metadata (prod/holdout, training job per model ID)
