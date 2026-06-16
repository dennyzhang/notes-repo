# Thread Summary: Notes Repo Cleanup + ot-disk-watch Completeness

_Source: spaces/AAQAVOjYc80 thread `tjmKhFz-J-A` · 59 messages · 2026-05-25T17:44–18:58 PT_
_Summarized: 2026-05-28 20:45 PT · last-msg-time: 2026-05-25T18:58:38Z_

## What was discussed

Two interleaved workstreams. (1) Notes repo structural cleanup: Denny asked about `pending-proposals.md` vs `auto-fixes/`, `failure-patterns.md` vs `patterns/failure-modes.md`, redundant `mega/` directory, and other taxonomy gaps. Bot analyzed and acted without asking. (2) `ot-disk-watch` cron: surfaced a mismatch between `df` (54%) and btrfs Data-chunk metric (~86%) that caused a false external CRITICAL alert. Bot ran `btrfs balance`, discovered balance made Data-chunk ratio worse, corrected the threshold logic, and deployed a completeness pass to the cron backend.

## Key decisions made

- **2026-05-25T17:47** — "just fix it": bot proceeded to migrate `pending-proposals.md` → `auto-fixes/`, collapse `auto-learnings/mega/` → `summaries/weekly/`, fix W21 dual-file bug. No POR draft.
- **2026-05-25T17:55** — "act; don't ask unless absolutely necessary": bot acted on all 6 identified taxonomy gaps (P-NNN collision rename, daily-ledger rotation, inventory subtree decision, etc.) without waiting for confirmation.
- **2026-05-25T18:26** — Denny authorized `btrfs balance start -dusage=50 /`; bot ran it and then self-corrected the threshold (Device-unallocated replaces Data-chunk ratio as the trigger metric).
- **2026-05-25T18:29** — "commit and push to notes repo": committed as `edbcd923dae1` on master.
- **2026-05-25T18:33** — "attack the cron to make it complete and reliable": 7 gaps closed (backend drift fixed via delete-recreate, MANIFEST.json entry added, schedule tightened to `*/15`, raw-debug capture, inode check, `alerts_posted_24h` prune, auto-mitigation on `ok→warning`).

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../auto-fixes/2026-05-17/01-05-*.md` | migrated from `pending-proposals.md` (5 entries) |
| `notes/.../auto-learnings/summaries/weekly/2026-W21.md` | merged W21 dual-file bug; `mega/` removed |
| `notes/.../cron-jobs/ot-disk-watch.md` | completeness pass (btrfs, inode, raw debug, auto-mitigation) |
| `notes/.../cron-jobs/MANIFEST.json` | added `ot-disk-watch` entry |
| `cron-prompt-backups/ot-disk-watch_2026-05-25T11-25_pre-btrfs-amendment.md` | pre-amendment backup |

## Cluster / pattern references

_(omitted — no verified CL-NNN applicable)_

## Followup items (not yet done)

_(none explicitly stated as open at thread end)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `ENMy7DG8lyk`, `cDZgP4hWUTU`
