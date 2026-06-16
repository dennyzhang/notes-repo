---
source: fbcode/claude-templates/components/skills/ot-reliability-health-check/SKILL.md
synced_by: ot-gdoc-context-sync (Part 2)
synced_at: 2026-06-07
source_sha16: d0ee49b33ef6f2da
note: AUTO-SYNCED from fbsource — do NOT edit by hand; overwritten on next sync.
---

---
name: ot-reliability-health-check
description: Use when user mentions OT reliability Health Checks, online training reliability, OT job health, snapshot freshness, training QPS issues, quality control checklist, or QC check for IG relevance models.
---

# OT Reliability Health Check

## Overview

Diagnose and monitor Online Training (OT) reliability for IG relevance models. Covers the full OT pipeline: job uptime, training throughput, checkpoint cadence, snapshot freshness, and streaming health. Also provides a Quality Control (QC) Checklist to validate OT model configurations.

## When to Use

- User mentions "OT reliability" or "online training reliability"
- User asks about OT job health, training QPS, or example age
- User asks about snapshot freshness (full or delta)
- User asks about streaming success rate or sparse streaming percentage
- User asks about checkpoint cadence or model staleness
- User asks to run a "QC check", "quality control checklist", or "config validation" for an OT model

## Key Concepts

### Model Hierarchy

| Concept | Description |
|---------|-------------|
| **Root Model** | The trained base model (user + item towers). Produces checkpoints consumed by downstream models. |
| **SilverTorch (ST) Model** | Inference model derived from root model. Bundles user tower + pre-computed item embeddings for serving. |
| **Upstream Model** | Any model a downstream depends on (feature, score, ST root, reranker). Defined in `UpstreamModelDependency` union in `configerator/structs/ai/model_registry/types.thrift`. |

### OT Pipeline Stages

1. **Training** — Root model consumes data from Scribe, trains continuously
2. **Checkpointing** — Periodic checkpoint saves (e.g., every 1hr for Reels LSR, every 50min for Reels ESR)
3. **Full Snapshot Publish** — Checkpoint packaged into a full snapshot and deployed to predictors
4. **Delta Snapshot Streaming** — Incremental updates (dense delta, sparse delta, item delta) streamed at higher cadence

### Model Type Mapping

| Model Type | Description |
|------------|-------------|
| `ig_reels_tab_mtml` | Reels LSR |
| `ig_reels_tab_esr_ttsn` | Reels ESR |
| `ig_organic_feed_mtml` | Feed LSR |
| `ig_reels_tab_vm_esr` | Reels VM ESR |

---

## Prerequisites

Before running any workflow, ensure the following CLI tools are available:

- **`meta` CLI**: Required for fetching MAST job metadata (`meta ai.mast-job`). Check with `which meta`. If not installed:
  ```bash
  devfeature install meta --persist
  ```
- **`mast` CLI**: Required for fetching MAST job definitions (`mast get-job-definition`). Check with `which mast`. If not installed:
  ```bash
  devfeature install mast_cli --persist
  ```
- **`chug` CLI**: Required for fetching trainer configs. Check with `which chug`. If not installed:
  ```bash
  devfeature install chug --persist
  ```

---

## Model Resolution (Shared Prerequisite)

All workflows below (Reliability Monitoring and QC Checklist) require resolving the input model ID to the actual OT root model and deriving the MAST job name. Execute this first.

### 1a. Query Model Registry and Resolve to Root OT Model

**Step 1: Fetch model metadata** using the `presto-query` skill:

```sql
SELECT
    model_id,
    model_type_name,
    oncall_shortname,
    upstream_model_ids,
    downstream_model_ids
FROM instagram.ig_model_registry
WHERE
    ds = CAST(CURRENT_DATE - INTERVAL '1' DAY AS VARCHAR)
    AND model_id = <input_model_id>
```

**Step 2: Load the model's configerator cconf** using the `knowledge_load` MCP tool to get accurate upstream dependencies:

```
https://www.internalfb.com/code/configerator/source/ai/model_registry/ig/<model_type>/models/<model_id>.cconf
```

Where `<model_type>` is from the Presto query (e.g., `ig_reels_tab_mtml`) and `<model_id>` is the input model ID. If the model type is unknown, try common types from the Model Type Mapping table above.

