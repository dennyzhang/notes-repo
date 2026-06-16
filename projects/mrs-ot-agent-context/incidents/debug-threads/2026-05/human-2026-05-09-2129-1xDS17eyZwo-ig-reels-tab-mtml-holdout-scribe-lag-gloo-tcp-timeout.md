---
human_involved: true
---

# Thread Summary: IG Reels Tab MTML holdout — scribe_read_proxy lag from Gloo TCP timeout

_Source: spaces/AAQAVOjYc80 thread `1xDS17eyZwo` · 3 messages · 2026-05-10T04:29–04:34 UTC_
_Summarized: 2026-06-02 17:43 PT · last-msg-time: 2026-05-10T04:34:13Z_

## What was discussed

Alert triage for model 2132766001 (ig_reels_tab_mtml holdout): `scribe_read_proxy.client_lag_in_seconds` fired. Bot determined that Gloo TCP transport timed out on attempt 1 (after 98h), creating a 22-min sparse delta gap that backed up Scribe consumer lag. Attempt 2 was RUNNING and healthy. Validator confirmed all ground-truth queries. Operator then directed a template update: triage outputs should include model metadata (architecture and importance level) at the top.

## Key decisions made

- (2026-05-10T04:29Z) Root cause: Gloo TCP timeout during in-train-loop publish killed attempt 1; 22-min delta gap caused scribe consumer lag backlog — alert expected to auto-clear as attempt 2 publishes normally.
- (2026-05-10T04:34Z) Triage template update required: every triage output must clarify model metadata at top — architecture (silvertorch, in-trainer, etc.) and importance (holdout, prod, QE, etc.).

## Files / artifacts touched

| path | what changed |
|---|---|
| triage output template (cron prompts) | Add model-metadata section at start of every triage |

## Cluster / pattern references

_(No confirmed CL-NNN IDs apply.)_

## Followup items (not yet done)

1. Update `ot-alert-monitor` and `ot-sev-monitor` cron prompts to include model-metadata (architecture + importance) at start of triage output.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `RmHQoswGPJs` (similar model / alert pattern for 2133008573)
