# Thread Summary: Triage Result Format Redesign

_Source: spaces/AAQAVOjYc80 thread `6pKeH_XqjcE` · 9 messages · 2026-05-16T16:23–17:17 UTC_
_Summarized: 2026-05-16 23:33 PT · last-msg-time: 2026-05-16T17:17:02Z_

## What was discussed

Denny reviewed a triage output for S665114 (ZippyDB outage) and identified two core problems: critical info was buried, and there was no root-cause classifier. The thread evolved into a full format overhaul: structured verdict header, class enum, confidence rubric, and machine-parseable JSON block.

## Key decisions made

- **Verdict header on line 1** (2026-05-16T16:56:58Z): action + root-cause status + class + confidence + auto-resolved flag. Eliminates burial of the key answer.
- **Class enum locked** (2026-05-16T17:03:21Z): 10 values incl. THRESHOLD_MISFIT, UPSTREAM_INFRA, REAL_OT_FAILURE, OUT_OF_SCOPE, CONVEYOR_CODE_REGRESSION, CONVEYOR_INFRA_FAILURE.
- **`falsified` → `ruled out`** (2026-05-16T17:02:47Z — Denny's explicit feedback): plain English beats Popperian jargon.
- **`model_type` added to JSON block** (2026-05-16T17:02:47Z): enables cluster queries like "all retrieval_stus failures last week" without LLM parsing.
- **Fixed 8-section template** (2026-05-16T17:03:21Z): sections must appear in fixed order; empty sections emit `(none)` rather than skip.
- **Inline validator status** (same): no more 30s-delayed separate "✓ confirmed" message; placeholder `⏳ pending` in main message, edited in-place.
- **ot-post-monitor format also needs update** (2026-05-16T17:17:02Z — Denny raised): not just ot-alert-monitor + ot-sev-monitor.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/ot-alert-monitor.md` | Locked verdict-header + JSON-block format |
| `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/ot-sev-monitor.md` | Same template applied |
| `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/ot-post-monitor.md` | Same template applied |

## Cluster / pattern references

- [CL-003] — The triggering triage (S665114 ZippyDB) was a UPSTREAM_INFRA incident; this thread produced the format that routes CL-003 events correctly.

## Followup items (not yet done)

1. `model_type` derivation: Denny noted (2026-05-16T17:16:34Z) correct value is `facebook_reels_ifu_mtml_v0`, not `ranking_trainer`; entrypoint-based derivation needs refinement.

## Cross-refs

- SEVs discussed: S665114, S665066
- Related threads: `djeMtzxvfbU` (state-file migration), `1cVsOXXSa34` (cron health + push discipline that verified format in prod)