**Step 3: Resolve to root OT model** by parsing the cconf's `ModelMetadata.upstream_model_dependencies` section. Each entry is an `UpstreamModelDependency` object with a key indicating the dependency type.

**Resolution logic based on dependency key:**

| Dependency Key | Action |
|---------------|--------|
| `st_root` | This is the SilverTorch root model. Use this upstream model ID as the resolved OT root model for all QC checks. |
| Other keys (e.g., `feature_model`, `reranker`, `score_model`) | These are **non-ST upstream models**. Do NOT resolve through them to find a different root. Instead, keep the original input model ID and run the full QC checklist against it as-is. |

**Example cconf structure:**
```
upstream_model_dependencies=[
    UpstreamModelDependency(st_root=DependentModel(model_id=123456))
    UpstreamModelDependency(feature_model=DependentModel(model_id=789012))
    UpstreamModelDependency(reranker_model=DependentModel(model_id=345678))
]
```

In the example above, `123456` is the ST root model (key `st_root`) — resolve to it. `789012` (feature_model) and `345678` (reranker_model) are non-ST upstream models — ignore them for root resolution purposes.

**Resolution summary:**

1. If the cconf has `upstream_model_dependencies` with an `st_root` entry, use the `st_root` model ID as the resolved model for all QC checks.
2. If the cconf has no `upstream_model_dependencies`, or no `st_root` key (only non-ST upstreams like `feature_model`, `reranker`), use the input model ID as-is for QC checks.
3. **Fallback:** If `knowledge_load` fails or the cconf does not exist, use the input model ID as-is for QC checks.

### 1b. Derive MAST Job Name

```
mvai-training-online-<resolved_model_id>
```

This job name is used for Scuba queries, ODS metric lookups, and MAST job inspection throughout all workflows.

### 1c. Fetch Latest MAST Job Version

```bash
meta ai.mast-job metadata --name=mvai-training-online-<resolved_model_id> --output=json
```

Parse the JSON output and extract the `version` field. Store as `MAST_JOB_VERSION`.

If the command fails or `version` is not found, default to `MAST_JOB_VERSION = 0`.

### Output

```
=== Model Resolution ===

| Field              | Value                                        |
|--------------------|----------------------------------------------|
| Input Model ID     | <input_model_id>                             |
| Resolved Model ID  | <resolved_model_id>                          |
| Model Type         | <model_type_name>                            |
| Oncall             | <oncall_shortname>                           |
| Resolution         | <SilverTorch → upstream / Root OT / Normal>  |
| MAST Job Name      | mvai-training-online-<resolved_model_id>     |
| MAST Job Version   | <MAST_JOB_VERSION>                           |

========================
```

## Telemetry

After resolving the model identity above, immediately run this command before proceeding to any workflow:

```bash
printf 'OT_SKILL_TELEMETRY|%s|%s|%s|%s\n' \
  'ot-reliability-health-check' '<resolved_model_id>' 'ALL' '<model_type_name>'
```

---

## Reliability Monitoring

Use these data sources and checklist to monitor OT pipeline health.

### Data Sources

#### Hive Tables (Presto)

| Table | Namespace | Purpose |
|-------|-----------|---------|
| `ig_model_registry` | `instagram` | Model metadata, upstream/downstream dependencies. One row per `(model_id, model_type_name)`. |
| `ig_all_models` | `instagram` | Enriched wide table with traffic, training, deployment info. One row per `model_id`. |

#### Scuba Datasets

| Dataset | Purpose | Key Columns |
|---------|---------|-------------|
| `mast_hpc_job_run_status` | OT job failures | `job_name`, `job_version`, `job_failure_type`, `job_type` |
| `dai_modelstore` | Checkpoint cadence | `model_entity_id`, `event` (filter: `CheckpointSaveSuccess`), `version` |
| `sigrid_predictor` | Full & delta snapshot age | `model_entity_id`, `tier`, `full_snapshot_model_age`, `dense_delta_model_age`, `sparse_delta_model_age`, `item_embedding_cache_model_age` |
| `runtime_freshness` | Streaming success rate | `model_entity_id`, `event_type`, `snapshot_types`, `control_plane_type`, `num_messages_applied`, `num_messages_sent` |
| `gmpp` | Sparse streaming % | `event_type` (filter: `TensorStreamingSessionStatsInfo`), `model_entity_id`, `additional_fields` |

