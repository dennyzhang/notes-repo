# SEV Firefighting Cheatsheet

Quick reference for the full SEV lifecycle: active response, review preparation, and retrospective impact framing.

## Mode Detection

| Mode | When | Purpose |
|------|------|---------|
| **Active** | Live incident in progress | Triage, communicate, mitigate |
| **Review** | Preparing for SEV review meeting | Generate pointed questions that drive action |
| **Retrospective** | After resolution, for PSC/impact | Quantify your contribution |

---

## Active Mode

### First 60 Seconds: 3 Questions (Source: Google SRE)

Before anything else, answer these three:
1. **What is broken?** (service, model, pipeline — name it)
2. **Who is affected?** (users, revenue, internal teams)
3. **Is it getting worse?** (trend: growing, stable, recovering)

If you can't answer all three in 60 seconds → escalate immediately. You're missing context that someone else has.

**Declare high, downgrade later.** If uncertain between SEV1 and SEV2, declare SEV1. Over-declaring is free. Missing a SEV1 costs hours.

### Assess Severity and Blast Radius

| Factor | Questions |
|--------|-----------|
| **Severity** | SEV1 (revenue/safety), SEV2 (significant degradation), SEV3 (limited impact)? |
| **Blast radius** | How many users/services? Which regions? |
| **Revenue impact** | Estimated $/hour — SEV1: $500K-$2M, SEV2: $50K-$200K, SEV3: $5K-$50K |
| **Trend** | Getting worse, stable, or improving? |
| **Dependencies** | Upstream/downstream services affected? |

### Escalation Criteria (Source: PagerDuty Incident Response)

Escalate when ANY of these are true:
- Impact is growing and mitigation hasn't started within 15 min
- You don't understand the failure mode after 10 min of investigation
- Fix requires access/expertise you don't have
- Multiple teams need coordinated action
- Customer-facing impact crosses a product boundary

**Never escalate "too early" — early escalation is always cheaper than late.**

### Incident Roles (Source: ICS adapted for software)

| Role | Responsibility | When needed |
|------|---------------|-------------|
| **Incident Commander (IC)** | Owns the response. Decides priorities, assigns tasks, controls communication cadence. | Always (defaults to oncall engineer) |
| **Comms Lead** | Posts updates at committed intervals. Shields IC from status requests. | SEV1 or when >3 teams involved |
| **Subject Matter Expert** | Deep-dives into specific systems. Reports findings to IC. | When root cause crosses domain boundaries |
| **Scribe** | Records timeline, decisions, actions in real-time. | SEV1 (for accurate postmortem) |

For SEV2-3 with 1-2 people, the oncall engineer plays all roles. Split roles only when coordination overhead justifies it.

### SEV Post Templates

**Initial post:**
```
**[SEV Level]: [One-line description]**

**Impact:** [Who/what is affected, scope]
**Status:** Investigating
**DRI:** @[name]

**Current understanding:**
- [Symptoms observed]
- [Timeline: when it started]
- [What we know / don't know]

**Next update:** [Time — 30 min for SEV1, 1 hour for SEV2]
```

**Update:**
```
**Update [Time]:** [SEV-ID]

**Status:** [Investigating / Mitigating / Resolved]
**Change:** [What changed since last update]

**Current actions:**
- [Action 1]: [Owner]
- [Action 2]: [Owner]

**Next update:** [Time] or when status changes
```

**Resolution:**
```
Resolved: [SEV-ID] [One-line description]

**Duration:** [Start] - [End] ([X hours])
**Impact:** [Final impact — users, duration, revenue]
**Root cause:** [1-2 sentences]
**Fix:** [What was done]

**Follow-ups:**
- [ ] [Action]: [Owner] - [Date]

Post-mortem: [Link when available]
```

### Verify Mitigation with Metrics (Source: Google SRE)

After applying a fix, don't trust "it looks better." Define the validation metric and watch it:

1. Identify the metric that proves impact stopped (staleness age, NE, error rate, traffic)
2. Watch for 15 minutes after mitigation
3. If no improvement → mitigation failed, try next option
4. Only declare "mitigated" when the metric confirms recovery

**"Mitigated" ≠ "Resolved."** Mitigated = user impact stopped. Resolved = root cause fixed and prevention deployed. These are different SEV states.

### Mitigation Options

Evaluate in order of speed and safety:

| Option | Speed | Risk | When to Use |
|--------|-------|------|-------------|
| **Rollback** | Fast | Low | Recent deploy caused the issue |
| **Config change** | Fast | Low-Med | Feature flag, rate limit, config-driven fix |
| **Traffic shift** | Fast | Medium | Regional or capacity issue |
| **Disable feature** | Fast | Medium | Isolate faulty component |
| **Scale up** | Medium | Low | Capacity-related |
| **Hotfix** | Slow | Medium | Root cause known, targeted fix |

