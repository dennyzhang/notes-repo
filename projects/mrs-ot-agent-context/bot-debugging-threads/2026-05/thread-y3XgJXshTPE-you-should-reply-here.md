# Thread Summary: Triage Reply Discipline + NaN Cascade Miss (Model 878858380)

_Source: spaces/AAQAVOjYc80 thread `y3XgJXshTPE` · 13 messages · 2026-05-22_
_Summarized: 2026-05-23 05:50 UTC · last-msg-time: 2026-05-22T06:34:55Z_

## What was discussed

Denny identified two compounding failures in bot behavior. (1) Bot had been posting triage results to the top-level space instead of replying within the originating alert thread, causing noise. (2) More critically: bot's triage of model 878858380 (facebook_cfr_main_mtml holdout) anchored on attempt-0 `Async publish process creation failed!` while missing a 3-version NaN cascade (v146 validation-loss NaN + v147/v148 Shampoo NaN) that actually caused ~6h 40m of the 11.5h total snapshot gap. Denny then asked for context to be stored for future reference, and concluded cheatsheets for issue-report / triage-trail / escalation belong in generic oncall cheatsheets, not the OT-specific reference folder.

## Key decisions made

- **2026-05-22T05:38:51Z** Bot: Future alert/SEV triages → reply in originating alert thread, not top-level.
- **2026-05-22T05:50:37Z** Bot corrected: real cause was multi-version CL-017-class NaN cascade (v146→v148 Shampoo NaN), not attempt-0 publish failure. Two cfr_main_mtml models (baseline 2134801434 + holdout 878858380) hit Shampoo NaN same day — family-wide event.
- **2026-05-22T05:56:17Z** Denny: Create issue report — "1/ a crispy summary 2/ a paste with details."
- **2026-05-22T06:14:04Z** Bot: Stored in 3 layers — incident archive, IMPROVEMENT-PROPOSALS.md H1-H8 batch, paste P2347269408.
- **2026-05-22T06:34:55Z** Denny: Cheatsheets (issue-report, triage-trail, escalation) should be generic and live in `cheatsheets/` not in OT agent reference folder. Cleanup needed.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-context/incidents/resolved-alerts/2026-05/ALERT-913270201550407-2026-05-21.md` | Created (incident archive) |
| `~/notes/.../mrs-ot-agent-context/IMPROVEMENT-PROPOSALS.md` | Added Batch 2026-05-21 (H1–H8) |

## Cluster / pattern references

- No verified cluster ID for Shampoo NaN cascade — CL-017 referenced in conversation but not present in CLUSTERS.md. Omitting per quality rules.

## Followup items (not yet done)

_(none explicitly committed in this thread — cheatsheet creation was picked up in thread lfDi7-bdqig)_

## Cross-refs

- SEVs discussed: S667071 (Scribe IFR, upstream contributor to attempt-0 failure)
- Tasks: T272497510, T272497752
- Diffs: D106049931 (proposal)
- Pastes: P2347269408
- Related threads: `SI-eCb6Dq44` (878858380 duplicate-alert + hold-down bug), `lfDi7-bdqig` (cheatsheet execution)
