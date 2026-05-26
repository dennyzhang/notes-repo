# Thread Summary: notes-to-fbcode-sync.sh Hardcoded Path Fix

_Source: spaces/AAQAVOjYc80 thread `cnWycC5_BKo` · 4 messages · 2026-05-15 22:38 PT → 2026-05-15 23:12 PT_
_Summarized: 2026-05-16 21:32 PT · last-msg-time: 2026-05-16T06:12:49Z_

## What was discussed

Operator instructed bot to debug and fix the notes-to-fbcode-sync.sh script which was failing to locate the notes source directory. Root cause was a stale hardcoded path left over from a directory rename earlier in the day.

## Key decisions made

- **2026-05-16T05:38Z** — Root cause identified: `notes-to-fbcode-sync.sh` line 22 had `NOTES_SRC=$HOME/notes/users/dennyzhang/mrs-ot-agent` but directory was renamed to `$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/`. Same class as `.myclaw-ot-team` rename casualties earlier.
- **2026-05-16T06:12Z** — Fix applied: one-line edit to `NOTES_SRC`, then committed dirty fbcode tree (21 modified + 2 untracked files) as `da26e45e5557` covering the day's edits. Script ran clean end-to-end with follow-up auto-sync commit `c31e22498407`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes-to-fbcode-sync.sh` | `NOTES_SRC` updated to correct `projects/mrs-ot-agent-src` path |
| fbcode `pe_mrs_ml/mrs_ot_agent/team_bot/` | Committed 21 modified + 2 untracked files (catch-up commit `da26e45e5557`) |

## Cluster / pattern references

_(No clusters directly applicable. Path-drift after directory renames is a recurring operational footgun documented in RULES.md.)_

## Followup items (not yet done)

_(None — fix was complete and verified in this thread.)_

## Cross-refs

- Related threads: none
- Pattern: rename-discipline rule in RULES.md § "Rename / move discipline"
