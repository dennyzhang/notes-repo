# General Capabilities Live In fbcode

Detailed reference for `team_bot/CLAUDE.md` § General Capabilities Live In fbcode.

## Tool placement: OT master-agent src vs the mvai-ot skill (HARD, 2026-06-24)

Every OT script/tool has ONE correct home; do not scatter them. Decision test:

- **OT-bot-internal tool** — one the OT bot builds, maintains, and iterates (cron-invoked scans OR ad-hoc debug tools the bot/OT-oncall run) → **the OT master-agent src**: author in notes `mrs-ot-agent-src/tools/` (notes-canonical → mirrored to `fbcode/pe_mrs_ml/mrs_ot_agent/`). Notes-canonical = **fast iteration (no review), bot-owned, reinstall-survives**. Examples already here: `scan-*.sh`, `lib-fleet-baseline.py`, `run-fleet-health.sh`, `render-fleet-digest.py`, `job_source_revision.py`, `job_fix_coverage.py`.
- **Shared human-facing helper** — a general MVAI-OT reliability helper meant for *any* human/team to discover and run → **the mvai-ot XFN skill** (`fbcode/minimal_viable_ai/agent/skills/mvai-ot/...`), discoverable via that skill's `SKILL.md` routing. Review-gated (`jf submit`).
- **Need both** (bot-owned AND XFN-discoverable): keep the tool **canonical in the OT-agent src** and add a thin **pointer row** in the mvai-ot `SKILL.md` — **never a duplicate copy** (duplicates drift; one source of truth).

**Anti-pattern that motivated this (2026-06-24):** `job_source_revision.py` + `job_fix_coverage.py` were built into the **mvai-ot skill** (review-gated, not the bot's own src) when they're OT-bot-internal debug tools — they belong in the OT master-agent src alongside `scan-ne-quality.sh`. Operator: *"why the ot script is not stored in OT master agent src in fbcode?"* Migrated 2026-06-24; the skill keeps only a pointer.

- **Reusable logic belongs in `fbcode/pe_mrs_ml/mrs_ot_agent/src/`,
  not embedded in cron prompts or one-off scripts.** When a piece of
  logic could plausibly be called by more than one surface (the cron,
  an interactive Claude session, a manual operator triage, a
  sibling-team bot, a future Phase-2 reply path), it is a capability
  and should be a module under `src/capabilities/`. The cron prompt
  should be a thin orchestration layer that calls the capability and
  acts on its output.
- **Why:** logic in cron prompts is invisible to the type checker,
  untestable, locked to a single caller, and forces the same lossy
  regex-in-natural-language reproduction every time a new caller
  shows up. Logic in fbcode is versioned, reviewable, importable,
  unit-testable, and discoverable. The 2026-04-29 SEV identification
  bug hunt (3 iterations of false-positive fixes embedded in the cron
  prompt before the gating gaps surfaced) was the forcing function
  for this rule.
- **Concrete examples that should be capabilities:**
  - SEV classification / OT-relevance scoring (`capabilities/sev_identification.py`)
  - Peer scenario isolation (`capabilities/peer_scenario.py`, already exists)
  - Snapshot timeline reconstruction for ground-truth verification
  - OT IC list resolution (rotation members ∪ curated extension)
  - Active-SEV cross-reference for diagnosis enrichment
- **Cron prompts should orchestrate, not classify.** A cron prompt
  reads inputs, calls one or more capabilities, decides on actions
  (notify / auto-tag / propose) based on the structured output,
  spawns the validator, logs the result. Classification rules,
  regex tiers, registry lookups, and similar logic move to
  `src/capabilities/` so a unit test can pin them down.
