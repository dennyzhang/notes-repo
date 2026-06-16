# Thread Summary: ot-perf-regression-watch retired, folded into ot-fleet-health + kfmt formatter

_Source: spaces/AAQAVOjYc80 thread `jrwfJJKEjEU` · 28 messages · 2026-06-04T22:46–22:58Z_
_Summarized: 2026-06-04 22:43 PT · last-msg-time: 2026-06-04T22:58:49Z_
human_involved: true

## What was discussed

Operator flagged that `ot-perf-regression-watch` was posting separately to the 1:1 space while fleet-health signals should be consolidated into one team message. Also flagged QPS number readability: `16,374/30,124` should render as `16.4K`. Bot confirmed the overlap (P-014: cron scope duplication it had already flagged but created anyway), retired the standalone cron, folded perf-regression as the 3rd scan (📉) inside the single `ot-fleet-health` team message (zombie · training-age · perf-drift). Bot then added a deterministic `kfmt` K/M formatter into `scan-perf-regression.sh` (not LLM-rendered), hardened edge cases, and generalized a number-readability HARD rule to all cron jobs via CLAUDE.md. Operator closed thread.

## Key decisions made

- **ot-perf-regression-watch retired** (removed from MANIFEST + deleted from sqlite). QPS-drop is the 3rd scan inside `ot-fleet-health`, not a separate cron. Decision: 2026-06-04T22:50:34Z.
- **Deterministic `kfmt` helper** in `scan-perf-regression.sh`: `0→0`, `<1000→N`, `≥1000→X.XK`, `≥1M→X.XXM`, `None/"x"→?`. Emits pre-formatted `signals[].h` strings; fleet-health renders those verbatim (LLM never re-formats numbers). Decision: 2026-06-04T22:54:35Z.
- **HARD readability rule generalized to ALL jobs** in CLAUDE.md § Cron Output Effectiveness: counts/qps→K/M, durations→h (>90min) or Nm, % integer, one-number-per-fact, non-numeric→`?`. Prefer formatting in the producing script, not the render. Decision: 2026-06-04T22:56:48Z.
- Operator corrections: "this msg should be consolidated" (2026-06-04T22:46:55Z); "needs to improve readability e.g. qps 16,374/30,124 → qps: 16.3K" (2026-06-04T22:47:46Z); "attack to make your solution comprehensive" (2026-06-04T22:50:42Z).

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../team_bot/cron-jobs/ot-fleet-health.md` | 📉 perf-drift section added; kfmt `h`-string rendering; number-format rule |
| `~/notes/.../team_bot/scripts/scan-perf-regression.sh` | `kfmt()` helper + `signals[].h` pre-formatted fields + unit tests |
| `~/notes/.../team_bot/MANIFEST.json` | `ot-perf-regression-watch` removed |
| sqlite | `ot-perf-regression-watch` deleted (deletes=1); `ot-fleet-health` updated (updates=1) |
| `~/notes/.../CLAUDE.md` | § Cron Output Effectiveness: number-readability HARD rule (all jobs) |

## Cluster / pattern references

- [CL-015] / [CL-016] — QPS dip/slow detection is now covered inside fleet-health 📉 scan

## Followup items (not yet done)

1. Changes staged in sqlite; live at next daemon restart.
2. Validator-caught bug (`--json-only` suppresses skip-count log) was fixed in the same session (thread `rREZuzVSOD8`) — `scan-perf-regression.sh` now emits machine-summary JSON.

## Cross-refs

- Related threads: `rREZuzVSOD8` (same session — validator-caught --json-only bug fixed there)
- SEVs discussed: none
