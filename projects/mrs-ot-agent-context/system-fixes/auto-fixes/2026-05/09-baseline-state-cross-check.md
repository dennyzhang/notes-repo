```yaml
fix_id: baseline-state-cross-check
title: Holdout-noise heuristic requires baseline state verification first
status: 🟡 drafted
identified: 2026-05-20 thread g4Jv-ZvxpB4
target: team_bot/cron-jobs/ot-alert-monitor.md
section: Triage discipline — holdout E2E latency alerts
impact: Closes blind application of "36% noisy" heuristic when baseline also affected
cost: ~10-line cron prompt amendment
```

## Gap

Team_context heuristic: "Holdout model E2E latency alerts: 36% are chronically noisy (threshold tuning in flight). Classify as THRESHOLD_MISFIT, not PAGE, until tuning lands." Bot applied this WITHOUT verifying baseline state. The heuristic is only valid when baseline is clean — if baseline is ALSO firing, the signal is shared-infra, not holdout-noise.

## Patch

```
HOLDOUT-NOISE HEURISTIC APPLICATION:

  Before applying R23 / "36% holdout noisy" classification to a holdout's
  E2E latency alert:

  1. Identify the corresponding BASELINE model (from inventory/models.md
     or from SEV's mentioned siblings)

  2. Query the baseline's active alerts:
     meta monitoring.alert list --oncall <oncall> \
       --alert-contains "<baseline-model-type>" --state-is ACTIVE

  3. If baseline is ALSO firing the same detector type → NOT holdout-noise.
     This is a shared-infra problem (CL-003 cascade or M-007 mechanism).
     Don't classify as THRESHOLD_MISFIT.

  4. If baseline is CLEAN AND holdout is firing → holdout-noise candidate
     is valid. Apply THRESHOLD_MISFIT per team_context heuristic.

  5. CITE the baseline state in the verdict:
     "Baseline m<id> alert state: <clean | also-firing>. Holdout-noise
      heuristic <applied | rejected>."

EXTENSION: also apply the periodic-pattern check (see 13-snapshot-cadence-
not-training-progress.md). Holdout E2E latency that's PERIODIC and matches
training-stall periodicity → real M-011 (not threshold misfit), regardless
of baseline state.
```

## Triggering evidence

- 2026-05-20 thread g4Jv-ZvxpB4 — m878102693 holdout fired; baseline 2134319967 also had identical alert (cron caught this; bot's earlier triage missed it)

## Validation

- [ ] All holdout E2E latency triages must cite baseline state
- [ ] Audit 7d window; verify 0 cases of "holdout-noise applied without baseline check"

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F evidence checklist
- `13-snapshot-cadence-not-training-progress.md`
