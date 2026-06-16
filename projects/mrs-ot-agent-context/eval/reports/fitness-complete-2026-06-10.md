# OT agent fitness — COMPLETE (2026-06-10, weight_covered=100%)

composite = 0.576   (was 0.526 at 65% weight; complete number is HIGHER because scoping_precision is perfect)

dims (weight): calibration 0.641 (.35) | detection_recall 0.423 (.20) | scoping_precision 1 (.15) | owner 0.25 (.15) | decisiveness 0.533 (.15)

## The agent's profile is lopsided
- scoping_precision = 1: dropped ALL 24 out-of-scope (incl. Ads/DPA OT-keyword near-misses, the S657101 leak class). Excellent — but tested on OUT-OF-ORG negatives only; in-MRS-non-OT not yet tested, so true precision likely <1.0.
- detection_recall = 0.423: drops 15+ of 26 REAL OT incidents it should catch. THIS is the weak spot — and missing a real SEV is the highest-cost failure.

## Ranked evolve targets (now evidence-backed)
1. detection_recall 0.42 — agent's scoping gate is too aggressive at DROPPING real OT signals (high precision / low recall trade is mis-set toward silence).
2. owner 0.25 — routing.
3. 30% R-rule confabulation (citation-discipline guard, P-007).

## Caveats
- detection_recall is on auto_detected=false SEVs (strong proxy for 'should have caught', not a literal bot-triage record).
- scoping_precision needs in-MRS-non-OT negatives to be complete.
