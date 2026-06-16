---
name: 5sjmmA3MtQo-ot-sev-postmortem-cron-genesis
description: Denny proposes and drives creation of ot-sev-postmortem cron; multiple correction rounds before implementation
metadata:
  type: thread_summary
  human_involved: true
---

# Thread Summary: ot-sev-postmortem cron — feature design and implementation

_Source: spaces/AAQAVOjYc80 thread `5sjmmA3MtQo` · 26 messages · 2026-05-04 to 2026-05-05_
_Summarized: 2026-06-02 08:43 PT · last-msg-time: 2026-05-05T04:07:30Z_

## What was discussed

Denny proposed a new automation to learn from OT SEV gchat threads: whenever an OT SEV closes, an LLM should read the SEV's GChat thread and generate a 4-element summary (symptom & impact, recovery metric, root cause, mitigation). He initially proposed output to `fbcode/pe_mrs_ml/mrs_ot_agent/journals/`. The thread was long and frustrating — the bot encountered task dependency issues, timed out, couldn't complete actions, and repeatedly needed Denny's nudges ("why can't you do it?", "where we are with this ask?"). Denny ultimately simplified the ask to "new cron ot-sev-postmortem, check this thread, suggest solution" and the implementation path emerged. Key constraints added: daily at 9pm, all outputs survive devserver reinstall (put under Claude folder / fbcode), cron timeout increase beyond 30 min, all cron jobs tracked in OT master agent of fbcode.

## Key decisions made

- [2026-05-04T20:56:41Z] Output goes to `fbcode/pe_mrs_ml/mrs_ot_agent/journals/` (operator choice over other paths).
- [2026-05-05T03:27:59Z] Cron runs daily at 9pm PT.
- [2026-05-05T01:23:53Z] All outputs must survive devserver reinstall — stored under fbcode / Claude folder, not local-only sqlite.
- [2026-05-05T04:06:54Z] Default 30-min cron timeout is too short; increase it. Change must be persistent in Claude Code config.
- [2026-05-05T04:07:30Z] All cron jobs in this MyClaw instance should be tracked in the OT master agent of fbcode (not just locally).

## Files / artifacts touched

| path | what changed |
|---|---|
| fbcode/pe_mrs_ml/mrs_ot_agent/journals/ | output destination for SEV postmortem summaries |
| fbcode/pe_mrs_ml/mrs_ot_agent/ (cron manifest) | ot-sev-postmortem cron added |
| Claude Code config (cron timeout setting) | timeout increased, devserver-reinstall-safe |

## Cluster / pattern references

_(omitted — cluster IDs not verified against failure-patterns.md)_

## Followup items (not yet done)

_(none explicit at thread end — implementation was in progress)_

## Cross-refs

- Related threads: `1lufURy61pM` (thread-summarizer cron genesis, same devserver-reinstall-survival theme)
