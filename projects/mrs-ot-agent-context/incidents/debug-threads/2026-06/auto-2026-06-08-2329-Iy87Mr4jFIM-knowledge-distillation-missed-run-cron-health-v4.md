---
human_involved: false
---
# Thread Summary: ot-knowledge-distillation + ot-triage-summary missed runs — Jun 8 Evergreen restarts, cron-health-guard v4 fix

_Source: spaces/AAQAVOjYc80 thread `Iy87Mr4jFIM` · 29 messages · 2026-06-08 23:29–2026-06-09 06:45 PDT_
_Summarized: 2026-06-09 23:04 PT · last-msg-time: 2026-06-09T06:45:57Z_

## What was discussed

ot-cron-health-guard alerted that ot-knowledge-distillation was 48.35h overdue. MyClaw diagnosed two-layer root cause: (1) scheduler recompute bug where `next_run = get_next(old_next_run)` instead of `get_next(now)` — any off-cycle run advances one real slot too far; (2) cron-health-guard auto-mitigation allowlist was interval-only, excluding all cron-type (daily/weekday) jobs, so `ot-triage-summary` and distillation fell in a detect-and-alert-only gap. The Jun 8 miss was reproduced live (manual recovery pushed triage-summary to Jun-10, skipping Jun-9). v4 retrigger-safe cron-type allowlist implemented and pushed to sqlite.

## Key decisions made

- [2026-06-09T06:38:06Z] Root insight: retrigger ≠ kill — kill-prohibited list guards SIGKILL-mid-write on a *running* cron; a `next_run=now` sqlite nudge on a not-running idempotent job has zero partial-write risk
- [2026-06-09T06:40:13Z] v4 fix: step 7.5 retrigger-safe allowlist (`ot-triage-summary`, `ot-knowledge-distillation`) gated on missing/evergreen_kill only, no-clean-run-since-slot, 6h dedup, 3/run cap; sqlite-nudge-not-CLI
- [2026-06-09T06:40:25Z] Recovery: triage-summary re-ran successfully, next_run corrected → Jun 9 09:30; distillation CLI recovery hung (known 2026-05-12 pattern) — killed, Jun-9 13:30 scheduled run covers the gap
- [2026-06-09T06:45:23Z] Deeper core bug (out of lane): `get_next(old_next_run)` recompute is myclaw-core; not yet at ≥3 escalation threshold; v4 retrigger is the compensating control

## Files / artifacts touched

| path | what changed |
|---|---|
| notes/.../cron-jobs/ot-cron-health-guard.md | v4 retrigger-safe allowlist added to step 7.5; matrix row + Safety section updated |
| sqlite (myclaw.db) | updates=1 via setup-cron-jobs.sh; v4 logic verified live |

## Cluster / pattern references

_(No CL-NNN in failure-patterns.md for scheduler/cron-health class)_

## Followup items (not yet done)

1. myclaw-core recompute bug `get_next(old_next_run)` — flagged for upstream; not yet escalated (below ≥3 threshold)

## Cross-refs

- Related threads: `k9UfpWApGWE` (prior cron-health recovery work)
