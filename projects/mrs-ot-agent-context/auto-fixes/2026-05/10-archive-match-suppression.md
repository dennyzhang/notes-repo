```yaml
fix_id: archive-match-suppression
title: Suppress re-triage on alerts that match an existing archive (already-diagnosed)
status: 🟡 drafted
identified: 2026-05-20 thread Uy1Yb4HyHfE + multiple
target: team_bot/cron-jobs/ot-alert-monitor.md
section: Pre-triage filter
impact: Eliminates duplicate-triage on stale re-fires
cost: ~10-line cron prompt amendment
```

## Gap

Alert IDs that have been archived (in `incidents/resolved-alerts/`) sometimes re-fire days later when the detector hasn't auto-cleared (M-017). Bot wastes triage cycles on alerts that were already analyzed and archived. Today's m2126189932 baseline alert `A1201406268614142` was archived 2026-05-17; re-fired 2026-05-20 03:15 PDT; bot re-triaged from scratch.

## Patch

```
PRE-TRIAGE ARCHIVE-MATCH CHECK (apply BEFORE pulling SEV/alert metadata):

  1. Extract alert_id (full, including @#$ suffix) from incoming alert

  2. Check archive: grep incidents/resolved-alerts/2026-*/  for alert_id

  3. If match found AND archive classifies the alert as one of:
       - DETECTOR_BROKEN (M-016)
       - STALE_FIRE (M-017)
       - THRESHOLD_MISFIT (R23)

     → SUPPRESS re-triage. Emit minimal heartbeat instead:
       "Re-fire of archived alert <A###>. Original archive: <path>.
        Classification: <class>. No new triage needed.
        If alert is now indicating REAL failure (different from archive):
        operator should re-categorize the archive (M-017 → REAL_OT_FAILURE)."

  4. If match found AND archive classified as REAL_OT_FAILURE_RECURRING:
     → Re-triage IS appropriate (recurrence). Cite archive in verdict
       as "Nth recurrence of pattern <CL-NNN>".

  5. If NO archive match: proceed with normal triage.

This pairs with M-017 detector-no-auto-clear pattern — the underlying
fix is in the detector framework (D-022). The suppression here is the
operational defense while detector tuning lands.
```

## Triggering evidence

- 2026-05-20 thread Uy1Yb4HyHfE — A1201406268614142 re-fired 3d after archive; bot re-triaged unnecessarily
- A1530150995193297 (12-day-old CRITICAL on ifu_i2i) — never archived but should be suppressed under same logic

## Validation

- [ ] After landing: count cron emits that suppress-via-archive-match vs proceed-with-triage
- [ ] Audit any DETECTOR_BROKEN re-classifications that should have suppressed

## Related

- `auto-learnings/patterns/mechanisms.md` M-017 detector-no-auto-clear
- `auto-learnings/patterns/defenses.md` D-021 archive-match suppression rule
