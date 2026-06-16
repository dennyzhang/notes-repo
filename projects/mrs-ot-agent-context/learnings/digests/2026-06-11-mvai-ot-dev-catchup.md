# 2026-06-11 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 32 human messages spanning 2026-06-04T11:47:34-07:00 → 2026-06-11T15:16:26-07:00 in **MVAI OT Dev** (8 members; primary contributors: Denny Zhang (17), Paul Lu (5), Li Lu (5))._

_Window: 7d delta (last_msg was 2026-06-04 though catchup_date was 2026-06-08 — pulled full delta since last_msg). Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

**D108045383 landed: diff→app-layer/base-layer classification now in agent.**
Canonical rule: check app-layer overlay paths listed at https://fburl.com/thrift_fiddle/ca6m6uo2. If diff is under those directories → patch app-layer. Otherwise → patch base-layer. Only patch both if diff spans overlay directories AND outside them. Accepted by Li Lu 6/9. Bot's diff→layer classifier uses this as ground truth.

**D108195174: DPP-starvation confirm/refute + preemption discriminators — RADAR verified.**
Today's SEV1 exposed that OT agent failed to detect DPP starvation. This diff closes the gap with: (a) confirm/refute logic for DPP starvation, (b) preemption discriminators to distinguish DPP vs non-DPP origin. RADAR verified. Bot should integrate once this diff lands. Scribe drain as sub-cause of DPP starvation is explicitly out of scope (bot defers to DPP team for what introduced the drain).

**T275298327 filed: TTFB (time-to-first-batch) slow-start monitoring.**
Alert proposal: fire warning alert if TTFB > 1h for any committed prod model. Paul Lu confirmed events logging is now available for time-to-first-batch (per-event log, not yet per-model metric). Li proposed querying fleetwise TTFB range first to calibrate threshold before setting the alert. PG aggregation-level view also discussed (alert if all models in a PG have TTFB > 1h). Assigned to Arbaz Khan as ramp-up task.

## P1 — significant nuance / sub-mechanisms

**D108074069 landed: deep-dive investigation format for log-heavy OT investigations.**
New report format for OT agent in log-heavy / deep-dive scenarios. Accepted by Denny Zhang 6/9. Agent should use this format when investigation involves log parsing (NCCL traces, SJD dumps, flight recorder outputs).

**S669019 sub-SEV2 — OOM from Python 3.10→3.12 in in-trainer publisher.**
Root cause confirmed: Python upgrade introduces OOM via C++/Python binding reference counting issue in publishing bindings (not a general py3.12 regression). py3.10 revert safe. Paul Lu driving; Denny thanked him 6/11. Paul out this morning for cataract surgery follow-up; Denny covered.

**Arbaz Khan ramp-up status:**
- T275298327 (TTFB monitoring) = first OT task
- Min Ni named as dedicated eng/PE for OT hands-on execution support (Michael Chen coordinating)
- Arbaz has weekly meeting scheduling conflict; Paul/Li were out this week

**Cross-check with MVAI agents before building new OT agent capabilities.**
Li Lu's standing suggestion (6/9): before building a new feature in the OT agent, cross-check whether MVAI agents already have it to avoid duplication. Applies to: tooling, metrics queries, debug workflows.

## P2 — references / good-to-know

- App-layer overlay paths canonical URL: https://fburl.com/thrift_fiddle/ca6m6uo2
- Events logging for TTFB is now available (Paul Lu, 6/9) — compute time-to-first-batch from event logs, not inferred from metric gaps
- D108074069 (deep-dive format) and D108045383 (diff→layer) both landed 6/9 — two OT agent capability upgrades in one day
- Denny's 65-model OT fleet number as inventory reference (Arbaz asked about it 6/8)

## Cross-references

- D108195174: discussed in MRS OT Oncall space in same context — consistent framing, no contradiction.
- T275298327 TTFB: new; not yet in fleet-health scan coverage — gap for future fleet-health addition.

## Open coordination threads

- **TTFB alert threshold**: not yet determined. Needs fleetwise TTFB query to calibrate (Li's step before setting alert). Paul Lu suggested realtime isn't mandatory — batch aggregation sufficient.
- **Arbaz/Min Ni ramp-up**: Michael Chen asked Min Ni for OT hands-on support; Min's response not in window. Follow up if T275298327 stalls.
- **MVAI agent cross-check habit**: Li's suggestion has no structural enforcement yet. Consider adding to OT agent change process.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | D108195174 DPP-starvation integration | Monitor diff land; update sev-monitor DPP probe once live | 1h post-land |
| P0 | TTFB slow-start coverage gap | Add TTFB to fleet-health scan when T275298327 matures | 2h |
| P1 | Deep-dive format (D108074069): use when log-heavy | Update triage dispatch logic to select deep-dive format for log-heavy cases | 30m |
| P1 | S669019 py3.12 known-pattern | Add to known-patterns.md: py3.12 OOM via in-trainer publisher binding issue | 30m |
