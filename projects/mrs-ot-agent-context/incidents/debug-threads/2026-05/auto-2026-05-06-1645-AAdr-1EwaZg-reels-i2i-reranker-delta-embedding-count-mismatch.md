---
name: auto-2026-05-06-1645-AAdr-1EwaZg
human_involved: false
---

# Thread Summary: Reels I2I reranker — delta fails "Not all sparse embeddings mapped" after adding UIH table

_Source: spaces/AAQAVOjYc80 thread `AAdr-1EwaZg` · 3 messages · 2026-05-06 16:45–16:51 PDT_
_Summarized: 2026-06-02 11:44 PT · last-msg-time: 2026-05-06T23:51:54Z_

## What was discussed

Gabriel Chen posted to mrs.ot about delta failure on job `mvai-training-online-2124629126` after adding an unpooled UIH embedding table to Reels I2I reranker. Error: `RuntimeError: Not all sparse embeddings are mapped. Expected 11, got 10`. Bot triaged: serving predictor's `model_param_config` (written when it last loaded a FULL_SNAPSHOT of the old 10-table model) has 10 weight_id entries; new training model has 11. `_get_model_param_config_for_sparse` at `utils.py:641` fails on the new table. Validator confirmed all ground-truth queries matched. No operator corrections.

## Key decisions made

- 2026-05-06T23:50:11Z bot fix: trigger FULL_SNAPSHOT first; serving predictor loads new arch and writes new model_param_config with 11 entries; then re-enable delta-only publishing
- 2026-05-06T23:51:54Z validator confirmed: error message, code path (`utils.py:641`), attempt timing pattern (attempt 0 ran 2h48m before delta triggered; attempts 1–2 fast-failed at ~17 min), and SEV cross-reference all verified

## Files / artifacts touched

| path | what changed |
|---|---|
| `fbcode/minimal_viable_ai/core/model_weights_delta_publisher/utils.py:641` | root cause site — `_get_model_param_config_for_sparse` fails on new table |
| `fbcode/minimal_viable_ai/core/model_weights_delta_publisher/weights_delta_publisher.py:362` | call site |

## Cluster / pattern references

(New embedding table not reflected in serving predictor's model_param_config — this is a "first delta after architecture change" failure mode, distinct from CL-001 snapshot-stuck. No established CL-NNN for this pattern in failure-patterns.md. Candidate for a new cluster if recurs.)

## Followup items (not yet done)

(No explicit followup; fix path was clear and given to gabrielchen directly via post reply routing.)

## Cross-refs

- SEVs discussed: (none — no open SEV matched in meta sevmanager scan)
- Posts: W1319356410159102 (mrs.ot gabrielchen post)
- Job: `mvai-training-online-2124629126` (DEAD, 3 attempts)
- Related threads: (none)
