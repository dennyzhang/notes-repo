# Thread Summary: Workplace Post Digest — P59 Pending + P60 Proposed (ADHOC-Tier Starcart Skip)

_Source: spaces/AAQAVOjYc80 thread `doVRPYg2fp0` · 6 messages · 2026-05-23T21:42–21:43Z_
_Summarized: 2026-05-23 23:47 PT · last-msg-time: 2026-05-23T21:43:26Z_

## What was discussed

Denny ran a Workplace post digest covering two posts. W1324729222955154 (Yu Liu, model 2135033479 snapshot-stuck 4h) confirmed CL-001 with a proposed P59 (`_preload_item_pool` deadlock → DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE); root cause included cold-start regression from clearing info.json. W1326836659411077 (Renqin Cai, model 2124118880 starcart not auto-starting) was classified as CL-009 and generated a new P60 proposal: ADHOC-tier models silently skip starcart auto-start with no error. The bot logged P60 as a memory gotcha immediately.

## Key decisions made

- **[21:42:40Z] P60 formally proposed** — ADHOC-tier OT model blocks starcart auto-start. Verify: `mvai online-training-mgr print -m <ID>` → tier=ADHOC. Fix: promote to PROD. Not yet in known_patterns.md Quick-Match; pending operator approval.
- **[21:42:40Z] P59 stays "proposed"** — already in failure-patterns.md CL-014 evidence section; won't enter Quick-Match Table until formally approved by Denny.
- **[21:43:26Z] mast_job_id lane taxonomy too coarse** — 5/5 posts hit same lane label but span 3 distinct clusters (CL-001, CL-013, CL-009). Finer lane taxonomy (e.g. `snapshot_publish_stuck`, `example_age_growth`, `auto_start_no_op`) needed for chronic-source signal to be actionable.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../resolved-posts/2026-05/2026-05-14-W1324729222955154.md` | existing archive — upsert skipped (richer) |
| `~/notes/.../resolved-posts/2026-05/2026-05-16-W1326836659411077.md` | created; pending @renqincai confirm |
| `memory/gotcha_adhoc-tier-starcart-skip.md` | created same session |

## Cluster / pattern references

- [CL-001] — snapshot-stuck; W1324729222955154 (model 2135033479)
- [CL-009] — OT auto-start stall; W1326836659411077 (model 2124118880, ADHOC-tier variant → P60)

## Followup items (not yet done)

1. Approve P60 → move into known_patterns.md Quick-Match Table. (Owner: dennyzhang, Status: proposed)
2. Approve P59 → promote from failure-patterns.md evidence to Quick-Match. (Owner: dennyzhang, Status: proposed)
3. Finer mast_job_id lane taxonomy design (snapshot_publish_stuck / example_age_growth / auto_start_no_op). (Owner: dennyzhang, Status: open idea)

## Cross-refs

- SEVs discussed: (none)
- Posts: W1324729222955154, W1326836659411077
- Related threads: `8LLIVF1l7Yw` (starcart/TMS concepts), `BzwgIQr_f48` (failure-patterns consolidation)
