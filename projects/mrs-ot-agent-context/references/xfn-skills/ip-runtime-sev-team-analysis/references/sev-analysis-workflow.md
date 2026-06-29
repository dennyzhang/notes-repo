# SEV Analysis Workflow

Repeatable process for analyzing SEVs where Runtime Team members participated. This workflow covers **individual SEV reports only**. The aggregate summary is a separate step done after all individual reports are reviewed and finalized.

---

## Runtime Team Roster (source: Workplace group 2428759990907528)

| Name | Unixname | Function |
|---|---|---|
| Scott Batura | scb | Engineering Director |
| Yang Wan | ywan24 | SWE Manager |
| Jason Arnold | jaar | PE Manager |
| Manish Rajpal | manishr | Software Engineer |
| Peter Hsu | peter1229 | Software Engineer |
| Euphemia Zhang | yingqizh | Software Engineer |
| Henry Ma | hym | Software Engineer |
| Xuan Qi | xuanqi | Software Engineer |
| Shabab Ayub | shababayub | Software Engineer |
| Richie Lee | rlx303 | Software Engineer |
| Kevin Lin | kevinlin8221 | Software Engineer |
| Charlie Zhang | whycz | Software Engineer |
| Hongbo Qin | hongbo1001 | Software Engineer |
| Joshua Su | joshuasu | Research Scientist |
| Melvin He | melvinhe | Software Engineer |
| Lujia Zhang | lujia | Software Engineer |
| Howard Huang | changhao | Software Engineer |
| Wanyun Lu | wanyunluc | Production Engineer |
| Thomas Jacob | tja | Production Engineer |
| Ruolin Zan | rzan | Production Engineer |
| Richard Huang | rihu | Production Engineer |
| Tiantian Li | ttli | Production Engineer |
| Rebecca Mao | bxm | Data Scientist |
| Fuxian Gong | fgong | Data Engineer |
| Yufeng Duan | duanyufeng | Contingent Worker |
| Jaikrishnan Pillai | pilljaikrishnan | Contingent Worker |

**Team size: 26**

### Runtime Team Sub-areas

- **Serving**: Predictor, inference runtime, request handling
- **Model Freshness**: Snapshot management, model loading, staleness
- **Hardware (non-CUDA GPU)**: AMD, MTIA, GPU test pipeline
- **Binary Release**: Release pipeline, canary, rollout
- **Observability**: Alerting, metrics, debugging tools
- **Bad Request Handling**: Input validation, crash isolation (active workstream, see context below)

---

## Step 1: Gather Data for a Single SEV

For each SEV, gather data from two sources:

### 1a. SEV Tool (meta sevmanager)

```bash
# Full metadata: timeline, owner, impacted areas, status
meta sevmanager.sev metadata --sev S640381 -o json

# Comments: note that `comment list` does NOT accept --sev.
# It lists by author. Use `meta sevmanager.sev metadata` for per-SEV comments (in comment_count field).
# meta sevmanager.comment list --author=manishr --after=2026-04-17 -o json

# Change history (status changes, field updates, actors)
meta sevmanager.sev history --sev S640381 -o json

# Follow-up tasks
# (included in metadata output under follow_up_tasks)

# Retrospective predictions (AI-generated RCA, impacted areas)
meta sevmanager.retrospective list --sev S640381 -o json
```

Extract from SEV tool:
- **Detection method**: How was the SEV detected? (auto-detected, manual, oncall alert)
- **Official timeline**: start, detected, diagnosed, mitigated, ended timestamps
- **Time to detect** and **time to mitigate** (computed by SEV tool)
- **Impacted areas** (tags like ig_predictor, reels-recommendations, etc.)
- **Owner** and **journalist**
- **Follow-up tasks**: Task IDs and status (PREVENTION, MITIGATION, SEV_REPORT)
- **Report narratives**: Overview, root cause, detection, remediation, prevention (if filled)
- **Related/mentioned diffs**

