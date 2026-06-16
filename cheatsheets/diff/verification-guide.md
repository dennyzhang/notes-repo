# Verification Guide

Reference for running parallel verification on diffs. Used by the diff completion workflow.

## Running Checks in Parallel

Launch all three streams simultaneously using the Task tool with `run_in_background: true`. Each stream is independent.

### Timeout Handling

Every verification command must be wrapped with `timeout 2400` (40 minutes). Exit code 124 means timeout — treat as failure.

## Stream 1: Pyre (Static Type Checking)

```bash
timeout 2400 arc pyre check-changed-targets
```

**Common error types:**
- `Incompatible parameter type` — fix type annotations or argument types
- `Undefined attribute` — check imports and class definitions
- `Missing return annotation` — add return type hints
- `Incompatible return type` — fix the return type or the returned value

**Fixing:** Prefer fixing the actual type issue over `# pyre-ignore[XX]` suppression.

## Stream 2: Linting

```bash
timeout 2400 arc lint -a    # auto-fix first
timeout 2400 arc lint       # check for remaining issues
```

If `arc lint -a` modifies files, those changes are valid fixes — keep them. Common categories: line length, import ordering, unused imports, missing type annotations.

## Stream 3: Test Plan Execution

Extract test commands from the diff's test plan. Typical patterns:

```bash
timeout 2400 buck test fbcode//path/to:test_target
timeout 2400 buck test fbcode//path/to:test -- TestClass.test_method
```

Focus on tests related to your changes — pre-existing failures are not your responsibility (note them in the summary).

## Iteration Rules

1. Only re-run streams that failed — do not re-run passing streams
2. Max 2 fix cycles per stream — stop after 2 failures and report
3. Run lightweight checks (pyre, lint) before tests — don't waste test build time on code with type errors

## Success Criteria

| Stream | PASS | FAIL |
|--------|------|------|
| Pyre | No errors in changed files | Any type error in changed files |
| Lint | No remaining issues after auto-fix | Issues that can't be auto-fixed |
| Tests | All test plan commands exit 0 | Any test failure or timeout |

_Last updated: 2026-05-12. Maintainer: dennyzhang._
