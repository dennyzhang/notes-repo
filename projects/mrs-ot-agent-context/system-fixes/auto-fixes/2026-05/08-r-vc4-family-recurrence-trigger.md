```yaml
fix_id: r-vc4-family-recurrence-trigger
title: Cron R-VC4 trigger — family-recurrence ratchet from per-incident to family-SEV proposal
status: 🟡 drafted
identified: 2026-05-20 multiple threads (cfr family NaN + IG retrieval holdout)
target: team_bot/cron-jobs/ot-alert-monitor.md, ot-sev-monitor.md
section: Triage verdict — recurrence escalation
impact: Closes the "5 alerts/family/24h still get individual MONITOR verdicts" gap
cost: ~15-line cron prompt amendment
```

## Gap

Auditor flagged R-VC4 (family-SEV gap) 6+ times today as carryover. The cron keeps issuing per-incident MONITOR verdicts on alerts that share a family (PG + product + symptom). Examples observed today:

- **CFR NaN family** — m878858380 + m2134801434 — ≥10 alerts/24h on CL-017 Shampoo NaN; bot issued individual MONITOR verdicts, never proposed family-level threshold suppression
- **IG retrieval holdout E2E latency family** — m878102693 + m2145491885 + m2132766001 + m2144816217 + m2145336177 — 5 alerts/<24h on CL-013; bot issued individual MONITOR verdicts, never proposed family escalation to Peiyang Yu

## Patch

### Before

(No explicit recurrence trigger in cron prompt)

```
For each alert/SEV: triage individually, emit verdict
```

### After

```
R-VC4 FAMILY-RECURRENCE TRIGGER (apply BEFORE emitting individual verdict):

  After identifying the alert's S-NNN cluster (per registry-first-triage),
  check the FAMILY-RECURRENCE RATIO:

  1. Define FAMILY scope for this alert:
     - Same PG (from inventory/models.md row)
     - Same product OR same role (e.g., all IG/Reels holdouts, or all
       CFR baselines)
     - Same S-NNN classification (e.g., S-001 example_age spike)

  2. Count recent alerts/SEVs in this family scope:
     - Last 24h: check active alert list + recent archives for matches
     - Cross-reference with auto-learnings/inventory/heatmap.md hot cells

  3. APPLY THE RATCHET:

     Threshold A: ≥3 alerts/24h in same family scope, same S-NNN
     → Verdict upgrades from per-incident MONITOR to:
       "Family-recurrence trigger fires (R-VC4): N alerts in family X
        within 24h. Escalate to <P-NNN owner> for family-level mitigation,
        not yet-another-individual MONITOR."

     Threshold B: ≥5 alerts/24h cross-submodel-family (e.g., ig_reels_*
                   holdouts across multiple submodel families)
     → Verdict upgrades to: "Cross-family pattern signal. Escalate to
        cluster-level owner (P-η defense theme; Peiyang Yu for IG holdout
        E2E latency thresholds, etc.)"

     Threshold C: ≥10 alerts/24h same model_id, same detector
     → STUS-style L20 ratchet: "Nth fire on detector_id <id> without
        owner ack. Recommend suppress/retune at detector source."

  4. CITE the recurrence count + scope in the verdict so auditor can
     verify the trigger fired correctly:
     ```
     R-VC4: 5 IG retrieval-family holdout E2E latency alerts in 24h
     (m878102693, m2145491885, m2132766001, m2144816217, m2145336177).
     Escalating to Peiyang Yu — IG holdout threshold tuning is operationally
     overdue. Single-incident MONITOR no longer adequate.
     ```

  5. NEVER skip this check on a per-incident triage. The per-incident
     verdict is correct but INCOMPLETE without the family-recurrence flag.
```

## Triggering evidence

- ot-triage-auditor R-VC4 carryover findings 6+ times 2026-05-19/20
- Multiple threads (g4Jv-ZvxpB4, vNV0NL_aKS0, lbzl2JEM0jc, MQwOLaC3jLc) where bot caught the family signal AFTER cron emitted per-incident verdict — should be caught BEFORE

## Validation

- [ ] After landing: monitor auditor R-VC4 finding rate; should drop to <2/week
- [ ] Track family-escalation recommendations actually being acted on by operators (vs ignored as noise)
- [ ] Verify heatmap.md hot-cell list aligns with R-VC4 triggers (positive correlation)

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F L20-style ratchet
- `auto-learnings/inventory/heatmap.md` (hot-cell visibility)
- `auto-learnings/patterns/patterns-beyond.md` P-η pattern (today's IG retrieval holdout signal)
