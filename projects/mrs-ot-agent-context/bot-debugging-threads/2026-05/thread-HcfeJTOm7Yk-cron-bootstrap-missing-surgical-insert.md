# Thread Summary: Bootstrap-missing crons registered via surgical sqlite INSERT

_Source: spaces/AAQAVOjYc80 thread `HcfeJTOm7Yk` · 7 messages · 2026-05-29T03:40–03:44 UTC_
_Summarized: 2026-05-29 16:45 PT · last-msg-time: 2026-05-29T03:44:39Z_

## What was discussed

The `ot-cron-health-watch` alert fired `bootstrap_missing→confirmed_missing HIGH` for two crons: `ot-triage-auditor` and `ot-thread-summarizer` — both absent from the sqlite jobs table, zero runs in 72h. The triage recommended running `setup-cron-jobs.sh`, but a dry-run showed it would delete `ot-notes-fbcode-sync-weekly` and overwrite 14 prompts with stale content. Bot blocked the unsafe path and used surgical sqlite INSERT to register only the 2 missing crons.

## Key decisions made

- **Surgical INSERT over full `setup-cron-jobs.sh` run** (2026-05-29T03:44Z) — dry-run confirmed the script would clobber the weekly sync cron and 14 in-session prompt edits. Safe path: targeted INSERT of just the missing job IDs.
- **Flag `setup-cron-jobs.sh` recommendation as unsafe** — proposed adding `--insert-only` mode as a follow-up to avoid this class of risk in future health alerts.

## Files / artifacts touched

| path | what changed |
|---|---|
| sqlite jobs table | 2 rows INSERTed: `ot-triage-auditor`, `ot-thread-summarizer` (next runs ~20:46 PT) |

## Cluster / pattern references

_(none — failure-patterns.md absent or no matching cluster)_

## Followup items (not yet done)

1. Add `--insert-only` flag to `setup-cron-jobs.sh` to prevent safe-cron-deletion risk. Owner: bot/Denny. Status: proposed, not started.

## Cross-refs

- Related threads: `iiujQv9mdP0` (same session — GChat reads degraded fix)
