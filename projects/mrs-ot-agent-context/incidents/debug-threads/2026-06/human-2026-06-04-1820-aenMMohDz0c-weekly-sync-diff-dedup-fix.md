---
name: weekly-sync-diff-dedup-fix
description: Three duplicate weekly-sync diffs discovered; root-caused two bugs; collapsed to one diff; operator granted one-time abandon approval; Phabricator query added as authoritative dedup gate
metadata:
  type: project
human_involved: true
---

# Thread Summary: Weekly Notes→fbcode Sync Diff Deduplication Fix

_Source: spaces/AAQAVOjYc80 thread `aenMMohDz0c` · 38 messages · 2026-06-05 01:20–01:42 UTC_
_Summarized: 2026-06-05 21:44 PT · last-msg-time: 2026-06-05T01:42:12Z_

## What was discussed

Operator asked why three duplicate `[OT bot weekly sync]` diffs existed (D107523097, D107557341, D107598211) when the design is one rolling weekly diff. Bot traced two confirmed bugs: (1) the sync script rejected `--no-submit` → exited 1 every run; (2) no amend-by-week-hash wiring in commit cron → new commit per run. Operator pushed for system-query dedup (not local tracking). Operator granted one-time approval to abandon the two stale twins.

## Key decisions made

- **Query Phabricator before creating any weekly-sync diff** (authoritative dedup, not local state) — operator at 01:33:18: "shouldn't you query the system to avoid duplications?" wired into CLAUDE.md §"One weekly-sync diff per week" and memory `weekly-sync-diff-dedup`.
- **Amend-by-week-hash wiring** added to commit cron so it amends the same weekly commit instead of creating a new one each run.
- **`--no-submit` accepted as no-op** in notes-to-fbcode-sync.sh (script never submits anyway; the flag was previously rejected → exit 1).
- **D107557341 + D107598211 abandoned** with one-time operator approval at 01:41:37; D107599159 kept as the sole W23 keeper.
- **`sl hide` ≠ Phabricator abandon** — confirmed: hiding local commits does NOT abandon their Phabricator diffs; system query is the only reliable source.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/cron-jobs/ot-notes-fbcode-commit.md` | Added amend-by-week-hash wiring + corrected state path |
| `notes/.../team_bot/notes-to-fbcode-sync.sh` | Accept `--no-submit` as no-op |
| `notes/.../CLAUDE.md` | Added §"One weekly-sync diff per week" system-query dedup rule |
| `notes/.../state/` | State now points at D107599159 / commit `9465d5c7f116` |

## Cluster / pattern references

- [P-016] — full ownership: bot traced root cause, applied fix, and collapsed twins; did not stop at "fix staged"

## Followup items (not yet done)

1. Land D107599159 (operator action; bot is read-only on landing). Once landed, trunk catches up and drift clears.
2. Daemon restart for staged cron changes to go live.

## Cross-refs

- Diffs: D107599159 (keeper), D107557341 (abandoned), D107598211 (abandoned), D107523097 (abandoned/obsolete)
- Related thread: `wXsrtNNSCTk` (weekly-sync-diff-dedup memory)
