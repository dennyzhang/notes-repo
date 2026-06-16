---
name: mgrGZ8eH5MM
human_involved: true
type: human
date: 2026-05-07
---

# Thread Summary: IEN/Gloo TCP Timeout Hang + New Operator Rules

_Source: spaces/AAQAVOjYc80 thread `mgrGZ8eH5MM` · 12 messages · 2026-05-07_
_Summarized: 2026-06-02 13:43 PT · last-msg-time: 2026-05-07T23:44Z_

## What was discussed

Operator reported a recurring OT failure: `AIException: invoke_on_rank_and_broadcast_result failed` / Gloo TCP `unbound_buffer.cc:81` timed out after 3600000ms. No root fix existed. Operator traced the hang to `wait_for_weights_process_impl` — specifically the `run_until_complete(ien_weight_processing_task)` branch (no log of "Reuse existing IEN weight processing output" confirmed the non-reuse path). Operator wanted a meta task created to track (1) understanding the Scuba query roles Dave shared, (2) improving logging to pinpoint the exact hang location. Two new agent rules were also established in this thread.

## Key decisions made

- [2026-05-07T23:30Z] Track in a meta task: (a) understand Scuba query roles for Gloo/IEN hang, (b) improve logging inside `wait_for_weights_process_impl` to pinpoint hang location
- [2026-05-07T23:42Z] **New rule:** Never comment directly on a SEV — route via task or gchat thread only
- [2026-05-07T23:44Z] **New rule:** When creating a meta task, always assign to `dennyzhang` (operator); never assign to anyone else

## Files / artifacts touched

| path | what changed |
|---|---|
| (meta task, id not captured) | Created for IEN/Gloo hang tracking + Scuba follow-up |
| fbcode/...IEN weight processing code | `wait_for_weights_process_impl` identified as hang site; no code change in session |

## Cluster / pattern references

- [CL-014] — Gloo TCP timeout is a NCCL/collective communication timeout pattern; IEN weight processing hang is a variant worth tracking separately

## Followup items (not yet done)

1. Understand Scuba query roles for IEN/Gloo hang — owner: dennyzhang, status: task created
2. Improve logging in `wait_for_weights_process_impl` to surface exactly which await blocks — owner: TBD, status: task created

## Cross-refs

- Related threads: `hD-Qd1Dg_YQ` (same session, DPP package + agent rules)
