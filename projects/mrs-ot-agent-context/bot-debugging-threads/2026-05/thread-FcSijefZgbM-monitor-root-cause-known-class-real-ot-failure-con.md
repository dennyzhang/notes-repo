# Thread Summary: Confirming Elastic-Agent Zombie Root Cause — S665478 MAST Log Signals

_Source: spaces/AAQAVOjYc80 thread `FcSijefZgbM` · 3 messages · 2026-05-18 – 2026-05-20_
_Summarized: 2026-05-21 00:41 PT · last-msg-time: 2026-05-20T19:17:14Z_

## What was discussed

Denny posted a completed triage output for S665478 (ig_reels_tab_mtml MB9 trainer zombie, P21 elastic-agent hang after NCCL ChildFailedError). Follow-up question: what specific MAST log signals confirm the elastic-agent zombie root cause rather than other hang classes? Bot provided the 4-layer cross-check diagnostic framework for confirming this class.

## Key decisions made

- (2026-05-20T19:17Z) The elastic-agent zombie class is confirmed by a **4-way cross-check**, not any single signal:
  1. Worker logs show `ChildFailedError` + `CUDACachingAllocator.cpp:3316 INTERNAL ASSERT FAILED` (Layer 1 — CUDA assert killed worker)
  2. `meta ai.mast-job error` shows **only** user-kill with no AITO classification (`aito_error_type: USER_TERMINATED_ERROR`, `aito_retryable: empty`) — ABSENCE of AITO class is the discriminator
  3. Scuba `mvai_metrics` QPS=0 starting at hang time T, continuing until user-kill
  4. MAST status = RUNNING throughout the T→user-kill window
- Key counter-intuitive insight: `meta ai.mast-job insights` returning 0 insights is a SUPPORTING signal (no GPU OOM / straggler flags = consistent with elastic-agent surviving without error after worker death)
- Workaround for large-job log retrieval: `meta ai.mast-job logs` may PHP-OOM; use `--limit` or query Scuba `aiplatform_mast_job_logs` directly for `CUDACachingAllocator` lines

## Files / artifacts touched

| path | what changed |
|---|---|
| (none in this thread) | triage discussed; no file writes in this specific exchange |

## Cluster / pattern references

- [CL-012] StuckJobDetector coverage gaps — sjd-coverage-map.md Mode 3: known "Cleanup hang in non-publisher path"
- [CL-014] Training timeout (NCCL/watchdog) — NCCL collective timeout is Layer-1 trigger here

## Followup items (not yet done)

_(none explicitly committed in this thread)_

## Cross-refs

- SEVs discussed: S665478, S665454 (sibling same-class)
- Related threads: `4u3oOvwSD30` (elastic-agent zombie class broader discussion)
