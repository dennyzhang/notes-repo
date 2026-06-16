# Thread Summary: Notes→fbcode Sync Self-Healing / Notes-as-SoT Enforcement

_Source: spaces/AAQAVOjYc80 thread `q-ZstjwGxlY` · 13 messages · 2026-05-28_
_Summarized: 2026-05-29 01:45 PT · last-msg-time: 2026-05-28T19:23:46Z_

## What was discussed

Denny directed the bot to "read the changes and make your own decisions" rather than asking, and reinforced "notes repo is the ground truth" + "maintain the sync pipeline health with minimal involvement from me." The bot had left the fbcode working copy dirty (uncommitted edits identical to notes). Per notes-is-SoT, the bot diffed both copies (identical), reverted the fbcode uncommitted edit, unblocked the sync cron, and confirmed auto-recovery logic for the dirty-and-identical case.

## Key decisions made

- [2026-05-28T19:19:08Z] Principle re-affirmed: notes repo = SoT; fbcode working copy never gets hand-edits — revert if dirty-and-identical.
- [2026-05-28T19:23:46Z] Sync cron extended to handle three cases: clean (pass), dirty-and-identical (revert + continue), divergent (escalate). Sqlite synced and script verified.

## Files / artifacts touched

| path | what changed |
|---|---|
| notes sync cron prompt (sqlite + notes) | added auto-recovery for dirty-and-identical fbcode state |

## Cluster / pattern references

_(none — failure-patterns.md not consulted; no confirmed cluster IDs)_

## Followup items (not yet done)

_(none — 3 incidental issues flagged by bot: `sl push --to user/dennyzhang` broken 5 days, heartbeat parallel-write at 12:22 PT, other crons leaving working-tree state; no explicit owner or deadline assigned)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none