### 1b. GChat Thread

Read all messages in the SEV GChat space. Extract:
- **Detailed timeline**: Detection, escalation, investigation milestones, mitigation, resolution
- **Participants**: Who posted, message count, what they contributed
- **Root cause discussion**: What broke, why, how it was identified
- **Resolution**: Immediate mitigation + preventive fix
- **Runtime Team involvement timeline** (see Step 3)

---

## Step 2: Identify Runtime Team Members

Cross-reference all GChat participants against the roster above using **unixnames**.

Calculate:
- **Total engineers involved** in the SEV (all participants)
- **Runtime Team members involved** (count + names)
- **Runtime Team participation rate** (members who posted / 26)

---

## Step 3: Build Runtime Team Involvement Timeline

For each Runtime Team member who participated, capture:

| Member (unixname) | Role | First Message | Last Message | Est. Active Time | Key Contributions |
|---|---|---|---|---|---|
| e.g. tja | primary_oncall | 9:21 PM | 11:45 PM | ~2h | Scuba queries, correlated SL timeline |
| e.g. manishr | SME | 10:30 PM | 11:00 PM | ~30m | Predictor config review |

**Role classification** (use `sev_context_enrichment.py classify_member`):
- **primary_oncall**: Member was primary oncall when they joined the SEV
- **secondary_oncall**: Member was secondary oncall when they joined the SEV
- **SME**: Member was added as subject matter expert (not oncall at join time)

**Estimating active time**: If someone said "looking into X" at time T1 and posted findings at T2, estimate T2-T1 as active time. If messages are unrelated or separated by hours with no clear investigation thread, don't assume continuous work. Use conservative estimates and note uncertainty.

**Total estimated Runtime Team effort**: Sum of active hours across all members.

---

## Step 4: Classify Root Cause

Categories:
- **In-domain (Runtime Team)**: Runtime bugs, predictor crashes from our code, snapshot issues from our infra, binary release problems from our pipeline
- **Adjacent (partial ownership)**: Defense-in-depth gaps, config issues in shared systems where Runtime Team has a role
- **External**: Model/ranking code bugs, upstream infrastructure failures (MySQL, CUDA, ServiceLab), feature engineering issues, JK misconfigurations

**Affected Runtime Team sub-area**: Which sub-area of the Runtime Team is most relevant? (Serving, Model Freshness, Hardware, Binary Release, Observability, Bad Request Handling)

---

## Step 5: Assess Runtime Team's Role

Assess the Runtime Team's performance against ownership expectations. The team owns the predictor stack end-to-end: availability, resilience, observability, and safe traffic handling.

Evaluate across these areas (rate each as Good / Gap / N/A):

- **Availability**: Did predictors stay up or crash? Was there graceful degradation?

- **Detection & Alerting**: Apply the blast radius rule:
  - If the issue is **root-caused in Runtime Team infra**: Runtime Team should detect it regardless of how many models are affected.
  - If the issue is **external but affects many models/surfaces broadly**: Runtime Team should detect infra-wide impact (crash-loop rates, error spikes across model types).
  - If the issue is **external and affects a small subset of tenants (<5 model types)**: Detection is primarily the model owner's responsibility. Assess whether Runtime Team alerting *could reasonably* have caught it, but don't rate as Gap if tenant-specific.

- **Diagnosis**: How quickly did the Runtime Team identify failure mode and blast radius once engaged?

- **Mitigation ownership**: Apply the same blast radius logic:
  - Infra-wide issue or root-caused in Runtime: Runtime Team should drive mitigation.
  - External, narrow blast radius: Model owner drives mitigation. Runtime Team assists.
  - External, broad blast radius: Runtime Team should co-own or have a generic mitigation lever (e.g., traffic shedding, circuit breaker).

