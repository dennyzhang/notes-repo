# From Tactical to Strategic — Domain-Model-Driven Leverage

_Design conversation, 2026-06-11/12 (operator: dennyzhang). Captures the
problem framing and solution design for evolving the OT agent beyond
per-incident tactical handling toward leveraged, strategic output. Not yet
built — this is the design of record so future sessions don't re-derive it._

## The problem, in one sentence

The agent is the only thing in the loop with **firehose bandwidth on the
domain** — it sees every SEV, alert, post, diff, and new capability,
continuously and completely — but it spends that bandwidth **one incident at
a time** and never builds the cross-stream model that only it is positioned to
build. The operator (SRE/PE) is stuck at **straw bandwidth**: the fires they
personally touch, re-deriving the domain's structure the slow way by living
through enough incidents to notice the shape.

The current closed loop is **inductive and local**: incident → pattern →
P-row/R-rule. Each pass makes the *next* instance of that incident handled
slightly better. Nothing reads the **distribution** of the stream and asks the
higher-altitude questions. That is the leverage left on the table:
**synthesis across the stream.**

## The four altitudes (one capability, four views)

The pieces the operator asked for are not four features — they are the same
missing capability (synthesis across the stream) viewed at four altitudes,
forming one pipeline **diagnose → select → plan**, with **learning running
alongside**:

1. **Diagnose — what's broken.** The structural failure *classes*, not
   instances (the "hard problems"). Read the distribution, not the reading.
2. **Select — where to bet.** Which problem to actually solve, under
   constraint. This is risk-adjusted bet-picking, not a sort.
3. **Plan — how to win.** The strategy / game plan for the chosen problem,
   as a falsifiable campaign.
4. **Learn — what the operator must know.** Accelerate the operator's
   learning of the domain itself, including new capabilities (e.g. RES =
   Raw Embedding Streaming) surfacing in incidents. "I don't know what I
   should know" = the unknown-unknowns problem.

Learning is not a separate track: the operator absorbs the domain *by reading*
the map and the bet-arguments the agent produces, instead of by getting paged.

## Why it doesn't happen today (root causes)

Two structural causes, both of which the solution must address:

1. **No domain model.** The self-improvement loop produces *per-incident
   rules* (`known-patterns.md`, P-rows). There is no artifact representing the
   *structure* of the domain — capability inventory, failure taxonomy, the
   dependency graph between them. Without that substrate, every higher-altitude
   question has nothing to read.

2. **The decision-inputs for the high altitudes aren't in the corpus.** The
   incident stream is **survivorship-biased toward loud failures.** It carries
   frequency and severity. It does **not** carry: **toil**, **silent/chronic
   degradation** (sub-threshold problems that never trip a SEV),
   **cost-to-fix**, **control** (who owns the fix), **durability** (is the
   capability rising or sunsetting), or the **counterfactual** (is it already
   being fixed by in-flight work). Selection and strategy are exactly the
   layers that need these — so they cannot be real until that data is sourced.

## The solution

**Make the agent a domain-model builder, and derive all four outputs from that
model under strict ground-truth discipline.**

### Layer 0 — a living domain map (the substrate)

