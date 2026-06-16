---
human_involved: false
---
# Thread Summary: S661284 — mvai_ifr_main cogwheel NE metrics regression, MC11 threshold mismatch

_Source: spaces/AAQAVOjYc80 thread `4iud1vogrE0` · 3 messages · 2026-05-08 09:09 – 09:14 PT_
_Summarized: 2026-06-02 14:43 PT · last-msg-time: 2026-05-08T16:14Z_

## What was discussed

L4 SEV S661284 on mvai_publish_pipeline: cogwheel_ifr_mtml_trunk_metrics_test failed on mvai_ifr_main releases R9536.2/R9541.1/R9542.1 due to online_train_publish NE metrics regression. Bot identified MC11 re-adoption (D104293080, D104293189) as the root — share_ne on R9536.2 was 2× the 0.66 threshold, consistent with MC11 threshold miscalibration (same pattern as S654315 which previously forced MC7 backout). Validator confirmed all material claims and added that D104293189 depends_on D104293080 (stacked re-adoption).

## Key decisions made

- **MC11 hypothesis confirmed**: share_ne=1.3097 vs 0.66 threshold on R9536.2 is far too large for random variance; likely MC11 thresholds calibrated for MC7 baselines.
- **S654315 precedent applies**: prior MC11 NE instability led to MC7 revert (D103095875); the same path is available if MC11 eval confirms genuine regression.
- **D104293080/D104293189 stacked**: both Accepted but not yet landed at time of triage; conveyor was blocked ~22:31 PT 2026-05-07.

## Files / artifacts touched

| path | what changed |
|---|---|
| (read-only triage — no edits made) | — |

## Cluster / pattern references

_(no verified cluster IDs — omitted)_

## Followup items (not yet done)

_(none explicitly stated in thread — follow-ups were in the SEV itself: land status check, MC11 vs MC7 threshold comparison, held-out eval)_

## Cross-refs

- SEVs discussed: S661284, S654315
- Diffs referenced: D104293080, D104293189, D103095875, D101678676, D88207631
- Owners: akmahesh (SEV), dennyzhang (OT escalation for MRS/mvai_publish_pipeline)
