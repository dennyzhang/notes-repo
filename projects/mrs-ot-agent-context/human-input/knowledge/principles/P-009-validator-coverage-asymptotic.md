# P-009: Validators are only as good as their checklist — asymptotic convergence to operator standards

**Statement:** Each operator catch = +1 check category in the validator. Coverage grows incrementally; the target isn't zero human involvement but asymptotic convergence to the operator's tacit standards. Don't claim a validator is "comprehensive" — claim it covers N specific checks, and that N grows from operator catches.

**Discovered:** 2026-05-17 thread `suPsRC2fGdc` (validator PASSED a brief that had URL 404s + topic-not-learning bullets; operator caught both)

**Why it matters:**
- The validator I built at 09:39 PT to catch silent failures shipped with insufficient checks and missed the first instance immediately
- Operator → validator → operator → me loop is structural: operator has tacit standards, agent codifies them, codification has gaps, operator catches gap, loop continues
- Treating validator as "done" creates false confidence; treating it as "always growing" matches reality
- Each operator catch becomes structural prevention IF you actually add the check; otherwise you keep paying the cost

**Applies to:** generalizable-to-any-agent-system (any system where an LLM + validation pipeline serves a human operator)

**Current applications:**
- `ot-prompt-change-validator.md` subagent checklist grew today:
  - Initial (09:39 PT): structural lint regex, mandatory citations, markdown syntax
  - +4h: URL well-formedness (chat/workplace/sevmanager/onedetection), learning-bullet insight-quality
  - +6h: 6 check categories total
- Each addition cites the operator-catch that surfaced the gap

**Anti-patterns it prevents:**
- Claiming "shipped" on a validator that hasn't been tested against the operator's actual standards
- Treating each new operator catch as a one-off bug instead of as evidence the validator coverage is incomplete
- Shipping a validator and then NEVER extending it (the original sin)
- Building a validator without including "checklist version + last-extended date" so coverage drift is visible

**Coverage extension pattern**

When operator catches something validator missed:
1. **Pin the catch** — what's the failure shape? what would a check look like?
2. **Codify the check** — add subagent prompt rule + grep/regex/structural test
3. **Backfill anti-regression** — re-run validator against the failure-case; verify it now catches
4. **Document the lineage** — cite operator thread + date in the check itself

**Asymmetry to manage**

Operator catches what validator misses because:
- Operator clicks URLs (validator only regex-matches structure)
- Operator reads for actionable insight (validator only checks markers)
- Operator notices "this looks like a stub" (validator only counts bytes)
- Operator integrates across artifacts (validator scopes per-artifact)

The asymmetry is fundamental — operator has tacit standards; codification approximates them. Convergence is asymptotic, not zero.

**Cron-rate visible coverage check**

Validator's own state file should expose: `{checks_total: N, checks_added_last_30d: M, operator_catches_caught: K, operator_catches_missed: L}`. If L > 0, validator is behind; extend.

**Related principles:** P-002 (shipping requires execution — same root: spec without verification is unenforced), P-007 (citation discipline — validator is one form of enforcement; not the only one), P-003 (generalize to system rule — operator's "generic feedback" usually = validator-coverage gap)
