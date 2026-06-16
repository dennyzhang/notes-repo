```yaml
fix_id: mega-learnings-grep-for-detector-name
title: Grep auto-learnings/summaries/ for detector name before triaging mvai_metrics alerts
status: 🟡 drafted
identified: 2026-05-20 thread 0ad4RSnVzyQ (m877766932 D75703936)
target: team_bot/cron-jobs/ot-alert-monitor.md
section: Triage step — detector validation
impact: Catches known-broken detectors immediately; eliminates false-positive triage
cost: ~5-line cron prompt amendment
```

## Gap

For m877766932 (`facebook_reels_vdd_hstu_v0`), bot derived "upstream DPP/Scribe data lag" as root cause. Actual root cause: D75703936 formula bug in `checkpoint_training_data_age_mins` detector — known-broken, documented in `auto-learnings/summaries/weekly/2026-W21.md` mega-learning. Bot didn't check the mega-learnings corpus.

## Patch

```
DETECTOR VALIDATION (apply during registry-first-triage step):

  When alert source is `mvai_metrics` or `checkpoint_*` detector:

  1. Grep auto-learnings/summaries/ for the detector name + key metrics:
     grep -r "<detector_name|metric_name>" auto-learnings/summaries/

  2. ALSO grep for diff IDs mentioned alongside known-broken detectors:
     grep -r "D[0-9]\{7,\}" auto-learnings/summaries/ | grep -i broken

  3. If match found — detector has a known issue:
     - Adopt DETECTOR_BROKEN classification (M-016)
     - Cite the mega-learning entry as source
     - Don't continue to derive root cause from first principles
     - Don't recommend operator action on the model itself; route to
       detector owner instead

  4. Common known-broken detectors (as of 2026-05-20):
     - D75703936 formula bug — checkpoint_training_data_age_mins UTC/PDT
       timezone shift produces ~3000-min false positive at restart
       (auto-learnings/summaries/weekly/2026-W21.md)
     - <add others as they're discovered>

This pairs with registry-first-triage (03-) — that fix adds the registry
consult; this one adds the SPECIFIC mega-learnings grep for detector-broken
patterns.
```

## Triggering evidence

- 2026-05-20 thread 0ad4RSnVzyQ — m877766932 CRITICAL training_data_age alert was DETECTOR_BROKEN per W21 mega-learning; bot's prior triage missed it

## Validation

- [ ] Every mvai_metrics / checkpoint_* detector alert: verdict cites mega-learnings grep result
- [ ] D75703936-class false positives → DETECTOR_BROKEN, never paged to model owner

## Related

- `03-registry-first-triage.md` (parent discipline)
- `auto-learnings/patterns/root-causes.md` D75703936-formula-bug entry
