# Thread Summary: 🔴 PAGE yufengma — m2134801434 NaN trainer failure + S666622/S665902

_Source: spaces/AAQAVOjYc80 thread `ZVdqxp0KIX8` · 5 messages · 2026-05-21_
_Summarized: 2026-05-22 07:47 UTC · last-msg-time: 2026-05-21T23:59:04Z_

## What was discussed

OT PAGE for model 2134801434 (facebook_cfr_main_mtml trainer). Three alerts fired detecting NaN in LOSS, NE, and calibration metrics; trainer died and restarted as v125 at 06:47 UTC. The post flagged a second NaN in 4 days and suspected S666622 (radical sizing increase) as a destabilizing factor. A concurrent open SEV S665902 (cfr publish ModuleNotFoundError) was identified as a potential publish-path blocker for v125. Auditor self-heal at 23:59 UTC corrected a fire-time timezone label (body said "01:23 UTC" but the correct reading is 08:23 UTC / 01:23 PDT).

## Key decisions made

- [2026-05-21T15:03:07Z] Verdict: 🔴 PAGE yufengma — NaN recurring (second in 4 days); classify as REAL_OT_FAILURE, confidence medium
- [2026-05-21T15:03:07Z] If NaN persists in v125: apply P56 (revert to snapshot 2134801434:2524, last VALID at 2026-05-20 22:54:48)
- [2026-05-21T23:59:04Z] Auditor self-heal R-EV1: fire-time TZ mislabeled as UTC; corrected to PDT; verdict tier unchanged

## Files / artifacts touched

| path | what changed |
|---|---|
| `https://www.internalfb.com/intern/paste/P2346251513/` | Machine fields for m2134801434 triage |
| `spaces/AAQAVOjYc80/threads/ZVdqxp0KIX8` | Triage sent twice (MyClaw failed on first attempt) |

## Cluster / pattern references

_(CL-017 is cited in the triage post but does not exist in CLUSTERS.md as of 2026-05-22 — omitting per quality rules. The pattern described is "Shampoo NaN cascade" — candidate for a new cluster entry if recurring.)_

## Followup items (not yet done)

1. yufengma: check v125 mvai_metrics for NaN continuation; if NaN persists → apply P56 (revert to 2134801434:2524)
2. Investigate whether S666622 sizing change preceded NaN onset (check timing vs 08:23 UTC alert)
3. Track S665902: if v125 FULL_SNAPSHOT still absent, check cfr publish path for ModuleNotFoundError

## Cross-refs

- SEVs discussed: S666622 (radical sizing, In Progress), S665902 (cfr publish ModuleNotFoundError, In Progress since 2026-05-18), S665163 (ZippyDB, mitigated 2026-05-19)
- Alert: A1703030847735006
- Related threads: `ULIdZMP8AN8` (sibling model 878858380, same cfr_main_mtml family, same CL-017 NaN pattern)
