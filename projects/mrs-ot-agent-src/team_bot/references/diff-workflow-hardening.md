# Diff-Workflow Hardening — Five Mechanisms

> **Audience**: future MyClaw / OT-bot sessions, when authoring a diff to
> `fbcode/pe_mrs_ml/mrs_ot_agent/` (or any fbcode area). Pinned here in the
> ot-agent repo so it survives devserver reinstalls and is reviewable.
>
> **Origin**: 2026-05-13 gchat thread `WFQIDN6xcWk` — D105041081 v3 shipped with
> a Devmate-flaggable rule violation (P39 inline source citation in pattern row)
> that the cheatsheet at `~/notes/users/dennyzhang/cheatsheets/diff/fbcode.md`
> explicitly enumerates. The cheatsheet existed; the workflow didn't enforce it.
> Markdown-only "remember to do X" guidance is not load-bearing on a session
> moving fast.

## The pattern this prevents

Self-discipline rules in markdown are fragile. The fix is to convert
"remember to do X" into "X is mechanically forced or it doesn't happen."

Five mechanisms below, ranked by leverage. **#1 + #2 stacked is the
recommended baseline.** #3–#5 are lower-leverage but cheaper to add.

---

## #1 — Hook-enforce the cheatsheet load (highest leverage)

**What**: pre-`jf submit` shell hook that asserts the diff cheatsheet was
read in the current session AND the `radar_preflight` check ran on the
current commit. Hard-blocks `jf submit` if either is missing — same
BLOCK pattern as the existing AUTODEPS2 gate in `quality-gate-precheck.sh`.

**Mechanism**:
- Sentinel files in `/tmp/`:
  - `/tmp/diff-cheatsheet-loaded-${SESSION_ID}` — written by the cheatsheet
    skill on load (touch-only, content irrelevant).
  - `/tmp/radar-preflight-${COMMIT_HASH}` — written by `radar_preflight`
    when it completes for the current commit.
- Hook checks both exist before allowing `jf submit` to proceed.
- Failure mode: if the session forgot to read the cheatsheet, submit just
  doesn't go through. No way to skip without explicit `[skip-cheatsheet-gate]`
  marker in the commit body + a one-line reason.

**Cost**: ~30 lines of bash, one-time.

**Benefit**: works even when the session is sloppy or rushed. Same
defense-in-depth as `quality-gate-precheck.sh`'s AUTODEPS2 detection.

**Status (2026-05-13)**: not yet implemented. Implementation plan:
1. Add `~/work/claude/scripts/diff-cheatsheet-gate.sh` (sentinel-file check).
2. Wire into `~/work/claude/scripts/quality-gate-precheck.sh` as a new
   precheck stage (runs after the existing arc-lint working-copy mutation
   detector, before the actual `jf submit`).
3. Update the diff-cheatsheet skill (currently the markdown file at
   `cheatsheets/diff/INDEX.md`) to `touch` the sentinel on load.
4. Update `radar_preflight` bash function to write its sentinel on success.

**Owner**: denny (cross-cutting tooling, not OT-specific).

---

## #2 — Subagent-dispatch all diff creation (recommended workflow)

**What**: every "create or improve a diff" task routes through a subagent
dispatch, never executes from the main session. The subagent's prompt
template forces the cheatsheet load as one of four mandatory completeness
checks (already designed in `cheatsheets/diff/common.md`
§ "Subagent diff prompts: 4 mandatory completeness checks").

**Why this works when self-discipline doesn't**: the cheatsheet's subagent
prompt template already encodes the discipline — but it only fires when a
**subagent** receives the prompt. Main sessions never receive it because
they're not the dispatcher's target. Routing diff work through subagents
is the prescribed lane the cheatsheet author already designed for.

**The 4 mandatory checks** (verbatim from `cheatsheets/diff/common.md`):
1. **Pyre output paste** — run `arc pyre check-changed-targets`, paste the
   final 5 lines verbatim (don't summarize).
2. **Cheatsheet load** — read `cheatsheets/diff/common.md` AND the
   repo-specific cheatsheet (`fbcode.md` / `configerator.md` / `www.md`).
3. **Sibling-site sweep** — grep the codebase for the same anti-pattern
   in OTHER files; fix all sites OR explicitly justify why each is exempt.
4. **Consumer of captured state** — name the consumer of any new
   captured field/log (file:line) or remove the write.

**Cost**: one extra dispatch step per diff, ~10s overhead.

**Benefit**: leverages discipline the cheatsheet author already designed
for. The exact mistake the cheatsheet was designed to prevent (cheatsheet
not loaded by main sessions) gets eliminated by always going through the
subagent path.

**Status (2026-05-13)**: documented but not enforced. Adopt by:
1. Updating `team_bot/CLAUDE.md` § "Pre-Submit Lint" to add a "Diff
   creation routing" rule: any "create / improve / update a diff" task
   from the main session MUST be dispatched via Agent tool with the
   4-check subagent template.
2. Maintaining a one-shot subagent prompt template in
   `team_bot/references/diff-subagent-prompt.md` that the main session
   pastes verbatim into Agent tool dispatches.

**Owner**: ot-bot session conventions (this repo).

---

## #3 — Forced checklist artifact at commit time

**What**: at `sl commit` time, generate `/tmp/diff-checklist-D<NUM>.md`
programmatically from the cheatsheet. Each item is a `[ ]` checkbox. Pre-
submit hook reads the file and BLOCKs if any item is unchecked.

**Why this complements #1**: #1 enforces THAT the cheatsheet was read;
#3 enforces that EACH ITEM was actively checked. The artifact also
becomes a discoverable record of what was verified for that diff.

**Mechanism**:
- `sl commit` post-hook generates the checklist by parsing the active
  cheatsheet sections.
- Each section's checks become checkboxes (RADAR pre-flight, summary word
  budget, reviewer presence, devmate findings on prior version, etc.).
