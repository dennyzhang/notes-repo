# Capacity Planning Cheatsheet

Quick reference for analyzing capacity, finding efficiency wins, drafting proposals, and framing capacity work for PSC impact.

## Utilization Ranges

| Resource | Healthy | Warning | Critical | Source |
|----------|---------|---------|----------|--------|
| **CPU** | 40-70% avg | > 80% | > 90% | ODS, host metrics |
| **Memory** | 50-80% | > 85% | > 95% | ODS, host metrics |
| **Storage** | 50-75% | > 80% | > 90% | Storage dashboards |
| **GPU** | > 70% util | < 50% (waste) | < 30% (waste) | GPU metrics |
| **Network** | < 60% link | > 75% | > 85% | Network dashboards |

---

## Analysis Template

```
## Capacity Analysis: [Service/Infra]

**Period:** [Date range] | **Scope:** [Resources]

### Utilization Summary
| Resource | Allocated | Used (avg) | Used (peak) | Util% | Status |
|----------|-----------|-----------|-------------|-------|--------|
| CPU | X cores | Y cores | Z cores | Y/X% | [ok/warn/crit] |
| Memory | X GB | Y GB | Z GB | Y/X% | [ok/warn/crit] |
| Storage | X TB | Y TB | — | Y/X% | [ok/warn/crit] |

### Trends
- [Resource]: [X%/month growth, stable, declining]
- Projected exhaustion: [Date if applicable]

### Efficiency Opportunities
| Opportunity | Estimated Savings | Effort | Priority |
|-------------|------------------|--------|----------|
| [Description] | [X cores / $Y / Z%] | [Low/Med/High] | [P0/P1/P2] |
```

---

## Efficiency Mining

| Category | What to Look For | Typical Savings |
|----------|-----------------|-----------------|
| **Right-sizing** | Over-provisioned instances, unused allocations | 10-30% compute |
| **Idle resources** | Unused dev instances, stale data, orphaned jobs | 5-15% storage/compute |
| **Scheduling** | Off-peak batch competing with peak traffic | 10-20% peak capacity |
| **Caching** | Repeated expensive computations | 20-50% for cached paths |
| **Code optimization** | Hot paths, N+1 queries | 10-40% per path |
| **Decommission** | Deprecated services still running | 100% of decommissioned |
| **Consolidation** | Multiple services doing similar work | 20-40% through sharing |
| **Compression** | Uncompressed data in storage/transit | 30-70% storage |

### Sizing an Efficiency Win

```
## Efficiency Opportunity: [Name]

### Current State
- Resource: [What's being used]
- Cost: [$X/month or Y cores or Z TB]
- Utilization: [Current %]

### Proposed Change
- Action: [What to do]
- Expected utilization: [Target %]

### Savings
- Gross savings: [Amount]
- Implementation cost: [Eng-hours, migration risk]
- Net savings: [Gross - Implementation]
- Payback period: [Time to ROI]
- Confidence: [High/Medium/Low]
```

---

## Capacity Proposal Template

```
## [Project Name]: Capacity Efficiency

### Problem
- Current utilization: [X%] for [resource]
- Cost: [$Y/month or Z% of allocation]
- Growth rate: [X%/month — exhaustion in Y months]
- Do nothing: [What happens]

### Solution
- Approach: [Technical approach]
- Expected savings: [Quantified]
- Timeline: [Schedule]

### Comparison
| Dimension | Do Nothing | With Project |
|-----------|------------|-------------|
| Cost in 6 months | [$X] | [$Y] |
| Capacity headroom | [X%] | [Y%] |
| Crunch risk | [High/Med/Low] | [Low] |
```

---

## Impact Framing

For PSC impact statements using capacity data, see `career/impact-quantifier.md`. Use the capacity metrics from the Analysis Template above as inputs.

**Capacity-specific examples:**

```
Right-sized 200 Tupperware tasks for ads serving,
reducing CPU allocation by 35% (1,200 cores freed, ~$180K/year),
enabling 2x traffic growth without new capacity asks.
Confidence: High, from 90-day ODS utilization data.
```

```
Decommissioned 3 deprecated pipelines,
recovering 50TB storage and 400 cores ($250K/year),
eliminating 12 false-positive oncall alerts per week.
Confidence: High, based on zero-traffic analysis over 6 months.
```

---

## See Also

`career/impact-metrics.md`, `career/anti-patterns.md`, `career/communication-templates.md`

_Last updated: 2026-05-12. Maintainer: dennyzhang._
