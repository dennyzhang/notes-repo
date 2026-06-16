---
human_involved: true
---

# Thread Summary: GRv0 CPU-OOM triage ask-1 fix — P-018 created, read-only lookup resolved

_Source: spaces/AAQAVOjYc80 thread `HEuiwnurEL4` · 19 messages · 2026-06-09 16:48–16:56 PT_
_Summarized: 2026-06-10 01:04 PT · last-msg-time: 2026-06-09T23:56:47Z_

## What was discussed

Operator questioned ask-1 in the GRv0 CPU-OOM triage: "why can't you queue the cli version?" — the triage had punted "confirm working CLI version from the comparison model" to the model owner, which is a read-only metadata lookup the bot should do itself. Bot resolved the lookup, corrected the ask, and then created P-018 as a systemic prevention.

## Key decisions made

- [2026-06-09T23:52:04Z] Resolved: comparison model cclo30b9 = mvai-training-online-2121055642, running light_cli:4690. Failing GRv0 job = mvai-training-online-2120506863, running light_cli:5712 (AOTI-publish CPU-OOM regression). Downgrade target is concrete: v5712 → v4690.
- [2026-06-09T23:52:04Z] Corrected ask-1: "relaunch GRv0 on light_cli:4690 (the version its healthy sibling 2121055642 runs)" — no guesswork left for the owner. The write/relaunch is theirs; the version lookup is the bot's.
- [2026-06-09T23:54:33Z] Created P-018: "triage next-action must not delegate read-only work to human." Litmus: could the bot produce this value with a read-only call? Then it must — emit the exact target; only write/mutation is the human's.
- Extended ot-post-monitor's NO-WAITING/THIN-WORK rule to explicitly cover owner-delegation (previously scoped to "don't ask the operator"; now includes "don't make the owner do a fetchable lookup").

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../human-input-generic/principles/P-018-triage-next-actions-resolve-readonly-not-delegate.md` | new P-018 principle file |
| `~/notes/.../human-input-generic/principles/INDEX.md` | added P-018 row after P-017 |
| ot-post-monitor prompt (sqlite) | extended NO-WAITING rule to cover next-action owner-delegation; added mlhub/fburl → cli-version recipe |

## Cluster / pattern references

_(no cluster match — new principle creation, not a known failure pattern)_

## Followup items (not yet done)

_(none — principle created, cron extended, instance corrected; fully closed)_

## Cross-refs

- GRv0 job: mvai-training-online-2120506863 (light_cli:5712, AOTI-publish CPU-OOM)
- Healthy sibling: mvai-training-online-2121055642 (light_cli:4690)
- P-018 principle file (founding miss: GRv0 ask-1 punted a version lookup that resolved to light_cli:4690 in seconds)
- Related threads: prior GRv0/CPU-OOM triage thread (source of the original ask-1)
