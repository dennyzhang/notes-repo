# Impact Quantifier Cheatsheet

## Conversion Anchors (make abstract numbers concrete)

| Raw metric | Anchor equivalent | Use when |
|-----------|-------------------|----------|
| 2,000 eng-hours/year | ~1 FTE freed | Audience is EM/director |
| 100 normKW saved | ~$150K/year | Capacity reviews |
| 1 SEV1 prevented/quarter | ~$500K-$2M avoided | Reliability framing |
| 10% MTTR reduction | ~X hours faster x N incidents/year | Oncall improvement |
| 1 diff/week increase per engineer | ~50 diffs/year x team size | Developer velocity |

Always scope the denominator: "across 50 training pipelines" not just "reduced failures 40%."

## The "So What" Chain (Source: Stack Overflow Engineering Blog)

After every metric, ask "so what?" and chain up to business impact:

```
Reduced OOM rate 60%
  -> So what? 40 fewer failed training jobs/week
  -> So what? 200 GPU-hours/week recovered
  -> So what? Equivalent to $150K/year compute savings
  -> So what? Directly supports H2 efficiency OKR
```

Stop at the level your audience cares about. ICs care about the first level. Directors care about the last.

## Vague -> Concrete Rewrite Examples

| Vague | Concrete |
|-------|----------|
| "Improved reliability" | "Reduced SEV2 incidents from 4/month to 1/month (75% reduction, [High] — measured in SEV tracker)" |
| "Saved engineering time" | "Automated oncall triage saves **15 min/alert x 30 alerts/week = 7.5 eng-hours/week** ($60K/year, [Medium])" |
| "Built monitoring" | "12 SLI dashboards covering 3 oncall areas. Detected 2 incidents before user impact (est. 4h MTTD reduction, [Medium])" |
| "Worked on training pipeline" | "Reduced training staleness SLA violations from 8/week to 0 for 6 retrieval models serving 500M+ users" |
