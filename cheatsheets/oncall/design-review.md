# Design Review Cheatsheet

How to review RFCs, design docs, and architectural proposals as an ML infra TL. Different from code review — you're evaluating tradeoffs, not implementation.

## ML Infra-Specific Questions

| Scenario | Questions to ask |
|----------|-----------------|
| **New training pipeline** | What's the recovery path when training crashes mid-job? How are checkpoints managed? What's the staleness SLA? |
| **Model serving change** | What's the rollback time? How do you detect degraded model quality? What's the canary strategy? |
| **Data pipeline change** | What happens when upstream data is late? Missing? Schema-changed? How is data quality validated? |
| **Monitoring/alerting** | What's the false positive rate? Who owns the alert? What's the runbook? |
| **Cross-team integration** | Who owns the interface contract? How do you version it? What happens when the partner team changes their API? |

## TL-Level Design Judgment (Source: Will Larson, Tanya Reilly)

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

_Last updated: 2026-06-01. Maintainer: dennyzhang._