#### ODS / Tetrahedra Metrics

| Metric | Entity Pattern | Key |
|--------|---------------|-----|
| OT Job Uptime | `regex(.*mvai-training-online-<MODEL_ID>.trainer.*/0)` | `tw.container.uptime` |
| Training QPS | `regex(mast.mvai-training-online-<MODEL_ID>.*.dpp_worker..*)` | `dpp_worker.num_examples_read.sum.60` |
| Example Age | `regex(mast.mvai-training-online-<MODEL_ID>.*.dpp_worker.*)` | `dpp_worker.scribe_example_age_ms.avg.60` |


---

## Quality Control Checklist

When the user asks to run a QC check, quality control checklist, or config validation for a model, execute this workflow.

### Input

- **Model ID** (required) — numeric model entity ID

**Prerequisite:** Complete **Model Resolution** above first. If the model is not found in `ig_model_registry` (primary) AND not found via `knowledge_load` MCP at `https://www.internalfb.com/code/configerator/source/ai/model_registry/ig/<model_type>/models/<model_id>.cconf` (fallback), **stop the entire flow** and report: "Model not found in Model Registry or configerator cconf. Cannot proceed with QC checks."

### QC Step 1: Fetch Config Sources

Fetch all three config sources **in parallel**. Each is independent — if one fails, the others still proceed.

**1a. Runtime Trainer Config** — PRIMARY source for Checks 1, 2.

Fetch the runtime trainer config using the chug CLI `fetch-mvai-trainer-config` subcommand, which implements a **three-tier resolution strategy**:

1. **Primary (AIX run metadata)** — queries AIX for the trainer config paste ID logged at job resolution time. Does NOT depend on checkpoints.
2. **Fallback 1 (MAST applicationMetadata)** — checks `mvai_trainer_config` key in MAST job metadata.
3. **Fallback 2 (checkpoint)** — uses `model_entity_id` → UMM Checkpoint → `serialized_job` paste.

**How to run:**

**Note:** The `chug` CLI is distributed via `devfeature`. If `chug` is not found, install it first:
```bash
devfeature install chug --persist
```

```bash
chug ot-utils fetch-mvai-trainer-config \
    --job-name mvai-training-online-<resolved_model_id> \
    --job-version <MAST_JOB_VERSION> \
    --output /tmp/mvai_trainer_config_<model_id>.json
```

This saves the config JSON to `/tmp/mvai_trainer_config_<model_id>.json`.

**After fetching, the config JSON can be 10K+ lines.** Do NOT load the entire content into context. Instead:
1. Save the output to a temp file: `/tmp/mvai_trainer_config_<model_id>.json`
2. Extract only the `trainer_config` key (~300 lines) using `jq`:
   ```bash
   jq '.trainer_config' /tmp/mvai_trainer_config_<model_id>.json
   ```
3. Load the `trainer_config` output into context — it contains all fields needed for Checks 1, 2:
   - `.config.data_source_config` — Scribe lookback, QPS cap (Checks 1, 2)

This CLI output does **not** include `--params-to-update` command-line arguments. Use the MAST rerun command in Step 1b as the source for Check 4.

If the MAST job doesn't exist or the paste can't be resolved, mark `runtime_config_available = false`. Checks 1, 2 will be **SKIP**ped.

**1b. MAST Rerun Command** — Source for Check 4.

Extract the rerun command paste ID from the MAST job definition, then resolve it:

```bash
# Step 1: Get rerun_cmd_line paste ID from job definition
mast get-job-definition mvai-training-online-<resolved_model_id> --tier=PROD --job-version <MAST_JOB_VERSION> | grep "rerun_cmd_line"
# Output: "rerun_cmd_line" -> "P1234567890"

# Step 2: Resolve the paste using knowledge_load MCP tool
# URL: https://www.internalfb.com/phabricator/paste/view/P<paste_id>
```

