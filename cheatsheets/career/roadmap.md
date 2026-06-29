# Team Roadmap Cheatsheet

Quick reference for half-on-half roadmap planning: project portfolio, reactive/proactive balance, staffing, four-axis coverage, and stakeholder communication.

## PE Roadmap Dimensions

| Dimension | What to Plan | Example |
|-----------|-------------|---------|
| **Reliability** | SLO improvements, SEV follow-ups, DR testing, monitoring | "Achieve 99.95% SLO for service X" |
| **Capacity & Efficiency** | Right-sizing, decommissions, capacity unblocking | "Reduce compute cost by 20%" |
| **Developer Velocity** | Tooling, automation, workflow improvements | "Deploy time: 2hr to 30min" |
| **Oncall Health** | Alert tuning, runbook updates, automation | "Non-actioned alerts from 15% to <5%" |
| **Security & Compliance** | DSS compliance, access controls, audit readiness | "DSS4 remediation for all tier-0" |
| **Team Growth** | Mentoring, onboarding, knowledge sharing | "2 new hires to independent oncall in 8 weeks" |

## Reactive vs Proactive Balance

| Team Maturity | Reactive | Proactive |
|---------------|----------|-----------|
| **New/unstable** | 40-50% | 50-60% |
| **Maturing** | 25-35% | 65-75% |
| **Mature** | 15-25% | 75-85% |

"You can't be strategic if you're not present where the battles are being won and lost daily."

## Roadmap Template

```
## [Team] Roadmap: [Half]

**TL:** [Name] | **EM:** [Name] | **Team Size:** [N]
**Reactive:** [X%] | **Proactive:** [Y%]

### Strategic Themes
1. [Theme 1]: [1-line description]
2. [Theme 2]
3. [Theme 3]

### Tier 1: Must-Do (Critical Path)
| Project | Owner | Half Target | Axis | Dependencies |
|---------|-------|-------------|------|-------------|
| [Project] | [Name/Level] | [Measurable] | Impact | [Deps] |

### Tier 2: Should-Do (High Value)
| Project | Owner | Half Target | Axis | Dependencies |
|---------|-------|-------------|------|-------------|

### Tier 3: Nice-to-Have (If Capacity)
| Project | Owner | Half Target | Axis | Dependencies |
|---------|-------|-------------|------|-------------|

### Ongoing/Reactive
| Work | Allocation | Owner(s) | Success Metric |
|------|-----------|----------|---------------|
| Oncall | [X%] | Rotation | Non-actioned alerts < 5% |
| SEV follow-ups | [X%] | Various | P0 closed within 30 days |

### Four-Axis Coverage
| Axis | Projects | Signal |
|------|----------|--------|
| Project Impact | [List] | Strong/Moderate/Weak |
| Engineering Excellence | [List] | " |
| Direction | [List] | " |
| People | [List] | " |

### Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|

### Dependencies & Asks
- [What we need, from whom, by when]
```

---

## Mid-Half Review Template

```
## Roadmap Review: [Team] — [Date]

### Overall: [On Track / At Risk / Off Track]

| Project | Plan | Actual | Status | Notes |
|---------|------|--------|--------|-------|
| [Project] | [Target] | [Current] | [ok/risk/off] | [Note] |

### Decisions Needed
1. [Decision]: [Options and recommendation]

### Adjustments
- [What changed and why]
```

---

## Staffing Principles

1. **Match level to scope** — IC3s on bounded tasks, IC5s on half-long, IC6s on cross-team
2. **Spread scope** — "Don't hoard scope. Taking on all the fun work is not what a TL does."
3. **Growth opportunities** — Assign stretch that demonstrates next-level performance
4. **Backstop, don't catch** — Let people struggle productively
5. **Pair strategically** — New hires with experienced engineers

### Staffing Matrix

```
| Engineer | Level | Load | Strengths | Growth Area | Projects |
|----------|-------|------|-----------|-------------|----------|
| [Name] | IC3 | 80% | [Areas] | [Gap] | [Projects] |
| [Name] | IC5 | 70% | [Areas] | [Gap] | [Stretch project] |
```

---

## Leadership Update Template

```
## [Team] Roadmap Update — [Period]

### Headline
[1-2 sentences: where we are, what changed]

### Progress
| Goal | Target | Current | Status |
|------|--------|---------|--------|

### Key Wins
- [Win]: [1-line impact with metrics]

### Risks & Asks
- [Risk/Ask]: [What's needed]

### Next Period
1. [Priority 1]
2. [Priority 2]
```

---

## See Also

**area monitor gdoc** (priority discovery before planning), `cheatsheet-oncall.md` (oncall-to-project pipeline), `10x-engineer:one-pager` skill (project proposals), `references/level-expectations.md`, `references/four-axes.md`, `references/impact-metrics.md`, `references/communication-templates.md`