- Pre-`jf submit` hook scans the file for unchecked boxes; BLOCKs if any.
- Operator can mark items skipped with `[ ] N/A: <reason>`.

**Cost**: ~50 lines of script + one hook integration.

**Benefit**: makes the discipline visible. Invisible items get skipped;
visible checkboxes don't.

**Status (2026-05-13)**: proposal. Not blocking on #1/#2.

---

## #4 — Add diff-cheatsheet as a pi skill with tool-trigger

**What**: register `cheatsheets/diff/INDEX.md` as a pi skill with a
description that specifies "Load BEFORE any `sl diff`, `sl commit`,
`jf submit`, or `arc lint` invocation." The pi skill loader surfaces it
whenever those tools are invoked.

**Why this complements #1**: #1 BLOCKs at submit time; #4 NUDGES at edit
time. Together: the nudge tries to land the cheatsheet content into the
session's working memory before the diff is even drafted; the gate
backstops if the nudge fails.

**Mechanism**:
- New skill at `~/.myclaw-ot-bot/skills/diff-cheatsheet/SKILL.md`
  (or in fbcode if pi supports repo-mounted skills).
- Description names the trigger tools explicitly.
- Skill loader surfaces the skill when those tool patterns are detected.

**Cost**: 1 SKILL.md file (~10 lines), pointing at the existing
`cheatsheets/diff/INDEX.md`.

**Benefit**: low overhead, automatic context injection.

**Caveat**: only catches if the pi skill loader supports tool-name-
triggered skills (vs only description-matched). Confirm pi behavior
before relying on this path.

**Status (2026-05-13)**: proposal pending pi skill-trigger confirmation.

---

## #5 — Self-prompt rule in CLAUDE.md / session bootstrap

**What**: append to a session-loaded CLAUDE.md or USER.md:
*"Before any `sl commit`, `sl amend`, or `jf submit`, ALWAYS load
`cheatsheets/diff/INDEX.md` first and follow links. No exceptions."*

**Honest assessment**: **lowest leverage, do not rely on this alone.**
This is what was already implicitly in place when D105041081 v3 shipped
with the violation. Self-discipline rules in markdown files are not
load-bearing on a session moving fast — the session reads them and then
does the diff anyway under cognitive pressure.

**When it does add value**: as a reminder fallback once #1 is in place.
The hook is the actual gate; the prose is the documentation that
explains why the gate exists.

**Status (2026-05-13)**: present in the existing `team_bot/CLAUDE.md`
§ "Pre-Submit Lint". Verbatim text already mandates the
`diff-summary-lint` skill. Did not prevent the v3 violation. Do not
add more prose without #1.

---

## Recommended adoption order

1. **Week 1**: #2 (subagent-dispatch) — pure workflow change, zero
   tooling cost. Update `team_bot/CLAUDE.md` and add a subagent prompt
   template under `team_bot/references/`. Test by routing the next 3
   ot-bot-authored diffs through it.
2. **Week 2**: #1 (hook-enforce) — the structural fix. Implement the
   sentinel-file gate + wire into `quality-gate-precheck.sh`. Hard-blocks
   submit when the cheatsheet wasn't loaded.
3. **As-needed**: #3 (forced checklist) once #1 + #2 stabilize and we
   have data on which checks actually catch violations.
4. **As-needed**: #4 (pi skill trigger) if pi supports tool-name-triggered
   skills.
5. **Skip**: #5 in isolation. It's already in place and demonstrably
   not load-bearing.

## Track recurrences here

When a diff lands or skips with a cheatsheet-rule violation that any of
#1–#5 would have caught, append a one-line entry below. Pattern:
`YYYY-MM-DD | D<NUM> | <violation> | <which mechanism would have caught it>`.

| Date | Diff | Violation | Mechanism that would have caught |
|------|------|-----------|----------------------------------|
| 2026-05-13 | D105041081 v1 | Companion-doc sweep miss (5 sites) | #2 (subagent sibling-sweep check) |
| 2026-05-13 | D105041081 v1 | Inline source citation in pattern rows (P44, P45, P46, P47) | #1 + #2 (cheatsheet load forces awareness of ot-agent-conventions Rule) |
| 2026-05-13 | D105041081 v3 | P39 inline source citation NOT fixed (carried over from v2) | #1 (would have BLOCKed submit until the prior-version Devmate finding was addressed) |
| 2026-05-13 | D105041081 v3 | Title 100 chars (cap 72) | #2 (subagent cheatsheet-load check would have flagged) |
| 2026-05-13 | D105041081 v3 | Summary 925 words (~2× cap) | #2 (subagent cheatsheet-load + summary word-budget check) |
