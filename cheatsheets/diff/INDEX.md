# Diff Cheatsheets

Load `common.md` for any diff operation. Add repo-specific file for the target repo.

| When | Load |
|------|------|
| Any diff operation | `diff/common.md` (always) |
| fbcode diffs | + `diff/fbcode.md` |
| configerator diffs | + `diff/configerator.md` |
| www diffs | + `diff/www.md` |
| Reviewing a diff | `diff/review.md` (instead of common) |
| Maximizing RADAR auto-stamp | `diff/common.md#radar-auto-stamp-optimization` + `diff/fbcode.md` Devmate section |
| Harness/reliability discipline | `diff/common.md#harness--reliability-discipline` (verify hooks fired, sibling-site sweep, no dead state writes, subagent 4-check template) |
| Subagent dispatching a diff | `diff/common.md#harness--reliability-discipline` — paste the 4-check template into the subagent prompt verbatim |
| `quality-gate-precheck.sh` BLOCKED submit | `diff/fbcode.md` AUTODEPS2 section — follow the re-amend runbook |
| Diff-flywheel learned classifier (auto-generated signal mirror) | `diff/learned-classifier.md` |
