# Thread Summary: Signal-Only Messaging — Don't Send Messages With No Value

_Source: spaces/AAQAVOjYc80 thread `t6SQVo16dTY` · 4 messages · 2026-05-17_
_Summarized: 2026-05-17 23:34 PT · last-msg-time: 2026-05-17T20:04:01Z_

## What was discussed

Operator challenged a recovery notification from `ot-disk-watch` that reported `/` and `/tmp` recovering from 92% → 81% used. Operator asked what the value of the message was, then issued generic feedback: "don't send me messages which have no value to me." Bot acknowledged and codified a new RULES.md rule covering four classes of no-value messages.

## Key decisions made

- (2026-05-17T20:03:49Z) Operator set explicit policy: every operator-facing gchat post must result in an action OR new learning — otherwise don't post.
- (2026-05-17T20:04:01Z) Bot added RULES.md § "Signal-only operator messaging" with four explicit anti-pattern classes: recovery pings (self-resolved), no-op heartbeats, state-file housekeeping, and already-alerted follow-ups.
- `ot-disk-watch` patched: `warning→ok` and `critical→ok` transitions now silent. Narrow exception: recovery from CRITICAL where operator replied in-thread within 4h → post recovery as threaded reply only.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/.myclaw-ot-bot/RULES.md` | Added "Signal-only operator messaging" rule with anti-pattern classes and self-check heuristic |
| sqlite daemon DB | `ot-disk-watch` cron prompt updated (recovery suppression) |

## Cluster / pattern references

_(no cluster IDs relevant to this operational/process thread)_

## Followup items (not yet done)

_(none explicitly discussed — fix was shipped in the same turn)_

## Cross-refs

- Related threads: `JFxkiKmeibI` (same session, applied same rule to notes-commit-push), `2KD3EVyCv08` (wait-reduction protocol)
