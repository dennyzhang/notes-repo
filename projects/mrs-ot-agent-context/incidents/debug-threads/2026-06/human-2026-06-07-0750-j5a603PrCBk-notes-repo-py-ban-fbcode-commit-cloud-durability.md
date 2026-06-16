---
name: human-2026-06-07-0750-j5a603PrCBk-notes-repo-py-ban-fbcode-commit-cloud-durability
description: Operator pushed on converting .py scripts to .sh to beat the notes deny_files ban. Bot explained why that's wrong, then resolved the durability + fast-iteration question via fbcode draft commits + Commit Cloud (verified end-to-end). Operator repeatedly challenged claims; bot verified each.
metadata:
  type: human
  thread_id: j5a603PrCBk
  space: spaces/AAQAVOjYc80
  human_involved: true
  first_msg_time_pt: 2026-06-07 07:50 PDT
  last_msg_time_utc: 2026-06-07T18:39:36Z
  msg_count: 19
---

# Thread Summary: Notes Repo .py Ban — fbcode + Commit Cloud as the Durability/Iteration Solution

_Source: spaces/AAQAVOjYc80 thread `j5a603PrCBk` · 19 messages · 2026-06-07 07:50–11:39 PDT_
_Summarized: 2026-06-07 21:46 PDT · last-msg-time: 2026-06-07T18:39:36Z_

## What was discussed

Operator proposed converting `.py` scripts to `.sh` to bypass the notes repo `deny_files` push hook that bans `.py`. Bot pushed back: the ban is server-side (not commit-hook), `.py` can commit locally but can never be pushed (jams the entire stack), bash is the wrong language for these scripts (regex/sqlite/library-import work). Operator then asked how to make scripts persist across devserver reinstall and support fast iteration. Bot proposed: (1) fbcode is the canonical home for code (notes for prose/config), (2) draft `sl commit` + Commit Cloud auto-backup = reinstall-durable without any review. Operator challenged "does this really work?" — bot ran an end-to-end test (test commit → appeared in `sl cloud sl` within ~69s → confirmed auto-backed-up → cleaned up). Verified and confirmed. Thread ended with operator asking to "create a meta task with plan, then execute it."

## Key decisions made

- [11:39 PDT, operator] Separate the ground-truth rule by type: prose/config → notes canonical; code (.py) → fbcode canonical. Prior CLAUDE.md rule ("notes is canonical for everything") was impossible for code because notes bans .py.
- [15:09 PDT, bot] Commit Cloud verification: `sl commit` (draft, no review) → auto-synced to Commit Cloud within ~69s. Confirmed via `sl cloud sl` showing the commit. `{backedup}` template field is unreliable; `sl cloud sl` is the authoritative check.
- [15:30 PDT, bot] Three-tier iteration model: (1) edit file → live next cron tick; (2) `sl commit` (draft) → Commit Cloud durable, zero review; (3) land to trunk → permanent + team-visible, batched weekly.
- Blocker identified: notes→fbcode mirror's fbcode-commit bug (CWD bug in `notes-to-fbcode-sync.sh`) — files copy but don't commit, so auto-durability is broken. Needs fix before the draft-commit path is reliable.

## Files / artifacts touched

| path | what changed |
|---|---|
| `team_bot/scripts/notes-to-fbcode-sync.sh` | CWD bug to be fixed (copies files but commit step fails with "no match under directory") |
| `pe_mrs_ml/mrs_ot_agent/` | sparse-profile membership to verify (needed for reinstall presence) |

## Cluster / pattern references

_(no CL-NNN applicable — tooling/iteration topic)_

## Followup items (not yet done)

1. Fix CWD bug in `notes-to-fbcode-sync.sh` fbcode-commit step. Owner: dennyzhang. Status: open.
2. Verify `pe_mrs_ml/mrs_ot_agent/` is in the eden/sparse profile post-reinstall. Owner: dennyzhang. Status: open.
3. Repoint cron `python3 tools/x.py` calls to the fbcode path (single canonical location). Owner: dennyzhang. Status: open.
4. Create a meta task with plan, then execute it (operator's last request, unexecuted). Owner: dennyzhang. Status: open.
5. Amend CLAUDE.md ground-truth rule to split: prose/config → notes canonical; code (.py) → fbcode canonical. Owner: dennyzhang. Status: open.

## Cross-refs

- Related threads: `BRcxJ7gSLzA` (iterating without blocking on diff land, same notes-ground-truth topic)
- Concepts: Commit Cloud, `sl cloud sl`, deny_files, notes-to-fbcode-sync, devserver reinstall survival
