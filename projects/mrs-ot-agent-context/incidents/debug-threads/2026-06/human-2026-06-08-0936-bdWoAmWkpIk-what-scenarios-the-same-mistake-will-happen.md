---
name: human-2026-06-08-0936-bdWoAmWkpIk
description: Diff↔task link failure scenarios; operator corrected confirmation-bait ending; rule: improvements go in cheatsheets
metadata:
  type: feedback
  human_involved: true
---

# Thread Summary: Diff↔Task Link Failure Scenarios

_Source: spaces/AAQAVOjYc80 thread `bdWoAmWkpIk` · 4 messages · 2026-06-08 16:36–17:50 UTC_
_Summarized: 2026-06-08 21:06 PT · last-msg-time: 2026-06-08T17:50:10Z_

## What was discussed

Operator asked "what scenarios the same mistake will happen?" — referencing the T272497510/D106049931 diff↔task association miss. Bot enumerated 8 failure classes (prose-ref instead of Tasks: field, cross-session orphan, draft diff, amend-strip, batched-sync diffs, post-land skip, etc.) and analyzed coverage gaps. Bot then ended with "Want me to build that reconciliation check?" — operator corrected this as confirmation-bait, then added that generic improvements belong in cheatsheets for reusable wins.

## Key decisions made

- **2026-06-08T17:49Z** — "why ask": bot must NOT end a diagnosis with an ask-to-implement; if the action is reversible and in scope, do it or note it as a cheatsheet item.
- **2026-06-08T17:50Z** — "generic improvements should in cheatsheets for reusable wins": structural improvements to the diff/task workflow belong in the diff cheatsheet (`~/notes/.../cheatsheets/diff/common.md`), not as one-off bot-built features requiring per-turn approval.

## Files / artifacts touched

| path | what changed |
|---|---|
| `cheatsheets/diff/common.md` | (proposed) add task-link verification step + reconciliation-scan description |

## Cluster / pattern references

- [P-001] (act don't ask) — bot violated this by ending with "Want me to build…?"

## Followup items (not yet done)

1. Add task-link verification step to diff cheatsheet (`meta phabricator.diff tasks --number=D<n>` must list task; catches A1/A3 at create time). Owner: Denny / bot. Status: open.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `nFVlLHvDlYE` (same session, bot instruction on thread-reply)
