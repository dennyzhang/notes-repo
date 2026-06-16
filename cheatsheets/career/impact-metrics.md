# Impact Metrics Reference

Standard metrics for quantifying infrastructure impact at Meta.

## Primary Metrics

### normKW (Normalized Kilowatts)

Measures compute efficiency. 1 normKW ~ $1M/year in infrastructure cost.

| Calculation | Example |
|-------------|---------|
| `(GPU hours saved x GPU power) / 1000` | 100K GPU-hours x 400W = 40,000 kWh = 40 normKW |
| `(CPU cores freed x TDP) / 1000` | 10K cores x 10W = 100 kWh = 0.1 normKW |

**When to use:** Capacity savings, efficiency improvements, resource optimization.

### Engineering Hours Saved

Measures developer productivity impact.

| Calculation | Example |
|-------------|---------|
| `(time saved per occurrence) x (occurrences/year) x (engineers affected)` | 2 hours x 50 incidents x 20 engineers = 2,000 eng-hours |
| `(manual process time) - (automated process time)` | 4 hours manual to 10 min automated = 3.8 hours saved |

**Conversion:** 1 engineer-year ~ 2,000 hours. 2,000 eng-hours = 1 engineer-year.

### Dollar Value ($)

| Type | Calculation |
|------|-------------|
| **Infra cost** | normKW x $1M/year |
| **Eng cost** | eng-hours x $150/hour (fully loaded) |
| **SEV cost** | SEV-hours x hourly revenue impact |
| **Avoided vendor cost** | Contract value - implementation cost |

### SEV Reduction

| Metric | Calculation |
|--------|-------------|
| **SEVs prevented** | Historical rate - new rate (same conditions) |
| **MTTR reduction** | Old MTTR - new MTTR |
| **Blast radius reduction** | Old affected users - new affected users |

**SEV cost estimates:**
- SEV1: $500K-$2M per hour (revenue + eng time + reputation)
- SEV2: $50K-$200K per hour
- SEV3: $5K-$50K per hour

### SLO/SLA Improvement

| Metric | Calculation |
|--------|-------------|
| **Availability gain** | New SLO% - Old SLO% |
| **Error budget recovered** | Minutes of downtime prevented per month |
| **Latency improvement** | p50/p99 reduction in ms |

## Confidence Levels

Always state confidence level with metrics.

| Level | Criteria | Example |
|-------|----------|---------|
| **High** | Measured directly, A/B tested, or from production data | "Reduced latency 40% (measured in production)" |
| **Medium** | Extrapolated from samples or similar projects | "Estimated 2,000 eng-hours based on pilot with 3 teams" |
| **Low** | Rough estimate, back-of-envelope | "Potentially $1-2M savings (needs validation)" |

## Metric Selection Guide

| Impact Type | Primary Metric | Secondary Metric |
|-------------|----------------|------------------|
| Capacity/efficiency | normKW | $ |
| Developer productivity | Eng-hours | $ |
| Reliability | SEV reduction | $ (SEV cost) |
| Performance | SLO improvement | Eng-hours (debugging saved) |
| Cost optimization | $ | normKW |

## Common Pitfalls

| Pitfall | Problem | Fix |
|---------|---------|-----|
| **Double counting** | Claiming both normKW and $ for same savings | Pick one primary; note the other as "equivalent to" |
| **Inflated projections** | "If all 1000 teams adopt..." | Use actual adoption numbers or state assumptions |
| **Missing baseline** | "Improved performance" | Always state before/after: "from X to Y" |
| **Vanity metrics** | "Processed 1B requests" | Focus on outcome: "Reduced cost per request 30%" |
| **One-time vs recurring** | Mixing one-time savings with annual impact | Label clearly: "$500K one-time" vs "$500K/year" |

## Impact Statement Templates

### Elevator Pitch (1 sentence)
```
[Project] [action verb] [metric], [equivalent business impact].
```
Example: "GPU profiler reduced OOM debugging time 80%, saving 2,000 eng-hours/year ($300K)."

### Impact Summary Table
```
| Metric | Value | Confidence | Methodology |
|--------|-------|------------|-------------|
| Eng-hours saved | 2,000/year | High | Measured across 5 pilot teams |
| $ equivalent | $300K/year | High | 2,000 x $150/hour |
| SEVs prevented | 3/year | Medium | Based on historical OOM-caused SEVs |
```

### Leadership-Ready Statement
```
[One-line impact] + [business context] + [proof point]
```
Example: "Reduced training job failures 40%, directly supporting our H2 OKR to improve ML velocity. Validated across 50 teams representing 60% of training compute."

_Last updated: 2026-05-12. Maintainer: dennyzhang._
