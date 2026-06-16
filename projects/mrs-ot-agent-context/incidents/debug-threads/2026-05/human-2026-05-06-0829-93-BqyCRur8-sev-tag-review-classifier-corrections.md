---
name: human-2026-05-06-0829-93-BqyCRur8
human_involved: true
---

# Thread Summary: OT SEV tag review — operator corrects classifier heuristics for inference and recurring-training SEVs

_Source: spaces/AAQAVOjYc80 thread `93-BqyCRur8` · 4 messages · 2026-05-06 08:29–09:30 PDT_
_Summarized: 2026-06-02 11:44 PT · last-msg-time: 2026-05-06T16:30:24Z_

## What was discussed

Bot ran ot-sev-tag-review and auto-applied #mvai-online-training to 19 SEVs, flagging 3 for operator review. Operator provided two new classifier heuristics that invalidate several auto-tagged SEVs. Operator also pushed back on bot waiting for confirmation: bot should have proposed a diff and tag-removal plan immediately rather than waiting for explicit "do it" instruction.

## Key decisions made

- 2026-05-06T15:58:06Z operator rule 1: if SEV owner reports to operator's manager AND is not a member of the OT dev group → SEV is not OT (example: S659181 sigrid predictor = inference, S659693 cogwheel = trunk; both wrong-tagged)
- 2026-05-06T15:58:06Z operator rule 2: if SEV title contains "recurring training" → not OT SEV (example: S658424 Stories ranking recurring training CUDA failure)
- 2026-05-06T15:58:06Z operator question: S659876 (IPs Model Age Alert for model 909309147) — why was this classified as OT? (heuristic `model.age` is insufficient)
- 2026-05-06T16:26:15Z operator: bot should create diff AND remove wrong tags immediately without waiting for "do it"

## Files / artifacts touched

| path | what changed |
|---|---|
| (diff proposed but not confirmed in thread) | — |

## Cluster / pattern references

(SEV classifier correctness — not a training failure pattern. No CL-NNN applicable.)

## Followup items (not yet done)

1. Remove #mvai-online-training tag from S659181, S659693 (wrong-tagged, owner heuristic)
2. Remove #mvai-online-training tag from S658424 (recurring training in title = not OT)
3. Clarify S659876: model.age heuristic alone is insufficient — add check against mvai-online-training oncall owner or model registry
4. Codify the two new rules into the classifier (diff to known_patterns.md or triage_config.yaml)

## Cross-refs

- SEVs discussed: S659181, S659693, S659876, S658424 (wrong-tagged or review), S658165, S658492, S652695, S657606, S655630, S659167, S659243, S658149 (correctly tagged)
- Posts: (none)
- Related threads: (none)
