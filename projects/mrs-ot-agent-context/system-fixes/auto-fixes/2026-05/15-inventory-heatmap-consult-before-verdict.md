```yaml
fix_id: inventory-heatmap-consult-before-verdict
title: Consult inventory/heatmap.md hot cells before locking in per-incident verdict
status: 🟡 drafted (depends on inventory layer landing)
identified: 2026-05-20 thread pjTRT7ubzUs
target: team_bot/cron-jobs/ot-alert-monitor.md, ot-sev-monitor.md
section: Triage discipline — cross-incident pattern check
impact: Catches spreading patterns at first alert, not at fifth
cost: ~5-line cron prompt amendment (requires inventory cron promoted first)
```

## Gap

Tonight's "5 IG retrieval-family holdout E2E latency alerts in <24h" pattern was invisible until the 5th instance — each cron triage saw 1 alert at a time. Inventory + heatmap fixes this: a hot cell (e.g., IG/Reels × P-η ≥3) is visible at first alert.

## Patch

```
INVENTORY + HEATMAP CONSULT (apply after registry-first-triage, before
emitting verdict):

  1. Look up the alert's model_id in auto-learnings/inventory/models.md
     → get PG, product, role, oncall_modeling, owner

  2. Identify the cell in auto-learnings/inventory/heatmap.md:
     - Row: <PG> / <product> (or / <role> for the role-sliced heatmap)
     - Column: corresponding S-NNN / M-NNN / P-NNN
     - Value: current count

  3. If the cell is a HOT CELL (auto-flagged ≥3 in 24h per ot-pg-trending):
     - Per-incident verdict still emits but with prefix:
       "⚠️ HOT CELL: <slice> × <pattern> = <N> in 24h
        See auto-learnings/inventory/heatmap.md for context."
     - Add R-VC4 family-recurrence trigger (see 08-).
     - Recommend pattern-level defense (P-NNN), not just per-incident fix.

  4. If the cell is NEW (no prior history in 7d but spiking today):
     - Flag explicitly: "⬆️ NEW pattern detected"
     - Lower confidence threshold (proactive surface even if first signal weak)

  5. If model_id NOT in inventory/models.md:
     - Flag for operator categorization
     - Log to auto-learnings/inventory/models-pending-review.md

This fix DEPENDS ON the inventory layer being landed
(see auto-learnings/inventory/proposed-crons/). Until that lands,
this fix is on hold.
```

## Triggering evidence

- 2026-05-20 multiple threads — 5 IG retrieval holdout family alerts triaged individually; pattern visible only retrospectively

## Validation

- [ ] After landing: monitor cron emit prefix "⚠️ HOT CELL" occurrences; should appear on real spikes
- [ ] Track operator response to hot-cell flags (acknowledged / actioned / dismissed)

## Related

- `auto-learnings/inventory/heatmap.md`
- `auto-learnings/inventory/proposed-crons/ot-pg-trending.md`
- `08-r-vc4-family-recurrence-trigger.md`
