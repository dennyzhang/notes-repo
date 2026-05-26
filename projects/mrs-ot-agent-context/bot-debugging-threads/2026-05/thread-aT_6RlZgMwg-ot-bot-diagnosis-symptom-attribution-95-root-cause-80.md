# Thread Summary: Model 883552231 Post-FS Alert Triage + Bot Triage Format Redesign

_Source: spaces/AAQAVOjYc80 thread `aT_6RlZgMwg` · 6 messages · 2026-05-16 04:25–10:10 PDT_
_Summarized: 2026-05-16 22:31 PT · last-msg-time: 2026-05-16T17:10:31.843158Z_

## What was discussed

Primary: Denny pasted a bot diagnosis for models 883552231 (facebook_reels_ifu_mtml_v0) — 2 CRITICAL alerts at 03:24 & 03:28 PDT for missing SPARSE/DENSE_DELTA. Bot verified all 5 FS cycles show a ~23–41 min post-FS delta pause; CRITICAL threshold is 30 min (3× cycle), so roughly half the cycles trip it — structural noise, not real incident. Trainer alive, pipeline self-healed.

Secondary: 5+ hours later, Denny gave two format feedbacks: (1) "Which delta is troublesome? Not clear from diagnosis." (2) "Not clear whether alert misconfiguration vs model performance issue." Bot redesigned both `ot-alert-monitor.md` and `ot-sev-monitor.md` triage templates to add a `Signal specifics` section (names SPARSE/DENSE/FULL_SNAPSHOT explicitly) and a `class` enum (`THRESHOLD_MISFIT` / `REAL_OT_FAILURE` / etc.) that answers both questions in the verdict header.

## Key decisions made

- (2026-05-16T11:25:52 Denny, diagnosis): Post-FS pause pattern verified across 5 consecutive FS cycles — CRITICAL threshold doesn't account for this model's natural cadence; classify as THRESHOLD_MISFIT, not real failure.
- (2026-05-16T17:10:19 Denny): "Act don't ask" — bot should not ask "Want me to?" when it has the answer. Single-file prompt edit → just do it.
- (2026-05-16T17:10:31 bot): Landed new `Signal specifics` section + `class` enum in both alert/sev triage cron prompts without further confirmation.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../cron-jobs/ot-alert-monitor.md` | Added `Signal specifics` section; `class` enum in verdict header; `signal_specifics.affected_snapshot_types` JSON field |
| `~/notes/.../cron-jobs/ot-sev-monitor.md` | Same template redesign applied |

## Cluster / pattern references

- [CL-005] — Delta publishing exposes uncharted failure modes; post-FS pause is a recurring variant
- [P01] — Post-FS delta pause pattern (recurring, codified); this thread is the primary case study
- [P44] — GIL hang; falsified by fresh mvai_metrics at 04:15 PDT

## Followup items (not yet done)

_(none — format fix landed in-thread; mega-learning cluster H was still pending at thread close)_

## Cross-refs

- SEVs discussed: S664024 (Mitigated, common pool), S665090 (In Progress, fbpkg, unrelated)
- Related threads: `JbRNzEK8Hx0` (878102693 cross-family confirmation), `DbIQXo1gSBQ` (ordering_bug, `act don't ask` extended)
