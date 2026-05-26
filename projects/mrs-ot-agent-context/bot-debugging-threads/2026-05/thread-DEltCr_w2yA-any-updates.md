# Thread Summary: Archive Cleanup Completion + failure-patterns.md Update

_Source: spaces/AAQAVOjYc80 thread `DEltCr_w2yA` · 4 messages · 2026-05-17T22:48:51Z – 2026-05-17T22:50:10Z_
_Summarized: 2026-05-18 00:33 PT · last-msg-time: 2026-05-17T22:50:10Z_

## What was discussed

Denny followed up asking "any updates?" on outstanding cleanup work. Bot reported completion of the 36 false-positive SEV archive removal (60 archives → 24), codification of a strict OT-title post-filter rule in the `ot-daily-learning-mitigated-sevs` cron, and a critical disk-full alert (`/dev/vda4` at 100%). Denny then asked whether `failure-patterns.md` needed updating, which the bot confirmed and reported as complete.

## Key decisions made

- **[22:49:12Z]** 36 false-positive backfill archives removed. Strict OT-title post-filter codified as step 4.5 in `ot-daily-learning-mitigated-sevs` cron. Required patterns: `online training` / `OT job` / `mvai-training-online-` / `teacher.*online`. Excluded: cogwheel-prefixed titles.
- **[22:49:12Z]** 9 true-OT SEV backfills retained: S663211, S663027, S664296, S662719, S658035, S657977, S664106, S657920, S659474.
- **[22:50:10Z]** `failure-patterns.md` updated: CL-017 escalated to ACCELERATING status (family-wide Shampoo NaN co-failure observed); CL-008 gained new sub-class (STUS `full_snapshot_publish_delay` false-PAGE on rare-cadence subtypes).

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/auto-learnings/failure-patterns.md` | CL-017 escalated to ACCELERATING; CL-008 new sub-class R14+R23; header updated to 2026-05-17 |
| `mrs-ot-agent-context/bot-debugging-threads/2026-05/` | 36 false-positive archives removed; 24 remain (15 verified + 9 true-OT stubs) |
| `tools/regen-archive-indexes.sh` | Fixed broken pointer (was looking for `failure-patterns.md` at old location, fixed to `auto-learnings/mega/registry/`); index regenerated: 24 archives · 16 mapped to clusters |
| `MISSING.md` | Updated: 57 out-of-scope SEVs grouped by rejection reason; explicit OT-rule documented |

## Cluster / pattern references

- [CL-017] — Optimizer state corruption (Shampoo NaN): escalated to ACCELERATING; new sub-mechanism #5 (family-wide simultaneous NaN in same `model_type_name`); new gap (per-model patching misses shared root when 2+ siblings co-fail)
- [CL-008] — STUS jobs mis-classified as trainer jobs: new sub-class added (m2130305043: `full_snapshot_publish_delay` false-PAGE when other snapshot subtypes publishing healthily); R23 codified

## Followup items (not yet done)

1. Tighten `fbcode//pe_mrs_ml/mrs_ot_agent/src/capabilities/team_lane_scope.py` upstream — `mtml`/`mvai` patterns too broad and `sev_type=Instagram` admitted by default leaks. Cron-side post-filter is the safer immediate fix; upstream needs tests against the 57-SEV regression fixture in MISSING.md. (owner: dennyzhang, status: open)
2. Disk cleanup: `/dev/vda4` at 100% (8,479 zombie `/tmp/.tmp*` dirs). (owner: dennyzhang, status: open at thread close time)

## Cross-refs

- SEVs discussed: S663211, S663027, S664296, S662719, S658035, S657977, S664106, S657920, S659474, S665135 (family-wide NaN), S665163
- Related threads: `FoMEj5Ql-ME` (STUS/R23 sub-class codification)
