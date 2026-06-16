# Thread Summary: gdoc Context Sync Cron Design + D106716098 Stale-Notes-Overwrites-Trunk Bug

_Source: spaces/AAQAVOjYc80 thread `LlBe4tLd2zY` · 38 messages · 2026-05-28–2026-05-29_
_Summarized: 2026-05-29 07:45 PT · last-msg-time: 2026-05-29T03:24:05Z_

## What was discussed

Denny approved a plan for `ot-gdoc-context-sync` cron: pull OT Reliability Meeting Notes + Cross-Team Follow-ups gdocs daily into `mrs-ot-agent-context/references/gdocs/`, make them available to every OT agent bootstrap. Bot filed Task T273336204 and draft diff D106716098. Multiple review rounds revealed a critical bug: stale `notes/MANIFEST.json` + `notes/team_bot/CLAUDE.md` were mirrored to fbcode, silently removing 4 active crons (`ot-triage-auditor`, `ot-postmortem-validator`, `ot-human-attention-brief`, `ot-prompt-change-validator`) and 2 CLAUDE.md sections ("Agent-design principles" and "Conditional Cheatsheet Loading"). Bot fixed MANIFEST.json and CLAUDE.md across multiple amendments but also missed running the diff cheatsheet — so V0.4 still had empty test plan, wrong task (T273336204 vs required T259215482), and missing `mrs-ot-reliability` reviewer. V0.5 fixed all.

## Key decisions made

- (2026-05-28T22:13:23Z) Denny: destination = `mrs-ot-agent-context/references/gdocs/` (context corpus, not src/team_bot).
- (2026-05-29T02:45:04Z) Bot confirmed: stale-notes overwrite bug — MANIFEST.json + CLAUDE.md generated from notes copy, which was stale vs fbcode trunk.
- (2026-05-29T03:13:02Z) Denny: "why didn't you run diff cheatsheet against D106716098?" — cheatsheet + conventions check mandatory on every `jf submit`, including re-amendments.
- (2026-05-29T03:20:24Z) Denny: lesson must be saved in the cheatsheet.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/references/gdocs/README.md` + `sources.json` | created (staged in notes, pending notes-commit) |
| `mrs-ot-agent-src/cron-jobs/ot-gdoc-context-sync.md` | new cron prompt |
| `team_bot/CLAUDE.md` (fbcode) | gdoc index entry + 2 restored sections |
| `team_bot/MANIFEST.json` (fbcode) | `ot-gdoc-context-sync` block added, 0 active crons removed |
| D106716098 | draft diff (V0.5); awaiting Denny review |
| `memory/gotcha_notes-to-fbcode-mirror-stale-notes-overwrite.md` | filed (durable memory) |
| `memory/feedback_diff-cheatsheet-mandatory-every-amend.md` | filed (durable memory) |

## Cluster / pattern references

_(omitted — failure-patterns.md not present)_

## Followup items (not yet done)

1. D106716098 awaiting Denny sign-off — after approval: notes commit + sqlite push + cron registration. Owner: bot + Denny, status: pending review.
2. Learning from this session saved in diff cheatsheet (2026-05-29T03:24Z). Owner: Denny verified, status: done.

## Cross-refs

- SEVs discussed: none
- Diffs: D106716098, D106735261
- Tasks: T273336204, T259215482
- Related threads: `AOQM8O19bHE`, `81U0lzuCXss`
