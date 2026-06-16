# Eval loop passing rate (7d) — ot-evolve-loop

_From `job_runs` (ground truth). v1 heuristic: an `ok` run > 25min is counted a likely STALL (returned HEARTBEAT_OK after a timeout). Exact once eval-flow.js writes a structured outcome marker._

## Rate
- ticks in window: **14** · daemon-attempted 12 · missed 2
- **passing rate: 83%**  (10 clean / 12 attempted)
- likely-stalled (ok but > 25min): 2 · errored: 0
- run duration: median 18.6min, max 31.7min

## Recent ticks
| run_at | mins | status | verdict |
|---|---|---|---|
| 2026-06-11T12:44 | 31.1 | ok | likely-stall |
| 2026-06-11T14:31 | 18.5 | ok | clean |
| 2026-06-11T16:22 | 9.5 | ok | clean |
| 2026-06-11T18:20 | 7.5 | ok | clean |
| 2026-06-11T20:20 | 7.4 | ok | clean |
| 2026-06-11T22:19 | 6.7 | ok | clean |
| 2026-06-12T00:32 | 19.7 | ok | clean |
| 2026-06-12T02:31 | 18.6 | ok | clean |
| 2026-06-12T04:34 | 21.4 | ok | clean |
| 2026-06-12T06:36 | 23.6 | ok | clean |
| 2026-06-12T08:43 | 0.0 | missed | missed |
| 2026-06-12T08:44 | 31.7 | ok | likely-stall |
