# User Journeys — Incident-Derived

What matters most to users, learned from how incidents are escalated, triaged, and resolved.
Not a static list — the bot updates this as it processes more incidents.

---

## Schema

```
- id: UJ-NNN
  journey: <what the user experiences>
  why_it_matters: <business impact when degraded>
  signals_that_reveal_priority:
    sev_count: <S0/S1/S2 incidents traced to this journey>
    alert_count: <total alerts traced to this journey>
    escalation_velocity: <avg time from alert to human attention>
    recovery_urgency: <off-hours fix vs next-morning>
    oncall_time_spent: <relative % of oncall cycles>
  incident_refs: [<CL-NNN, SEV-NNN, thread refs>]
  confidence: <confirmed|inferred|proposed>
  discovered: <date>
  last_updated: <date>
```

**How journeys get discovered:**
- An incident draws disproportionate escalation attention → ask "what user-visible thing was at risk?"
- Multiple CL-NNN clusters share the same user-visible consequence → group under one journey
- A SEV postmortem names the user impact explicitly → extract and codify
- An alert fires with no clear user impact → evidence that the alert may be noise, not a journey

**How journeys get ranked:**
- Primary: SEV severity distribution (S0/S1 = top priority)
- Secondary: escalation velocity (fast = high priority)
- Tertiary: recurrence frequency (chronic = systemic)
- Tiebreaker: oncall time spent (high = high cost even if not severe)

---

## Active Journeys (ranked by incident-derived priority)

### UJ-001: Model Freshness → Ranking Quality Degradation

- why_it_matters: Stale models serve outdated ranking signals. Users see irrelevant content. Engagement metrics drop.
- signals_that_reveal_priority:
  - sev_count: High — model staleness is the #1 trigger for OT SEVs (estimate, needs SEV query validation)
  - alert_count: CL-013 (training example age) ranked #1 by recurrence (4/4 weeks, from failure-patterns INDEX)
  - escalation_velocity: Fast — ATS alerts get immediate oncall attention (estimate)
  - recovery_urgency: Off-hours fixes common (estimate)
  - oncall_time_spent: ~40% of OT oncall cycles (estimate, needs oncall rotation data)
- incident_refs: [CL-013, IG OT SLO Dashboard freshness axis]
- related_metrics: [KM-T1, KM-T2, KM-S1, KM-F1, KM-F2, KM-F3]
- confidence: confirmed
- discovered: 2026-05-26
- last_updated: 2026-05-26
- notes: Most incidents that escalate to SEV trace back to "model stopped updating" in some form — trainer crash, DPP starvation, publisher stuck, checkpoint corruption. Different root causes, same user journey.

### UJ-002: Model Availability → Serving Fallback to Stale

- why_it_matters: When no snapshot is available, serving falls back to an older model version. If stale long enough, quality degrades silently without an obvious breakage signal.
- signals_that_reveal_priority:
  - sev_count: Moderate — usually caught before full outage
  - alert_count: CL-001 (snapshot stuck CREATING) ranked #2 by recurrence (13+ alerts/4wk)
  - escalation_velocity: Medium — often masked by delta streaming continuing
  - recovery_urgency: Same-day but not always off-hours
  - oncall_time_spent: ~25% of OT oncall cycles
- incident_refs: [CL-001, facebook_reels_ifu_i2i 2132070936 investigation 2026-05-23]
- related_metrics: [KM-P1, KM-D1, KM-CK1, KM-PKG1]
- confidence: confirmed
- discovered: 2026-05-26
- last_updated: 2026-05-26
- notes: The 2026-05-23 investigation revealed a subtlety — stream publishes (every ~2 min) can mask a full snapshot outage for hours. The model "looks alive" in gmpp but the full fused snapshot hasn't updated. User impact depends on how much the full snapshot matters vs incremental updates for that model type.

### UJ-003: Silent Quality Drift → No Alert But Model Wrong

