---
name: human-2026-06-07-0053-u5Ix-ci7K3c-debug-agent-challenging-problems-and-thread-routing
description: Operator asked about the hardest problems in debug-agent world; bot answered with 5 categories (confidently-wrong root cause, keyhole data, depth, non-reproducibility, no learning). Operator correction on thread routing triggered a live verify-before-claiming demonstration.
metadata:
  type: human
  thread_id: u5Ix-ci7K3c
  space: spaces/AAQAVOjYc80
  human_involved: true
  first_msg_time_pt: 2026-06-07 00:53 PDT
  last_msg_time_utc: 2026-06-07T07:56:14Z
  msg_count: 6
---

# Thread Summary: Debug Agent Hardest Problems + Thread-Routing Verification

_Source: spaces/AAQAVOjYc80 thread `u5Ix-ci7K3c` · 6 messages · 2026-06-07 00:53–00:56 PDT_
_Summarized: 2026-06-07 21:46 PDT · last-msg-time: 2026-06-07T07:56:14Z_

## What was discussed

Operator asked "what is the most challenging problems and solutions in debug agent world." Bot answered with 5 categories. Operator then corrected thread routing ("you should reply to the thread per gchat cheatsheet"), and bot loaded the cheatsheet then verified from the message log that replies *were* landing in the correct thread. The verification changed the diagnosis: no threading bug, bot was already threaded correctly — the daemon's delivery was working. A latent gap was surfaced: the thread-routing hook enforces in-session sends (which can't happen in this CLI), but does *not* enforce the daemon's delivery threading — narrower coverage than the "✓" in feedback-coach implies.

## Key decisions made

- [00:53:29 PDT, operator] Thread routing directive: load gchat cheatsheet before replying.
- [00:56:14 PDT, bot] Diagnosis revised after verify: replies ARE landing in u5Ix-ci7K3c. What appeared as a bug is working behavior. The hook coverage is narrower than "✓" implies — daemon threading is unhooked (currently latent, not active bug). Status downgraded accordingly.

## Files / artifacts touched

_(none — conversational thread, no file edits)_

## Cluster / pattern references

- No CL-NNN applicable — this is meta/agent-design content, not an OT incident.

## Followup items (not yet done)

_(none explicitly committed)_

## Cross-refs

- Related threads: none
- Concepts: verify-before-claiming lever, P-002 (act don't ask), confidently-wrong diagnosis as the central debug-agent risk
