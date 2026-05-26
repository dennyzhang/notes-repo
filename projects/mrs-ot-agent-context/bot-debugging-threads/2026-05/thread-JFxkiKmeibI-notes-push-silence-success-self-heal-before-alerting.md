# Thread Summary: Notes Push — Silence on Success, Self-Heal Before Alerting

_Source: spaces/AAQAVOjYc80 thread `JFxkiKmeibI` · 4 messages · 2026-05-17_
_Summarized: 2026-05-17 23:34 PT · last-msg-time: 2026-05-17T20:48:08Z_

## What was discussed

Operator challenged a success ping from `ot-notes-commit-push` ("22 files committed: <hash>") asking what the value of the message was. Operator directed: "I would rather get alerted when your notes push has failed. But that needs to be after your attempt of fix doesn't work." Bot rewrote the cron and then applied the same pattern to three other high-volume crons. When bot asked "want me to audit those three?" operator replied "Act; don't ask" — triggering a standing rule update.

## Key decisions made

- (2026-05-17T20:31:26Z) Operator policy: success → silent; failure → self-heal first; alert only after `consecutive_failures >= 2` (self-heal exhausted).
- (2026-05-17T20:31:39Z) `ot-notes-commit-push` rewritten: silent on success, self-heal on divergence/mid-op/transient, alert with last-error + suggested debug command after 2 consecutive failures, dedupe via `last_alert_epoch` (re-alert after 24h or 12 consecutive failures).
- (2026-05-17T20:47:56Z) Operator: "Act; don't ask" → RULES.md updated with "Act, don't ask" rule + mechanical pre-send check.
- (2026-05-17T20:48:08Z) Three additional crons patched: `ot-prompt-change-validator` (HEARTBEAT_OK on no-FAIL), `ot-cron-health-watch` (no audit-note posts in gchat), `ot-notes-deletion-watch` (post only when casualties detected).

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/.myclaw-ot-bot/RULES.md` | Added "Bot-first retry, escalate only when self-heal exhausted" + "Act, don't ask" + "mechanical pre-send check" rules |
| sqlite daemon DB | 4 cron prompts updated (`ot-notes-commit-push`, `ot-prompt-change-validator`, `ot-cron-health-watch`, `ot-notes-deletion-watch`) |
| `ot-notes-commit-push-state.json` | Initialized with `consecutive_failures=0, last_alert_epoch=null` |

## Cluster / pattern references

_(no failure cluster IDs relevant — this is a bot behavior/process thread)_

## Followup items (not yet done)

_(none — all changes shipped in-session)_

## Cross-refs

- Related threads: `t6SQVo16dTY` (same session: signal-only rule that prompted the pattern), `2KD3EVyCv08` (wait-reduction: "Act; don't ask" antecedent)
