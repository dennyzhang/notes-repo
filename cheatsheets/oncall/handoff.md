# Oncall Handoff Cheatsheet

## Good vs Bad Handoff Examples

| Good | Bad |
|------|-----|
| "Model 2137626899 staleness alert fired 3x but auto-recovered. Watch for a 4th — if it recurs, check CHC rate in Scuba." | "Some alerts fired, seemed fine." |
| "D98260667 landed yesterday — Package Archiver now retries on BLOB_NOT_FOUND. Monitor for new failure modes." | "Shipped a diff." |
| "Quiet shift, no action needed." | (No handoff written at all) |

## ML Infra-Specific Handoff Items

Always include in the handoff for ML training oncall:

| Item | What to check | Where to find it |
|------|--------------|-----------------|
| **Model staleness** | Any models near or past SLA? | Hawkeye Model Health Hub |
| **Training failures** | Recurring job failures this shift? | MAST job dashboard, `meta ai.mast-job` |
| **Active MRBs** | Any Massive Revert Bans in effect? | SEV Manager |
| **Data pipeline** | Any upstream data delays or blockouts? | Hive partition dashboard |
| **Package pushes** | Any scheduled or recent package deployments? | Conveyor |
| **Open SEV follow-ups** | Any unfixed SEV action items due this week? | SEV tracker tasks |

## Open Discussion Points (rotate forward each shift)

These are recurring process gaps worth raising at handoff or staff. The outgoing oncall flags them; the incoming one decides whether to act this week.

| Topic | Question | Why it matters |
|---|---|---|
| **Cross-team escalation SLA** | When triage points root cause to another team's subsystem (DPP, Warm Storage, NCCL, model_processing, model_store, Manifold, Hedwig, Scribe), our 1d support SLA still applies — but we're now waiting on another oncall. **How do we ensure they take prompt action?** Options to weigh: GChat tag (cheapest, no SLA), SEV4 file (built-in tracking + escalation, paged if breached), task assignment (slowest), partner-team oncall page (most direct). Paul's 2026-04-27 pattern: file SEV4 while still working the issue. **Concrete recent case (2026-04-27, model 2127366584):** triage surfaced Warm Storage Freeproxy quota -> owned by `dpp_distributed_systems`. We tagged in GChat; no formal accountability mechanism for their response time. Was our 1d SLA met? | Without an explicit cross-team protocol, every escalation depends on the personal relationship between oncalls. Slow partner-team responses silently turn into our SLA breaches. |

When closing this row in a future shift, move the resolution into `customer-support.md` or `mast-debugging.md` as a permanent rule.

## See Also

`oncall/sev.md` (when an issue escalates to SEV), `oncall/assessment.md` (oncall health assessment), `oncall/mast-debugging.md` (debugging training failures)
