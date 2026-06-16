---
name: 3TmkLcROA0o
type: thread-summary
human_involved: true
thread_id: 3TmkLcROA0o
space: spaces/AAQAVOjYc80
msg_count: 5
date_range: 2026-05-07 10:07–10:22 PDT
summarized: 2026-06-02 12:43 PDT
last_msg_time: 2026-05-07T17:22:32Z
---

# Thread Summary: S660774 — Conveyor Blocked by Stale `light_cli` Prod Tag

_Source: spaces/AAQAVOjYc80 thread `3TmkLcROA0o` · 5 messages · 2026-05-07 10:07–10:22 PDT_
_Summarized: 2026-06-02 12:43 PDT · last-msg-time: 2026-05-07T17:22:32Z_

## What was discussed

Bot triaged S660774: conveyor blocked at "Check package size" since R37799 (09:09 PDT). Root cause identified as `light_cli` prod tag incorrectly set to v5359 — a Dec 2025 x86_64-only build (9.61 GiB) vs normal multi-arch builds (15–17 GiB). Size check detected 58.9% delta > 10% threshold and blocked the pipeline. Prod tag was updated to v5359 at 08:01 PDT, preceding the block by 68 minutes. Validator confirmed all 4 material claims. Bot then sent a "." (empty message) as a status post, which operator called out as noise. Operator also flagged repetitive content in bot output. Thread ended with operator showing the "conversation to diff" workflow to @Paul Lu.

## Key decisions made

- **Root cause confirmed (2026-05-07T17:07:50Z):** Wrong prod tag (v5359, single-arch) → size check baseline mismatch. Fix: re-point prod tag to correct multi-arch version.
- **Bot behavior corrections (2026-05-07T17:09:52Z, 17:15:16Z):** Operator explicitly called out: (1) bot posted a "." empty message with no purpose, (2) bot output contained repetitive content that adds no value. Both flagged as quality failures.

## Files / artifacts touched

| path | what changed |
|---|---|
| `light_cli` fbpkg prod tag | Should be updated to correct multi-arch version (action item, not confirmed done) |

## Cluster / pattern references

- Related: S658649 (same failure class — stale prod tag blocking conveyor, `ien.lower.mvai.cg1:prod`)

## Followup items (not yet done)

1. Re-point `light_cli` prod tag to correct version and rerun conveyor — owner: @trevormathisen (mrs_ml_release_oncall)
2. Audit what set prod tag to v5359 at 08:01 PDT
3. Add prod-tag gate to reject single-arch/size-anomalous versions

## Cross-refs

- SEVs discussed: S660774 (primary), S658649 (same failure class)
