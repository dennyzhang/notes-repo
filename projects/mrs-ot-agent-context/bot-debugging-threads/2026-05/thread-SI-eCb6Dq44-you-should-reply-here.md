# Thread Summary: Duplicate Alerts + Publishing Cadence Debug — Model 878858380 (facebook_cfr_main_mtml)

_Source: spaces/AAQAVOjYc80 thread `SI-eCb6Dq44` · 21 messages · 2026-05-22_
_Summarized: 2026-05-22 21:47 PDT · last-msg-time: 2026-05-22T06:13:43Z_

## What was discussed

Denny surfaced two problems with OT-bot's handling of alerts for model 878858380 (facebook_cfr_main_mtml). (1) Two separate OneDetection alerts fired for the same model — bot diagnosed as duplicate observer registrations (`913270201550407` + `848590011404637`, same metric, same start_time, 6-min gap from different confirmation windows). (2) `ot-alert-monitor` silently suppressed both critical alerts for 3+ hours due to the 24h hold-down bug (both IDs were in `diagnosed_ids` from the morning bulk-stamp migration). Additionally Denny asked for a deep-dive on the FULL_SNAPSHOT release cadence for model 878858380, revealing a systemic publish-path fragility (CREATING zombies, silent skips, 25% of gaps >100min SLO).

## Key decisions made

- **2026-05-22T05:45:42Z** Bot: three fixes queued for weekly batch: (1) priority-aware hold-down (critical alerts bypass 24h hold-down), (2) state-transition refresh (re-triage if alert went open→closed→open since last diagnosed), (3) fail-loud stuck-suppression detector (>2h OPEN + never operator-acknowledged → surface notification).
- **2026-05-22T05:53:59Z** Denny: "yes, file a meta task and propose a fix."
- **2026-05-22T05:54:21Z** Task filed: T272497510 (model_store oncall, MID priority). Bot chose NOT to fire blind configerator diff — deferred to proposal artifact.
- **2026-05-22T06:05:48Z** Denny: "fire a proposal diff."
- **2026-05-22T06:13:43Z** D106049931 fired (DRAFT, unpublished): `pe_mrs_ml/mrs_ot_agent/proposals/dai_modelstore_dedup_proposal.md` (180 lines). Posted as comment on T272497510.

## Files / artifacts touched

| path | what changed |
|---|---|
| `fbcode/pe_mrs_ml/mrs_ot_agent/proposals/dai_modelstore_dedup_proposal.md` | New (D106049931, DRAFT) |

## Cluster / pattern references

- CREATING zombie pattern — 5 size=0 stuck snapshots in last 4 days for model 878858380; every gap >180min follows a CREATING zombie. Not yet a named pattern entry.
- Hold-down bug root cause: bulk-stamp epoch from bare-list→dict schema migration treated persistent critical alerts as "already diagnosed."

## Followup items (not yet done)

1. T272497510 OPEN — model_store to review D106049931 proposal and implement real dedup fix.
2. Weekly batch: land 3 `ot-alert-monitor` fixes (priority-aware hold-down, state-transition refresh, fail-loud stuck-suppression).
3. CREATING-zombie reaper for model_store publish path (Mode A: `CREATING + size=0 + age>30min → FAILED`).
4. Silent skip alerting: add observer on "Async publish process creation failed!" trainer log.

## Cross-refs

- SEVs discussed: S667071 (Scribe, acute cause of today's worst 692-min gap)
- Tasks: T272497510
- Diffs: D106049931 (proposal, DRAFT)
- Related threads: `fRqqEPlfcsQ` (disk/eden context from same day)
