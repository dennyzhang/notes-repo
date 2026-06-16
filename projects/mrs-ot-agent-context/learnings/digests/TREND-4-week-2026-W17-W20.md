# OT Mega-Learnings — 4-Week Trend View (2026-W17 → W20)

_Backfilled 2026-05-16. Synthesizes cross-week patterns across W17 (Apr 20), W18 (Apr 27), W19 (May 4), W20 (May 11). Future months: regenerate at month-end._

## Volume

| Week | SEV count (mvai-online-training tag) | Notes |
|---|---|---|
| W17 (Apr 20–26) | 6 | Migration-heavy, low activity |
| W18 (Apr 27–May 3) | 27 | First full week of pre-archive data |
| W19 (May 4–10) | 39 | **Highest** — driven by S660017 ZippyDB SEV1 cascade |
| W20 (May 11–17) | ~30 (in-progress) | Tonight is Day 6 of W20 |
| **4-week mean** | ~25 SEVs/week | Roughly 4 per day, dominated by 5-8 recurring clusters |

## Recurring cluster trends

### Cluster F: Conveyor / cogwheel publish failures (DOMINANT, CHRONIC)

| Week | Count | Sub-classes observed |
|---|---|---|
| W18 | 8 | CUDA OOM, stale MaaS FQN, FBLearner OOM, NaN/Inf, Set-mutation-during-iteration, multi-model publish |
| W19 | 11 | CUDA, preproc imports, jagged_unique_indices regression, NE thresholds, calibration thresholds, fbpkg drift, lowering pkg |
| W20 (so far) | 5 | TorchScript P52, transitive C++ dep break, TGIF timeout, header/ABI compile, Sandcastle infra OOM+preemption |
| **4-week total** | **24+** | **Highest-density chronic issue surface in OT** |

**This is the single biggest pattern across the month.** No other cluster touches this volume or persistence. Justifies dedicated investment beyond R-rule additions — likely a project / task / SLO commitment with mvai-reliability.

### Cluster P50: Upstream-infra cascade into OT (RECURRENT)

| Week | Trigger | OT impact |
|---|---|---|
| W19 | S660017 ZippyDB SEV1 | 4 cascaded SEVs over 19+ hours |
| W20 (tonight) | S665114 ZippyDB Flash ATG0 | model 2130305043 SPARSE_DELTA blackout |
| W18 (earlier in arc) | S660220 ZippyDB SEV1 (May 6) | 3 STUS models 0 QPS for ~7h |
| **3-week count** | **3 distinct ZippyDB events affecting OT** | Avg ~1/week |

**Frequency justifies the i-0a mandatory check in `ot-alert-monitor` and `ot-sev-monitor`.** Pre-rule (W18) operators wasted hours; post-rule (W19→W20) cron correctly routes to ZippyDB oncall within 8 min (tonight's S665114 triage example).

### Snapshot-stuck-CREATING is heterogeneous (CONFIRMED ACROSS WEEKS)

| Week | Distinct roots producing snapshot-stuck |
|---|---|
| W18 | TCPStore binding bug, QE entitlement, MaaS config drift, scheduler pending, capacity (N=5) |
| W19 | ZippyDB cascade, expired job, MaaS FQN, AMD hardware rejection, capacity (N=5) |
| W20 | NCCL/TMS no-restart, stale base layer, DPP `_preload_item_pool` blocking (N=3 documented) |

**13+ distinct roots across 4 weeks all produce the same D7 symptom.** R17 trainer-liveness probe (added 2026-05-13) was the correct response.

### STUS vs trainer confusion (R14 evidence base)

W19 had ≥5 STUS-vs-trainer mistake costs documented retrospectively. R14 was added 2026-05-08 (mid-W19) after operator-flagged repeated mistakes. **W20 has zero R14-class triage errors observed in current cron output.** Rule is effective.

### IG Vital / cross-org leaks (R18 evidence base)

| Week | Leak count (out-of-scope OT-tagged) |
|---|---|
| W18 | 2 (Everstore L2, Unidash L2) |
| W19 | 3 (IG Vital ×2, IG Direct DE ×1) |
| W20 | 0 (R18 routing) |

**R18 (added 2026-05-13) cut cross-tier noise to zero in W20.** Empirically validated.

### Migration churn (BASELINE NOISE)

| Week | Migration-related SEVs | % of week |
|---|---|---|
| W17 | 4 | 67% |
| W18 | 3 | 11% |
| W19 | 3 | 8% |
| W20 | 1-2 (so far) | ~5% |
| **Baseline** | **~3-4/week** | Stable; should be subtracted from health-metric denominators |

## What the 4-week view tells us

1. **The bot's rule additions are working.** R14, R18, P50, R17 each show clean before/after data in the backfill — operational quality improving.
2. **Conveyor failures are the #1 unsolved problem.** 24+ SEVs in 4 weeks, no decline. R-rules alone can't fix this; needs project-level investment.
3. **Per-week mega-learnings miss long-arc patterns.** This trend file should be generated monthly by `ot-knowledge-curation` (currently only does single-week + monthly-systemic-gap). Worth adding a `--lookback-weeks=4` mode.
4. **Migration churn should be reported separately from operational SEVs** in any health metric. Conflating them masks real signal.

## Proposed actions

- **P1 / project** — File task on mvai-reliability for "OT release-pipeline reliability project" citing 24+ conveyor SEVs in 4 weeks
- **P2 / cron enhancement** — Extend `ot-knowledge-curation` to emit monthly trend file like this one
- **P3 / metric** — Add "non-migration SEV count" as the primary OT health indicator (currently dominated by migration noise)

## How this file gets maintained

- **Manually backfilled 2026-05-16** for W17–W20 (operator-requested historical context).
- **Future updates:** end of each month, regenerate based on 4 most recent weekly files. Cron candidate.
- **Don't auto-update piecemeal** — the value is in the cross-week synthesis, which is point-in-time.
