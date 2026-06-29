# Backfill Guide: Update Weekly JSON Files with Enhanced Data

This guide shows how to retroactively extract structured data from all 109 SEV reports and update the weekly-results.json files with 40+ fields for rich analysis and visualization.

## What Gets Added

### Current Weekly JSON (15 fields)
- sev_number, status, analysis_date, report_path, summary
- root_cause_category, sub_area, team_effort_hours, ownership_gaps
- effort_avoidable, preventable, preventable_reason
- recurring_themes, oncall_concurrent_sevs, followup_actions_filed

### After Backfill (40+ fields)

**New SEV Metadata:**
- level (SEV2/SEV3)
- title
- time_started, duration_hours
- sev_status (Mitigated/In Progress/Closed)
- gchat_participants, gchat_messages

**New Impact Metrics:**
- total_engineers_involved
- runtime_team_members_count, runtime_team_members_list
- runtime_participation_rate
- time_to_detect_minutes, time_to_mitigate_hours
- time_to_runtime_engagement_minutes
- surfaces_impacted

**New Ownership:**
- runtime_drove_mitigation, runtime_drove_fix
- key_runtime_contributor
- oncall_primary, oncall_secondary (from backfill_oncall_data.py)
- repeat_related_sev

**New Follow-up Tracking:**
- followup_actions_count
- has_runtime_followup_tasks
- runtime_followup_tasks (array with task_id, owner, status)

**New Team Engagement:**
- runtime_members_detail (array):
  - member (unixname)
  - role (primary_oncall, secondary_oncall, SME)
  - first_message, last_message
  - est_active_hours
  - key_contributions
- key_external_contributors (top 5)

**Enhanced Existing:**
- effort_avoidable_hours (numeric extraction from report)

## Prerequisites

None! The scripts parse existing markdown reports. No external data needed.

## Running the Backfill

### Option 1: Backfill Everything (Recommended)

```bash
# Update all weekly JSON files from all reports
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/update_weekly_json.py \
    backfill ~/notes/users/manishr/analysis/q1sevs
```

This will:
- Find all `weekly-results.json` files
- For each week, parse all SEV reports in that directory
- Extract 40+ fields from each report
- Merge with existing JSON (preserving status, analysis_date, summary)
- Write updated weekly JSON files

**Expected runtime:** ~30-60 seconds (parses 109 reports)

### Option 2: Update One Week at a Time

For testing or if you want more control:

```bash
# Test with one week first
cd ~/notes/users/manishr/analysis/q1sevs/reports/2026-04-10

# Update just this week's JSON
python3 /data/users/manishr/fbsource/fbcode/ip_runtime/skills/sev-team-analysis/scripts/update_weekly_json.py \
    backfill ~/notes/users/manishr/analysis/q1sevs

# Check the result
jq '.sevs[0] | keys | length' weekly-results.json  # Should be 40+
```

## What to Expect

### Before Backfill

```json
{
  "sev_number": "S648074",
  "status": "done",
  "summary": "...",
  "root_cause_category": "external",
  "team_effort_hours": 18,
  ...
}
// 15 fields total
```

### After Backfill

```json
{
  "sev_number": "S648074",
  "level": "SEV2",
  "title": "Multiple IFR MTML Models Crash-looping...",
  "duration_hours": 30.6,
  "gchat_participants": 30,
  "total_engineers_involved": 30,
  "runtime_team_members_list": ["manishr", "wanyunluc", "changhao", "jaar", "tja"],
  "time_to_detect_minutes": 91.3,
  "time_to_mitigate_hours": 30.6,
  "runtime_drove_mitigation": false,
  "oncall_primary": "manishr",
  "runtime_members_detail": [
    {
      "member": "manishr",
      "role": null,  // Will be enriched by backfill_oncall_data.py
      "est_active_hours": 8,
      "key_contributions": "Lead coordinator, AI analysis..."
    }
  ],
  "runtime_followup_tasks": [
    {"task_id": "T264765122", "owner": "wanyunluc", "status": "Open"}
  ],
  ...
}
// 40+ fields total
```

## Output

```
Found 5 weekly JSON files to update

Processing week 2026-03-13...
    ✓ Updated S640381
    ✓ Updated S641234
    ...
  Updated 21 SEVs

Processing week 2026-03-20...
    ✓ Updated S644012
    ...
  Updated 24 SEVs

...

✓ Backfill complete: 109 SEVs updated across 5 weeks

Next steps:
  1. Review updated JSON files in ~/notes/users/manishr/analysis/q1sevs/reports/
  2. Commit changes:
     cd ~/notes
     sl add users/manishr/analysis/q1sevs/reports/
     sl commit -m "Update weekly JSON with enhanced SEV data" --reason "update json - sl help commit"
     sl push --to manishr --reason "push json updates - sl help push"
```