Store the resolved paste content as `RERUN_CMD`. This is the full `fire` CLI command used to launch the job, containing `--params-to-update` with UVM caching settings.

If the job definition doesn't contain `rerun_cmd_line` or the paste can't be resolved, mark `rerun_cmd_available = false`. Check 4 will be **SKIP**ped.

**1c. TMS Configerator cconf** — Source for Check 5.

Fetch the cconf file from **configerator master** using the `knowledge_load` MCP tool with this URL template:

```
https://www.internalfb.com/code/configerator/source/aiplatform/training_launch_service/models/<model_id>.cconf
```

**IMPORTANT:** TMS cconf files live in the **configerator** repo, which is separate from **fbsource**. The following approaches will NOT work:
- `search_files` MCP — searches fbsource, not configerator
- Local filesystem search (`find`, `ls`) — sparse checkout may not have the file
- `sl cat` from fbsource — configerator subtree in fbsource may not reflect configerator master

Always use `knowledge_load` MCP with the `internalfb.com/code/configerator/...` URL to reliably fetch from configerator master.

If `knowledge_load` returns an error or the file does not exist, mark `cconf_available = false`. Check 5 will automatically **FAIL** (model is not registered in TMS).


### QC Step 2: Run 6 Checks

Run checks **in parallel by data source group**. Use the `Agent` tool to run groups concurrently.

| Group | Data Source | Checks | Requires |
|-------|------------|--------|----------|
| **A** | Runtime trainer config (QC Step 1a) | 1 (Scribe Lookback), 2 (QPS Cap) | `runtime_config_available` |
| **B** | MAST rerun command (QC Step 1b) | 4 (UVM Caching), 6 (Hardware Type) | `rerun_cmd_available` |
| **C** | TMS cconf (QC Step 1c) | 5 (TMS Registration) | `cconf_available` |
| **D** | Scuba | 3 (Weekly Crashes) | Always runs |

Status values: **PASS**, **FAIL**, **WARN**, **SKIP** (when data source unavailable).

---

#### Check 1: Scribe Lookback Window

**Source:** Runtime trainer config (QC Step 1a) → `trainer_config.config.data_source_config`

**Fields to check:**
- `scribe_reader_catchup_sec` — the lookback window in seconds (the value you see in the runtime config)
- `scribe_reader_catchup_sec_compute_mode` — controls how `scribe_reader_catchup_sec` was resolved before it was written to the runtime config. Possible values: `always_try` (default) or `no_op`.

**Background:** The `scribe_reader_catchup_sec` in the runtime config may have been dynamically overwritten by the job resolver (`job_resolver.py::_resolve_scribe_data_source`). When `scribe_reader_catchup_sec_compute_mode` is `always_try`, the resolver computes `min(configured_value, current_time - last_trained_timestamp)`, so the runtime value is typically less than the configured cap. When `no_op`, the configured value is used as-is.

**Check logic** (treat missing `scribe_reader_catchup_sec_compute_mode` as `always_try`):

1. If `scribe_reader_catchup_sec > 7200` → **FAIL** (regardless of mode)
2. If `scribe_reader_catchup_sec_compute_mode` is `always_try` (or missing) and `scribe_reader_catchup_sec <= 7200` → **PASS**
3. If `scribe_reader_catchup_sec_compute_mode` is `no_op` and `scribe_reader_catchup_sec == 7200` → **PASS**
4. If `scribe_reader_catchup_sec_compute_mode` is `no_op` and `scribe_reader_catchup_sec != 7200` → **FAIL**

Reference: D91744526, `fbcode/minimal_viable_ai/core/trainer/job_resolver.py`

---

#### Check 2: QPS Cap Configured

**Source:** Runtime trainer config (QC Step 1a) → `trainer_config.config.data_source_config`

**Fields:**
- `qps_throttling_config` — should contain a `QPSThrottlingConfig`
- `maxScribeRowsRead` within `QPSThrottlingConfig` — should be > 0

| Criteria | Status |
|----------|--------|
| `qps_throttling_config` set AND `maxScribeRowsRead > 0` | PASS |
| `qps_throttling_config` is None or not found | FAIL |

Reference: D92300013 (OneFeed MB7 QPS cap)

---

#### Check 3: Weekly Crash Aggregation

