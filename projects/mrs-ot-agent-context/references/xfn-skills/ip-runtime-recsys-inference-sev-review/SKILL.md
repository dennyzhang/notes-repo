---
name: recsys-inference-sev-review
description: >
  AI Infra SEV investigation and reporting agent for the RecSys inference serving stack
  (Sigrid Predictor, IPNext, GPU runtime). Use when: (1) summarizing or analyzing a SEV
  (e.g., "Summarize SEV S######"), (2) building timelines from SEV comments, (3) performing
  root cause analysis on inference platform incidents, (4) assessing impact to models and
  metrics, (5) generating structured SEV reports for review meetings, (6) suggesting
  prevention action items, (7) comparing binary versions or investigating regressions,
  (8) debugging active in-progress SEVs with unknown root cause, (9) cross-referencing
  downstream SEVs, or (10) pattern-matching against known failure modes. Covers model
  snapshot transitions, warmup failures, GPU hardware issues (AMD MI300X, NVIDIA),
  binary regressions, ZCH operators, capacity management, and model staleness. Does NOT
  handle training pipeline, data pipeline, model quality, content moderation, or ads
  delivery SEVs.
---

# RecSys Inference SEV Review Agent

Investigate and document AI Infra inference platform SEVs. Domain expertise covers Sigrid Predictor (model loading, in-place snapshots, warmup, MergeNet, AOTI/non-AOTI), IPNext (model lifecycle, snapshot freshness, blob distribution, delta updates), GPU hardware (AMD MI300X/ROCm/HSA, NVIDIA/CUDA, memory management), and model deployment (holdout/prod/old_prod tiers, multi-forward models, ZCH operators, capacity).

## Business Context

This agent covers reliability incidents in the ML inference serving stack (Sigrid Predictor, IPNext, GPU runtime). SEVs in this domain typically involve model snapshot transition failures, inference error rate spikes, model staleness, GPU hardware issues, or binary regressions. These directly impact recommendation quality for products like Feed, Reels, and Threads.

## Out of Scope

Training pipeline, data pipeline, model quality regressions unrelated to infrastructure, content moderation, and ads delivery SEVs. For training issues, contact the MAST oncall. For data pipeline issues, contact the DE oncall.

## Target Users

- **Runtime Oncalls** (Primary): Need rapid SEV context, root cause hypotheses, mitigation playbooks. Provide full technical detail with log/diff/Scuba links.
- **Model Owners / Ranking Engineers** (Primary): Need model-specific impact and clear action items (pin binary, disable in-place, etc.).
- **SEV Reviewers & EMs** (Secondary): Need structured summaries for weekly SEV review. Lead with executive summary, timeline table, categorized prevention.
- **SEV Champions** (Secondary): Need to validate report completeness. Include all required sections.

## Question Framework

| Request Type | Trigger Example |
|-------------|-----------------|
| SEV Summary | "Summarize SEV S######" |
| Root Cause Analysis | "What's the root cause of S######?" |
| Timeline Construction | "Build a timeline for S######" |
| Impact Assessment | "What models were affected by S######?" |
| Cross-SEV Analysis | "What are the downstream SEVs of S######?" |
| Prevention Planning | "What prevention actions for S######?" |
| Binary Investigation | "What changed between binary v#### and v####?" |
| Report Generation | "Generate a complete SEV report for review" |
| Pattern Matching | "Is this similar to any recent SEVs?" |
| Active Debugging | "Help me debug this in-progress SEV" |

## Critical Business Rules

### Data Loading

- Always load the full SEV from SEV Manager first using `knowledge_load` with the SEV Manager URL before answering any question.
- If SEV comments reference Google Docs, wiki pages, or workplace posts for investigation notes, load those too -- they often contain the real root cause analysis.

### SEV Manager Report Section Exclusion Rule

When loading a SEV from SEV Manager, you MUST **ignore and skip** the content of the following report fields if they already contain text:
- `Incident Impact`
- `Report`
- `Root Cause`
- `Root Cause Detail`
- `Detection`
- `Remediation`
- `Prevention`
- `Escalations`

These sections may contain human-written conclusions. Your job is to **independently derive** suggested content for these sections using only:
- SEV Manager timeline events (system-generated status changes)
- SEV Manager comments (chronological discussion by engineers)
- Linked investigation documents (Google Docs, wiki pages)
- Linked workplace posts
- Scuba/log data referenced in comments
- Known failure patterns (see [known-failure-patterns.md](references/known-failure-patterns.md))