- **Traffic safety**: Assess what the Runtime Team could **reasonably do within its generic runtime mandate**. The Runtime Team provides a generic runtime environment. It is not practical to validate every model-specific input. Assess against the current workstream:
  - Short-term: End-to-end request observability, bad request logging, crash isolation (D97988162, D97346936)
  - Long-term: Model-exported validations via Silvertorch/MVIA metadata
  - Reference: Workplace posts by jaar (2026-03-25) and wanyunluc (2026-03-16) on addressing predictor bad request SEV risk
  - Rate as Gap only if the Runtime Team lacked protections it could reasonably have had without model-specific knowledge.

- **Blast radius containment**: Was the impact isolated, or did it spread across tasks/regions/surfaces?

- **Incident recurrence prevention**: Were follow-up tasks from prior similar SEVs completed? Check SEV tool for related follow-up tasks.

Summarize: how many areas have gaps, the overall pattern, and what was done well.

---

## Step 5.5: Enrich SEV Context (Oncall & Area Lead)

Use the `sev_context_enrichment.py` script to deterministically lookup:

### A. Oncall Members at SEV Start

```bash
# Fetch historical oncall schedule (use --past to get all past shifts)
meta oncall.rotation schedule --rotation ip_runtime --past --limit 300 -o json \
    > /tmp/oncall_schedule.json

# Check who was oncall when this SEV started
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/sev_context_enrichment.py \
    check_oncall /tmp/oncall_schedule.json /tmp/sev_metadata.json
```

**Fallback when `time_started` is missing**: Some SEVs (especially SEV4/tracking SEVs) have no `time_started` in the SEV tool. In that case, use the first GChat message timestamp as a proxy:

```bash
# Extract first GChat message timestamp and normalize (strip timezone offset)
FIRST_MSG=$(meta google.chat.message list -s spaces/<SPACE_ID> --limit 500 -o json \
    | jq -r 'sort_by(.create_time_unix | tonumber) | .[0].create_time' \
    | sed 's/T/ /' | sed 's/[-+][0-9:]*$//')

# Pass as fallback to check_oncall (5th argument)
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/sev_context_enrichment.py \
    check_oncall /tmp/oncall_schedule.json /tmp/sev_metadata.json "$FIRST_MSG"
```

Output:
```json
{
  "sev_number": "S648074",
  "sev_start_time": "2026-04-13 05:02",
  "primary_oncall": "manishr",
  "secondary_oncall": "whycz"
}
```

**IMPORTANT**: Use the SEV start time (`time_started`) — or first GChat message as fallback — to determine who was oncall, not when team members joined the investigation. This reflects who was paged/responsible when the incident began.

### B. Classify Team Member Roles

For each Runtime Team member who participated, determine if they were engaged as oncall or as an SME:

```bash
# Get the first time this member appeared in the SEV (from GChat or SEV history)
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/sev_context_enrichment.py \
    classify_member /tmp/oncall_schedule.json <unixname> "<join_timestamp>"
```

Output:
```json
{
  "member": "manishr",
  "join_time": "2026-04-15 14:12",
  "role": "SME"  // or "primary_oncall" | "secondary_oncall"
}
```

Use this to distinguish:
- **Oncall load**: How much work fell on the designated oncall vs SMEs
- **Escalation patterns**: When do oncalls pull in SMEs vs handling themselves
- **Domain expertise**: Which members are pulled in for specific sub-areas

### C. Check Area Lead Assignment (Manual)

For SEVs where Runtime Team members participated but the SEV is not owned by a Runtime Team member, verify if an area lead was correctly identified:

```bash
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/sev_context_enrichment.py \
    check_area_lead /tmp/sev_metadata.json
```

Output includes instructions to manually verify in the SEV UI. Expected Runtime area:
- **Tag ID**: 253058003073680
- **Name**: "RecSys Runtime"
- **Hierarchy**: "AI > Serving / Inference > RecSys Runtime"
- **Oncall**: ip_runtime

**To check manually**:
1. Visit the SEV in the SEV Manager UI
2. Check "Active Areas" section (where area leads are assigned)
3. Verify if "RecSys Runtime" area is listed with the appropriate lead

