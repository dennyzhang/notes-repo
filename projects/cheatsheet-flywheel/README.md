# Cheatsheet Flywheel — project

Self-improving cheatsheet system: keep existing sheets healthy + reliably useful, and grow new
ones from the operator's practice — gated, eval-validated, probation-then-prod.

- **Canonical design spec:** `cheatsheets/agents/cheatsheet-flywheel.md` (the loop, the Contract,
  the gates, the two-loop target state). This project folder tracks the **build**, not the design.
- **Design doc:** [DESIGN.md](DESIGN.md) — architecture summary, components + status, build phases.
- **Status:** [STATUS.md](STATUS.md) — what's built, what's next, the one human blocker.
- **Golden set:** `golden/` — the eval answer key (`(situation, wrong, right)` cases). Seeded by
  `scripts/lint/golden-backfill.py`; grows from corrections via the collector (Phase 2).

_Last updated: 2026-06-14. Maintainer: dennyzhang._
