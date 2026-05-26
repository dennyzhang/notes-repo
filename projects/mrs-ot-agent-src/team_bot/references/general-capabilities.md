# General Capabilities Live In fbcode

Detailed reference for `team_bot/CLAUDE.md` § General Capabilities Live In fbcode.

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
