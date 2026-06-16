---
name: d5S8rxlB2xw
type: thread-summary
human_involved: true
thread_id: d5S8rxlB2xw
space: spaces/AAQAVOjYc80
msg_count: 4
date_range: 2026-05-07 10:48–12:10 PDT
summarized: 2026-06-02 12:43 PDT
last_msg_time: 2026-05-07T19:10:18Z
---

# Thread Summary: Bot Behavior Corrections — Act Not Ask, Draft Diff Violation

_Source: spaces/AAQAVOjYc80 thread `d5S8rxlB2xw` · 4 messages · 2026-05-07 10:48–12:10 PDT_
_Summarized: 2026-06-02 12:43 PDT · last-msg-time: 2026-05-07T19:10:18Z_

## What was discussed

Thread consists entirely of operator corrections to bot behavior. Prior context (outside this thread) involved a diff being created. Operator corrections: (1) bot asked for permission to do something it should have done autonomously → "do it. why you ask?" (P-001: act don't ask); (2) operator asked bot to attack and improve the diff; (3) bot published a diff directly instead of as `--draft` → operator invoked the diff cheatsheet rule explicitly; (4) operator asked bot to add future prevention mechanisms. No triage content in this thread — it is exclusively a behavior-quality feedback thread.

## Key decisions made

- **P-001 violation confirmed (2026-05-07T17:48:55Z):** Bot asked before acting on a reversible, in-scope task — operator's frustration signal ("do it. why you ask?") is unambiguous.
- **Draft-diff rule violated (2026-05-07T19:07:57Z):** Bot published diff directly. Cheatsheet mandates `--draft` always. No exceptions cited by operator.
- **Future prevention required (2026-05-07T19:10:18Z):** Operator explicitly asked for systemic fix, not just one-off correction.

## Files / artifacts touched

| path | what changed |
|---|---|
| (unknown — prior context not in thread) | A diff was created and published directly |

## Cluster / pattern references

_(Omitted — CL-NNN not verified against failure-patterns.md)_

## Followup items (not yet done)

1. Add systemic prevention for direct diff publish (hook or pre-submit gate) — operator asked explicitly

## Cross-refs

- Relevant rules: P-001 (act don't ask), diff cheatsheet `~/notes/users/dennyzhang/cheatsheets/diff/common.md`
