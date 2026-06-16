---
thread_id: pnL5GSkFRW0
human_involved: true
space: spaces/AAQAVOjYc80
msg_count: 9
first_msg_time: 2026-06-08T10:34:39Z
last_msg_time: 2026-06-09T14:33:42Z
---

# Thread Summary: P-017 Mechanism — Upstream Decisive-Task Helper Built

_Source: spaces/AAQAVOjYc80 thread `pnL5GSkFRW0` · 9 messages · 2026-06-08 to 2026-06-09_
_Summarized: 2026-06-09 22:04 PT · last-msg-time: 2026-06-09T14:33:42Z_

## What was discussed

Thread started with a cron triage output (🟡 MONITOR) for S672163 + S668542 scribe/ZippyDB lag on IG reels. The next day, operator challenged the bot on a missing follow-up: "Shouldn't we have a follow-up which creates a task to build decisive query to confirm the upstream issue?" The bot then built the shared helper and wired it into the recurrence detector.

## Key decisions made

- [2026-06-09T14:30] Build `tools/file-decisive-metric-task.sh`: auto-files ONE deduped `ot-upstream-decisive-metric` task when a recurring+high-confidence+upstream finding is detected; task is owner=dennyzhang with deliverable = decisive ground-truth query.
- [2026-06-09T14:31] Wire the helper into `ot-cron-health-guard` step 7.7's upstream branch (primary recurrence detector).
- [2026-06-09T14:32] Also wire into `ot-bot-volume-watch` (team-leak detector) — the same upstream pattern applies there.

## Files / artifacts touched

| path | what changed |
|---|---|
| `tools/file-decisive-metric-task.sh` | NEW — shared helper; dedup via open-task name match; dry-run gate |
| `ot-cron-health-guard` prompt (sqlite) | Wired upstream branch to call the helper |
| `ot-bot-volume-watch` prompt (sqlite) | Wired same helper for volume-watch upstream findings |

## Cluster / pattern references

_(no verified CL-NNN in failure-patterns.md at time of summary)_

## Followup items (not yet done)

_(none discussed in thread)_

## Cross-refs

- SEVs discussed: S672163, S668542
- Related threads: `jPPo82dAT4M` (P-017 formal codification)
