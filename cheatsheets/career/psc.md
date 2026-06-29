# PSC Preparation Cheatsheet

Quick reference for synthesizing a half of PE work into a PSC packet. Calibrated to PE-specific level expectations, supports both project-focused and fixer archetypes.

**Constraint:** 800-word limit for the four assessment sections (Project Impact, Engineering Excellence, People, Direction). CTW summary and Growth Areas are outside this limit.

## Write for Calibration

Your primary audience is **managers from other teams** reading your packet in calibration. They need to understand your work in 2 minutes. Every section should answer these 4 questions:

| Question | What They're Looking For |
|----------|------------------------|
| **What is the concrete impact?** | Metrics, outcomes, business results — not activities |
| **What is YOUR individual contribution?** | What you did vs. the team |
| **Why was this challenging?** | Technical complexity, ambiguity, scope |
| **How does this relate to goals?** | Planned vs. actual, met/exceeded/fell short |

## PE Archetype Detection

| Archetype | Signals | PSC Framing |
|-----------|---------|-------------|
| **Project-Focused** | Led 1-3 large projects, clear milestones | Classic: problem, solution, impact |
| **Fixer** | Many investigations, cross-system debugging, pattern recognition | Laundry list OK if each item is impactful. Frame: pattern, systemic fix, prevention |
| **Tech Lead** | Team roadmap, diff reviews, mentoring, shipping through others | Team outcomes enabled by your leadership + personal technical contributions |
| **Broad TL** | Cross-team coordination, architectural direction | Influence radius, decisions that shaped multiple teams |

"If the packet looks like a laundry list, but each item looks worthy and impactful, you may have a fixer. Do not pigeonhole them in a classic project-focused discussion."

## Data Gathering

| Source | What to Extract |
|--------|----------------|
| **Diffs landed** | Count, complexity, themes — `sl log --user <you> --date "YYYY-MM-DD to YYYY-MM-DD"` |
| **Diffs reviewed** | Count, quality of reviews, coaching given |
| **SEV contributions** | SEVs responded to, your role, MTTD/MTTR impact |
| **Tasks completed** | GSD tasks, outcomes |
| **SLO improvements** | Before/after metrics (SLICK) |
| **Oncall improvements** | Alert reduction, automation built (IROC) |
| **Mentoring** | Who, what, outcomes |
| **Org contributions** | Interviews, bootcamp, DPE |
| **Cross-team work** | Design reviews, working groups, RFC participation |

### Diff Velocity Check

PE expectation: at least 1 diff/week, aim for 3+/week.

```
Total diffs: [N] | Average: [N/weeks]/week | Status: [above bar / below bar]
```

## Four-Axis Mapping (PE Signals)

### Project Impact

| PE Signal | Evidence |
|-----------|----------|
| Reliability improvements | SLO attainment, SEV reduction |
| Capacity savings | $ or cores freed |
| Performance optimization | Latency, throughput |
| Services unblocked | Partner teams enabled |
| User-facing impact | Through infrastructure improvements |

**Per-project structure** (answer the 4 calibration questions):

**Writing rules:**
- **Outcome first**: "Reduced SEV frequency 40%" not "Built a monitoring system." Flip every sentence — if it starts with Built/Implemented/Created, rewrite starting with the outcome verb.
- **Bold key metrics** inline: "...reducing MTTD from **45 min to 8 min** across **12 services**." Calibration readers scan, they don't read.
- **Front-load strongest project** first in each section. If a reader only reads the first paragraph, they should see your best work.
- **Continuous brag doc**: Don't write the PSC from memory. Keep a running brag doc throughout the half. Prevents recency bias.

```
[Project Name] ([Timeframe], [Your Role]):
- Goal: [Original goal/target]
- Challenges: [Why difficult — complexity, ambiguity, constraints]
- Contributions: [What YOU did — design, implementation %, coordination]
- Impact: [Metrics achieved vs. goal, timeline vs. plan]
[links to evidence]
```

### Engineering Excellence

