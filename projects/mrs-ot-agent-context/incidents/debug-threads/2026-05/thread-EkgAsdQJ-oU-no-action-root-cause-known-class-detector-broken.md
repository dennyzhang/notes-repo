# Thread Summary: FBLearner model 2145491885 — dead detector misconfig (CL-018)

_Source: spaces/AAQAVOjYc80 thread `EkgAsdQJ-oU` · 6 messages · 2026-05-23T00:53Z → 2026-05-23T00:55Z_
_Summarized: 2026-05-23 21:47 PT · last-msg-time: 2026-05-23T00:55:56Z_

## What was discussed

Alert fired for model 2145491885 (ig_reels_starsearch_t2i_retrieval holdout) with prefix `[Invalid Detector - No Data]` tracking `scribe_read_proxy.client_lag_in_seconds`. This is a MAST/MVAI metric but the model runs on FBLearner Flow — structurally never emits this metric. Model publishing was healthy (SPARSE_DELTA every ~2 min). Bot also discovered two cron-context limitations during this triage.

## Key decisions made

- **2026-05-23T00:53:13Z** — Verdict 🟢 NO ACTION / DETECTOR_BROKEN: model is FBLearner (`runtime_platform=FBLEARNER_FLOW`), no `mvai-training-online-2145491885` MAST job exists, metric will never appear. CL-018 match. Suppress/reconfigure detector for FBLearner models; zero model-side action.
- **2026-05-23T00:55:31Z** — Bot self-correction acknowledged: this was the 3rd wrong triage on model 2145491885 in 24h (timezone assumption on `ai.model.instance list` = PDT not UTC). Memory updated.

## Files / artifacts touched

| path | what changed |
|---|---|
| `memory/MEMORY.md` | Added `triage-discipline` gotcha: `ai.model.instance list` returns PDT |
| paste P2348348040 | Machine fields created (not updated — `meta paste.paste update` broken in cron, L32 issue) |

## Cluster / pattern references

- [CL-018] — dead/misconfig detector for FBLearner-runtime models; detector built for MAST, model is FBLearner

## Followup items (not yet done)

1. Suppress or reconfigure `scribe_read_proxy.client_lag_in_seconds` detector for FBLearner models in ig_reels_starsearch_t2i_retrieval — owner: weiz / igr_retrieval, tracked in IMPROVEMENT-PROPOSALS.md.

## Cross-refs

- SEVs discussed: none (27 ZippyDB SEVs in-progress but model unaffected)
- Posts: none
- Related threads: none
