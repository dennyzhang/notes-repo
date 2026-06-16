# Diff Review Cheatsheet

Quick reference for reviewing diffs as a PE Tech Lead. Combines fast signal extraction with PE-specific reliability focus. **Read `diff/common.md` first** for shared Sapling/JF patterns.

## Hard Rule: Maximum 2 Comments Per Diff

An uber TL focuses on the most critical improvements and ignores the rest. Others (AI, peers, CI) can catch the minor issues. If you have more than 2 things to say, rank them and drop everything below #2.

**Why 2:** Fewer comments = each one carries more weight. 5 comments dilutes your signal. 1-2 comments says "this is what actually matters." This is the pull-not-push principle applied to code review.

**Exception:** Only exceed 2 if the diff has a fundamental design problem that requires explaining the alternative — and even then, that's 1 comment with context, not 5 scattered ones.

## Reviewer Psychology (Source: Google "How to do code reviews")

**Your goal is to get the code improved, not to prove you're smart.**

| Principle | What it means in practice |
|-----------|--------------------------|
| **Be kind** | "Have you considered X?" not "This is wrong." The author spent hours on this. |
| **Explain why** | "This could cause a race condition because..." not just "Use a lock here." |
| **Offer alternatives** | "One approach: X. Another: Y. What do you think?" not "Do X." |
| **Distinguish severity** | Prefix with `nit:` (take or leave), `suggestion:` (consider), or no prefix (must fix) |
| **Approve with comments** | If comments are minor, accept the diff and note "LGTM with nits." Don't block on style. |

**The 24-hour rule**: Respond to review requests within 1 business day. A blocked diff costs more than an imperfect review.

### Comment Type Prefixes (Source: Google eng-practices + Graphite)

| Prefix | Meaning | Blocking? |
|--------|---------|-----------|
| (no prefix) | Required change — must fix before landing | Yes |
| `nit:` | Style/preference, non-blocking | No |
| `suggestion:` | Optional improvement idea | No |
| `question:` | Genuine question for understanding | No |
| `blocking:` | Hard block — must fix | Yes |

**The "net improvement" standard**: Approve if the diff improves overall code health, even if it isn't perfect. Don't block on personal style preferences not in the style guide.

## Abstraction-Level Evaluation (AI-Generated or Large Changes)

When reviewing AI-generated changes or any diff touching 3+ files, evaluate at three abstraction levels instead of reading every line. This maps to the Layered Change Summary Protocol — if the diff includes a structured summary, use it as the entry point.

| Level | What to Evaluate | Time | Skip When |
|-------|-----------------|------|-----------|
| **1 - Intent** | Does the 1-sentence summary match the original request? Is the "why" clear? | 5 sec | Never skip |
| **2 - Design** | Are the key decisions sound? Were alternatives considered? Do tradeoffs make sense for our context? | 30 sec | Low-scope, single-file changes |
| **3 - Risk** | Are risk annotations accurate? Is blast radius correctly scoped? Do spot-check recommendations match your intuition? | 1-2 min | Low-risk only (new files, docs, config) |

**Review protocol:**
1. Read Level 1 always — if intent is wrong, stop and redirect before reviewing code
2. Read Level 2 for medium+ scope — challenge design decisions, not implementation details
3. Drill into Level 3 only for medium/high risk — verify the AI's risk assessment matches yours
4. Skip implementation details unless risk annotation flags them or your gut says something's off

**Trust calibration:** Track whether summaries are accurate over time. After 20+ reviews, reduce depth in domains where AI summaries are consistently reliable. Increase depth where they've missed things.

## The 3-Minute Review Framework

Most diffs need one key comment, not ten. Find it fast.

### Step 1: Understand the Intent (30 seconds)

Before reading any code, answer one question: **what is this diff trying to accomplish and why?**

1. **Title + Summary** — what problem is being solved? What's the motivation?
2. **Stack position** — is this part of a stack? Read earlier diff summaries for context.
3. **Linked task or SEV** — is there a backstory that explains constraints or urgency?

**Start every review with a 1-2 sentence plain-language explanation of the diff's purpose.** This forces understanding before critique, and gives the author a chance to correct misunderstanding early. Example: "This diff adds a guided test workflow so model owners can verify OT setup before going to production."

If you can't state the intent in one sentence after reading the summary, that's your first comment: "The summary doesn't explain why this change is needed."

### Step 1.5: Scope Drift Detection (15 seconds)

