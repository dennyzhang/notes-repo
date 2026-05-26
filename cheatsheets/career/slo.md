# SLO Management Cheatsheet

Quick reference for the full SLI/SLO lifecycle: define SLIs, set SLO targets, calculate error budgets, run reviews, and assess SEV-SLI linkage.

## SLI Type Selection

| SLI Type | Formula | Best For | Example |
|----------|---------|----------|---------|
| **Availability** | 1 - (failed / total requests) | Request-serving services | API: 99.95% success rate |
| **Latency** | % requests < threshold | User-facing services | P99 < 100ms for search |
| **Durability** | 1 - (bytes lost / bytes stored) | Storage services | 99.999999% data durability |
| **Correctness** | 1 - (incorrect / total) | Data pipelines, ML inference | 99.9% correct predictions |
| **Coverage** | records processed / records received | Batch processing | 99.5% of incoming events |
| **Freshness** | % data accesses with fresh data | Caching, replication | < 5 min staleness for 99% |

## SLI Design Principles

1. **Measure from the customer's perspective** — success ratio SLIs (good events / total events)
2. **3-5 SLIs per service** — enough to cover critical dimensions, not so many they're ignored
3. **1-week+ measurement windows** — short windows create noise
4. **SLO = healthy tension** — set through customer negotiation, then defend
5. **Start conservative** — set SLOs at current baseline, then tighten as you improve

## SLI/SLO Specification Template

```
## SLI/SLO Specification: [Service Name]

**Owner:** [Team] | **Tier:** [0/1/2] | **SLICK Dashboard:** [link]

### SLI Definitions
| # | SLI Name | Type | Good Event | Total Event | Data Source |
|---|----------|------|------------|-------------|-------------|
| 1 | [Name] | Availability | Status < 500 | All requests | ODS counter |
| 2 | [Name] | Latency | Latency < Xms | All requests | Scuba log |
| 3 | [Name] | Correctness | Correct outcomes | All outcomes | Pipeline metrics |

### SLO Targets
| SLI | SLO Target | Window | Error Budget | Budget = |
|-----|-----------|--------|--------------|---------|
| [SLI 1] | 99.95% | 7 days | 0.05% | ~302 errors per 604K requests |
| [SLI 2] | 99.0% | 7 days | 1.0% | ~36 min of violation per week |

### Alerting Configuration
| SLI | Burn Rate | Window | Severity | Action |
|-----|-----------|--------|----------|--------|
| [SLI 1] | 14.4x | 1h | Critical | Page oncall |
| [SLI 1] | 6x | 6h | Warning | Oncall reviews next shift |
| [SLI 1] | 1x | 3d | Info | Track in weekly review |
```

---

## Error Budget

### Calculation

```
Error Budget = 100% - SLO Target

Example: SLO = 99.95% over 7 days
- Budget = 0.05%
- 10M requests/week: 5,000 allowed failures
- Time: 7 x 24 x 60 x 0.0005 = 5.04 min downtime
```

### Budget Interpretation

| Budget State | Meaning | Action |
|-------------|---------|--------|
| **> 50% remaining** | Healthy | Ship features, experiment |
| **25-50% remaining** | Caution | Review deploys, increase canary duration |
| **< 25% remaining** | At risk | Freeze non-critical changes, fix reliability |
| **Exhausted** | SLO violated | Stop feature work, fix root causes, postmortem |

### Multi-Window Burn Rate Alerts

| Scenario | Burn Rate | Window | Exhaustion | Response |
|----------|-----------|--------|------------|----------|
| **Acute** | 14.4x | 1 hour | ~1 hour | Immediate page, SEV triage |
| **Elevated** | 6x | 6 hours | ~7 hours | Oncall investigates this shift |
| **Chronic** | 1x | 3 days | ~7 days | Tracked in weekly review |

---

## SLO Period Review

### When to Run

- After any SLO violation period
- Monthly for Tier 0/1 services
- Quarterly for Tier 2 services
- Before half planning (input to roadmap)

### Review Template

```
## SLO Period Review: [Service Name]

**Period:** [Date range] | **Reviewer:** [Name]

### SLO Attainment
| SLI | Target | Actual | Status | Budget Remaining |
|-----|--------|--------|--------|-----------------|
| [SLI 1] | 99.95% | 99.92% | Violated | -0.03% (overspent) |
| [SLI 2] | 99.0% | 99.5% | Met | 50% remaining |

### Violation Analysis
**SLI 1 violation (99.92% vs 99.95%):**
- **Root cause:** [Description]
- **Correlated incidents:** [SEV-IDs]
- **Error budget consumed:** [X% of weekly budget in Y hours]

### Action Items
| Priority | Action | Owner | Deadline | Expected Impact |
|----------|--------|-------|----------|-----------------|
| P0 | [Action] | [Name] | [Date] | Prevents X% budget burn |

### Recommendation
[Keep current SLO / Tighten / Relax — with rationale]
```

---

## SEV-SLI Coverage Assessment

PE target: **50%+ of SEVs should have corresponding SLI violations**.

### Coverage Template

```
## SLI Coverage: [Team/Org]

**Period:** [Date range]

| SEV ID | Severity | SLI Detected? | Time to Alert | Gap |
|--------|----------|---------------|---------------|-----|
| [SEV-1] | SEV1 | Yes | 5 min before user reports | None |
| [SEV-2] | SEV2 | No | N/A | Missing SLI for [component] |
| [SEV-3] | SEV2 | Partial | 30 min after impact | Threshold too loose |

**Coverage Score:** [X]% ([Y] of [Z] SEVs detected)
**Target:** 50%+ | **Gap:** [Z-Y] SEVs uncovered

### SLI Detection Impact
- With SLI detectors: avg MTTD = 0.53 hours (2.5x faster)
- Without: avg MTTD = 1.32 hours
- Error budget consumption 2.4x higher without detectors

### Gaps
| Gap | Service | Recommended SLI | Priority |
|-----|---------|-----------------|----------|
| Missing coverage | [Service] | [Type + definition] | P0 |
| Loose threshold | [Service] | Tighten to [X] | P1 |
```

---

## See Also

`references/impact-metrics.md`, `references/pe-reliability-metrics.md`, `references/communication-templates.md`
