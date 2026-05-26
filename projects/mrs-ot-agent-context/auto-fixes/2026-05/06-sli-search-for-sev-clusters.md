```yaml
fix_id: sli-search-for-sev-clusters
title: SEV cluster search by shared SLI (primary), title keyword (secondary)
status: 🟡 drafted
identified: 2026-05-20 thread _aJ06YzXb1o
target: team_bot/cron-jobs/ot-sev-monitor.md
section: SEV cluster identification
impact: Catches cluster siblings the title-keyword search misses
cost: ~5-line cron prompt amendment
```

## Gap

When triaging a SEV cluster announcement (≥2 sibling SEVs), bot searched by title keyword (`umia`, `cogwheel`, `publish_all`, `timeout`, `conveyor`, owner) and failed to find the 2nd SEV (S666413). Cron found it via the **shared SLI** `mrs_ml/v1_instagram / IGR Trunk Stability`.

## Patch

### Before

```
For each SEV:
  Search siblings via: meta sevmanager.sev list --in-progress --title-contains <keyword>
```

### After

```
SEV CLUSTER SEARCH — SHARED SLI IS PRIMARY:

  1. Pull SEV's linked_slis field via:
     meta sevmanager.sev describe --sev=<num>

  2. Search for siblings sharing the SLI:
     meta sevmanager.sev list --in-progress \
       --filter "linked_slis CONTAINS <SLI>"
     (if SLI filter unavailable: fall back to full list + post-filter)

  3. Title-keyword search is SECONDARY (use when SLI is absent or
     too broad):
     meta sevmanager.sev list --in-progress --title-contains <kw>

  4. ADD: search by conveyor name. If SEV mentions a conveyor (e.g.,
     mvai/umia_v1_igr, mvai/mvai_ifr_main):
     meta sevmanager.sev list --in-progress --title-contains <conveyor>

  5. ADD: search by owner if SEV has explicit clear ownership:
     meta sevmanager.sev list --in-progress --owner <unixname>

  6. Cluster recognition signal: 2+ SEVs sharing SLI within same week,
     created within hours of each other, with related (but not identical)
     symptoms → conveyor regression cluster. Apply M-012 reasoning.

SANITY CHECK: when SEV title contains the cluster name (e.g., "mvai/X
conveyor blocked"), search MUST also include the cluster as a keyword.
"umia" matches umia_v1_igr but not "conveyor"; the broader search nets
sibling SEVs that don't share the specific submodel name.
```

## Triggering evidence

- 2026-05-20 _aJ06YzXb1o — cron found S666322 + S666413 cluster via SLI; my title-keyword search missed S666413

## Validation

- [ ] Audit cluster triages over 7d; for any cluster announcement, SLI was the discriminating evidence
- [ ] Apply to historical cluster SEVs from resolved-sevs/; verify SLI-search would have caught siblings

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F evidence-completeness checklist
- `auto-learnings/patterns/mechanisms.md` M-009 cogwheel publish failure class (cluster home)
