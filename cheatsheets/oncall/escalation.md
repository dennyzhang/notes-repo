# Cross-Team Escalation Cheatsheet

How to escalate OT issues to infrastructure teams. Sourced from real
triage sessions — each rule has a concrete evidence trail behind it.

## Before You Escalate

1. **Check per-job metrics, not category aggregates.** Category-level
   metrics (e.g., `rfe.sli.ingestion_lag_ms`) average across all consumers
   and mask per-job spikes. Always check per-job signals first — the gap
   between aggregate and per-job tells you WHERE the bottleneck is.

2. **Produce shareable links.** Every escalation needs at minimum:
   - One Scuba/ODS chart link showing the symptom
   - One link showing the correlation to the infrastructure component
   - A paste (P-number) with the full writeup for context

3. **Cross-job correlation first.** If multiple jobs (different owners,
   regions, tiers) hit the same symptom → shared dependency, not
   job-specific. State this explicitly — it changes the urgency.

## Symptom → Team Routing

| Symptom | Check This First | If Confirmed → Team | Oncall |
|---------|------------------|---------------------|--------|
| High example age, multiple jobs | `scribe_read_proxy.client_lag_in_seconds` per job | DPP (consumer lag) | `dpp_starvation` |
| High example age, single job | DPP starvation ODS + job config (worker count, threads) | DPP or model owner (config) | `dpp_client` |
| Scribe write QPS drop | `ptail_flow.<category>.output.lines.rate.60` | Scribe / upstream producer | `scribe` |
| Scribe category-level ingestion lag spike | `rfe.sli.<category>.ingestion_lag_ms` | ScribeOne / LogDevice | `logdevice` |
| MAST job PENDING, never scheduled | MAST attempts list (all PENDING, none RUNNING) | MAST scheduler | `di_tetris` / `mast_optimizer` |
| Publishing stall, no new snapshots | UMM model instance records + GMPP logs | SilverTorch / model_processing | `home_ml_platform` |
| Streaming success drop | Hedwig rate limit / stream dispatch errors | Hedwig | `hedwig` |
| Permission errors across all ranks | Koski/AclChecker errors in trainer logs | Auth infra | `acl_checker` |

## The Per-Job vs Category-Level Trap

This is the most common misdiagnosis. Example from S665454 (2026-05-21):

| Metric | Level | Value | What It Tells You |
|--------|-------|-------|-------------------|
| `rfe.sli.ingestion_lag_ms` | Category aggregate | 12–15 sec | Scribe/LogDevice is healthy |
| `scribe_read_proxy.client_lag_in_seconds` | Per DPP worker | 1,000–5,500 sec (16–92 min) | DPP workers are the bottleneck |

If you only checked the category-level metric, you'd conclude "scribe is
fine" and stop. The per-job metric revealed the actual 92-minute lag that
directly caused the example-age spike.

**Rule:** When example age is elevated, ALWAYS check per-job
`scribe_read_proxy.client_lag_in_seconds` before concluding scribe is healthy.

## How to Find Scribe Category for a Job

Not always visible in MAST UI (especially SilverTorch-path jobs — see T272462228).

```bash
# Step 1: Get the rerun paste ID
meta ai.mast-job metadata --name=<JOB> -o json | \
  python3 -c "import json,sys; md=json.loads(json.load(sys.stdin)['application_metadata']); print(md.get('rerun_cmd_line','N/A'))"

# Step 2: Read the paste, find --scribe-categories
pastry <PASTE_ID> | grep -o '\-\-scribe-categories [^ ]*'
```

## Escalation Message Template

Keep it short. Three elements: problem, evidence links, ask.

```
[N] OT jobs reading scribe category `<CATEGORY>` hit recurring
training-example-age spike — up to ~X min daily during HH:MM–HH:MM PDT.
Picked one job (`<JOB_NAME>`) and confirmed that DPP
`client_lag_in_seconds` ramps from ~Y min baseline to ~Z min at peak,
directly matching the example-age inflation. [Upstream metric] is healthy,
so the bottleneck appears to be on the [component] side.

Could the [team] team take a look?

- Example age chart: <ODS_LINK>
- [Component] lag chart: <SCUBA_LINK>
- Full writeup: <PASTE_ID>
```

## Key Scuba Queries

### Per-job DPP read lag

```
dataset: scribe_read_proxy
metric: max(client_lag_in_seconds)
dimensions: time, client_tw_job_name
filters:
  category = <SCRIBE_CATEGORY>
  client_tw_job_name contains <MAST_JOB_NAME>
time: -3 days
view: Timeseries Chart, 1h buckets
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

## Oncall Quick Reference

| Team | Oncall Rotation | Scope |
|------|----------------|-------|
| DPP starvation | `dpp_starvation` | DPP workers falling behind, read lag, data starvation |
| DPP client | `dpp_client` | General DPP client-side issues |
| DPP worker | `dpp_worker` | DPP worker process issues |
| ScribeOne / LogDevice | `logdevice` | Storage-level read/write issues |
| MAST scheduler | `di_tetris` / `mast_optimizer` | Job scheduling, placement, preemption |
| TMS | `managed_training_service` | Job lifecycle, registration, auto-restart |
| SilverTorch | `home_ml_platform` | Publishing, snapshot generation |
| Hedwig | `hedwig` | Streaming dispatch, rate limits |
| Recsys / IPnext | `ip_runtime` | Predictor, serving, snapshot transition |
| Auth infra | `acl_checker` | Permission errors, Koski |

## Lessons Learned

### S665454 (2026-05-21): DPP read lag causing daily example age spikes

- **Symptom:** 30–90 min example age spikes daily during 06:00–12:00 PDT
  across multiple OT jobs reading `ig_muddler_generic_training_data_text_post_app_roo`
- **Misdiagnosis path:** "ZDB AI-training tier" → "ScribeOne multi-tenant
  clusters" → finally: DPP workers falling behind
- **What broke the case:** per-job `client_lag_in_seconds` was 92 min
  while category aggregate was 12 sec. The 3 orders-of-magnitude gap
  pointed squarely at DPP, not storage.
- **Lesson:** Always check per-job metrics before category aggregates.
  The scribe page's "read" section shows category-level lag — useful but
  insufficient. The `scribe_read_proxy` Scuba table filtered to the
  specific TW job name shows the actual per-consumer lag.
