# 2026-06-14 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `ot-ingest-gchat` cron. Source: 1 human message (delta since 2026-06-13) in **MVAI OT Dev** (8 members; primary contributor: Li Lu)._

_Window: 7d (2026-06-07 → 2026-06-14). Delta since last run: 2026-06-12T23:13:26Z → 2026-06-13T17:36:14Z. Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

**Alert noise taxonomy: 3 false-positive paging patterns identified (Li Lu, 2026-06-13)**

Li Lu flagged that at least 2 "critical alerts" (pager-level) this week were NOT infra/reliability failures — they were model owner configuration mistakes. The bot currently lacks sub-classifications for these patterns and would mis-triage them as real OT failures.

**Pattern A — LSR + allow_concurrent_delta_during_full_publish=False + tight SPARSE_DELTA SLO**
- Root: when `allow_concurrent_delta_during_full_publish=False`, the full snapshot publish suppresses (swallows) 3–4 delta publish attempts (sparse interval 10min × duration). A model with this setting CANNOT achieve "8 SPARSE_DELTA per 100 minutes" reliably — the SLO target is structurally unreachable.
- Classification: model-registry config mismatch, not infra failure. Owner action: either flip `allow_concurrent_delta_during_full_publish=True` or widen the SLO goal.
- Dashboard: https://fburl.com/monitoring/a9p29le4

**Pattern B — New model launched without updating baseline model in registry**
- Root: PG launches a new model but the model registry still points to the old baseline. Alerts fire against the new model's lineage before the registry diff lands.
- Classification: model owner ops gap, not infra failure. Fix: PG must land model registry diff before launch or as part of the launch runbook.
- Dashboard: https://fburl.com/monitoring/26v59bl4

**Pattern C — Upstream model inheriting SLO settings from root model**
- Root: an upstream model auto-inherits the root model's publishing SLO settings (including tight SPARSE_DELTA goals) even though those SLOs don't apply to the upstream's publishing cadence.
- Classification: SLO inheritance misconfiguration, not infra failure. Fix: upstream model registry entries must explicitly override inherited SLO fields that don't apply.
- Dashboard: https://fburl.com/monitoring/26v59bl4

**Integration ask:** bot's triage classifier should probe for these 3 patterns BEFORE escalating a SPARSE_DELTA or publish SLO alert to pager level. If `allow_concurrent_delta_during_full_publish=False` is set on a model with a tight SPARSE_DELTA alert, auto-classify as Pattern A and route to model owner, not oncall.

## P1 — significant nuance / sub-mechanisms

- Li Lu is proposing a team brainstorm to systematically catalog all known alert-noise sources, then drive model owners to fix configuration mismatches. Intent: work with PGs to reduce false-positive paging, not just suppress alerts.
- Scope: two confirmed pager-level false positives this week alone. Signal that these are chronic, not one-off.

## P2 — references / good-to-know

- SPARSE_DELTA monitoring dashboard: https://fburl.com/monitoring/a9p29le4
- Baseline model / upstream SLO dashboard: https://fburl.com/monitoring/26v59bl4

## Cross-references

None in this message.

## Open coordination threads

- Li Lu proposed scheduling a brainstorm session (next week from 2026-06-13) to enumerate all alert-noise sources. No resolution yet — operator should confirm timing with Li Lu and Paul Lu.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Recognize Pattern A (LSR + concurrent=False + tight SLO) as config-mismatch, not infra failure | `ot-alert-monitor`: add probe for `allow_concurrent_delta_during_full_publish` in SPARSE_DELTA alert triage | 1h |
| P0 | Recognize Pattern B (new model without baseline registry update) as owner ops gap | `ot-alert-monitor`: check if model was recently launched; if model registry diff is pending, route to owner not oncall | 1h |
| P0 | Recognize Pattern C (upstream inheriting root SLO) as SLO inheritance misconfiguration | `known-patterns.md`: add CL entry for inherited SLO false-positive; triage gate checks model registry inheritance chain | 2h |
| P1 | Contribute to Li Lu's alert-noise catalog | Operator-driven: gather patterns into a shared doc; bot should eventually consume the catalog as a lookup table | team session |
