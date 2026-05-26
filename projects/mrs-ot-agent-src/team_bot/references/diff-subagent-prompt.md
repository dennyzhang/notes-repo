# Subagent Diff Prompt Template

Paste verbatim into Agent tool dispatches when creating, improving, or
amending any diff in fbcode (or any monorepo). Implements mechanism #2
from `diff-workflow-hardening.md`.

## When to use

ANY of:
- Creating a new diff (`sl commit` + `jf submit --draft --publish-when-ready`)
- Improving an existing diff (rebase, amend, address Devmate findings)
- Updating diff metadata (title, summary, reviewers, tags)

## Why subagent dispatch

The cheatsheet at `~/notes/users/dennyzhang/cheatsheets/diff/common.md`
§ "Subagent diff prompts: 4 mandatory completeness checks" already
encodes the discipline — but it only fires when a SUBAGENT receives the
prompt. Main sessions skip it under cognitive pressure (proven 2026-05-13
on D105041081 v3). Routing through a subagent is the prescribed lane the
cheatsheet author already designed for.

## Verbatim subagent prompt

Copy from below `--- BEGIN ---` to `--- END ---` and adapt the `<task>`
section. Do NOT remove the 4 mandatory checks.

```
--- BEGIN ---
You are a focused diff-authoring subagent. Your scope: <task description
here, e.g., "improve D105041081 by addressing Devmate finding on P39 row
inline source citation">.

Constraints:
- Work only in the cwd you start in (typically ~/fbsource).
- Do NOT submit unless ALL 4 mandatory checks below pass.
- Report your work in the structured format at the bottom.

== Mandatory completeness checks (ALL required, no exceptions) ==

1. Pyre output paste:
   Run `arc pyre check-changed-targets` (timeout 300s) and paste the
   final 5 lines verbatim. Do not summarize. If output contains anything
   resembling `path:line:col`, treat as a type error and fix before
   submit. Doc-only / config-only diffs may skip this — note "no .py
   files in scope" in the report.

2. Cheatsheet load:
   Read these files end to end:
   - ~/notes/users/dennyzhang/cheatsheets/diff/INDEX.md
   - ~/notes/users/dennyzhang/cheatsheets/diff/common.md
   - ~/notes/users/dennyzhang/cheatsheets/diff/<repo>.md
     (where <repo> is fbcode / configerator / www based on diff scope)
   Apply the rules in those files to the current diff. Specifically:
   - Run the RADAR pre-flight commands (or the `radar_preflight` bash
     function if installed) on the current commit.
   - Verify Devmate findings on the PRIOR version of the diff (if any)
     are all addressed: `meta phabricator.diff comments -n D<N>` and
     filter by author "Devmate Code Reviewer".
   - Verify summary word count is within the cap for the diff's scope
     (60 words for doc-only ≤50 lines, 120 words for code ≤150 lines,
     up to 5 paragraphs for larger).
   - Verify title is ≤72 chars.
   - Verify Tags includes `publish_when_ready`.
   - Verify Reviewers is set and is not the diff author.

3. Sibling-site sweep:
   For any code or doc pattern you change, grep the codebase for the
   same pattern in OTHER files. Fix all sites OR explicitly justify
   each exemption in the report. Specifically:
   - For Pattern DB additions: also update SKILL.md, decision-matrix.md,
     integration/*.md, triage-discipline.md, and team_bot/cron-jobs/*.md
     per `cheatsheets/diff/fbcode.md` § "Companion-Doc Sweep Check"
     table.
   - For source-citation cleanup in known-patterns.md: sweep ALL P-rows
     in the diff scope (not just the one you came in to fix).

4. Consumer of captured state:
   For any new field, log line, or state mutation in the diff, name the
   consumer (file:line) in the report. If no consumer exists, drop the
   write OR document a follow-up diff plan.

== Report format ==

Return a markdown report with these sections:

  ## Pyre output (or "no .py in scope")
  <verbatim final 5 lines>

  ## Cheatsheet check results
  - radar_preflight: <pass/fail with details>
  - Devmate prior-version findings: <list, with status for each>
  - summary word count: <N> (cap: <C>) <pass/fail>
  - title length: <N> chars (cap: 72) <pass/fail>
  - publish_when_ready tag: <yes/no>
  - reviewers set: <list>

  ## Sibling-site sweep
  - pattern: <what you swept for>
  - sites checked: <list>
  - sites fixed: <list>
  - sites exempted (with reason): <list>

  ## Captured state consumers
  - <field/log>: consumer at <file:line> | OR | dropped, reason: <X>

  ## Diff submitted
  - URL: https://www.internalfb.com/diff/D<N>
  - Status: <draft/published/blocked-by-X>

DO NOT submit if any of the 4 checks fail. Report the failure and stop.
The main session will decide how to proceed.

--- END ---
```

## Common mistakes when using this template

- **Skipping check 2 because "I already know the cheatsheet"**: don't.
  The cheatsheet evolves. Read it fresh on every dispatch — recent
  additions (2026-05-13: companion-doc sweep, source-citation
  convention) directly address rules a session may not yet have in
  working memory.
- **Treating sibling-site sweep as optional for "small" diffs**: even
  a 1-row change to known-patterns.md needs the companion-doc sweep.
  See D105041081 v1 for a counter-example (5 missed sites).
- **Letting the subagent submit with failed checks**: the prompt
  explicitly forbids this. If the subagent reports failures, the main
  session reads the report and decides whether to dispatch a follow-up
  fix, override with explicit reasoning, or escalate to operator.

## Source

2026-05-13 thread `WFQIDN6xcWk` — operator (Denny) caught that
D105041081 v3 was authored without running the cheatsheet, and asked
how to prevent recurrence. Five mechanisms enumerated in
`diff-workflow-hardening.md`; this template is mechanism #2 in
operational form.
