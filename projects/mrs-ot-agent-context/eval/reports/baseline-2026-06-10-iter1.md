# OT agent eval — 2026-06-10 iter1 (signal-integrity fixed)

composite=0.526 | weight_covered=65% | n=60 | harness_excluded=0
dims: calibration=0.641 owner=0.25 decisiveness=0.533 detection=null scoping=null
hallucination-gated: 18/60 (GENUINE — malformed retried to 0)
by_type root_cause_acc: alert=0.638(n29), post=0.792(n12), sev=0.658(n19)
generalization=0.518 gap=0.008

## Key finding
Fixing the 2 harness bugs did NOT inflate the score (0.528->0.526) — it CONFIRMED a real hallucination problem: 18/60 cases carry a confident fabrication.
Systematic pattern: confident R-rule confabulation (agent invents/misattributes R-rules, e.g. a fake 'R19 structural _retrieval detector rule'). Cases: A878102693-413, ALERT-1002291152283272, ALERT-1011200521237714, ALERT-1021144657237695, ALERT-1201406268614142, ALERT-1427819186056622, ALERT-1473457624222843, ALERT-1480195820275950
=> #1 evolve target: citation-discipline guard (P-007) — verify R-rule/P-row definition before citing.

## Diagnostics
- root_cause_accuracy=0.675
- p_row_accuracy=0.575
- owner_accuracy=0.333
- verdict_calibration=0.733
- hallucination_rate=0.3
- leak_suspect_rate=0.183

## Still open: detection_recall+scoping_precision (need false-negative + noise corpus); temporal hold-out.