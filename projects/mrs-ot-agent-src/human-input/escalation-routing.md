# OT-Specific Escalation Routing Table

> **For the generic escalation discipline** (when, how, what to include, anti-patterns, message template): see [`~/notes/users/dennyzhang/cheatsheets/oncall/escalation.md`](../../../cheatsheets/oncall/escalation.md).
>
> This file holds OT-domain routing DATA: per-symptom → which oncall, OT-specific Scuba/ODS queries, OT-specific lessons. Use alongside the generic cheatsheet.

---

## Symptom → Team Routing (OT-specific)

| Symptom | Check This First | If Confirmed → Team | Oncall |
|---------|------------------|---------------------|--------|
| High example age, multiple jobs | `scribe_read_proxy.client_lag_in_seconds` per job | DPP (consumer lag) | `dpp_worker` |
| High example age, single job | DPP starvation ODS + job config (worker count, threads) | DPP or model owner (config) | `dpp_client` |
| Scribe write QPS drop | `ptail_flow.<category>.output.lines.rate.60` | Scribe / upstream producer | `scribe` |
| Scribe category-level ingestion lag spike | `rfe.sli.<category>.ingestion_lag_ms` | ScribeOne / LogDevice | `logdevice` |
| MAST job PENDING, never scheduled | MAST attempts list (all PENDING, none RUNNING) | MAST scheduler | `di_tetris` / `mast_optimizer` |
| MAST job killed: `reading data not specified in tetrisArgs` | fire_args missing/incomplete table declarations | Tetris (data-locality) — fix in fire_args, see [`tetris.md`](tetris.md) | `di_tetris` |
| MAST job won't schedule: `empty regionSelectionArgs.tetrisArgs` | fire_args have no `--table-namespace`/`--table-name`/`--partition-str` | Tetris — declare reads in fire_args, see [`tetris.md`](tetris.md) | `di_tetris` |
| Publishing stall, no new snapshots | UMM model instance records + GMPP logs | SilverTorch / model_processing | `home_ml_platform` |
| Streaming success drop | Hedwig rate limit / stream dispatch errors | Hedwig | `hedwig` |
| Permission errors across all ranks | Koski/AclChecker errors in trainer logs | Auth infra | `acl_checker` |
| `Async publish process creation failed!` | MAST attempt-0 error + active Scribe SEVs | Publish-side (S667071-class) | `home_ml_platform` + scribe owner |
| FULL_SNAPSHOT stuck in CREATING (mode A zombie) | `meta ai.model.instance list` shows size=0 | model_store | `model_store` |
| Duplicate alerts for same model_id | `meta oncall.feed list` reveals 2 alert_ids with `[holdout]` | model_store observer config | `model_store` |

## The Per-Job vs Category-Level Trap (OT canonical example)

This is the most common OT misdiagnosis. From S665454 (2026-05-21):

| Metric | Level | Value | What It Tells You |
|--------|-------|-------|-------------------|
| `rfe.sli.ingestion_lag_ms` | Category aggregate | 12–15 sec | Scribe/LogDevice is healthy |
| `scribe_read_proxy.client_lag_in_seconds` | Per DPP worker | 1,000–5,500 sec (16–92 min) | DPP workers are the bottleneck |

If you only checked the category-level metric, you'd conclude "scribe is fine" and stop. The per-job metric revealed the actual 92-minute lag.