| PE Signal | Evidence |
|-----------|----------|
| Code review quality | Diffs reviewed, coaching, bar raised |
| SEV handling | MTTD/MTTR contributions, root cause quality |
| Monitoring & observability | Improvements shipped |
| Testing infrastructure | Integration, chaos, load tests |
| Oncall improvements | Alert quality, runbooks, automation |
| SLI/SLO definition | Coverage, adoption |

### Direction

| PE Signal | Evidence |
|-----------|----------|
| Roadmap planning & execution | IC5+ |
| Running roadmap planning process | IC6+ |
| Architecture proposals | Technical direction set |
| Tech debt identification | Prioritized and addressed |
| Cross-team reliability initiatives | Scope of influence |
| Oncall-to-project conversion | Systemic issues identified and fixed |
| Discover new areas | IC6: new areas for team to pursue |

**Attribution note:** Idea generation = Direction. Executing/shipping the idea = Project Impact.

### People

| PE Signal | Evidence |
|-----------|----------|
| Mentoring | Especially new PEs on oncall ramp |
| Diff review as teaching | Coaching through code review |
| Knowledge sharing | Tech talks, docs, runbooks |
| Interviews | ~2/week at IC5+ (~25 hrs/half) |
| SEV review leadership | Training team on incident response |

"You still can't interview your way to Meets All. Impact is still the most important aspect."

## Level Calibration

### IC5 (E5) — Meets Expectations

- Own projects taking at least a full half (months)
- Independently solve whole business problems (what AND how)
- Delegate while maintaining high individual productivity — "Focusing solely on facilitation or delegating away tech work is not a path to success"
- Drive SLO definition for owned services
- Champion Engineering Excellence (SEV contributions, reliability, efficiency)
- ~25 hours/half org contributions
- 1+ diff/week minimum, 3+/week target

**Common IC5 gaps:** Delegating away tech work. Not driving SLO adoption. Not participating in SEV reviews.

### IC6 (E6) — Meets Expectations

- Projects in halves or years, influencing other teams (not just individuals)
- **Leadership is the key differentiator** from high-performing IC5
- Involved with business aspects of the problem space
- Partner with managers for roadmaps with ROI
- Pay attention to opportunity costs — "the team could do something else with higher ROI"
- Run roadmap planning, coordinate team-wide events
- Discover new areas for team to pursue

**IC6 Fixer signals:** Natural circle of influence. Cross-system investigations. Surface patterns. Follow problems across org boundaries. Raise the bar in SEV Reviews. Teach investigation techniques.

## PSC Template

```
CoreTechnicalWork: Diffs:X [links], SLOC:X, DiffsActioned:X [links],
Daiqueries:X, Notebooks:X, TechnicalDesigns:X [links],
SEVs owned/mitigated:X [links], MLTrainingWorkflows:X

---

## Performance Summary: [Name] — [Half]

**Level:** [Current] | **Role:** PE Tech Lead
**Team:** [Name] | **Size:** [N engineers]
**Archetype:** [Project-Focused / Fixer / Broad TL]

---

### Executive Summary
[3-4 sentences: What did you accomplish? Why did it matter? Who benefited?]

---

### Project Impact
[2-3 paragraphs. Use per-project structure (Goal/Challenges/Contributions/Impact).
Fixers: group investigations into themes.]

**Key metrics:**
| Outcome | Metric | Confidence |
|---------|--------|-----------|
| [Outcome] | [Number] | [H/M/L] |

---

### Engineering Excellence
[1-2 paragraphs]

- Code reviews: [N reviewed, themes, bar raised]
- SEV handling: [N SEVs, roles, MTTD/MTTR]
- Oncall: [Improvements with measured impact]
- SLO/SLI: [Coverage, attainment]

---

### Direction
[1-2 paragraphs]

- Roadmap: [What planned, how tracking]
- Architecture: [Proposals, decisions, cross-team influence]
- New areas: [Discovered and proposed]

---

### People
[1-2 paragraphs]

- Mentoring: [Who, growth, outcomes]
- Diff reviews: [Coaching examples]
- Org: [Interviews (N), intern mgmt, DPE]
- Knowledge sharing: [Talks, docs, runbooks]

---

### Diff Velocity
- Landed: [N] ([X/week avg])
- Reviewed: [N]

---

### Self-Assessment
**Calibration:** [Exceeds Some / Meets All / Meets Most] at [level]
**Rationale:** [1-2 sentences referencing level bar]

---

### Growth Areas
[1-2 meaningful areas. Include specific examples and what you learned.]
- [Area 1]: [What happened, what you'd do differently]
- [Area 2]: [What happened, what you'd do differently]
```

