# Thread Summary: FB Reels VDD HSTU trainer crash-loop → crisp WP report + json-only bug fix

_Source: spaces/AAQAVOjYc80 thread `rREZuzVSOD8` · 11 messages · 2026-06-04T23:03–23:12Z_
_Summarized: 2026-06-04 22:43 PT · last-msg-time: 2026-06-04T23:12:17Z_
human_involved: true

## What was discussed

Operator asked for a crisp 5-element WP report for `877766818` (FB Reels VDD HSTU) — trainer `877766932` crash-looping (attempts FAILED 51h → FAILED 23h → DEAD; v8 resubmitted). Bot verified current state, created detail paste P2363771996, and drafted the crisp report (operator to post; bot does not write to WP). During report composition, the prompt-change-validator caught a real bug: `scan-perf-regression.sh --json-only` suppresses the log line the 📉 fleet-health section needed for skip-count. Bot fixed it in-thread (script now emits `{"summary":{"scanned":30,...}}` machine-summary line). Operator correction at thread start: "you should reply to thread per gchat cheatsheet."

## Key decisions made

- Root cause (inferred, not formally confirmed): trainer dies on `No write to scribe category feed_learning_xsurface_training_data` (INPUT_ERROR, non-retryable). Upstream SEV S672114 ("Unstable UDD/IFU XSurface Online Training Scribe QPS") is the likely owner — not a Manifold/checkpoint-quota throttle. Decision/caveat at 2026-06-04T23:11:51Z.
- Bot does not post to WP groups — operator owns that surface. Paste created first (P2363771996), report drafted as copy-paste text. This is the correct report-creation workflow.
- Validator-caught bug fix: `--json-only` flag suppresses `log()` in `scan-perf-regression.sh`; script now emits machine-summary JSON as a separate `echo '{"summary":...}'` outside log(). Verified: prints correctly. Decision: 2026-06-04T23:12:15Z.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../team_bot/scripts/scan-perf-regression.sh` | machine-summary JSON line (`{"summary":{...}}`) emitted outside `--json-only` gate |
| sqlite | fleet-health cron prompt synced (updates=1) |
| P2363771996 (paste) | Verbose investigation detail for the WP report |

## Cluster / pattern references

- [CL-003] — downstream-infra reliability (Scribe cascade): `feed_learning_xsurface_training_data` scribe category write failure → trainer INPUT_ERROR → crash loop. S672114 is a Scribe-QPS SEV affecting this training pipeline.
- [CL-001] — snapshot-stuck: served model `877766818` missing FULL_SNAPSHOT (8h+ gap, prior 57.7h gap 06-01→06-04). Snapshot staleness is the visible symptom; crash-loop is the cause.

## Followup items (not yet done)

1. Monitor v8 of `877766932` — will crash again at first publish cycle if S672114 is not resolved.
2. Operator: post P2363771996 + crisp report to the relevant WP group; dedup alert A902257976006165 against S672114.

## Cross-refs

- SEVs discussed: S672114 (Unstable UDD/IFU XSurface Online Training Scribe QPS)
- Alert: A902257976006165
- MAST jobs: `mvai-training-online-2121434823` (related, same day), `877766932` (crash-looping)
- Model: `877766818` (served), `877766932` (training)
- Related threads: `3zU8AML7_RA` (Logarithm timestamps on same `2121434823` job), `jrwfJJKEjEU` (json-only bug sourced from same consolidation work)
