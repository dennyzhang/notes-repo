# Eval fitness — mean ± std over last 2 FULL run(s)

_From `reports/eval-flow-history.jsonl` (appended by `eval-stats.sh append` after each run). The composite **std is the noise band** — a candidate's gain must exceed it to be a real win, not luck. **6 partial (per-shard) row(s) EXCLUDED** — only full-corpus composites count toward the baseline._

| dim | mean | std (noise) | n |
|---|---|---|---|
| composite | 0.675 | ±0.029 | 2 |
| calibration | 0.792 | ±0.025 | 2 |
| owner | 0.36 | ±0.03 | 2 |
| decisiveness | 0.717 | ±0.037 | 2 |
| hallucination | 0.14 | ±0.021 | 2 |
| root_cause | 0.775 | ±0.046 | 2 |

**Noise band (composite std): ±0.029** — accept a mutation only if its composite gain > this.

## Runs
| date | composite | n | gold_version |
|---|---|---|---|
| 2026-06-12 | 0.704 | 59 | 2026-06-11-stable-inputs |
| 2026-06-12b | 0.646 | 56 | 2026-06-11-stable-inputs |
