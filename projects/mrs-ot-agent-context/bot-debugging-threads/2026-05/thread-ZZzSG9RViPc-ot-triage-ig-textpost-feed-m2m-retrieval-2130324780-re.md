# Thread Summary: Triage Correction — FS Duration Error and Corpus Query Discipline

_Source: spaces/AAQAVOjYc80 thread `ZZzSG9RViPc` · 3 messages · 2026-05-21 01:18–02:27 UTC_
_Summarized: 2026-05-24 16:51 PT · last-msg-time: 2026-05-21T02:27:43Z_

## What was discussed

Denny posted the canonical triage for `ig_textpost_feed_m2m_retrieval 2130324780`: FS missing 4h 50m (last: 13:16 PDT May 20), v41 kmeans crash (got 1,315, needed 64,077), upstream corpus `agg_threads_star_search_common_pool_with_replies_by_ts_48h` regressed ~22K→1,315. Bot acknowledged and noted 3 corrections to its earlier triage (thread `YAACkhGjs04`): wrong FS duration (bot said 50h+; correct was 4h50m), missing corpus dataset name, and absent operational discipline (do NOT restart v43 until corpus ≥64,077). Thread ended with Denny asking "What is your key learning" — no bot reply.

## Key decisions made

- **2026-05-21T01:19Z** — Bot self-correction: the `-l 200` model.instance query silently missed the most recent FS because on a STUS model with deltas every 5-15 min, top-200 instances ≈ 16-50h of delta history with only a small fraction being FS. Must filter explicitly by snapshot_type or sort by FS-specific timestamp.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none) | Analysis / correction only |

## Cluster / pattern references

- [CL-001] snapshot-stuck — this incident is a direct instance; FS missing was ~4h50m (not 50h+)
- P63 (STUS kmeans corpus underflow) — confirmed; the corpus name was `agg_threads_star_search_common_pool_with_replies_by_ts_48h`

## Followup items (not yet done)

1. Denny asked "What is your key learning" at 2026-05-21T02:27Z — no bot reply. Key learning: for STUS models with high-frequency delta publishing, `meta ai.model.instance list -l 200` cannot reliably find the last FULL_SNAPSHOT (200 instances ≈ delta window only). Must use `--filter snapshot_type=FULL_SNAPSHOT` if the CLI supports it, or parse by type+sort manually.

## Cross-refs

- SEVs discussed: none explicitly (Denny's triage referenced ot-alert-monitor L22 fire at 05:52 PDT)
- Posts: W1330685625692847 (mrs.ot Workplace post)
- Related threads: `YAACkhGjs04` (original bot triage), `DYu4zoMBeJE` (3-component topology)
