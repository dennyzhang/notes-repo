# Thread Summary: OT Alert Digest — ZippyDB Cascade × 2 + Publisher Hang Self-Heal

_Source: spaces/AAQAVOjYc80 thread `ph5LCN64YIY` · 6 messages · 2026-05-24T05:20–05:22 UTC (2026-05-23 22:20–22:22 PDT)_
_Summarized: 2026-05-24 19:50 PT · last-msg-time: 2026-05-24T05:22:12Z_

## What was discussed

Denny posted a 3-alert OT triage digest. A997443402676035 (m878102693 AGG) and A26934055329519355 (m2130305043 SPARSE_DELTA) = CL-003 UPSTREAM_INFRA — ZippyDB cascade (S667276/S654082/S653864 In Progress) + stale feed item (April 18); no OT action. A1386657526635645 (m2125752019 FULL_SNAPSHOT) = REAL_OT_FAILURE, publisher subprocess hang self-healed via StuckJobDetector. Bot flagged `weights_delta_publisher.py` at 2 incidents in ~36h across different functions; below P-row threshold but watching.

## Key decisions made

- `[2026-05-24T05:21:51Z]` A997443402676035 (m878102693) = CL-003 UPSTREAM_INFRA; ZippyDB S667276/S654082/S653864 In Progress, more noise expected. No OT action.
- `[2026-05-24T05:21:51Z]` A26934055329519355 (m2130305043) = CL-003 UPSTREAM_INFRA; stale feed item April 18. No OT action.
- `[2026-05-24T05:21:51Z]` A1386657526635645 (m2125752019) = REAL_OT_FAILURE self-healed. Publisher hang → StuckJobDetector @ 12:13 PDT → v25 restart 12:33 → FULL_SNAPSHOT published 18:02 PDT. No manual action.
- `[2026-05-24T05:22:12Z]` `ai.model.instance list` freshness floor ~90min. Gap <2h ≠ staleness; cross-check MAST status + mvai_metrics.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../resolved-alerts/2026-05/low-2026-05-23-A997443402676035-449.md` | archived; @bsun tagged to confirm/correct |
| `~/notes/.../resolved-alerts/2026-05/high-2026-05-23-A26934055329519355.md` | archived; bot-verified UPSTREAM_INFRA |
| `~/notes/.../resolved-alerts/2026-05/high-2026-05-23-A1386657526635645.md` | archived; @yucheng tagged to confirm/correct |

## Cluster / pattern references

- [CL-003] — both A997443402676035 and A26934055329519355 match ZippyDB/scribe cascade pattern; S667276+S654082+S653864 driving ongoing noise on m878102693
- [CL-001] — A1386657526635645 is a CL-001 symptom (publisher subprocess hang → CREATING stuck); self-healed, first occurrence for this model

## Followup items (not yet done)

1. @bsun: confirm or correct triage on A997443402676035 (marked in archive file)
2. @yucheng: confirm or correct triage on A1386657526635645 (marked in archive file)
3. `weights_delta_publisher.py` — 2 incidents in ~36h across two models/functions; watch for third (P-row threshold is ≥2 per model, not per module)
4. m878858380 (facebook_cfr_main_mtml) at 6 FULL_SNAPSHOT alerts in 7d — bot offered to pull its alert history; unanswered in this thread

## Cross-refs

- SEVs discussed: S667276, S654082, S653864 (ZippyDB, all In Progress at time of triage)
- Related threads: `glb71z7nhJ0` (prior CL-003 context per archive reference)
