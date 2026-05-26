# Thread Summary: Confirming Elastic Agent Zombie Root Cause — MAST Log Evidence

_Source: spaces/AAQAVOjYc80 thread `FcSijefZgbM` · 3 messages · 2026-05-18 12:53 PDT – 2026-05-20 12:17 PDT_
_Summarized: 2026-05-20 22:41 PT · last-msg-time: 2026-05-20T19:17:14Z_

## What was discussed

The cron posted a MONITOR triage for ig_reels_tab_mtml models 2123154171 and 2123153585 (S665478), classifying them as an elastic-agent zombie hang. The operator asked what specific MAST log evidence would confirm the root cause is the elastic agent exit code bug (vs other hang mechanisms). The bot provided a 3-layer diagnostic cross-check methodology.

## Key decisions made

- (2026-05-20T19:17:14Z) Confirmed diagnostic sequence is a **4-way cross-check**: (1) `mast-job logs` shows `ChildFailedError` + `CUDACachingAllocator.cpp:3316` SIGABRT; (2) `mast-job error` shows ONLY user-kill with **no AITO classification** — absence is the strongest discriminator (if the top-level process had died, AITO would classify); (3) Scuba mvai_metrics QPS=0 starting at the ChildFailedError timestamp; (4) MAST status = RUNNING throughout until user-kill.
- (2026-05-20T19:17:14Z) `meta ai.mast-job logs` may PHP-OOM on large jobs — workaround: use `--limit` flag or Scuba `aiplatform_mast_job_logs` directly and filter for `CUDACachingAllocator` keyword.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — discussion only) | n/a |

## Cluster / pattern references

- [CL-014] — NCCL timeout / elastic agent zombie class; S665478 is a confirmed instance
- [CL-013] — training example-age spike results downstream from the zombie hang state

## Followup items (not yet done)

(none)

## Cross-refs

- SEVs discussed: S665478, S665454
- Related threads: `4u3oOvwSD30` (elastic agent zombie class consolidation)
