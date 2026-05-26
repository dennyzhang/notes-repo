# P-008: History Repeats — Check Recurrence Before Re-Deriving

**Statement:** Before generating a fresh hypothesis for any incident, check (a) same-workload recurrence in last 30d (R20), (b) cross-workload pattern in last 24h on the model family (R21). Most "novel" incidents are repeats with prior triage already on file.

**Discovered:** 2026-05-17 thread `r70kC-3eghA` — operator noticing bot re-deriving hypotheses for incidents that already had cluster citations.

**Why it matters:** The bot maintains 18 failure clusters + 54 P-rows + N archives. Skipping these on triage = wasting operator's time + producing inferior analysis (the prior triages have evidence the current triage lacks).

**Applies to:** any agent doing root-cause analysis where prior incidents are queryable.

**Current applications:**
- R20 same-workload recurrence (3 monitor crons + per-incident archives)
- R20 local-archive sweep (mitigated-sevs/posts/alerts + mega-learnings) — added 2026-05-17 11:10/11:18 PT
- R21 cross-workload sibling check (model family + paired baseline/holdout variants)
- R22 AGG sub-alert expansion (for aggregation alerts)
- failure-patterns.md "Evidence" list per cluster

**Anti-patterns it prevents:**
- Re-triaging A1480 from scratch when CL-013 evidence already cites it
- Generating P-row "candidates" when prior matched P-row is in archive
- Operator having to remind bot "this is the 3rd time this week"

**Related principles:** P-007 (citation discipline), P-014 (defer overlap to designed cron)