**OT-specific rule:** When example age is elevated, ALWAYS check per-job `scribe_read_proxy.client_lag_in_seconds` before concluding scribe is healthy. (This rule is encoded in the OT master agent's P51 probe — see `~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/known_patterns.md` P51 + `src/sources/scribe_lag.py`.)

## How to Find Scribe Category for a Job

Not always visible in MAST UI (especially SilverTorch-path jobs — see T272462228).

```bash
# Step 1: Get the rerun paste ID
meta ai.mast-job metadata --name=<JOB> -o json | \
  python3 -c "import json,sys; md=json.loads(json.load(sys.stdin)['application_metadata']); print(md.get('rerun_cmd_line','N/A'))"

# Step 2: Read the paste, find --scribe-categories
pastry <PASTE_ID> | grep -o '\-\-scribe-categories [^ ]*'
```

## Key Scuba / ODS Queries

### Per-job DPP read lag (P51 canonical query)

```
dataset: scribe_read_proxy
metric: p95(client_lag_in_seconds), max(client_lag_in_seconds)
dimensions: category
filters:
  client_tw_job_name = <MAST_JOB_NAME>
  (optional) category = <SCRIBE_CATEGORY>
time: -1 hour
output: --output=json
```

CLI form:

```bash
meta scuba.dataset query --dataset=scribe_read_proxy \
  --aggregate=p95 --columns=client_lag_in_seconds \
  --aggregate-list='[{"column":"client_lag_in_seconds","op":"max"},{"column":"client_lag_in_seconds","op":"count"}]' \
  --group-by=category \
  --where='[{"column":"client_tw_job_name","op":"eq","values":["<JOB>"]}]' \
  --hours=1 --output=json
```

### Scribe write health (category-level)

```bash
meta ods.metric query \
  --entity "ptail_flow.<SCRIBE_CATEGORY>" \
  --key "output.lines.rate.60" \
  --stime=3d --show-url
```

### Scribe read ingestion lag (category-level)

```bash
meta ods.metric query \
  --entity "rfe.sli.<SCRIBE_CATEGORY>" \
  --key "ingestion_lag_ms" \
  --stime=3d --show-url
```

### DPP starvation (per-job ODS)

```bash
meta ods.metric query \
  --entity "aiplatform.pytorch.job.<MAST_JOB>.trainer.<VERSION>.<HASH>" \
  --key "dpp.client_unified_starvation_duration_us.sum.60" \
  --stime=3d --show-url
```

### Multi-version MAST error history (H1 query)

```bash
for v in $(seq <LATEST-5> <LATEST>); do
  echo "=== v$v ==="
  meta ai.mast-job describe --name=mvai-training-online-<MODEL_ID> --version=$v | \
    grep -E "status|submission_time|end_time"
  meta ai.mast-job error --name=mvai-training-online-<MODEL_ID> --version=$v --attempt=0 | \
    grep error_message
done
```

## OT Oncall Quick Reference

| Team | Oncall Rotation | Scope |
|------|----------------|-------|
| DPP starvation (symptom: workers falling behind, read lag) | `dpp_worker` | DPP worker process issues + starvation symptoms — `dpp_starvation` rotation deprecated 2026-05-28 (not staffed; per mpoggy in D106697344) |
| DPP client | `dpp_client` | General DPP client-side issues |
| ScribeOne / LogDevice | `logdevice` | Storage-level read/write issues |
| Scribe | `scribe` | Scribe producer / write-side issues |
| MAST scheduler | `di_tetris` / `mast_optimizer` | Job scheduling, placement, preemption |
| TMS | `managed_training_service` | Job lifecycle, registration, auto-restart |
| Model Store | `model_store` | dai_modelstore, snapshot state machine, observer config |
| SilverTorch | `home_ml_platform` | Publishing, snapshot generation |
| Hedwig | `hedwig` | Streaming dispatch, rate limits |
| Recsys / IPnext | `ip_runtime` | Predictor, serving, snapshot transition |
| Auth infra | `acl_checker` | Permission errors, Koski |

## OT-Specific Lessons Learned

### S665454 (2026-05-21): DPP read lag causing daily example age spikes

- **Symptom:** 30–90 min example age spikes daily during 06:00–12:00 PDT across multiple OT jobs reading `ig_muddler_generic_training_data_text_post_app_roo`
- **Misdiagnosis path:** "ZDB AI-training tier" → "ScribeOne multi-tenant clusters" → finally: DPP workers falling behind
- **What broke the case:** per-job `client_lag_in_seconds` was 92 min while category aggregate was 12 sec. The 3 orders-of-magnitude gap pointed squarely at DPP, not storage.
- **Lesson:** Always check per-job metrics before category aggregates. The scribe page's "read" section shows category-level lag — useful but insufficient. The `scribe_read_proxy` Scuba table filtered to the specific TW job name shows the actual per-consumer lag.
- **Encoded as:** known_patterns.md P51 + `src/sources/scribe_lag.py` (commit `dc5e70b53ea0`).

### ALERT-913270201550407 + 848590011404637 (2026-05-21): cfr_main_mtml family-NaN cascade

- **Symptom:** 11.5h FULL_SNAPSHOT gap on holdout model 878858380; baseline 2134319967 hit same CL-017 Shampoo NaN within 6 hours.
- **Misdiagnosis path:** initial frame on v149 attempt-0 publish-spawn error; missed the v146-v148 NaN cascade in prior versions.
- **What broke the case:** operator correction → multi-version MAST error history loop revealed Shampoo NaN class across 3 versions.
- **Lesson:** Phase-1 must look back across MAST versions, not just current attempt. When current attempt is clean but freshness alert fires, the actual story is in prior crashed versions.
- **Encoded as:** IMPROVEMENT-PROPOSALS.md H1 (multi-version lookback) + H2 (family-aware clustering).

---

_OT-specific routing data. Sibling: generic [escalation.md](../../../cheatsheets/oncall/escalation.md). For broader cheatsheet index: `~/notes/users/dennyzhang/cheatsheets/oncall/INDEX.md`._
