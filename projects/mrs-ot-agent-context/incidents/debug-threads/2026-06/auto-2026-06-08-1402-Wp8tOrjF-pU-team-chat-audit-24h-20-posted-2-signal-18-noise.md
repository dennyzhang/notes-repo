---
name: auto-2026-06-08-1402-Wp8tOrjF-pU
description: Team-chat audit 10% precision + fbpkg cap-watch urgency + paste fix for cross-team post
metadata:
  type: project
  human_involved: false
---

# Thread Summary: Team-Chat Audit (24h) + Fbpkg Cap-Watch Urgency

_Source: spaces/AAQAVOjYc80 thread `Wp8tOrjF-pU` · 4 messages · 2026-06-08 21:02–21:05 UTC_
_Summarized: 2026-06-08 21:06 PT · last-msg-time: 2026-06-08T21:05:10Z_

## What was discussed

The `ot-bot-volume-watch` cron posted a 24h team-chat audit: 20 posts in 24h, only 2 signal, 18 noise (10% precision). Noise breakdown: interactive replies ×17 (operator↔bot conversation routed to team space instead of 1:1) + sev-monitor ×1 (daily-brief format not matched by signal allow-list). Bot analyzed the audit: both noise classes trace to the same routing leak (interactive leaks need myclaw-core session routing, tracked in T274834361 — not flippable from the OT lane). Bot separately flagged an urgent time-sensitive item: `ot-fbpkg-cap-watch` detected `light_cli` at 1047/1200 cap, growth 18/day → cap hits ~Jun 16-17, before next Monday's cron run. Bot also corrected paste P2369293164 (stale ASK: "MVAI/TMS oncall"; verified primary = `mlhub_debugging_experience`) → created replacement P2369339688 in thread `RxPdrLPPBvY`.

## Key decisions made

- Team-chat precision 10% = routing problem, not content problem. Fix lives in myclaw-core session routing (T274834361), not OT lane config.
- `light_cli` fbpkg cap urgency: human must ping fbpkg oncall to raise Version Limit (or push T271102844) **before Wed Jun 11** — weekly cron won't catch it.

## Files / artifacts touched

| path | what changed |
|---|---|
| Paste P2369339688 | Created; corrects P2369293164 (stale ASK line; primary oncall now `mlhub_debugging_experience`) |

## Cluster / pattern references

- (none coded — routing class known, tracked in T274834361)

## Followup items (not yet done)

1. Ping fbpkg oncall to raise `light_cli` Version Limit before Jun 11 (or push T271102844). Owner: Denny. Status: URGENT — deadline before weekly cron.
2. T274834361 — session routing fix for interactive-reply cross-space leak. Owner: myclaw-core team. Status: open.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `RxPdrLPPBvY` (paste fix delivered there)
