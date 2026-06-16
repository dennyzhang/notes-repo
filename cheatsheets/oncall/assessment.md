# Oncall Health Cheatsheet

<!-- Last updated: 2026-06-11 -->

Quick reference for assessing oncall quality, identifying toil patterns, planning improvements, and converting oncall pain into funded projects.

## Key Metrics

| Metric | PE Target | Where to Find |
|--------|-----------|---------------|
| **Non-actioned critical alerts** | < 5% | IROC dashboard |
| **Oncall responsiveness** | > 90% | IROC metrics |
| **MTTD** | Track and reduce | SEV timeline analysis |
| **MTTR** | Track and reduce | SEV timeline analysis |
| **False positive rate** | < 20% | Alert audit |
| **Pages per shift** | Decreasing trend | IROC, PagerDuty |
| **Oncall bad days** | Minimize | Oncall survey, IROC |
| **Escalation rate** | Track | IROC |
| **Task backlog** | Decreasing | GSD task queries |

---

## Templates

Assessment, Improvement Plan, Leadership Report, and Shift Report templates are in `oncall/oncall-templates.md`. Load on demand.

---

## Toil Classification

| Category | Examples | Fix Strategy |
|----------|----------|-------------|
| **Alert noise** | False positives, stale alerts, wrong thresholds | Tune thresholds, dedup, delete stale |
| **Missing automation** | Manual remediation for known issues | FBAR auto-remediation, scripts |
| **Knowledge gaps** | Escalations for known issues, long MTTR | Runbooks, diagnostic tooling |
| **Missing observability** | Blind spots, can't diagnose without author | Metrics, logging, dashboards, SLI detectors |
| **Architectural debt** | Single points of failure, cascading failures | Project proposal for reliability fix |
| **Process gaps** | Unclear escalation, missing handoffs | Document procedures, update IROC config |

---

## Oncall-to-Project Pipeline

The best PE TLs convert recurring oncall patterns into funded projects. This is how you demonstrate Direction.

### Pattern Mining

```
Review last [N] weeks:
- What alerts fire most frequently?
- What takes longest to resolve?
- What requires the most specialized knowledge?
- What keeps coming back after being "fixed"?
- What caused the most oncall bad days?
```

### Impact Quantification

Quantify using `career/impact-quantifier.md`. Oncall-specific factors to highlight:

| Factor | Why It Matters for Oncall |
|--------|--------------------------|
| **SEV risk** | Likelihood of pattern escalating to SEV |
| **Team health cost** | Impact on oncall sentiment and retention |
| **Opportunity cost** | Eng-hours on toil vs. project work |

### Converting to a Project Proposal

Route to the `10x-engineer:one-pager` skill with pre-filled context:
```
Problem: [Pattern with data]
Current cost: [Eng-hours/quarter, SEV risk, revenue impact]
Proposed solution: [High-level approach]
Expected outcome: [Metric targets]
```

---

## Oncall Report Skills (claude-templates)

Skills in `fbcode/claude-templates/components/skills/`. Pick based on what you need:

### Quick Decision Guide

| I need to... | Use this skill | Automation |
|-------------|---------------|------------|
| Generate a shift handoff summary | `oncall-summary-generator` | Fully auto, cron-ready |
| Create a comprehensive shift report | `oncall-shift-report` | Fully auto, 18 data sources |
| Post a summary to Workplace | `oncall-summary-post` | Fully auto, Google Doc draft |
| Check OMH feed items via CLI | `omh-oncall-feed` | Interactive |
| Analyze oncall health over time | `oncall-health-report` | Mostly auto |
| Find toil patterns from past summaries | `oncall-health-analyzer` | Fully auto |
| Multi-week trend analysis | `oncall-trend-analyzer` | Fully auto, 4-week default |
| Simple UI-guided summary | `oncall-summary` | Semi-auto (manual input) |

### Skill Details

