```yaml
fix_id: registry-first-triage
title: Cron triage must consult failure-patterns.md + patterns/ before emitting verdict
status: 🟡 drafted
identified: 2026-05-20 thread MQwOLaC3jLc
target: team_bot/cron-jobs/ot-alert-monitor.md, ot-sev-monitor.md, ot-post-monitor.md
section: Triage step ordering / verdict derivation
impact: Eliminates 3-5 classes of narrow-lens triage errors observed today
cost: ~30-line cron prompt amendment per cron
```

## Gap

The bot has been re-deriving cluster analysis from first principles on every triage instead of grep'ing the existing `auto-learnings/failure-patterns.md` registry + `auto-learnings/patterns/` knowledge graph. Result: tonight's triages mostly map to existing CL-NNN clusters that the bot didn't recognize.

| Triage today | Should have classified as | Registry status |
|---|---|---|
| m2130324780 STUS FS gap (missed PAGE) | CL-013 + CL-008 | visible at Rank #1 + #11 |
| S665454/S665478/S665464/S628346/S658165 | CL-012 | visible at Rank #6 |
| m2145491885 ITEM_EMB_DELTA misconfig | CL-018 | visible at Rank #9 |
| m2145336177 25min/hr training stall | CL-013 + new M-011 | live instance of Rank #1 |

## Triggering evidence

- Multiple narrow-lens triage errors in 2026-05-19/20 session, auditor flagged R-XR4 6+ times
- Operator framing 2026-05-20 thread MQwOLaC3jLc

## Patch

### Before

(Existing triage flow — cron pattern-matches symptoms ad-hoc)

```
1. Pull alert / SEV metadata
2. Cross-check active SEVs
3. Pull model.instance / MAST attempts
4. Classify per pattern recognition
5. Emit verdict
```

### After

```
TRIAGE STEP 0: PRE-VERDICT REGISTRY CHECK (BEFORE any other step)

Before pulling any data, grep the cluster registry for symptom keywords:

  Search 1: auto-learnings/failure-patterns.md
    grep -i '<symptom keyword>' for: "example_age", "snapshot", "FS missing",
    "QPS", "stuck", "NCCL", "publish", "scribe", etc.

  Search 2: auto-learnings/patterns/symptoms.md
    Match keyword → S-NNN entry

  Search 3: auto-learnings/patterns/edges.md
    Follow S → M → R → P → D edges

  Search 4: auto-learnings/summaries/*.md
    Grep mega-learning corpus for detector name (catches known-broken
    detectors like D75703936 formula bug)

If a matching CL-NNN or S-NNN cluster exists:
  1. Adopt the cluster's classification (CL-NNN / S-NNN) explicitly in the verdict
  2. Reference the cluster's status (chronic / routed / watch / not-OT-owned)
  3. Reference the cluster's outstanding action item + owner if any
  4. Don't re-derive root cause from first principles — the cluster doc
     contains the canonical analysis; verify it still applies, then move on
  5. Cross-reference auto-learnings/inventory/heatmap.md to see if this slice
     (PG / product / role × pattern) is hot. If so, mention in verdict.

If NO matching cluster exists:
  1. Note explicitly: "no matching CL-NNN cluster in failure-patterns.md"
  2. Add a candidate cluster entry to auto-fixes/YYYY-MM-DD/<slug>.md
     for human review
  3. Be more conservative on confidence (medium at best for unmatched)
  4. Search auto-learnings/summaries/ once more — the analysis may exist as
     a mega-learning that hasn't graduated to a cluster yet

THIS STEP IS NOT OPTIONAL. Skipping it means re-deriving knowledge that
already exists in the registry — the primary cause of narrow-lens triage
errors observed across 2026-05-19/20 session.
```

## Why this fix

The bot has had access to `auto-learnings/failure-patterns.md` all along but consulted it inconsistently. Today's session showed the cost: 5+ misses on first triage, each of which had a matching entry already in the registry. A single Step-0 amendment closes the entire class.

## Validation

- [ ] After landing, audit 20 consecutive cron triages; 100% should reference at least one CL-NNN or S-NNN classification (or note explicit no-match)
- [ ] Re-run today's missed triages through the amended prompt; verify each correctly identifies its CL-NNN cluster
- [ ] ot-triage-auditor R-XR4 (carryover-miss) findings should drop by ≥50% in 7d window after landing

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F registry-first triage discipline
- `04-fs-cadence-check.md` (specific symptom-check fix)
- `05-model-id-verification.md` (companion verification fix)
- `auto-learnings/patterns/README.md` (the knowledge graph this fix consults)
