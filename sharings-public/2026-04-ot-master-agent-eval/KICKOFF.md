# OT Master Agent — Eval Kickoff

**Started:** 2026-04-21
**Owner:** Denny Zhang
**Tracking:** T265884994 (registration + Scuba), T259215482 (parent project)

## Goal

1. **Validate** the OT Master Agent end-to-end workflow on real historical SEVs.
2. **Then** iterate on triage quality.

Order matters. No quality optimization before the loop runs end-to-end on at least one real case.

## Method: Replay-Eval

Borrowed from Harry Han's MVAI Agentic Oncall pattern (PE Anchor Week 2026):

> Ship at 40% accuracy. The goal is **investigation done**, not answer right. Oncall is the safety net for the other 60%.

Translation for OT: grade on **investigation completeness** (did the agent surface the right logs / configs / code / partner team?) — not root-cause correctness.

## Plan

### Today (1–2 hours)

1. Pick **1 SEV** from the OT SEV list — preferably one I remember well, with a known root cause.
2. Capture what the agent would see at T0:
   - initial alert text
   - SEV initial post
   - error signature
3. Run OT Master Agent against it manually.
4. Write down what it got right / wrong / missed. Plain text, no framework.

### This Week

5. Repeat for **5 diverse SEVs** — different root causes, not all SilverTorch-flavored. Diversity matters more than count.
6. *Then* decide: thin replay script, or stay manual?

### Don't Build Yet

- No eval framework
- No grading rubric DSL
- No CI integration
- No dashboard

Build only after 5 manual cases prove the agent is worth automating around.

## Grading Rubric (provisional)

For each replay, capture:

| Dimension | Question |
|-----------|----------|
| Trigger surfaced | Did the agent identify the right alert / error sig from T0 input? |
| Investigation depth | Did it pull the relevant logs / configs / code? |
| Partner team | Did it route to the correct of the 6 OT infra teams? |
| Actionable next step | Did it suggest a concrete debug move, not just summarize? |
| Time to draft | Wall-clock from input → draft answer? |

Refine after 5 cases.

## Open Items

- **SEV list source** — where exactly is the curated list? Task IDs / sheet / wiki?
- **T0 reproducibility** — for older SEVs, can we still pull the original alert payload, or only the SEV post?
- **Agent invocation surface** — replay against `/ask-agents`, or direct OT agent CLI?

## Why This Exists

Validates Goal 1 (OT Master Agent v1) on real ground truth before scaling to 6-team coordination. IC7 narrative needs evidence the agent moved triage behavior, not that 148 agents were registered.
