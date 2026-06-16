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

## Escalation Quality Analysis (was the response well-coordinated?)

Everything above routes a symptom to the right team. This section is the
orthogonal dimension: **diagnosing how well the escalation itself went** —
for SEV reviews, retros, and post-incident write-ups. Cherry-picked from
imoc `fb-report-escalation-methodology.md` (2026-06-10).

### Failure taxonomy — 10 categories to scan chat for

| # | Category | Evidence pattern to search for |
|---|----------|-------------------------------|
| 1 | **Delayed initial response** | Alert fire time vs. first oncall chat message; gap > 15 min |
| 2 | **Wrong first responder** | "this isn't my area", "page X instead", explicit handoff |
| 3 | **Slow cross-team escalation** | First "we need team Y" message vs. when Y first responded; gap > 30 min |
| 4 | **Missing war room** | No `#filevc`/zoom/VC at all on a 3+-team SEV |
| 5 | **Delayed war room** | Second team joined vs. VC created; gap > 45 min |
| 6 | **Insufficient seniority** | "should we revert?" / "is this a SEV2?" with no TL/senior weighing in; delayed level upgrade |
| 7 | **Parallel-investigation gaps** | One person debugging sequentially while others only observe (vs. "I'll check X" / "I'll check Y" from different people) |
| 8 | **Handoff failures** | "let me check previous messages", "what happened so far?", new responder repeating done work |
| 9 | **Silent observers** | Experts from the owning team present in chat but zero investigation messages |
| 10 | **Cross-SEV blindness** | Related concurrent SEV not connected for > 30 min, missing shared root cause |

### Timestamp-gap benchmarks

| Gap | Target | Flag if |
|-----|--------|---------|
| Alert → first response | < 5 min | > 15 min |
| First response → SEV filed | < 15 min | > 30 min |
| SEV filed → cross-team escalation | < 30 min | > 60 min |
| Cross-team request → team engaged | < 15 min | > 30 min |
| Multi-team → war room created | < 15 min | > 45 min |
| Root-cause ID → mitigation started | < 15 min | > 30 min |

For each gap in the timeline, compare measured duration to the benchmark;
exceeding "Flag if" → call it out with the gap title, duration, TTM impact,
and evidence quote.

### Anti-hallucination rules (mandatory — violating any invalidates the analysis)

- **Never call an oncall "late" without TWO timestamps:** when they were
  first paged/requested AND when they first responded. Both timestamp-cited.
- **"Not paged" vs "paged but didn't respond" are different failure modes
  needing different fixes.** Not paged → fix the escalation *path*. Paged,
  no response → fix the oncall *response process*. Never conflate them.
- **Absence of chat ≠ absence of work.** People use DMs, phone, VC. Phrase
  quiet periods as "no visible chat activity", never "no one investigated"
  / "Person X didn't respond". When a request shows no reply, check whether
  that person appeared later (they may have answered off-channel).
- **Never characterize escalation as "smooth"/"effective" without measured
  gap evidence.** "Escalation proceeded as follows…" is always safe;
  "escalation was smooth" needs proof.
- **Focus on process gaps, not individuals.** Tag any inference `[INFERRED]`.

For multi-day SEVs additionally check: explicit shift-handoff messages,
urgency decay (messages/hour dropping, >4h silent windows), and decision
delays (a "should we revert?" debated for hours, or decisions blocked on
one specific person).

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

_Last updated: 2026-06-10. Maintainer: dennyzhang._
