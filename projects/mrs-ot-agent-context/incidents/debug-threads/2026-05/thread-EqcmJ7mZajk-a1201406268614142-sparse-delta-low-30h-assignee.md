# Thread Summary: Second Alert Triage Run — Dead Detector, P58×3, Noisy Models, Notes Persistence

_Source: spaces/AAQAVOjYc80 thread `EqcmJ7mZajk` · 8 messages · 2026-05-17_
_Summarized: 2026-05-17 22:33 PT · last-msg-time: 2026-05-17T17:58:09Z_

## What was discussed

Second alert digest of the day (5 alerts: A1201406268614142, A977255094865118, A878102693-413, A878102693-417, A1011200521237714). Bot confirmed P58 on three alerts (ZippyDB S665163), proposed P59 for dead-detector false alarm (`[Invalid Detector - No Data]` scenario), and posted top-noisy-models surface (878858380 and 878102693 both at 3 alerts in 7d). Operator asked for the noisy-models info to be saved persistently in notes. Bot created `NOISY-MODELS.md` and extended the cron to append on every run.

## Key decisions made

- [2026-05-17T17:53:35Z] P58 confirmed ×3 (A977, A878102693-413, A878102693-417). CL-003.
- [2026-05-17T17:53:35Z] P59 proposed: `[Invalid Detector - No Data]` auto-clearance pattern — dead-detector false alert where observer lifecycle=enabled and model still publishing. Falsifier: check `meta monitoring.observer describe` → enabled + VALID publishing → not real dead detector.
- [2026-05-17T17:55:29Z] Operator decision: top noisy models data must persist in notes repo (not just live in gchat).
- [2026-05-17T17:58:09Z] `mitigated-alerts/NOISY-MODELS.md` created; cron extended to append per-run. Commit `7d375228b6a2`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mitigated-alerts/NOISY-MODELS.md` | Created; append-only trend table seeded with 2026-05-17 top-2 models |
| `ot-daily-learning-mitigated-alerts.md` | Step 11 added: chronic-noisy model surfacing (top-3 percentile + ≥3 floor) |

## Cluster / pattern references

- [CL-003] — ZippyDB RE throttling (P58) confirmed on 3 AGG/SPARSE_DELTA alerts in this run.

## Followup items (not yet done)

_(No explicit followup discussed — NOISY-MODELS.md ships closes the loop.)_

## Cross-refs

- SEVs discussed: S665163 (ZippyDB RE throttling, mitigated 08:19 PDT)
- Related threads: `aT68OxqVFtA` (first digest run same day), `Uc-pVBEXNQ8` (mitigated-alerts folder improvements)
