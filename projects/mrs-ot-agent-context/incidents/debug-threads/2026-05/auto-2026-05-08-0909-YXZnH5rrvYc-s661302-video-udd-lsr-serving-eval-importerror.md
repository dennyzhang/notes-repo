---
human_involved: false
---
# Thread Summary: S661302 — video_udd_lsr serving_eval blocked by ImportError (kDatafmUfsEnrichmentFeatureMonitorScuba)

_Source: spaces/AAQAVOjYc80 thread `YXZnH5rrvYc` · 3 messages · 2026-05-08 09:09 – 09:14 PT_
_Summarized: 2026-06-02 14:43 PT · last-msg-time: 2026-05-08T16:14Z_

## What was discussed

L4 SEV S661302 on mvai_serving: conveyor for mvai/video_udd_lsr blocked at cogwheel_trunk_multi_arm_metrics_online_test since ~07:00 PT 2026-05-07 (detected 25.8h later). Both vanguard jobs (1269469735172287, 1485903536250480) failed with `ImportError: kDatafmUfsEnrichmentFeatureMonitorScuba` at `roo_predictor_eval_preproc.py:209`. Bot triage concluded a diff landed ~2026-05-07 removed or renamed this symbol. Validator confirmed all facts and clarified the S661020 cross-ref was for surface awareness (different root cause — threshold breach, not ImportError), not a root-cause link.

## Key decisions made

- **ImportError at import stage** rules out model snapshot quality and vanguard infra as root causes — failure before evaluation runs.
- **25.8h detection gap** flagged as a quality issue — recommendation to add import-stability test for `roo_predictor_eval_preproc.py`.
- **Video lane deferral**: OT escalation owner listed as "defer" (no active Video OT rotation assigned).

## Files / artifacts touched

| path | what changed |
|---|---|
| `roo_predictor_eval_preproc.py:209` | (proposed fix: update import path for kDatafmUfsEnrichmentFeatureMonitorScuba) |

## Cluster / pattern references

_(no verified cluster IDs — omitted)_

## Followup items (not yet done)

_(none explicitly stated in thread — follow-ups were in the SEV itself: find current symbol definition, fix import, add import-stability test)_

## Cross-refs

- SEVs discussed: S661302, S661020
- Vanguard jobs: 1269469735172287, 1485903536250480
- Owners: vrahangdale (SEV), Video OT (deferred — no rotation assigned)
