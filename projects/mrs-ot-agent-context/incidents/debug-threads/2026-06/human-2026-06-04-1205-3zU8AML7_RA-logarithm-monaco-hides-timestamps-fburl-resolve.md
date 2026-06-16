# Thread Summary: Logarithm MONACO view hides timestamps; fburl resolution via meta CLI

_Source: spaces/AAQAVOjYc80 thread `3zU8AML7_RA` · 7 messages · 2026-06-04T19:05–19:09Z_
_Summarized: 2026-06-04 22:43 PT · last-msg-time: 2026-06-04T19:09:13Z_
human_involved: true

## What was discussed

Operator asked why timestamps were missing from a Logarithm log view shared as an fburl. Bot initially tried plain curl (hit SSO wall) before operator pointed out the MAST job name is embedded in the url. Bot used `meta fburl.link` to resolve the short link and identified two compounding causes: (1) the url carried `"view":"MONACO"` which hides the per-line time column, and (2) Python `print()` lines carry no embedded timestamp (C++ glog lines do).

## Key decisions made

- `meta fburl.link <fburl>` is the correct CLI resolver for fburl short links (web SSO not available from CLI). Decision at 2026-06-04T19:06:56Z.
- To get timestamps on every line: use default Logarithm table view (drop MONACO), or pull via `meta ai.mast-job logs --name=<job> --version=<v> --task-id=0` which emits glog ingestion time per line. Decision at 2026-06-04T19:09:13Z.

## Files / artifacts touched

| path | what changed |
|---|---|
| — | No files written; answer was investigative only |

## Cluster / pattern references

_(no matching cluster — this is a tooling/workflow question, not an OT incident pattern)_

## Followup items (not yet done)

1. Operator noted v11 of `mvai-training-online-2121434823` exited code 1 at 08:47 — bot offered to triage restart-loop root cause but no followup was requested in this thread.

## Cross-refs

- SEVs discussed: none
- MAST job referenced: `mvai-training-online-2121434823` v11
- Related threads: `rREZuzVSOD8` (same job context)
