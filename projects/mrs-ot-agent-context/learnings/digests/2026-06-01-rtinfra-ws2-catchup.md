# 2026-06-01 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 5 human messages spanning 2026-05-29T10:00 → 2026-06-01T06:27 in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Josef Cohen (jcohen1), Dave Kotfis (dkotfis))._

_Window: 7d. Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

**SLO breach actively forming — scribe age + model age combined = 11-12 min (SLO ≤10 min):**
- P90 `dpp_worker.scribe_example_age_ms` spiking to ~11 min as of 2026-05-29 (Dave Kotfis)
- Item streaming job QPS dropped overnight → ~2 min training delay regression vs previous model
- Combined effect: scribe pipeline delay + model age = ~11-12 min total, trending past SLO threshold
- **Canonical Scuba URL (new):** https://fburl.com/scuba/dpp_stats_v2/k387vbo3 — P90 dpp_stats_v2 scribe example age view; team uses this as primary SLO debug surface
  - Bot should add this URL to its SLO triage reference for `dpp_worker.scribe_example_age_ms` checks

**Remaining scribe regression as of 2026-06-01 (Josef Cohen):**
- ~1 min regression still present in scribe the morning of 2026-06-01, after partial recovery
- QPS had recovered somewhat but a 1 min floor remains

## P1 — significant nuance / sub-mechanisms

**Scribe read vs write time not currently isolated in DFM:**
- Josef Cohen proposed expanding DFM data to include recopublisher scribe categories, separating read and write scribe time
- Current DFM aggregation bundles read+write → debugging a scribe regression requires manual Scuba cross-reference
- This is an upcoming DFM schema change; bot's scribe-age triage should note that `scribe_read_proxy` and `dpp_worker.scribe_example_age_ms` may diverge due to this layering (per prior message context in thread)

**Item streaming QPS drop → training delay sub-mechanism:**
- QPS drop on item streaming job produces a delayed training lag (not a stallout / MAST failure)
- Recovery path: QPS recovers on its own; residual lag from scribe pipeline takes longer to clear
- Distinct from: NCCL timeout, publisher crash, MAST eviction — this is upstream data-pipeline lag

## P2 — references / good-to-know

- Scuba view: `dpp_stats_v2` dataset, P90 on `dpp_worker.scribe_example_age_ms` → https://fburl.com/scuba/dpp_stats_v2/k387vbo3
- Current thread is discussing scribe_read_proxy vs dpp_worker.scribe_example_age_ms differences as root of measurement inconsistency

## Cross-references

None this week — no CL-NNN or P-NN confirmations or contradictions.

## Open coordination threads

- **DFM expansion (Josef Cohen):** Proposal open to expand recopublisher scribe categories in DFM for read/write isolation. No conclusion reached this week. Operator may want to follow up with Josef Cohen if this affects SLO dashboard methodology.
- **Scribe 1 min regression (unresolved as of 2026-06-01 06:27 PT):** Josef investigating this morning. Thread still active — outcome unknown at time of distillation.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Add `dpp_stats_v2` Scuba URL as canonical SLO debug surface for scribe age | Add to triage-auditor's SLO reference section: `dpp_worker.scribe_example_age_ms` P90 → `https://fburl.com/scuba/dpp_stats_v2/k387vbo3` | 15 min |
| P0 | SLO threshold context: scribe delay + model age → 11-12 min combined is the failure mode to watch | Add to failure-patterns.md under "SLO" section: combined-lag pattern (not just model age in isolation) | 20 min |
| P1 | DFM read/write isolation pending — note `scribe_read_proxy` ≠ `dpp_worker.scribe_example_age_ms` | Add disambiguation note to scribe-lag failure pattern | 10 min |
| P1 | Item streaming QPS drop → training delay (distinct from MAST failure / publisher crash) | Add to failure-patterns.md as upstream-data-lag sub-mechanism | 15 min |
