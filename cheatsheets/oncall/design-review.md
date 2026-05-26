# Design Review Cheatsheet

How to review RFCs, design docs, and architectural proposals as an ML infra TL. Different from code review — you're evaluating tradeoffs, not implementation.

## The Core Question

**"Will this design still work in 6 months when traffic doubles, the team changes, and requirements shift?"**

Code review asks "is this correct?" Design review asks "is this the right approach?"

## The 5-Minute Design Review Framework

### Step 1: Understand the Problem (1 min)

Before evaluating the solution, verify the problem is worth solving:
- What's the current pain? (metrics, incidents, user complaints)
- Who asked for this? (user pull vs. engineer push)
- What happens if we do nothing? (urgency test)

**If the problem statement is vague, that's your first comment.** Everything else is premature until the problem is sharp.

### Step 2: Evaluate the Approach (2 min)

| Question | What you're checking | Red flag |
|----------|---------------------|----------|
| **Why this approach over alternatives?** | Author considered options | No alternatives section = tunnel vision |
| **What's the migration path?** | Existing systems can transition | "Big bang migration" with no incremental path |
| **What happens when it fails?** | Failure modes are explicit | No failure analysis = optimistic design |
| **Who operates this?** | Operational burden is acknowledged | "It's self-healing" with no monitoring plan |
| **What's the rollback plan?** | Can undo if it goes wrong | No rollback = one-way door |

### Step 3: Check the Tradeoffs (2 min)

Every design makes tradeoffs. Good designs make them explicit. Bad designs hide them.

| Tradeoff axis | Ask |
|--------------|-----|
| **Complexity vs. correctness** | Is the added complexity justified by the problem's difficulty? |
| **Latency vs. throughput** | Does optimizing for one hurt the other? |
| **Consistency vs. availability** | What happens during partitions? |
| **Build vs. reuse** | Does an existing system solve 80% of this? |
| **Now vs. later** | Is this solving today's problem or tomorrow's? (YAGNI test) |

## What to Look For (Priority Order)

| Priority | Category | Questions |
|----------|----------|-----------|
| P0 | **Feasibility** | Can this actually be built with the stated resources and timeline? |
| P1 | **Failure modes** | What breaks? How do you detect it? How do you recover? |
| P2 | **Scalability** | 10x traffic, 10x data, 10x team size — what breaks first? |
| P3 | **Operational burden** | Who gets paged? What's the oncall load? What needs manual intervention? |
| P4 | **Dependencies** | What external systems does this rely on? What if they change? |
| P5 | **Security/privacy** | Data flows, access controls, PII handling |

## ML Infra-Specific Questions

| Scenario | Questions to ask |
|----------|-----------------|
| **New training pipeline** | What's the recovery path when training crashes mid-job? How are checkpoints managed? What's the staleness SLA? |
| **Model serving change** | What's the rollback time? How do you detect degraded model quality? What's the canary strategy? |
| **Data pipeline change** | What happens when upstream data is late? Missing? Schema-changed? How is data quality validated? |
| **Monitoring/alerting** | What's the false positive rate? Who owns the alert? What's the runbook? |
| **Cross-team integration** | Who owns the interface contract? How do you version it? What happens when the partner team changes their API? |

## Comment Patterns

**Good design review comments:**
- "What happens when [specific failure scenario]?" — forces the author to think about it
- "Have you considered [alternative] because [tradeoff]?" — opens dialogue, doesn't dictate
- "This reminds me of [similar system] which hit [problem] at scale" — experience-based warning
- "The migration path from current state to this design is unclear — can you add a phased rollout plan?" — specific ask

**Bad design review comments:**
- "This is too complex" (vague — which part? compared to what?)
- "I would do it differently" (ego, not feedback — state the concern, not your preference)
- "What about [edge case that will never happen]?" (theoretical, not practical)
- Rewriting the design in the comment (review, don't redesign)

## Design Review Checklist

Before approving a design doc:

- [ ] Problem statement is clear and quantified
- [ ] At least 2 alternatives were considered (with reasons for rejection)
- [ ] Failure modes are listed with detection and recovery plans
- [ ] Migration path from current state is incremental (not big bang)
- [ ] Rollback plan exists
- [ ] Operational burden is acknowledged (who gets paged, monitoring plan)
- [ ] Dependencies are listed with owners
- [ ] Timeline and milestones are realistic
- [ ] Success metrics are defined (how do you know this worked?)

## TL-Level Design Judgment (Source: Will Larson, Tanya Reilly)

Beyond correctness, a senior IC evaluates these dimensions:

| Dimension | Question | IC5 concern | IC6+ concern |
|-----------|----------|-------------|-------------|
| **Reversibility** | One-way door or two-way door? | Can I undo this? | Should we invest in making this reversible? |
| **Blast radius** | What's the worst case? | My service goes down | Multiple teams' services go down |
| **Maintenance cost** | Who keeps this alive in 2 years? | Can I maintain it? | Can the team maintain it after I leave? |
| **Opportunity cost** | What are we NOT doing to do this? | Is this the best use of my time? | Is this the best use of the team's quarter? |

### When to Block a Design

Block (request major revision) when:
- No failure mode analysis at all
- Single point of failure with no redundancy plan
- Migration plan is "big bang" with no incremental path
- Blast radius is unclear or unbounded
- The design solves a different problem than the one stated

Don't block for:
- Implementation details you'd do differently (style, not substance)
- Missing optimization (ship first, optimize later)
- Incomplete testing plan (important but rarely a design blocker)

## See Also

`diff/review.md` (code review), `oncall/sev.md` (failure mode thinking), `career/project-doc.md` (writing your own design docs)
