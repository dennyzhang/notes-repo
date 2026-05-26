# Agent Pressure Cheatsheet

Distilled from Marty Dumaual's "Your Agent Isn't Stupid. It's Under Pressure" (Claude Code Community, 2026-04, ~400 eval iterations on Claude Opus 4.6) plus self-audit of Pylon (work-instance) practices on 2026-04-29.

The headline finding: **agent failures are predictable responses to specific input signals that suppress otherwise-available capabilities** — not capability gaps. Each failure mode has two sides: what the input *constrains* (effort / willingness to challenge / scope / etc.) and what behavior gets *suppressed* as a result.

## The Two-Sided Framing

You can't fight a constraint directly ("don't be helpful" doesn't work when helpfulness is core). You **redirect** toward the suppressed behavior while staying within the constraint.

| Format | Works within constraint of... | Redirects toward... |
|---|---|---|
| Y/N checklist | Effort ("feels low-effort") | Depth (binary truth on each item) |
| Procedure | Deference ("following steps feels compliant") | Independent evaluation (steps produce evidence) |
| Enumeration | Scope ("listing feels organizing") | Breadth (full set named) |
| Per-field classification | Helpfulness ("classifying feels thorough") | Sensitivity (each field evaluated) |
| Scratchpad | n/a (not a constraint problem) | Externalizes working memory |

## Three Meta-Patterns

### 1. Three-ingredient recipe (agent-internal failures)

Agent-internal failures require ALL THREE conditions:

1. **Neutral / ambiguous signals** — names don't reveal sensitivity (`delivery_contact_ref` not `customer_phone`)
2. **No visible correct pattern** — no sibling method to copy from
3. **Cognitive pressure toward inclusion** — helpfulness, completeness, task compliance, user claims

Remove ANY one and the agent succeeds. Architecture levers:
- Use explicit names (kills ingredient 1)
- Provide a visible correct example near the work site (kills ingredient 2)
- Avoid pressure-loaded prompts ("complete", "exhaustive", "all of") (kills ingredient 3)

### 2. Pareto boundary (spec trust)

Any wording that increases trust in specs also increases trust in WRONG specs. Three independent runs confirmed the tradeoff is inherent.

**Escape**: "Write tests for both spec and implementation. If they disagree, flag the discrepancy." Don't choose which to trust — surface the conflict.

### 3. Hook interference

Multiple hook types firing on the same task can degrade performance. Marty measured PreToolUse + UserPromptSubmit on the same action: **0.667 → 0.431**.

**Rule**: test hook combinations, not just individual hooks.

## Pressure Signals in User Prompts

These framings carry implicit signals that shift what the agent prioritizes. Same deliverable, different framing → meaningfully different work.

| Pressure framing | Better framing | What it removes |
|---|---|---|
| "Just a sanity check" | "Do a full review" | "just" / "sanity check" → low-effort signal |
| "Tech lead reviewed this" | "Review independently" | Authority → defer-don't-evaluate |
| "I've already implemented X" | "Here's what I have. Right approach?" | Sunk cost → reluctance to suggest changes |
| "Don't worry about that" | "Check whether X is handled correctly" | Strongest suppression signal — agent will almost always comply |
| "We ran 50M ops, zero failures" | "What conditions would surface this failure mode?" | Past-success defer → reasoning about mechanism |
| "Log everything for debugging" | "Log what's needed for debugging, considering what should/shouldn't be stored" | Filter-feels-unhelpful → filtering as part of task |
| "Just do it" | "Do it, flag concerns inline" | Suppress suggest-alternatives |
| "Fix X" | "Fix X if approach is right; otherwise propose alternate" | Suppress redesign-vs-patch |
| "ok" | "ok proceed, but pause if you hit Y" | Suppress should-we-reconsider |

## Checklist for Architects (your-end levers)

When designing classifiers, prompts, or agent automation:

| Check | Why |
|---|---|
| Does the classifier have explicit category names? | Removes neutral-signals ingredient |
| Is there a visible correct example in the same file/directory? | Removes no-visible-pattern ingredient |
| Does the prompt contain pressure signals (just / already / don't worry / complete)? | Triggers suppression |
| Are hook combinations tested, not just individual hooks? | Marty's 0.667 → 0.431 finding |
| Does the agent have room to disagree (question form, not assertion)? | Avoids deference suppression |
| Is spec separated from implementation in agent's view? | Avoids value-anchoring |

## Anti-Patterns Pylon Has Hit (self-audit)

- **Sunk-cost suppression on the WIB pivot (2026-04-26)**: Boss had to override with "why we need wib bot??" because I'd built up DENNY-AGENT context that biased toward including the WIB approach. Lesson: re-verify rationale when applying a known pattern to a new domain.
- **Heads-down without acknowledging questions (2026-04-29)**: Boss called out "you haven't replied to my question here" — I went into execution mode without first answering. Lesson: answer the question, then go dark.
- **Cross-domain pattern reuse without "what problem does this solve" check (2026-04-26)**: Recommended OT-bot WIB pattern for Phab review without checking whether the audience problem (new joiners scanning member list) translated.

## The Takeaway

Marty's most-quoted line: *"the input that matters most is usually yours."*

True at the prompt level. **Less true** at the architecture level — investments in trust gradients (RADAR, auto-review-bot), persona rules (anti-sycophancy in soul), explicit confidence labels (`[VERIFIED]` / `[INFERRED]` in CLAUDE.md), and feedback memories absorb a lot of variance. The 80/20 for already-mature setups: hook combinations + prompt-pattern reframings.

## See Also

- Source post: https://fb.workplace.com/groups/claude.code.community/permalink/970944888780965
- `cheatsheets/diff/reviewer-comment-automation.md` — RADAR-style trust gradient applied to diff review
- `cheatsheets/diff/common.md` § "RADAR Auto-Stamp Optimization" — original trust-gradient pattern
- `~/.myclaw-work/SOUL.md` — anti-sycophancy persona rules (already aligned)
- `~/work/claude/CLAUDE.md` § "Anti-hallucination compact" — `[VERIFIED]`/`[INFERRED]` discipline