- why_it_matters: Model trains on bad data, produces NaN metrics, or resumes from a corrupted checkpoint. No alert fires because the job is "running" — but the model is serving garbage.
- signals_that_reveal_priority:
  - sev_count: Low frequency but highest severity when it hits (S0/S1 — revert-and-ban)
  - alert_count: Low — the whole problem is that alerts DON'T fire
  - escalation_velocity: Slow — often discovered hours/days later by product teams
  - recovery_urgency: Immediate once discovered (revert-and-ban)
  - oncall_time_spent: ~10% of cycles but ~50% of S0 time
- incident_refs: [NaN cascades, revert-and-ban procedures in triage.md]
- related_metrics: [KM-Q1 (NE), KM-Q2 (loss/NaN), KM-T2 (QPS as proxy)]
- confidence: inferred
- discovered: 2026-05-26
- last_updated: 2026-05-26
- notes: Hardest journey to monitor because "running but wrong" has no single metric. Best proxy signals: NE regression, loss NaN, metric validation errors. The reranker zombie (2125081901, 6 days idle with isActive=false) is a variant — job running, zero output, no alert.

### UJ-004: Infra Cost Waste → GPUs Consumed Without Output

- why_it_matters: Zombie jobs, crash-looping jobs, and stuck jobs consume GPU allocation without producing model updates. Direct cost waste + opportunity cost (other jobs can't schedule).
- signals_that_reveal_priority:
  - sev_count: Rarely becomes a SEV (no user-visible symptom)
  - alert_count: CL-012 (StuckJobDetector gaps) — ~512 GPU-hr/mo waste estimated
  - escalation_velocity: Very slow — often discovered during audits, not alerts
  - recovery_urgency: Low — next-day or weekly cleanup
  - oncall_time_spent: ~5% of cycles
- incident_refs: [CL-012, reranker 2125081901 zombie (6 days × 8 A100 = 1,152 GPU-hr wasted)]
- related_metrics: [KM-P4 (Hedwig activity), KM-TMS2 (restart count), KM-PKG1 (package expiry), KM-SYNC1 (TMS/MAST orphan), KM-SYNC2 (swallowed exception crash-loop)]
- confidence: inferred
- discovered: 2026-05-26
- last_updated: 2026-05-26
- notes: Lower priority than freshness/availability from user perspective, but high cost. The reranker zombie is a concrete example — SJD has no "progress liveness" check, so alive-but-idle jobs persist indefinitely.

---

## Proposed Journeys (need more incident evidence)

### UJ-P1: Upstream Cascade → Multiple Models Affected Simultaneously

- why_it_matters: A single infra failure (DPP outage, Scribe lag, Manifold issue) can degrade many OT models at once, causing fleet-wide staleness.
- evidence_so_far: CL-003 (downstream infra cascade, ~1/week). Root model 2125081911 DPP connection errors affected the entire I2I dependency chain.
- needs: 3+ more incidents to confirm this as a distinct journey vs a variant of UJ-001.
- confidence: proposed
- discovered: 2026-05-26

### UJ-P2: Model Onboarding Failure → New Model Never Reaches Prod Quality

- why_it_matters: New OT models fail during onboarding (config errors, streaming not wired, TMS not registered) and silently never reach expected freshness.
- evidence_so_far: CL-009 (auto-start silent stall). Breathalyzer auto-deallocation of QE arms.
- needs: More onboarding incident data.
- confidence: proposed
- discovered: 2026-05-26

---

## Discovery Protocol

When processing any incident, the bot should ask:

1. **What user-visible thing was at risk?** Map to an existing UJ-NNN or propose a new one.
2. **How fast did humans react?** Record escalation velocity.
3. **What severity was assigned?** S0/S1 = high journey priority.
4. **Was the fix off-hours or next-morning?** Off-hours = high recovery urgency.
5. **Did an existing alert catch it, or was it discovered ad-hoc?** Ad-hoc = monitoring gap for this journey.

After every 10 incidents processed, re-rank the journey list by the signals above.

---

## Evolution Log

| Date | Change | Trigger |
|---|---|---|
| 2026-05-26 | Seeded UJ-001 through UJ-004 from flywheel patterns + 2026-05-23 triage session | Initial creation |
| 2026-05-26 | Proposed UJ-P1, UJ-P2 from CL-003 and CL-009 patterns | Pattern review |
