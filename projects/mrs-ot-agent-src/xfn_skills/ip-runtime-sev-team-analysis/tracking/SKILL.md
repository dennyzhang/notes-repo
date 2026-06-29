---
name: sev-analysis-resume
description: >-
  Resume multi-session SEV analysis for Runtime Team. Supports both Q1 early (Jan-Mar 2026) and recent (Mar-Apr 2026) analysis periods.
  Checks week-level batch progress, runs the next incomplete batch using parallel sub-agents (one per SEV),
  writes weekly results + report, then updates tracking. Use when resuming SEV analysis work across sessions.
---

# SEV Analysis Resume

Resume the Runtime Team's multi-session SEV analysis project. This skill picks up where the last session left off.

## Goal

Analyze SEVs to find **actionable follow-ups that reduce the team's operational load**. The final deliverable is an aggregate summary with patterns, ownership gaps, and concrete recommendations.

**Two analysis periods**:
- **Q1 Early** (Jan 16 - Mar 17, 2026): 136 SEVs across 9 weeks
- **Mar-Apr** (Mar 18 - Apr 16, 2026): ~109 SEVs across 5 weeks

## Project Structure

SEVs are organized by **oncall week** (Fri–Thu). All files live under `~/notes/users/manishr/analysis/q1sevs/`.

```
~/notes/users/manishr/analysis/q1sevs/
├── metadata/
│   ├── batches/
│   │   ├── week-2026-01-16.md      # Q1 early batches
│   │   ├── ... (9 weeks)
│   │   ├── week-2026-03-13.md      # Mar-Apr batches
│   │   └── ... (5 weeks)
│   ├── tracking-q1-early.json      # Jan-Mar tracking
│   ├── tracking.json               # Mar-Apr tracking
│   ├── sevs-q1-early.json          # Jan-Mar discovery
│   └── sevs-30d.json               # Mar-Apr discovery
├── reports/
│   ├── 2026-01-16/
│   │   ├── weekly-report.md
│   │   ├── weekly-results.json
│   │   ├── S611715.md
│   │   └── ... (individual SEV reports)
│   └── ... (14 weeks total)
└── aggregate-summary.md
```

The normal unit of work is **one batch = one oncall week**. Each batch runs pending SEVs as parallel sub-agents, then produces a weekly-results JSON and a weekly report. Tracking files are updated only after the batch completes — never during parallel sub-agent runs (race condition risk).

## CRITICAL: Always Commit and Push After Changes

All tracking and reports live in the notes repo (`~/notes`). After EVERY report or tracking update:

```bash
cd ~/notes
sl add users/manishr/analysis/q1sevs/
sl commit -m "SEV analysis: <what changed>"
sl push --to manishr --reason "push sev analysis updates - sl help push"
```

The `manishr` bookmark provides a stable CodeHub URL:
`https://www.internalfb.com/code/notes/[manishr]/users/manishr/analysis/q1sevs/aggregate-summary.md`

This ensures progress is never lost between sessions. Do this after:
- Creating or updating a SEV report
- Writing a weekly-results JSON or weekly report
- Updating tracking.json
- Any other file changes in the q1sevs directory

## How to Resume

### Step 1: Check Progress

**First, ask the user which analysis period** they want to work on:
- Q1 Early (Jan 16 - Mar 17, 2026) → use `metadata/tracking-q1-early.json`
- Mar-Apr (Mar 18 - Apr 16, 2026) → use `metadata/tracking.json`

Check progress at two levels:

**Week-level** — for each week, check whether the weekly report exists:
```bash
ls ~/notes/users/manishr/analysis/q1sevs/reports/*/weekly-report.md
```

**SEV-level** — from the appropriate tracking file, how many SEVs per week are done vs pending:
```bash
# Read metadata/tracking.json or metadata/tracking-q1-early.json
```

Report progress to the user:
- For each week: total SEVs, how many done, how many pending, whether weekly report exists
- How many SEVs total across all weeks
- How many analyzed (status = "done")
- How many need re-analysis (status = "redo") — these have prior reports but were incomplete (e.g. no GChat access at the time). Re-analyze with full data and overwrite the existing report.
- How many blocked or skipped
- How many remaining (status = "pending")

### Step 2: Pick Next Batch (Week)

