# Principles — Operator-Driven Lessons from Building OT Bot

_Cross-project learnings extracted from live operator/agent conversations. Each principle is operator-flagged, codified once, then applied across the system. The catalog itself is the operator's tacit standards made explicit._

**Owner:** dennyzhang. **Audience:** anyone building AI-agent systems with human operators. **Started:** 2026-05-17 thread asking "how we can track them, so building this system's experience can be applied to similar areas?"

---

## Why this exists

Every operator-agent conversation produces lessons. Most evaporate into commit messages or per-cron prompt edits that future maintainers won't grep. This catalog makes the **transferable principles** searchable + actionable.

**The asymmetry being managed:** the operator has tacit standards (concise output, no 404s, system-wide thinking). The agent defaults to local-fix-per-incident. Each principle here = one tacit standard made explicit.

---

## Index by scope

### Agent-behavior principles (apply to ANY agent assisting an operator)

| ID | Principle | Discovered |
|---|---|---|
| [P-001](./P-001-act-dont-ask-for-readonly.md) | Act, don't ask, for read-only investigation work | 2026-05-17 thread `2KD3EVyCv08` |
| [P-002](./P-002-shipping-requires-execution.md) | Cron-prompt edits require one representative execution before claiming shipped | 2026-05-17 (5 silent failures in 2h) |
| [P-003](./P-003-generalize-to-system-rule.md) | When operator says "generic feedback," promote local fix to system-wide rule | 2026-05-17 thread `-x-xLvG_vPo` |
| [P-015](./P-015-backtest-spec-edits.md) | Backtest spec edits manually against ≥1 representative data point before pushing | 2026-05-17 thread `Uc-pVBEXNQ8` |
| [P-016](./P-016-full-ownership-on-every-fix.md) | Full ownership on every fix — diagnose, land, verify, push, monitor, close-the-loop. No confirmation-bait. | 2026-05-18 thread `wf45Cu8OLzc` |

### Output-quality principles (apply to ANY operator-facing artifact)

| ID | Principle | Discovered |
|---|---|---|
| [P-004](./P-004-no-404-urls.md) | Every URL emitted MUST work; if form unverifiable, render plain text | 2026-05-17 thread `-x-xLvG_vPo` |
| [P-005](./P-005-conciseness-as-discipline.md) | Concise output is a discipline; raw URLs / verbose duplication are operator-hostile | 2026-05-17 thread `Y3qbdh2hC20` |
| [P-006](./P-006-learning-is-insight-not-topic.md) | "Learned X" must state the actionable insight, not the topic header | 2026-05-17 thread `suPsRC2fGdc` |
| [P-007](./P-007-citation-discipline-not-just-presence.md) | Doing the work isn't enough — citing it (CL-NNN / P-row / VERIFIED markers) is what makes the work compound | 2026-05-17 thread `suPsRC2fGdc` |

### Workflow / architecture principles (apply to ANY agent-system design)

| ID | Principle | Discovered |
|---|---|---|
| [P-008](./P-008-history-repeats.md) | History repeats: check same-workload recurrence + cross-workload patterns before re-deriving hypothesis | 2026-05-17 thread `r70kC-3eghA` |
| [P-009](./P-009-validator-coverage-asymptotic.md) | Validators are only as good as their checklist; each operator catch = +1 check category (asymptotic convergence to standards) | 2026-05-17 thread `suPsRC2fGdc` |
| [P-010](./P-010-source-migration-audit-downstream.md) | When a cron's data source changes, audit downstream artifact schemas (filenames, INDEX columns, README enums), not just the query call | 2026-05-17 thread `Uc-pVBEXNQ8` |
| [P-011](./P-011-spec-vs-lint.md) | Spec without lint = unenforced. Spec with lint but no coverage = unenforced anyway. Both gaps must close | 2026-05-17 thread `Y3qbdh2hC20` |

### Content / cluster-registry principles

