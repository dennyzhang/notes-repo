# P-012: "Mitigated" ≠ "Routed". Source Stoppage Required for Mitigation Status.

**Statement:** 🟢 "mitigated" status requires the source pattern to have stopped recurring. Bot routing/categorization improvements alone = 🔵 "routed" status, not mitigation. Don't conflate "bot now knows about it" with "the underlying defect stopped."

**Discovered:** 2026-05-16 thread `ZP2y-6Bdpwk` — operator distinguishing structural-knowledge improvements from underlying-defect-fix when reviewing CL status.

**Why it matters:** Conflating routing-fix with source-fix produces false sense of progress. "We mitigated 14 things" when actually "we routed 14 things and 0 source patterns stopped" misleads leadership + the team.

**Applies to:** any cluster-tracking / status-rollup system where multiple kinds of progress exist.

**Current applications:**
- failure-patterns.md status enum: 🔴 active / 🟡 partial / 🟢 mitigated / 🔵 routed
- CL-018 reclassification 🟡→🔵 after R22 sub-alert expansion (bot can now triage, source unfixed)
- CL-017 marked 🔴 active despite 4 archived events (source = Shampoo NaN cascade, ongoing)

**Anti-patterns it prevents:**
- Marking CL-NNN green because bot now triages well (source still recurring)
- Leadership rollups showing "all clusters mitigated" when only routing improved

**Related principles:** P-013 (leadership asks need ownership), P-007 (citation discipline applies to status claims too)
