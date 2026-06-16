---
name: human-2026-06-10-1554-OQj2eYyr-O4
description: vdd_hstu 2130289862 FULL_SNAPSHOT stall; cron said "partial"; operator correction prompted full triage; root = shared STORAGE_SVC_PUT_CHUNK timeouts
metadata:
  type: project
  human_involved: true
---

# Thread Summary: vdd_hstu FULL_SNAPSHOT stall — storage write timeout, not bootstrap

_Source: spaces/AAQAVOjYc80 thread `OQj2eYyr-O4` · 4 messages · 2026-06-10 22:54–22:56 UTC_
_Summarized: 2026-06-10 23:06 PT · last-msg-time: 2026-06-10T22:56:35Z_

## What was discussed

Cron had labeled `facebook_reels_vdd_hstu_v0` model 2130289862 as "partial / medium / bootstrap not conclusively closed." Operator challenged: "why you don't triage the issue?" Bot ran OBSERVE probes and produced a conclusive verdict. Key reframe: v7a2 IS RUNNING (since ~13:16, 2.5h), so it's not a bootstrap stall. FULL_SNAPSHOT is stalled because `STORAGE_SVC_PUT_CHUNK` / `CAN_ACCEPT` are timing out fleet-wide across trainers (MTRS_RESOURCE_BUSY_TIMEOUT, TIMED_OUT 1199s, IO_ERROR, NETWORK_ERROR, ongoing from 14:10 through 15:40+). Small SPARSE/DENSE deltas squeak through; large multi-chunk FS writes cannot complete.

## Key decisions made

- [22:56 UTC] Root = UPSTREAM_INFRA (storage write tier), not model-owner issue. Route to storage/manifold/MTRS oncall, not model owner kedhe. [CORRECTION: cron stopped at "partial"; operator forced the triage]
- [22:56 UTC] The STORAGE_SVC_PUT_CHUNK RESOURCE_BUSY_TIMEOUT signature matches the zombie 2121054758 earlier the same day — INFERRED shared permv2/MTRS tier event. Discriminating check: cross-model large-write timeout rate to confirm shared vs per-shard.
- [22:56 UTC] Not a page yet (deltas keep serving; FS staleness degrades gradually) — but if fleet-wide, escalate as shared-infra event.

## Files / artifacts touched

| path | what changed |
|---|---|
| — | no files modified; triage verdict produced in-thread |

## Cluster / pattern references

- [CL-001] — Snapshot-stuck-CREATING; this is a storage-write-failure variant (PUT_CHUNK timeout blocking FS completion vs. CREATING stall in the scheduler). Related mechanism, different failure point.
- [CL-003] — Downstream-infra reliability (shared tier cascade); storage/MTRS write-tier degradation matches this cluster's "shared infra event affecting multi-model OT jobs" pattern.

## Followup items (not yet done)

1. Verify: is the PUT_CHUNK timeout fleet-wide across OT models? If yes, file as shared-infra event with storage/MTRS oncall.

## Cross-refs

- Models: 2130289862 (vdd_hstu_v0), trainer 2130289886; cross-ref zombie 2121054758 (same PUT_CHUNK signature same day)
- Related threads: none
