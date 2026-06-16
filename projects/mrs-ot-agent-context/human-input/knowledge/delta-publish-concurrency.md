# Systemic Gap: Delta Publish Pipeline is Fully Serial

**Task:** [T273983790](https://www.internalfb.com/T273983790)
**SEV:** [S668980](https://www.internalfb.com/sevmanager/view/668980) (IGR ESR Mb7 — abnormal QPS during delta publish)
**Short-term fix:** [D107207628](https://www.internalfb.com/diff/D107207628) (non-blocking skip, llu6)
**Source:** Li Lu analysis, GChat `AAQAX8BWfqc/frHzp2lHW0g`, 2026-06-02

---

## The gap in one sentence

The delta publish pipeline processes one delta at a time in a single subprocess on a single thread — when Phase 2 (CPU/network) is slow, training either blocks (pre-fix) or drops deltas (post-fix).

## Two-phase architecture

```
Delta timer fires
  │
  ├─ Phase 1 — GPU-side diff extraction (BLOCKS training, fast)
  │    select which embedding rows changed since last delta (topK)
  │    → index_select to gather rows from live embedding tables
  │    → GPU→CPU copy
  │    (sparse read of changed rows, NOT a full checkpoint — seconds)
  │
  └─ Phase 2 — CPU-side publish (async, slow)
       process extracted embedding rows on CPU → serialize
       → upload tensors to Manifold/Hedwig
       → generate delta update metadata → commit to UMM
       (background subprocess — 5-30+ min for large models)
```

Phase 1 is fast because it's a sparse diff, not a full-rank checkpoint. Phase 2 is the bottleneck (CPU + network I/O).

## Why it matters

| Scenario | Before D107207628 | After D107207628 |
|----------|-------------------|------------------|
| Phase 2 still running when next delta fires | Training thread **blocks** in `may_wait_for_ongoing_task_done()` for 20+ min | Training continues, delta cycle **skipped** |
| Impact | QPS drops periodically | No QPS drop, but **deltas silently dropped** → model freshness degrades |

D107207628 trades QPS stability for delta freshness. The right fix is concurrent Phase 2 — start a new Phase 2 while the old one is still running.

## What concurrent Phase 2 requires (Li Lu's analysis)

1. **Multiple future tracking** — code stores a single `_ongoing_task_future`; a second submit overwrites the reference
2. **Independent cleanup** per concurrent task
3. **SubProcessWithTaskQueue** doesn't support concurrent tasks today
4. **2× CPU memory** — two Phase 2 cycles = two CPU copy buffers alive simultaneously
5. **Ordering** — concurrent publishes can produce out-of-order deltas

CPU/mem/network are underutilized (headroom exists), but the code is architecturally serial.

## Suggested approach

1. Land D107207628 (immediate — stops QPS drops)
2. Design concurrent Phase 2: ordering semantics, memory cap, failure isolation
3. Prototype 2-slot concurrency on a single model
4. Measure delta freshness improvement vs skip-only baseline

## Known-pattern connection

This gap is the root mechanism behind war story S668980 (blocking delta publish) and is adjacent to:
- P01 (Full snapshot blocking deltas) — same pipeline, different stage
- P02 (Publish pipeline deadlock) — same code path, different failure mode
- New pattern candidate: "Delta Phase 2 blocking training thread"
