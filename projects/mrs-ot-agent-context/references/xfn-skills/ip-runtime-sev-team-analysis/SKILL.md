---
name: sev-team-analysis
description: >-
  Analyze SEVs for Runtime Team engagement, root cause attribution, and
  ownership assessment. Use when: (1) generating a per-SEV team analysis
  report, (2) assessing whether a SEV's root cause is in Runtime Team's
  domain, (3) evaluating Runtime Team's ownership performance (detection,
  mitigation, blast radius), (4) building an aggregate summary across
  multiple SEVs for team-level insights. Covers team participation rates,
  estimated effort, Runtime Team sub-area mapping, oncall triage
  recommendations, and ownership gap identification. Does NOT handle
  active SEV debugging, root cause investigation, or SEV Manager report
  generation (use recsys-inference-sev-review for those).
---

# SEV Team Analysis

Analyze SEVs to understand Runtime Team engagement, root cause attribution, and ownership gaps. Produces structured reports for team-level review and improvement planning.

## Business Context

The Runtime Team (RecSys Inference Serving) responds to SEVs across the inference serving stack. Not all SEVs are root-caused in the team's domain, but the team owns the predictor stack end-to-end: availability, resilience, observability, and safe traffic handling. This skill helps answer two key questions:

1. **What fraction of SEVs are attributed to the Runtime Team's domain?**
2. **How can the team better triage and respond to issues where the root cause is outside its domain?**

## Out of Scope

- Active SEV debugging or investigation (use `recsys-inference-sev-review`)
- SEV Manager report generation (use `recsys-inference-sev-review`)
- Training pipeline, data pipeline, or ads delivery SEVs

## Target Users

- **Engineering Managers** (Primary): Need aggregate views of team SEV engagement, effort allocation, and ownership patterns for planning and staffing.
- **Tech Leads** (Primary): Need per-SEV ownership assessments to identify systemic gaps in detection, mitigation, and blast radius containment.
- **Oncall Engineers** (Secondary): Need triage recommendations and faster escalation paths based on patterns from prior SEVs.

## Workflow

### Step 0: Find SEVs and Classify Oncall Roles

**ALWAYS start here.** Use `find_team_sevs.py` (in this skill directory) to identify SEVs where Runtime Team members participated in the GChat thread and classify each member's oncall role.

```bash
# Find SEVs from the last 7 days with role classification (default: 14 days)
python3 find_team_sevs.py --days 7 --output json

# Find SEVs in a specific date range
python3 find_team_sevs.py --start 2026-04-17 --end 2026-04-22 --output json

# Table format for quick review
python3 find_team_sevs.py --days 7 --output table
```

The script:
1. Queries Hive tables (`oncall_rotation_members`, `sev_gchat_metadata`, `sev_metrics`) to find SEVs where ip_runtime oncall chatted
2. Fetches the oncall schedule via `meta oncall.rotation schedule -r ip_runtime` to get exact shift windows (Main/Secondary/Shadow)
3. For each SEV, identifies Runtime Team members from `meta sevmanager.chat list` and classifies each as: `primary_oncall`, `secondary_oncall`, `shadow_oncall`, or `SME` (non-oncall team member)

Output per-SEV includes: `sev_number`, `level`, `title`, `status`, `event_type`, `first_oncall_date`, `members` (list with unixname + role), and role-grouped lists (`primary_oncall`, `secondary_oncall`, `shadow_oncall`, `sme`). It also prints an oncall coverage summary for the date range to stderr. Automatically filters out false positives and stale SEVs.

**Do NOT use keyword-based `meta sevmanager.sev list` searches** (e.g. `--title-contains="predictor"`) to find the initial SEV list. Those produce many false positives and miss SEVs where Runtime Team participated but the title doesn't contain obvious keywords. The script uses actual GChat participation data, which is the ground truth.

### Per-SEV Analysis (Steps 1-6)

Follow the detailed workflow in [sev-analysis-workflow.md](references/sev-analysis-workflow.md):

1. **Gather data** from both the SEV tool (`meta sevmanager`) and the GChat war room thread
2. **Identify Runtime Team members** using the roster (unixnames) and calculate participation rate
3. **Build Runtime Team involvement timeline** with per-member active time estimates
4. **Classify root cause** (In-domain / Adjacent / External) and map to Runtime Team sub-area
5. **Assess Runtime Team's role** across 7 ownership areas (Availability, Detection, Diagnosis, Mitigation, Traffic Safety, Blast Radius, Recurrence Prevention)
6. **Generate report** to `~/notes/users/manishr/analysis/q1sevs/sev-report-SXXXXXX.md`

### Secondary Oncall Engagement (captured per-SEV in Step 3)

During each per-SEV analysis, while reading the GChat thread, capture:
- Did the primary oncall ask for help? (look for "not sure", "stuck", "help", "#addoncall", etc.)
- Did the secondary oncall post in the thread?
- If the primary asked for help, who responded (secondary, SME, external)?

