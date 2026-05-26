# Thread Summary: ot-notes-fbcode-sync hung→persistent_failure — fbcode dirty-tree unblock

_Source: spaces/AAQAVOjYc80 thread `ViskFZpcoWA` · 6 messages · 2026-05-21 01:40–02:42 UTC_
_Summarized: 2026-05-24 17:50 PT · last-msg-time: 2026-05-21T02:42:22Z_

## What was discussed

The `ot-notes-fbcode-sync` cron had 3 consecutive failures blocked by uncommitted fbcode modifications (`MANIFEST.json` + `ot-cron-health-watch.md`). The bot had already staged a local commit (`30e9cc13dae7`) cleaning up the working tree, but pushing was blocked by a guardrail (`pre-push.push_agent_check hook failed: pushing from agent is not allowed`). Three unblock options were presented (push directly, arc diff, or revert). Denny selected option B (arc diff) at `2026-05-21T02:26:57Z`, but the session hit idle timeout at `02:42:22Z` before execution completed.

## Key decisions made

- `2026-05-21T02:26:57Z` — Denny selected option B (arc diff) for the unblock path, preferring a Phab review trail over direct push. Bot had committed the working tree locally; arc diff was to stage the review.
- Human-lands-only rule confirmed as appropriate: agent guardrail correctly blocked the push; bot must never bypass `push_agent_check`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/` | Local commit `30e9cc13dae7` staged (MANIFEST.json + ot-cron-health-watch.md), working tree cleaned. Arc diff NOT run — session timed out. |

## Cluster / pattern references

_(No failure-pattern clusters apply — this was a tooling/infra workflow issue, not an OT training incident.)_

## Followup items (not yet done)

_(None explicitly committed before session timeout. The arc diff was not run; follow-up state unknown.)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none explicitly cited
