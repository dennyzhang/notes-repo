# Backfill Guide: Adding Oncall Data to Existing SEV Reports

This guide shows how to retroactively add deterministic oncall and area lead data to the 109 already-analyzed SEV reports from the Mar-Apr 2026 period.

## Prerequisites

1. **Oncall schedule data**: Fetch the full oncall schedule for the analysis period

```bash
meta oncall.rotation schedule --rotation ip_runtime \
    --start "2026-01-01" --end "2026-04-30" --limit 300 -o json \
    > /tmp/oncall_schedule.json
```

2. **Verify schedule coverage**: Check that you have data for the full period

```bash
jq '[.[].start] | min, max' /tmp/oncall_schedule.json
# Should show: "2024-10-31 11:00" to "2026-04-17 10:00" or similar
```

## Running the Backfill

### Test with a Single SEV First (Recommended)

Before updating all 109 reports, test with one SEV to verify the script works correctly:

```bash
# Create a test tracking file with just one SEV
jq '{period: .period, sevs: [.sevs[0]]}' \
    ~/notes/users/manishr/analysis/q1sevs/metadata/tracking.json \
    > /tmp/test_tracking.json

# Run backfill on test file
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/backfill_oncall_data.py \
    /tmp/test_tracking.json \
    /tmp/oncall_schedule.json

# Review the output and check the updated report
cat ~/notes/users/manishr/analysis/q1sevs/reports/2026-04-10/S648791.md | head -50
```

**What to check:**
- Script output shows oncall members found
- Report Quick Stats table has new rows for oncall data
- Tracking JSON has new fields: `oncall_primary`, `oncall_secondary`

### Full Backfill for Mar-Apr Period (109 SEVs)

Once you've verified the test works:

```bash
# Backfill all 109 analyzed SEVs from Mar-Apr 2026
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/backfill_oncall_data.py \
    ~/notes/users/manishr/analysis/q1sevs/metadata/tracking.json \
    /tmp/oncall_schedule.json
```

This will:
- Process all 109 SEVs with `status: "done"`
- Update each report's Quick Stats table
- Update tracking.json with new fields
- Print progress for each SEV

**Expected runtime:** ~5-10 minutes (fetches metadata for each SEV via meta CLI)

### Backfill Q1 Early Period (When Available)

Once Q1 early SEVs are analyzed:

```bash
python3 fbcode/ip_runtime/skills/sev-team-analysis/scripts/backfill_oncall_data.py \
    ~/notes/users/manishr/analysis/q1sevs/metadata/tracking-q1-early.json \
    /tmp/oncall_schedule.json
```

## What Gets Updated

### In Each SEV Report (markdown file)

New rows added to Quick Stats table:

```markdown
| Oncall on duty (at SEV start) | manishr |
| Oncall secondary (at SEV start) | whycz |
| Area lead assigned? | N/A |
| Area lead name | N/A |
```

The script preserves all existing content and only adds new rows.

### In Tracking JSON

New fields added to each SEV entry:

```json
{
  "sev_number": "S648791",
  "oncall_primary": "manishr",
  "oncall_secondary": "whycz",
  "area_lead_assigned": null,
  "area_lead_name": null,
  ...
}
```

## Post-Backfill Tasks

### 1. Review Changes

```bash
# Check how many reports were updated
grep -r "Oncall on duty (at SEV start)" ~/notes/users/manishr/analysis/q1sevs/reports/ | wc -l

# Spot-check a few reports
cat ~/notes/users/manishr/analysis/q1sevs/reports/2026-03-20/S644012.md | grep -A10 "Quick Stats"
```

### 2. Manual Area Lead Verification

For SEVs not owned by Runtime Team members, manually verify area lead assignment:

1. Visit SEV in SEV Manager UI
2. Check "Active Areas" section
3. Look for "RecSys Runtime" (tag ID: 253058003073680)
4. If assigned, note the area lead name
5. Update report and tracking JSON manually

### 3. Commit and Push

```bash
cd ~/notes
sl add users/manishr/analysis/q1sevs/
sl commit -m "$(cat <<'EOF'
Backfill oncall and area lead data for 109 Mar-Apr SEVs

Added deterministic oncall lookup data to all analyzed SEV reports:
- Oncall on duty (at SEV start): From official ip_runtime schedule
- Oncall secondary (at SEV start): From official ip_runtime schedule
- Area lead assigned/name: Placeholder for manual verification

This replaces manually-inferred oncall assignments with authoritative
schedule data, enabling accurate oncall load analysis.

Updated:
- 109 SEV report markdown files (Quick Stats table)
- metadata/tracking.json (new fields per SEV)
EOF
)" --reason "backfill oncall data - sl help commit"

sl push --to manishr --reason "push backfilled data - sl help push"
```

## Interpreting the Results

### Oncall vs. Handler Discrepancy

You may find cases where the oncall on duty differs from who actually handled the SEV. For example:

- **Oncall on duty**: manishr, whycz
- **Who handled it**: bwindsor (opened SEV, drove mitigation)

This is **expected** and **valuable data** because it reveals:
1. Load-sharing patterns (who helps beyond their shift)
2. Oncall coverage gaps (why didn't oncall handle it)
3. Domain expertise clustering (certain people always handle certain types)

### Area Lead Assignment Gaps

SEVs marked with `area_lead_assigned: null` indicate:
- Runtime Team participated but didn't own the SEV
- No automated way to verify if Runtime area lead was assigned
- Manual verification needed for accountability tracking

## Troubleshooting

### "No oncall found" warnings

If the script reports `primary_oncall: null`, it means:
- SEV started outside any scheduled oncall shift (gap in schedule)
- Schedule data doesn't cover that time period
- Need to fetch extended schedule data

Fix:
```bash
# Extend schedule fetch period
meta oncall.rotation schedule --rotation ip_runtime \
    --start "2025-12-01" --end "2026-05-31" --limit 500 -o json \
    > /tmp/oncall_schedule_extended.json

# Re-run backfill with extended data
```

### "Report not found" warnings

If the script can't find a report file:
- Check `oncall_week` value in tracking JSON
- Verify report exists at: `reports/{oncall_week}/{sev_number}.md`
- May indicate tracking data is out of sync with actual reports

### Script errors on SEV metadata fetch

Some SEVs may be inaccessible or deleted. The script handles this gracefully:
- Logs error message
- Skips that SEV
- Continues with remaining SEVs
- Original tracking entry preserved

## Example Output

```
Loaded 109 SEVs from tracking.json
Loaded 200 oncall shifts

Processing 109 analyzed SEVs...

  Processing S648791...
    Oncall: manishr (primary), whycz (secondary)
    Area lead: Manual verification required
    Updated report: /home/manishr/notes/users/manishr/analysis/q1sevs/reports/2026-04-10/S648791.md

  Processing S648074...
    Oncall: manishr (primary), whycz (secondary)
    Area lead: Manual verification required
    Updated report: /home/manishr/notes/users/manishr/analysis/q1sevs/reports/2026-04-10/S648074.md

  ...

✓ Updated tracking file: ~/notes/users/manishr/analysis/q1sevs/metadata/tracking.json

Next steps:
  1. Review updated reports in ~/notes/users/manishr/analysis/q1sevs/reports
  2. Manually verify area lead assignments for SEVs marked as requiring verification
  3. Commit changes: [commands shown above]
```
