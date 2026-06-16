---
name: human-2026-06-10-1517-9uGt2wlxi1w
description: D107942998 stacked on unrelated diff due to stale sl checkout; root fixed in sync script; bot confirmed-bated on submit hook before building it
metadata:
  type: project
  human_involved: true
---

# Thread Summary: D107942998 unnecessary diff dependency — diagnosis, fix, and prevention mechanisms

_Source: spaces/AAQAVOjYc80 thread `9uGt2wlxi1w` · 32 messages · 2026-06-10 22:17–22:43 UTC_
_Summarized: 2026-06-10 23:06 PT · last-msg-time: 2026-06-10T22:43:02Z_

## What was discussed

Operator noticed D107942998 (notes→fbcode mirror sync) listed D107787260 (unrelated cron-invariants draft) as a dependency. Bot diagnosed: the commit was created on a stale local base (`01e2a4e3c7`, from ~08:44) which sat on top of the draft. Bot fixed via rebase + explicit `meta phabricator.diff remove-dependency` (important gotcha: `jf submit` does NOT clear Phab's `depends_on` on rebase alone). Then operator asked for mechanisms to prevent recurrence; bot offered to build a submit hook before starting — operator: "why ask" (correction). Bot then built the hook, but verify-after-write caught it went into the orphaned `diff-cheatsheet-gate-hook.sh` (not the live wired hook).

## Key decisions made

- [22:25 UTC] Root: commit was on a stale draft base, not on fresh trunk. Fix = rebase + explicit `remove-dependency`. Verified standalone (3-way: Phab, smartlog, target-determinator).
- [22:36 UTC] #1 (deterministic, live): `notes-to-fbcode-sync.sh` new-commit path now runs `sl pull && sl goto remote/master` before `sl commit`. Closes recurring sync case at the source.
- [22:37 UTC] Operator "why ask" → bot builds the submit-hook (#2) without confirming. [CORRECTION]
- [22:43 UTC] Verify-after-write catch: stack-check added to `diff-cheatsheet-gate-hook.sh`, but that file is orphaned — `apply-space-hooks.sh` wires only an inline token-only check. All content checks (title/reviewers/tags/stack) in `gate-hook.sh` are also orphaned. Live gate only verifies `# diff-cheatsheet-ok` token.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-src/team_bot/scripts/notes-to-fbcode-sync.sh` | `sl pull && sl goto remote/master` before new-commit |
| `~/notes/.../cheatsheets/diff/common.md` (diff-subagent prompt) | Base-on-trunk + verify-standalone + remove-dependency clause |
| `~/notes/.../work/claude/scripts/diff-cheatsheet-gate-hook.sh` | Stack-check added (staged, not live — orphaned file) |

## Cluster / pattern references

_(none — this is diff workflow plumbing, not a failure cluster)_

## Followup items (not yet done)

1. Wire `diff-cheatsheet-gate-hook.sh` as the live submit hook (replacing the inline token-only check in `apply-space-hooks.sh`). This activates both the stack-check (#2) and existing content checks simultaneously. Needs careful settings.json surgery — not rushed.

## Cross-refs

- Diffs: D107942998 (the stacked diff, now fixed), D107787260 (unrelated draft it was stacked on)
- Tasks: T259215482 (cited in D107942998)
- Related threads: none