**Add to Quick Stats table**:
- **Area lead assigned?**: Y/N (if SEV not owned by Runtime Team)
- **Area lead name**: unixname (if assigned)
- **Area name**: RecSys Runtime (or "Not assigned")

This accountability check helps identify whether Runtime Team is properly tagged for visibility and follow-up tracking.

---

## Step 6: Generate Report

Write to `~/notes/users/manishr/analysis/q1sevs/sev-report-SXXXXXX.md`

Use the template from `sev-report-s640381.md` with these sections:

### Report Structure

1. **Header**: SEV ID, Severity, Title, Date, Duration, Status, GChat Space
2. **Quick Stats** (new, for aggregate rollup):

| Metric | Value |
|---|---|
| Total engineers involved | N |
| Runtime Team members involved | N / 26 (list unixnames) |
| Est. Runtime Team effort | ~Xh |
| Time to detect | Xm (from SEV tool) |
| Time to mitigate | Xm (from SEV tool) |
| Time to Runtime Team engagement | Xm (SEV start to first Runtime Team message) |
| Root cause category | In-domain / Adjacent / External |
| Affected Runtime Team sub-area | Serving / Model Freshness / Hardware / Binary Release / etc. |
| Surfaces impacted | Feed / Reels / Explore / Threads / etc. |
| Runtime Team drove mitigation? | Y/N |
| Runtime Team drove fix? | Y/N |
| Key Runtime Team contributor | unixname of person who carried the load |
| Oncall on duty (at SEV start) | unixname of primary oncall (deterministic from schedule) |
| Oncall secondary (at SEV start) | unixname of secondary oncall (deterministic from schedule) |
| Oncall rotation dates | date range of the oncall shift covering this SEV |
| Area lead assigned? | Y/N (for SEVs not owned by Runtime Team, check if RecSys Runtime area lead was assigned) |
| Area lead name | unixname (if area lead was assigned) or "Not assigned" |
| Repeat/related SEV | SXXXXXX (or None) |
| Runtime Team follow-up tasks | Y/N (list task IDs + Open/Closed status) |
| Ownership gaps (of 7) | N/7 |
| Effort avoidable with better tooling? | Xh of Yh (brief explanation of what tooling would have avoided the effort) |
| Preventable? | Yes/No. If yes, state which prior follow-up or improvement would have prevented it |
| Recurring themes | Comma-separated tags from: crash-isolation, cross-model-alerting, follow-up-tracking, bad-request-handling, oncall-paging, blast-radius, detection-gap, runbook-gap, servicelab-isolation, config-safety, snapshot-management |
| Oncall concurrent SEVs | N (number of other SEVs the oncall was handling simultaneously) |
| Follow-up actions filed | N filed, M with task IDs |

3. **Executive Summary** (2-3 sentences + root cause attribution line)
4. **Timeline** (key milestones)
5. **Runtime Team Involvement Timeline** (table: member unixname, first msg, last msg, est. active time, key contributions)
6. **Root Cause Analysis** (category + failure chain + repeat incident check)
7. **Team Engagement** (Runtime Team members table with unixnames + participation rate + key external contributors)
8. **Attribution Summary** (dimension/assessment table)
9. **Runtime Team's Role** (ownership assessment table with Area/Expectation/What Happened/Rating + summary)
10. **Recommendations** including:
    - Oncall-specific recommendations (faster paging, better runbooks, escalation paths)
    - Faster triage recommendations (what signals to check first, what tools to use)
    - Follow-up tasks for Runtime Team (if any)
11. **Structured Follow-ups** (table for aggregate tracking):

| # | Action | Owner | Priority | Task ID | Status |
|---|---|---|---|---|---|
| 1 | Example: Deploy crash isolation | unixname | P0/P1/P2 | TXXXXXXXXX or "Not filed" | Open/Closed/In Progress |

---

## Step 6.5: Update Weekly JSON

