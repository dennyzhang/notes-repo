You are running the weekly **cheatsheet skill-harvest** (Goal 2 of the cheatsheet
improvement flywheel). Spec: `~/notes/users/dennyzhang/cheatsheets/agents/cheatsheet-flywheel.md`.

GOAL: find content in the available skill catalog and recent learnings that would
improve the cheatsheet tree at `~/notes/users/dennyzhang/cheatsheets/`, WITHOUT
bloating it. Density is the whole value of this tree — bias hard toward rejecting.

Use the **Workflow tool** (token cost is not a concern; be thorough). **Fallback:
if the Workflow tool is unavailable or errors in this headless/cron environment,
do NOT skip the harvest — run the same scan → dedup → reject → draft steps inline
using the Agent tool (or sequentially yourself).** Never silently no-op. Shape:

1. SCAN (parallel fan-out): bucket the skill catalog (SKILL.md files under
   `~/.claude/plugins/`) plus recent learnings (`~/notes/users/dennyzhang/scripts/learnings/auto-save-learnings.md`
   and `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/`).
   One agent per bucket returns candidates: `{source → covers a GAP in <cheatsheet> | OVERLAPS <cheatsheet>}`.
   Only consider sources relevant to existing cheatsheet lanes (diff, oncall,
   gdocs, comms, notes-repo, system, research, career). Ignore pure ML-training
   skills with no cheatsheet lane.
2. DEDUP (barrier): merge; drop anything already covered by an existing rule.
3. ADVERSARIAL REJECT (parallel): one skeptic per surviving candidate must argue
   "reject — bloat / already covered / fails the ≥3-evidence bar", citing the
   specific existing `file:line` it checked. Default to REJECT when uncertain.
4. SYNTHESIZE: pick AT MOST ONE candidate. Apply the two anti-bloat rules:
   - **Link-over-copy**: propose pointing the cheatsheet at the canonical skill +
     distilling only the non-obvious delta — never copy the skill body.
   - **Net-neutral-or-shrinking**: a deletion/merge proposal is as valid as an add.

OUTPUT: write the single candidate (or "no candidate cleared the bar this week")
to `{{OUT}}` using the Write tool, as a review draft for the operator. Format:
- TARGET cheatsheet file + section
- CHANGE (the exact link-over-copy snippet or deletion)
- SOURCE (skill/learning path) and why it clears the bar
- TIER (auto-land vs ask, per the flywheel tier table) — almost always "ask"
DO NOT edit any cheatsheet. DO NOT commit or push. The draft is the only write.

Keep your final chat response to one line (the draft path or "no candidate") —
this runs headless; narration leaks to the cron log.
