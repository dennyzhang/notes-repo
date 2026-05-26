# Thread Summary: W19 Missing + Notes Cheatsheets + Conditional Cheatsheet Loading + Daemon Restart Fix

_Source: spaces/AAQAVOjYc80 thread `iqRw-QgzYjM` · 16 messages · 2026-05-16_
_Summarized: 2026-05-17 00:31 PT · last-msg-time: 2026-05-16T21:17:54Z_

## What was discussed

Large multi-topic thread. Operator opened by flagging W19 missing from notes and another thread-routing slip. Bot diagnosed the W19 casualty (notes repo rebase racing with auto-sync, merged out a W19+TREND commit), restored the files, and then built out preventive infrastructure: a notes-repo-operations cheatsheet, an `ot-notes-deletion-watch` cron, gchat RULE #1 elevation in the gchat cheatsheet, conditional cheatsheet loading in `team_bot/CLAUDE.md`, and a daemon restart command fix (`ot-team` → `ot-bot`). Thread ended with operator asking bot to load recently-changed files from a parallel Claude session before proceeding.

## Key decisions made

- **[2026-05-16T21:07:55Z] Create notes-repo-operations cheatsheet** — 198-line ops guide committed, operator confirmed with "yes" after bot proposed.
- **[2026-05-16T21:08:43Z] Add notes-repo cheatsheet + ot-notes-deletion-watch cron** — both landed in single push `3780719e1541`; cron bootstrapped into daemon with first fire at 15:10 PT.
- **[2026-05-16T21:09:35Z] Improve gchat cheatsheet, RULE #1 threading** — operator directed; gchat.md and RULES.md updated.
- **[2026-05-16T21:11:51Z] Load cheatsheets conditionally** — operator directed change to `team_bot/CLAUDE.md` so cheatsheets are applied modality-by-modality.
- **[2026-05-16T21:15:43Z] Wait on daemon restart** — operator chose to defer `myclaw restart --instance ot-bot` to scheduled Saturday 00:00 PT weekly restart.
- **[2026-05-16T21:15:54Z] `--instance ot-bot` not `ot-team`** — operator caught wrong instance name; fix landed in cron prompt + daemon DB (`1106752a82ae`).

## Files / artifacts touched

| path | what changed |
|---|---|
| `mega-learnings/2026-W19.md`, `TREND-4-week-2026-W17-W20.md` | Restored (commit `da3cd1c3ca6c`) after rebase casualty |
| `cheatsheets/notes-repo-operations.md` | Created (198 lines, anti-patterns + push-divergence dance) |
| `cheatsheets/comms/gchat.md` | RULE #1 elevated to top; pre-send `thread_name` check added |
| `team_bot/cron-jobs/ot-notes-deletion-watch.md` | Created — hourly casualty detector |
| `team_bot/CLAUDE.md` (notes + fbcode) | Added conditional cheatsheet loading table |
| `~/.myclaw-ot-bot/RULES.md` | Push-discipline + gchat RULE #1 + pre-send check hardened |

Commits: `da3cd1c3ca6c` (W19 restore), `3780719e1541` (cheatsheets + deletion-watch), `c5b29eec452b` (gchat RULE #1), `d3bb8cd75b83` (conditional loading), `1106752a82ae` (instance fix).

## Cluster / pattern references

_(No cluster IDs from failure-patterns.md apply to this operational-discipline thread.)_

## Followup items (not yet done)

1. Daemon restart (`myclaw restart --instance ot-bot`) deferred to Saturday 00:00 PT (`ot-myclaw-weekly-restart` cron). New conditional-cheatsheet-loading section in `team_bot/CLAUDE.md` won't take effect until then.

## Cross-refs

- Related threads: `pFlYRGd0q2c` (threading discipline), `xELpXuo0m2Q` (mrs-ot-agent-context restructure later that evening)
