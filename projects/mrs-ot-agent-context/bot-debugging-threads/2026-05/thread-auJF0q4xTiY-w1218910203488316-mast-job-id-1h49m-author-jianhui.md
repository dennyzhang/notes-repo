# Thread Summary: OT Posts Pattern Triage — Training Age, NCCL, P55 Added

_Source: spaces/AAQAVOjYc80 thread `auJF0q4xTiY` · 5 messages · 2026-05-17 04:38 – 04:42 UTC_
_Summarized: 2026-05-17 13:31 PT · last-msg-time: 2026-05-17T04:42:04Z_

## What was discussed

`ot-daily-learning-mitigated-posts` cron fired and produced a digest of 3 Workplace posts. Operator submitted a separate pattern-triage annotation. Bot integrated both into notes and added a new known pattern (P55).

Posts processed:
- **W1218910203488316** (Jianhui Sun, May 9–11, IG Reels Tab, model 2147007224) → mapped to [CL-013] (training-age spike). Root cause: OT job restarted v51→v52 with `scribe_reader_catchup_sec=0`, clearing the holdout delay and dropping training example age to near-zero. Missing `latency_injection_ms` from D102533010 also suspected.
- **W1215710353808301** (Jakub Bester) → MATCH P36 (silent success via `skip_recurring=True`). Runbook note: if `generate-job-config-diff` fails with JOB_NOT_FOUND, model needs `register-and-run` first.
- **W1319390770155666** (Kedong He) → MATCH P19 (NCCL timeout / watchdog).

Validator was unavailable in cron context (no Agent tool); digest published unvalidated.

## Key decisions made

- **2026-05-17T04:42Z** — P55 added to `known_patterns.md` for `scribe_reader_catchup_sec=0` regression pattern (OT restart clears scribe holdout delay). Source: W1218910203488316.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/known_patterns.md` | P55 added: OT restart clears `scribe_reader_catchup_sec` holdout delay |
| `mrs-ot-agent-context/mega-learnings/registry/CLUSTERS.md` | CL-013 new evidence added (W1218910203488316) |
| `mrs-ot-agent-context/mitigated-posts/2026-05/` | 3 post archive files added |

Commit: `db3e0fd49dec` (P55 + CL-013 evidence), `999e6fc82bf0` (mapping batch).

## Cluster / pattern references

- [CL-013] — Training-age / example-age spike; `scribe_reader_catchup_sec=0` added as sub-mechanism #N

## Followup items (not yet done)

_(No followups discussed.)_

## Cross-refs

- Posts: W1218910203488316, W1215710353808301, W1319390770155666
- Related threads: `LqKW1jLtNeM` (same session's alert triage)
