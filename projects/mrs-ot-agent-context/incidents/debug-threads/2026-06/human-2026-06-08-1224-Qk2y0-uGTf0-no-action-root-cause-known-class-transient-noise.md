---
name: Qk2y0-uGTf0
human_involved: true
---

# Thread Summary: ig_reels_tab_mtml FULL_SNAPSHOT miss — transient verdict missing root deep fix

_Source: spaces/AAQAVOjYc80 thread `Qk2y0-uGTf0` · 17 messages · 2026-06-08 12:24–15:58 PDT_
_Summarized: 2026-06-08 22:05 PT · last-msg-time: 2026-06-08T22:58:56Z_

## What was discussed

Bot triaged a WARNING alert for `ig_reels_tab_mtml` model 2133008573 FULL_SNAPSHOT missing (~3.7h gap), classifying it TRANSIENT_NOISE / NO_ACTION ("post-restart bootstrap, self-resolves in ~2.5h"). Operator challenged the verdict (22:46 PDT): "Why there is no root deep fix in the next actions?" Bot traced back to its own `ot-alert-monitor` L80 rule — "WARNING = investigate DEEP, never fast-drop as TRANSIENT_NOISE" — which it had violated. The same stall pattern had already recurred on 2026-06-07, making the "transient" label doubly wrong.

## Key decisions made

- [2026-06-08T22:50 PDT] Added `triage-output-lint` **check #9**: a TRANSIENT/NO_ACTION verdict on a WARNING/staleness/recurring signal is blocked unless Next actions carries a root deep fix (durable prevention / leading-indicator / config diff / root-fix task / escalation). Verified wired into both `ot-sev-monitor` and `ot-alert-monitor`.
- [2026-06-08T22:51 PDT] Filed **T275031545** (owner=dennyzhang): RCA the recurring crash at triage time (before logs purge), add FS resume-from-checkpoint to kill the 2.5h gap, add leading-indicator example-age/QPS detector.
- [2026-06-08T22:58 PDT] Root structural answer to "how to avoid the class": proactive **prose→lint coverage audit** (currently ~233 MUST/NEVER rules, only 9 mechanically enforced). Every operator-caught shallow verdict must yield a new lint/hook + backtest fed through the validator-discrepancy harvest (distillation step 10).

## Files / artifacts touched

| path | what changed |
|---|---|
| `ot-alert-monitor.md` lint integration (L176-178) | check #9 wired in |

## Cluster / pattern references

_(no existing CL-NNN IDs found in known-patterns.md)_

## Followup items (not yet done)

1. T275031545 — RCA recurring attempt-crash for mvai-training-online-2133008573; add FS resume-from-checkpoint; add leading-indicator example-age/QPS detector. Owner: dennyzhang.
2. Proactive prose→lint coverage audit job — sweep all ~233 MUST/NEVER rules, convert deterministically-checkable ones to `triage-output-lint` checks, route judgment-only ones to the validator.

## Cross-refs

- SEVs discussed: none new
- Related threads: `8LLIVF1l7Yw` (facebook_reels_vdd_hstu precedent, motivated L80)