Compare what was requested (linked task, PR description, commit messages, stack context) against what the diff actually delivers. Flag before the main review:
- **Out-of-scope additions** — changes that aren't part of the stated goal (opportunistic refactors, unrelated fixes bundled in)
- **Missing requirements** — the stated intent implies work that isn't in the diff
- **Scope mismatch** — the diff solves a different problem than what was asked

If scope drift is found, that's your first comment — everything else is secondary until scope is right.

### Step 2: Orient (30 seconds)

1. **Affected files** — scope and blast radius
2. **Test plan** — does the author believe this works?
3. **CI signals** — is anything already broken?

### Step 3: Find the Key Thing (2 minutes)

Ask these questions in priority order. Stop at the first "yes":

| Priority | Question | What to look for |
|----------|----------|------------------|
| P0 | **Is it correct?** | Logic errors, off-by-one, wrong assumptions, missing edge cases |
| P1 | **Is it safe?** | Silent failures, missing validation at boundaries, unary embedding SEV-style risks |
| P2 | **Does it achieve the stated intent?** | Partial solution, missing cases the intent implies, over/under-scoped |

Most review value comes from P0-P1. Everything else is noise unless P0-P1 are clean.

### Step 4: Write 1-2 Comments Max (30 seconds)

**[What's wrong] + [Why it matters] + [Concrete fix]** — all three in 1-2 sentences per comment. No preamble, no "I think maybe." If you found multiple issues in Step 3, rank them and keep only the top 2. The "Dropped" section in your review note trains your judgment on what truly matters.

## PE Review Dimensions (Deep Review)

For thorough reviews (large diffs, high-risk changes), evaluate across these tiers:

### Tier 1: Must Review (Blocking)

| Dimension | What to Check | PE-Specific Focus |
|-----------|---------------|-------------------|
| **Reliability** | Error handling, failure modes, retry logic, circuit breakers | Will this break at 3 AM? Can oncall mitigate without the author? |
| **Safety** | Rollback plan, feature flags, canary strategy, blast radius | Can it be rolled back in <5 min? |
| **Correctness** | Logic errors, edge cases, race conditions, data consistency | Does it handle partial failures in distributed systems? |
| **Security** | Input validation, auth checks, PII handling | DSS compliance, ACL checks |

### Tier 2: Should Review (Important)

| Dimension | What to Check | PE-Specific Focus |
|-----------|---------------|-------------------|
| **Observability** | Logging, metrics, alerting | Can we detect if this breaks? Are SLIs covered? |
| **Performance** | Latency impact, resource usage, caching | P99 impact at scale? |
| **Operability** | Runbook updates, oncall impact | Does oncall need new knowledge? |
| **Testing** | Coverage, edge cases, integration tests | Are failure scenarios tested, not just happy paths? |

### Tier 3: Skip by Default

Code quality, naming, formatting, documentation — skip unless explicitly asked. If a design issue causes reliability or performance problems, it belongs in Tier 1/2.

### Depth by Diff Size

| Size | Lines / Files | Default Depth |
|------|---------------|---------------|
| Small | < 50 lines, 1-2 files | Quick (Tier 1 only) |
| Medium | 50-300 lines, 2-5 files | Standard (Tier 1+2) |
| Large | 300+ lines or 5+ files | Thorough (all tiers) |

## Test Plan Validation

High-signal check most reviewers skip.

| Question | Red Flag |
|----------|----------|
| Does the test plan exist? | Empty, "TODO", or "manual testing" for non-trivial changes |
| Does it test what changed? | Test targets don't touch modified code paths |
| Are failure scenarios covered? | Only happy-path tests, no error/edge cases |
| Are new code paths tested? | New functions added but no corresponding test |

Output a one-line assessment: **Covers changes** / **Partial** (with gap) / **Insufficient** (with what's missing) / **Missing**.

## What Not to Comment On

Your time as a reviewer is expensive. Spend it on things only a human can catch.

**Leave these to AI and automation:**
- Variable/function naming that's "okay but could be better"
- Import ordering, formatting, whitespace
- Missing docstrings or type annotations on unchanged code
- "You could simplify this with a list comprehension"
- Suggesting a helper function for a one-time operation
- Anything `arc lint` or `arc pyre` would catch

**Only comment when:**
- The diff would break something or cause a SEV (correctness, safety)
- The diff doesn't achieve its stated intent
- The approach has a fundamental flaw (wrong abstraction, race condition)
- There's a pattern that will cause pain in 3 months

**The test:** "Would I mass-page someone at 2 AM over this?" If no, consider whether it's worth the author's time.

## What to Check by Diff Type

### Feature Addition
- Does the new code follow existing patterns in the file?
- Is the new abstraction justified (used more than once)?
- Are tests covering the happy path AND the failure path?

### Bug Fix
- Does the fix address the root cause or just the symptom?
- Is there a regression test that would have caught the original bug?
- Could this same class of bug exist elsewhere? Check for similar patterns.
- Was the failure reproduced in a controlled way before the fix was applied? (reproduce-before-fix pattern)

### Refactoring
- Zero behavior change? Check for materialized/generated output diffs
- Are collection types preserved (set vs list)?

### Config Change
- Does `arc build` / compilation pass?
- Are defaults sensible and consistent with neighboring configs?

### Safety-Sensitive Change (ACLs, Rate Limits, Logging, Privacy)
- Is the change behind a GK or feature flag for rollback?
- For ACL changes: who gains or loses access?
- For rate limit changes: what's the current traffic volume?
- For logging changes: is any PII being added to logs?

### Stacked Diffs
- Review each diff in order — later diffs may depend on earlier assumptions
- Check that each diff is independently safe to land (what if the stack lands partially?)
- Watch for state that "leaks" across diffs

### Test Addition
- Do the tests actually assert something meaningful?
- Is there a test for the failure case, not just the happy path?

## Writing Comments

**[What's wrong] + [Why it matters] + [Concrete fix]** — all three in 1-2 sentences.

### Good Examples

> `verify_metrics` is already 120 lines (longest method in the file by 2x). Adding 45 lines inline pushes it to ~165. Consider extracting to `_verify_cross_step_metrics` — same pattern as `_verify_with_baseline`.

> The `description` field has metadata that belongs in the body only. `NE Impact...Trade-offs none.` is appended to the description but already documented in lines 12-15. Remove it from `description`, keep the body as-is.

### Bad Examples
- "Nit: maybe rename this?" — no reason given
- "Can we add more tests?" — which tests, for what?
- "Consider using X instead of Y" — unless Y causes a real problem
- Any comment that starts with "Nit:" — if it's truly a nit, don't post it

## Structured Review Output

When producing a formal review (max 2 comments — rank and cut):

```
## TL Review: D[number]

**Purpose:** [1-2 sentence plain-language explanation of what the diff does and why]

[One sentence: ship it / needs changes / needs redesign — and why]

- **Oncall impact:** [None / needs runbook / needs training]
- **Rollback:** [OK / missing / insufficient]
- **Test plan:** [Covers changes / Partial / Insufficient / Missing]

### Comment 1 (most critical)
- `file.py:42` — [what's wrong] + [why it matters] + [concrete fix]

### Comment 2 (if needed)
- `handler.py:88` — [what's wrong] + [why it matters] + [concrete fix]

### Dropped (not worth commenting on)
[List items you considered but ranked below the top 2 — this trains your judgment]
```

## Reviewing Diffs from Reports and Mentees

Reviewing a report's diff is coaching, not just gatekeeping.

- **Lead with the most important lesson**, not every issue. One teaching moment per review sticks; five overwhelm.
- **Name the pattern, not just the instance.** "This is the Null Object pattern — here's when to use it."
- **Distinguish blocking from coaching.** Mark must-fix items clearly. Prefix growth comments with "Non-blocking:".
- **Point to existing code as examples.** "See how `FooProcessor` handles this same case in line 45."
- **Track repeated patterns.** If you've flagged the same issue three times, it's a 1:1 topic, not a diff comment.

### Coaching Calibration by Author Level

| Author Level | Review Style |
|--------------|--------------|
| **IC3** | Detailed explanations, link to docs, suggest patterns. "Here's why this matters..." |
| **IC4** | Point to the issue, suggest the fix, brief rationale. "Consider X because Y" |
| **IC5** | Flag the concern, trust them to fix. "This needs retry logic — you know the pattern" |
| **IC6+** | Peer discussion. "Have you considered X? I'd lean toward Y because Z" |

## Using AI for Review

### What AI Is Good At
- Reading the full file for context the diff doesn't show
- Checking CI signals and lint failures
- Cross-referencing affected files for consistency
- Drafting comments once you know what to say

### What AI Is Bad At
- Judging whether a design decision is right for the team's context
- Knowing which risks are real vs theoretical
- Prioritizing — AI will give you 7 comments when you need 1

**Never let AI post the comment directly.** You review, you edit, you own it.

## Patterns That Signal Problems

| Pattern | Why It Matters |
|---------|---------------|
| No error handling on RPC calls | Cascading failures |
| Hardcoded timeouts | Won't adapt to varying load |
| Missing metrics/logging on new code paths | Invisible failures in production |
| No test for failure scenarios | Only happy path validated |
| Config changes without rollback plan | Stuck if it breaks |
| Database schema changes without migration plan | Data loss risk |
| Missing rate limiting on new endpoints | DoS vulnerability |
| Synchronous calls in hot paths | Latency bomb at scale |
| The method grew again | Flag with line count — concrete numbers convince |
| Commented-out code with active imports | Signals incomplete work, lint failures |
| Same data in two places | Always drifts — flag early |
| Silent fallback (returns None, swallows exceptions) | Hardest bugs to debug |
| Asymmetric error handling | One branch validates, the other doesn't |
| Schema/enum definition ≠ usage sites | Defined `A|B|C` but code uses `D` too — grep all references |
| Safety claim contradicts implementation | Says "read-only" but step N writes — reviewers catch this fast |

## Security Review Checklist

Check these on every diff that touches code paths handling user input, auth, data access, or external calls. Skip for pure config/doc diffs.

| Category | What to Look For | Severity |
|----------|-----------------|----------|
| **Credential exposure** | API keys, tokens, passwords, private keys hardcoded or logged. Secrets must use Meta Keychain or env vars, never config files or source. | P0 |
| **SQL injection** | Unparameterized queries, string concatenation building SQL. Must use parameterized queries or ORM. | P0 |
| **Command injection** | User input passed to shell commands, `eval()`, `exec()`, `subprocess` without sanitization. | P0 |
| **XSS** | Unescaped HTML output, `dangerouslySetInnerHTML`, user content rendered without sanitization. | P1 |
| **Path traversal** | User input used in file paths without validation (e.g., `../../../etc/passwd`). | P1 |
| **Auth/authorization bypass** | Missing auth checks on new endpoints, privilege escalation, role checks skipped in error paths. | P0 |
| **Unsafe deserialization** | `pickle.loads()`, `yaml.load()` without SafeLoader, untrusted `JSON.parse` feeding code execution. | P1 |

## Privacy Review Checklist

Check on any diff that handles user data, logging, or cross-service data flows. Meta-specific concerns.

| Category | What to Look For | Severity |
|----------|-----------------|----------|
| **PII in logs/errors** | User IDs, names, emails, IPs, or device IDs written to logs, error messages, or Scuba tables. | P1 |
| **Missing Ent privacy policy** | New Ent types without a privacy policy — all Ent objects must have privacy rules. | P0 |
| **Viewer Context bypass** | Data access without checking viewer permissions. Must use `ViewerContext` or equivalent. | P1 |
| **Cross-app data aggregation** | Combining data across apps (FB, IG, WA) without explicit consent or purpose limitation. | P0 |
| **Missing data retention** | New data stores without TTL or deletion policy. | P1 |
| **Minor/teen protections** | Features that may expose minors' data differently than adults'. | P0 |

These checklists are modeled after Jubin Chheda's Deep Review Agent (`fbcode/claude-templates/components/skills/deep-review-agent/`) which automates security (7 categories) and privacy (16 categories) analysis at scale. The lists above cover the subset relevant to PE/infra diffs.

## Review Cadence for Tech Leads

| When | What |
|------|------|
| Daily | Skim new diffs from your team — 1 min each, comment only if P0-P1 |
| Twice weekly | Deep review on 1-2 significant diffs — read full files, check patterns |
| Weekly | Check for stale diffs (>5 days no activity) — nudge or unblock |
| On-call week | Tighter review on anything touching production paths, configs, or safety knobs |
| After a SEV | Review all related diffs with fresh eyes — did the review process miss something? |
| Quarterly | Look at your review patterns — same issue recurring? That's a team training gap |

## See Also

`diff/common.md` (shared diff patterns), `oncall/design-review.md` (design doc review), `career/level-expectations.md`, `diff/fbcode-conventions.md`

_Last updated: 2026-05-14. Maintainer: dennyzhang._
