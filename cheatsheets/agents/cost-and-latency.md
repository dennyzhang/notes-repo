# Cost & Latency Principles for Autonomous Workflows

Sibling to `autonomous-workflow-principles.md`. Those 20 principles cover **reliability + correctness + safety**;
this file covers the **two dimensions they don't measure**: $/case and seconds/case. Same forensic bar — every
principle states the rule, the *why*, and the concrete practice grounded in real signal.

The cost telemetry already exists (`scripts/cron-token-usage-alert.sh` emits tiered SOFT/WARN/HARD signals from
`meta ai.usage summary`; history at `state/token-usage/history.jsonl`). What's missing is making cost + latency
**first-class eval/gate dimensions** for every workflow, not just a fleet-wide cap monitor.

---

## VI. COST — spend is a measured outcome, not a side effect

**21. Every eval emits `$/case` and `tokens/case` alongside quality.**
Why: a change that lifts composite by 0.02 while doubling cost is a regression dressed as a win. Without the
cost column the gate can't see it. Practice: extend the eval row to `composite, $/case, p50/p95_tokens, p50/p95_seconds`;
promotion gate is `quality ↑ AND cost ≤ +X% AND latency ≤ +Y%` — never quality alone. Reference: the existing
`building-agent-evals.md` mean ± std discipline applies per-dimension; cost gets the same ±band as quality.

**22. Model tier by task class — Opus is not the default for everything.**
Why: subagents inherit the parent model, so a one-line "this Opus session spawns 30 classifier dims" is a
silent 10–30× cost multiplier vs. Haiku for the same accuracy. Practice (a decision rule, not a debate per call):
- **Deterministic / mechanical** (parse, regex, schema validate, dedup, link-extract) → **code**, no LLM.
- **Classification / extraction** (tag, score, route, summarize-one-line, sentiment) → **Haiku**.
- **Synthesis / cross-check / drafting** (compose digest, generate diff summary, write a reply) → **Sonnet**.
- **Hard judge / adversarial verify / planning** (eval grader, novel-problem reasoning, multi-step plan) → **Opus**.
- **Reasoning panel** (N-vote) → cheapest tier that maintains agreement; escalate ONE judge to Opus only on disagreement.

The Workflow tool's `agent({model})` and `Agent({model})` both accept an override — *use it*. Inheriting parent
model is the wrong default for fan-out: the parent picked Opus for its OWN reasoning, not for 30 subagents each
classifying one item.

**23. Tokens are a measured dimension on the same loop as quality.**
Why: §14 has a feedback-effectiveness loop for *correctness*; cost has no such loop today. A drift that adds
20% cost per week looks fine — nothing is watching the rate of change at the workflow level. Practice: for any
workflow shipping >$X/run or >K runs/day, log per-run `tokens, $, wall_clock` to a workflow-scoped jsonl;
weekly cron reports the workflow-level trend. The fleet-wide `cron-token-usage-alert.sh` catches the macro
budget; the per-workflow log catches the *attribution* — "which workflow blew up this week?"

**24. Cost-aware shrink ladder — when to compute less, not just present less.**
Why: §0 (density) is about *output* size; this is about *input + compute* size. Practice for any workflow that
fans out: (a) **deterministic pre-filter** before LLM (a regex/SQL that drops 80% of candidates costs ~0 tokens),
(b) **cheap classifier first**, escalate only the uncertain set to the expensive judge, (c) **cap fan-out width**
explicitly — `max_parallel=N` based on cost budget, not "as many as I have items." A 200-item parallel fan-out at
Opus is the silent budget-killer; a 200-item fan-out at Haiku with 20 escalations to Opus is the same accuracy at
~5% the cost.

---

## VII. LATENCY — wall clock is a budget, not just a timeout

**25. Each workflow declares a `latency_budget_seconds`; over-budget is a finding.**
Why: a 5-min job that drifts to 9 min is invisible until it bumps the cron `cron_run` timeout backstop —
narrated as "~6.5 min, worth watching" instead of acted on (real incident, autonomous-workflow-principles §6).
Practice: define the budget at workflow-create time; instrument `actual / budget` ratio per run; emit
`over_budget=true` as a structured finding (→ attention brief), NOT a log line. Sibling of §15
(measure what you optimize); §6's run-health audit covered THAT incident, this generalizes it.

