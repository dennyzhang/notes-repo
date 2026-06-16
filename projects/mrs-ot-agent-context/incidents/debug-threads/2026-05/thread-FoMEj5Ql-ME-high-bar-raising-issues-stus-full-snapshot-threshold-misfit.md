# Thread Summary: High Bar for Raising Issues — STUS FULL_SNAPSHOT False PAGE

_Source: spaces/AAQAVOjYc80 thread `FoMEj5Ql-ME` · 6 messages · 2026-05-17_
_Summarized: 2026-05-17 23:34 PT · last-msg-time: 2026-05-17T22:09:15Z_

## What was discussed

Operator noticed the bot had PAGEd qianh25 for model m2130305043 (ig_reels_tab_cs_omni_retrieval baseline, STUS v4) citing "FULL_SNAPSHOT not published since 2026-05-13." Operator checked MLHub UMM and found a fresh snapshot at 14:17 PT on 2026-05-17. Bot investigated and confirmed the model was healthy — deltas publishing every ~2 min — but the FULL_SNAPSHOT subtype specifically had a 4-day gap. For STUS retrieval models, FULL_SNAPSHOT cadence is intentionally rare/disabled; the detector was misconfigured for STUS class. Operator issued generic feedback: "hold a high bar when you raise issues to me — only show me problems that need my attention."

## Key decisions made

- (2026-05-17T22:02:10Z) Bot confirmed: FULL_SNAPSHOT stale is real, but model is demonstrably healthy (deltas fresh). Correct verdict was THRESHOLD_MISFIT, not REAL_OT_FAILURE. Right action: binary question to qianh25 ("is FULL_SNAPSHOT intentionally rare for this STUS model?"), not a PAGE.
- (2026-05-17T22:09:07Z) Operator policy: high bar for escalation — only surface problems that need operator attention RIGHT NOW.
- (2026-05-17T22:09:15Z) Bot added RULES.md § "High bar for raising issues" with a 4-level verdict table (PAGE / MONITOR / NO_ACTION / THRESHOLD_MISFIT) and anti-pattern list: detector noise misclassified as model issue, symptom-only diagnosis without falsifier, already-known recurrences, self-healing in progress, ambiguous-evidence diagnoses.
- R23 (SNAPSHOT-SUBTYPE DISAMBIGUATION) added to `ot-alert-monitor`: when `full_snapshot_publish_delay` fires on STUS-class model with other subtypes fresh → classify as THRESHOLD_MISFIT, not REAL_OT_FAILURE.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/.myclaw-ot-bot/RULES.md` | Added "High bar for raising issues" rule with verdict table + anti-patterns |
| sqlite daemon DB | `ot-alert-monitor` prompt updated with R23 |
| `~/notes/.../auto-learnings/failure-patterns.md` | [CL-008] updated with R23 (STUS subtype disambiguation) |

## Cluster / pattern references

- [CL-008] — STUS jobs mis-classified as trainer jobs; R23 adds STUS-subtype detector noise as a new subclass (FULL_SNAPSHOT rare-by-design for STUS retrieval models)

## Followup items (not yet done)

_(none explicitly — fix landed in-session; operator did not assign follow-up to themselves)_

## Cross-refs

- SEVs discussed: _(none — this was a OneDetection alert, not a SEV)_
- Related threads: `t6SQVo16dTY` (signal-only rule, same session), `JFxkiKmeibI` (act-don't-ask, same session)
