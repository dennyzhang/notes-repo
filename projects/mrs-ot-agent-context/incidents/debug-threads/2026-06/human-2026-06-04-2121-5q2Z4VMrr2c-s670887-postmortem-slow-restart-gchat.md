---
name: s670887-postmortem-slow-restart-gchat
description: Operator surfaced bot had not read S670887's live gchat; headline finding is slow restart (~2h vs 30-min SLO) with 7/10 nodes hanging in fuse-overlayfs cleanup, not just the OOM trigger
metadata:
  type: project
human_involved: true
---

# Thread Summary: S670887 Postmortem — Slow Restart & Live GChat Gap

_Source: spaces/AAQAVOjYc80 thread `5q2Z4VMrr2c` · 7 messages · 2026-06-05 04:21–04:25 UTC_
_Summarized: 2026-06-05 21:44 PT · last-msg-time: 2026-06-05T04:25:10Z_

## What was discussed

Operator asked if bot had read the S670887 gchat conversation for the postmortem. Bot admitted it had not read S670887's live gchat (AAQA2hiGsrA) for the most recent postmortem — it had triaged off MAST error + SEV describe. Bot read the channel and found the headline issue is the slow restart (~2h vs 30-min SLO), not just the OOM trigger.

## Key decisions made

- **Postmortem headline = slow restart, not OOM** (at 04:25:10): 7/10 nodes hung in fuse-overlayfs cleanup at 07:08; SJD SIGABRT-killed them at 07:32:48; MAST didn't mark DEAD until 08:30 — a 57-min gap. Root class: S665454-class (light_cli not exiting when trainer dies).
- **Bot admitted triage gap** at 04:22:01: "my earlier triage captured the OOM trigger, but the conversation has since moved on and I had not read this latest evolution." The live gchat must be read for postmortems, not just SEV metadata.

## Files / artifacts touched

_(none — information gathering only)_

## Cluster / pattern references

_(no CL-NNN cluster confirmed for this thread — slow-restart pattern relates to S665454 but not yet codified)_

## Followup items (not yet done)

1. S670887 SEV report fields (MISSING_ROOT_CAUSE etc.) still empty — postmortem write-up pending (operator/Yucheng action). Bot offered to draft from the gchat conversation.
2. Diffs in flight: D98638473 (exit-clean) + D107459272 (exit logging) + D107413467→D107589212 (Fei's path); Yucheng building new base-layer. Need all three for the 57-min MAST-DEAD gap.

## Cross-refs

- SEVs: S670887 (GPU OOM zombie / slow restart), S665454 (light_cli exit class)
- Diffs: D98638473, D107459272, D107413467, D107589212
- GChat: AAQA2hiGsrA (S670887 live room), AAQAm9VXChs (S672114 room — empty/no access)
- Debug vehicle: `mvai-training-online-2121434823` v11