**26. Fast-path / slow-path tiering — cheap deterministic check before any LLM call.**
Why: most "is this interesting?" decisions are answerable in <10ms by a regex, a SQL count, or a sentinel
file — no LLM needed. Practice: every classifier-shaped workflow has a deterministic gate BEFORE the LLM;
LLM fires only on the items the gate flags as uncertain. Cuts both cost AND latency by ~10× on typical
distributions. Failing to add the gate is the default; you have to *choose* to add it.

**27. Graceful degrade emits PARTIAL with explicit coverage — never a silent crop.**
Why: a workflow that hits its budget and silently truncates to N items reports "ran clean" while having judged
~nothing (the gated-detector trap from §6, restated for latency). Practice: on budget exhaustion, emit
`evaluated_n, skipped_n, reason='budget_exhausted'` exactly like §6's gated-scan reconciliation; never let
truncation read as "all clear." A partial run that says so is honest; a partial run that doesn't is the
worst failure mode.

**28. Concurrency cap = the lowest of {API rate limit, cost budget, observability budget}.**
Why: unbounded `parallel()` of subagents will hit *something* — rate limit (visible), cost budget (invisible
until the speeding ticket), or your own ability to debug (invisible until something fails and 50 logs scroll
past). Practice: pick the cap explicitly; default to ≤8 for cron workflows, ≤16 for interactive. The
Workflow tool already caps at `min(16, cores-2)`; reuse that bound for hand-rolled fan-outs.

---

## Pre-ship gate additions (extends `autonomous-workflow-principles.md` § Pre-ship gate)

For ANY new or changed cron / digest / workflow, in addition to the existing 8 checks:

9. **Cost dimension** — eval reports `$/case` and `tokens/case`; promotion gate has a cost ceiling (§21). ☐
10. **Model tier** — every LLM call labeled with task-class and assigned tier per §22; no implicit
    parent-model inheritance for fan-out subagents. ☐
11. **Latency budget** — workflow declares `latency_budget_seconds`; over-budget emits a finding (§25). ☐
12. **Deterministic pre-filter** — any LLM fan-out has a cheap gate in front of it OR documents why none
    is possible (§24/§26). ☐
13. **Concurrency cap** — `max_parallel` set explicitly, justified by the lowest of {rate, cost, debug} (§28). ☐

These compose with the existing 8; same rule — a check that can't be satisfied by a *mechanism* is the
signal to build the mechanism, not to wave through.

---

## What this builds on (already exists — don't re-implement)

| Capability | Where it lives | What this cheatsheet adds |
|---|---|---|
| Fleet-wide token-cost monitoring with SOFT/WARN/HARD tiers | `scripts/cron-token-usage-alert.sh` + `state/token-usage/history.jsonl` | per-workflow attribution + eval-level cost gating |
| Tiered signals → agent self-correct | `state/token-usage/SIGNALS.md` + `PENDING-BRIEF.md` | the "speeding ticket" pattern (memory `feedback_early_signals_over_hard_alerts.md`) applied per-workflow, not just fleet |
| Workflow concurrency cap | Workflow tool: `min(16, cores-2)` | extend to hand-rolled fan-outs in cron scripts |
| Latency timeout backstop | `cron_run <timeout>` wrapper | budget-as-finding (not just timeout-as-kill) |
| Cost telemetry endpoint | `meta ai.usage summary -o json` | per-workflow tagging so attribution is mechanical |

---

## The one-sentence version

**A high-quality autonomous workflow earns its quality at the lowest cost and latency it can — measures both
on the same loop as correctness, picks the cheapest model that does the job, and degrades to honest partial
output before silently overspending the budget.**

_Last updated: 2026-06-17. Maintainer: dennyzhang. Source: gap analysis of `autonomous-workflow-principles.md`
against the four operator goals (reliability, quality, latency, cost) — only the first two were covered._
