---
name: IABOamE1VK4
type: thread-summary
human_involved: false
thread_id: IABOamE1VK4
space: spaces/AAQAVOjYc80
msg_count: 3
date_range: 2026-05-06 19:14–19:18 PDT
summarized: 2026-06-02 12:43 PDT
last_msg_time: 2026-05-07T02:18:10Z
---

# Thread Summary: VDD HSTU Model 877766873 — FULL_SNAPSHOT Missing (DPP Starvation Cascade)

_Source: spaces/AAQAVOjYc80 thread `IABOamE1VK4` · 3 messages · 2026-05-06 19:14–19:18 PDT_
_Summarized: 2026-06-02 12:43 PDT · last-msg-time: 2026-05-07T02:18:10Z_

## What was discussed

Alert for model 877766873 (`facebook_reels_vdd_hstu_v0`): FULL_SNAPSHOT missing ~43h. Bot diagnosed a cascade: DPP starvation in training job `mvai-training-online-877766932` (`DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE`) blocked FULL_SNAPSHOT publish for both inference models 877766873 and 877766818 (sibling from `ZxcclsKXYbg`), which both stopped publishing within 5 minutes of each other on 2026-05-04 23:37/23:42 UTC. Training job 877766932 was in rapid retry loop with accelerating failure durations (278h→114h→54h→11h→2h). Validator confirmed all material claims independently.

## Key decisions made

- **Cascade identified (2026-05-07T02:16:52Z):** Synchronized FS cutoff for both models (5-min window) confirms shared upstream cause, not per-model issue. DPP starvation in 877766932 is the upstream blocker.
- **Alert tuning needed (2026-05-07T02:16:52Z):** 877766873 has only 2 historical FS events; alert threshold is miscalibrated for bootstrap phase.

## Files / artifacts touched

| path | what changed |
|---|---|
| `minimal_viable_ai/sandbox/umia_hstu/train.py:512` | Code pointer for DPP starvation path (not edited) |
| `pytorch/data/fb/disaggregated_dpp_reading_service.py:441` | Code pointer for DPP output queue failure (not edited) |

## Cluster / pattern references

_(Omitted — CL-NNN not verified against failure-patterns.md)_

## Followup items (not yet done)

## Cross-refs

- Related threads: `ZxcclsKXYbg` (sibling model 877766818, same FS cutoff window)
- MAST jobs: `mvai-training-online-877766873` (v19 atm6), `mvai-training-online-877766932` (v6, rapid retry)
