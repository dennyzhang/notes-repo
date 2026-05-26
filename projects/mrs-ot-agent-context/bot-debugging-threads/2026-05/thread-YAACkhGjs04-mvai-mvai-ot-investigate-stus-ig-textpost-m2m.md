# Thread Summary: STUS Kmeans Corpus Underflow — ig_textpost_feed_m2m_retrieval (2130324780)

_Source: spaces/AAQAVOjYc80 thread `YAACkhGjs04` · 5 messages · 2026-05-21 00:46–02:29 UTC_
_Summarized: 2026-05-24 16:51 PT · last-msg-time: 2026-05-21T02:29:06Z_

## What was discussed

Denny invoked `/mvai:mvai-ot investigate` on a `dai_modelstore` FS-missing alert for model `2130324780` (`ig_textpost_feed_m2m_retrieval`, STUS-role). Bot initially replied to a different thread (routing bug); Denny had to ask "why no response." Bot triage: P63 STUS kmeans corpus underflow — v40/v41 crashed with `AssertionError: At least 64077 embs needed for kmeans, but got 22035 / 1315`, v42 DPP cascade, v43 running. Recommended: PAGE `ronghuang` + `p92_relevance_retrieval_oncall`, open SEV, escalate T2I corpus team to restore ≥ 64,077 items. Thread ended with Denny asking "Why lowering that can help" (re: D-017 lower `n_min_embeddings_required` as stopgap) — no bot reply.

## Key decisions made

- **2026-05-21T00:52Z** — Bot verdict: REAL_OT_FAILURE_RECURRING · P63 · HIGH confidence. Recommended PAGE + SEV open + D-017 stopgap workaround.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none) | Triage analysis only |

## Cluster / pattern references

- [CL-001] snapshot-stuck — FS-missing alert is in this cluster family
- P63 (STUS kmeans corpus underflow) — the specific systemic cause pattern applied

## Followup items (not yet done)

1. Denny asked "Why lowering that can help" (re: D-017 `n_min_embeddings_required` stopgap) at 2026-05-21T02:29Z — no bot answer. Answer: lowering the threshold allows kmeans to run with fewer embeddings; enables FS publish to succeed even with a depleted corpus, at cost of lower-quality embedding space. Only a stopgap until upstream corpus is restored.

## Cross-refs

- SEVs discussed: none opened in thread (SEV open was recommended, not confirmed)
- Related threads: `DYu4zoMBeJE` (same model, 3-component topology confusion), `ZZzSG9RViPc` (operator's canonical triage correction)
