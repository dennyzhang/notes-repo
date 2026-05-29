# Missing Metric Auto-Discovery

```yaml
fix_id: missing-metric-auto-discovery
title: Add metric gap detection to fleet health scanner and triage workflow
status: 🟡 drafted
identified: 2026-05-26 session (facebook_reels_ifu_i2i investigation + D106193941 review)
target: team_bot/cron-jobs/ot-fleet-health.md + triage workflow
section: metric coverage audit
impact: Detect silent failures and resource waste BEFORE they become SEVs
cost: 2-3 days (fleet health cron amendment + triage prompt update)
```

## Gap

The agent has metrics, thresholds, and detection patterns codified in `metrics/`, but **no mechanism to proactively detect when a metric is MISSING for a model**. Current gaps discovered this session:

| Gap | How discovered | Impact |
|---|---|---|
| Zombie job (QPS=0 for 6 days) | Manual investigation of reranker 2125081901 | 1,152 GPU-hr wasted |
| TMS/MAST desync crash-loop | D106193941 review, model 2128686073 | 21 crash-loops, GPU waste |
| Full snapshot stalled but stream publishes masking it | Manual investigation of I2I model 2132070936 | 8+ hours stale full snapshot |
| Root model crash-looping blocking downstream | Manual tracing of dependency chain | Entire I2I pipeline stalled |
| dai_modelstore schema gap for retrieval models | Wrong query returned "0 publishes" (false) | Misleading triage |

All of these were **discoverable programmatically** — the data existed, but nobody (human or bot) was running the checks.

## Triggering evidence

- 2026-05-23 triage session: reranker zombie, root model crash-loop, I2I snapshot blocked
- D106193941: TMS/MAST desync from swallowed UNAUTHORIZED
- Existing fleet health cron only checks model count and package expiration, not metric health

## Proposed additions

### 1. Fleet health cron: add metric coverage audit

The fleet health scanner should, for each OT model:

```
For each active OT model (TMS ONLINE_READY):
  1. KM-T2 check: Is training QPS > 0? (catches DP-001 zombie)
     - If QPS = 0 for >1h → flag ZOMBIE
  2. KM-SYNC1 check: Does MAST state match TMS state? (catches DP-006 desync)
     - If MAST RUNNING + TMS not ONLINE_READY → flag ORPHAN
  3. KM-P4 check: Is publisher active? (catches DP-007 silent publisher death)
     - If isActive=false for >30 min → flag SILENT_PUBLISHER_DEATH
  4. KM-T3 check: Is job crash-looping? (catches DP-006, DP-013)
     - If ≥3 DEAD attempts <10 min in last 2h → flag CRASH_LOOP
  5. KM-CK1 check: Is checkpoint cadence within SLO? (catches DP-004)
     - If no checkpoint for >2x expected interval → flag CHECKPOINT_STALL
```

### 2. Triage prompt: add metric gap detection

When the triage bot processes an incident, after reaching a verdict, run this self-check:

```
Post-triage metric gap check:
  1. Could this incident have been caught earlier by an existing DP-NNN pattern?
     - If yes: was the pattern actually being monitored? If not → propose adding it to fleet health cron
  2. Did triage require a metric/query that wasn't in the metrics/ folder?
     - If yes: propose new KM-XX + Q-NNN as auto-fix
  3. Did an existing query return wrong/misleading data?
     - If yes: update Q-NNN with corrected approach + gotchas
  4. Was the root cause in an upstream dependency?
     - If yes: check if DP-009 through DP-013 cover it. If not → propose new DP-NNN
```

### 3. Weekly metric coverage report

Add a weekly check (can be part of shift summary or separate cron):

```
Metric coverage audit:
  - Total active OT models: N
  - Models with training QPS data in last 1h: N (gap = zombie candidates)
  - Models with checkpoint in last 2x expected interval: N (gap = checkpoint stall candidates)
  - Models with MAST/TMS state match: N (gap = orphan candidates)
  - Models with publisher active: N (gap = silent death candidates)
  - Detection patterns with zero hits in 7 days: list (may be misconfigured)
  - Detection patterns with >10 hits in 7 days: list (may need threshold tuning)
```

## Why this fix

Today the metrics folder is a **reference** — the bot reads it during triage. But the discovery loop is missing: nothing proactively scans for "which models are missing which health signals." This turns the reference into an active scanner.

The three additions form a closed loop:
- Fleet health cron (proactive detection) catches problems before they escalate
- Triage self-check (reactive learning) discovers new patterns from incidents
- Weekly audit (coverage validation) ensures no blind spots accumulate

## Validation

- [ ] Fleet health cron runs DP-001 check (zombie) → confirms reranker 2125081901 would have been caught
- [ ] Fleet health cron runs DP-006 check (desync) → confirms model 2128686073 would have been caught
- [ ] Triage self-check proposes new metric when encountering a novel failure mode
- [ ] Weekly report correctly identifies models with missing health signals

## Related

- `metrics/detection-patterns.md` — the patterns this fix operationalizes
- `metrics/slo-recovery-metrics.md` — the metrics being checked
- `metrics/queries.md` — the queries used to check them
- `solution-design.md` H7 (disk capacity) — similar pattern of proactive cron-based detection
- `solution-design.md` H8 (CL-009 silent-stop detector) — specific instance of this general capability
