# OT Early-Warning — example-age trend-toward-threshold (2026-06-15)

> **REPORT-ONLY. This detector NEVER pages, escalates, or mutates any external state.** It exists to ACCRUE precision + lead-time data so a *future* gated proactive-paging loop (Problem #3 — "signal before first page") can be calibrated at a bounded false-alarm rate. Enabling the page is a deliberate boundary expansion = **the operator's switch** (see `eval/early-warning-loop-proposal.md`). Until then this file is the entire deliverable.

_Metric: `dpp_worker.scribe_example_age_ms.avg.60` (KM-T1 training example age), model-level rollup entity. Same source+query as `scan-scribe-age.sh` / `eval-online-correlate.sh`; this tool keeps the full 4h @ 5m series to fit a trend. Bands: healthy <5min · elevated 5-30min · unhealthy/SEV >30min._

**Fleet this run:** 59/61 models with data · healthy 48 · elevated-stable 3 · **approaching 3** · already-unhealthy 5 · no-data 2 · errors 0.

## Currently APPROACHING (elevated + rising toward 30min)

| model_entity_id | age (min) | slope (min/hr) | gap to 30min | est. lead (min) |
|---|---|---|---|---|
| 2139705840 | 26.44 | 7.11 | 3.56 | **30.1** |
| 2124428748 | 12.67 | 2.79 | 17.33 | **372.8** |
| 2137792444 | 13.93 | 2.05 | 16.07 | **470.6** |

_Sorted by soonest estimated breach. These are CANDIDATES being recorded for precision accrual — no action is taken._

## Precision engine (outcome reconciliation)

**Status: ACCRUING — 4 settled event(s), need ~20 before precision is trustworthy**

| metric | value |
|---|---|
| settled events (TP + recovered) | 4 |
| true positives (later breached >30min) | 0 |
| recovered (candidate false-alarm) | 4 |
| pending (lead window not elapsed / unobserved) | 3 |
| **precision** = TP / settled | 0.0 |
| **median lead-time** (TP events) | accruing |

> Not enough SETTLED events yet to trust a precision number. The detector records ~1 candidate-set per run and settles each only after its lead window elapses, so the dataset grows over days/weeks. A precision figure is reported once **≥20** events have settled. **Calibrating the paging gate needs this number** — until then the gate stays OFF. This is the standing measurement that unblocks Problem #3, not a number today.

## How this feeds the future paging gate

1. This detector accrues `(approaching-event → actual-outcome)` pairs into `early-warning-history.jsonl`.
2. Once **≥20** events settle, precision + median-lead become trustworthy.
3. The operator picks a precision floor (bounded false-alarm rate) and flips the gate ON — at that point, and only then, an approaching-event with sufficient confidence may page. That switch is the operator's, not this tool's.

_Window: 4h @ 5m ODS · slope = OLS min-age/hour · min-slope-to-flag 1.0 min/hr · 4/20 events settled toward calibration._
