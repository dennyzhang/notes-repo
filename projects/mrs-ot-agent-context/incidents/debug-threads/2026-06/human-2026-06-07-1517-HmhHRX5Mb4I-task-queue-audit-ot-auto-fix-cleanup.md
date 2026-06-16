---
name: task-queue-audit-ot-auto-fix-cleanup
description: Task queue audit found 153 open tasks (15 bot-filed); closed 17 WP-synced + 5 dups; all auto-filers now set priority + dedup; branch B wired to diff-loop for detector-config auto-fix tasks
human_involved: true
---

# Thread Summary: OT task queue audit + auto-fix workflow cleanup

_Source: spaces/AAQAVOjYc80 thread `HmhHRX5Mb4I` · 53 messages · 2026-06-07_
_Summarized: 2026-06-07 15:48 PT · last-msg-time: 2026-06-07T22:48:30Z_

## What was discussed

Operator flagged the "[OT auto-fix]" task accumulation and asked whether an autonomous workflow was closing them. Bot audited the full open queue (initially under-counted from paginated view → corrected to 147 open total, 15 bot-filed), identified 5 duplicates and 17 Workplace-post-synced tasks, closed them all, and fixed the underlying task-filer generators. Operator then directed adding a new rule: WP-synced tasks older than 14 days are safe to auto-close.

## Key decisions made

- **All 4 auto-filers must set `--priority`** (chronic→LOW, systemic-gap→MID, alert-monitor→MID, cron-health-guard→MID); UNKNOWN was the root of the proliferation complaint. (msg: 2026-06-07T22:23:50Z)
- **Live dedup-search added before every auto-file create** to prevent the 1-min race-dup that let T274601694/T274601711 both exist. State-cache alone insufficient. (msg: 2026-06-07T22:30:04Z)
- **4 fragmented chronic tasks consolidated → T274839082** (carries real-vs-diurnal investigation; the bot had named the consolidation "[ot-fleet-health]" but the filer was the bot — provenance imprecision flagged). (msg: 2026-06-07T22:27:08Z)
- **17 WP-post-synced tasks closed** — confirmed via "Synced to internal group post" marker in description (not just author), Butterfly Rule (group 1084744250286987) as generator. (msg: 2026-06-07T22:42:18Z)
- **Cheatsheet rule: WP-synced tasks >14d old = safe to auto-close** without per-task review; <14d may still be active, leave them; closing task never touches the WP post. (msg: 2026-06-07T22:44:39Z, operator-set)
- **Branch B added to ot-knowledge-distillation diff-loop** — processes `[OT auto-fix]` THRESHOLD_MISFIT/DETECTOR_BROKEN tasks → drafts configerator detector-tuning diff. Hard guardrails: configerator-only, prove-no-masking backtest required, `--draft` only, reviewer = detector owner, cap 1/run A-before-B. (msg: 2026-06-07T22:38:04Z)
- **Verify-create before retry** — bot filed T274822960 as an unverified-retry dup; lesson: check whether prior create succeeded (verify=0) before retrying. Now in cheatsheet as rule.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/capabilities/ot-alert-monitor.py` (step 3b) | added live dedup-search before auto-fix task create |
| `notes/.../team_bot/cron-jobs/ot-cron-health-guard.md` | generator root-fix task now names filer ("Auto-filed by ot-cron-health-guard") |
| `notes/.../team_bot/capabilities/file-systemic-gap-task.py` | priority already set ✓; verified |
| `notes/.../team_bot/cron-jobs/ot-knowledge-distillation.md` | branch B added (detector-config auto-fix path) |
| `notes/.../cheatsheets/meta-tasks.md` | new "Auto-filed tasks" section: set priority, verify-create-before-retry, N-correlated=one task, provenance #19, owner-only handhold; WP-sync auto-close rule (>14d) |

## Cluster / pattern references

_(No cluster IDs cited — not verified against failure-patterns.md)_

## Followup items (not yet done)

1. First branch-B run to confirm detector-config diff drafted + no-mask backtest actually ran (not assumed). Owner: dennyzhang / bot.
2. 10 remaining UNKNOWN-priority tasks are operator's own real OT work — priority triage is operator's call, not bot's.
3. T274839082 needs operator eyes on real-vs-diurnal baseline (the auto-answer mechanism still unbuilt).
4. WP-sync auto-close → mechanism: thin task-hygiene cron (the cheatsheet rule is spec; the cron is enforcement). Flagged in cheatsheet.

## Cross-refs

- SEVs discussed: none
- Posts: WP group 1084744250286987 (mrs.ot, source of Butterfly-synced tasks)
- Related threads: `sts0WrNeOBM` (provenance #19, task-filer sweep), `z65y10B925Y` (cron-health-guard rename)
