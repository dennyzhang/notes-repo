# P-021: A Fix Diff Is Minimal — Every Hunk Traces to the Verified Root; No Speculative "Defense-in-Depth"

**Statement:** Every file/hunk in an issue-scoped fix must be REQUIRED to fix that issue's *verified root* (the actual raising/effective `file:line`). A change that fixes a DIFFERENT bug, is "defense-in-depth", "while we're here", or sits on a code path OTHER than the verified failing path is **scope creep** — remove it or split it into its own diff. Prefer the fix at the SINGLE layer where the root lives (a generic base over a per-model override); touching extra files/owners is a flag unless each is independently required. "Kept as defense-in-depth" is a violation to FLAG, never a feature to report. This is the explicit COUNTER to the sibling-site sweep ([P-009]/cheatsheet): the sweep prevents UNDER-fixing; this prevents OVER-fixing.

**Discovered:** 2026-06-13 thread `Nk_Ui4WFn4U`. Operator, on D108525530: *"why made the unnecessary changes in the diff? and how to add prevention?"* The diff carried 3 unnecessary `ig_retrieval/` files (a per-model resolver, load-bearing cross-team code) — the original wrong-site patch — kept as "defense-in-depth" after the real, generic fix was found in the base resolver. The agent had even *reported* keeping them as a positive.

**Why it matters:** Over-fixing is as harmful as under-fixing — more blast radius, more review burden, more cross-team owners dragged in, and it muddies the diff's intent so a reviewer can't cleanly reason about "what does this change and why." Bundling a speculative fix for a *different* bug means that fix ships unreviewed-on-its-own-merits and the real fix is harder to evaluate. **Root cause of how it happened:** (1) the fix was first authored at the first *plausible* site, not the verified raising site ([P-018]/`fix-at-raising-site`); (2) when corrected, the wrong-site change was *kept* rather than reverted; (3) the diff-subagent's mandatory checks all biased toward MORE coverage (sibling sweep, completeness) with no minimality counter-check — so scope creep was rewarded, not flagged.

**Applies to:** every code/config diff. Generalizable to any agent authoring diffs.

## The gate
```
For each changed file/hunk in the diff:
  └─ Which verified-root file:line (from the reproduce step) does this hunk fix?
       ├─ It IS that root site / required by it → keep.
       └─ Different bug / "defense-in-depth" / "while here" / off the verified path
              → REMOVE (sl revert -r .^ <file>) or SPLIT to its own diff.
Prefer ONE layer (generic base) over N per-call-site patches. Extra owners = flag.
```

## Enforcement
- `team_bot/references/diff-subagent-prompt.md` — mandatory check #6 "Minimality / necessity" + report section (counter to check #3 sibling-sweep).
- `cheatsheets/diff/common.md` § Self-Review — "Minimality / necessity (no speculative scope)" bullet.
- Worked instance: D108525530 reduced 473→161 lines, 6 files→3 (ig_retrieval reverted), base-resolver-only.

**Related:** [P-018](./P-018-external-attribution-needs-confirming-metric.md) (fix at the verified root, not the plausible site) · [P-009](./P-009-validator-coverage-asymptotic.md) · [P-014](./P-014-narrower-scope-defer-overlap.md) (narrower scope, defer overlap) · [P-016](./P-016-full-ownership-on-every-fix.md).
