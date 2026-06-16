---
human_involved: false
---

# Thread Summary: ot-alert-monitor digest — 5 alerts triaged (2026-06-03/04)

_Source: spaces/AAQAVOjYc80 thread `gm78FcukgXg` · 4 messages · 2026-06-04 05:17 UTC_
_Summarized: 2026-06-04 21:45 PT · last-msg-time: 2026-06-04T05:17:35Z_

## What was discussed

Cron output from `ot-alert-monitor` triaging 5 alerts. Pattern analysis identified a P23 recurrence for model 877766818 (facebook_reels_vdd_hstu_v0). Validator was unavailable in this cron context (no Agent tool); digest published unvalidated.

## Key decisions made

- **A1306814721539638 (IG MTML AGG):** NO_ACTION — IG-owned; mrs_online_training is follower only. Timestamp: 2026-06-04T05:17 UTC.
- **A902257976006165 (vdd_hstu_v0 FULL_SNAPSHOT):** P23 confirmed (Manifold kClientShardSizeThrottled, 2nd recurrence within 48h since Jun 1 incident) — charlesz notified to request Manifold per-shard quota increase for training model 877766932. Timestamp: 2026-06-04T05:17:29Z.
- **A1455336899399360 (ig_textpost M2M retrieval):** recurring FULL_SNAPSHOT miss (linked to S670384 + 4 prior archives); investigate `mvai online-training-mgr print -m 2130324780`. No resolution verified (purged from feed).
- **A1955974545038771 (reels I2I re-fire):** existing archive from 2026-05-16 supersedes; no new archive written.
- **Validator gap noted** in cron output: Agent tool not available in cron execution context — represents a recurring auditability limitation.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../resolved-alerts/2026-06/high-2026-06-02-A1306814721539638.md` | auto-written |
| `notes/.../resolved-alerts/2026-06/unknown-2026-06-03-A1455336899399360.md` | auto-written |
| `notes/.../resolved-alerts/2026-06/unknown-2026-06-03-A902257976006165.md` | auto-written |
| `notes/.../resolved-alerts/2026-06/unknown-2026-06-03-A1558388828479222.md` | auto-written |

## Cluster / pattern references

- P23 — Manifold kClientShardSizeThrottled (confirmed for A902257976006165, 2nd recurrence model 877766818 in 48h)

## Followup items (not yet done)

1. A1455336899399360: investigate recurring FULL_SNAPSHOT miss for ig_textpost M2M retrieval model 2130324780. Owner: mrs_online_training oncall. Status: open.
2. A902257976006165: charlesz to request Manifold quota increase for training model 877766932. Status: notified, unconfirmed.

## Cross-refs

- SEVs discussed: S670384 (recurring FULL_SNAPSHOT miss context)
- Related threads: none
