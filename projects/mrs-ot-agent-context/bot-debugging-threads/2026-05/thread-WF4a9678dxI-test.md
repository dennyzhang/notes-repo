# Thread Summary: Model 886797001 (ifr_main_mtml) — DPP 20-day session restart

_Source: spaces/AAQAVOjYc80 thread `WF4a9678dxI` · 4 messages · 2026-05-23T02:53Z → 2026-05-23T02:55Z_
_Summarized: 2026-05-23 21:47 PT · last-msg-time: 2026-05-23T02:55:37Z_

## What was discussed

IFR Watchtower alert for model 886797001 (ifr_main_mtml) fired for too few SPARSE_DELTA/DENSE_DELTA snapshots. Root cause: DPP hit the 20-day (1,728,000s) max session lifetime, triggering a planned restart. Attempt 1 bootstrapped in ~15 min and resumed before the alert fired. Bot triage verdict was correct but thin on evidence — Denny's reference triage revealed 3 missing checklist categories (mvai_metrics gap_min, prior_SEVs, sibling_sevs_7d). A live S666788 SEV3 on the same pipeline was flagged as a real follow-up.

## Key decisions made

- **2026-05-23T02:55:09Z** — Verdict 🟢 TRANSIENT_NOISE / auto-resolved: DPP 20-day fence is expected behavior. Attempt 1 RUNNING since 18:51 PDT. No OT infrastructure issue.
- **2026-05-23T02:55:37Z** — Bot acknowledged triage was correct but missed 3 evidence categories. Rules 12-16 added to `gotcha_triage-discipline.md`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `memory/gotcha_triage-discipline.md` | Rules 12-16 added (mvai_metrics gap_min, prior_SEVs checks) |
| paste P2348441406 | Machine fields |

## Cluster / pattern references

_(No CL match — DPP 20-day restart is expected/planned behavior, not a failure pattern)_

## Followup items (not yet done)

1. Verify S666788 ("mvai/mvai_ifr_main blocked by publish timeout", SEV3, time_mitigated=empty) with wenshunliu — separate from this alert but same pipeline.

## Cross-refs

- SEVs discussed: S666788 (SEV3, in-progress, unrelated root cause)
- Posts: none
- Related threads: none
