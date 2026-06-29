---
name: s663484-lsr-sev-postmortem
description: SEV postmortem for S663484 (Threads LSR prod teacher OT failure), bot self-corrects inferred model ID and wrong-access-method errors
metadata:
  type: project
  thread_id: ByPlnIGg0ks
  human_involved: false
---

# Thread Summary: S663484 SEV Postmortem — Threads LSR Teacher OT Failure

_Source: spaces/AAQAVOjYc80 thread `ByPlnIGg0ks` · 9 messages · 2026-06-15_
_Summarized: 2026-06-17 11:15 PT · last-msg-time: 2026-06-16T04:16:24Z_

## What was discussed

Postmortem cron's digest for S663484 (Threads LSR prod teacher, L4, 11.9h, owner Haoyu Wu). Postmortem fields were all empty (non-required SEV4/false-positive/preemptive/merged), so only recurrence signal was available. The bot self-identified that it had propagated three wrong values in the same turn: wrong `--space-name` vs `--space-id`, wrong notes path vs runtime path, and an inferred model ID (2128461909) that resolved to 2128461099 via ground-truth from S664106's title.

## Key decisions made

- **Model grouping caveat** (04:15:23): S664106 is the *Feed* teacher (2128461099); S663484 is the *LSR* prod teacher (no confirmed ID in its record) — possibly different models. T276010371's step 1 = confirm grouping before anchoring a recurrence metric.
- **Task corrected**: T276010371 updated with correct model ID (2128461099 replacing wrong 2128461909) and caveat about Feed vs LSR distinction.
- **Self-diagnosis** (04:16:24): Bot committed to always resolving every ID against the ground-truth entity record before it enters a task, diff, or report. "Verify with the exact flag/path the source uses."

## Files / artifacts touched

| path | what changed |
|---|---|
| ~/notes/.../incidents/resolved-sevs/2026-06/L4-2026-06-15-S663484.md | written by postmortem cron (degraded — all postmortem fields empty) |
| T276010371 | corrected model ID + grouping caveat |

## Cluster / pattern references

- [CL-009] — S663484 marked [INFERRED] CL-009 (OT auto-start silent stall); unverifiable given empty postmortem fields

## Followup items (not yet done)

1. Once S673655 resolves and its postmortem is filed, classify S663484 as P62/PT2-recompile vs MVAI-expiry sub-class (owner: oncall, no deadline set)

## Cross-refs

- SEVs discussed: S663484, S664106, S673655
- Related threads: `D1nJtPfn66Q` (same cron run, post postmortem)