Pick the next incomplete oncall week to analyze — the oldest week that has no weekly report yet. Read the corresponding batch file from `~/notes/users/manishr/analysis/q1sevs/metadata/batches/week-YYYY-MM-DD.md` to see which SEVs in that week are already done and which are still pending.

Present the week and its pending SEV count to the user and confirm before starting.

**Important**: Do NOT touch the tracking file during batch execution — sub-agents run in parallel and concurrent writes cause corruption. Collect all sub-agent results first, then update the tracking file in a single pass after all sub-agents complete.

### Step 3: Run the Batch (Parallel Sub-agents)

Launch one sub-agent per pending SEV in the batch, all simultaneously using the Agent tool.

Each sub-agent prompt should instruct the sub-agent to:

1. **Ensure GChat access** (BLOCKING):

   First get the space ID from SEV metadata, then check if already a member before joining:
   ```bash
   # Get space ID from metadata (fetch metadata first for this step)
   SPACE_ID=$(meta sevmanager.sev metadata --sev SXXXXXX -o json | jq -r '.chat_space_id // empty')
   JOINED_FOR_ANALYSIS=false

   # Check existing access — try reading messages without joining
   if meta google.chat.message list -s spaces/$SPACE_ID --limit 1 -o json 2>/dev/null | jq -e '. | length > 0' >/dev/null; then
     : # Already have access — no join needed
   else
     # No access — join and flag for cleanup
     meta sevmanager.chat join --sev=SXXXXXX -o json
     JOINED_FOR_ANALYSIS=true
     # Verify access
     meta google.chat.message list -s spaces/$SPACE_ID --limit 1 -o json
   fi
   ```
   If after joining the message list is still empty or the join fails, STOP — set status `"blocked"` in the result and return. Do NOT analyze without GChat data.

2. **Gather SEV metadata and oncall schedule**:
   ```bash
   meta sevmanager.sev metadata --sev SXXXXXX -o json > /tmp/sev_metadata_SXXXXXX.json
   meta sevmanager.sev history --sev SXXXXXX -o json > /tmp/sev_history_SXXXXXX.json
   meta oncall.rotation schedule --rotation ip_runtime --past --limit 300 -o json > /tmp/oncall_schedule.json
   ```

3. **Enrich context with oncall and area lead data**:
   ```bash
   # Get oncall members at SEV start time (use for "Oncall on duty" fields)
   # If time_started is missing, pass first GChat message timestamp as fallback (5th arg):
   #   FIRST_MSG=$(jq -r 'sort_by(.create_time_unix|tonumber)|.[0].create_time' /tmp/gchat.json | sed 's/T/ /' | sed 's/[-+][0-9:]*$//')
   python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/sev_context_enrichment.py \
       check_oncall /tmp/oncall_schedule.json /tmp/sev_metadata_SXXXXXX.json [FIRST_MSG_IF_NO_TIME_STARTED]

   # Check area lead assignment (for SEVs not owned by Runtime Team)
   python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/sev_context_enrichment.py \
       check_area_lead /tmp/sev_metadata_SXXXXXX.json

   # For each Runtime Team member, classify their role when they joined
   # (Use first appearance time from GChat or SEV history)
   python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/sev_context_enrichment.py \
       classify_member /tmp/oncall_schedule.json <unixname> "<join_timestamp>"
   ```

4. **Follow Steps 1–6** in `fbcode/ip_runtime/skills/sev-team-analysis/references/sev-analysis-workflow.md`:
   - Read GChat messages, build involvement timeline, identify Runtime Team members
   - Classify root cause, assess ownership across the 7 areas
   - Write the full report to `~/notes/users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/SXXXXXX.md` (where YYYY-MM-DD is the oncall_week for this SEV)

5. **Leave GChat if joined only for this analysis, then commit and push the report and JSON result**:
   ```bash
   # Leave the space if we joined just for this analysis
   if [ "$JOINED_FOR_ANALYSIS" = "true" ]; then
     MEMBER_NAME=$(google-api-proxy --json call --token-class GoogleChatAuthTokenAsUser \
       GET "https://chat.googleapis.com/v1/spaces/$SPACE_ID/members/me" | jq -r '.name')
     MEMBER_ID=$(echo "$MEMBER_NAME" | awk -F/ '{print $NF}')
     google-api-proxy --json call --token-class GoogleChatAuthTokenAsUser \
       DELETE "https://chat.googleapis.com/v1/spaces/$SPACE_ID/members/$MEMBER_ID"
   fi

   # Save JSON result to notes (orchestrator also reads this from /tmp)
   cp /tmp/SXXXXXX_result.json ~/notes/users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/SXXXXXX.json

   # Commit and push both the report and JSON result
   cd ~/notes && sl add users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/SXXXXXX.md users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/SXXXXXX.json && sl commit -m "SEV analysis: report and result for SXXXXXX" --reason "commit sev report - sl help commit" && sl push --to manishr --reason "push sev report - sl help push"
   ```

