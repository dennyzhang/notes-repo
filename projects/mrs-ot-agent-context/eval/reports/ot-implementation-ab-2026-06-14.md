# A/B: does `ot-implementation.md` (diff-distilled comprehension corpus) improve triage? — NO

**Date:** 2026-06-14 · **Harness:** eval-flow.js (complete metric, full 77-case gold set) · **Method:** baseline (SKILL+known-patterns+triage-discipline) vs treatment (same + ot-implementation.md), 2 full runs each arm.

## Result — no measurable lift; mild downside

| metric | baseline (0.725, 0.765) | treatment (0.696, 0.772) | Δ mean | call |
|---|---|---|---|---|
| composite | 0.745 | 0.734 | −0.011 | within noise — NO LIFT |
| detection_recall | 0.769 | 0.853 | +0.084 | suggestive, noisy (overlap) |
| hallucination_rate | 0.094 | 0.137 | +0.043 | worse |
| scoping_precision | 0.800 | 0.750 | −0.050 | worse |

Noise band (baseline, complete metric): composite ±~0.04; detection_recall ±~0.05+ (subset). Treatment composite range (0.696–0.772) is *wider* than baseline — high variance, no central shift.

## Mechanism (why it didn't help — and a coherent story)
The corpus shifts the agent toward "everything is a real mechanism": **detection_recall up, but scoping_precision down + hallucination up** — it raises recall by lowering the dismissal threshold, not by raising the accuracy frontier. Net wash on composite.

**Smoking gun (both treatment runs):** on the STUS real-failure ALERT-1955974545038771, the agent **cited `ot-implementation.md` by name** ("NULL publish_mode for retrieval models pages chronically, D107403198/D107672307") to *justify inverting a real publish stall into a detector-false-alarm*. The corpus's "monitoring false-positives" content became ammunition to dismiss a real failure. Graded leak_suspect + hallucination=1.

## Decision
- **Do NOT wire `ot-implementation.md` into the live agent.** It fails the proof; it adds context cost + a tendency to over-rationalize false-alarms with no composite gain.
- Keep the file in notes as a reference artifact (not loaded), and as the input for a *redesigned* future iteration (lead with real-failure fingerprints + verify-before-dismiss gates; drop/quarantine the false-alarm catalog).

## Strategic implication (grounded in all 6 runs)
The triage bottleneck is **NOT mechanism comprehension** — root_cause held 0.78–0.80 in *both* arms; the agent already reasons about mechanisms well. The bottleneck is **judgment + routing**:
- **owner_accuracy ~0.38–0.41 is the stable floor across all 6 runs** — the single biggest, most consistent weakness. An owner/ownership-map aid (from people/gchat data) would likely move the composite more than any comprehension corpus.
- **dismissal calibration** — the recurring hard-misses (STUS inversion, TMS-transient-as-GIL) are judgment failures; the fix is a verify-before-dismiss guard, not more knowledge.

→ Pivot ingestion/optimization effort from "teach more mechanism" to "fix owner routing + dismissal judgment."

## Harness wins banked this session (durable, regardless of the negative result)
- Fixed shard-contamination (stale `/tmp/eval-daemon-shard.json` silently turned a full-77 run into a 5-case shard 1).
- `EVAL_CAP` 60→77 (full corpus removes sampling noise).
- `args.with_impl` A/B toggle.
- **Computed `detection_recall` + `scoping_precision`** from existing gold-set verdict labels (were hardcoded null → metric was 35% blind on the most important dim; now 100% weight covered).
