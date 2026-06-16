---
name: jn_yaWyvYCw-s650346-ifr-esr-hedwig-end-loss
description: Triage of S650346 IFR ESR MC4 sparse delta streaming; Hedwig END message loss for arm2; validator confirmed
metadata:
  type: thread_summary
  human_involved: false
---

# Thread Summary: S650346 — IFR ESR MC4 sparse delta streaming low success rate (arm2 Hedwig loss)

_Source: spaces/AAQAVOjYc80 thread `jn_yaWyvYCw` · 3 messages · 2026-05-05_
_Summarized: 2026-06-02 08:43 PT · last-msg-time: 2026-05-05T04:10:27Z_

## What was discussed

Denny forwarded the alert for S650346 (mrs_online_training, L4, reopened 2026-05-04). The bot triaged the issue: arm2 (model 2128342260) sparse delta streaming was down again. Two prior fix series had been applied (dtype fix D101297690, Hedwig throughput-aware stream assignment D102669322 for arm3/2127973120, plus D101848845 and D101849806 for arm2). The bot's standing hypothesis at 82% confidence: Hedwig END message_sent drop for arm2 — message_received and message_applied were OK but message_sent was missing (reported by Li Lu 2026-05-04 20:08 PT). Validator confirmed all key claims and added additive context: arm2 had 3 prior fix series (not 2), strengthening the "distinct new failure mode" framing for the Hedwig loss hypothesis.

## Key decisions made

- [2026-05-05T04:09:33Z] Primary suspect: Hedwig END message loss for arm2 (2128342260). Page Sanket Karnik to check throughput-aware stream assignment for 2128342260 (D102669322 fixed 2127973120 only).
- Validator: arm2 had 3 prior fix series; tonight's failure is a new regression on already-patched arm2.

## Files / artifacts touched

| path | what changed |
|---|---|
| IFR ESR prod config | predictor_data_type=INT4 applied (D101297690) |
| Hedwig JK config | throughput-aware stream assignment for arm3/2127973120 (D102669322) — arm2 needs equivalent |

## Cluster / pattern references

_(omitted — cluster IDs not verified against failure-patterns.md)_

## Followup items (not yet done)

_(none explicit — next steps in triage: page Sanket Karnik, check Hedwig dashboard for 2128342260)_

## Cross-refs

- SEVs discussed: S650346, S658142 (same pipeline, may affect streaming config)
