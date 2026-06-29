# SEV Analysis Scripts

Utilities for enriching SEV analysis with deterministic context.

## sev_context_enrichment.py

Provides deterministic lookup for oncall members and area lead assignment.

### Usage

#### 1. Check Oncall Members at SEV Start Time

Determines who was primary and secondary oncall when the SEV started:

```bash
# Fetch oncall schedule
meta oncall.rotation schedule --rotation ip_runtime \
    --start "2026-01-01" --end "2026-04-30" --limit 300 -o json \
    > /tmp/oncall_schedule.json

# Get SEV metadata
meta sevmanager.sev metadata --sev S648074 -o json > /tmp/sev_metadata.json

# Check oncall at SEV start time
python3 sev_context_enrichment.py check_oncall \
    /tmp/oncall_schedule.json /tmp/sev_metadata.json
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

#### 2. Classify Team Member Role

Determines if a team member was engaged as oncall or SME based on when they joined:

```bash
python3 sev_context_enrichment.py classify_member \
    /tmp/oncall_schedule.json manishr "2026-04-15 14:12:41"
```

Output:
```json
{
  "member": "manishr",
  "join_time": "2026-04-15 14:12",
  "role": "SME"  // or "primary_oncall" | "secondary_oncall"
}
```

#### 3. Check Area Lead Assignment

For SEVs not owned by Runtime Team, checks if Runtime area lead was assigned:

```bash
python3 sev_context_enrichment.py check_area_lead /tmp/sev_metadata.json
```

Output:
```json
{
  "area_lead_check_required": true,
  "active_areas_raw": "",
  "runtime_area_tags": {
    "253058003073680": "RecSys Runtime"
  },
  "instructions": "Check SEV UI for area lead assignment...",
  "sev_number": "S648074"
}
```

**Manual verification**: Visit the SEV in SEV Manager UI and check "Active Areas" section.

Expected Runtime area:
- **Tag ID**: 253058003073680
- **Name**: "RecSys Runtime"
- **Hierarchy**: "AI > Serving / Inference > RecSys Runtime"
- **Oncall**: ip_runtime

## Why Deterministic Oncall Lookup?

Previously, oncall information was inferred from GChat participation or manually noted. This approach:

1. **Eliminates ambiguity**: Uses the official oncall schedule as source of truth
2. **Enables accountability**: Clear distinction between oncall work vs SME support
3. **Supports load analysis**: Track how much work falls on oncall vs pulled-in experts
4. **Handles edge cases**: Correctly handles SEVs that span oncall shift changes

## extract_sev_data.py

Parse markdown SEV reports and extract structured data for JSON export.

### Usage

```bash
python3 extract_sev_data.py <report_path>
```

Output: JSON with 40+ fields extracted from the report

### Extracted Fields

- **SEV metadata**: level, title, time_started, duration, status, GChat stats
- **Impact metrics**: team size, timing (detect, mitigate, engagement), surfaces
- **Ownership**: who drove mitigation/fix, oncall, key contributors
- **Analysis**: root cause, effort, gaps, preventability
- **Team engagement**: member details with roles, timing, contributions
- **Follow-ups**: task IDs, owners, statuses

This is used internally by `update_weekly_json.py`.

## update_weekly_json.py

Update weekly-results.json files with enhanced data from SEV reports.

### Usage

**Single SEV (after writing a new report):**
```bash
python3 update_weekly_json.py S648074 2026-04-10 ~/notes/users/manishr/analysis/q1sevs
```

**Backfill all weeks:**
```bash
python3 update_weekly_json.py backfill ~/notes/users/manishr/analysis/q1sevs
```

### What It Does

For each SEV report:
1. Parses the markdown report using `extract_sev_data.py`
2. Extracts 40+ structured fields (see above)
3. Merges with existing weekly-results.json entry (preserves status, analysis_date, etc.)
4. Writes updated JSON

### Enhanced Weekly JSON Schema

Goes from **15 fields → 40+ fields**, enabling rich analysis:

```json
{
  "sev_number": "S648074",
  "level": "SEV2",
  "title": "Multiple IFR MTML Models Crash-looping...",
  "duration_hours": 30.6,
  "total_engineers_involved": 30,
  "runtime_team_members_list": ["manishr", "wanyunluc", ...],
  "time_to_detect_minutes": 91.3,
  "time_to_mitigate_hours": 30.6,
  "runtime_drove_mitigation": false,
  "oncall_primary": "manishr",
  "runtime_members_detail": [
    {
      "member": "manishr",
      "role": "SME",
      "est_active_hours": 8,
      "key_contributions": "Lead coordinator..."
    }
  ],
  "runtime_followup_tasks": [
    {"task_id": "T264765122", "owner": "wanyunluc", "status": "Open"}
  ],
  ...
}
```

### When to Use

- **After writing each new SEV report** - run single SEV mode to update weekly JSON
- **One-time backfill** - run backfill mode to update all existing reports

## backfill_oncall_data.py

Retroactively enrich already-analyzed SEV reports with oncall and area lead data.

### Usage

```bash
# First fetch oncall schedule for the full analysis period
meta oncall.rotation schedule --rotation ip_runtime \
    --start "2026-01-01" --end "2026-04-30" --limit 300 -o json \
    > /tmp/oncall_schedule.json

# Backfill Q1 early period (Jan 16 - Mar 17)
python3 backfill_oncall_data.py \
    ~/notes/users/manishr/analysis/q1sevs/metadata/tracking-q1-early.json \
    /tmp/oncall_schedule.json

# Backfill Mar-Apr period (Mar 18 - Apr 16)
python3 backfill_oncall_data.py \
    ~/notes/users/manishr/analysis/q1sevs/metadata/tracking.json \
    /tmp/oncall_schedule.json
```

### What It Does

For each SEV with `status: "done"`:

1. **Fetches SEV metadata** using `meta sevmanager.sev metadata`
2. **Determines oncall** at SEV start time using `sev_context_enrichment.get_oncall_at_time()`
3. **Updates markdown report**:
   - Adds "Oncall on duty (at SEV start)" row to Quick Stats table
   - Adds "Oncall secondary (at SEV start)" row
   - Adds "Area lead assigned?" and "Area lead name" rows (with placeholder for manual verification)
4. **Updates tracking JSON** with new fields:
   - `oncall_primary`
   - `oncall_secondary`
   - `area_lead_assigned` (null, requires manual verification)
   - `area_lead_name` (null, requires manual verification)

### After Running

1. Review updated reports in `~/notes/users/manishr/analysis/q1sevs/reports/`
2. For SEVs not owned by Runtime Team, manually verify area lead assignment in SEV UI and update reports
3. Commit changes:
   ```bash
   cd ~/notes
   sl add users/manishr/analysis/q1sevs/
   sl commit -m "Backfill oncall and area lead data" --reason "backfill sev data - sl help commit"
   sl push --to manishr --reason "push backfilled data - sl help push"
   ```

### Dry Run

To preview what would be updated without modifying files, review the script output. It prints:
- SEV number being processed
- Determined oncall members
- Whether report was updated
- Warnings for missing reports or tables

## Implementation Notes

- Uses `meta oncall.rotation schedule` as authoritative source
- Timestamp parsing handles both ISO format (`2026-04-17T15:48:52`) and simple format (`2026-04-17 15:48`)
- Skips "Shadow" and "Reverse Shadow" rotations (training only)
- For shift boundaries, uses standard interval semantics: `[start, end)`
- Backfill script preserves existing report content, only adds new rows to Quick Stats table
- Area lead assignment currently requires manual verification (SEV API doesn't expose active_areas structure)