These fields go in the per-SEV Quick Stats and JSON result. Step 7 aggregates them into a weekly "Secondary Oncall Engagement" section without re-reading GChat.

### Post-Analysis Data Pipeline (after writing reports)

After writing per-SEV reports and the weekly report, update the tracking files:

```bash
# 1. Update weekly-results.json from per-SEV report markdown (if reports follow the template)
python3 scripts/update_weekly_json.py backfill ~/notes/users/manishr/analysis/q1sevs

# 2. Sync oncall data from weekly JSON to tracking.json
python3 scripts/sync_oncall_to_tracking.py ~/notes/users/manishr/analysis/q1sevs

# 3. Update oncall-schedule.json with this week's coverage (manual)
# Edit ~/notes/users/manishr/analysis/q1sevs/oncall-schedule.json
```

If per-SEV analysis produces a structured JSON result (preferred over markdown parsing):
```bash
python3 scripts/update_weekly_json.py from-json /tmp/S648074_result.json 2026-04-17 ~/notes/users/manishr/analysis/q1sevs
```

### Aggregate Summary (Step 8, separate)

Only after all individual reports are reviewed and finalized by the human. Produces a cross-SEV summary with team engagement patterns, ownership scorecard, secondary oncall patterns, and recommendations.

## Critical Rules

### Data Sources

For each SEV, gather from BOTH sources. Neither alone gives the complete picture.

**SEV Tool** (`meta sevmanager`):
- `meta sevmanager.sev metadata --sev SXXXXXX -o json` (timeline, owner, impacted areas, follow-up tasks)
- Comments: `comment list` does NOT accept `--sev`; it lists by author: `meta sevmanager.comment list --author=manishr -o json`
- `meta sevmanager.sev history --sev SXXXXXX -o json` (status changes)

**GChat Thread**:
- **Join the space first**: `meta sevmanager.chat join --sev=SXXXXXX` (required for API access even if listed as authuser)
- Read ALL messages in the SEV space. Do not skip or sample.
- Use `meta google.chat.message list -s spaces/XXXXXXXX --limit=500 --no-truncate -o json` to get messages.

### Runtime Team Roster

Use the roster in [sev-analysis-workflow.md](references/sev-analysis-workflow.md). Always identify team members by **unixname** to avoid ambiguity. Team size: 26.

### Ownership Assessment Nuances

These rules prevent oversimplified assessments:

**Detection & Alerting** (blast radius rule):
- Root-caused in Runtime infra: Runtime Team should detect regardless of scope
- External, broad impact (many models/surfaces): Runtime Team should detect infra-wide impact
- External, narrow impact (<5 model types): Detection is model owner's responsibility

**Mitigation ownership** (same blast radius logic):
- Infra-wide or root-caused in Runtime: Runtime Team should drive mitigation
- External, narrow: Model owner drives, Runtime Team assists
- External, broad: Runtime Team should co-own or have a generic lever (traffic shedding, circuit breaker)

**Traffic safety** (generic runtime constraint):
- Runtime Team provides a generic runtime environment
- It is NOT practical to validate every model-specific input
- Assess against what is reasonable without model-specific knowledge
- Reference the active bad request handling workstream (see workflow context section)
- Rate as Gap only if protections were missing that did not require model-specific knowledge

### Effort Estimation

Estimate active time conservatively from message patterns:
- "Looking into X" at T1, findings posted at T2: estimate T2-T1 as active time
- Unrelated messages separated by hours: do not assume continuous work
- Note uncertainty in estimates

### Writing Style

- Always say "Runtime Team" (not "the team", "runtime team", or "our team")
- Use unixnames for all Runtime Team members
- No em dashes. Use commas, periods, or parentheses instead.
- Be specific: cite diff numbers, task IDs, timestamps, unixnames.

## Report Template

See [sev-analysis-workflow.md](references/sev-analysis-workflow.md) Step 6 for the full report structure. Key sections:

1. Header (SEV metadata)
2. Quick Stats (aggregate-friendly metrics table)
3. Executive Summary
4. Timeline
5. Runtime Team Involvement Timeline
6. Root Cause Analysis (with sub-area and category)
7. Team Engagement (with unixnames and participation rate)
8. Attribution Summary
9. Runtime Team's Role (7-area ownership assessment)
10. Recommendations (including oncall and triage-specific)

## Error Handling

- **Cannot access GChat space**: Note in report, analyze from SEV tool data only. Flag as incomplete.
- **SEV tool returns empty fields**: Use GChat thread as primary source. Note which SEV tool fields were empty.
- **Team member identification uncertain**: Use unixname lookup. If a participant's name doesn't match the roster but seems like a Runtime Team member, flag for human review.
- **Effort estimation too uncertain**: Report "insufficient data to estimate" rather than guessing.
