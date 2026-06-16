---
thread_id: 3yt3GJLcH_k
human_involved: true
space: spaces/AAQAVOjYc80
msg_count: 45
first_msg_time: 2026-06-09T16:24:44Z
last_msg_time: 2026-06-09T16:54:18Z
---

# Thread Summary: Shift-Summary GDoc — Oncall Name Error + Local Notes Wipe

_Source: spaces/AAQAVOjYc80 thread `3yt3GJLcH_k` · 45 messages · 2026-06-09_
_Summarized: 2026-06-09 22:04 PT · last-msg-time: 2026-06-09T16:54:18Z_

## What was discussed

Operator left comments on the OT oncall shift summary gdoc. Four unresolved comments initially: (1) wrong incoming oncall name (Paul Lu vs Li Lu), (2) alert noise description too vague, (3) verbose hand-off section, (4) date/time granularity in timeline. Bot fixed the oncall name via `meta oncall.rotation schedule --upcoming` ground-truth query (confirmed Li Lu = llu6, incoming since 06-09 11:00). During the session, gdocs CLI stdin hang was discovered and fixed with `< /dev/null` redirect. Operator then added 3 more comments mid-session including a serious one: the cron had wiped the "Local Notes (Bot -- don't touch it)" section that the operator maintains, replacing it with a template placeholder. Recovery was attempted (revisions API returned empty) but the notes were unrecoverable via tooling.

Root cause analysis: RULE 72 and RULE 80 (preserve Local Notes verbatim) already existed in the cron prompt with anti-regression notes from prior wipes — the failure was a **runtime compliance failure**, not a missing rule. Full-body `gdocs replace` overwrites human-maintained sections despite the prose rules.

## Key decisions made

- [2026-06-09T16:27] Ground-truth oncall query: `meta oncall.rotation schedule` with `-r` (rotation) not `--name`; use `--upcoming` for incoming, not current.
- [2026-06-09T16:35] Operator question "why you made this mistake? how to avoid it?" → cron's §2 was using "current oncall = incoming" heuristic instead of querying the schedule.
- [2026-06-09T16:45] Root-fix: cron now runs `meta oncall.rotation schedule --upcoming` to get actual incoming oncall.
- [2026-06-09T16:50] Key discovery: Local Notes wipe is a **prose-rule compliance failure** — RULE 72/RULE 80 already prohibited it. Lesson: prose rules with prior anti-regression notes still don't reliably fire when the cron template does a full-body replace.
- [2026-06-09T16:53] Three new rendering rules added to cron: date-only in timeline (no hh:mm), verbose hand-off format, post-push verification guard for Local Notes.

## Files / artifacts touched

| path | what changed |
|---|---|
| Shift-summary gdoc (tab June-09 shift) | Line 2 corrected: "Incoming → Li Lu"; alert-noise wording concretized |
| `ot-shift-summary` cron prompt (sqlite) | §2 oncall logic fixed to query `--upcoming`; RULE 72/80 context strengthened; 3 rendering rules added |

## Cluster / pattern references

_(no verified CL-NNN in failure-patterns.md at time of summary)_

## Followup items (not yet done)

1. Operator's Local Notes content is unrecoverable via tooling (revisions API returned empty). Operator must restore manually.
2. GDoc comment replies were attempted but could not be verified (gdocs comments-list readback consistently empty in this session; verify separately).

## Cross-refs

- Related patterns: shift-summary Local Notes wipe recurrence (prior instances noted in RULE 80 anti-regression comment)
