# Baseline — confirmed (2026-06-12): 2 eval-flow runs + 1 eval-scoping run

First clean end-to-end runs after the throttle + report-crash (`files`/`allCases`/`eligible`
ReferenceError) fixes. **Eval is noisy at n≈56–59** — the triage composite swung 0.65↔0.70 between
two identical-config runs, so report MEANS with ranges, never a single run.

## Triage (eval-flow.js, frozen 60-case gold set)

| dim | run1 (wf_acfb4f12) | run2 (wf_f17605f6) | mean (range) |
|---|---|---|---|
| composite (triage, 65% wt) | 0.704 | 0.646 | **0.675** (0.65–0.70) |
| calibration | 0.818 | 0.767 | 0.79 (0.77–0.82) |
| owner | 0.39 | 0.33 | 0.36 (0.33–0.39) |
| decisiveness | 0.754 | 0.679 | 0.72 (0.68–0.75) |
| hallucination (gate) | 0.119 | 0.161 | 0.14 (0.12–0.16) |
| root_cause_acc | 0.729 | 0.821 | 0.78 |
| n_evaluated | 59 | 56 | — |
| generalization_gap | +0.012 | −0.028 | ≈ 0 (not memorizing) |

## Scoping (eval-scoping.js, 1 run, corpus RE-MINED — noisy)
- detection_recall **0.833** (12 positives, 2 missed: S657690, S673569 — both tagging/routing, not diagnosis)
- scoping_precision **1.00** (29 negatives all dropped, incl. Ads ads_mtml S657101 trap)

## Full composite (mean dims + scoping) ≈ **0.76**

## Weakest components (consistent across BOTH runs → the evolve-loop's re-pointed targets)
- scope-detector: rc ~0.67, halluc 0.33
- T2-training: rc ~0.63

## Methodology TODOs surfaced
1. **Report mean ± std over k runs** — single-run deltas (±0.03) are unreliable; small composite changes can't be trusted from one run.
2. **Freeze the scoping corpus** like the gold set (it re-mines each run → detection_recall not comparable run-to-run; 0.833 here vs 0.96 prior is corpus difference, not regression).
