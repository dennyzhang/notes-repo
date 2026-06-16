# PG × Pattern Accumulation Heatmap

_Cross-cut of inventory (`workloads.md`) × patterns (`../patterns/`). Cell = count of recent incidents in that PG/product slice mapping to that pattern. Updated daily by `INDEX.md`._

**Read direction:** identify accumulation in a cell (high count = pattern-spike in that PG slice). Take action when a P-NNN class is concentrating in a specific PG/product — it's a structural ask, not a per-incident triage.

## Last 24h (2026-05-19 → 2026-05-20 17:00 PT) — initial seed

### S-NNN × PG/product

| Symptom | IG/Feed | IG/Reels | IG/Stories | IG/Mixed | IG/Explore | Threads/Retr. | Threads/Feed | Facebook/CFR | Facebook/Video | Facebook/IFR | Production/Time-spent | infra-cross-pg |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| S-001 example_age spike | 1 | 4 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| S-002 FS missing | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 1 | 0 | 1 | 1 |
| S-003 QPS=0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| S-005 StuckJobException | 0 | 0 | 0 | 0 | 0 | 3 | 1 | 0 | 0 | 0 | 0 | 0 |
| S-007 detector noise | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 5+ | 1 | 0 | 0 | 0 |
| S-008 serving error rate | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 0 | 0 |
| S-009 cogwheel/conveyor | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 4 |

**Hot cells:**
- **IG/Reels × S-001 = 4** ← today's holdout E2E latency cluster spike (4 of 5 models in this row + 1 in IG/Mixed)
- **Facebook/CFR × S-007 = 5+** ← stale NaN detector noise on m878858380 + m2134801434
- **Threads/Retrieval × S-005 = 3** ← S665454 cluster (3 affected jobs)
- **infra-cross-pg × S-009 = 4** ← S666322 + S666413 + S666451 + S665902 cogwheel/conveyor cluster

### M-NNN × PG/product

| Mechanism | IG/Feed | IG/Reels | IG/Stories | IG/Mixed | Threads/Retr. | Threads/Feed | Facebook/CFR | Facebook/Video | infra-cross-pg |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| M-001 elastic agent zombie | 0 | 0 | 1 | 0 | 3 | 1 | 0 | 0 | 0 |
| M-002 DPP starvation | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| M-003 NaN cascade | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| M-004 auto-start silent stall | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |
| M-005 ALLREDUCE rank desync | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| M-007 downstream-infra cascade | 1 | 4 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| M-009 cogwheel publish failures | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 4 |
| M-011 holdout periodic stall | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| M-012 conveyor regression | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 |
| M-013 STUS kmeans underflow | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| M-015 bloom_index overflow | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |
| M-016 detector misconfig | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| M-017 detector no-auto-clear | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |

**Hot cells:**
- **IG/Reels × M-007 = 4** ← scribe lag cascade across multiple holdouts
- **Threads/Retrieval × M-001 = 3** ← elastic agent zombie hitting 3 sibling models
- **infra-cross-pg × M-009 = 4** ← cogwheel publish failure class concentration

### P-NNN × PG/product (the structural-ask layer)

| Systemic cause | IG/Feed | IG/Reels | IG/Stories | IG/Mixed | Threads/Retr. | Threads/Feed | Facebook/CFR | Facebook/Video | infra-cross-pg |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| P-001 main-thread-blocked | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| P-002 worker-died-launcher-stuck | 0 | 0 | 1 | 0 | 3 | 1 | 0 | 0 | 0 |
| P-003 static-config-vs-growth | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 |
| P-004 reland-without-guardrail | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| P-005 detector-role-mismatch | 1 | 1 | 0 | 0 | 0 | 0 | 2 | 1 | 0 |
| P-006 silent-orchestration-event | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |
| **P-007 periodic-sync-op-vs-training** | **0** | **4** | **0** | **1** | **0** | **0** | **0** | **0** | **0** |

**The single hottest structural cell today**: **P-007 × IG/Reels = 4 (+ 1 in IG/Mixed = 5 family-wide)** — this is today's IG retrieval-family holdout E2E latency cluster expressed as a systemic cause accumulation. **Mitigation theme D-001 (external liveness probe / progress-based watchdog) would close the entire P-007 class** — and crucially, this is visible at a glance HERE that wasn't visible across 5 per-incident triages.

**Second hottest**: **P-002 × Threads/Retrieval = 3** — elastic-agent zombie class concentrated on Threads Retrieval U2M family. Defense D-001/D-002/D-003 architectural mitigation needed.

## Rolling-window deltas (when daily cron lands)

Schema (placeholder until first cron run):

```
| Cell | 24h | 7d | 30d | 7d slope | 30d trend |
|---|---:|---:|---:|---:|:---:|
| IG/Reels × P-007 | 4 | 4 | ? | new | ⬆️ NEW |
| Threads/Retrieval × P-002 | 3 | 6 | 8+ | flat | ⬆️ chronic |
| Facebook/CFR × M-003 | 2 | 5+ | 13+ | flat | ⬆️ chronic accelerating |
| infra-cross-pg × M-009 | 4 | 8 | 26+ | flat | ⬆️ chronic |
```

A slope flag of `⬆️ NEW` or `⬆️ accelerating` should trigger an explicit operator escalation in the daily brief.

## How to read this for action

1. **Hot S/M cell** = a wave of incidents on a specific symptom/mechanism in a specific PG slice. Action: investigate whether something common changed in that slice (deploy, infra event, model launch).
2. **Hot P cell** = the systemic cause is concentrating. Action: review the P-NNN entry in `../patterns/systemic-causes.md` for mitigation theme; surface as leadership-ask.
3. **NEW slope** = pattern just emerged. Surface explicitly even at low count — may be a precursor wave.
4. **Accelerating slope on chronic pattern** = existing defense isn't keeping up. Time to escalate or reprioritize.

## Maintenance

- Manual snapshot from 2026-05-20. Refresh during weekly review from resolved-* archives + noisy-trends.md + active-SEV list.
- Counts are over rolling windows (24h, 7d, 30d). Older windows show slope.
- Empty cells should NOT be deleted; preserve the matrix structure for stable visual layout.
- Hot-cell threshold: ≥3 in 24h, ≥5 in 7d, ≥10 in 30d (these are the auto-flag triggers).
