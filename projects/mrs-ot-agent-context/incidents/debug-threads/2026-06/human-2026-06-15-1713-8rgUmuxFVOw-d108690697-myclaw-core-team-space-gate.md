---
name: d108690697-myclaw-core-team-space-gate
description: Building D108690697 — myclaw-core delivery gate for team-space cron routing. 3 rounds of operator review comments addressed. Landed. Config staged, awaiting package upgrade to activate.
metadata:
  type: project
  human_involved: true
---

# Thread Summary: D108690697 — myclaw-core team-space cron send gate

_Source: spaces/AAQAVOjYc80 thread `8rgUmuxFVOw` · 74 messages · 2026-06-15–16_
_Summarized: 2026-06-17 10:04 PT · last-msg-time: 2026-06-16T01:29:35Z_

## What was discussed

Operator said "why ask" in response to bot asking whether to start building T275142534 (myclaw-core delivery gate). Bot built D108690697 as a `--draft` diff: a send gate in `deliver_isolated_result()` (isolated_runner.py) that intercepts cron deliveries to the team space and reroutes non-allow-listed crons to the operator 1:1. Three rounds of operator code review:
1. Default should be all-allowed (opt-in, not restrictive default) — fixed in V1.1.
2. Policy must live in per-instance `config.json`, not hardcoded in `myclaw/src/core/config.py` — already correct in V1.1 (reads via `load_config`); operator confirmed.
3. Real infra IDs (`AAQA2bZMw24`) in unit tests are wrong — replaced with dummy `TEAMSPACE_TEST` in V1.3.

Diff landed (operator confirmed). Bot staged OT config: `team_space_allowed_sources` set to `[ot-sev-monitor, ot-alert-monitor, ot-post-monitor, ot-weekly-reliability-digest]`. Held `team_space_id` — safe to set only at package-upgrade time (setting it early activates a `<team_context>` prompt injection via prompts.py:629 with no gate benefit while old code is running). Gate requires `myclaw restart` after package upgrade to go live.

T275999884 filed: runbook for team members whose bots spam team chat — two options (disable the cron, or opt into the gate via their own `config.json`). Diff learnings logged as 6 dated entries in `diff-learnings-log.md` (not promoted to rules — first occurrence each).

**Key lesson (operator correction at 00:13:07Z):** "why ask" — asking before building a draft-gated diff adds a round-trip without adding safety. The review IS the gate; ask only at land/publish, not at start.

## Key decisions made

- Gate is `source_type=="job"` scoped (crons only) — triggers/task replies pass through (they are human-directed). (design decision)
- Default all-allowed: per-instance opt-in via `config.json:team_space_allowed_sources`. (operator comment, V1.1)
- `team_space_id` held in config until package upgrade — avoids side effect on prompts.py:629. (bot verification)
- T275999884 filed as member runbook + durable-fix tracker (shared-config-read-by-gate design). (2026-06-16T01:29:35Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| `myclaw/src/core/isolated_runner.py` | Added `deliver_isolated_result` gate |
| `myclaw/src/core/config.py` | Added `team_space_allowed_sources` config read |
| `myclaw/src/core/tests/` | 13 gate tests (dummy IDs) |
| OT `config.json` | `team_space_allowed_sources` staged (pending package upgrade activation) |
| `notes/.../cheatsheets/diff/diff-learnings-log.md` | 6 dated entries appended |

## Cluster / pattern references

_(No confirmed cluster IDs in failure-patterns.md — omitted)_

## Followup items (not yet done)

1. myclaw package upgrade → set `team_space_id` + restart to activate the gate for OT lane.
2. T275999884 — durable fix: make gate read allow-list from team-scoped source (eliminates per-member whack-a-mole).
3. Interactive/heartbeat funnel backstop (source tag on `MessageOrigin`) — documented as follow-up, not in D108690697.

## Cross-refs

- Diffs: D108690697 (landed)
- Tasks: T275999884 (filed), T275142534 (structural upstream)
- Related threads: `zLLsV9Hnyz0` (channel-field fix, same-day), `l7DblxcOh7Q` (step-12 deterministic fix)
