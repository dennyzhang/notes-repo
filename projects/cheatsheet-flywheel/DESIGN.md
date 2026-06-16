# Cheatsheet Flywheel — Design

Project build doc. The detailed design (loop, Contract, gates) is canonical in
`cheatsheets/agents/cheatsheet-flywheel.md` — this doc summarizes the architecture and tracks
how it's built. Link-over-copy: do not restate the spec here.

## Goal
Cheatsheets teach an agent to do specialized tasks correctly. Today they're authored from the
operator's experience. The flywheel makes the corpus **self-maintaining and self-growing**:
1. **Maintain** — keep existing sheets healthy and reliably useful; demote/trim stale ones.
2. **Grow** — mine the operator's practice, propose new sheets, gate + eval + probation → prod.

## Architecture (two loops, one linchpin)
```
  operator works + corrects ─► CORRECTIONS ─┬─► "After"  = cheatsheet RULE
  (+ "close the thread")                     └─► (situation,wrong,right) = GOLDEN case
  LOOP B grow:  mine → ≥3 bar → ACCEPTANCE GATE → PROBATION → EVAL → prod
  LOOP A maintain: hygiene (lint/dedup/grounding) + eval-gated trim (demote-not-delete)
  LINCHPIN: the EVAL (pairwise with/without sheet, scored against the GOLDEN set)
```

## Components & status
| Component | Path | Status |
|-----------|------|--------|
| Structural gate/audit/heal | `scripts/lint/lint-cheatsheets.sh` (`--gate/--fix/--stamp/--fix-index/--audit-grounding`) | ✅ built |
| Grounding gate (trust-gradient) | same, `--gate` (CS_STRICT=block, else warn) | ✅ built |
| Adversarial content verify (LLM) | `scripts/lint/cheatsheet-content-verify.sh` (dedup/contradiction) | ✅ built |
| Acceptance gate (one call) | `scripts/lint/cheatsheet-accept.sh` (det → LLM, default-fail) | ✅ built |
| Existing-corpus dedup sweep | `scripts/lint/cheatsheet-dedup-sweep.sh` | ✅ built |
| Daily structural sweep + grounding backlog | `scripts/cron/cheatsheet-sweep.sh` | ✅ built |
| Weekly harvest (absorb skills/learnings) | `scripts/cron/cheatsheet-harvest.sh` | ✅ built |
| Prompt-coaching (coach the operator) | `cheatsheets/agents/prompt-coaching.md` + `config/hooks/check-coach-placement.py` | ✅ built |
| **Golden set — backfill** | `scripts/lint/golden-backfill.py` → `golden/diff.jsonl` (58 cases) | ✅ built |
| **Golden set — ongoing collector** | tee corrections + outcomes + gate verdicts → `golden/` | 🔶 Phase 2 |
| **Eval harness** | pairwise with/without sheet, scored by gates over `golden/` | ❌ Phase 3 (linchpin) |
| Provisional tier + probation | `provisional:` frontmatter + `lint` check; shadow-load + measure | ❌ Phase 4 |
| Usage telemetry | log which sheets load; demote never-loaded | ❌ Phase 5 |

## Build phases
1. ✅ **Hygiene + acceptance gate** — done (the maintain-half walls + the grow-half gate).
2. 🔶 **Golden data layer** — backfill done (58 cases); ongoing collector next.
3. ❌ **Eval** (linchpin) — pairwise runner over `golden/`, oracle = existing gates for `diff/`.
4. ❌ **Provisional/probation** — quarantine auto-content, measure, promote.
5. ❌ **Telemetry** — usage signal for demote-not-delete trim.

## Scheduling (cron) — the flywheel is many small crons, not one monolith
Each station runs on its own cadence (failure isolation + different rhythms). Re-installed after a
devserver reinstall by `scripts/cron/install-cheatsheet-flywheel.sh` (the persistence boundary).

| Cron | Cadence | Role |
|------|---------|------|
| `cron-autolearn-corrections.sh` | daily 07:15 | corrections → cheatsheets (the input stream; also the golden-collect source) |
| `cheatsheet-sweep.sh` | daily 07:30 | structural auto-fix + grounding backlog draft |
| `cheatsheet-harvest.sh` | weekly Mon 08:00 | absorb new skills/learnings (anti-bloat by construction) |
| `cheatsheet-dedup-sweep.sh` | weekly Mon 08:30 | dedup/contradiction over the existing tree (LLM) |
| `cron-diff-autolearn.sh` | weekly Mon 06:00 | reviewer-comment learning |
| golden-collect (Phase 2) | daily, after autolearn | tee corrections/outcomes → `golden/` *(to add when built)* |
| eval (Phase 3) | weekly | pairwise with/without over `golden/` *(to add when built)* |

The commit-gate (`cheatsheet-lint-hook.sh`) is reactive (not cron); the crons are the proactive
counterpart. golden-backfill is one-time (not cron).

## Key decisions (settled)
- Golden set is **organic** — corrections are the answer key; one correction = a rule AND a test
  case. Stored as **extracted cases + provenance pointer**, never raw transcripts; work-lane only,
  sensitive-stripped (the store is GH-mirrored).
- **Trust gradient:** machine-authored content (pipeline via `CS_STRICT`) is hard-blocked on
  grounding; human edits get a warn.
- **Trim = demote-not-delete** by default; delete only when eval shows zero contribution + superseded.
- **Eval bootstrap from history** — the diff learnings-log's Common-Mistakes rows are ready
  `(wrong, right)` pairs (Phase-2 backfill).

## Human involvement (leverage-ranked)
1. **Approve the eval oracle + spot-check ~5 golden cases** (`diff/`) — unblocks Phase 3. The one
   real dependency. (~10 min)
2. **Just keep working + correcting** — the engine; no extra effort.
3. **Set the bars** (≥3, eval threshold, trim/delete authority, auto-vs-human promotion) — once.
4. **Weekly review** — leverage-capped ask-tier queue, default-safe on silence.

_Last updated: 2026-06-14. Maintainer: dennyzhang._