## Anti-Patterns

| Anti-Pattern | Example | Fix |
|--------------|---------|-----|
| Activity over impact | "Reviewed 200 diffs" | "Reviews led to 3 reliability improvements preventing X" |
| Claiming team credit | "Team achieved 99.99%" | "I drove SLO definition and alert tuning that enabled..." |
| Missing people signal | No mentoring section | Add: who mentored, what grew, coaching through reviews |
| Single-axis focus | All Project Impact | Ensure all four axes have evidence |
| No baseline | "Improved latency" | "Reduced P99 latency from 450ms to 120ms (73% reduction)" |
| Effort justification | "Spent 3 months on X" | Time invested is not impact. State the outcome. |
| Passive voice | "Monitoring was improved" | "I built 12 SLI dashboards covering 3 oncall areas" |
| Missing counterfactual | "Fixed the bug" | "Without the fix, estimated $X/week impact to Y users" |

## Impact Writing Framework: STAR-I (Source: STAR adapted for engineering)

Every impact claim should have these 4 elements:

| Element | What it answers | Example |
|---------|----------------|---------|
| **Situation** | What was the problem/opportunity? | "MRS ML Package Archiver had no failure alerting — oncall discovered failures via email 2-3 hours late" |
| **Task** | What was your specific role? | "As TL, I owned the alerting gap and proposed a Watchtower-based solution" |
| **Action** | What did YOU do (not the team)? | "Designed alert config, created D98260667 (2 defense layers + 2 tests), landed in 3 days" |
| **Result + Impact** | Measurable outcome | "MTTD reduced from 2-3 hours to <5 min. Estimated 4 silent failures/month now auto-detected." |

**The "I" upgrade**: Add the **counterfactual** — what would have happened without your contribution? This separates "participated" from "was essential."

## Impact Laddering: IC5 → IC6 → IC7 (Source: Will Larson, Staff Engineer's Path)

| Level | Impact scope | Example framing |
|-------|-------------|-----------------|
| **IC5** | "I built X which improved Y by Z%" | Individual contribution, clear ownership |
| **IC6** | "I identified the pattern across N services, designed the solution, and led 2 engineers to ship it" | Cross-team pattern, solution design, multiplied through others |
| **IC7** | "I set the technical direction for [area], which changed how 3 teams approach [problem]. The resulting improvements saved $X/year across the org." | Organizational impact, direction-setting, lasting change |

**The IC6→IC7 gap**: IC6 solves problems given to them at higher scope. IC7 identifies which problems are worth solving and convinces others to work on them. In the PSC, the difference shows up in the Direction section — IC7 has "I proposed and drove adoption of..." not just "I executed..."

## What Calibration Reviewers Actually Look For (Source: aggregated from Meta PE calibration patterns)

| What they scan first | What makes them stop reading | What makes them rate higher |
|---------------------|------------------------------|---------------------------|
| Executive summary (do I understand what this person does?) | Wall of text with no metrics | Clear before/after numbers |
| Key metrics table (is the impact quantified?) | Activity lists ("I did X, Y, Z") | Counterfactual impact ("without this, X would happen") |
| Level-specific signals (does this match IC5/6/7?) | Vague scope ("worked on reliability") | Specific scope ("OT pipeline for 6 retrieval models") |
| Growth areas (self-aware or defensive?) | "I have no growth areas" | Honest weakness + what you learned |

For impact quantification anti-patterns (vague scope, missing confidence, effort justification), see `career/impact-quantifier.md`.

## See Also

`oncall/sev.md` (SEV impact framing), `career/impact-quantifier.md` (quantifying impact), `career/communication.md` (collaboration framing), `references/level-expectations.md`, `references/four-axes.md`
