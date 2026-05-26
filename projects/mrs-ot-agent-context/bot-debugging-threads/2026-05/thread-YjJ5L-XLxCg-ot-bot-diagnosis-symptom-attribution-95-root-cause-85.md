# Thread Summary: DETECTOR_BROKEN Alert Class (Model 2126189932) + "Say Go" Anti-Pattern Callout

_Source: spaces/AAQAVOjYc80 thread `YjJ5L-XLxCg` · 7 messages · 2026-05-16 05:21–10:12 PDT_
_Summarized: 2026-05-16 22:31 PT · last-msg-time: 2026-05-16T17:12:56.200303Z_

## What was discussed

Denny pasted a bot diagnosis for an `[Invalid Detector - No Data]` alert on model 2126189932 (ig_reels_starsearch_t2i_retrieval baseline, owner: yjfu, oncall: igr_retrieval, role: STUS). The detector had no observations for the "e2e latency sparse delta" metric — pipeline was healthy (SPARSE_DELTA every ~2 min, MAST RUNNING v4). This is a `DETECTOR_BROKEN` class false positive: distinct from `THRESHOLD_MISFIT` (cluster A on same shift) because the detector data source is missing/disconnected, not the threshold misconfigured. Validator confirmed fresh deltas at 05:19 PDT.

5+ hours later, Denny flagged the "Say go and I'll write it" pattern twice as an anti-pattern. Bot composed a calibration rule: for single-file prompt edits in bot-owned cron files that are reversible and have a clear spec, execute without asking. Ask only for multi-cron contract changes, external system edits, or genuinely ambiguous direction.

## Key decisions made

- (2026-05-16T12:21:58 bot): DETECTOR_BROKEN = distinct class from THRESHOLD_MISFIT. Fix target differs: detector data-source owner (yjfu) vs centralized alert-rule team.
- (2026-05-16T17:06:01 Denny): "Why do you need my involvement when you have the answer?" — explicit escalation of "act don't ask" rule to cover mega-learning drafts and prompt edits.
- (2026-05-16T17:06:15 bot): Calibration locked: "single-file edit, clear spec, reversible → just do it." Applied retroactively to thread `6pKeH_XqjcE` format-fix.
- (2026-05-16T17:12:56 Denny): "How to avoid this in the future?" — mechanical pre-send check prescribed: scan final sentences for "Want me to / Say go / Confirm before I / Ready to execute?" and delete if operator already directed action.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/fbsource/fbcode/.../RULES.md` (local) | "Act don't ask" calibration rule documented (per bot acknowledgment) |

## Cluster / pattern references

- [CL-008] — STUS jobs mis-classified as trainer jobs; model 2126189932 is STUS role — confirmed correct via entrypoint `st_update_service_v2.py`, detector gap is separate from classification
- [R14] — STUS classification rule; correctly identified role in this triage

## Followup items (not yet done)

1. yjfu / igr_retrieval: audit OneDetection detector config for model 2126189932 "e2e latency sparse delta" data source — disconnected or never configured

## Cross-refs

- Related threads: `aT_6RlZgMwg` (THRESHOLD_MISFIT class, same shift), `aZ0g0BQ1XNo` (transient scribe class, same shift), `DbIQXo1gSBQ` ("act don't ask" first raised)
