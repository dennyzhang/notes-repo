# Impact Quantifier Cheatsheet

Quick reference for turning vague impact claims into concrete, leadership-ready statements with numbers and confidence levels.

## Output Formats

### Elevator Pitch (1 sentence, <50 words)

```
[Project] [action verb] [impact area], delivering [quantitative impact] and [key benefit].
```

Example: "GPU profiler reduces OOM debugging time 80%, saving 2,000 eng-hours/year ($300K) and accelerating ML iteration velocity."

### Impact Summary Table

```
| Metric | Value | Confidence |
|--------|-------|------------|
| [Primary metric] | [Value] | High/Medium/Low |
| [Secondary metric] | [Value] | [Confidence] |
| $ equivalent | [Value] | [Confidence] |
```

### Leadership-Ready Statement

```
[One-line impact] + [business context] + [proof point]
```

Example: "Reduced training job failures 40%, directly supporting our H2 OKR to improve ML velocity. Validated across 50 teams representing 60% of training compute."

## Process

1. **Identify impact area:** SEV prevention, capacity savings, developer efficiency, reliability
2. **Quantify with baseline:** Always state before/after
3. **Set confidence:** High (measured), Medium (extrapolated), Low (estimated)
4. **Connect to business:** Link to Meta priorities
5. **Check anti-patterns:** Run against `references/anti-patterns.md`

## Impact Areas

| Area | Primary Metric | Secondary Metric |
|------|---------------|-----------------|
| **SEV Prevention** | SEVs prevented, MTTR reduction | $ loss avoided |
| **Capacity Savings** | normKW, cores freed | $/year |
| **Developer Efficiency** | Eng-hours saved | $ equivalent |
| **Reliability** | SLO improvement, error rate | Eng-hours (debugging saved) |

## Confidence Levels

| Level | Criteria | Example |
|-------|----------|---------|
| **High** | Measured directly, A/B tested, production data | "Reduced latency 40% (measured in prod)" |
| **Medium** | Extrapolated from pilot or similar project | "Est. 2,000 eng-hours based on 3-team pilot" |
| **Low** | Rough estimate, needs validation | "Potentially $1-2M savings (needs validation)" |

## Conversion Anchors (make abstract numbers concrete)

| Raw metric | Anchor equivalent | Use when |
|-----------|-------------------|----------|
| 2,000 eng-hours/year | ~1 FTE freed | Audience is EM/director |
| 100 normKW saved | ~$150K/year | Capacity reviews |
| 1 SEV1 prevented/quarter | ~$500K-$2M avoided | Reliability framing |
| 10% MTTR reduction | ~X hours faster × N incidents/year | Oncall improvement |
| 1 diff/week increase per engineer | ~50 diffs/year × team size | Developer velocity |

Always scope the denominator: "across 50 training pipelines" not just "reduced failures 40%."

## The "So What" Chain (Source: Stack Overflow Engineering Blog)

After every metric, ask "so what?" and chain up to business impact:

```
Reduced OOM rate 60%
  → So what? 40 fewer failed training jobs/week
  → So what? 200 GPU-hours/week recovered
  → So what? Equivalent to $150K/year compute savings
  → So what? Directly supports H2 efficiency OKR
```

Stop at the level your audience cares about. ICs care about the first level. Directors care about the last.

## Vague → Concrete Rewrite Examples

| Vague | Concrete |
|-------|----------|
| "Improved reliability" | "Reduced SEV2 incidents from 4/month to 1/month (75% reduction, [High] — measured in SEV tracker)" |
| "Saved engineering time" | "Automated oncall triage saves **15 min/alert × 30 alerts/week = 7.5 eng-hours/week** ($60K/year, [Medium])" |
| "Built monitoring" | "12 SLI dashboards covering 3 oncall areas. Detected 2 incidents before user impact (est. 4h MTTD reduction, [Medium])" |
| "Worked on training pipeline" | "Reduced training staleness SLA violations from 8/week to 0 for 6 retrieval models serving 500M+ users" |

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Number without baseline | Always state before/after: "from X to Y" |
| Untagged confidence | Tag every number [High/Medium/Low] — readers assume Low if untagged |
| Effort as impact | "Spent 3 months" is effort. State the outcome. |
| Orphaned metric | "Saved 2,000 eng-hours" — anchor it: "equivalent to 1 FTE for a year" |
| Missing scope | "Reduced failures 40%" — across what? Name the scope. |
| Credit without contribution | "Team achieved 99.99%" — state YOUR specific contribution |

## See Also

`career/psc.md` (PSC writing), `oncall/sev.md` (SEV impact framing), `references/impact-metrics.md`, `references/anti-patterns.md`
