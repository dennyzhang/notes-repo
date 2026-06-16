---
name: igxDlzYWHQA
human_involved: true
---

# Thread Summary: OT auto-fix diff automation + reinstall durability for new cron jobs

_Source: spaces/AAQAVOjYc80 thread `igxDlzYWHQA` · 10 messages · 2026-06-08 14:48–15:18 PDT_
_Summarized: 2026-06-08 22:05 PT · last-msg-time: 2026-06-08T22:18:57Z_

## What was discussed

Operator asked (14:48 PDT): "Do you have automation to create diffs for these tasks?" — referring to [OT auto-fix] tasks (e.g., T275008531 threshold tuning). Bot explained the partial automation: `ot-knowledge-distillation` step 3.5 branch B drafts configerator detector-tuning diffs for THRESHOLD_MISFIT/DETECTOR_BROKEN tasks (1 diff/run/day cap, mandatory no-mask backtest). Gap: no dedicated per-task diff-queue cron. Operator then directed (14:13 PDT): "Make the job survive from devserver reinstall and sync job eventually to fbcode." Bot verified durability of the two jobs built earlier that day.

## Key decisions made

- [2026-06-08T22:17 PDT] Durability requires fbcode, not just notes: `bootstrap.sh` reinstall reads the **fbcode** copy of `setup-cron-jobs.sh` + MANIFEST, so a job is reinstall-survivable only once mirrored to fbcode.
- [2026-06-08T22:18 PDT] `ot-diff-task-link-reconcile` — **already in fbcode** (`.md` + script + MANIFEST entry). Reinstall-survivable immediately. ✓
- [2026-06-08T22:18 PDT] `ot-sev-detection-gap-audit` — **notes-only** at time of thread. Will reach fbcode via `ot-notes-fbcode-commit` mirror cron (4×/day). No manual force-push — avoids dup-commit risk from state-based weekly-amend.

## Files / artifacts touched

| path | what changed |
|---|---|
| notes MANIFEST | `ot-diff-task-link-reconcile` + `ot-sev-detection-gap-audit` entries present |
| fbcode MANIFEST | `ot-diff-task-link-reconcile` entry confirmed present |

## Cluster / pattern references

_(no existing CL-NNN IDs found in known-patterns.md)_

## Followup items (not yet done)

1. Verify `ot-sev-detection-gap-audit` reached fbcode via the next mirror tick (4×/day); confirm via grep after the next `ot-notes-fbcode-commit` run.
2. Design and build the dedicated [OT auto-fix] task-queue → draft-diff cron (per-task, not once-daily, with no-mask backtest guardrail). Bot proposed bringing Denny the guardrail design before wiring live.

## Cross-refs

- Posts: none
- Related threads: `BRcxJ7gSLzA` (notes=ground-truth / fbcode=mirror operator decision 2026-06-02)
