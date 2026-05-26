```yaml
fix_id: fs-cadence-check-not-zero-in-last-n
title: STUS-confirmation must use gap-vs-cadence ratio, NOT "0 FS in last N"
status: 🟡 drafted
identified: 2026-05-20 thread m_fDUO0qxy0
target: team_bot/cron-jobs/ot-alert-monitor.md (FS-missing alert handling)
section: Triage discipline / STUS-role classification
impact: Closes the single most damaging missed-PAGE class observed today
cost: ~15-line cron prompt amendment
```

## Gap

When triaging FS-missing alerts, the bot's STUS-role classification used:

```
"Last 30 instances show 0 FULL_SNAPSHOT → STUS-role confirmed → THRESHOLD_MISFIT"
```

This is a HALF-check. The right check is "does this model normally publish FS, and if so, when was the last one?" — comparing gap-since-last-FS to the model's historical FS cadence.

Today's m2130324780 case at 05:51 PDT: cron said "0 FS in last 30 instances → STUS confirmed → NO ACTION". Reality: model has historical FS cadence ~80 min; last FS was 19.5h ago (15× cadence). This was a real publish-path failure (kmeans corpus collapse from 22K to 1,315 entries — STUS R-031 / M-013) requiring PAGE.

## Triggering evidence

- 2026-05-20 05:51 PDT thread m_fDUO0qxy0 — cron PAGE'd correctly; bot's prior "NO ACTION" verdict was wrong
- ot-thread-summarizer si7PIRLI6Gc earlier today flagged this EXACT failure mode: "STUS FULL_SNAPSHOT misclassified as THRESHOLD_MISFIT (kmeans assertion missed)" — bug pattern is named

## Patch

### Before

```
STUS-role classification (R14):
  If `meta ai.model.instance list -l 30` shows 0 FULL_SNAPSHOT entries
  → role: STUS, classify as THRESHOLD_MISFIT (R23) for FS-missing alerts
```

### After

```
STUS-role classification (R14) — gap-vs-cadence ratio is dispositive,
not "0 in last N":

  Step 1: Pull AT LEAST 100 most-recent instances (not 30; small N
          masks cases where the model historically publishes FS at
          long cadence but isn't STUS).

  Step 2: Identify the most recent FULL_SNAPSHOT in the list.
          - If FOUND: compute gap_since_last_FS = now - last_FS_time
          - If NOT FOUND in 100: model is plausibly STUS, but still
            check existence in 500 instances or all-time

  Step 3: Compute the model's HISTORICAL FS CADENCE:
          - Take the most recent ~10 FULL_SNAPSHOT entries (going
            back further if needed)
          - Compute median time-between-consecutive-FS as `cadence`

  Step 4: STUS-CONFIRMATION requires EITHER:
          (a) Zero FS in 500+ instance history → true STUS, no FS ever, OR
          (b) gap_since_last_FS <= 2 × cadence → within normal STUS range

          If gap_since_last_FS > 2 × cadence:
          → NOT THRESHOLD_MISFIT — this is a REAL FAILURE.
          → Classify as REAL_OT_FAILURE_RECURRING.
          → Pull MAST attempts: meta ai.mast-job attempts --name=mvai-training-online-<id>
          → Pull MAST error: meta ai.mast-job error --version=<latest>
          → Check for AssertionError + 'kmeans' (M-013 / R-031)
          → Check for SEVs touching this model in title-contains
          → PAGE model owner with the specific Layer-1 trigger identified

  Step 5: ONLY after Steps 2-4 confirm STUS-with-normal-cadence,
          apply R23 THRESHOLD_MISFIT classification.

DECISION TABLE:

  History 0 FS, 500+ instances        → True STUS, R23 THRESHOLD_MISFIT
  History has FS, gap ≤ 2× cadence    → STUS-normal, R23 THRESHOLD_MISFIT
                                         (apply L20 if 2nd+ fire)
  History has FS, gap > 2× cadence    → REAL FAILURE, PAGE model owner
                                         + identify Layer-1 trigger via M
                                         (NaN cascade, kmeans, conveyor, etc.)
```

## Why this fix

"0 FS in last N" is a NECESSARY but NOT SUFFICIENT condition for STUS classification. Models with ~80-minute FS cadence can have 0 FS in last 30 instances (last 30 = last ~90 minutes of fast publishing). The gap-vs-cadence ratio is the dispositive signal. This is exactly the failure mode auditor named earlier today (si7PIRLI6Gc); making the check explicit in the cron prompt closes the gap.

## Validation

- [ ] Re-run m2130324780 triage through amended prompt; verify outputs PAGE not NO_ACTION
- [ ] Apply to 5 historical STUS cases from resolved-* archives; verify correct STUS-vs-real-failure classification
- [ ] Track auditor R-EV-FS-cadence finding rate before and after landing; should drop to 0

## Related

- `auto-learnings/patterns/symptoms.md` S-002 falsifier (already updated)
- `auto-learnings/patterns/mechanisms.md` M-013 STUS kmeans corpus underflow + M-014 STUS-normal-cadence misclassification
- `IMPROVEMENT-PROPOSALS.md` Proposal F evidence-completeness checklist
- `03-registry-first-triage.md` (registry consult comes first)
