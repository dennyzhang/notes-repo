---
human_involved: false
---

# Thread Summary: S661922 — Silvertorch NaN publish failures on multiple edits sourcing models

_Source: spaces/AAQAVOjYc80 thread `KKFBeSIMYbM` · 3 messages · 2026-05-11T06:14–06:15 UTC_
_Summarized: 2026-06-02 17:43 PT · last-msg-time: 2026-05-11T06:15:44Z_

## What was discussed

Bot triaged S661922 (L3, `mvai_publish_pipeline`): Silvertorch NaN validator rejecting publishes on multiple edits-sourcing models since 09:59 UTC (12h before SEV opened). GChat for the SEV space was API-degraded, leaving model IDs unavailable. Three standing hypotheses proposed: NaN gradient explosion → bad weights; upstream sparse feature pipeline delivering NaN; or Silvertorch trunk regression (NaN threshold change). Bot auto-tagged SEV with `mvai-online-training`. Two validator confirmations matched all live-data claims.

## Key decisions made

- (2026-05-11T06:14Z) Three hypotheses held open pending model IDs (unavailable due to GChat degradation). Bot correctly flagged v.1 gate: publish has been failing 12h+, model age growing.
- (2026-05-11T06:14Z) Auto-tag `mvai-online-training` applied (confirmed by validator).

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — read-only triage + auto-tag) | — |

## Cluster / pattern references

_(No confirmed CL-NNN IDs apply. Silvertorch NaN multi-model simultaneous failures not yet in known-patterns.)_

## Followup items (not yet done)

1. [yingjieqian] Get model IDs from alarm 50968828639 / SEV GChat; fill SEV overview.
2. Once model IDs known: run `mast-job attempts` + `mast-job error` per model.
3. H3 check: scan `fbcode/aml/silvertorch` diffs after 2026-05-09 for NaN validator threshold change.

## Cross-refs

- SEVs discussed: S661922, S661020 (MITIGATED), S661170 (MITIGATED)
- Posts: none
- Related threads: none
