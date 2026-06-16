---
name: xchDL8SVGDI
human_involved: true
thread_id: xchDL8SVGDI
space: spaces/AAQAVOjYc80
msg_count: 10
date_range: 2026-05-08T20:48Z — 2026-05-09T04:22Z
---

# Thread Summary: IG Post Triage — OT/Root Model Health (csanghera)

_Source: spaces/AAQAVOjYc80 thread `xchDL8SVGDI` · 10 messages · 2026-05-08T20:48Z–2026-05-09T04:22Z_
_Summarized: 2026-06-02 16:43 PT · last-msg-time: 2026-05-09T04:22Z_

## What was discussed

Calvin Sanghera posted in mrs.ot about poor source rate metrics for 2 IG retrieval arms (model 2125399403 AMD+ST2.0+inplace, model 2125249288 AMD+ST2.0). Bot diagnosed a stalled recurring training run — 19h vs 6h baseline — as the cause. Validator caught that the run had actually SUCCEEDED and a new run was already in flight, invalidating the staleness hypothesis. True cause was S661169 (AMD snapshots rejected on AMD hardware). Operator then pushed bot to check user replies, debug why full snapshot was missing, and create a summary.

## Key decisions made

- (2026-05-08T20:51Z validator) "stalled training job" hypothesis invalidated — f1078664497 completed normally at 19.4h; updated root cause to S661169 AMD rejection
- (2026-05-09T00:09Z operator) bot was asked to debug why full snapshot didn't generate — implying validator correction alone wasn't enough for operator
- Bot should have proactively checked for S661169 before asserting training staleness; confidence score (85%) was too high given unverified model_entity_id linkage

## Files / artifacts touched

| path | what changed |
|---|---|
| N/A (triage-only thread) | no notes files written in this thread |

## Cluster / pattern references

_(No verified CL-NNN clusters in failure-patterns.md — omitted to avoid fabrication)_

- Related: S661169 (AMD snapshots rejected on AMD hardware, In Progress, igr_retrieval oncall)
- Related: S661170 (GPU quota rejection, Mitigated May 8)

## Followup items (not yet done)

_(None explicitly committed in thread)_

## Cross-refs

- SEVs: S661169, S661170
- Posts: wp/groups/mrs.ot/permalink/1320816783346398
- Model series: 2125399403, 2125249288
- MAST: fire-csanghera-f1078664497, f1079108064 (follow-on run)