| ID | Principle | Discovered |
|---|---|---|
| [P-012](./P-012-mitigated-vs-routed.md) | "Mitigated" requires source pattern to have stopped recurring; bot-routing improvements ≠ mitigation (separate status: 🔵 routed) | 2026-05-16 thread `ZP2y-6Bdpwk` |
| [P-013](./P-013-leadership-asks-need-names-and-deadlines.md) | Leadership asks need named target (unixname) + specific deadline; "scope a project" without owner evaporates | 2026-05-16 thread `ZP2y-6Bdpwk` |
| [P-014](./P-014-narrower-scope-defer-overlap.md) | Narrower scope wins; defer overlapping work to the cron designed for it (don't ship 4 categories when 2 suffice) | 2026-05-17 thread `Uc-pVBEXNQ8` |

---

## Process — when to add a principle here

Add when ALL of:
1. Operator-flagged in a thread (not self-derived)
2. Application is broader than one cron / one file (transferable)
3. You're about to (or just did) write the same lesson into >1 place

Don't add when:
- The fix is purely OT-specific (use `failure-patterns.md` / `known_patterns.md` instead)
- The fix is purely cron-prompt-mechanical (use the cron prompt directly)
- The lesson is captured cleanly in one file already (link from here instead)

## File format per principle

```
# P-NNN: <one-line principle>

**Statement:** <single sentence>

**Discovered:** <date>, thread `<gchat-thread-id>`, originating incident

**Why it matters:** <concrete consequences if violated>

**Applies to:** <bot-specific | operator-workflow | generalizable-to-any-agent-system>

**Current applications:**
- file:line where this principle is enforced
- file:line where this principle is enforced

**Anti-patterns it prevents:**
- <concrete example 1, with date>
- <concrete example 2, with date>

**Related principles:** P-NNN, P-NNN
```

## What this is NOT

- NOT a duplicate of `failure-patterns.md` (that catalogs OT failure modes; this catalogs agent-design lessons)
- NOT a duplicate of `RULES.md` (that's the bot's binding ruleset; this is the documentation of why those rules exist)
- NOT a place to dump every commit message lesson (only operator-flagged + transferable)

## How to use this catalog

- **New team member or agent self-orientation:** read INDEX + browse 1-2 principles per scope group. ~15 min total.
- **Designing a new cron:** check Workflow/Architecture principles before writing.
- **Editing an output format:** check Output-quality principles.
- **Building a similar AI-operator system elsewhere:** all 14 are transferable; lift the structure.

## Pending principles (drafts, not yet split into files)

Things I've noticed but haven't written up yet — when I have time or operator confirms relevance:

- **Daemon-cache-vs-on-disk gap:** prompt edits in notes don't take effect until `setup-cron-jobs.sh` runs. (RULES.md has this but principle hasn't been generalized.)
- **State files survive devserver reinstalls only if symlinked into notes** (RULES.md storage policy)
- **"Where leaders should look first" duplicates per-cluster red headers; pick one** (failure-patterns.md restructure)
- **Operator-prompted vs scheduled cron fires have different next_run_epoch semantics** (daemon snaps manual UPDATE back to schedule)

When these become operator-flagged or applied 2+ times, promote to numbered principle.

---

## Red-team audit (added 2026-05-17 thread `RtQW3qQf5tg` 11:21 PT after operator: "attack your solution to make it complete and reliable")

Gaps identified, status of each:

| Gap | Severity | Status | Fix |
|---|---|---|---|
| **G1** All 14 INDEX entries link-404 (only 5 files existed) | CRITICAL — violated P-004 (no 404 URLs) the principle itself documented | ✅ FIXED | All 14 files now exist + P-015 added |
| **G2** No discovery mechanism for unwritten principles | Medium — principles only captured when I remember | ⏳ Need cron: ot-principle-extraction (scan threads for operator-flagged feedback that doesn't map to existing principle) |
| **G3** No machine check that principles get applied | High — P-007 cited in lint for 3 of N crons, others silent | ⏳ Need per-principle audit: "what enforces this here?" column in INDEX |
| **G4** No freshness tracking | Low — stale principles look authoritative | ⏳ Add `last_applied` field to each file |
| **G5** Principle files not cross-referenced from team_bot/CLAUDE.md or RULES.md | High — new agent boot won't see them | ⏳ Add symlink-style reference to bootstrap |
| **G6** No supersedes/refines graph between principles | Low — "Related" field is informal | Defer |
| **G7** No way to validate principle CAUSED behavior change | Medium — can't tell if anti-pattern recurred | ⏳ Need observability: scan commit history for anti-pattern matches |
| **G8** No enforcement of "3 criteria for adding" process | Low — could add non-operator-flagged principle | Defer |

The biggest meta-lesson: **the principles INDEX violated P-004 (no 404 URLs).** Fixing this first was non-negotiable — the catalog can't credibly document anti-patterns it itself exhibits.

Gaps G2/G3/G5/G7 will be tackled in next iteration. G6/G8 deferred (low ROI).

---

_Created 2026-05-17 (operator thread asking "how we can track them"). Started with 14 principles drawn from yesterday's failure-patterns.md restructure + today's silent-failure cascade. Now 15 principles (added P-015 backtest-spec-edits 11:21 PT). Will grow with future operator conversations._
