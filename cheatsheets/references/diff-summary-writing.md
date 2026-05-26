# Diff Summary Writing Guide

Extracted from `cheatsheets/diff/common.md`. Full guide for writing diff summaries that lead with why.

## Why-First Extraction

Before writing, answer 3 questions:
1. **What gap or risk does this diff close?**
2. **What would happen if this diff didn't land?**
3. **What's the first question a reviewer will ask?** Pre-answer it.

## Diff Type Detection

| Diff Type | Detection | Lead With |
|-----------|-----------|-----------|
| Test diff | `test_` prefix, `_test.py` suffix | What gap this test closes |
| Feature diff | New production code, endpoints | What problem this solves |
| Fix diff | Bug fixes, SEV follow-ups | What broke, how this prevents recurrence |
| Refactor diff | No behavior change | What maintenance burden this reduces |
| Config diff | Config files, thresholds | What behavior changes, rollback plan |

## Implementation Detail Filter

Strip from summaries (visible in the diff itself):
- **File inventory** — never list which files were added/modified or repeat directory structures. The diff already shows this. "Added 4 files with architecture docs" is pure noise.
- **Line/word counts** — "165 lines, 1090 words" is metadata the reviewer doesn't need. If size matters, say why ("kept under 3000 tokens to meet CI budget").
- **Bullet-by-bullet content narration** — don't describe what each file contains. The reviewer will read them. Only mention a file if there's a non-obvious reason for its existence.
- Class/mixin names — describe what they DO, not what they're CALLED
- Inheritance chains, config field names/values, import paths
- BUCK/build file changes

## Anti-Robotic Voice

| Robotic | Human |
|---------|-------|
| "This diff adds..." | Start with the why directly |
| "The following changes were made..." | Just describe what matters |
| Identical structure across every diff | Vary format |
| Every sentence starts with a verb | Mix structures |

## Structure by Complexity

**Simple (< 50 lines):** 1-2 sentences. No bullets.

**Medium (design decisions):**
```
[What this enables and why]
- [Decision 1 with rationale]
- [Decision 2 with rationale]
```

**Complex/series:**
```
[Motivation and where this fits]
**Approach:**
- [Decision 1] — [why]
- [Decision 2] — [why]
NOTE: [Caveats]
```

## Anticipate Reviewer Questions

| Situation | Reviewer Asks | Pre-Answer |
|-----------|---------------|------------|
| Prod bug, no SEV | "How bad? Why no SEV?" | Explain limited impact |
| Tests + prod code | "Why prod changes in test diff?" | Explain necessity |
| Config scope unclear | "What's affected?" | Scope + rollback |
| Code deleted | "Still used?" | Grep evidence |
| Defaults changed | "Why this value?" | Before/after + rationale |
| No migration | "Existing users?" | Backward compat explanation |
| Large diff | "Can this split?" | Why it's atomic |
| Other team's code | "Talked to owners?" | Mention conversation |

## Pre-Flight Check

Before finalizing, can a reviewer answer from the summary alone:
- Why does this change exist?
- What risk does it mitigate?
- What should I focus on?
- What's the most suspicious part? (pre-answer it)
