# Thread Summary: SEV Tag Audit + PG Field + CLUSTERS.md Major Refactor

_Source: spaces/AAQAVOjYc80 thread `ZP2y-6Bdpwk` · 91 messages · 2026-05-16 21:28 – 2026-05-17 01:23 UTC_
_Summarized: 2026-05-17 13:31 PT · last-msg-time: 2026-05-17T01:23:50Z_

## What was discussed

Four interlocked workstreams in a single long session:

1. **SEV tag audit** — Operator noticed `S655556` and `S656088` were false-positive OT SEVs. Bot audited all 116 `mvai-online-training`-tagged SEVs (W17–W20): 12 confirmed false positives, 17 unclear. Tagger attribution: dennyzhang manual (5), Butterfly auto via impacted_areas keyword (6), asrivas/Ads (1). Bot auto-tagger was exonerated (zero FPs).

2. **PG (Product Group) field** — `sev_type` field in SEV metadata maps to PG. Operator requested adding a `pg` dimension to sev/alert/post-monitor cron outputs. Mapping: IG, Threads, Video, Facebook, infra-cross-pg, unknown. `Production` sev_type → `infra-cross-pg`. `Multifeed` → `Facebook`.

3. **CLUSTERS.md refactoring** — Multiple critique-and-fix iterations. Audience explicitly: tech leads and managers. Changes: removed redundant Status snapshot table, added PG breakdowns to all 12 clusters, reordered by gap size, added new clusters (CL-015 QPS dip, CL-016 slow QPS start, CL-017 Shampoo NaN cascade). Leadership asks section trimmed (CL-004 already aligned = FYI only).

4. **Session bash tool failure** — CWD was set to deleted dir `AAQAWs06mYI` instead of `AAQAVOjYc80`. Operator restarted daemon to fix. Tier 2 `impacted_areas` gate (scope_check.py enhancement) was designed but not implemented due to this breakage.

## Key decisions made

- **2026-05-16T22:10Z** — "do them all. again - ack, don't ask if unnecessary" → audit all 116 SEVs + update scope_check identification code.
- **2026-05-16T23:27Z** — "3" → implement Tier 2 impacted_areas gate (blocked by bash failure; deferred to next session).
- **2026-05-17T00:20Z** — "change Multifeed to facebook PG" then "use infra-cross-pg" → two sequential naming decisions; final: `Production → infra-cross-pg`.
- **2026-05-17T00:21Z** — "PG reference table should be at the top" of CLUSTERS.md.
- **2026-05-17T00:49Z** — "once it done, attack it again" → iterative critique loop enforced for CLUSTERS.md.
- **2026-05-17T01:23Z** — "once are you done, attack it again. then push to notes repo" — session ended mid-task.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/expert-observations/2026-05-16-all-time-sev-tag-audit.md` | Created; 147 SEVs Jan–May 2026, 12 FP (8.2%), monthly trend, tagger attribution |
| `mrs-ot-agent-context/mega-learnings/registry/CLUSTERS.md` | Major refactor: PG breakdowns, gap-size ordering, new clusters CL-015/016, leadership-asks trimmed |
| `cron-jobs/ot-sev-monitor.md` + `ot-alert-monitor.md` + `ot-post-monitor.md` | `pg` field added to JSON output schema; PG derivation rules embedded |

Commits: `5aa9505`, `203b870`, `9b12727`, `1564d215`, `fbc3cd80`, `3201a96f`, `952aa83c`, `db7cb8b8`, and others.

## Cluster / pattern references

- [CL-001] — FULL_SNAPSHOT snapshot-stuck; PG breakdown added (IG×7, Facebook×1, Threads×1)
- [CL-004] — Cogwheel/conveyor publish failures; scope corrected to trunk-health workstream, OT on-demand only, cadence ~2/week medium
- [CL-013] — Training-age spike; confirmed top OT symptom, accelerating
- [CL-017] — Shampoo NaN cascade; new cluster added this session

## Followup items (not yet done)

1. Tier 2 impacted_areas gate in `team_lane_scope.py` — designed, unimplemented; blocked by session bash failure. Resume in next session.

## Cross-refs

- SEVs discussed: S655556, S656088, S657546, S658534, S664106
- Related threads: `_c2kI6nNMzQ` (archive completeness), `xELpXuo0m2Q` (RULES.md context)
