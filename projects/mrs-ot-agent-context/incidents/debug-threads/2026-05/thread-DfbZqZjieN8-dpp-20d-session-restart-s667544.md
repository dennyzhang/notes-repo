# Thread Summary: DPP 20-day session restart → example age spike (S667544)

_Source: spaces/AAQAVOjYc80 thread `DfbZqZjieN8` · 5 messages · 2026-05-23T17:39–17:57Z_
_Summarized: 2026-05-23 22:50 PT · last-msg-time: 2026-05-23T17:57Z_

## What was discussed

Denny filed a triage report for S667544 (L3, Mitigated 10:30 UTC, 3.6h). The root cause was a DPP session being killed at the designed 20-day age limit (`SessionController.cpp:2204 checkSessionAgeLimit()`) causing a 2.6-minute data gap and an example-age spike on IFR MC8 MTML. Bot hit idle timeout before responding substantively; thread completed via the triage post only.

## Key decisions made

- [2026-05-23T17:39Z] Pattern identified as non-actionable 20-day-limit event: ~50 OT models affected on ~20d cycle (~280 dips per half-fleet per cycle). Auto-recovered; no emergency restart needed.
- [2026-05-23T17:39Z] P0 follow-up: loop in `dpp_distributed_data_reading` for graceful session rotation (task T272679108, from P2349015923).
- [2026-05-23T17:39Z] Recommended adding DPP restart fingerprint as new cluster entry in `failure-patterns.md` to short-circuit future triage on this symptom class.

## Files / artifacts touched

| path | what changed |
|---|---|
| Workplace post | https://fb.workplace.com/groups/mrs.ot/permalink/1332798372148239/ |
| Paste P2349022325 | Detail triage report |
| Task T272679108 | Graceful DPP session rotation P0 |

## Cluster / pattern references

- [CL-013] — training example-age spike; DPP session restart is a sub-mechanism causing a transient age spike with auto-recovery
- [CL-003] — downstream-infra reliability: DPP `checkSessionAgeLimit()` is the triggering component

## Followup items (not yet done)

1. Add DPP 20-day restart fingerprint as new CL entry in `failure-patterns.md` — unowned, proposed by Denny

## Cross-refs

- SEVs discussed: S667544
- Posts: W1332798372148239
- Related threads: `glb71z7nhJ0` (same-day example-age SEVs)
