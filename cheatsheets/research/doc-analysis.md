# Document Analysis Cheatsheet

Quick reference for speed-reading infrastructure documents (RFCs, post-mortems, one-pagers, tech specs) as a tech lead.

## Document Type Detection

| Type | Detection Signals | Analysis Focus |
|------|-------------------|----------------|
| **RFC** | "Proposal:", "Alternatives Considered", "Migration Plan" | Architecture decisions, alternatives, rollback plan |
| **Post-mortem** | "Root Cause", "Timeline", "Action Items", SEV ID | Root cause accuracy, MTTD/MTTR, action item quality |
| **One-pager** | "Problem", "Solution", "Impact", short format | Problem clarity, ROI, resource justification |
| **DRD** | "Requirements", "Acceptance Criteria" | Completeness, measurability, dependencies |
| **Tech Spec** | "API Design", "Data Model", "Architecture" | API design, scalability, operational readiness |

## Speed Read Output (30 seconds)

```
Document Type: [Type]
Read time: [X min]
Your role: [Review/Approve/Escalate/Decide]

1. [What this is — problem + solution]
2. [Impact — quantified]
3. [Your decision point]

Critical Questions:
1. [Highest-risk unknown author must answer]
2. [Second question]

TL;DR for Leadership:
[One sentence with a number]
```

## Action Item Prioritization

| Priority | Meaning | Examples |
|----------|---------|---------|
| **Critical Path** | Unblocks decisions, de-risks investment | "Run shadow mode — de-risks $2M investment" |
| **High ROI** | Low effort, high impact | "Get storage team approval — unblocks decision" |
| **Standard** | Can delegate or defer | "Write migration runbook" |
| **Don't Bother** | Low-ROI, over-engineering | "Benchmark against 3 other frameworks" |

## Analysis Framework

### 1. Critical Path & Bottlenecks
- IO-bound, compute-bound, or synchronization?
- What breaks at 10x or 100x scale?

### 2. Infrastructure Impact
- Networking, power/thermal, scheduling, storage

### 3. The "Meta" Tax
- Integration with internal tooling
- Migration from legacy systems
- Impact on oncall

### 4. Blind Spots
- Edge cases in fault tolerance
- Missing telemetry
- Optimistic assumptions
- Testing gaps

_Last updated: 2026-06-01. Maintainer: dennyzhang._