**`oncall-summary-generator`** — Best for weekly handoffs
- Fetches tasks via GraphQL, classifies alerts, detects noise, correlates SEVs
- Args: `<rotation> [--prev] [--no-review] [--start DATE] [--end DATE] [--message]`
- Output: Markdown (Pastry, GChat, Workplace)
- Cron: `1 13 * * 1 claude -p '/oncall-summary-generator <ROTATION> --prev --no-review --message'`

**`oncall-shift-report`** — Best for comprehensive reports
- Pulls from 18 data sources (SEVs, alerts, tasks, Workplace posts, SLO violations)
- Two-part output: operational handoff + team summary
- Output: Google Doc, Workplace post, HTML, Paste
- Depends on: `data-collector`, `md-export` skills

**`oncall-health-report`** — Best for oncall quality metrics
- SEV data, alert health, ack rates, outside-hours metrics
- Produces overall health score (FM Execution Quality v1)
- Output: Google Doc or terminal
- Includes Presto SQL and GraphQL for oncall resolution

**`oncall-trend-analyzer`** — Best for identifying recurring issues
- Default 4-week window, deterministic Python + LLM for judgment
- Volume trends, recurring issues, load score sparklines
- Queries: `dim_oncallx`, `dim_public_tasks_activity`, `dim_public_tasks`, `d_employee_plus`
- Output: Workplace post with data-driven comparisons

**`oncall-health-analyzer`** — Best for toil reduction planning
- Analyzes summaries from any team's Workplace group
- Cross-team comparisons, training gap identification
- Generates prioritized training plans with expected toil reduction %
- Output: Custom reports

**`omh-oncall-feed`** — Best for quick OMH data access
- Fetches OMH feed items (tasks, SEVs, alerts, support cases) via GraphQL
- Also fetches test issues (failures, flaky tests)
- Output: Terminal (structured feed data)

**`oncall-summary-post`** — Best for publishing
- Generates Google Doc draft with structured sections
- Supports bulk GSD task creation for follow-up items
- Output: Google Doc with overview, criticals, improvements, SEVs, follow-ups

## Dashboard Format

Used by `/my-oncall dashboard`. Keep under 25 lines. Lead with action items. Skip empty sections.

```
## Oncall — [date] | [rotation]

### Needs Action Now
[Active alerts, unacked SEVs, stalled tasks. If clear: "All clear"]

### Monitoring
[Mitigated items. What to watch, when to escalate]

### Context Loaded
- Runbook: [link]
- Escalation: [contacts/path]
- Open follow-ups: [count from ONCALL-LOG]

### Stats
| Alerts (active/cleared) | SEVs | Tasks | Diffs |
```

---

## Alert State Tracking

Each alert in `projects/mrs-ml-training-reliability/ONCALL-LOG.md` carries a state that persists across sessions. `/my-oncall` reads and updates these automatically — no manual state management needed.

**States**: `detected` → `investigating` → `mitigated` → `resolved`

**Log format** (append per alert, update state in-place):
```
### [Alert ID / Title] — [state]
- **Detected**: YYYY-MM-DD HH:MM
- **Source**: [OMH / OD / GChat / manual]
- **State history**: detected (HH:MM) → investigating (HH:MM) → ...
- **Root cause**: [filled when known]
- **Mitigation**: [what was done]
- **Follow-up**: [task/diff if needed, or "none"]
```

**Rules**:
- `/my-oncall dashboard` counts alerts by state for the Stats row and surfaces `investigating` alerts in "Needs Action Now"
- `/my-oncall handover` auto-generates the handover from non-resolved alerts — no manual rewriting
- State transitions happen naturally: when Claude investigates an alert, update to `investigating`; when a mitigation is applied, update to `mitigated`; when confirmed fixed, `resolved`
- Resolved alerts stay in the log for the shift duration (handover context), then get dropped on next shift start

---

## Handover Format

Used by `/my-oncall handover`. Write to `context/cache/ONCALL-HANDOVER.md` (overwrite).

