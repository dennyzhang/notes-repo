# Thread Summary: notes-to-fbcode sync — 3-diff consolidation + 2-cron split

_Source: spaces/AAQAVOjYc80 thread `zv128jeH6Q8` · 17 messages · 2026-05-22 16:43–20:42 UTC_
_Summarized: 2026-05-22 23:47 PT · last-msg-time: 2026-05-22T20:42:28Z_

## What was discussed

Denny discovered MyClaw had created 3 separate daily draft diffs (D106052922, D106080932, D106084230) for the notes→fbcode sync instead of one weekly diff. Root cause: the sync cron lost its `--no-submit` flag during a cherry-pick cleanup, so every run was calling `jf submit`. Denny chose Option B: split into two crons (4×/day commit-only + weekly Monday submit). MyClaw then executed consolidation and was asked to rebase D106052922 to latest trunk as a follow-up.

## Key decisions made

- `2026-05-22T17:32:37Z` (Denny): Option B — split into two crons (4×/day commit-only, Mon 09:00 PDT submit-only)
- `2026-05-22T17:35:49Z` (Denny): "get it done. don't ask me, if absolutely needed" — authorization to act without confirmation loops
- D106080932 and D106084230 abandoned; D106052922 updated with consolidated 33-file weekly summary
- New cron `ot-notes-fbcode-sync-weekly` registered with next_run Mon 2026-05-25 09:00 PDT

## Files / artifacts touched

| path | what changed |
|---|---|
| `cron-jobs/ot-notes-fbcode-sync.md` | Added `--no-submit`, commit-title rewrite |
| `cron-jobs/ot-notes-fbcode-sync-weekly.md` | New file — weekly submit cron spec |
| `cron-jobs/MANIFEST.json` | Updated old entry + inserted new weekly entry |
| `myclaw.db jobs` table | New row for `ot-notes-fbcode-sync-weekly` |
| D106052922 | Consolidated 3 drafts → 1 surviving diff (33 files) |
| D106126551/D106126552/D106126550 | Phase A fbcode-as-SoT rebase stack |

## Cluster / pattern references

_(omitted — failure-patterns.md not present)_

## Followup items (not yet done)

1. Phase A diffs D106126551→D106126552→D106126550: needs Denny review + mark non-draft + land bottom-up. MyClaw blocked on this.
2. Phase B (auto-sync fbcode→sqlite) gated on Phase A landing.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `3pj-uyxQ_Go` (earlier Phase A discussion)
