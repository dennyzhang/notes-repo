# 2026-06-02 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 9 new human messages spanning 2026-06-01T11:06 → 2026-06-01T14:06 PT in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Dave Kotfis × 4, Josef Cohen × 3, Pushpak Raj Gautam × 2)._

_Window: 7d default (delta since last_msg_create_time 2026-06-01T06:27 PT). Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

None this week. No owner/dashboard changes that contradict existing bot state.

## P1 — significant nuance / sub-mechanisms

**Item snapshot vs. scribe latency — distinct regression tracks**

The ongoing scribe latency regression (P90 ~1 min over SLO) resolved for the scribe/recopublisher path by June 1 ("trending downward", Dave Kotfis 11:25). But the **item snapshot** remains regressed — Josef Cohen (jcohen1) confirmed at 11:15 with screenshot. Dave Kotfis acknowledged the distinction at 11:24 ("forgot it was item").

Bot implication: when diagnosing scribe-age regressions, triage must distinguish:
- `scribe/recopublisher` latency (self-healing d/d this week)
- `item snapshot` latency (still elevated as of 2026-06-01)

These are separate monitoring surfaces; a healthy scribe dashboard does not clear the item snapshot regression.

**DFM expansion proposal: read/write isolation for recopublisher scribe**

Josef Cohen (jcohen1, 11:28) proposed using the ongoing item snapshot regression as a forcing function to expand DFM data to include **recopublisher scribe categories with read time and write time isolated**. This would allow triage to distinguish whether a latency spike is a read-side or write-side failure.

Status: proposal only, not yet landed. If this lands, the bot's canonical DFM source gains a new column split.

**xdb.dai_model_platform_prod overload as blast-radius failure mode**

Paul Lu (lupaul, 12:50) flagged S670401 — "VSP Traffic Spike to AMS causes `xdb.dai_model_platform_prod` overload" — noting training jobs failing with `TApplicationException: facebook::nodeapi::NodeSqlSystemException`. Pushpak Raj Gautam (prgzz, 14:06) added that detector [1441772260965558](https://www.internalfb.com/monitoring/detector/1441772260965558) and S670393 co-fired.

Bot implication: `TApplicationException: NodeSqlSystemException` on training jobs can trace to `xdb.dai_model_platform_prod` saturation from unrelated VSP/AMS traffic spikes — not a model-specific or OT-specific root cause. This is a new blast-radius pattern to add to the triage decision tree.

## P2 — references / good-to-know

- Detector [1441772260965558](https://www.internalfb.com/monitoring/detector/1441772260965558) — fires on xdb.dai_model_platform_prod saturation events. S670393 and S670401 both fired on 2026-06-01.
- "Typical June for IG head models" — Pushpak Raj Gautam (11:06) context note. IG OT high-SEV season expected through June.

## Cross-references

None this week.

## Open coordination threads

- **Item snapshot latency still elevated** — Dave Kotfis and Josef Cohen monitoring. No resolution as of end of 2026-06-01. Bot should check if this is still open next week.
- **DFM read/write expansion** — Josef Cohen's proposal. No decision captured. If it lands, the bot needs to know the new DFM column names.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P1 | Distinguish item-snapshot vs. scribe/recopublisher in scribe-age triage | Add to `known_patterns.md` — new failure-class split under scribe-latency cluster | 30 min |
| P1 | `TApplicationException: NodeSqlSystemException` → check `xdb.dai_model_platform_prod` saturation | Add to failure-patterns.md under blast-radius class; cite detector 1441772260965558 | 20 min |
| P2 | DFM read/write isolation columns (if landed) | Update canonical-dashboards section of `ot-sev-monitor` cron when confirmed | 10 min when ready |
