---
name: OoOeBUlbWsk
human_involved: true
thread_id: OoOeBUlbWsk
space: spaces/AAQAVOjYc80
msg_count: 9
date_range: 2026-05-09T04:29Z — 2026-05-09T05:34Z
---

# Thread Summary: ot-triage-summary Cron Design — Three Operator Corrections

_Source: spaces/AAQAVOjYc80 thread `OoOeBUlbWsk` · 9 messages · 2026-05-09T04:29Z–2026-05-09T05:34Z_
_Summarized: 2026-06-02 16:43 PT · last-msg-time: 2026-05-09T05:34Z_

## What was discussed

Operator asked for a daily cron that summarizes resolved OT issues (SEVs, alerts, posts) as individual local files. Bot created a diff and cron job. Three operator corrections followed: (1) bot skipped the diff cheatsheet during diff creation; (2) output directory was wrong (bot used `~/.myclaw-ot-team/...`, operator changed to `~/work/claude/projects/mrs-ml-training-reliability/triage-summaries/`); (3) initial triage summaries were too thin — operator showed example SEV-S659572 which had only a shell with no real content.

## Key decisions made

- (2026-05-09T04:39Z operator) Output path: `~/work/claude/projects/mrs-ml-training-reliability/triage-summaries/` (NOT the ~/.myclaw-ot-team path)
- (2026-05-09T04:39Z operator) Diff creation MUST run against diff cheatsheet — bot skipped it, this is a recurring failure mode
- (2026-05-09T05:23Z operator) Summaries need: GChat thread content, postmortem fields, linked diffs/tasks — NOT just a thin SEV metadata stub
- (2026-05-09T05:34Z bot sample) Richer format confirmed: metadata + postmortem prose + quoted GChat line + linked D/T numbers

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/work/claude/projects/mrs-ml-training-reliability/triage-summaries/` | target dir for resolved-issue per-file summaries |
| diff cheatsheet | should have been loaded; was NOT; gap flagged |

## Cluster / pattern references

_(No CL-NNN clusters — omitted)_

- Recurring failure: bot skipping diff cheatsheet under task focus pressure (also seen in D106859537)

## Followup items (not yet done)

1. Confirm diff for ot-triage-summary cron landed and output dir is correct (thread did not show final "diff merged" confirmation)
2. Enforce diff cheatsheet load as hook rather than prose rule — this correction recurred across multiple threads

## Cross-refs

- Referenced diff: D104497251 (triage summary cron)
- Example re-render: `~/work/claude/projects/mrs-ml-training-reliability/triage-summaries/2026-05/SEV-S661157-2026-05-08.md`
- CLAUDE.md §"Pre-Submit Lint": diff cheatsheet is mandatory before every jf submit
