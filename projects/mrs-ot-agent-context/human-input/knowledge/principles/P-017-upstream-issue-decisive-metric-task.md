# P-017: Upstream Recurring Issue → Decisive-Metric Task, Not Repeated Narration

**Statement:** When an issue is **recurring + high-confidence + upstream** (root cause outside the agent's control — core platform, another team's service, a not-yet-landed dependency), the generic next step is **one follow-up task anchored on a decisive, reproducible metric query**. The query (a) confirms the issue from ground-truth data, not narration, and (b) is the **acceptance test** for when the upstream owner's fix lands. Then **monitor the metric — stop re-triaging and re-narrating the symptom each occurrence.**

**Discovered:** 2026-06-09 thread `jPPo82dAT4M`. Operator: *"There should be a follow-up task for a recurring and high confidence issue. E.g, build decisive metric query to confirm this issue"* → *"This follow up should be a generic next step for recurring + high confidence + upstream issues. Right?"* Context: 4 consecutive team-chat volume audits re-diagnosed the same team-space delivery leak in prose; the root cause was upstream (myclaw-core daemon routing, D107579040 consumer unbuilt), so no amount of in-lane prose moved the number.

**Why it matters:** The agent's failure mode for an unfixable-here issue is to re-diagnose it every time it recurs — producing N rounds of narration that all say the same thing and bury real signal. That's motion, not progress. A decisive metric query converts "I keep noticing X" into "X is measured at Y, target Z, here's the one task that closes when Y crosses Z." It also stops the agent from emitting confident prose in place of a number it could have computed.

**Applies to:** any recurring issue whose root cause the agent cannot directly land — core/platform bugs, another team's SEV, an unmerged dependency, a hardware/infra limit. NOT for in-lane-fixable issues (those are [P-016](./P-016-full-ownership-on-every-fix.md): fix end-to-end).

## The gate — who owns the root cause?

```
Issue recurring + high-confidence?
  └─ Is the root cause IN MY LANE (config/prompt/script/R-rule I can edit)?
        ├─ Yes → P-016: fix it end-to-end (diagnose, land, verify, push, monitor). No standing task needed.
        └─ No (UPSTREAM: core / other team / unlanded dep) → P-017:
              1. Build a DECISIVE metric query (deterministic, ground-truth source, reproducible).
              2. Run it → record the CONFIRMED baseline number.
              3. File ONE follow-up task: query + baseline + acceptance threshold + link to the root-cause task.
              4. Monitor the metric. Do NOT re-narrate the symptom on each recurrence.
```

The **upstream qualifier is the whole distinction.** P-016 and P-017 are complementary: P-016 = "you can fix it, so fix it"; P-017 = "you can't fix it, so measure it, track it, and hand it off with an acceptance test."

## What makes the metric query "decisive"

| Property | Why | Anti-pattern it kills |
|---|---|---|
| **Ground-truth source** | The number must come from authoritative data, not the agent's narration or a derived log. | Counting from an ingestion/cache log that isn't the real event (e.g. local `messages` table = ingestion, not sends). |
| **Deterministic / reproducible** | Anyone (or a cron) can re-run it and get the same answer; no LLM judgment in the count. | "Precision looks like ~2%" from per-message LLM classification that can rate its own leak as signal. |
| **Robust to known confounds** | Encode the gotchas (e.g. classify by content-prefix when sender-id is unreliable). | A filter that silently mis-buckets (sender-id filter when bot posts render under the operator's id). |
| **Doubles as acceptance test** | A single threshold ("≥90% over 24h") defines "fixed." The task closes on the number, not on prose. | An open task that lingers because "is it fixed yet?" is answered by vibes. |

## Worked example (the founding instance)

Team-chat delivery leak — recurring (4 audits 2026-06-08/09), high-confidence, **upstream** (myclaw-core: `cross_space.py` ungated + daemon auto-delivers non-`HEARTBEAT_OK` final responses; fix is D107579040's unbuilt core consumer):
- **Decisive query:** `tools/team-space-precision.sh [HOURS]` — pulls team-space posts from the **live GChat API** (not the local `messages` ingestion log), classifies by **content prefix** (robust to bot-posts-render-under-operator-id), emits precision + per-source noise as JSON. No LLM judgment.
- **Confirmed baseline:** 24h precision = **9.5%** (42 bot posts, 4 signal, 38 noise; 30 = `🛟 MyClaw-OT` interactive leak).
- **Task:** `T275122535` — carries query + baseline + **acceptance test (≥90% over 24h, interactive=0)**, links root-cause `T274834361`. Closes when the number crosses the bar, not when an audit says so.
- **Behavior change:** stop posting a fresh prose diagnosis on every volume audit; the metric is the status.

## Anti-patterns this principle prevents

- Re-diagnosing the same upstream issue in prose on every recurrence (N audits, one root cause, zero new information).
- An open issue with no decisive number — "is it fixed?" answered by re-reading symptoms instead of re-running one query.
- A metric derived from narration or a non-authoritative cache instead of ground truth.
- Treating "I filed a task" as done when the task has no acceptance test (it never closes cleanly).
- Confusing P-016 and P-017: trying to "fix" an upstream issue in-lane with prose (cron-prompt whack-a-mole when the daemon is the cause), OR filing a tracking task for something you could just fix.

## Enforcement

- **On every recurring + high-confidence issue, ask: is the root cause in my lane?** If no → don't write another diagnosis; write/῍run the decisive query and file (or update) the one tracking task with an acceptance threshold.
- **Every such task must contain a runnable query + a confirmed baseline + a numeric acceptance threshold + a link to the root-cause task.**
- **Subsequent recurrences update the metric, not the prose.** A new narration of a tracked upstream issue is the noise this principle exists to stop.

## Related principles

- [P-016](./P-016-full-ownership-on-every-fix.md) — Full ownership on in-lane fixes. P-017 is its upstream counterpart: when you can't fix it, the ownership move is measure + track + acceptance-test.
- [P-003](./P-003-generalize-to-system-rule.md) — Promote a local fix to a system rule. P-017 itself was promoted via this principle (operator: "generic next step").
- [P-008](./P-008-history-repeats.md) — History repeats; recurrence is the trigger condition for P-017.
- [P-009](./P-009-validator-coverage-asymptotic.md) — Measurement/validation coverage as the durable defense; the decisive metric is that defense for upstream issues.
