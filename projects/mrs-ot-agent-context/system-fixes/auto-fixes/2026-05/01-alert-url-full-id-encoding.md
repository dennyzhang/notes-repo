```yaml
fix_id: alert-url-full-id-encoding
title: Cron output: emit full URL-encoded alert_id (including @#$ suffix)
status: 🟡 drafted
identified: 2026-05-20 thread jrXXZbszX8E
target: team_bot/cron-jobs/ot-alert-monitor.md (also ot-sev-monitor.md, ot-post-monitor.md, daily-brief.md — any cron that emits alert URLs)
section: GChat output / alert link format
impact: 100% of alert URLs become click-through valid
cost: ~10-line cron prompt amendment per cron
```

## Gap

Cron emits alert URLs containing only the numeric prefix of `alert_id`:
```
https://www.internalfb.com/onedetection/alert?alert_id=25209897055308328
```

Actual OneDetection alert_ids have a compound format:
```
25209897055308328@#$mvai_metrics@#${column:count; job_name:...}@#$<title>
```

OneDetection cannot disambiguate the specific sub-alert without the `@#$<entity>@#$<key>@#$<title>` suffix. Truncated URLs land on a generic detector view OR 404 entirely.

## Triggering evidence

- 2026-05-20 jrXXZbszX8E (m878858380 NaN sub-alert) — operator clicked link, got invalid
- Pattern: any compound alert_id stripped to numeric prefix when emitted
- Likely also affects auto-archived alert URLs (resolved-alerts/) — worth retro-fix

## Patch

### Before

(In cron prompt — alert URL format guidance)

```
When emitting an alert URL in chat:
  https://www.internalfb.com/onedetection/alert?alert_created_time=<epoch>&alert_id=<numeric_prefix>
```

### After

```
When emitting an alert URL in chat:
  1. Fetch the FULL alert_id via `meta monitoring.alert metadata --alert '<full-id>'`.
     The full id has the form: <numeric>@#$<entity>@#$<key>@#$<title>
  2. URL-encode the full id (@ → %40, # → %23, $ → %24, space → +).
  3. Emit:
     https://www.internalfb.com/onedetection/alert?alert_created_time=<epoch>&alert_id=<encoded_full_id>
  4. NEVER strip the @#$ suffix. OneDetection cannot disambiguate sub-alerts
     without it. A truncated URL is worse than no URL — it leads to confusion.

SANITY CHECK: the emitted URL should have %40%23%24 segments. If the URL
contains ONLY a numeric alert_id with no encoded special chars, the fix
hasn't been applied.
```

## Why this fix

OneDetection sub-alerts share a numeric prefix when they belong to the same detector; the suffix is the unique identifier. Truncation makes every operator click manually re-search for the specific sub-alert, defeating the purpose of the embedded link.

## Validation

- [ ] After landing, click an emitted alert URL from a fresh cron run; should land on the specific sub-alert page, not a detector overview
- [ ] Grep recent emit history (last 24h after landing) for any `alert_id=<short>` without `%40%23%24` — count should be 0
- [ ] Test on compound alert (multiple sub-alerts on same detector) — each sub-alert URL should resolve distinctly

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F output-quality checklist
- `02-thread-anchoring.md` (companion fix for thread anchoring)