**Source:** Scuba (independent of other config sources)

**Primary query** using `scuba` skill:

```
Dataset: mast_hpc_job_run_status
Time range: last 7 days
Filters: job_name LIKE 'mvai-training-online-<MODEL_ID>%', state IN ('DEAD', 'FAILED')
Group by: job_failure_type, error_traits_category
Columns: job_name, attempt_index, job_version, normalized_message, source_failure_message
Aggregation: COUNT(*)
```

**Fallback** if primary returns no data:

```
Dataset: training_platform_model_events
Time range: last 7 days
Filters: model_entity_id = <MODEL_ID>, event_type = 'FAILURE'
Group by: failure_reason
Aggregation: COUNT(*)
```

| Criteria | Status |
|----------|--------|
| 0 crashes | PASS |
| 1-2 crashes | WARN — note failure types |
| 3+ crashes OR same failure pattern >1 time | FAIL |

**Output format:** In addition to the error category summary, return a **detailed table of all individual failed jobs** from the past week:

```
Failed Jobs (last 7 days):

| Job Name | Attempt Index | Job Version | Failure Type | Error Category | MAST Link |
|----------|---------------|-------------|--------------|----------------|-----------|
| <job_name> | <attempt_index> | <job_version> | <failure_type> | <error_category> | https://www.internalfb.com/mlhub/pipelines/runs/mast/<job_name>?job_attempt=<attempt_index>&version=<job_version>&tab=definition&env=PRODUCTION |
| ... | ... | ... | ... | ... | ... |
```

**MAST link format:**
```
https://www.internalfb.com/mlhub/pipelines/runs/mast/<job_name>?job_attempt=<attempt_index>&version=<job_version>&tab=definition&env=PRODUCTION
```

Each row in the table should include a clickable MAST link constructed from the job's `job_name`, `attempt_index`, and `job_version` fields.

---

#### Check 4: UVM Caching Enablement

**Source:** MAST rerun command (QC Step 1b) → `RERUN_CMD`

Check if the `RERUN_CMD` string contains `"TBE_LOCATION_OVERRIDE": "UVM_CACHING"` (within the `--params-to-update` JSON).

| Criteria | Status |
|----------|--------|
| `RERUN_CMD` contains `"TBE_LOCATION_OVERRIDE": "UVM_CACHING"` | PASS |
| `"TBE_LOCATION_OVERRIDE"` not found or set to a different value | WARN |

---

#### Check 5: TMS Registration Completeness

**Source:** TMS cconf (QC Step 1b)

**Required fields** in `OnlineTrainingJobConfig`:
- `launch_config.launcher_package` — not empty
- `launch_config.command_arguments` — not empty
- `launch_config.owner_unixname` — not empty
- `launch_config.oncall` — not empty
- `launch_config.entitlement` — not empty
- `launch_config.data_project` — not empty
- `--model-entity-id` in command args
- `--publish-model-entity-id` in command args (if applicable)
- `--model-type` in command args

**Also check TMS state** via `mvai online-training-mgr print -m <model_id>` — should be `ONLINE_READY` or `RUNNING`.

| Criteria | Status |
|----------|--------|
| All required fields populated, TMS state = ONLINE_READY or RUNNING | PASS |
| cconf not found (not registered in TMS) | FAIL |
| Any required field missing or unexpected TMS state | FAIL |

---

#### Check 6: Hardware Type Validation

**Source:** MAST rerun command (QC Step 1b) → `RERUN_CMD`

**Background:** Using `TC_ANY` or `TC_ANY_80G` as the `--hardware` flag in OT fire_args allows MAST to schedule the job on any available hardware type. This caused SEV S649226 when a job was placed on incompatible hardware after a restart. All prod OT jobs must specify a concrete hardware type (e.g., `GRANDTETON`, `GRANDTETON_B200`, `ZIONEX_80G`, `SMC_A100_80GB`).

**Check logic:**

1. Extract all `--hardware <value>` flags from `RERUN_CMD`
2. Check if any value matches `TC_ANY` or `TC_ANY_80G` (case-insensitive)

| Criteria | Status |
|----------|--------|
| All `--hardware` values are specific types (no `TC_ANY` variants) | PASS |
| Any `--hardware` value is `TC_ANY` or `TC_ANY_80G` | FAIL |

