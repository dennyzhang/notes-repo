# Thread Summary: context-ingestor-gchat + context-ingestor-posts Missing from Daemon

_Source: spaces/AAQAVOjYc80 thread `8Nzx9nUrsOI` · 3 messages · 2026-05-18T19:40–T19:41Z_
_Summarized: 2026-05-19 00:41 PT · last-msg-time: 2026-05-18T19:41:05Z_

## What was discussed

`cron-health-watch` surfaced that both `context-ingestor-gchat` and `context-ingestor-posts` were missing from the daemon's sqlite jobs table — they were added to MANIFEST.json but `setup-cron-jobs.sh` was never run to register them. The bot diagnosed, ran setup-cron-jobs.sh (2 inserts, 27 updates), then triggered both jobs manually. Both ran successfully: 4 catch-up files from gchat, 1 combined experts file from posts. `cron-health-watch` expected to self-clear next fire.

## Key decisions made

- **2026-05-18T19:41Z** — Root cause: MANIFEST.json and daemon sqlite diverge whenever a cron is added without running `setup-cron-jobs.sh`. Fix: run script immediately after adding to MANIFEST, not deferred.
- **2026-05-18T19:41Z** — Process lesson: a pre-commit hook or post-commit step in `ot-notes-fbcode-sync` should auto-run `setup-cron-jobs.sh` when MANIFEST.json changes. Deferred to Thursday hygiene pass.

## Files / artifacts touched

| path | what changed |
|---|---|
| daemon sqlite (jobs table) | 2 crons inserted (context-ingestor-gchat, context-ingestor-posts), 27 updated |
| `human-input-domain/2026-05-18-*-catchup.md` | 4 gchat catch-up files + 1 posts catch-up file written on manual retrigger |

## Cluster / pattern references

_(No failure-cluster references — operational gap, not model/training incident.)_

## Followup items (not yet done)

1. Pre-commit hook or post-sync step: auto-run `setup-cron-jobs.sh` when MANIFEST.json changes. Owner: dennyzhang. Status: deferred to Thursday hygiene pass.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `Oe2XG0WVOMY` (original cron creation thread)
