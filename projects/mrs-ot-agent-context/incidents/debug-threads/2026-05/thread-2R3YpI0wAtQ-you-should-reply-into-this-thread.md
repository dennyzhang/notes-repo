# Thread Summary: Expert Observations Layer 1 — SJD Coverage Gaps

_Source: spaces/AAQAVOjYc80 thread `2R3YpI0wAtQ` · 4 messages · 2026-05-16_
_Summarized: 2026-05-17 00:31 PT · last-msg-time: 2026-05-16T20:36:52Z_

## What was discussed

Operator redirected a misthreaded reply back to `2R3YpI0wAtQ` (the original expert-observations-workflow thread). Bot re-anchored the state: a 3-layer proposal (Layer 1 = drop-file, Layer 2 = ingest cron, Layer 3 = triage integration) was already accepted, and the SJD-coverage-gap discussion in `z5JIb7DGm5o` was the first test case. Operator approved. Bot executed Layer 1 in one batch.

## Key decisions made

- **[2026-05-16T20:35:55Z] Layer 1 chosen as starting point** — lowest friction; operator said "ok", bot executed all 4 steps before second approval was sought.
- **[2026-05-16T20:36:52Z] CL-012 created** — SJD coverage gaps given dedicated cluster with N=2 instances; D1-eligible at N=3.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/expert-observations/2026-05-16-sjd-coverage-gaps.md` | Created (first operator observation file) |
| `mrs-ot-agent-context/mega-learnings/catalogs/sjd-coverage-map.md` | Created (SJD failure-mode catalog, 2 initial scenarios) |
| `mrs-ot-agent-context/mega-learnings/registry/CLUSTERS.md` | Added CL-012 |
| `thread-summaries/2026-05/*.md` | First-run thread-summarizer output (5 files) |

Commit: `6f9be2f9cdc2` on master.

## Cluster / pattern references

- [CL-012] — SJD coverage gaps; this thread established the pattern's first two instances (NCCL deadlock + cleanup hang) and created the catalog.

## Followup items (not yet done)

1. Layer 2 (ot-expert-observations-ingest cron) not yet built — deferred until Layer 1 is used in anger with more observations.
2. Operator to supply additional SJD-bypass scenarios to extend `sjd-coverage-map.md` row 3+.

## Cross-refs

- Related threads: `z5JIb7DGm5o` (SJD analysis), `1lufURy61pM` (thread-summarizer genesis)