**Recommendation on FAIL:** Replace `TC_ANY_80G` with a specific hardware type matching the model's requirements. Common mappings: `ZIONEX_80G` (A100 80GB), `GRANDTETON` (H100), `GRANDTETON_B200` (B200), `SMC_A100_80GB` (A100 80GB SuperMicro). Update the `run_config.py` and relaunch the OT job to regenerate the TLS config.

Reference: S649226, T269415458

---

### QC Step 3: Generate Report

Present the full report using **table format** for every section to improve readability and visualization.

```
=== OT Quality Control Report for Model <model_id> ===
Checked at: <timestamp>

--- Model Info ---

| Field              | Value                                        |
|--------------------|----------------------------------------------|
| Model ID           | <model_id>                                   |
| Model Type         | <model_type_name>                            |
| Oncall             | <oncall_shortname>                           |
| Resolved Model ID  | <resolved_model_id>                          |
| Resolution         | <SilverTorch → upstream / Root OT / Normal>  |
| MAST Job Name      | mvai-training-online-<resolved_model_id>     |

--- Config Sources ---

| Config Source              | Status    | Reference                                                                 |
|----------------------------|-----------|---------------------------------------------------------------------------|
| Runtime trainer config     | <status>  | Paste: P<paste_id> / not found                                           |
| MAST rerun command         | <status>  | Paste: P<paste_id> / not found                                           |
| TMS cconf (master)         | <status>  | https://www.internalfb.com/code/configerator/source/aiplatform/training_launch_service/models/<model_id>.cconf / not found |
| Model registry cconf       | <status>  | https://www.internalfb.com/code/configerator/source/ai/model_registry/ig/<model_type>/models/<model_id>.cconf / not found |

--- QC Check Results ---

| # | Check                     | Status | Details                      |
|---|---------------------------|--------|------------------------------|
| 1 | Scribe Lookback           | PASS   | 7200s, no catch_up_strategy  |
| 2 | QPS Cap                   | FAIL   | Not configured               |
| 3 | Weekly Crashes            | WARN   | 2 crashes (OOM x1, NCCL x1) |
| 4 | UVM Caching               | PASS   | 10%, FixedPercentage         |
| 5 | TMS Registration          | PASS   | All fields present           |
| 6 | Hardware Type             | PASS   | GRANDTETON_B200              |

--- Summary ---

| Result | Count |
|--------|-------|
| PASS   | X/6   |
| WARN   | Y/6   |
| FAIL   | Z/6   |
| SKIP   | W/6   |

--- Weekly Crash Details (Check 3) ---

If Check 3 found any crashes, include the full failed jobs table here:

| Job Name | Attempt Index | Job Version | Failure Type | Error Category | MAST Link |
|----------|---------------|-------------|--------------|----------------|-----------|
| <job_name> | <attempt_index> | <job_version> | <failure_type> | <error_category> | https://www.internalfb.com/mlhub/pipelines/runs/mast/<job_name>?job_attempt=<attempt_index>&version=<job_version>&tab=definition&env=PRODUCTION |

--- Recommendations ---

| Priority | Check | Action                                   |
|----------|-------|------------------------------------------|
| FAIL     | 2     | Add QPS cap. See D92300013.              |
| WARN     | 3     | Investigate 2 crashes last week.         |
| SKIP     | X,Y   | <reason for skip>                        |

=========================================================
```

### QC Data Source Summary

| Data Source | How to Access | Used By |
|-------------|---------------|---------|
| Model registry | Presto: `instagram.ig_model_registry` | QC Step 0 |
| Runtime trainer config | `chug` CLI: `ot-utils fetch-mvai-trainer-config` (three-tier resolution) | Checks 1, 2 |
| MAST rerun command | `mast get-job-definition` → `rerun_cmd_line` paste → `knowledge_load` MCP | Checks 4, 6 |
| TMS cconf | `knowledge_load` MCP: `https://www.internalfb.com/code/configerator/source/aiplatform/training_launch_service/models/<model_id>.cconf` | Check 5 |
| Crash data | Scuba: `mast_hpc_job_run_status` | Check 3 |
