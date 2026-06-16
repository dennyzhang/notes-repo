---
human_involved: false
thread_id: a2iUBsV8sGA
thread_name: spaces/AAQAVOjYc80/threads/a2iUBsV8sGA
msg_count: 3
date_range: 2026-06-02 08:09–08:12 PDT
summarized: 2026-06-03 10:43 PDT
last_msg_time: 2026-06-02T15:12:02Z
---

# Thread Summary: S669486 — Threads Retrieval U2M Publish Failures (Accidental OT Job Closure)

_Source: spaces/AAQAVOjYc80 thread `a2iUBsV8sGA` · 3 messages · 2026-06-02 08:09–08:12 PDT_
_Summarized: 2026-06-03 10:43 PT · last-msg-time: 2026-06-02T15:12:02Z_

## What was discussed

Postmortem digest for S669486 (mvai_publish_pipeline, L3, Closed after ~5.5 days): ig_textpost_feed_xapp_u2m_retrieval holdout (model 2147155613) failed to publish new snapshots. Two compounding factors: (a) recurring publish for the holdout had already expired; (b) ronghuang accidentally closed OT job 2147155628 (root model) while cleaning training machines on 2026-06-01. Both factors confirmed via GChat read (AAQA-hlmF2E). Two validators confirmed clean, all 5 checks passed.

## Key decisions made

- No new P-row: single one-off human error, below ≥3-sample threshold (2026-06-02T15:09:35Z).
- Operational learning: before closing OT jobs during machine cleanup, verify TMS deregistration and confirm no holdout traffic depends on the model.
- Production model is 2132160075 (recent launch); 2147155613 holdout was already planned for cleanup.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — postmortem digest output only) | — |

## Cluster / pattern references

(omitted — no verified cluster IDs)

## Followup items (not yet done)

(none — holdout cleanup was intentional; no follow-up tasks filed; SEV closed)

## Cross-refs

- SEVs discussed: S669486
- Posts: (none)
- Related threads: (none)
