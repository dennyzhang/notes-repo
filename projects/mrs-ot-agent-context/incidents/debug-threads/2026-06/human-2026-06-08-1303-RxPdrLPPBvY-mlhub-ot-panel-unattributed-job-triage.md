# Thread Summary: MLHub Online-Training Panel Shows Unattributed Job for threads_feed_mtml

_Source: spaces/AAQAVOjYc80 thread `RxPdrLPPBvY` · 121 messages · 2026-06-08 13:03–2026-06-09 01:04 PT_
_Summarized: 2026-06-10 00:04 PT · last-msg-time: 2026-06-09T01:04:36Z_
_human_involved: true_

## What was discussed

Operator asked "which team or oncall could help" with no in-thread context. Bot disambiguated: it was about the mrs.ot Workplace post (1346326357462107) by jameyz — MLHub's Online-Training section for model 2123804366 (threads_feed_mtml) displayed `pni_mb4_fresh` (PENDING, owner=nobody, empty model_entity_id) instead of the real RUNNING OT job. Thread spanned: routing lookup → crispy report iteration → root-cause trace into GraphQL/Alacorn source code → diff D107935047 authored → terminology correction (operator: "it's not ghost job") → diff summary update → operator asked what improvements to make.

## Key decisions made

- **Root cause verified in code** (2026-06-08T21:43): `genMastJobFromAlacorn` in `TGraphQLEntAIModelSeriesFields.php` takes the newest Alacorn result keyed on `model_series_id` with no `model_entity_id` filter; the only guard is "name non-empty," which the named unattributed job passes
- **Terminology corrected** (2026-06-08T23:45, operator-led): "ghost OT job" was wrong — `pni_mb4_fresh` is a real PENDING job, just not attributed to this model (empty model_entity_id); diff title/summary/test-plan all updated
- **Confirmed via ground-truth GraphQL query**: `xfb_ai_model_series_by_model_id(id: 2123804366).latest_mast_job_from_alacorn → pni_mb4_fresh` (2026-06-08T23:46)
- **Known limitation disclosed**: fix filters on model_entity_id-match, not job-type; a newer non-OT job could surface if it's in the series Alacorn index; follow-on `online_training`-only filter recommended
- **Safe-path confirmed**: "just unregister it" via OT CLI would tear down the live job (CLI is keyed on model_entity_id, which the ghost lacks); cleanup requires TMS/registry deletion, not OT-unregister

## Files / artifacts touched

| path | what changed |
|---|---|
| `www/TGraphQLEntAIModelSeriesFields.php` (D107935047) | draft: filter `genMastJobFromAlacorn` to model_entity_id == page model; drops unattributed jobs |
| Pastes P2369293164, P2369534957, P2369339688 | detail pastes (successive corrections; P2369339688 is authoritative) |
| diff-subagent prompt (notes) | added check #5: verify full-behavior (not just happy path) + correct entity labels before filing |

## Cluster / pattern references

_(none confirmed in known-patterns.md — omitted)_

## Followup items (not yet done)

1. `mlhub_debugging_experience` review/land D107935047 — operator holds; needs cross-team review
2. Purge stale `pni_mb4_fresh` display-source record (not an OT-unregister) — jameyz / MVAI oncall
3. Add online_training-only job-type filter as follow-on hardening to D107935047

## Cross-refs

- Posts: 1346326357462107 (mrs.ot Workplace)
- Diff: D107935047
- Pastes: P2369534957 (authoritative), P2369339688
