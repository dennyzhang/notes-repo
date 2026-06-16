# Thread Summary: Zombie Job Definition + Notes→SQLite Drift Fix

---
human_involved: false
---

_Source: spaces/AAQAVOjYc80 thread `umrMW1Mw8A0` · 4 messages · 2026-06-03T18:28–18:33Z_
_Summarized: 2026-06-03 16:43 PT · last-msg-time: 2026-06-03T18:33:34Z_

## What was discussed

Operator asked "what makes it zombie?" in context of a training job. Bot also found a concurrent validator post flagging notes→sqlite drift in the daily-brief cron, handled the drift fix first, then answered the zombie question.

## Key decisions made

- **Notes→sqlite drift fix (18:33Z):** `setup-cron-jobs.sh` → `updates=1`. The `daily-brief` prompt in sqlite had drifted; after sync it references `spaces/AAQAVOjYc80` (operator 1:1) ×7, zero refs to the team space. Tomorrow's 08:14 fire routes correctly.
- **Zombie job definition (18:33Z):** A zombie = MAST/TMS reports `RUNNING` (process alive, heartbeat OK) while trainer makes *zero forward progress* (QPS/mvai_metrics flatline at 0). Key property: the *gap between scheduler-perceived liveness and actual training progress*.
- **Mechanism:** (1) One rank hangs (e.g. CUDA IMA corrupts context, as in S670844) — *hangs*, doesn't crash-exit. (2) All other ranks block forever on the next NCCL collective waiting for the stuck rank → distributed deadlock. GPUs idle, processes stay up. (3) Safety nets miss it: NCCL watchdog needs a timeout (hung rank never exits); MAST/TMS health = process-liveness, not training progress; elastic agent only restarts on a clean `ChildFailedError` (hung rank never exits cleanly).
- **Recovery gap:** v35 was a 1.5h manual kill (`"Job seems stuck, restarting OT"`) — no progress-aware auto-kill fired. A QPS=0-for-N-min watchdog while RUNNING would turn a 1.5h zombie into a fast auto-restart.

## Files / artifacts touched

| path | what changed |
|---|---|
| sqlite (myclaw.db) | daily-brief prompt synced from notes (updates=1) |

## Cluster / pattern references

(omitted — cluster IDs not verified against failure-patterns.md)

## Followup items (not yet done)

1. Implement QPS=0-for-N-min auto-kill watchdog — the structural fix for zombie detection (proposed in thread, not implemented).

## Cross-refs

- SEVs discussed: S670887 (OOM zombie, previously mis-triaged), S670844 (CUDA IMA trigger)
- Related: memory `triage-fact-gathering-probe-set` (GPU-mem probe skipped in S670887 mis-triage)
