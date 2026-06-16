---
thread_id: T5Y1BA-UTLw
space: spaces/AAQAVOjYc80
human_involved: true
summarized: 2026-06-12
---

# Thread Summary: Cron Auto-Heal + DPP Starvation Metric Validation

_Source: spaces/AAQAVOjYc80 thread `T5Y1BA-UTLw` · 24 messages · 2026-06-07 to 2026-06-11_
_Summarized: 2026-06-12 11:06 PT · last-msg-time: 2026-06-11T02:59:56Z_

## What was discussed

Two entangled topics. First (Jun 7): Denny asked how the bot could auto-detect and self-resolve issues like ot-shift-summary going missing for days without manual intervention — bot found the watchdog already existed and already fired, but lacked auto-resolution (only one-shot alert). Second (Jun 11): Denny corrected the bot ("why ask") for narrating DPP starvation validation plans instead of running them; bot ran ground-truth Scuba queries against S674219 and validated the correct metric spec.

## Key decisions made

- [2026-06-07T15:43Z] Cron auto-heal spec: when ot-cron-health-watch sees a cron-type job with stale `next_run` vs its schedule, auto-nudge `next_run` once (safe — nudging an overdue job ≠ killing one mid-flight); if still missing next audit, escalate-until-resolved with backoff; surface persistent stalls in morning human-attention-brief. (Not yet built.)
- [2026-06-11T02:57Z] DPP starvation metric locked: use `data_starvation_pct >95%` from `dpp.dpp_master` (dataset `dpp_stats_v2`), keyed by `model_entity_id`, gated on RUNNING + recent-window avg — NOT examples-read≈0 proxy. Gotcha: max `data_starvation_pct` sits ≥100 at baseline (idle jobs), so scan must use fleet p95 or per-job recent-window avg, not raw per-row comparison.

## Files / artifacts touched

| path | what changed |
|---|---|
| `ot-cron-health-watch` state | bot verified it had already fired "missing" alert for ot-shift-summary (Jun 5 21:41 PDT) |
| `scan-dpp-starvation.sh` | rewire PENDING — spec locked; held pending clean notes tree |

## Cluster / pattern references

- [CL-003] downstream-infra reliability (DPP/Scribe cascade) — S674219 ("75% regression in DPP OT ingress, EAG scribe drain") was the ground-truth validation target; `dpp_stats_v2` scribe-token-ingress confirmed −65% trough exactly matching the SEV 11:52→13:46 window.

## Followup items (not yet done)

1. Rewire `scan-dpp-starvation.sh` from examples-read≈0 proxy to `data_starvation_pct >95%` via per-job Scuba query grouped by `model_entity_id`; gate on RUNNING + recent-window avg. Spec: locked. Owner: bot. Status: blocked on clean notes tree.
2. Build cron auto-heal: nudge `next_run` for overdue cron-type missing jobs + escalate-until-resolved backoff. Spec: see Jun 7 decision above. Owner: bot. Status: proposed, not yet built.

## Cross-refs

- SEVs discussed: S674219
- Related threads: `dC5krNkcMXE` (DPP starvation per-job baseline follow-up)
