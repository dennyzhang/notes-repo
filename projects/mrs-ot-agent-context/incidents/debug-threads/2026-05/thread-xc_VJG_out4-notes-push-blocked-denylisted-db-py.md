# Thread Summary: Notes Push Blocked by Denylisted .db/.py + Phabricator Diff Paste + Weekly Paste Cron

_Source: spaces/AAQAVOjYc80 thread `xc_VJG_out4` · 64 messages · 2026-05-31_
_Summarized: 2026-06-01 04:45 PT · last-msg-time: 2026-05-31T01:59:38Z_

## What was discussed

Denny asked for a Phabricator URL of the 7-day notes changes. The bot hit two problems getting there: (1) `pastry`'s upload endpoint was down, so the fallback `meta phabricator.paste create --stdin` was used; (2) the `sl diff -X` exclude flag silently no-ops, so churn filtering had to be done post-hoc. The resulting diff-paste (P2357388906, 157 meaningful files) was accepted. Denny then asked for a weekly recurring cron to produce this paste. While wiring it, the bot discovered that `sl push --to master` had been silently failing because three denylisted files were tracked in the notes repo (`.db` runtime sqlite + `.py` installer), blocking every push. Notes master had been stale with recent changes piling up in unpushable local commits.

## Key decisions made

- **2026-05-31T01:22** `pastry` endpoint broken → use `meta phabricator.paste create --stdin` (confirmed working).
- **2026-05-31T01:34** Denny approved creating `ot-notes-weekly-review-paste` cron — Mondays 07:00 PDT, produces a colored rendered-diff paste of the prior 7 days' meaningful notes changes.
- **2026-05-31T01:36** Cron registered in notes + sqlite + MANIFEST. `next_run = 2026-06-01 07:00 PDT`.
- **2026-05-31T01:56** Root cause of stale notes master: `crons.db`, `state/ot_agent.db`, `team_bot/apply-space-hooks.py` are tracked in the notes repo; `deny_files` hook rejects the entire push because of them.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-notes-weekly-review-paste.md` | new cron prompt (weekly notes diff paste) |
| `notes/.../MANIFEST.json` | new cron entry added |
| `myclaw.db` jobs table | `ot-notes-weekly-review-paste` registered, next_run Mon 07:00 PDT |
| Paste P2357388906 | 7-day notes diff, 157 meaningful files, rendered as colored diff |
| Notes cheatsheet | updated with: `-d` baseline recipe, post-hoc churn filter, `meta phabricator.paste create --stdin --language=diff` |

## Cluster / pattern references

_(omitted — failure-patterns.md does not exist yet)_

## Followup items (not yet done)

1. Fix notes push: untrack `crons.db`, `state/ot_agent.db`, `team_bot/apply-space-hooks.py` via `.gitignore` + `sl forget`; then collapse-push the stale backlog (cheatsheet revert-snapshot workaround). Awaiting Denny's go on notes-repo surgery.

## Cross-refs

- Related threads: `S2zrir2qpBY` (reinstall durability), `rLh3PKgXCmA` (apply-space-hooks.py canonical home)
- Posts: none
