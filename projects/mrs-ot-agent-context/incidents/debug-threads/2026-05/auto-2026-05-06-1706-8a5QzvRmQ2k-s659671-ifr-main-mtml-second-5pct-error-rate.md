# Thread Summary: S659671 — facebook_ifr_main_mtml_second 5+% sigrid error rate (snapshot 2473 regression)

_Source: spaces/AAQAVOjYc80 thread `8a5QzvRmQ2k` · 3 messages · 2026-05-06 17:06–17:09 PDT_
_Summarized: 2026-06-02 10:43 PT · last-msg-time: 2026-05-06T00:09:18Z_
human_involved: false

## What was discussed

Bot triage of S659671 (L3, mrs_online_training): model m875961478 (chronos_secgrp_feed_recommendations, facebook_ifr_main_mtml_second) showing 5+% error rate at sigrid tier 1 (400–600kQPS). Error onset 34 minutes after snapshot 2473 publish (11:02 PDT); snapshots 2474 and 2475 also serving errors → rollback to 2472 not yet executed. Duration 5h29m at triage time. Standing hypothesis: feature schema or model dependency regression introduced with snapshot 2473. Validator flagged one discrepancy: S659181 (cfr_feed_mtml_userfm sigrid errors) was cited as a concurrent parallel signal but actually predates S659671 by ~48h — it's a pre-existing incident, not simultaneous.

## Key decisions made

- Snapshot 2472 (pre-incident) identified as rollback target (2026-05-06 17:08 PDT); action: `meta ai.model.instance metadata --instance-id=875961478:2472`
- Validator discrepancy noted: S659181 is pre-existing (started 2026-05-03), not concurrent — cross-ref should not imply shared upstream root cause (2026-05-06 17:09 PDT)

## Files / artifacts touched

| path | what changed |
|---|---|
| fbcode/fblearner/predictor/ | sigrid predictor mtml serving (investigation target, no edits) |

## Cluster / pattern references

_(omitted — not verified against failure-patterns.md)_

## Followup items (not yet done)

1. Roll back to snapshot 2472 to mitigate — owner: ajfoiani / jiweny
2. Compare feature configs between snapshots 2472 and 2473 to identify regression — owner: ajfoiani + jiweny
3. Add mtml serving canary: pre-deploy error rate gate in predictor tier (long-term)

## Cross-refs

- SEVs discussed: S659671, S659181 (pre-existing, not concurrent)
- Posts: none
- Related threads: none
