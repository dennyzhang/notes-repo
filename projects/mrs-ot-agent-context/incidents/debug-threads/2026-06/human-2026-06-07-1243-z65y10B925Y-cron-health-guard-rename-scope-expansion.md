---
name: cron-health-guard-rename-scope-expansion
description: ot-cron-health-watch renamed to ot-cron-health-guard (scope expanded to active mitigation + root-fix drafting); full coordinated migration across MANIFEST, 13 cross-refs, sqlite, KNOWN_RENAMED_AWAY
human_involved: true
---

# Thread Summary: ot-cron-health-watch → ot-cron-health-guard rename + scope expansion

_Source: spaces/AAQAVOjYc80 thread `z65y10B925Y` · 18 messages · 2026-06-07_
_Summarized: 2026-06-07 12:58 PT · last-msg-time: 2026-06-07T21:01:18Z_

## What was discussed

Operator asked what improvements the cron-health job had made for "this" (initially ambiguous — bot first guessed shift doc, then corrected to ot-cron-health-watch). Bot confirmed the job has two proactive levels: auto-mitigate transients (re-fire missing/hung/evergreen-killed jobs) + root-fix handoff for persistent agent-code failures (files task → diff-loop drafts fix). Operator then asked whether the job name should change to match the expanded scope; bot explained the migration cost and dependencies. Operator said "why ask" (act-don't-ask), triggering immediate rename.

## Key decisions made

- **Rename: `ot-cron-health-watch` → `ot-cron-health-guard`** — "watch" undersells the scope; "guard" matches `ot-disk-guard` convention for jobs that actively mitigate, not just detect. (msg: 2026-06-07T20:58:04Z, operator set via "why ask")
- **Full coordinated migration** (commit `1b8bfca1db1a`, all in one pass):
  - MANIFEST.json updated; prompt file renamed
  - 13 cross-referencing cron prompts updated (sev/alert/post-monitor, triage-auditor, prompt-change-validator, human-attention-brief, weekly-restart, oauth-refresher, channel-rollout, notes-deletion-watch, bot-volume-watch) + self-exclusion ref
  - `KNOWN_RENAMED_AWAY` got old id → drift gate won't flag it as a dropped job
  - sqlite: `setup-cron-jobs` auto-deleted orphaned old row, inserted the guard (enabled, next fire 22:00)
  - State file kept as `ot-cron-health-state.json` → guard inherits prior failure history (doesn't start blind)
- **Precedent: same dance as `ot-disk-watch` → `server-disk-guard`** — rename pattern is established.
- **What the guard actually does (verified in this thread)**:
  - Level 1: auto-mitigate transients (missing/hung/evergreen-kill → re-fire, bounded, idempotent, cool-down-guarded)
  - Level 2: persistent failure (≥3 consecutive) where root cause is agent's own code → files ONE deduped `ot-agent-self-improve` task → diff-loop (ot-knowledge-distillation) drafts `--draft` fix
  - Excludes: upstream API/infra/Claude session init/restart artifacts (not diff-fixable)
  - Real pass rate: ~98% once cron-stats counting bug fixed (old "86%" was miscounted)
- **Staged-not-live**: guard goes fully live on next daemon restart; currently staged in sqlite.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/cron-jobs/ot-cron-health-guard.md` | renamed from `ot-cron-health-watch.md`; all internal self-refs updated |
| `notes/.../team_bot/MANIFEST.json` | job id updated, KNOWN_RENAMED_AWAY entry added |
| 13 cross-referencing cron prompt `.md` files | old id → new id across the prompt tree |
| sqlite `jobs` table | guard row inserted, orphaned watch row auto-deleted |

## Cluster / pattern references

_(No cluster IDs cited — not verified against failure-patterns.md)_

## Followup items (not yet done)

1. First post-rename job_runs entry for `ot-cron-health-guard` to confirm it fires cleanly (proof that the migration worked, not assumed). Owner: bot / next daemon restart.
2. Root-fix loop hasn't fired on a real persistent-agent-code failure yet — first live end-to-end run is the proof point.
3. Daemon restart needed for staged changes to go live (weekly-restart or manual).

## Cross-refs

- SEVs discussed: none
- Related threads: `sts0WrNeOBM` (cron-health-guard filer provenance gap fixed), `HmhHRX5Mb4I` (cron-health-guard cross-ref updated in task-audit context)