After writing the report, extract all structured data and update the weekly-results.json file:

```bash
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/update_weekly_json.py \
    S640381 2026-03-20 ~/notes/users/manishr/analysis/q1sevs
```

This script:
- Parses the markdown report and extracts **40+ fields**
- Updates `~/notes/users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/weekly-results.json`
- Preserves existing summary/analysis fields while adding rich metadata

### Extracted Fields (Enhanced Schema)

The weekly JSON now includes:

**SEV Metadata (9 fields):**
- level, title, time_started, duration_hours, sev_status
- gchat_participants, gchat_messages
- sev_number, report_path

**Impact Metrics (8 fields):**
- total_engineers_involved, runtime_team_members_count, runtime_team_members_list
- time_to_detect_minutes, time_to_mitigate_hours, time_to_runtime_engagement_minutes
- surfaces_impacted

**Ownership (6 fields):**
- runtime_drove_mitigation, runtime_drove_fix
- key_runtime_contributor, oncall_primary, oncall_secondary
- repeat_related_sev

**Analysis Results (9 fields):**
- root_cause_category, sub_area, team_effort_hours
- ownership_gaps, effort_avoidable, effort_avoidable_hours
- preventable, preventable_reason, recurring_themes

**Follow-ups (4 fields):**
- followup_actions_filed, followup_actions_count
- has_runtime_followup_tasks, runtime_followup_tasks (array)

**Team Engagement (3 fields):**
- runtime_participation_rate
- runtime_members_detail (array with role, timing, contributions)
- key_external_contributors (array)

**Other (2 fields):**
- oncall_concurrent_sevs, status, analysis_date, summary

This rich data enables:
- **Load dashboards** - individual effort, oncall vs SME breakdown
- **Effectiveness metrics** - detection/mitigation times, avoidable effort
- **Root cause trends** - category distribution, recurring themes
- **Follow-up tracking** - task status, preventability analysis
- **Oncall analysis** - concurrent SEVs, engagement timing, role classification

---

## Step 7: Aggregate (separate step, after all individual reports are finalized)

Only run after all individual reports have been reviewed and adjusted by Manish. Create a summary with:
- Total SEVs analyzed
- Fraction attributed to Runtime Team's domain vs external
- Most common external root cause categories
- Affected Runtime Team sub-areas breakdown
- Runtime Team engagement patterns (who responds most, avg participation rate, total effort hours)
- Runtime Team ownership scorecard across all SEVs
- Systemic gaps and recurring patterns
- **Avoidable effort analysis**: total hours spent, hours avoidable with better tooling, ROI of top improvements
- **Preventability analysis**: fraction of SEVs that were preventable if prior follow-ups had been closed
- **Recurring themes heatmap**: which theme tags appear most frequently across SEVs
- **Follow-up action tracker**: aggregate table of all structured follow-ups across SEVs, grouped by status
- **Oncall load analysis**: concurrent SEV handling, paging latency distribution
- Recommendations for better triage of out-of-domain issues
- Recommendations for Runtime Team ownership improvements
- Oncall improvement recommendations

---

## Context: Runtime Team Bad Request Handling Workstream

The Runtime Team acknowledges that Predictor cannot generically sanitize model-specific inputs. The current strategy (per jaar and wanyunluc Workplace posts, March 2026):

**Short-term (active, daily war room):**
- End-to-end request observability improvements
- Bad request logging with consistent IDs in shared Scuba table
- Crash isolation: D97988162 and D97346936 provide options to run bad requests non-batched or reject them
- Client-side metadata logging to Predictor tables

**Long-term:**
- Model framework teams (Silvertorch, MVIA) define validation metadata exported with models
- RaaS and Predictor invoke these validations on model load
- Two tracks: (1) export existing model assertions (jaar + Gufan Yin), (2) define new validation metadata (Hongzhang Yin)

When assessing "traffic safety," evaluate against what is reasonable for a generic runtime, not against perfect model-specific input validation.
