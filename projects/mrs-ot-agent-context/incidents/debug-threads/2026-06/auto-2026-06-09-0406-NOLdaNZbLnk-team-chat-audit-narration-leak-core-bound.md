---
human_involved: false
---
# Thread Summary: team-chat audit 25% precision — narration-leak class proven core-bound, more prose futile

_Source: spaces/AAQAVOjYc80 thread `NOLdaNZbLnk` · 8 messages · 2026-06-09 04:06–04:11 PDT_
_Summarized: 2026-06-09 23:04 PT · last-msg-time: 2026-06-09T11:11:29Z_

## What was discussed

ot-volume-audit reported team-chat precision improving from 4% to 25% (97→18 noise posts). MyClaw analyzed the residual 18 noise: sev/alert-monitor already carry "no preamble / EXACTLY HEARTBEAT_OK" rules but violated them at runtime anyway. This falsifies the "add more prose rules" fix — the rule is present and the LLM violates it under task focus. The remaining noise is core-bound (interactive leak via cross_space.py, narration violations despite existing rules). A decisive fix was added to T274834361: suppress auto-delivery when the final response *contains* `HEARTBEAT_OK` (not requires exact match).

## Key decisions made

- [2026-06-09T11:08:46Z] Falsification: no-preamble rule already present in sev-monitor + alert-monitor, yet leaked at runtime → adding more prose is proven futile for narration class
- [2026-06-09T11:09:31Z] fleet-health team post (1) is intentional (zombie/perf = shared OT incident, operator-consolidated), not a cron bug — volume-audit allowlist gap, not a routing error
- [2026-06-09T11:10:10Z] Decisive core fix recorded on T274834361: `contains HEARTBEAT_OK` suppression (vs `equals`) kills narration-before-HEARTBEAT class in one daemon change; pair with cross_space.py route gate

## Files / artifacts touched

| path | what changed |
|---|---|
| T274834361 | Added precise evidence: rule-present-yet-violated; proposed contains-token suppression fix |

## Cluster / pattern references

_(No CL-NNN in failure-patterns.md for narration-leak class)_

## Followup items (not yet done)

1. Core fix T274834361 / D107579040 not yet landed — precision target ≥90% gated on it
2. fleet-health `run-fleet-health.sh` failure-branch routing fix — flagged for deliberate daytime edit

## Cross-refs

- Related threads: `jPPo82dAT4M` (team-chat precision metric, T275122535)
