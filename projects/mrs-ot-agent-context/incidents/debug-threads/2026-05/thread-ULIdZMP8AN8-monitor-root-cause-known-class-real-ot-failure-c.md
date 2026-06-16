# Thread Summary: 🟡 MONITOR yzqian — m878858380 oscillating NaN alert + MyClaw audit findings

_Source: spaces/AAQAVOjYc80 thread `ULIdZMP8AN8` · 5 messages · 2026-05-21_
_Summarized: 2026-05-22 07:47 UTC · last-msg-time: 2026-05-21T23:59:12Z_

## What was discussed

OT MONITOR for model 878858380 (facebook_cfr_main_mtml trainer), sibling of 2134801434. Three alerts from 2026-05-17 for NaN remain OPEN via oscillation; model auto-recovered through v146 (started 07:33 UTC). Triage rated as REAL_OT_FAILURE auto-resolved, chronic-noisy model (#1 by alert count per noisy-models.md). The thread also surfaced a cross-thread audit request: Denny directed MyClaw to "Investigate this. Be thorough." re: paste P2346253789 (this is the same triage post). MyClaw's audit response was delivered in thread `yXZMouOo5sU` (routing artifact). Auditor self-heal at 23:59 corrected fire-time TZ (05:28 PDT, not UTC).

## Key decisions made

- [2026-05-21T15:04:57Z] Verdict: 🟡 MONITOR yzqian — NaN oscillating, auto-resolved, no immediate action
- [2026-05-21T15:05:44Z] Triage re-sent (MyClaw failed first attempt at 15:05:14) — duplicate post, same content
- [2026-05-21T23:59:12Z] Auditor self-heal R-EV1: alert_created_time=1779020928 → 12:28:48 UTC / 05:28:48 PDT; body mislabeled as UTC; verdict tier unchanged

## Files / artifacts touched

| path | what changed |
|---|---|
| `https://www.internalfb.com/intern/paste/P2346253789/` | Machine fields for m878858380 triage (investigated in thread yXZMouOo5sU) |

## Cluster / pattern references

_(CL-017 cited in triage but absent from CLUSTERS.md — omitting per quality rules. See thread ZVdqxp0KIX8 note for Shampoo NaN candidate cluster.)_

## Followup items (not yet done)

1. yzqian: track S665902 (cfr_main_feed_mtml publish ModuleNotFoundError) — may affect v146 publish path
2. Track S666636 (IPNext availability for m878858380) for serving impact

## Cross-refs

- SEVs discussed: S665902 (cfr publish, In Progress), S666636 (IPNext, In Progress), S665163 (ZippyDB, mitigated)
- Alert: A25209897055308328
- Related threads: `ZVdqxp0KIX8` (sibling m2134801434, same family), `yXZMouOo5sU` (MyClaw audit response for this thread landed there — routing artifact)
