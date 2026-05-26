# Thread Summary: Post digest — preload deadlock + training-age false-positive pattern proposals

_Source: spaces/AAQAVOjYc80 thread `rKkU35N2J14` · 8 messages · 2026-05-18T04:38–04:39 UTC_
_Summarized: 2026-05-18 22:42 PT · last-msg-time: 2026-05-18T04:39:38Z_

## What was discussed

`ot-daily-learning-mitigated-posts` cron digest covered two Workplace posts (W1324864999608243 and W1321547686606641) and proposed two new P-row patterns. Bot and operator analyzed both proposals, disagreed on where the second one belongs (P-row vs CL-013 detector pitfall), and discussed chronic-source tracking heuristics. Validator was unavailable (no Agent tool in cron context); confidence capped at 0.5.

## Key decisions made

- (2026-05-18T04:38:57Z) P_new(1) `_preload_item_pool() ↔ DPP consumer deadlock`: ACCEPT as new P-row under CL-013, not a new CL. Mechanism is distinct (startup preload path, parameter-tunable fix: `--preload-batch-size 2048→512`), owner-routable to p92_relevance_retrieval.
- (2026-05-18T04:38:57Z) P_new(2) `checkpoint_training_data_age_mins false-positive for OT jobs`: Do NOT add as P-row. Add as CL-013 "Detector pitfalls" subsection note instead. This is a detector-quality finding, not a failure pattern. Cross-check: `dpp_worker.scribe_example_age_ms.avg.60` in ODS; if ODS healthy → false-positive. Known bug D75703986 (timezone mismatch).
- (2026-05-18T04:39:11Z) Validator-skip should emit a louder banner (`⚠️ UNVALIDATED`) rather than a footnote line — batch with next cron-prompt-hygiene pass.
- Empty top-3 chronic-post sources this week = healthy signal. CL-NNN frequency would be a richer v2 signal than entity frequency.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-posts/2026-05/2026-05-17-W1324864999608243.md` | Archive created (HEURISTIC_RESOLVED, CL-013) |
| `incidents/resolved-posts/2026-05/2026-05-17-W1321547686606641.md` | Archive created (HEURISTIC_RESOLVED, HOWTO) |

## Cluster / pattern references

- [CL-013] — Training example-age spike; both posts relate to this cluster (DPP queue stall, false-positive age metric)
- [CL-014] — Training timeout (NCCL/watchdog/RaaS); DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE is the CL-013/CL-014 boundary signal for W1324864999608243

## Followup items (not yet done)

1. Land P_new(1) as `P-XX` under CL-013 in failure-patterns.md (mechanism: startup preload deadlock).
2. Land P_new(2) as CL-013 detector-pitfall note: add ODS cross-check requirement before declaring CL-013.
3. Add louder UNVALIDATED banner to `ot-daily-learning-mitigated-posts` cron prompt.
4. Tighten upstream scope_check.py regex (backlog, separate diff).

## Cross-refs

- SEVs discussed: none directly
- Posts: W1324864999608243 (Rudra Barua, _preload_item_pool deadlock), W1321547686606641 (Denny Zhang, training-age formula bug)
- Related threads: `6i0LDKZxIR8` (archive cleanup same session)
