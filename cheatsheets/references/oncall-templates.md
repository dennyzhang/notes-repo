# Oncall Templates

Extracted from `cheatsheet-oncall.md`. Load on demand when generating reports.

## Assessment Template

```
## Oncall Health: [Rotation Name]

**Period:** [Date range] | **Health:** [Healthy / Needs Attention / Unhealthy]

### Metrics
| Metric | Current | Target | Trend |
|--------|---------|--------|-------|
| Non-actioned critical | X% | < 5% | [up/down/flat] |
| Responsiveness | X% | > 90% | [up/down/flat] |
| Pages/shift | X | Benchmark | [up/down/flat] |
| False positive rate | X% | < 20% | [up/down/flat] |
| MTTD (avg) | Xh | Reduce | [up/down/flat] |
| MTTR (avg) | Xh | Reduce | [up/down/flat] |

### Top Pain Points
1. [Most frequent/impactful issue with data]
2. [Second]
3. [Third]

### Toil Patterns
- [Recurring alert -> root cause -> fix]
- [Manual process -> automation opportunity]

### Recommended Actions
1. [Quick win — highest impact/effort ratio]
2. [Medium-term improvement]
3. [Longer-term project]
```

## Improvement Plan Template

```
## Oncall Improvement: [Rotation]

**Goal:** [e.g., "Reduce non-actioned alerts from 15% to <5%"]
**Timeline:** [This half / Next quarter]
**Owner:** [Name]

### Phase 1: Quick Wins (Week 1-2)
- [ ] [Action]: [Expected impact] — [Owner]

### Phase 2: Medium-Term (Week 3-6)
- [ ] [Action]: [Expected impact] — [Owner]

### Phase 3: Projects (This half)
- [ ] [Action]: [Expected impact] — [Owner]

### Success Metrics
| Metric | Before | Target | Measurement |
|--------|--------|--------|-------------|
| [Metric] | [Current] | [Goal] | [How to measure] |
```

## Leadership Report Template

```
## Oncall Health: [Team/Rotation]
**Period:** [Date range]

### Health Score: [X/10]

### Key Metrics
| Metric | This Period | Last Period | Trend |
|--------|------------|-------------|-------|
| Non-actioned alerts | X% | Y% | [up/down/flat] |
| MTTD | Xh | Yh | [up/down/flat] |
| Pages/shift | X | Y | [up/down/flat] |

### Notable Incidents
- [SEV/incident]: [1-line summary + outcome]

### Improvements Completed
- [What was done] -> [Measured impact]

### Asks
- [Support needed from leadership]
```

## Shift Report Template

Standard report format for weekly oncall handoffs. Based on best practices from `oncall-shift-report`, `oncall-shift-handoff`, and `sev-report` skills.

```
# {ROTATION} Oncall Report — YYYY-MM-DD to YYYY-MM-DD

**Oncall**: Name | **Rotation**: rotation_name | **Shift**: Mon MM/DD — Sun MM/DD

**TL;DR**: 1-2 sentences. Lead with highest-impact event. Include alert count, SEV count, diffs produced.

---

## Quick Stats

| Metric | Value |
|--------|-------|
| SEVs handled | N (list IDs) |
| SEVs related | N (prior/adjacent SEVs that drove work) |
| Alerts fired | N (breakdown by severity) |
| Actionable alerts | N (excluding transient/auto-resolved) |
| Diffs produced | N (list IDs) |
| Tasks created | N |
| Bugs found | N |

---

## Needs Attention (for next oncall — unresolved, requires action)

1. **Item**: Context. Action needed.
2. ...

## Monitoring (mitigated but watch for recurrence)

1. **Item**: What to watch for. Escalation path.
2. ...

---

## SEVs

### S{number} — SEV{level} | {Status: Mitigated/Resolved/Open/Under Investigation}

- **Title**: {title}
- **Model**: {model_name} ({model_id})
- **Owner**: {owner team/person}
- **Duration**: {time from detection to mitigation}
- **Root Cause**: {1-2 sentence technical causal chain}
- **Detection**: {how detected — alert, GChat, customer report} ({timestamp})
- **Impact**: {user-facing impact, error rates, blast radius, duration}
- **Mitigation**: {what was done, with diff links if applicable}
- **Prevention**: {follow-up diffs/tasks to prevent recurrence}
- **Contributing Factors**: {systemic issues, process gaps}
- **Related SEVs**: S{number} ({relationship})
- **Status**: {current state}

(Repeat for each SEV. Group by: Owned SEVs → Carryover SEVs → Related SEVs)

---

## Alerts

### Actionable Alerts

| # | Time | Alert | Model | Severity | Root Cause | Resolution |
|---|------|-------|-------|----------|------------|------------|

### Batch/Transient Alerts (auto-resolved or non-actionable)

| # | Time | Alert | Model | Severity | Assessment |
|---|------|-------|-------|----------|------------|

---

## Bugs Found

### Bug N: {title}
- **File**: {repo: path}
- **Impact**: {what breaks}
- **Fix**: D{number} — {what it does}

---

## Proactive Improvements

| Diff | Repo | Description | Impact |
|------|------|-------------|--------|

---

## Tasks

| Task | Title | Priority | Status | Owner |
|------|-------|----------|--------|-------|

---

## Incident Timeline

| Time | Day | Event |
|------|-----|-------|
(Chronological cross-source view: alerts → investigation → SEVs → fixes → mitigation)

---

## Handoff Items

| # | Item | Context | Action for Next Oncall |
|---|------|---------|----------------------|
```

### Report Data Gathering (run in parallel before writing)

1. SEV details — `meta search.doc search -q "S<number>" --doc-type=SEV -o json` or `knowledge_load`
2. Related diffs — diffs linked to the SEV or created during the incident window
3. Related tasks — tasks created from the SEV or linked to follow-ups
4. Downstream SEVs — other SEVs caused by or related to this one
5. Workplace posts — oncall summaries, incident discussion threads
6. SEV chat thread — if accessible, this is the **highest-truth source** (prioritize over summaries)

### Report Writing Principles

- **Blameless by default** — no individual names in reports; use roles ("the oncall", "the author") consistent with Meta's postmortem culture
- **Non-expert readable** — someone outside your team should understand the report without domain knowledge
- **SEV chat > summaries** — the actual incident chat is the most accurate source for timeline and decisions; summaries can omit critical context
- **Section-by-section verification** — verify each section (timeline, root cause, impact) against source data before moving on; don't let Claude fabricate details

### Section Guidelines

- **Needs Attention** goes first — next oncall reads this before anything else
- **SEVs** get full detail blocks, not table rows — root cause, impact, and prevention matter
- **Alerts** split into actionable vs. transient — don't bury real issues in noise
- **Incident Timeline** is chronological across all sources (alerts, GChat, SEVs, diffs)
- **Handoff Items** are specific: what, why, and exact next action
- **Quick Stats** at top for leadership visibility
