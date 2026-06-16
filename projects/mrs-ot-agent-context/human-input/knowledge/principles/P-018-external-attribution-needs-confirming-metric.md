# P-018: External-Attribution Verdicts Require a Built, Confirming Link-Metric (Class-Agnostic)

**Statement:** Any HIGH-confidence verdict whose root cause is an EXTERNAL attribution — an upstream SEV, an upstream service (Scribe / ZippyDB / TMS / Manifold / GMPP / …), or another team's code — must carry a `[VERIFIED]` metric that LINKS that cause to THIS entity's symptom: matching **scope** (right tenant / model / dependency) AND matching **time window**. "An external SEV exists + a similar symptom" is coexistence, not causation → `[INFERRED]`, never high. **If the confirming query does not exist, IDENTIFY and BUILD it** — then it becomes that verdict class's required artifact. The requirement is **CLASS-AGNOSTIC**: do not wait for a per-class guardrail row; the default for "it's caused by `<external thing>`" is *confirm-the-link-or-cap*.

**Discovered:** 2026-06-13 thread `j7iFKgBgtXg` (+ `e78lVJptOAI`). Operator: *"for issue triaged as upstream_infra with high confidence, we should always expect a solid evidence which can confirm this. If missing, you should identify and build the missing metric"* → *"shouldn't we detect and build solid query to confirm the upstream hypothesis?"* → *"debug why you miss to do this deeper follow-up."* Context: the bot classified `ig_organic_feed_mtml` (878102693) UPSTREAM_INFRA / high under S669133 ("root/Facebook/Feed over scribe quota"), but ground truth (Scuba `mast_admission_control_decisions`) showed the model runs on `root/Instagram/...`, was never quota-rejected, and sat under SLO → an inferred false-link. The confirming query was then built (`tools/confirm-upstream-scribe.sh`) and now REFUTES it.

**Why it matters:** "Blame upstream" is the agent's easiest escape hatch — a plausible verdict for the least work. Asserted at high confidence without a confirmed link, it MASKS the real (often in-lane) cause and routes attention to the wrong owner. **RCA for why it kept recurring** (operator had to push each time): the proof-of-work guardrails were added REACTIVELY — one artifact row per operator-caught miss — so every NEW shallow-verdict class escaped until flagged. UPSTREAM_INFRA was the live blind spot: every other high-stakes class required an artifact; it didn't. Making the requirement class-agnostic closes the blind spot for the NEXT external-attribution class without waiting to be pushed.

**Applies to:** any verdict of the form "the cause is `<external entity>`" at high/PAGE confidence — upstream SEVs, shared infra (Scribe/ZippyDB/TMS/Manifold/GMPP), foreign-team code, hardware limits. NOT for in-lane root causes (those are [P-016](./P-016-full-ownership-on-every-fix.md): fix end-to-end). Complements [P-017](./P-017-upstream-issue-decisive-metric-task.md): P-018 confirms the attribution *per verdict*; P-017 tracks it with a decisive-metric *task* when it recurs.

## The gate
```
Verdict root cause is EXTERNAL + confidence is high/PAGE?
  └─ Do I have a [VERIFIED] metric linking that cause to THIS entity's symptom (scope + window)?
        ├─ Yes               → high confidence earned; cite the metric.
        ├─ Query exists, unrun → run it. CONFIRMED → keep. REFUTED → flip verdict, cap, file a deduped owner task.
        └─ No query exists    → BUILD it (P-017 mechanics), then run. Until then: cap to [INFERRED] / MONITOR and dig.
```

## Enforcement
- `human-input/triage-discipline.md` § Anti-laziness proof-of-work table — the **UPSTREAM_INFRA row** + the **class-agnostic external-attribution bullet** (validator-enforced: the validator checks the diagnosis carries the artifact its class requires).
- Worked instance (scribe-quota / CL-003 / P57 class): `tools/confirm-upstream-scribe.sh` queries Scuba `mast_admission_control_decisions` (`rejected=1` + `policy_name=ONLINE_TRAINING_SCRIBE_USAGE` for the model's job + `tenant_path`). On REFUTED → deduped `owner=dennyzhang` tracking task; on CONFIRMED → the upstream SEV is the tracker (R20).

**Related:** [P-016](./P-016-full-ownership-on-every-fix.md) · [P-017](./P-017-upstream-issue-decisive-metric-task.md) · [P-009](./P-009-validator-coverage-asymptotic.md).
