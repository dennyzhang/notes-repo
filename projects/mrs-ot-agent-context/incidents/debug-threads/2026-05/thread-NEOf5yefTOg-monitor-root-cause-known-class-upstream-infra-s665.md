# Thread Summary: Model 2130305043 Sparse Delta Latency — ZippyDB Causal Chain Falsified

_Source: spaces/AAQAVOjYc80 thread `NEOf5yefTOg` · 7 messages · 2026-05-19T02:49–02:55Z_
_Summarized: 2026-05-19 21:41 PT · last-msg-time: 2026-05-19T02:55:08Z_

## What was discussed

The ot-alert-monitor cron posted a triage for model 2130305043 (ig_reels_tab_cs_omni_retrieval STUS), classifying it as `UPSTREAM_INFRA (S665114 ZippyDB Flash ATG0)` with high confidence. Denny challenged this: the causal chain "ZippyDB Flash bandwidth → Scribe read proxy throughput → sparse delta latency" was an unverified inference. MyClaw investigated and falsified the claim: only model 2130305043 was alarming on `scribe_read_proxy.client_lag_in_seconds` (if S665114 were a shared upstream cause, other consumers would also be alarming); ZippyDB Flash and Scribe read proxy are different systems with no documented dependency; S665114's `impacted_services_linkage` is empty. Denny also corrected the directional terminology: from OT's perspective, ZippyDB/Scribe serving layer is *downstream* (OT publishes into it), not upstream. "Upstream" = PG/model/config side.

## Key decisions made

- [02:51:15Z] Root cause reclassified from `UPSTREAM_INFRA (high)` to `UNKNOWN (low confidence)`. The ZippyDB→Scribe chain is an unverified correlation, not causation.
- [02:53:17Z] Directional terminology corrected in prompt: Upstream = PG/model/config/Scribe-producers feeding into OT. Downstream = publish/predictor/ZippyDB/Scribe-consumers receiving OT output. Mislabeled instances in `ot-alert-monitor.md` + `failure-patterns.md` to be audited.
- [02:55:08Z] Three new learnings committed (L16–L18): L16 = correlation≠causation (run single-model-only falsifier), L17 = empty SEV impact fields = NULL evidence (mark "blast radius UNVERIFIED"), L18 = every evidence bullet must carry [VERIFIED] / [INFERRED] / [DERIVED-FROM] provenance label.
- [02:53:17Z] Alert URL format fixed: `alert_id=<numeric>` produces 404; must use full composite key URL-encoded (`%40%23%24` separator). Rule added to `ot-alert-monitor.md` + URL validator.
- [02:53:17Z] Model-ID ≠ alert-ID: never prefix a model ID with `A` to form an alert reference. Separate namespaces.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../learnings.md` | L16 (correlation falsifier), L17 (empty SEV fields = NULL), L18 (evidence provenance labels) |
| `~/notes/.../cron-jobs/ot-alert-monitor.md` | UPSTREAM/DOWNSTREAM directional definition; alert URL composite-key rule; evidence-provenance label rule |

## Cluster / pattern references

- [CL-003] — initially suspected (downstream-infra reliability, ZippyDB/Scribe cascade), but falsified by single-model-only impact

## Followup items (not yet done)

_(none explicitly committed — prompt edits noted as "landing now" but no explicit ack from Denny)_

## Cross-refs

- SEVs discussed: S665114
- Related threads: `-QYYCRmS75s` (5/18 tab updated in next thread to add this alert honestly)
