# Thread Summary: MODEL-ID GUARD Wrong on SUM Alert + Suppressed Alert Miss Root Cause

_Source: spaces/AAQAVOjYc80 thread `rwtOo7CQVdI` · 7 messages · 2026-05-29T06:18–08:00 UTC_
_Summarized: 2026-05-29 13:46 PT · last-msg-time: 2026-05-29T08:00:30Z_

## What was discussed

Two intertwined issues: (1) bot applied MODEL-ID GUARD to alert 68426//91181 — a SUM/infrastructure alert with no model_id by design — and asked Denny for model context instead of investigating directly. Denny's one-word reply "Why you ask" triggered the correction. (2) Root cause of 4× missed alert: suppression_state=SUPPRESSED (until 2032) → no oncall.feed item generated → Query A blind for 19:06–22:37 PT. Query B (`monitoring.alert list --state-is=ACTIVE`) added as anti-regression. A separate alert (model 2121139435, chronos_secgrp_instagram_home_core_ranking, mvai_tgif_publisher non-retryable error) self-resolved 23:02–23:36 PT.

## Key decisions made

- MODEL-ID GUARD does NOT apply to SUM/infrastructure alerts — investigate the component directly; no model_id needed (2026-05-29T08:00Z)
- Query B is now mandatory in ot-alert-monitor to catch SUPPRESSED alerts that skip oncall.feed (retroactively added; confirmed catches ACTIVE alerts Query A misses)
- Alert 68426//91181 still ACTIVE MAJOR; related SEV S668828 (TGIF validation, andrewxmao) may be upstream — needs TGIF publisher log dig

## Files / artifacts touched

| path | what changed |
|---|---|
| ot-alert-monitor cron prompt | Query B added as anti-regression (monitoring.alert list --state-is=ACTIVE) |
| notes / sqlite | MODEL-ID GUARD SUM-exception gotcha codified |

## Cluster / pattern references

_(failure-patterns.md not found — omitting cluster refs)_

## Followup items (not yet done)

1. Dig TGIF publisher logs for alert 68426//91181 root cause; related to S668828 (andrewxmao, Day 2 In Progress)

## Cross-refs

- SEVs discussed: S668828 (TGIF model validation, cogwheel)
- Related threads: `3l_SghsIBZE` (UBN triage / pull alert page pattern)
