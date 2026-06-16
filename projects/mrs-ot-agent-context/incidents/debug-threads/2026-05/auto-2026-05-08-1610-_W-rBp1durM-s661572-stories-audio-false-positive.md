---
name: s661572-stories-audio-false-positive
description: S661572 "publish" regex false positive — IG Stories audio regression not an ML pipeline issue; correctly identified as client-side bug
metadata:
  type: project
  thread_id: "_W-rBp1durM"
  space: spaces/AAQAVOjYc80
  human_involved: false
---

# Thread Summary: S661572 — Stories Audio False Positive on "publish" Regex

_Source: spaces/AAQAVOjYc80 thread `_W-rBp1durM` · 3 messages · 2026-05-08_
_Summarized: 2026-05-08 16:10–16:14 PT · last-msg-time: 2026-05-08T23:14:15Z_

## What was discussed

SEV S661572 "[Android] [iOS] [Stories] Audio added to Story missing after publish" was ingested via the `mvai_publish_pipeline` classifier lane (regex hit on "publish"). Bot correctly identified as a false positive: "publish" referred to a user posting a Story, not ML model deployment.

## Key decisions made

- **False positive confirmed (confidence 0.2):** S661572 is an IG Stories client-side audio regression (flytrap/226150590804030, T270380586 regression). No model ID, no MVAI cogwheel reference, no ML pipeline involvement.
- **Auto-tag withheld:** validator confirmed tagging `mvai-online-training` would be incorrect for this SEV.
- **Routing:** SEV owner oliviaberreby (IG Stories eng), awareness ping to @dkotfis (IG OT lane). No OT pipeline action needed.

## Files / artifacts touched

| path | what changed |
|---|---|
| SEV S661572 | read-only; auto-tag correctly suppressed |

## Cluster / pattern references

_(No existing cluster ID confirmed — this is a classifier false-positive pattern. "publish" as word in SEV title reliably hits `mvai_publish_pipeline` even for non-ML publish actions.)_

## Followup items (not yet done)

1. Classifier improvement candidate: narrow `mvai_publish_pipeline` regex to require ML-specific context words alongside "publish" (e.g., "model", "snapshot", "cogwheel", "MAST") to reduce IG-Stories-style false positives.

## Cross-refs

- SEVs discussed: S661572 (L3, IG Stories audio regression)