6. **Return a comprehensive JSON result** capturing all SEV data — this is what the orchestrator uses to write weekly-results.json. Include everything directly from the SEV API and analysis (do NOT parse markdown to fill these fields):
   ```json
   {
     "sev_number": "SXXXXXX",
     "status": "done",
     "analysis_date": "<today YYYY-MM-DD>",
     "report_path": "~/notes/users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/SXXXXXX.md",
     "week": "YYYY-MM-DD",
     "summary": "<one-line key finding>",

     "level": "<from sev_metadata.level>",
     "title": "<from sev_metadata.title>",
     "sev_status": "<from sev_metadata.status>",
     "time_started": "<from sev_metadata.time_started, or first GChat message timestamp if empty>",
     "duration_hours": <number or null>,

     "oncall_primary": "<unixname from check_oncall script>",
     "oncall_secondary": "<unixname from check_oncall script or null>",
     "area_lead_assigned": <true|false|null>,
     "area_lead_name": "<unixname or null>",

     "gchat_participants": <number or null>,
     "gchat_messages": <number or null>,
     "total_engineers_involved": <number>,
     "runtime_team_members_count": <number>,
     "runtime_team_members_list": ["<unixname>", ...],
     "time_to_detect_minutes": <number or null>,
     "time_to_mitigate_hours": <number or null>,
     "time_to_runtime_engagement_minutes": <number or null>,
     "surfaces_impacted": ["<surface>", ...],

     "root_cause_category": "<internal|external|infra|unknown>",
     "sub_area": "<serving|model_freshness|hardware|binary_release|observability|bad_request|other>",
     "team_effort_hours": <number>,
     "runtime_drove_mitigation": <true|false>,
     "runtime_drove_fix": <true|false>,
     "key_runtime_contributor": "<unixname or null>",
     "ownership_gaps": <number>,
     "effort_avoidable": <true|false|null>,
     "effort_avoidable_hours": <number or null>,
     "preventable": <true|false|null>,
     "preventable_reason": "<string or null>",
     "recurring_themes": ["<theme>", ...],
     "oncall_concurrent_sevs": <number or null>,
     "repeat_related_sev": "<SXXXXXX or null>",

     "followup_actions_filed": <true|false>,
     "followup_actions_count": <number>,
     "has_runtime_followup_tasks": <true|false>,
     "runtime_followup_tasks": [{"task_id": "TXXXXXX", "owner": "...", "status": "..."}],

     "runtime_members_detail": [
       {"member": "<unixname>", "role": "primary_oncall|secondary_oncall|SME",
        "first_message": "<timestamp>", "last_message": "<timestamp>",
        "est_active_hours": <number>, "key_contributions": "<string>"}
     ],
     "key_external_contributors": [
       {"unixname": "<unixname>", "messages": <number or null>, "role": "<string>"}
     ]
   }
   ```

**Focus each analysis on actionable insights**:
- What could have reduced time-to-detect or time-to-mitigate?
- Was oncall engaged on something outside their domain? Could triage be faster?
- Are there systemic patterns (same sub-area, same root cause category)?
- What follow-up tasks would actually reduce future operational load?

### Step 4: Collect Results → Weekly Files → Update Tracking

After all sub-agents return:

**4a. Write weekly-results JSON** — for each sub-agent result, upsert into the weekly JSON using the `from-json` mode (no markdown parsing):
```bash
# For each sub-agent result saved to /tmp/SXXXXXX_result.json:
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/update_weekly_json.py \
    from-json /tmp/SXXXXXX_result.json YYYY-MM-DD ~/notes/users/manishr/analysis/q1sevs
```
This writes directly from the sub-agent JSON — sev_number, level, title, oncall, all analysis fields — into:
```
~/notes/users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/weekly-results.json
```

