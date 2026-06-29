---
name: persist-critical-metrics-principle
description: Operator asks if shift metrics are persisted; bot builds shift-metrics-history.jsonl; operator generalizes to principle; §IV.15 added to autonomous-workflow cheatsheet
metadata:
  type: project
  thread_id: PCGQ2mAHtow
  human_involved: true
---

# Thread Summary: Persist Critical Metrics — Principle Origin

_Source: spaces/AAQAVOjYc80 thread `PCGQ2mAHtow` · 19 messages · 2026-06-16_
_Summarized: 2026-06-17 11:15 PT · last-msg-time: 2026-06-16T16:24:37Z_

## What was discussed

Operator asked (16:11:32): "Are these metrics tracked in files, so we can do a lookback and comparison later?" Bot verified: shift headline metrics (SEVs touched/open/closed, alerts, diffs, WP, bot-score) were computed fresh each Tuesday and only rendered into the per-week gdoc tab — no structured compare-friendly store existed. Bot built `state/shift-metrics-history.jsonl`, backfilled Jun 9-16 as first data point. Operator then directed generalization: "This shall be a generic learning — all critical metrics should be saved for future comparisons and study" + "Write it down in autonomous workflow cheatsheet."

## Key decisions made

- **shift-metrics-history.jsonl created** (16:14:33): per-week JSONL in notes `state/`, appended by `ot-shift-summary` on each Tuesday close-out, idempotent on `window_end`. Schema: sevs_touched/open/closed/open_sev_ids/alerts/alerts_crit/diffs_open/diffs_landed/wp_posts/bot_confirmed/bot_total/bot_autotagged/bot_discrepancies/outgoing_oncall/window.
- **§IV.15 written to cheatsheet** (16:22:42): "Persist every CRITICAL metric to a structured history, not just a rendered artifact" added to `cheatsheets/agents/autonomous-workflow-principles.md` §IV (Durability). Now a build-time check enforced before any cron is built or edited.
- **T276078640 filed** (16:23:11): sweep to apply §IV.15 across existing crons. Quick inventory: already persisted = shift-summary, fleet-health, triage_events, bot-volume. Render-only gaps = daily-brief counts, team-chat precision trend, knowledge-distillation metrics, ingest-cron counts, weekly clean-model rate.

## Files / artifacts touched

| path | what changed |
|---|---|
| ~/notes/.../state/shift-metrics-history.jsonl | created; Jun 9-16 row backfilled |
| ~/notes/.../cheatsheets/agents/autonomous-workflow-principles.md | §IV.15 added |

## Cluster / pattern references

(none — operational tooling improvement, not a failure pattern)

## Followup items (not yet done)

1. T276078640 — apply §IV.15 to remaining render-only crons; specifically weekly clean-model rate (north-star time series) (owner: dennyzhang)
2. Optional: move shift-metrics computation into a script for audit-grade counts (independent of rendered table) — on-request

## Cross-refs

- Related threads: `8ocbaJ_GjKI` (shift summary that triggered the question)
