---
name: 2KSYKVhujNQ-s673995-p017-task
description: S673995 light_cli conveyor OOM — bot applies P-017, files decisive-metric task T275290769
metadata:
  type: project
human_involved: false
---

# Thread Summary: S673995 (light_cli OOM) + P-017 Decisive-Metric Task

_Source: spaces/AAQAVOjYc80 thread `2KSYKVhujNQ` · 4 messages · 2026-06-10_
_Summarized: 2026-06-10 22:10 PT · last-msg-time: 2026-06-10T14:32:52Z_

## What was discussed

Operator posted the cron's triage verdict for S673995 (light_cli conveyor blocked by Sandcastle OOM during cogwheel QPS harness build, ~03:41 PDT). The verdict correctly classified it as a trunk-health class owned by trevormathisen/mrs_ml_release_oncall, monitor-only, no OT escalation needed. Bot then recognized the surfaced evidence — 8 light_cli build SEVs in 30 days (~2/week) — as a textbook P-017 recurring+upstream class and autonomously filed a decisive-metric task to track recurrence rate rather than re-triaging each instance.

## Key decisions made

- [2026-06-10T14:32:14Z] Bot determined no existing decisive-metric task for the light_cli build-OOM class → filed T275290769 (owner=dennyzhang, handed to mrs_ml_release_oncall/trevormathisen)
- [2026-06-10T14:32:52Z] P-017 applied: going forward, bot monitors the weekly light_cli-SEV count metric rather than re-narrating each recurrence

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — task filed via meta CLI) | T275290769 created |

## Cluster / pattern references

_(No confirmed CL-NNN cluster IDs — omitted)_

- [P-017] — recurring + high-confidence + upstream issue → one decisive-metric task, then monitor; do not re-narrate each recurrence

## Followup items (not yet done)

1. T275290769 — build decisive metric (weekly count of light_cli conveyor-blocking SEVs + conveyor-block duration) and monitor; acceptance test = rate drops after mrs_ml_release_oncall hardens the build infra. Owner: dennyzhang → route to trevormathisen.

## Cross-refs

- SEVs discussed: S673995 (active at time of thread), S673405 (ruled out)
- Related threads: _(none known)_
