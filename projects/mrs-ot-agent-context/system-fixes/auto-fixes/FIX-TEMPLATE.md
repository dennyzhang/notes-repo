# Fix Template

```yaml
fix_id: <slug>
title: <one-line description>
status: 🟡 drafted | 🟢 approved | ✅ landed | ❌ rejected | ⏸ on hold
identified: <YYYY-MM-DD thread <id>>
target: <file path, e.g. team_bot/cron-jobs/ot-alert-monitor.md>
section: <section name within target>
impact: <expected error class closed>
cost: <estimated effort>
```

## Gap

What's currently wrong (specific behavior observed).

## Triggering evidence

- <SEV/alert/thread reference>
- <SEV/alert/thread reference>

## Patch

### Before

```
<current text in target>
```

### After

```
<proposed text in target>
```

## Why this fix

Explanation of how the patch closes the gap.

## Validation

How to verify the fix works once landed:

- [ ] <test 1>
- [ ] <test 2>

## Related

- `auto-fixes/<other related fixes>`
- `patterns/<S/M/R/P/D entity>` if applicable
- `IMPROVEMENT-PROPOSALS.md` <proposal letter>