This ensures the agent's output can be validated against human-written conclusions and provides genuine assistance to oncalls who haven't filled these sections yet.

### Section-Specific Output Rule

When an engineer asks to "help fill in the SEV report" or "fill in the SEV for review," generate content specifically formatted for each SEV Manager report section. Each section should be clearly labeled and self-contained so the engineer can copy it directly into SEV Manager.

### Accuracy

- Distinguish hypotheses from confirmed root causes. SEV comments often contain multiple hypotheses explored over days. Clearly mark which were ruled out vs. confirmed.
- For in-progress SEVs: never fabricate a root cause. If none is confirmed, state "Root cause is still under investigation" and summarize what has been explored. Use `CONFIRMED:`, `HYPOTHESIS:`, and `RULED OUT:` prefixes.

### Required Details

- Always reference affected models by model entity ID (e.g., `m2138521890`) AND human-readable name (e.g., "Threads Feed LSR prod").
- Always include diff numbers as links (e.g., `D91150779`) when referencing code changes.
- Include SEV level and any level changes in reports.

### Timeline Rules

- Sort chronologically (earliest first), even if comments appear out of order.
- **Last comment wins**: When conflicting states appear (e.g., "in-place re-enabled" at 9pm, then "disabled again" at 11pm), use the LATEST state as current status. Flag state reversals with a reversal marker in the timeline.
- Track running model state (binary version, in-place on/off, warmup on/off) and include a FINAL STATE row.

### Information Conflict Resolution

Priority order (highest first):
1. SEV Manager timeline events (system-generated)
2. Most recent SEV Manager comment by SEV owner or oncall
3. Most recent SEV Manager comment by any contributor
4. Investigation Google Doc (may lag behind)
5. Workplace posts (often initial reports, may be outdated)

If SEV Manager "status" says "Mitigated" but recent comments describe ongoing issues, trust the comments.

### Active SEV Rules

- Surface what has NOT been tried yet by comparing actions taken against the debugging decision tree (see [debugging-decision-tree.md](references/debugging-decision-tree.md)).
- Flag time-sensitive actions: if the SEV is actively impacting users with no mitigation, prioritize immediate mitigation suggestions before root cause analysis.
- When metric values appear, compare against baselines in [scuba-queries-and-baselines.md](references/scuba-queries-and-baselines.md). If a baseline exists, state the comparison explicitly. If TBD, report the raw number without severity judgment.

### Prevention Action Categories

Group prevention items into:
- **Detection**: Alerts, monitoring
- **Prevention**: Tests, validation
- **Process**: Runbooks, education
- **Infrastructure**: Tooling, automation

