# PE Reliability Metrics Reference

Standard reliability metrics framework for Production Engineers at Meta.

## PE Reliability Target Framework

| Category | Metric | Target | Source |
|----------|--------|--------|--------|
| **SLI Quality** | %SEV <> SLI Linkage | 50%+ coverage | SLICK, SEV Manager |
| **Oncall Health** | %Non-Actioned Critical Alerts | < 5% | IROC dashboard |
| **Change Safety** | %CBSS Enablement | 100% | CBSS dashboard |
| **SLO Performance** | SLO Attainment | > 90% | SLICK |
| **Oncall Health** | Oncall Responsiveness | > 90% | IROC |
| **Incident Mgmt** | %SEVs 0-2 Reviewed Within 30 Days | Track | SEV Manager |
| **Incident Mgmt** | MTTD / MTTR | Monitor and reduce | SEV timeline |

## SLI Detection Impact Data

Measured across Meta's Tier 0 oncalls:

| Scenario | Avg MTTD | Factor |
|----------|----------|--------|
| No SLI detectors | 1.32 hours | Baseline |
| At least one SLI detector | 0.53 hours | **2.5x faster** |

Error budget consumption is **2.4x higher** for services without SLI detectors.

## PE Productivity Expectations

| Metric | Target | Notes |
|--------|--------|-------|
| **Diffs landed** | 1+/week minimum, 3+/week target | "Production engineers should be no different from SWEs" |
| **Interviews** | ~2/week at IC5+ | ~25 hours/half |
| **Org contributions** | ~25 hours/half at IC5+ | Interviewing, mentoring, DPE, bootcamp |

## SEV Cost Estimates

| Severity | Cost Per Hour | Typical Duration | Typical Total Cost |
|----------|--------------|-----------------|-------------------|
| SEV1 | $500K-$2M | 2-6 hours | $1M-$12M |
| SEV2 | $50K-$200K | 2-12 hours | $100K-$2.4M |
| SEV3 | $5K-$50K | 4-48 hours | $20K-$200K |

## Capacity & Efficiency Metrics

| Metric | Definition | Unit |
|--------|-----------|------|
| **normKW** | Normalized kilowatts — 1 normKW ~ $1M/year | normKW |
| **CPU utilization** | Healthy: 40-70% avg | Percentage |
| **GPU utilization** | Target: >70% | Percentage |
| **Memory utilization** | Healthy: 50-80% | Percentage |
| **Storage utilization** | Healthy: 50-75% | Percentage |

## Oncall Health Metrics

| Metric | Definition | Healthy | Warning |
|--------|-----------|---------|---------|
| **Non-actioned alerts** | Alerts acknowledged but no action | < 5% | > 10% |
| **False positive rate** | Alerts with no real issue | < 20% | > 30% |
| **Pages per shift** | Total pages per oncall shift | Decreasing trend | Increasing |
| **Oncall bad days** | Shifts with excessive pages/SEVs | Rare | Frequent |
| **Escalation rate** | % requiring escalation beyond oncall | Decreasing | Increasing |
| **Task backlog** | Oncall-generated tasks unresolved | Decreasing | Growing |

## Impact Framing Templates

### Reliability Work (Project Impact)
```
[Action] [specific reliability improvement] for [service],
[quantified outcome] ([metric with confidence level]).
```

### Oncall Improvement (Engineering Excellence)
```
[Action] [specific oncall improvement],
reducing [oncall metric] from [before] to [after],
freeing [X eng-hours/quarter] for project work.
```

### SLO Definition (Direction)
```
Drove SLI/SLO definition for [N] services,
achieving [X%] SEV-SLI linkage (from [Y%] baseline),
reducing MTTD by [Z]x for covered services.
```

### Capacity Work (Project Impact + Direction)
```
[Action] [efficiency improvement] for [service/infra],
reducing [resource] cost by [X%] ($Y/year),
[business outcome enabled by freed capacity].
```
