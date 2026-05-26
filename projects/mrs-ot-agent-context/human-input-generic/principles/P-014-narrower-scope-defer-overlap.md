# P-014: Narrower scope wins — defer overlapping work to the cron designed for it

**Statement:** When you're about to ship N categories of output, ask: does some existing cron already handle K of them? Defer those K; ship only the (N-K) that's net-new. Two crons producing overlapping content = operator noise + maintenance burden + duplicate-numbering bugs.

**Discovered:** 2026-05-17 thread `Uc-pVBEXNQ8` ("attack and improve it" — operator caught that step 10 of ot-daily-learning-mitigated-alerts was duplicating ot-knowledge-curation work)

**Why it matters:**
- Two crons proposing overlapping artifacts produces duplicate IDs (today: P56 collision across knowledge-curation + daily-learning-debugging + manual landing)
- Operator sees the same insight twice from different angles, can't tell which is canonical
- Each duplicate adds bytes to the operator's daily skim budget
- Maintenance: when the underlying logic changes, you have to update N places instead of 1

**Applies to:** generalizable-to-any-agent-system (any system with multiple crons / multiple producers feeding the same operator)

**Current applications:**
- `ot-daily-learning-mitigated-alerts.md` step 10: originally 4 categories (a/b/c/d). Reduced to 2 (a/b only) — (c) "follow-up tasks for new recurring patterns" and (d) "suggested diffs" deferred to `ot-knowledge-curation` (designed for cross-incident pattern detection).
- `ot-postmortem-validator.md`: scope explicitly limited to validating digests; doesn't auto-fix or auto-propose (those are `ot-knowledge-curation`'s job)
- `ot-human-attention-brief.md`: aggregates existing cron outputs; doesn't re-derive triages or re-propose patterns

**Anti-patterns it prevents:**
- 2026-05-17 morning: ot-daily-learning-debugging proposed P56/P57/P58 same day ot-knowledge-curation proposed conflicting P56/P57/P58. THREE-WAY collision (cron A + cron B + manual land). Caused operator-visible numbering confusion (suPsRC2fGdc thread).
- 2026-05-17 10:22 PT: I shipped step 10 with 4 categories without checking ot-knowledge-curation already handled 2 of them. Operator caught at 10:25 PT.

**Decision rubric**

Before adding output category X to cron Y:
1. Is X already produced by some OTHER cron Z?
2. If yes, does Z's coverage of X subset what you want, or are there gaps Z misses?
3. If Z covers it fully → DON'T add to Y. Reference Z in Y's prompt for discoverability.
4. If Z has gaps → add JUST the gap to Y, not the full category. Cross-reference Z.
5. If no Z handles it → safe to add to Y.

Common overlap-prone categories in agent systems:
- Pattern proposals (P-row / R-rule drafts)
- Diff drafts
- Task creation suggestions  
- Cross-incident learnings
- Status updates to a registry

These tend to land in 2-3 crons each unless explicitly scoped.

**Related principles:** P-006 (insight vs topic — narrow what's actually new), P-002 (shipping requires execution — overlap is often surfaced only at first live fire), P-009 (validator coverage — overlapping crons multiply the validator-checklist surface area)
