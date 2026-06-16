---
human_involved: true
---

# Thread Summary: Knowledge-distillation cron design + diff cheatsheet compliance

_Source: spaces/AAQAVOjYc80 thread `6gf2-KK6ERY` · 4 messages · 2026-05-09T04:30–04:58 UTC_
_Summarized: 2026-06-02 17:43 PT · last-msg-time: 2026-05-09T04:58:07Z_

## What was discussed

Operator requested a new daily cron (`ot-knowledge-distillation`) that would parse issue summaries from the triage-summary cron, identify patterns, and create a Phabricator diff to improve the OT master agent. Operator then caught that the bot's diff creation during this work had skipped the diff cheatsheet — a recurring compliance gap. Operator also directed the bot to wire a memory entry for the closed-loop design and update the OT master gdoc.

## Key decisions made

- (2026-05-09T04:30Z) Create `ot-knowledge-distillation` cron — daily, a few hours after `ot-triage-summary`, parses summaries and proposes diffs.
- (2026-05-09T04:39Z) Always run diff cheatsheet before any `jf submit` — operator explicitly flagged a missed run, which became a standing rule.
- (2026-05-09T04:40Z) Wire memory entry for closed-loop design + update OT master gdoc with the design.
- (2026-05-09T04:58Z) Triage-summaries output path changed from `~/.myclaw-ot-team/spaces/AAQAVOjYc80/triage-summaries/` to `~/work/claude/projects/mrs-ml-training-reliability/triage-summaries/`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/.myclaw-ot-bot/` (cron config) | New cron `ot-knowledge-distillation` designed |
| `triage-summaries/` path | Redirected from `.myclaw-ot-team` to `work/claude/projects/mrs-ml-training-reliability` |

## Cluster / pattern references

_(No confirmed CL-NNN IDs apply.)_

## Followup items (not yet done)

_(None explicitly discussed in thread.)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `1lufURy61pM` (original thread motivating this cron per cron spec)
