---
name: human-2026-05-06-0209-EhGJO1jWA6g
human_involved: true
---

# Thread Summary: reels_ifu_mtml_v0 — FS blocking deltas, why is FS itself 28 min?

_Source: spaces/AAQAVOjYc80 thread `EhGJO1jWA6g` · 8 messages · 2026-05-06 02:09–09:09 PDT_
_Summarized: 2026-06-02 11:44 PT · last-msg-time: 2026-05-06T16:09:00Z_

## What was discussed

Two SPARSE_DELTA + DENSE_DELTA missing alerts fired at 01:21 and 01:26 PDT on model 883552231 (facebook_reels_ifu_mtml_v0). Bot diagnosed P01 (FULL_SNAPSHOT at 01:00:06 blocked delta publishing for ~26 min; self-resolved at 01:26:25) and validator confirmed. Operator then pushed for deeper triage: why was the full snapshot itself blocking for ~28 min, and what is the snapshot's size? Operator also requested a meta task and instructions on how to check fullsnapshot size.

## Key decisions made

- 2026-05-06T09:09:52Z alert: P01 (FS blocking deltas) confirmed; no immediate action needed since publishing self-resolved
- 2026-05-06T14:05:18Z operator correction: stopping at "FS blocked deltas" is insufficient — need to also diagnose why the FS window itself is ~28 min (model size? instance count? resource pressure?)
- 2026-05-06T16:08:28Z operator ask: file meta task capturing problem and suggestion
- 2026-05-06T16:09:00Z operator ask: check latest fullsnapshot size and teach how to query it

## Files / artifacts touched

| path | what changed |
|---|---|
| (none in thread) | — |

## Cluster / pattern references

- [CL-001] snapshot-stuck — this thread is an instance of FS-blocking-deltas (the common outcome), but reveals the next gap: bot doesn't triage root cause of FS duration itself

## Followup items (not yet done)

1. Determine model 883552231 fullsnapshot size (command: `meta ai.model.instance list --model-id=883552231 -l 5 --sort-by=creation_time --sort-order=desc` + inspect artifact size field) — owner: dennyzhang
2. File meta task capturing FS-duration investigation + threshold suggestion for this model — owner: dennyzhang
3. Add "why is FS slow" to triage depth checklist so bot goes one level deeper on CL-001 diagnoses

## Cross-refs

- SEVs discussed: none open
- Alerts: 1473457624222843, 1799789414004939 (OneDetection)
- Related threads: `drAQ_-nwhLg` (same model, alert threshold misconfiguration, same day)
