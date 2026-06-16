# Thread Summary: Post-postmortem digest validation — 4 alerts (2026-05-20)

_Source: spaces/AAQAVOjYc80 thread `qg9Esaf-vSs` · 6 messages · 2026-05-21 05:18–05:19 UTC_
_Summarized: 2026-05-24 17:50 PT · last-msg-time: 2026-05-21T05:19:19Z_

## What was discussed

Digest validation session for 4 `mrs_online_training` alerts. Three confirmed, one reclassified. Two chronic-noisy models were contextualized (both had known active explanations). Two cron bugs noted (same as thread `DKEswmprWqA`). The post-emit in-thread validation pattern was applied again.

## Key decisions made

- `2026-05-21T05:18:52Z` — **A2102250270339970** confirmed: DETECTOR_BROKEN/CL-013 (D75703936 TZ formula, 3rd recurrence on m877766932). Escalation: 3rd fire on same model passes passive-verdict threshold — page charlesz for suppression or D75703936 landing, not just "auto-cleared, monitor."
- `2026-05-21T05:18:52Z` — **A950082977383608** confirmed: THRESHOLD_MISFIT/CL-003 (scribe lag, 5-model IG holdout family).
- `2026-05-21T05:18:52Z` — **A851114280806378** confirmed: TRANSIENT_NOISE/CL-003 (2/7 real OT sub-alerts, scribe lag spike, 2nd fire in 4d).
- `2026-05-21T05:18:52Z` — **A1473282050958618** RECLASSIFIED: primary = M-011 GPU under-utilization (SM util p50=0.92% vs fleet 36.52% — 40× gap); CL-003 scribe-lag was co-fire noise that auto-cleared. PAGE xinwu/ig_feed_retrieval (not just "investigate"). First M-011 instance flagged for new P-row.
- `2026-05-21T05:19:19Z` — "Chronic-noisy with known-SEV" vs "chronic-noisy unexplained" distinction: m878858380 (in S665902), m878102693 (IG holdout, Peiyang Yu threshold tuning) are both explained → not independently actionable this week.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-alerts/2026-05/critical-2026-05-20-A2102250270339970.md` | Archived (cron-created) |
| `incidents/resolved-alerts/2026-05/high-2026-05-20-A950082977383608.md` | Archived |
| `incidents/resolved-alerts/2026-05/high-2026-05-20-A851114280806378.md` | Archived |
| `incidents/resolved-alerts/2026-05/high-2026-05-20-A1473282050958618.md` | Archived |

## Cluster / pattern references

- [CL-013] — A2102250270339970: training example-age formula bug (D75703936), 3rd recurrence
- [CL-003] — A950082977383608, A851114280806378: downstream-infra scribe lag
- [CL-003] — A1473282050958618: co-fire noise only; primary is M-011 (new, first documented instance)

## Followup items (not yet done)

1. Draft new P-row for M-011 (GPU under-utilization / low SM util) — first documented instance 2026-05-20.
2. Page charlesz on D75703936 or set suppression for m877766932 (3rd recurrence threshold crossed).
3. Add "chronic-noisy with known-SEV explanation" flag to digest cron — "known-SEV" vs "unexplained" distinction saves false triage.

## Cross-refs

- SEVs discussed: S665902 (m878858380 context)
- Posts: none
- Related threads: `DKEswmprWqA` (same cron bugs noted in both)
