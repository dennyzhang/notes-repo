---
name: ZxcclsKXYbg
type: thread-summary
human_involved: true
thread_id: ZxcclsKXYbg
space: spaces/AAQAVOjYc80
msg_count: 5
date_range: 2026-05-06 17:11–17:27 PDT
summarized: 2026-06-02 12:43 PDT
last_msg_time: 2026-05-07T00:27:49Z
---

# Thread Summary: VDD HSTU `facebook_reels_vdd_hstu_v0` — FULL_SNAPSHOT Missing (gloo hang)

_Source: spaces/AAQAVOjYc80 thread `ZxcclsKXYbg` · 5 messages · 2026-05-06 17:11–17:27 PDT_
_Summarized: 2026-06-02 12:43 PDT · last-msg-time: 2026-05-07T00:27:49Z_

## What was discussed

Alert fired for model 877766818 (`facebook_reels_vdd_hstu_v0`): FULL_SNAPSHOT missing ~41h. Bot diagnosed a silent hang in attempt 7 of `mvai-training-online-877766818` at `dist.barrier(weight_processing_pg)` in `st_hstu_tgif_publish_mixin.py:1252` — same call that killed attempt 6 with gloo TCP timeout (1,200,000 ms). Attempt 7 was running 4+ days with no error and no new FULL_SNAPSHOT. Operator then added critical context: this is a SilverTorch model, so escalation should route to `home_ml_platform`, not `mrs_retrieval_u2i`. Operator also asked bot to create a SEV.

## Key decisions made

- **Routing correction (2026-05-07T00:26:34Z):** Operator clarified the model is SilverTorch-owned → escalation owner is `home_ml_platform`, not the `mrs_retrieval_u2i` oncall that model-series metadata implied. Bot did not know this at triage time.
- **Debug direction:** Investigate why attempt 7 is silently hung on the same barrier call that timed out in attempt 6.
- **SEV requested (2026-05-07T00:27:49Z):** Operator explicitly asked bot to create a SEV for the recurring `dist.barrier` hang.

## Files / artifacts touched

| path | what changed |
|---|---|
| `st_hstu_tgif_publish_mixin.py:1252` | Root site of gloo TCP barrier hang (code pointer only, not edited) |

## Cluster / pattern references

_(Omitted — CL-NNN not verified against failure-patterns.md)_

## Followup items (not yet done)

1. Debug silent hang in `mvai-training-online-877766818` attempt 7 — owner: `home_ml_platform` oncall
2. SEV creation for recurring `dist.barrier` hang — requested by operator, bot status unknown from thread

## Cross-refs

- SEVs discussed: none open at triage time (VERIFIED)
- Alert: OneDetection alert, `mrs_online_training` rotation
- Related threads: `IABOamE1VK4` (sibling model 877766873, same FULL_SNAPSHOT window)
