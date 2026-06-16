```yaml
fix_id: snapshot-cadence-not-training-progress
title: Snapshot-publishing cadence is NOT a liveness signal for training progress
status: 🟡 drafted
identified: 2026-05-20 thread MQwOLaC3jLc (m2145336177 25min/hr stall)
target: team_bot/cron-jobs/ot-alert-monitor.md
section: Triage discipline — trainer-health assessment
impact: Catches periodic training stalls that masquerade as healthy
cost: ~15-line cron prompt amendment
```

## Gap

For m2145336177, bot saw snapshot publishing every 3 min through alert window → inferred "trainer healthy → TRANSIENT_NOISE / THRESHOLD_MISFIT". Reality: GPU SM utilization p50 = 0.92% (vs fleet 36.52% — 30× below), p25 GPU device util = 0%, training QPS dropped to 0 for ~25 min/hr. Snapshot output ≠ training progress for STUS-role models; the model can publish snapshots while doing essentially zero compute.

## Patch

```
TRAINER-HEALTH ASSESSMENT — DO NOT RELY ON SNAPSHOT CADENCE ALONE:

  When triaging any alert that implies trainer might be unhealthy
  (example_age spike, QPS=0, FS missing, e2e latency, etc.):

  Snapshot publish cadence (`meta ai.model.instance list`) is a
  PUBLISH-PATH liveness signal, NOT a training-compute liveness signal.
  A model can publish snapshots on clockwork cadence while training
  compute is idle.

  REQUIRED CHECKS FOR TRAINER-HEALTH:

  1. mvai_metrics freshness (training Python alive):
     meta scuba ... | tail -1  → check latest_sample timestamp
     If latest_sample >5min old while job status=RUNNING → SUSPICIOUS

  2. GPU system metrics over last 6h:
     meta ai.mast-job system-metrics --name=<job> --version=<v>
     Read SM Utilization avg, p50, p25 + Tensorcore p50.
     If SM Util avg < 10% of fleet avg OR p25 GPU device util = 0%
     OR Tensorcore p50 = 0% → training compute is idle most of the time

  3. DPP Data Starvation %:
     If high (>10%) → DPP-bound (M-002)
     If low (<3%) but SM util also low → NOT DPP, something else is
     stalling training (periodic sync barrier, eval pass, etc.) — M-011 candidate

  4. MAST attempts history:
     meta ai.mast-job attempts --name=<job>
     If recent attempt restarted but old attempt's failure is in error
     log → trainer-side bug; verify recovery is stable

  CLASSIFICATION DECISION:

     Healthy snapshots + healthy GPU util (>30%)         → trainer healthy
     Healthy snapshots + low GPU util (p50 < 5%)         → M-011 periodic stall
                                                             (snapshot output ≠ training)
     Snapshot gap + low GPU util                          → real trainer failure
                                                             (any of M-001, M-002, M-003)
     Snapshot gap + healthy GPU util                      → publish-path break,
                                                             trainer fine
                                                             (M-012, R-005, etc.)
```

## Triggering evidence

- 2026-05-20 thread MQwOLaC3jLc — m2145336177 SM util p50=0.92% vs fleet 36.52%; training stalled 25min/hr while snapshots clockwork

## Validation

- [ ] Holdout E2E latency triages: verdict cites SM util check, not just snapshot cadence
- [ ] Periodic-stall cases (M-011) → classified correctly, not "transient noise"
- [ ] Reverse: 0 cases of "trainer healthy" verdict based ONLY on snapshot cadence going forward

## Related

- `auto-learnings/patterns/mechanisms.md` M-011 holdout periodic data-cycle stall
- `auto-learnings/patterns/patterns-beyond.md` P-η periodic sync-op vs training
- `IMPROVEMENT-PROPOSALS.md` Proposal F evidence checklist
