# Communication Templates

Reusable patterns for common engineering communications.

## Leadership Update

```
[LEDE: 1 sentence on key result/blocker/decision needed]

[CONTEXT: 1 sentence on what this project is, if non-obvious]

[DETAILS: 2-3 bullets with metrics/progress]
- Metric/progress point 1
- Metric/progress point 2
- Blocker/risk (if any)

**Ask:** [Specific action with deadline]
```

Key rules: Lede first. No jargon — translate to business impact. Numbers, not adjectives. Explicit ask with deadline.

## Weekly Status Update

```
## Week of [Date]

**TL;DR:** [1 sentence summary of the most important thing]

### Shipped
- [Outcome 1 with metric]

### In Progress
- [Project]: [Status] | ETA: [Date]

### Blockers/Risks
- [Blocker]: [Impact if not resolved] | Need: [Specific help]

### Next Week
- [Top priority]
```

## Project Pitch / One-Pager

```
## [Project Name]

### Problem
[1-2 sentences: What's broken and why it matters]

### Solution
[1-2 sentences: What you're proposing]

### Impact
| Metric | Expected Value | Confidence |
|--------|----------------|------------|
| [Metric 1] | [Value] | High/Medium/Low |

### Alternatives Considered
1. [Alternative 1]: [Why not chosen]

### Timeline
| Milestone | Date |
|-----------|------|

### Ask
[What you need: headcount, approval, resources]
```

## Cross-Team Request

```
[LEDE: What you need from them, by when]

[WHY: 1 sentence on why you need this]

[SCOPE: Quantify the ask — hours, people, timeline]

[THEIR BENEFIT: What's in it for them, or fallback plan]

**Ask:** [Specific DRI + action]
```

Key rules: Lead with what you need. Quantify the scope (hours, not "some help"). Explain what's in it for them. Name a specific person to respond.

## SEV Communication

**Initial post:**
```
**[SEV Level]: [One-line description]**

**Impact:** [Who/what is affected, scope]
**Status:** Investigating / Mitigating / Resolved
**DRI:** @[name]

**Current understanding:**
- [What we know]
- [What we're doing]

**Next update:** [Time]
```

**Update:**
```
**Update [Time]:** [SEV-123]

**Status:** [Investigating / Mitigating / Resolved]
**Change:** [What changed since last update]

**Current actions:**
- [Action 1]: [Owner]

**Next update:** [Time] or when status changes
```

**Resolution:**
```
Resolved: [SEV-123] [One-line description]

**Duration:** [Start] - [End] ([X hours])
**Impact:** [Final impact summary]
**Root cause:** [1 sentence]
**Fix:** [What was done]

**Follow-ups:**
- [ ] [Action item]: [Owner] - [Date]

Post-mortem: [Link when available]
```

## Escalation

```
**Escalating:** [One-line issue description]

**Why escalating:** [What's blocked, why you can't resolve at your level]

**Impact if not resolved:** [Consequences + timeline]

**Options:**
1. [Option 1]: [Trade-offs]
2. [Option 2]: [Trade-offs]

**My recommendation:** [Which option and why]

**Ask:** [Decision needed by when]
```

## Peer Chat

Keep it conversational — tables and headers feel over-engineered in chat.

```
[Acknowledge their point briefly]

[Your key insight — 1-2 sentences]
- [Supporting point 1]
- [Supporting point 2]

[Proposal or next step]
```

Avoid: Tables for simple comparisons. Headers/sections. "I wanted to share..." Formal closings.

## Message Length Guide

| Audience | Target | Max |
|----------|--------|-----|
| VP/Director | 3-5 sentences | 150 words |
| Manager | 5-8 sentences | 250 words |
| Peer engineers | 8-15 sentences | 400 words |
| Peer chat reply | 3-8 sentences | 100 words |

## What to Cut

| Cut This | Replace With |
|----------|--------------|
| "I wanted to update you on..." | Just start with the update |
| "As discussed in our last meeting..." | Reference only if essential |
| "I think we should..." | "I recommend..." or "We should..." |
| "Let me know if you have questions" | Specific ask instead |
| "Just wanted to reach out..." | Delete entirely |