A persistent artifact (notes tree) representing OT structurally, built **for
free off the existing loop**: the daily triage already touches every incident;
add one step so each incident also updates the map (which failure class? any
novel entity + first-appearance date? increment counts, attach the ID, note the
operator's knowledge gap). The aggregate emerges incrementally — no separate
firehose-reader needed. Contents:

- **Capability inventory** — sparse streaming, dense delta, multicast, RES, …
  what exists, *first-appearance date* (so "new" is first-class), what each
  replaced (the architectural delta).
- **Failure taxonomy** — the classes, each linked to its incident instances.
- **Per node:** frequency · severity · toil · cost-to-fix · control/owner ·
  durability (lifecycle) · operator knowledge-gap.

### Layer 1 — the derived pipeline (low cadence, propose-only)

- **Diagnose.** Read the distribution: rank failure classes by
  frequency×severity×toil. Spot **dependency-graph enablers** — a root that
  recurs across multiple classes' causal chains, the low-glamour fix that
  collapses several at once or *unlocks* the ability to fix them. An agent
  reading the whole taxonomy connects these; a human seeing only their own
  slices cannot. This is a concrete way AI synthesis beats human synthesis.

- **Select.** Turn the ranked list into **risk-adjusted bets**
  (EV = P(success) × value × durability − cost), each tagged by:
  - **Leverage type:** *eliminate* (fix root, class disappears) / *detect*
    (cut MTTR, catch sub-threshold) / *absorb* (auto-remediate, toil goes
    away) / *hand-off* (upstream, make it someone else's *tracked* problem
    with an acceptance metric).
  - **Control:** I fix it in-lane (P-016) vs I can only escalate/influence
    (P-017).
  - **Mandatory adversarial alternative:** present the runner-up bet and why
    it might be the right call instead — the antidote to selection theater
    (same shape as the validator / codex adversarial pass).
  - **The agent ranks and argues; the operator picks.** Selection among
    near-ties depends on context the agent lacks (manager priorities, team
    capacity, org politics, what the operator wants to be known for).

- **Plan.** The chosen bet becomes a **falsifiable campaign:** goal stated as
  a metric (X→Y = the acceptance test) → **critical-unknown-first** sequencing
  (milestone 1 resolves the one thing that decides whether the whole plan works,
  cheaply) → kill-criterion → owner map (mine / escalate / hand-off).
  Probe-first, never "commit the big fix" up front.

- **Learn.** From the novelty + knowledge-gap fields, an *ordered* curriculum
  (prerequisite structure: architecture → the capability on top of it → its
  failure modes), each primer **assembled from the incident trail + skill docs,
  never training priors** (RES especially — a freshly-launched internal
  capability is exactly what an LLM gets wrong). Acceleration mechanisms:
  1. **Compression** — fold N incidents into one structural lesson; the
     operator reads the conclusion instead of living through all N.
  2. **Naming unknown-unknowns** — convert unknown-unknown → known-unknown
     ("RES is now on your hook"). The highest-value step; you can't accelerate
     toward a target you can't name.
  3. **Pre-runbook assembly** — for a new capability still throwing SEVs, the
     official doc doesn't exist yet; assemble the de-facto runbook from the
     incident trail before the operator gets paged.
  4. **Just-in-time delivery** — when a live incident touches a capability the
     operator is weak on, inject the 2-line mental model right then. Learning
     at point-of-need beats a separate study session.

### Layer 2 — the discipline (because every output here is leveraged)

A wrong "hard problem," wrong bet, or wrong primer is **worse than nothing** —
it's high-leverage and the operator will trust it as their map. So:

- **Show the work** — every claim sourced to incident IDs + live queries.
  Anything unsourceable is marked `unknown` (never fabricated) and *that
  unknown becomes the first probe.*
- **Falsifiable** — each hard-problem / bet states "if this is true, query X
  shows Y."
- **Propose-only, human-gated, 1:1 not team** — these are operator-facing
  (learning curriculum is keyed to the operator), so they go to the 1:1, never
  the team room (consistent with the audience gate in CLAUDE.md).
- **Novelty gate** — a new entity enters the curriculum only with
  incident-attachment (≥2-3 real issues) + recurrence; else every new acronym
  drowns the real ones.

## The honest hard part (build this first)

The entire edifice's quality is capped by the **least-available data**: toil,
silent degradation, cost-to-fix, and the in-flight counterfactual. The
loud-incident corpus does not have them.

- **Diagnose** works on today's corpus.
- **Select** and **Plan** do **not** — until a **second sourcing channel**
  exists: alert near-misses, repeated manual interventions that never became
  SEVs, metric trends, and in-flight diffs/migrations.

That second channel is the real prerequisite. Until it's built, the
select/plan layers are plausible-sounding, not real. It is the first thing to
build and the thing to be most skeptical of if skipped.

## Cheapest validation probe (when we build)

Don't build the cron first. Run the synthesis **once, by hand**, over the
existing corpus and judge it on one question: *does it surface a hard problem
(or a RES capability brief) with a leverage argument the operator didn't
already have, assembled from data — or does it just reproduce
`known-patterns.md`?* If the latter, the hypothesis is wrong and we've spent an
hour. RES is the natural worked example for the learning axis.

## Provenance

Operator design conversation 2026-06-11/12. Operator framing, verbatim themes:
"all tactical … the agent should have sufficient context to derive what are the
hard problems in the domain … more leveraged wins"; "new workflow and new
capabilities exposed in the incidences … RES … I'm behind … I just don't know
what I should know"; "another hard problem is: which problem to solve … what's
the strategy or game plan to solve the problems."