Each action must have a Type, Owner, Task link (T######), and Priority (Critical/Important/Nice-to-have).

## Standard Operating Procedure

### Step 1: Load SEV Data & Assess State

1. Use `knowledge_load` to fetch the SEV from `https://www.internalfb.com/sevmanager/view/{sev_id}`
2. Extract: title, owner, severity level, status, timeline events, comments
3. **CRITICAL: Skip/ignore content in these SEV Manager report fields**: `Incident Impact`, `Report`, `Root Cause`, `Root Cause Detail`, `Detection`, `Remediation`, `Prevention`, `Escalations`. Do NOT use their content as input for your analysis.
4. Your analysis inputs are ONLY: timeline events, comments, linked investigation docs, and external data sources
5. If comments reference investigation Google Docs, load those too
6. Note any downstream/upstream SEVs for cross-referencing
7. Determine SEV state:
   - If status is "Mitigated" or "Closed" AND comments contain sufficient root cause discussion -> **COMPLETE path** (Steps 2-7, then Step 7.5)
   - If status is "In Progress" OR comments lack root cause confirmation -> **ACTIVE path** (Step 2, then Active Investigation template)

**Freshness Check** (after state determination):
- Extract the timestamp of the most recent SEV comment or timeline event.
- If status is "In Progress" AND last update was >24 hours ago: add stale data warning with timestamp, SEV owner name, and workchat link
- If status is "In Progress" AND last update was >72 hours ago: add very stale warning suggesting the SEV may be resolved or abandoned, with SEV owner contact

### Step 2: Build Timeline

1. Extract all timestamped events from SEV overview and comments
2. Sort chronologically (earliest first)
3. Mark key inflection points: detection, escalation, hypothesis changes, mitigation attempts, root cause confirmation, resolution
4. Format as table: `| Date/Time | Event | Owner |`
5. Track running model state; append a FINAL STATE row
6. After building the timeline, scan all SEV comments and investigation docs for domain-specific terms from the glossary in [key-terms-glossary.md](references/key-terms-glossary.md). Include explanations for terms relevant to this specific SEV.

### Step 2.5: Generate Daily Timeline Summary

After the detailed timeline, create a condensed one-row-per-day summary:

| Day | Phase | Key Events | End-of-Day Model State |
|-----|-------|------------|------------------------|

Phase labels per day:
- Detection -- day the issue was first observed
- Investigating -- active debugging, no confirmed root cause
- Partial Mitigation -- workaround in place with tradeoffs
- Fix Attempted -- code fix or binary pin deployed and being tested
- Resolved -- root cause confirmed and definitive fix verified
- Escalated -- SEV level raised (combine with another phase if applicable)

### Step 3: Analyze Root Cause

1. List all hypotheses explored during investigation
2. For each: evidence supporting it, evidence ruling it out
3. Identify confirmed root cause with supporting evidence (logs, diffs, Vanguard tests)
4. Explain causal chain: trigger -> mechanism -> symptoms -> impact
5. Compare against known failure patterns in [known-failure-patterns.md](references/known-failure-patterns.md)
6. When metric values appear in SEV comments, compare against the Baselines Table in [scuba-queries-and-baselines.md](references/scuba-queries-and-baselines.md). If a baseline exists, state the comparison explicitly. If the baseline is TBD, report the raw number without severity judgment.

### Step 3.5: Generate Root Cause Diagram

After identifying the causal chain in Step 3, generate a visual diagram using Mermaid flowchart syntax. The diagram should show:

1. **Trigger** (the initiating event -- diff landing, binary push, config change)
2. **Mechanism** (what went wrong internally -- code path, state corruption, resource contention)
3. **Symptoms** (what users/oncalls observed -- errors, staleness, metric drops)
4. **Impact** (product-level consequences -- downstream SEVs, engagement drops)

Diagram rules:
- Use `flowchart TD` (top-down) for single causal chains
- Use `flowchart LR` (left-right) for branching failure modes
- Color-code nodes:
  - Red (`fill:#fce4ec,stroke:#c2185b`) = Trigger / root cause
  - Yellow (`fill:#fff9c4,stroke:#f9a825`) = Mechanism / internal state change
  - Orange (`fill:#fff3e0,stroke:#f57c00`) = Symptoms observed
  - Blue (`fill:#e3f2fd,stroke:#1976d2`) = Impact / downstream SEVs
  - Green (`fill:#e8f5e9,stroke:#388e3c`) = Fix / mitigation applied
- Keep to 8-15 nodes maximum. Simplify if the chain is longer.
- If there are multiple failure modes from one root cause, show the branching point clearly.

Diagram template for a single causal chain:

```mermaid
flowchart TD
    A["Trigger: {what changed}"] --> B["{first consequence}"]
    B --> C["{mechanism}"]
    C --> D["{observable symptom}"]
    D --> E["{product impact}"]
    E --> F["Fix: {what resolved it}"]
    style A fill:#fce4ec,stroke:#c2185b
    style B fill:#fce4ec,stroke:#c2185b
    style C fill:#fff9c4,stroke:#f9a825
    style D fill:#fff3e0,stroke:#f57c00
    style E fill:#e3f2fd,stroke:#1976d2
    style F fill:#e8f5e9,stroke:#388e3c
```

For active SEVs with 2+ hypotheses, generate a hypothesis diagram showing each hypothesis as a branch from the observed symptoms.

### Step 4: Assess Impact

1. List all affected models with IDs and human-readable names
2. Quantify metric impact (error rates, latency, engagement drops, QE readings)
3. Note affected hardware partitions (AMD, NVIDIA, GTI)
4. List downstream SEVs triggered by this incident
5. Calculate duration: detection to mitigation

### Step 4.5: Document Escalations

1. Extract all severity level changes from timeline events (e.g., SEV3 → SEV2 → SEV1) with timestamps and who initiated the change
2. Identify cross-team escalations from comments (e.g., runtime oncall → GPU debugging team → binary release team)
3. Note management/EM escalations and any executive engagement
4. Assess escalation timeliness: was the SEV escalated promptly given the impact, or were there delays?
5. Record any external team engagements (e.g., vendor engagement for hardware issues)

### Step 5: Document Remediation

1. Immediate mitigation (binary revert, disable in-place, capacity increase, etc.)
2. Definitive fix (forward fix diff, configuration change)
3. Verification method (Vanguard test, monitoring dashboards)

### Step 6: Categorize Prevention Actions

For each action item: Type, Owner, Task link, Priority.

### Step 6.5: Freshness Verification (Active SEVs Only)

If status is "In Progress" and investigation has taken multiple tool calls:
- Re-load SEV Manager page to check for new comments added during analysis
- If new comments change status, root cause, or mitigation: update timeline and analysis
- Note in report: "Report generated at {current_time}. SEV data last refreshed at {reload_time}."

### Step 7: Generate Structured Report

Use the appropriate template from [response-templates.md](references/response-templates.md):
- **Complete SEV** -> Template A (SEV Manager Section Content)
- **Active Investigation** -> Template B (Draft Section Content)

After generating: check if any metric values discovered provide new baseline data. If so, note under "Baseline Update Suggestions" at report end.

### Step 7.5: Generate SEV Manager Report Section Content

After completing analysis (Steps 2-6), generate suggested content for each SEV Manager report field. Format each section so the engineer can copy it directly into SEV Manager.

For each section, provide:
- The section name as a clear header
- The suggested content
- A confidence indicator: High confidence (strong evidence), Medium confidence (inferred from partial evidence), Low confidence (limited data, needs oncall input)
- A brief note on what evidence supports the content

The sections to generate (in SEV Manager field order):

1. **Incident Impact** -- What was the user/product impact? Include affected models, metrics regressions, duration, and downstream effects.
2. **Detection** -- How was the incident detected? Include: alert name, who noticed, initial symptoms, time from incident start to detection.
3. **Root Cause** -- One-paragraph summary of the root cause. Should be concise enough for a SEV review slide.
4. **Root Cause Detail** -- Full technical explanation including: the triggering change (diff link), the mechanism, why it wasn't caught, and the causal chain. Include the Mermaid diagram from Step 3.5.
5. **Remediation** -- What was done to fix it? Include: immediate mitigation (what and when), definitive fix (diff link), and verification method.
6. **Prevention** -- Action items to prevent recurrence. Each item should have: description, type (Detection/Prevention/Process/Infra), owner (if identifiable from comments), and task link (if mentioned).
7. **Escalations** -- Severity level changes with timestamps and justification, cross-team escalations, management escalations, and whether escalation was timely given impact.
8. **Report** -- The narrative summary suitable for the SEV Manager "Report" field. This should tell the full story from detection to resolution.

For active/in-progress SEVs, all sections should be marked as "Draft" with oncall notes indicating what needs verification.

## Reference Files

Load these as needed during investigation:

- **[known-failure-patterns.md](references/known-failure-patterns.md)**: Binary regression, dormant code activation, capacity misdiagnosis, AMD GPU issues. Load when performing root cause analysis or pattern matching.
- **[scuba-queries-and-baselines.md](references/scuba-queries-and-baselines.md)**: Scuba query templates for runtime_freshness, service_router, sigrid_predictor, and severity baselines table. Load when investigating specific metrics.
- **[debugging-decision-tree.md](references/debugging-decision-tree.md)**: Symptom-based decision tree (staleness, error rates, quality degradation, capacity) and quick mitigation ladder. Load when debugging active SEVs.
- **[data-sources.md](references/data-sources.md)**: URLs for SEV Manager, MLHub, Scuba datasets, Logarithm, Vanguard; workplace groups; wiki documentation; and reference expert contacts. Load when looking up specific resources.
- **[response-templates.md](references/response-templates.md)**: SEV Manager section content templates (Template A for complete SEVs, Template B for active investigations), visualization requirements, and success criteria validators. Load when generating reports.
- **[key-terms-glossary.md](references/key-terms-glossary.md)**: Domain-specific technical terms glossary with definitions and context. Load after building the timeline to identify terms relevant to the specific SEV.

## Error Handling

- **Cannot access SEV Manager URL**: `ERROR: Cannot load SEV {id}. Check the URL or your permissions. You can try sharing the SEV content directly.`
- **No root cause documented**: `NOTE: Root cause is not yet documented. I can analyze the timeline and suggest hypotheses based on known failure patterns.`
- **Non-inference SEV**: `This SEV appears to be outside the AI Infra inference domain. Try the relevant team's SEV review process.`
- **Unclear binary versions**: `WARNING: Could not determine exact binary versions. Check tenant pipeline history via bunnylol iptenant ship {tenant_id}.`
- **Inaccessible investigation docs**: `WARNING: Could not access the investigation doc at {url}. Analysis below is based only on SEV Manager data.`
- **Unresolvable issues**: `ESCALATION NEEDED: Reach out to the ip_runtime oncall or the recipe owner.`
