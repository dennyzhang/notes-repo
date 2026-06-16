---
name: auto-2026-06-10-0616-eg8jsXMvdI0
description: notes→fbcode commit aborted for ot-human-attention-brief drift; bot diagnosed deprecated, added to KNOWN_RENAMED_AWAY in notes canonical
metadata:
  type: project
  human_involved: false
---

# Thread Summary: notes→fbcode commit ABORTED — ot-human-attention-brief trunk drift

_Source: spaces/AAQAVOjYc80 thread `eg8jsXMvdI0` · 7 messages · 2026-06-10 13:16–13:21 UTC_
_Summarized: 2026-06-10 23:06 PT · last-msg-time: 2026-06-10T13:21:05Z_

## What was discussed

The weekly notes→fbcode commit script aborted because `ot-human-attention-brief` appeared in fbcode trunk's MANIFEST.json but was missing from the notes MANIFEST — the drift detector's safe guard. Bot investigated: found the job IS deprecated (daily-brief absorbed it on 2026-06-09, per MANIFEST line 9: "absorbing the deprecated ot-human-attention-brief"), not a job entry in either MANIFEST (both = 42 jobs), last ran 06-09 08:05, 21KB .md file left behind. Added it to `KNOWN_RENAMED_AWAY` in the notes canonical `ot-notes-fbcode-commit.md`. Propagated to sqlite.

## Key decisions made

- [13:19 UTC] `ot-human-attention-brief` is deprecated → KNOWN_RENAMED_AWAY (not restore to MANIFEST). Confirmed by notes MANIFEST line 9 + zero sqlite job entries + last run 06-09.
- [13:19 UTC] Fix goes into notes canonical (`ot-notes-fbcode-commit.md`), not fbcode. Prior add had landed in a non-canonical copy that a mirror sync overwrote — that was the recurrence root.
- [13:21 UTC] No manual re-fire of the sync. The abort was non-data-loss; next tick (`15 */6`) handles it. (Per don't-fire-sync-diffs rule.)
- [13:21 UTC] Residual: 21KB `.md` + a stale purpose-string reference in `ot-triage-auditor` remain (harmless dead weight from incomplete deprecation). Flagged for cleanup.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/ot-notes-fbcode-commit.md` | Added `ot-human-attention-brief` to `KNOWN_RENAMED_AWAY` |
| sqlite `cron_jobs` | Prompt propagated (verified in same turn) |

## Cluster / pattern references

_(none — this is cron-infrastructure drift handling, not a failure cluster)_

## Followup items (not yet done)

1. Cleanup: remove `ot-human-attention-brief.md` (21KB) and the stale purpose-string reference in `ot-triage-auditor` (`...reads it for the morning rollup`). Harmless dead weight from incomplete deprecation.

## Cross-refs

- Diffs: D106716098 (referenced as motivation for the drift abort logic)
- Related threads: none
