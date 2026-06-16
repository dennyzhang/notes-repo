---
name: lsr-snapshot-stuck-creating-phase
description: LSR online training model 2124090946 snapshots :0–:4 all stuck CREATING with size=0; overlaps with S661170 GPU quota SEV
metadata:
  type: project
  thread_id: "ky-p7TPPrHs"
  space: spaces/AAQAVOjYc80
  human_involved: false
---

# Thread Summary: LSR Online Training — Snapshot Stuck in CREATING Phase

_Source: spaces/AAQAVOjYc80 thread `ky-p7TPPrHs` · 3 messages · 2026-05-08_
_Summarized: 2026-05-08 13:38–13:40 PT · last-msg-time: 2026-05-08T20:40:15Z_

## What was discussed

Feier Lian posted to mrs.ot: model 2124090946 (facebook_reels_ifu_mtml_v0) snapshots :0–:4 stuck in CREATING state with size=0 for 19+ hours. Trainer MAST job RUNNING healthy, no errors. Bot diagnosed overlap with S661170 (GPU quota rejection for publish jobs, MITIGATED 13:14 same day). Validator confirmed.

## Key decisions made

- **S661170 (GPU quota) explains :0–:3** (started before mitigation at 13:14 PT), but snapshot :4 (started 12:07 PT, before mitigation) also size=0 post-mitigation — publish pipeline not auto-retrying after quota cleared.
- **UNKNOWN_PG namespace on snapshot :0** flagged as possible contributing factor — may block snapshot validation independent of GPU quota.
- **Manual re-trigger needed** — CREATING snapshots don't auto-retry; videorecs_ranking oncall must manually re-trigger publish job.
- **Owner:** feierlian (model owner), route: videorecs_ranking oncall.

## Files / artifacts touched

| path | what changed |
|---|---|
| MAST job mvai-training-online-2124090946 | RUNNING, not the failure point |
| Snapshots :0–:4 | all CREATING, size=0, blocked in publish pipeline |

## Cluster / pattern references

_(No existing cluster ID confirmed — omitted per quality rule.)_

## Followup items (not yet done)

1. Check propagation delay after S661170 mitigation — if snapshot :4 still size=0 by ~14:30 PT, re-trigger manually.
2. Investigate UNKNOWN_PG namespace on snapshot :0 — may need model config fix.

## Cross-refs

- SEVs discussed: S661170 (L3, GPU quota rejection for publish jobs, MITIGATED 13:14 2026-05-08)
- Posts: https://fb.workplace.com/groups/mrs.ot/permalink/1320805680014175/
