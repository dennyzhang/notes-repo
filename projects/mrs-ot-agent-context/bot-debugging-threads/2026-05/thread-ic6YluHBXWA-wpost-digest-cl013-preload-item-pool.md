# Thread Summary: W-Post Digest — ig_retrieval _preload_item_pool DPP Starvation (CL-013)

_Source: spaces/AAQAVOjYc80 thread `ic6YluHBXWA` · 9 messages · 2026-05-20T04:37–05:40 UTC_
_Summarized: 2026-05-20 23:45 PT · last-msg-time: 2026-05-20T05:40:03Z_

## What was discussed

W-post digest processed Workplace post W1324864999608243 (Rudra Barua, "OT Not Creating New Checkpoints + OP Not Creating New Snapshots"). The cron classified it as CL-013 (training example-age / DPP starvation). A validator pass confirmed the classification as correct and clean — no new pattern proposals needed.

## Key decisions made

- **CL-013 classification confirmed correct** (2026-05-20T05:40:03Z validator): `_preload_item_pool()` blocks DPP consumer during startup → queues fill → GetDataTimeoutError 6000s → crash loop over 9 restarts in 2 regions. Existing archive from 2026-05-17 (run 725) is richer; no rewrite performed.
- **No new P-row** (2026-05-20T05:40:03Z): `_preload_item_pool` block mechanism is novel vs P43 but not distinct enough for its own row yet; defer until second occurrence.
- **Existing archive retained** (04:37 UTC): `archives_skipped_existing_richer=1` — correct action when a richer archive already exists.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-posts/2026-05/2026-05-17-W1324864999608243.md` | Existing archive retained (UPSERT skipped) |

## Cluster / pattern references

- [CL-013] — `_preload_item_pool()` deadlock matches DPP starvation via output-queue fill; 2 regions, 9 restarts, 21h outage for ig_retrieval trainer

## Followup items (not yet done)

## Cross-refs

- Posts: W1324864999608243
- Related threads: `UH1t_Fwjom4` (parallel SEV digest with validator-unavailable same gap)