**4b. Write weekly report** at `~/notes/users/manishr/analysis/q1sevs/reports/YYYY-MM-DD/weekly-report.md`:
```markdown
# Weekly SEV Report — Fri <date> – Thu <date+6>, 2026

## Oncall Coverage
- **Primary:** <name> <dates>
- **Secondary:** <name> <dates>

## Summary
- Total SEVs: N
- Analyzed: N | Blocked: N
- [brief narrative]

## Operational Load Distribution
[Which sub-areas generated the most SEV work this week]

## Out-of-Domain Triage
[How much effort was spent on SEVs where root cause is external to Runtime Team]

## Ownership Assessment
[Systemic gaps observed this week]

## Actionable Follow-ups
[Concrete recommendations from this week's SEVs]

## Individual SEV Summaries
| SEV | Level | Root Cause | Sub-area | Effort (hrs) | Avoidable | Key Finding |
|---|---|---|---|---|---|---|
[one row per SEV]
```

**4c. Update tracking file** — for each sub-agent result, set the SEV entry in the appropriate tracking file (metadata/tracking.json or metadata/tracking-q1-early.json) to the returned JSON (status, analysis_date, report_path, summary, etc.).

**4d. Commit and push everything**:
```bash
cd ~/notes
sl add users/manishr/analysis/q1sevs/
sl commit -m "SEV analysis: week YYYY-MM-DD — N SEVs analyzed, weekly report written"
sl push --to manishr --reason "push sev analysis updates - sl help push"
```

### Step 5: Offer to Continue or Stop

After each weekly batch, ask the user:
- "Week YYYY-MM-DD done. N weeks remaining (list them). Run the next week or stop here?"

### Phase 3: Aggregate Summary

Only when **all weekly reports for the chosen analysis period exist** AND reviewed by the user. Follow Step 7 in the workflow. Focus on:

1. **Operational load distribution**: Which sub-areas generate the most SEV work?
2. **Out-of-domain triage**: How much effort is spent on SEVs where root cause is external?
3. **Actionable follow-ups**: Concrete recommendations to reduce future SEV engagement
4. **Ownership scorecard**: Where are the systemic gaps across all SEVs?

Write the aggregate report to `~/notes/users/manishr/analysis/q1sevs/aggregate-summary.md`.

## Blocking and Skipping SEVs

**Blocked (GChat access)**: If `meta sevmanager.chat join` fails and message list returns empty, mark as blocked and notify the user. Do NOT analyze without GChat data.
```json
{
  "status": "blocked",
  "block_reason": "Cannot join GChat space — user action needed"
}
```

**Skipped**: Only for SEVs where the SEV tool itself returns no useful data (e.g., empty metadata, no comments, no history). GChat access alone is not a skip reason.
```json
{
  "status": "skipped",
  "skip_reason": "SEV tool returned empty metadata and no comments"
}
```

## Files

All tracking and reports are in the **notes repo** (`~/notes`), not fbsource. This avoids code review requirements and keeps tracking next to reports.

| File | Purpose |
|---|---|
| `metadata/tracking.json` | Mar-Apr tracking — per-SEV status. Updated once per batch after all sub-agents complete. |
| `metadata/tracking-q1-early.json` | Jan-Mar tracking — per-SEV status. Updated once per batch after all sub-agents complete. |
| `metadata/batches/week-YYYY-MM-DD.md` | Batch prompt for each oncall week — lists SEVs, oncall coverage, sub-agent instructions |
| `metadata/sevs-30d.json` | Raw discovery data for Mar-Apr period |
| `metadata/sevs-q1-early.json` | Raw discovery data for Jan-Mar period |
| `reports/YYYY-MM-DD/weekly-results.json` | Collected sub-agent results for a week (written after batch completes) |
| `reports/YYYY-MM-DD/weekly-report.md` | Weekly narrative report (written after batch completes) |
| `reports/YYYY-MM-DD/SXXXXXX.md` | Individual SEV reports (one per SEV, written by sub-agents) |
| `aggregate-summary.md` | Final aggregate summary (written after all weeks complete) |
| `references/sev-analysis-workflow.md` (in fbsource skill) | Detailed per-SEV analysis workflow |
| `SKILL.md` (in fbsource skill) | This file |
