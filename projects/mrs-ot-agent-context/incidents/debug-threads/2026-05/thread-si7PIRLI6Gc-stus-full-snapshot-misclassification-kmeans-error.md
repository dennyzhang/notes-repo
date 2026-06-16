# Thread Summary: STUS FULL_SNAPSHOT Misclassified as THRESHOLD_MISFIT — kmeans Assertion Missed

_Source: spaces/AAQAVOjYc80 thread `si7PIRLI6Gc` · 7 messages · 2026-05-19_
_Summarized: 2026-05-19 22:41 PT · last-msg-time: 2026-05-19T16:09:00Z_

## What was discussed

Cron classified m2130324780 (ig_textpost_feed_m2m_retrieval, STUS role) FULL_SNAPSHOT gap (74.9h) as THRESHOLD_MISFIT — 2nd fire of alert 1455336899399360. The live session caught that cron never ran `meta ai.mast-job error --version=40` on the last FAILED attempt: `AssertionError: At least 64077 embs needed for kmeans, but got 22035` in `silvertorch/experimental/realtime/fresh_index_initializer.py:91`. This is a real STUS-internal failure (upstream embedding corpus regression), not a detector threshold misfit.

Denny then asked: "If full snapshot detection is 44h, why did the alert come at 75h?" Bot explained: the detector fired on-time at ~44h (2026-05-17 20:32 PT, 1st fire); 75h is the 2nd re-notification after the OneDetection dedup window expired (~30h re-notify interval). Denny asked: "Any gap in the monitoring system? This should be a recurring check in alert triage. If yes, file tasks and work on diffs."

## Key decisions made

- **[2026-05-19T14:52:33Z]** Bot corrected THRESHOLD_MISFIT → REAL_OT_FAILURE (STUS-internal kmeans assertion on upstream embedding feed regression). The distinction matters: THRESHOLD_MISFIT routes to "silence detector"; REAL_OT_FAILURE routes to "ronghuang investigate upstream emb feed."
- **[2026-05-19T16:09:00Z]** Denny established standing rule: gaps in the monitoring system found during triage should trigger task-filing and diff work. Bot to apply this as a recurring triage step.

## Files / artifacts touched

| path | what changed |
|---|---|
| (no files written this session) | Prompt edits identified but batched to WApKJGlKThc |

## Cluster / pattern references

- [CL-008] — STUS jobs mis-classified: cron has R14/R23 for STUS role detection, but THRESHOLD_MISFIT classification path skips `mast-job error` on FAILED attempts — same carryover-anchoring gap
- [CL-001] — STUS FULL_SNAPSHOT missing is architecturally similar to snapshot-stuck-CREATING

## Followup items (not yet done)

1. Prompt edit: before classifying THRESHOLD_MISFIT on publishing-stability alerts, run `mast-job error` on the latest FAILED attempt; if error_message non-empty → default to REAL_OT_FAILURE — batched to WApKJGlKThc
2. Recurring triage check: for each alert, verify dedup-window behavior; document "re-notification ≠ re-detection" in `references/publishing-stability-alerts.md` — per Denny's 2026-05-19T16:09Z direction, this should also generate a task + diff

## Cross-refs

- SEVs discussed: S654852 (unrelated prior SEV for same model)
- Related threads: `WApKJGlKThc` (prompt-edit batch), `QisdJLyHeLE` (auditor dry-run item #2 on this thread)