```
# Oncall Handover — [rotation] | [date range]

## Must Act On
1. **[Item]**: [Context]. [Next action].

## Monitor
1. **[Item]**: [What to watch]. [Escalation path].

## Context
- [Background items]

## Open Diffs/Tasks
[Table if any]
```

---

## Alert Query and Debugging

### Querying Active Alerts

Use the `onedetection-alert-query` skill (installed via `claude-templates skill onedetection-alert-query install`).

```bash
# List all active alerts for a rotation
~/.claude/skills/onedetection-alert-query/scripts/graphql_alerts_by_filter.sh \
  --oncall mrs_online_training --state active

# List recently cleared alerts
~/.claude/skills/onedetection-alert-query/scripts/graphql_alerts_by_filter.sh \
  --oncall mrs_online_training --state cleared --limit 50

# Get full details for a specific alert (decode %40→@ %23→# %24→$ from URL first)
~/.claude/skills/onedetection-alert-query/scripts/graphql_alert_content.sh "<decoded_alert_id>"

# Get detector config (Scuba query, thresholds)
~/.claude/skills/onedetection-alert-query/scripts/get_detector_details.sh <detector_id>
```

The OMH alerts dashboard (https://www.internalfb.com/omh/view/<rotation>/alerts) is NOT loadable via Metamate or knowledge_load — always use the GraphQL skill above.

### Alert Creation and Calibration via Claude

Claude can write and calibrate OneDetection monitoring alerts end-to-end. When setting up new monitoring for a service or pipeline:
1. Ask Claude to review existing alerts for the rotation (via the query skill above)
2. Describe what you want monitored — Claude generates the detector config with appropriate thresholds
3. Claude calibrates against recent data to reduce false positives

This replaces manual threshold tuning. Works for Scuba-backed detectors. Pattern source: AI4P post on writing 4 calibrated alerts in 3 prompts.

### Reading Alert IDs from URLs

Alert URLs encode the ID with URL escaping. Decode before using:
```
%40 → @    %23 → #    %24 → $    %3A → :    %2F → /    %20 → space
```

Example: `2311582562654335%40%23%24mvai_metrics%40%23%24...` decodes to `2311582562654335@#$mvai_metrics@#$...`

The decoded alert ID contains structured fields separated by `@#$`:
```
<detector_id>@#$<source>@#${key:value; key:value; ...}@#$<alert_name>
```

### Common OT Alert Patterns

| Pattern | Likely Cause | Action |
|---------|-------------|--------|
| Multiple NaN metrics from same job, same timestamp | Job restart / warmup phase | Check if job is running; will auto-clear |
| Single NaN metric, sparse task (VPVD, outbound_click) | Empty training window for low-volume task | Monitor; typically transient |
| NaN across ALL metrics | Job crash or data pipeline gap | Investigate job status and upstream data |
| Threshold violation on single metric | Model regression or data distribution shift | Check training logs, compare to baseline |

### Debugging Workflow

1. **Identify scope**: Same job? Same detector? Same timestamp? → Batch issue vs. individual
2. **Check job health**: Is the training job still running and producing checkpoints?
3. **Check upstream data**: Are training data pipelines flowing?
4. **Check metric history**: Is this a new metric (warmup NaN) or a regression?
5. **Escalate if**: Multiple CRITICAL alerts, metrics not recovering after 1h, or checkpoint publishing stopped

---

## Oncall Shift Report Template

Full template (with SEV blocks, alert tables, timeline, data gathering, and writing principles) is in `oncall/oncall-templates.md`. Load on demand when generating reports.

---

### MRS OT Oncall Reference

- **Rotation**: `mrs_online_training`
- **OMH alerts**: https://www.internalfb.com/omh/view/mrs_online_training/alerts?query=ALERTS_OVERVIEW
- **Oncall log**: `projects/mrs-ml-training-reliability/ONCALL-LOG.md` (per-shift)
- **Report template**: `projects/mrs-ml-reliability/ONCALL-REPORT-*.md`

---

## See Also

`career/impact-metrics.md`, `oncall/pe-reliability-metrics.md`, `career/anti-patterns.md`
