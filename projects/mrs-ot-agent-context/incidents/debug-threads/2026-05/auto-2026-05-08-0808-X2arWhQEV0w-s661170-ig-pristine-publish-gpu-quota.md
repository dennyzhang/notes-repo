---
human_involved: false
---
# Thread Summary: S661170 — IG Pristine reel+photo retrieval publish job failed, GPU quota rejection

_Source: spaces/AAQAVOjYc80 thread `X2arWhQEV0w` · 3 messages · 2026-05-08 08:08 – 08:12 PT_
_Summarized: 2026-06-02 14:43 PT · last-msg-time: 2026-05-08T15:12Z_

## What was discussed

L3 SEV S661170 on mvai_publish_pipeline: prod Pristine models 920261872 (reel) and 920261873 (photo) had their recurring publish job fail due to GPU quota rejection. Bot triage found training itself was healthy (last VALID snapshots from ~14:05 PT prior day), so failure was squarely at the FBLearner publish submit step hitting quota cap. Validator confirmed all claims.

## Key decisions made

- **Standing hypothesis confirmed**: GPU quota exhaustion on FBLearner publish submit (~14:05 PT 2026-05-07); possible shared quota pressure from sibling IG retrieval jobs.
- **Cross-refs flagged**: S659877 (QE models snapshot slow/IGML quota), S660677 (explore retrieval holdout publish delay) share the same quota pool and may be contributing.

## Files / artifacts touched

| path | what changed |
|---|---|
| (read-only triage — no edits made) | — |

## Cluster / pattern references

_(no verified cluster IDs — omitted)_

## Followup items (not yet done)

_(none explicitly stated in thread)_

## Cross-refs

- SEVs discussed: S661170, S659877, S660677
- Owners: taiqiwang (SEV), dkotfis (OT escalation)
