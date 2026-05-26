# Thread Summary: ig_reels_starsearch_t2i_retrieval — DETECTOR_BROKEN duplicate triage

_Source: spaces/AAQAVOjYc80 thread `vT6Qk-hir-4` · 5 messages · 2026-05-18T02:26–02:31 UTC_
_Summarized: 2026-05-18 22:42 PT · last-msg-time: 2026-05-18T02:31:15Z_

## What was discussed

Alert `[Invalid Detector - No Data]` fired for model 2126189932 (ig_reels_starsearch_t2i_retrieval, role=stus) on sparse-delta e2e latency. Bot triaged it three times in quick succession (02:29, 02:30, 02:31 UTC) — all three reached identical verdict `NO_ACTION / DETECTOR_BROKEN / high confidence`. An interleaved "Test reply in thread A" (02:30:54Z) suggests threading-behavior testing was happening concurrently. Disk-full condition caused pastry failures in all three outputs (`ENOSPC`).

## Key decisions made

- (2026-05-18T02:29–02:31Z) Verdict: OneDetection detector lost its data source (Scribe/metric offline) — model pipeline is healthy. SPARSE_DELTA publishing every ~2 min, MAST v4 running since 2026-05-13. No model intervention needed; detector data source requires repair by igr_retrieval / OneDetection oncall.
- Three duplicate triage outputs in 2 minutes indicate the alert fired multiple times in the hold-down window; the dedup logic did not suppress the re-triage.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — read-only triage run) | no file edits; pastry creation failed (ENOSPC) |

## Cluster / pattern references

- [CL-018] — alert noise / dead-detector / invalid-detector rules; this is a textbook DETECTOR_BROKEN instance (detector config broken, not model)
- [CL-008] — STUS jobs mis-classified; model is STUS (role=stus), not a trainer — detector was tracking wrong metric type

## Followup items (not yet done)

_(none explicitly discussed — operator did not request action)_

## Cross-refs

- SEVs discussed: S658333 (quota/QPS, In Progress), S660122 (Closed)
- Posts: none
- Related threads: none
