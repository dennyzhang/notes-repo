---
name: notes-canonical-fbcode-mirror-decision
human_involved: true
thread_id: BRcxJ7gSLzA
space: spaces/AAQAVOjYc80
first_msg: 2026-06-02T19:28:47Z
last_msg: 2026-06-02T19:46:15Z
messages: 28
summarized: 2026-06-03 00:43 PT
---

# Thread Summary: Notes = Ground Truth, fbcode = Mirror (Canonical Decision)

_Source: spaces/AAQAVOjYc80 thread `BRcxJ7gSLzA` · 28 messages · 2026-06-02 12:28–12:46 PT_
_Summarized: 2026-06-03 00:43 PT · last-msg-time: 2026-06-02T19:46Z_

## What was discussed

The bot had been editing fbcode `team_bot/CLAUDE.md` during a session while the canonical instruction in notes said "notes is canonical." This created three-way drift between `~/.myclaw-ot-bot/CLAUDE.md`, fbcode, and notes. The bot surfaced the contradiction and asked Denny which is ground truth. Denny decided: **notes = ground truth, fbcode = mirror**. The bot then executed the full reconciliation: union-merged both sides' real content into notes, fixed the sync-cron direction narration bug, mirrored notes→fbcode, and refreshed the local copy.

## Key decisions made

- **Notes = ground truth; fbcode = mirror** (2026-06-02T19:34, operator: "Notes should be ground truth. Fbcode should be a mirror"): the "edit fbcode" instruction in CLAUDE.md was flipped; notes CLAUDE.md now states "GROUND TRUTH = notes; fbcode = mirror; edit notes, never hand-edit fbcode."
- **Union merge completed** (2026-06-02T19:36–19:40): fbcode-only content captured into notes: `apply-space-hooks.py` (identical copy), `ot-alert-monitor.md` retry-block + `2>&1` fix, `ot-shift-summary.md` R64-71, `## Close the Thread` section. notes-only content (Team-Chat Send Gate, 102 lines) preserved throughout.
- **Sync-cron direction bug fixed** (2026-06-02T19:43): `ot-notes-fbcode-sync.md` cron prompt had LLM narrating "fbcode newer, notes missing Send Gate" (backwards) and emitting `cp fbcode→notes` recovery (the clobber). Rule added: never call notes "stale" without checking which side holds the content; never recommend cp→notes; recovery is a union merge.
- **Prompt filename divergence flagged** (2026-06-02T19:46): notes has `ot-notes-fbcode-commit.md`; MANIFEST + live job use `ot-notes-fbcode-sync.md`. Fix was applied to the live file; reconciling to one canonical name was deferred as a deliberate cleanup with blast radius.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/CLAUDE.md` | "edit notes" ground-truth rule; "Close the Thread" section merged in |
| `notes/.../cron-jobs/ot-notes-fbcode-sync.md` | DIRECTION-TRUTH + ANTI-CLOBBER rule added |
| `notes/.../apply-space-hooks.py` | copied from fbcode (identical) |
| `notes/.../cron-jobs/ot-alert-monitor.md` | retry-block + `2>&1` fix merged in |
| `notes/.../cron-jobs/ot-shift-summary.md` | R64-71 merged in |
| `~/.myclaw-ot-bot/CLAUDE.md` | refreshed from notes (stale "edit fbcode" instruction removed) |
| fbcode mirror copies | verified 0-diff vs notes post-sync |

## Cluster / pattern references

_(No CL-NNN clusters defined in failure-patterns.md)_

- "Why ask" x2 — operator pattern: low-blast-radius reconciliation work within stated goals should be executed without confirmation.

## Followup items (not yet done)

1. Prompt filename divergence (`ot-notes-fbcode-commit.md` vs `ot-notes-fbcode-sync.md`) — flagged but not reconciled; needs explicit decision on which name wins + delete the dup + fix MANIFEST.

## Cross-refs

- Related threads: `8IyKRxB9wPE` (shift-summary + flywheel work same session)
