# P-006: Learning Bullets State Insight, Not Topic

**Statement:** A "learning" must state actionable insight in cause→symptom→fix form. Topic headers ("learned about X", "investigated Y") are not learnings — they're table-of-contents entries pretending to be insights.

**Discovered:** 2026-05-17 thread `suPsRC2fGdc` — operator critiquing learning entries that said "investigated training_data_age metric" instead of "training_data_age can't be queried via meta CLI → add Scuba direct query path for this metric."

**Why it matters:** A topic header doesn't compound — re-reading it 3 months later teaches nothing. An actionable insight (cause→symptom→fix) compounds — operator + future-bot can both use it.

**Applies to:** mega-learnings/, weekly synthesis, principles/, retrospectives, knowledge-base entries.

**Current applications:**
- ot-knowledge-curation lint: rejects learnings without cause→symptom→fix structure
- ot-human-attention-brief lint: insight-quality check
- failure-patterns.md: each cluster has Evidence + Hypothesis sections (not just title)

**Anti-patterns it prevents:**
- 2026-05-17 09:53 PT: brief emitted "topic-not-learning" headers (caught + fixed)
- Generic "investigated foo" entries that future-bot can't use to triage

**Related principles:** P-007 (citation discipline — insights need backing evidence), P-002 (shipping requires execution = insights need verification)