## Verification

Check that fields were extracted correctly:

```bash
# Count fields in updated JSON
jq '.sevs[0] | keys | length' ~/notes/users/manishr/analysis/q1sevs/reports/2026-04-10/weekly-results.json
# Should show 40+

# Check specific fields
jq '.sevs[] | select(.sev_number == "S648074") | {
  level,
  duration_hours,
  oncall_primary,
  runtime_members_detail: (.runtime_members_detail | length),
  followup_tasks: (.runtime_followup_tasks | length)
}' ~/notes/users/manishr/analysis/q1sevs/reports/2026-04-10/weekly-results.json
```

## Combining with Oncall Backfill

For complete enrichment, run both backfills:

```bash
# 1. First, backfill oncall data (adds oncall_primary/secondary, area_lead)
#    See BACKFILL_GUIDE.md for details
meta oncall.rotation schedule --rotation ip_runtime \
    --start "2026-01-01" --end "2026-04-30" --limit 300 -o json \
    > /tmp/oncall_schedule.json

python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/backfill_oncall_data.py \
    ~/notes/users/manishr/analysis/q1sevs/metadata/tracking.json \
    /tmp/oncall_schedule.json

# 2. Then, update weekly JSONs (extracts all data including updated oncall fields)
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/update_weekly_json.py \
    backfill ~/notes/users/manishr/analysis/q1sevs
```

The weekly JSON update will pick up the oncall_primary/secondary fields that were added to the reports by the oncall backfill.

## Post-Backfill

### Review Changes

```bash
# See what changed
cd ~/notes
sl diff users/manishr/analysis/q1sevs/reports/

# Check a sample week
jq '.sevs[0]' users/manishr/analysis/q1sevs/reports/2026-04-10/weekly-results.json | head -50
```

### Commit

```bash
cd ~/notes
sl add users/manishr/analysis/q1sevs/reports/
sl commit -m "$(cat <<'EOF'
Update weekly JSON files with enhanced SEV data

Extracted 40+ structured fields from all 109 SEV reports:
- SEV metadata: level, title, duration, GChat stats
- Impact metrics: team size, timing, surfaces
- Ownership: who drove mitigation/fix, oncall, key contributors
- Team engagement: member roles, timing, contributions
- Follow-ups: task IDs, owners, statuses

Enables rich analysis and visualization:
- Load dashboards (individual effort, oncall vs SME)
- Effectiveness metrics (detection/mitigation times)
- Root cause trends (category distribution)
- Follow-up tracking (task status, preventability)
- Oncall analysis (concurrent SEVs, engagement timing)
EOF
)" --reason "update weekly json - sl help commit"

sl push --to manishr --reason "push json updates - sl help push"
```

## Use Cases Enabled

With the enhanced weekly JSON, you can now easily:

### Load Analysis
```bash
# Who worked the most across all SEVs?
jq '[.sevs[].runtime_members_detail[] | {member, hours: .est_active_hours}] |
    group_by(.member) |
    map({member: .[0].member, total_hours: (map(.hours) | add)}) |
    sort_by(.total_hours) | reverse' reports/*/weekly-results.json
```

### Effectiveness Metrics
```bash
# Average detection time
jq '[.sevs[].time_to_detect_minutes] | add / length' reports/*/weekly-results.json

# Avoidable effort
jq '[.sevs[] | select(.effort_avoidable_hours)] |
    {total_effort: (map(.team_effort_hours) | add),
     avoidable: (map(.effort_avoidable_hours) | add)}' reports/*/weekly-results.json
```

### Oncall Analysis
```bash
# Who was oncall for the most SEVs?
jq '[.sevs[].oncall_primary] | group_by(.) |
    map({oncall: .[0], count: length}) |
    sort_by(.count) | reverse' reports/*/weekly-results.json
```

### Follow-up Tracking
```bash
# How many follow-up tasks per person?
jq '[.sevs[].runtime_followup_tasks[] | .owner] |
    group_by(.) |
    map({owner: .[0], count: length})' reports/*/weekly-results.json
```

## Troubleshooting

### Missing fields in output

Some fields may be missing if the report doesn't have them:
- `time_started` - if Timeline section is not in expected format
- `runtime_participation_rate` - if Quick Stats doesn't have this row
- `role` in runtime_members_detail - will be null until oncall backfill runs

This is expected. The script extracts what's available.

### "Report not found" warnings

If a weekly JSON references a SEV but the report doesn't exist:
- Check if the report is in the correct week directory
- Check tracking.json oncall_week field
- May indicate incomplete analysis

### Parsing errors

If a report has non-standard formatting, some fields may not extract correctly. The script is defensive and returns partial data rather than failing. Check the output JSON to see what was extracted.