**Key question:** "What is the fastest safe way to stop the bleeding?"

### Investigation Checklist

```
Recent Changes:
- [ ] Code deploys in the last 24 hours
- [ ] Config changes (feature flags, rate limits)
- [ ] Infrastructure changes (capacity, networking)
- [ ] Dependency updates (upstream services, libraries)
- [ ] Traffic pattern changes (seasonal, campaign-driven)
```

### Investigation Paste — 2 Canonical Questions

Every major SEV investigation eventually needs a shareable paste
that answers the same two questions. Use this template directly —
don't reinvent each time. Past worked examples: P2313270537
(S654235), P2313129757 (S654235 brief).

**Q1: Which part of the `<system>` process gets stuck — and why?**

Answer in three layers:

| Layer | What to provide |
|-------|-----------------|
| **Stuck site(s)** | Specific `file:line`, function name, what call. If multiple sites (rank-dependent), list each. |
| **Solid evidence** | Per-rank progress map: which rank logged what at what timestamp. Cite the literal log message verbatim. Include a code window showing the last log + the next missing log (proves the silent gap location). |
| **Root mechanism** | NOT "X calls Y which times out" (that's symptom). Why does Y NOT have a timeout / fail-fast / proper logging? Trace to the design choice that allows the failure mode. Cite codebase rules (`ACR_*.md`) and past SEVs of same class. |

**Q2: Suggested mitigation**

Always provide ALL FOUR tiers — even if one tier is "not applicable":

| Tier | When | Constraints |
|------|------|-------------|
| **Immediate (today, no code)** | Live SEV is bleeding | Must be reversible. Workarounds, traffic shifts, host bumps, blocklists. |
| **Short-term (this week, low-risk diff)** | After bleeding stops | Heartbeat-only / observability-only diffs. No new failure modes. |
| **Medium-term (this month, behavior change)** | After short-term ships | Add fail-fast, timeouts, JK-gated. Requires data from short-term observability. |
| **Long-term (this quarter, structural)** | After medium-term proves out | Sweep sibling sites, eliminate the anti-pattern class, rearchitect if needed. |

For each tier, include:
- Action with file:line refs
- Owner (specific person or oncall name — never "TBD")
- Risk (low / medium / high) with one-line justification
- Expected effect (quantified where possible — "X→Y minutes", "rate-Z events / week")

**Rules:**

- Q1's evidence section MUST include verbatim log/error messages —
  no paraphrasing (per memory `feedback_verbatim_logs_in_drafts`).
- Q1's `file:line` refs MUST be grep-verified before publishing
  (per memory `feedback_verify_line_refs_in_pastes`).
- Q2's "Immediate" tier should fit on 1 row of a table — if it
  needs prose, it's not actually immediate.
- If you can't fill a tier in Q2, write "N/A — <reason>" rather
  than skip it. Empty tier is a smell.

### Root Cause Analysis: 5 Whys (Source: Toyota/Google SRE)

Don't stop at the first cause. Ask "why" 5 times to reach the systemic root:

```
Symptom: Model staleness alert fired
Why 1: Trainer hasn't produced a snapshot in 6 hours
Why 2: Trainer crashed with OOM
Why 3: Batch size doubled from config change
Why 4: Config change wasn't validated against memory limits
Why 5: No pre-deploy memory check exists for config changes
→ Root cause: Missing validation gate, not the OOM itself
→ Fix: Add memory budget check to config deploy pipeline
```

**Rules:**
- Each "why" must be supported by evidence (log line, metric, timeline entry)
- Stop when you reach a process/system gap (not a person's mistake)
- If you can't answer a "why", that's your investigation gap — find the evidence

### Blameless Postmortem Template (Source: Google SRE + Etsy)

```markdown
# Postmortem: [SEV-ID] [One-line description]

## Summary
[2-3 sentences: what happened, impact, duration]

## Timeline (UTC)
| Time | Event |
|------|-------|
| HH:MM | First symptoms observed |
| HH:MM | Alert fired / incident declared |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied |
| HH:MM | Incident resolved |

## Root Cause (5 Whys)
[Chain from symptom to systemic cause — see template above]

## Impact
- Duration: [X hours]
- Users affected: [N]
- Revenue impact: [$X] ([confidence])
- Error budget consumed: [X%]

## What Went Well
- [Specific thing that worked — be concrete]

## What Went Wrong
- [Specific thing that failed — focus on systems, not people]

## Action Items
| Action | Owner | Priority | Due | Task |
|--------|-------|----------|-----|------|
| [Preventive fix] | @name | P0 | YYYY-MM-DD | T<number> |
| [Detection improvement] | @name | P1 | YYYY-MM-DD | T<number> |

## Lessons Learned
[What would we do differently? What should other teams know?]
```

**Blameless principle:** Focus on "what" and "why", never "who". Replace "X didn't monitor" with "monitoring for X was not configured." The goal is to make the system safer, not to assign fault.

### Follow-Up Categories

| Category | Examples |
|----------|---------|
| **Preventive** | Add monitoring, improve alerting thresholds |
| **Detective** | Better dashboards, anomaly detection |
| **Process** | Update runbooks, improve escalation paths |
| **Architectural** | Eliminate single points of failure, add circuit breakers |
| **Testing** | Chaos tests, integration tests |

### Active Mode Checklist

Before closing active response:

- [ ] SEV post with accurate severity and blast radius
- [ ] Regular updates at committed intervals
- [ ] Root cause identified (or investigation plan)
- [ ] Mitigation applied and verified
- [ ] Resolution post with impact summary
- [ ] Follow-up action items with owners and dates
- [ ] DRI handoff communicated (if applicable)
- [ ] SLI linkage verified — did SLIs detect this? If not, gap identified
- [ ] Error budget impact calculated

---

## Review Mode

Generate pointed questions for SEV review meetings. Every question drives toward a concrete action.

### Historical Pattern Mining

Before generating questions, search for similar past SEVs:

```
knowledge_filtered_search(
  doc_types: ["SEV"],
  keywords: "<affected service or failure type>",
  start_creation_time: "<6 months ago>"
)
```

**Without history:** "Should we add monitoring for this failure mode?"
**With history:** "This is the 3rd cache OOM in 4 months. The follow-up from S496098 was 'add memory alerts' — did that ship? If it did, why didn't it fire?"

### Gap Patterns

| Gap | What to Look For | Question Pattern |
|-----|-----------------|-----------------|
| **Detection lag** | Time between failure and alert | "Failure started at X but alert fired at Y. What SLI catches this in <5 min?" |
| **Slow rollback** | Rollback >10 min | "Rollback took X min. What blocked it?" |
| **Repeat failure** | Similar SEV in past 6 months | "This is the Nth [type] SEV. What's the systemic issue?" |
| **Missing SLI** | No SLI fired or fired late | "Our SLI measures X, not Y. Should we add Y?" |
| **Vague root cause** | Abstract description | "Root cause says '[vague].' Which specific code path?" |
| **Unclear blast radius** | Qualitative impact | "How many users exactly? Dashboard available?" |
| **Weak follow-ups** | No owners/dates | "'Improve monitoring' — what metric, what threshold, who, when?" |
| **No error budget** | Budget impact not quantified | "How much error budget did this consume? Still within SLO?" |
| **Manual mitigation** | Human intervention needed | "Can we automate this into a runbook action or self-healing?" |
| **Single point of failure** | One component took down the path | "Why didn't failover work?" |

### Question Format

```
**Q[N]: [Direct question]**
Context: [1 sentence — why this matters]
Expected answer: [What a good answer looks like]
```

### Always Ask

1. "If this exact failure happens next week, will we detect it faster?"
2. "What's the one change that would have prevented this entirely?"
3. "Which other services have the same pattern and are exposed?"
4. "What's the rollback time right now — is that acceptable?"

### Never Ask

| Bad | Why | Ask Instead |
|-----|-----|-------------|
| "What went well?" | Invites self-congratulation | "What would have made detection 10x faster?" |
| "What did we learn?" | Too vague | "Which follow-up prevents the next occurrence?" |
| "How can we improve?" | Too broad | "Who owns the SLI gap fix and when will it ship?" |
| "Is everyone comfortable?" | Social, not engineering | "Has the fix been verified under same load conditions?" |
| "Should we have escalated sooner?" | Hindsight bias | "What signal would trigger automatic escalation?" |

---

## Retrospective Mode

For framing SEV contributions in PSC and impact discussions.

### IC Role Classification

| Role | Signals | Frame As |
|------|---------|----------|
| **DRI** | "I was oncall/DRI/led response" | Full MTTD/MTTR story; leadership and decision-making |
| **SME** | "I was called in/diagnosed/identified root cause" | Expertise and MTTD reduction; how your knowledge unblocked the team |
| **Mitigation Implementer** | "I wrote the fix/rolled back/deployed" | Execution speed and MTTR reduction |
| **Follow-Up Owner** | "I built monitoring/wrote runbook" | Preventive impact; future SEVs prevented |
| **Preventive** | "My automation caught it/my monitoring alerted" | Proactive engineering; blast radius reduction |

### Quantify Contributions

| Metric | How to Calculate |
|--------|------------------|
| **MTTD reduction** | "Without my [action], detection would have taken X longer" |
| **MTTR reduction** | "My [action] reduced resolution by X" |
| **Blast radius reduction** | "Limited impact to X instead of Y" |
| **Revenue saved** | Duration reduction x hourly cost (see severity table above) |
| **Incidents prevented** | "Follow-up prevents N similar incidents/year" |

Confidence levels: **High** (from SEV timeline/dashboards), **Medium** (extrapolated from similar incidents), **Low** (rough estimate).

### Impact Statement Templates

**DRI:**
```
Led response to [SEV-ID] ([severity], [duration], [users affected]),
coordinating [N] engineers across [N] teams. Identified root cause within
[time] and directed mitigation, reducing MTTR by [hours]
(~$[X] avoided revenue loss, [confidence]).
```

**SME:**
```
Diagnosed root cause of [SEV-ID] ([description]) within [time] of being paged,
unblocking mitigation team. Without domain expertise, estimated MTTD would
have been [X] longer (~$[Y] additional impact, [confidence]).
```

**Follow-Up Owner:**
```
Built [prevention mechanism] after [SEV-ID], preventing [N] similar incidents
in [timeframe] ([confidence], based on [evidence]).
Estimated annual savings: $[X] ([confidence]).
```

For impact quantification anti-patterns (credit without contribution, vague impact, missing baseline), see `career/impact-quantifier.md` and `references/anti-patterns.md`.

---

## See Also

`career/psc.md` (SEV contributions in PSC), `career/slo.md` (error budget), `career/impact-quantifier.md` (quantifying impact), `references/impact-metrics.md`

## SEV Triage Discipline (learned 2026-05-20/23)

1. **Verify model_id before locking in.** Opsmate's literal model_id citation is often wrong. Cross-check via `flow_model_type` + `flow_entitlement` + oncall match against the SEV title family before triaging. (Source: S665454 — Opsmate cited m2129246926, actual was m2124122280.)

2. **Search SEV clusters by shared SLI first, title keyword second.** SLI is the cluster backbone (`mrs_ml/v1_instagram / IGR Trunk Stability`). Title keyword search (`umia`, `timeout`) misses siblings with different wording. (Source: S666322/S666413 — title search missed the sibling.)

3. **Operator paste in agent-feed = canonical RCA.** When a SEV's agent-feed contains an operator-written paste URL, that paste overrides Opsmate's automated analysis. Grep agent-feed for paste URLs before locking in root cause. (Source: S665454 — Opsmate said "bloom_index deadlock", operator paste P2341568201 said "CUDA CachingAllocator SIGABRT + D-state hang".)

4. **Parse ALL affected jobs from first SEV chat message.** SEV escalations often list multiple jobs. Parse the full list and triage as a cluster, not just the first one Opsmate cites. `meta sevmanager.chat list --sev=<num> -l 30 --no-truncate` (Source: S665454 — 3 jobs listed, only 1 triaged.)

5. **Read SEV chat via `meta sevmanager.chat list`.** Works when the bot lacks gchat room membership. Returns SEV-specific chat content as text, bypassing the room-membership requirement. (Source: S661645 — gchat URL inaccessible, CLI worked.)

6. **"Zero in last N" is not a valid staleness check.** Compare gap-since-last-event to the model's historical cadence. "0 FULL_SNAPSHOT in last 30 instances" could mean normal (STUS model that publishes FS every 200 instances) or critical (model with 45-min FS cadence that's been silent 19 hours). Always: `gap / normal_cadence` ratio. Ratio > 2× = investigate. (Source: m2130324780 — "0 FS in last 30" classified as THRESHOLD_MISFIT, was actually a 19.5h publish failure.)

7. **Verify baseline before applying holdout-noise heuristic.** Any "holdout is noisy, ignore" classification is only valid when the corresponding baseline is clean. If baseline is ALSO firing, the signal is shared-infra, not holdout-specific noise. Check baseline state first, then decide. (Source: holdout E2E latency alerts — 36% noisy heuristic applied blindly without baseline check.)

## Common Mistakes

| What happened | Correct approach |
|---|---|
| No second alert found in this scan — likely auto-recovered. Continue monitoring. | No second alert in 24h window. Current CHC rate: [link live Scuba query]. If ... |
| Do NOT restart without clearing ALL 6 channels first — OOM guaranteed. Runboo... | Owner: serving_infra_oncall (Hedwig/publisher layer). Do NOT restart without ... |
