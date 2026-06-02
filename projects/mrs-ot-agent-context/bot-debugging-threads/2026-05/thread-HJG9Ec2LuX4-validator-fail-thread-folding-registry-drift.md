# Thread Summary: Validator FAILs fixed + thread-folding discipline + empty-msg false alarm + registry drift

_Source: spaces/AAQAVOjYc80 thread `HJG9Ec2LuX4` · 46 messages · 2026-05-29T16:24–17:01 UTC_
_Summarized: 2026-05-29 16:45 PT · last-msg-time: 2026-05-29T17:01:26Z_

## What was discussed

Multi-topic thread covering four issues: (1) Denny asked what approvals bot needed for validator FAILs; bot fixed 3 invalid `oncall.feed metadata/comments` invocations across 2 crons. (2) Denny instructed "fold messages of same topic into the related gchat thread" — bot codified thread-folding as the 3rd volume lever. (3) Bot investigated "150 empty BOT msgs/day" and overturned the alert: the `messages` table is an ingestion log where all BOT rows are `status='skipped'` — not an outbound send log. (4) Registry drift found and resolved: 7 crons firing from in-memory schedule but unregistered in sqlite; 2 sqlite-only crons added to MANIFEST.

## Key decisions made

- **`oncall.feed` has no `metadata`/`comments` action** (2026-05-29T16:28Z) — canonical action is `describe` (or `monitoring.alert metadata` for alert namespace). 3 occurrences fixed: ot-shift-summary L597+L645, ot-alert-monitor L304.
- **`messages` table = ingestion log, not send log** (2026-05-29T16:31Z) — all BOT rows are `status='skipped'` echoes. Volume counts must use GChat API, not sqlite. Empty-msg finding was a false alarm.
- **Thread-folding as 3rd volume lever** (2026-05-29T16:33Z) — always `--reply-in-thread`; fold same-topic into ONE reply; ot-bot-volume-watch step 11 measures distinct-thread count (target ≤10).
- **Registry drift fix** (2026-05-29T16:56Z) — 7 unregistered crons added to sqlite (byte-exact parity), 2 sqlite-only added to MANIFEST. `ot-gdoc-context-sync` intentionally gated on D106716098.

## Files / artifacts touched

| path | what changed |
|---|---|
| ot-shift-summary.md | 2 invalid `oncall.feed metadata` → `describe` fixed |
| ot-alert-monitor.md | 1 invalid `oncall.feed metadata` → `monitoring.alert metadata` fixed |
| ot-knowledge-curation + ot-human-attention-brief | A<id> bare-token rendering fixed (alerts now linkified) |
| memory/gotcha_messages-table-is-ingestion-log.md | created |
| memory/feedback_fold-messages-into-threads.md | created |
| sqlite jobs table | 7 crons registered; 2 MANIFEST entries added |

## Cluster / pattern references

_(none — failure-patterns.md absent or no matching cluster)_

## Followup items (not yet done)

1. gdoc 6/2 tab scrub (bot-content + trunk-health section removal) — mentioned as remaining, not confirmed done.
2. Prompt-validator false-positives on NEVER/FORBIDDEN-context lines — flagged for Denny's call, not started.

## Cross-refs

- Related threads: `3tFk1T8bbyM` (shift summary format regression same session)
