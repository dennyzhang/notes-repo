# Eval fitness — mean ± std over last 0 FULL run(s)

_From `reports/eval-flow-history.jsonl` (appended by `eval-stats.sh append` after each run). The composite **std is the noise band** — a candidate's gain must exceed it to be a real win, not luck. **32 partial (per-shard) row(s) EXCLUDED** — only full-corpus composites count toward the baseline._

| dim | mean | std (noise) | n |
|---|---|---|---|
| composite | n/a | — | 0 |
| calibration | n/a | — | 0 |
| owner | n/a | — | 0 |
| decisiveness | n/a | — | 0 |
| hallucination | n/a | — | 0 |
| root_cause | n/a | — | 0 |

**Noise band (composite std): ±None** — accept a mutation only if its composite gain > this.

## Runs
| date | composite | n | gold_version |
|---|---|---|---|
