---
name: human-2026-06-08-0926-nFVlLHvDlYE
description: AI Playbook "My workflows" tab update; operator corrected stale "broken" entry and proposed new stable/WIP additions
metadata:
  type: project
  human_involved: true
---

# Thread Summary: AI Playbook "My workflows" Bot Job Classification

_Source: spaces/AAQAVOjYc80 thread `nFVlLHvDlYE` · 10 messages · 2026-06-08 16:26–17:53 UTC_
_Summarized: 2026-06-08 21:06 PT · last-msg-time: 2026-06-08T17:53:31Z_

## What was discussed

Operator instructed bot to reply in-thread. Bot scheduled a one-shot cron (`oneshot-aiplaybook-workflows`) to fire ~09:51 PDT, read the AI Playbook "My workflows" tab, classify all enabled OT cron jobs as stable vs maturing, and propose additions in-thread. The one-shot fired on time (verified: new jobs discovered live, no daemon restart needed). It proposed two clusters: STABLE (real-time triage triad, morning attention brief, oncall shift gdoc, tag hygiene, P/R rollup, knowledge distillation, incident summaries) and MATURING (postmortem harvesters, debug quality scoring, fleet health, weekly reliability digest, fbpkg cap watch). Operator reviewed and provided corrections:

- ⚠ "OT alert investigator — broken since 2026-06-01" is stale — `ot-alert-monitor` triaged 2 clusters that morning with a multi-lens validator panel. Should be moved to Prod or clarified (stale entry = active component misrepresented).
- Proposed additional Prod entries: Real-time triage (continuous 15-min SEV/alert/post loop), Self-audit (30-min R-rule auditor + debug-quality scoring), Accuracy scorecard (daily auto-tag P/R).
- Proposed WIP addition: Model fleet health (4-hourly zombie scan).

## Key decisions made

- **2026-06-08T17:53Z** — "verify-before-trust": bot must verify before stating a component is "broken"; `ot-alert-monitor` was live and correct; stale archive notes ≠ ground truth.
- One-shot cron mechanism confirmed working for delayed read-and-propose tasks (daemon discovers new jobs live, no restart needed — contradicts prior `cron-changes-staged-not-live-until-restart` memory for inserts specifically).

## Files / artifacts touched

| path | what changed |
|---|---|
| AI Playbook gdoc "My workflows" tab | (proposed, not yet written) add Prod: real-time triage, self-audit, accuracy scorecard; WIP: model fleet health; fix/remove "broken" alert investigator entry |

## Cluster / pattern references

- [[detector-calibration-verify-source]] — stale "broken" entry = same class as mis-reading stale archive notes before verifying

## Followup items (not yet done)

1. Write the proposed additions into the AI Playbook "My workflows" tab (stable→Prod, fleet-health→WIP, bullet style matching existing entries). Operator offered to confirm. Status: open.
2. Correct/remove "OT alert investigator — broken since 2026-06-01" entry. Status: open.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `bdWoAmWkpIk` (same session; thread-reply correction)
