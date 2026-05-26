# P-011: Spec Without Lint = Unenforced. Lint Without Coverage = Unenforced Anyway.

**Statement:** A spec rule needs a lint check that fires for non-compliance. A lint check needs to cover the actual cron execution path. Both gaps must close or the spec is decorative.

**Discovered:** 2026-05-17 thread `Y3qbdh2hC20` — discovered R20 rule existed in spec but cron emitted output that violated R20 because no lint enforced it on the output side. Spec → execution path → lint check is a 3-step chain.

**Why it matters:** Specs accumulate as commit-message intentions. Without lint enforcement, the next agent edit can silently drift. Without coverage, lint passes vacuously. Both gaps look like "we have a spec for that" but produce no behavior change.

**Applies to:** any agent system with durable specs.

**Current applications:**
- CONTENT lint enforces R20/R21/CL-NNN/P-row citations across 3 monitor crons
- ot-prompt-change-validator runs sub-agent simulation to catch lint-not-firing on real outputs
- ot-postmortem-validator coverage extended to ot-knowledge-curation (was missing)
- FALSIFIER-RESPECT lint added after operator caught P58 cite without falsifier check

**Anti-patterns it prevents:**
- 2026-05-17 09:23 PT: CL/P citation rule existed; lint didn't enforce → output lacked citations
- 2026-05-17 11:02 PT: FALSIFIER-RESPECT in spec; no lint → P58 cited despite no active ZippyDB SEV
- 2026-05-17 09:53 PT: insight-quality rule existed; brief lint didn't cover it

**Related principles:** P-002 (shipping requires execution), P-007 (citation discipline), P-009 (validator coverage asymptotic)
