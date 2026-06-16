# Thread Summary: OAuth GChat 403 Fix — Monitor Prompts Amended, HEARTBEAT Rule Codified

_Source: spaces/AAQAVOjYc80 thread `AOQM8O19bHE` · 19 messages · 2026-05-29_
_Summarized: 2026-05-29 07:45 PT · last-msg-time: 2026-05-29T03:20:34Z_

## What was discussed

Denny confirmed GChat 403 is a recurring pattern (not one-off): OAuth token expires periodically, `meta google.chat.message list` returns 403, recoverable via `buck2 run`. Bot had been treating it as a hard wall (reporting degradation, capping confidence) instead of attempting the buck2 recovery first. Bot shipped the fix: all 3 monitor cron prompts amended with fallback chain (403 → `buck2 run` refresh → retry → escalate); HEARTBEAT.md rule 6 updated with the same chain; L66 filed in daily-ledger. Thread closes with Denny noting a P-001 violation: bot asked "Want me to fix D106735261?" instead of just doing it (reversible, pre-authorized class of work).

## Key decisions made

- (2026-05-29T02:42:12Z) Denny: GChat 403 root cause = OAuth token expiry; recovery = `buck2 run`; fix = codify the fallback chain in prompts + HEARTBEAT.
- (2026-05-29T02:59:00Z) Bot: pre-authorized + reversible, ship without asking (Denny confirmed with "why ask?").
- (2026-05-29T03:20:34Z) Denny: P-001 violation logged (asked "Want me to fix D106735261?" on pre-authorized reversible work).

## Files / artifacts touched

| path | what changed |
|---|---|
| ot-sev-monitor, ot-alert-monitor, ot-post-monitor cron prompts (notes + sqlite) | OAuth recovery chain added; parity verified |
| `HEARTBEAT.md` rule 6 | sub-bullet: on GChat 403 → buck2 run → retry → escalate |
| `mrs-ot-agent-context/learnings/daily-ledger.md` | L66: OAuth token expiry root cause + recovery path |

## Cluster / pattern references

_(omitted — failure-patterns.md not present)_

## Followup items (not yet done)

1. Token-lifetime probe (#3 from bot's list) — deferred 24h pending instrumentation data. Owner: bot, status: pending.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `AYu0E96ZdUE` (root cause investigation), `LlBe4tLd2zY` (D106716098 context)
