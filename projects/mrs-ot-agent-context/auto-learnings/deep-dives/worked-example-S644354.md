# Worked Example — S644354

End-to-end Phase 1 → Phase 3 routing on a real OT SEV. Use this shape when producing a new triage report.

> **Back to:** [SKILL.md](../../../mrs-ot-agent-src/SKILL.md)

**Input:** `S644354` (also resolvable: `mvai-training-online-2134440419`)

**Phase 1 captured signals (18s):**
- 3 consecutive FAILED attempts, durations 16h53m → 15h31m → 7h14m → RUNNING (accelerating failure)
- Zoomer insight: `Excessive GPU communication time` (WARNING) — 40%+ comm overhead
- GPU device util 89.6% avg, SM util 37.6% — communication-bound, not compute-bound
- 10 hosts in nha5 region, no rank-specific errors → not single-host failure
- Last kill: user `chrisleung` (manual intervention)
- No CUDA OOM (memory util 46.4% avg, 82.6% max)

**Phase 3 verdict:**
- Bottleneck: **T2 (Training)** with likely **T3 (Publishing)** contribution
- Top hypothesis: **[P19](../../../mrs-ot-agent-src/known_patterns.md)** (HIGH confidence) — captured signals match the pattern's keyword signature
- Red herrings: cross-checked against [Ruled-Out list in known_patterns.md](../../../mrs-ot-agent-src/known_patterns.md)

**Recommended action:**
1. Query `gmpp` Scuba for FULL_SNAPSHOT events at failure timestamps (03:12, 18:45, 02:02)
2. If publish-correlated, disable concurrent delta + migrate to DeltaOnlyPublisher (S628346 fix)
3. Check IG OT SLO dashboard — is 1 restart/day within 8h/week budget?

**MAST URL:** https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-2134440419
**SEV URL:** https://www.internalfb.com/sevmanager/view/644354
**Full validation:** _(journals/S644354-validation.md — not yet written)_

Time saved: 18s vs 4 days of human triage to reach the same top hypothesis.
