---
name: k9UfpWApGWE-alert-triage-p57-scribe-readproxy
description: Automated alert triage digest — P57 confirmed on scribe_read_proxy AGG + FULL_SNAPSHOT investigation for ig_textpost_feed_u2m_retrieval
metadata:
  type: project
human_involved: false
---

# Thread Summary: Alert triage — P57 scribe_read_proxy (A4622541328066171) + u2m_retrieval FULL_SNAPSHOT investigation (A27273086059047715)

_Source: spaces/AAQAVOjYc80 thread `k9UfpWApGWE` · 7 messages · 2026-06-07 05:19–05:20 UTC_
_Summarized: 2026-06-18 01:20 PT · last-msg-time: 2026-06-07T05:20:39Z_

## What was discussed

Automated `ot-alert-monitor` cron digest in thread, covering two alert resolutions from 2026-06-06. The first (A4622541328066171) was a high-severity `[AGG] scribe_read_proxy/client_lag_in_seconds` for ig_reels_tab_ss_omni_retrieval (model 2144816217) — classified P57 confirmed (7th fire on this model, all NO_ACTION, all auto-resolved). The second (A27273086059047715) was a low-severity `FULL_SNAPSHOT` missing alert for ig_textpost_feed_u2m_retrieval (model 2124099323) — metadata expired, resolution signal was auto-clear, flagged NEEDS_INVESTIGATION with a possible R23 subclass (ig_textpost u2m_retrieval may be STUS, so FULL_SNAPSHOT may be intentionally rare).

## Key decisions made

- A4622541328066171 → P57 / CL-003 confirmed, NO_ACTION (2026-06-07T05:19:17Z) — 7th fire, all identical outcome, no chronic-noisy-model task warranted (both models at 1 alert/7d, below ≥3 floor per policy)
- A27273086059047715 → NEEDS_INVESTIGATION (2026-06-07T05:19:17Z) — hypothesis: R23 subclass (STUS model); if confirmed, reclassify REAL_OT_FAILURE → THRESHOLD_MISFIT

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../resolved-alerts/2026-06/low-2026-06-06-A27273086059047715.md` | archived alert record |
| `~/notes/.../resolved-alerts/2026-06/high-2026-06-06-A4622541328066171.md` | archived alert record |

## Cluster / pattern references

- [CL-003] — A4622541328066171 is a textbook CL-003 (downstream-infra reliability: Scribe/ZippyDB cascade causing false alerts on embedding pipeline)
- P57 — scribe_read_proxy latency false alarm; confirmed valid, multiple prior fires on same model

## Followup items (not yet done)

1. A27273086059047715: verify ig_textpost_feed_u2m_retrieval STUS status (owner: wenping / p92_relevance_retrieval_oncall) — if STUS confirmed, reclassify and potentially add model to R23 suppression list

## Cross-refs

- Alerts discussed: A27273086059047715, A4622541328066171
- Models: 2124099323 (ig_textpost_feed_u2m_retrieval), 2144816217 (ig_reels_tab_ss_omni_retrieval)
