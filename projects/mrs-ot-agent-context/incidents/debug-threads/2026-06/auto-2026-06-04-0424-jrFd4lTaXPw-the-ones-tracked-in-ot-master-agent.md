---
human_involved: false
---

# Thread Summary: Build ot-perf-regression-watch cron (scan-perf-regression.sh)

_Source: spaces/AAQAVOjYc80 thread `jrFd4lTaXPw` · 33 messages · 2026-06-04 04:24–04:57 UTC_
_Summarized: 2026-06-04 21:45 PT · last-msg-time: 2026-06-04T04:57:35Z_

## What was discussed

Denny asked the bot to build a QPS/GPU-memory regression watcher for the OT-tracked model fleet. The bot designed `tools/scan-perf-regression.sh` reading `human-input/models.md` (30 models), fanning out concurrently, and computing baseline-relative drift per model. The cron was registered as `ot-perf-regression-watch` (6h interval, delivers to operator 1:1). Denny then asked to run it immediately rather than wait 6h — bot ran live, 0 regressions found.

## Key decisions made

- **Baseline = trailing-7d median per model** (not a global threshold); avoids penalizing models with structurally lower QPS. Decision: 2026-06-04T04:26 UTC.
- **Scope = dense/MTML ranking fleet only** (retrieval/sub-models emit `qps/global/window/train` under a different EID → 16 skipped; coverage gap reported every run, not hidden). Decision: 2026-06-04T04:30 UTC.
- **Non-overlap with ot-fleet-health** — example-age is already covered there (P-014); new cron only adds QPS-drop + GPU-mem-slope. Decision: 2026-06-04T04:31 UTC.
- **Codex adversarial pass mandatory** (pilot): found 3 silent-false-negative bugs before ship — QPS fetch-fail→SKIP, QPS=0 collapse→SKIP (worst regression), worker death→lost. All fixed. Decision: 2026-06-04T04:35 UTC.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../tools/scan-perf-regression.sh` | new — fleet perf scanner (mirrors zombie-scan structure) |
| `notes/.../cron-jobs/ot-perf-regression-watch.md` | new — cron prompt (6h, 1:1 delivery) |
| `notes/.../MANIFEST.json` | added ot-perf-regression-watch entry (inserts=1, 38 total jobs) |
| `notes/.../cheatsheets/oncall/mast-debugging.md` | added "Performance Regression" debug playbook section |

## Cluster / pattern references

_(omitted — failure-patterns.md not present in this session; no CL-NNN fabricated)_

## Followup items (not yet done)

1. Close retrieval-model coverage gap: models emit QPS under root-trainer EID, not their own — need a mapping layer. Owner: dennyzhang. Status: open.

## Cross-refs

- SEVs discussed: S670887 (OOM zombie — QPS→0 symptom, motivated the QPS=0→SKIP fix)
- Related threads: none
