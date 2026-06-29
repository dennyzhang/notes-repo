---
name: team-chat-audit-real-60pct-cron-channel-fix
description: Two audit posts in one day — first (100%) was clean, second (60%) was a real cron leak. Bot diagnosed, found 3 crons missing channel field, added it, verified in sqlite.
metadata:
  type: project
  human_involved: false
---

# Thread Summary: Team-chat audit 60% precision — real cron channel leak fixed

_Source: spaces/AAQAVOjYc80 thread `zLLsV9Hnyz0` · 11 messages · 2026-06-15_
_Summarized: 2026-06-17 10:04 PT · last-msg-time: 2026-06-15T18:11:45Z_

## What was discussed

Operator posted two `📋 team-chat audit` results. The 08:05 audit (100% precision) was correctly identified as a clean no-op — bot stayed silent. The 18:04 audit (60% precision) flagged `ot-knowledge-curation` and `ot-prompt-change-validator`. Bot investigated: ran the authoritative script, confirmed both leaks were real — `ot-knowledge-curation` had posted a no-op narration to team (should have been `HEARTBEAT_OK`), and the validator leak was an older one already aging out. Bot diagnosed root cause: 3 operator-1:1-only crons declared "1:1 ONLY" in their prompts but were missing the `channel` field that routes delivery deterministically.

## Key decisions made

- Add `channel=spaces/AAQAVOjYc80` to `ot-knowledge-curation`, `ot-triage-auditor`, and `ot-team-chat-self-audit` — the 3 crons missing it while declaring 1:1-only delivery. (2026-06-15T18:07:25Z — bot identified the missing field as the in-lane deterministic lever)
- Do NOT add duplicate prose rules — the HEARTBEAT_OK rule was already present; the channel field is the fix, not more text. (2026-06-15T18:07:25Z)
- The durable fix remains T275142534 (myclaw-core daemon send gate) — channel is a mitigation, LLM-variance beats prose-only rules. (2026-06-15T18:11:45Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/MANIFEST.json` | Added `channel` to 3 crons |
| sqlite `myclaw.db` | Applied via `setup-cron-jobs.sh`, verified `[UPDATE] ×3` |
| notes repo | Committed + cloud-synced |

## Cluster / pattern references

_(No confirmed cluster IDs in failure-patterns.md — omitted)_

## Followup items (not yet done)

1. T275142534 — myclaw-core daemon send gate (structural LLM-variance fix); not in-lane, awaiting myclaw-core deploy

## Cross-refs

- Related threads: `8GImC-FVbrY` (same-day false-alarm audit investigation)
