# Thread Summary: S659693 — mvai/mvai_ig_ranking cogwheel DataPreproc uint32 rolling-window underflow

_Source: spaces/AAQAVOjYc80 thread `IbsIy1l6jwU` · 3 messages · 2026-05-06 19:04–19:11 PDT_
_Summarized: 2026-06-02 10:43 PT · last-msg-time: 2026-05-06T02:11:19Z_
human_involved: false

## What was discussed

Bot triage of S659693 (L4, mvai_publish_pipeline): mvai/mvai_ig_ranking cogwheel test (R8206) DEAD at 10:18–12:58 UTC due to DataPreproc JIT transform failure. Root cause identified: `torcharrow_accel_preproc_common.py:2319` in `_rolling_agg_loop` computes `window_starts = index - window_size + 1` which can go negative; negative int cast to uint32 yields 4294967286 (= 2^32 − 10), which is out of bounds for dim 0 size 8001 → `RuntimeError`. Fix: clamp `window_starts = max(window_starts, 0)`. The error message itself points to N7997773 for feature diagnosis. Validator confirmed all findings. Cross-refs to S659617 (same cogwheel test, different stage — DeltaOnlyPublisher, not DataPreproc) correctly noted as separate blockers.

## Key decisions made

- Root cause confirmed as uint32 underflow at torcharrow_accel_preproc_common.py:2319 (2026-05-06 19:09 PDT); defensive clamping fix identified
- Cogwheel rerun via rerun_cmd P2306667281 recommended after fix lands (2026-05-06 19:09 PDT)

## Files / artifacts touched

| path | what changed |
|---|---|
| minimal_viable_ai/utils/torcharrow_accel_preproc_common.py:2319 | `window_starts` bounds fix needed — `max(window_starts, 0)` clamping |

## Cluster / pattern references

_(omitted — not verified against failure-patterns.md)_

## Followup items (not yet done)

1. Run N7997773 to identify specific feature causing negative window_starts — owner: clementc
2. Apply `max(window_starts, 0)` clamping at torcharrow_accel_preproc_common.py:2319 — owner: clementc
3. Rerun cogwheel after fix via rerun_cmd P2306667281

## Cross-refs

- SEVs discussed: S659693, S659617 (same cogwheel test, DeltaOnlyPublisher failure — separate blocker)
- Posts: none
- Related threads: `8tivqmMMCqI` (S659617/S659631, same ig_ranking conveyor block event)
