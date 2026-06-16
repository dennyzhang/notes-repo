---
name: eg8jsXMvdI0-notes-fbcode-commit-abort-known-renamed-away
description: Commit cron aborted on trunk-drift for ot-human-attention-brief; added to KNOWN_RENAMED_AWAY in notes canonical
metadata:
  type: project
  human_involved: false
---

# Thread Summary: Notes→fbcode commit abort — ot-human-attention-brief KNOWN_RENAMED_AWAY fix

_Source: spaces/AAQAVOjYc80 thread `eg8jsXMvdI0` · 7 messages · 2026-06-10 06:16–06:21 PT_
_Summarized: 2026-06-10 21:04 PT · last-msg-time: 2026-06-10T13:21Z_

## What was discussed

The `ot-notes-fbcode-commit` cron aborted because `ot-human-attention-brief` appeared in fbcode trunk's MANIFEST but was absent from notes — structural trunk-drift that would cause a silent drop (cf. D106716098). Bot verified with data: job is deprecated (daily-brief absorbed it 2026-06-09; notes MANIFEST line 9 states this explicitly), not in sqlite, last ran 06-09 08:05. The grep hits triggering the drift detector were non-entry mentions in other jobs' purpose strings, not a real entry. Fix: add to `KNOWN_RENAMED_AWAY` in notes canonical `ot-notes-fbcode-commit.md`, propagate to sqlite. Next scheduled commit (15 */6) will proceed without aborting.

## Key decisions made

- **Fix in notes canonical, not fbcode** (2026-06-10 06:19 PT): prior KNOWN_RENAMED_AWAY add went to a non-canonical copy that a mirror sync overwrote; this time fixed in notes ground-truth so it survives future syncs.
- **Don't manually re-fire the commit cron** (2026-06-10 06:21 PT): abort was non-data-loss; notes is canonical; next scheduled tick handles it safely.

## Files / artifacts touched

| path | what changed |
|---|---|
| ~/notes/.../cron-jobs/ot-notes-fbcode-commit.md | Added `ot-human-attention-brief` to KNOWN_RENAMED_AWAY |

## Cluster / pattern references

(no cluster — infrastructure/tooling)

## Followup items (not yet done)

1. Complete the 2026-06-09 deprecation: remove orphaned `ot-human-attention-brief.md` (21KB) and stale purpose-string reference in `ot-triage-auditor.md`. Low priority, harmless.

## Cross-refs

(none)
