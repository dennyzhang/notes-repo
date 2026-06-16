---
name: human--QStSpCVGkE-s659181-inference-not-ot-scope
description: Bot triaged S659181 (FB Feed sigrid predictor serving errors) as OT; operator corrected — inference-stage serving errors are not OT SEVs
metadata:
  type: project
  thread_id: -QStSpCVGkE
  human_involved: true
---

# Thread Summary: S659181 — Inference-Stage Serving Error Misclassified as OT

_Source: spaces/AAQAVOjYc80 thread `-QStSpCVGkE` · 12 messages · 2026-05-05 07:04–10:21 PDT_
_Summarized: 2026-06-02 09:43 PT · last-msg-time: 2026-05-05T17:21:02Z_

## What was discussed

S659181 (L3, mvai_serving signal) — high error rate from `facebook_cfr_feed_mtml_userfm` models in VCN and TTX regions — was posted to the OT space and bot triaged it at confidence 0.55, noting it had only metadata (GChat unreadable, report fields empty). Bot hypothesized bad/corrupt model artifacts in VCN+TTX tied to a prior snapshot push. Operator then explicitly corrected: "this SEV is an inference stage SEV instead of training stage. So it's not an OT SEV." After the scope correction, operator shifted to diff work: directed bot to create a new diff, include SEV postmortem learnings, add future prevention for "sloppiness" issues, validate the changes, and adjust claude_idle_timeout.

## Key decisions made

- Inference-stage serving errors (predictor error rate, model serving failures) are NOT OT SEVs — training and serving are distinct stages; OT scope is training-side only [14:32 PDT, explicit correction]
- `mvai_serving` signal tag alone does not make a SEV OT-relevant [implicit]
- SEV postmortem diff should include future-prevention instructions for scope sloppiness [16:08 PDT]

## Files / artifacts touched

| path | what changed |
|---|---|
| (diff created, number not confirmed in thread) | Postmortem learnings + future-prevention section |

## Cluster / pattern references

_(no verified cluster IDs)_

## Followup items (not yet done)

_(none explicit after the 17:21 idle-timeout request)_

## Cross-refs

- SEVs discussed: S659181 (L3 In Progress — Feed sigrid predictor VCN/TTX error rate), S658142 (L4 mtml packaging regression, cross-ref cited in triage)
- Related threads: none
