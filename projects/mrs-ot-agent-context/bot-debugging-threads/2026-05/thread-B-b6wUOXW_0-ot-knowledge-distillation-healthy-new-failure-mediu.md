# Thread Summary: ot-knowledge-distillation Blocked by Dirty fbcode Working Tree

_Source: spaces/AAQAVOjYc80 thread `B-b6wUOXW_0` · 4 messages · 2026-05-21 00:44–02:30 UTC_
_Summarized: 2026-05-24 16:51 PT · last-msg-time: 2026-05-21T02:30:50Z_

## What was discussed

An alert fired: `ot-knowledge-distillation` was in `new_failure` (2nd consecutive day). Root cause: fbcode working tree had 6 uncommitted modifications (MANIFEST.json + 5 cron prompt files, mtime 2026-05-18/19). Both `ot-notes-fbcode-sync` and `ot-knowledge-distillation` were blocked on the same dirty-tree blocker. Bot diagnosed the 6 modifications as legitimate notes→fbcode sync updates that stalled before committing, not WIP to discard. Thread ended with Denny asking "What blocks by me" — no bot reply.

## Key decisions made

- **2026-05-21T00:44Z** — Bot diagnosed blocker: 6 modified files in fbcode working tree, all coherent sync updates. Proposed option B (inspect `ot-shift-summary.md` +129 lines before committing) vs option A (just commit). Denny's last message at 02:30 UTC asked "What blocks by me" — this was not answered.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none in this thread) | Analysis only; no writes |

## Cluster / pattern references

_(no cluster IDs applicable — this is a bot-infra failure, not an OT training failure)_

## Followup items (not yet done)

1. Denny asked "What blocks by me" at 2026-05-21T02:30Z — bot never responded. The blocker was: inspect `ot-shift-summary.md` (+129 lines) and `ot-cron-health-watch.md` (+28 lines), then commit with `sl commit -m "[OT bot sync] notes->fbcode 2026-W21 (resume from stall)"` + `sl push --to master`.

## Cross-refs

- SEVs discussed: none
- Related threads: bot-debugging-threads containing `ot-notes-fbcode-sync` and `ot-knowledge-distillation` failure tracking
