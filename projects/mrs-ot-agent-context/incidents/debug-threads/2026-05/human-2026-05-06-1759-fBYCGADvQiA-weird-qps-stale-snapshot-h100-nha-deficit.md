---
name: fBYCGADvQiA
type: thread-summary
human_involved: true
thread_id: fBYCGADvQiA
space: spaces/AAQAVOjYc80
msg_count: 4
date_range: 2026-05-06 17:59–18:11 PDT
summarized: 2026-06-02 12:43 PDT
last_msg_time: 2026-05-07T01:11:44Z
---

# Thread Summary: Weird Training QPS + Stale Snapshot — H100 NHA Deficit (S659877)

_Source: spaces/AAQAVOjYc80 thread `fBYCGADvQiA` · 4 messages · 2026-05-06 17:59–18:11 PDT_
_Summarized: 2026-06-02 12:43 PDT · last-msg-time: 2026-05-07T01:11:44Z_

## What was discussed

Kedong He posted to mrs.ot Workplace about QPS drop and stale snapshot for `facebook_reels_vdd_hstu_v0` root model training. Bot triaged: both MAST jobs (training + publisher) RUNNING without crash errors. Root cause pointed to S659877 — H100 NHA quota deficit (-2.875) blocking QE transitions and snapshot publish. Spiky near-zero QPS consistent with DPP data starvation under constrained compute. Validator confirmed core facts but flagged the cross-org causation (IGML H100 → Video VDD publish) as inferred, not directly proven. Thread ended with operator asking the bot to explain snapshot publish failure in more depth.

## Key decisions made

- **Two-issue framing (2026-05-07T01:05:31Z):** Training QPS drop (DPP starvation) and snapshot publish failure (H100 capacity → QE block) treated as coupled but distinct, both downstream of S659877.
- **Validator caveat (2026-05-07T01:08:30Z):** Cross-org causation (IGML H100 → Video VDD) explicitly flagged as inferred; recommended kedhe verify with guanj directly.

## Files / artifacts touched

| path | what changed |
|---|---|
| N/A | Read-only triage; no code touched |

## Cluster / pattern references

_(Omitted — CL-NNN not verified against failure-patterns.md)_

## Followup items (not yet done)

1. Operator asked for deeper explanation of snapshot publish failure — thread ended before answer was delivered

## Cross-refs

- SEVs discussed: S659877 (IGML H100 NHA deficit), S660484 (Threads LSR MB4 publishing), S659492 (video_udd_lsr cogwheel NE)
- Posts: W1319390770155666 (mrs.ot Workplace post by Kedong He)
- Related threads: `ZxcclsKXYbg`, `IABOamE1VK4` (same model family, overlapping time window)
