# Knowledge Sharing Cheatsheet

Writing effective internal knowledge sharing posts and presentations. Complements `career/launch-post.md` (for product launches) and `career/sharing-post.md` (for Workplace posts).

## Pre-Work: Know Your Audience

Before writing anything, answer these 3 questions:

1. **What does this audience already know?** List 3 things they'd roll their eyes at if you explained them. Those are your table stakes — cut them entirely.
2. **What's their current level?** Start one step beyond it. Not two steps (too advanced), not zero steps (table stakes).
3. **What format are they used to?** A 13-min org talk needs tables and hooks. A 45-min deep dive can use more prose. A Workplace post needs a punchline in the title.

## Hard Rules

5 rules that prevent the most common failures. (Source: autolearn sharing doc, 7 revision rounds + oncall and OT sharing experience.)

| # | Rule | Recipe |
|---|------|--------|
| 1 | **Cut table stakes** | List 3 things the audience already knows. Delete them. Start where their knowledge ends. |
| 2 | **Scannable in 2 seconds** | Every concept gets a table or a bold one-liner. If it takes a paragraph to explain, you haven't clarified it yet. |
| 3 | **Capability expansion > time savings** | Take your before/after metric. Ask: "what can they do NOW that was impossible before?" That's your headline. "Deep dive in minutes" > "saves 35 min." |
| 4 | **Team-adoptable** | Every technique needs a "Team recipe" line: who does what, how long, what they get. "Any TL sets this up once, runs forever." |
| 5 | **Proof for every claim** | Name the specific artifact. Not "it works" but "specifically, this rule was auto-added from this reviewer comment and has been enforced in every session since." |

## Narrative Structure (4 layers)

- **Layer 1: Hook** — 2-3 jaw-dropping examples before any framework. The "I don't do X" pattern: "I don't write Google Docs. I leave 3 comments, Claude edits — 2 min." Earns attention.
- **Layer 2: Framework** — One table that captures the key idea. Scannable in 2 seconds. Conversational framing: "You know how...? What if...?"
- **Layer 3: Patterns** — 2-3 reusable techniques with proof. Each one: table + key design + team recipe + inline demo. The audience test: can someone steal this and use it next week?
- **Layer 4: Honest gaps + CTA** — "What we're working on" (before the CTA, not after). Then: "Try this week" action table.

## Checklist (7 items)

- [ ] **Audience calibrated** — table stakes identified and cut
- [ ] **Hook before framework** — 2-3 "I don't do X" examples up front
- [ ] **Every concept scannable** — tables, not paragraphs
- [ ] **Framed as capability, not efficiency** — what's now possible, not what's faster
- [ ] **Every technique team-adoptable** — "Team recipe" line with who/how/time
- [ ] **Every claim has proof** — named artifact, not assertion
- [ ] **Conversational tone** — "You know how...?" not "The default workflow involves..."

## Anti-Patterns

| Wrong | Right | Why |
|---|---|---|
| Explaining basics the audience knows | "Everyone here uses X — here's what's beyond that" | Signals you don't know your audience |
| Feature dump (I built X, Y, Z) | Problems solved, not tools built | Nobody cares what you built; they care what it fixes |
| Prose paragraphs in a talk doc | Table for every concept | 13-min talks are scanned, not read |
| "Saves 35 minutes" as the headline | "Deep dive any area in minutes, not hours" | Efficiency is forgettable; new capability is memorable |
| "I have 20 cron jobs" | "Any TL sets this up once, runs forever" | Personal showcase vs team playbook |
| "It works great" (no proof) | "This specific rule was auto-added from this reviewer comment" | Claims without artifacts are noise |
| Standalone demo section | One-line "Demo:" inline with each technique | Separate section repeats what you already said |
| "What's Still Broken" as last section | "What We're Working On" before the CTA | Honest gaps before the ask, not after |
| Discussion Qs about your work | Qs about THEIR work: "What would change if...?" | The sharing is for them, not about you |

## Common Mistakes

Specific errors from real sharings, with the correction.

| What happened | Correct approach |
|---|---|
| Opened with "Most people use Claude as a stateless chatbot" — audience pushed back ("not true, we use it statefully") | Don't assume the audience's level. State what you know about THEIR level, then start one step beyond. |
| Used "1:1 meeting prep" as a hook example — audience said "that's table stakes" | Test each example against: "Would this impress the most experienced person in the room?" If no, cut it. |
| Wrote 3 examples as prose paragraphs — feedback: "not scannable" | Bold the first sentence of each example. Or use a table with Before/After columns. |
| Merged demo text into technique paragraphs mid-sentence — created broken text | Demo notes go as a separate `Demo:` line after the technique, never inline within a sentence. |
| Framed everything as personal ("I told Claude," "my contacts," "my setup") — feedback: "make it org-adoptable" | Every "I" statement needs a "Team recipe" counterpart. Alternate between "here's what I do" and "here's how any engineer does it." |
| Kept "What's Still Broken" right before "Try This Week" — undercut the CTA | Rename to "What We're Working On." Include mitigations so it reads as progress, not failure. |

## Template

Flexible structure — adapt to your topic, don't force-fit.

```
# [Insight in Title Form]
Author, Team | Duration

## The Key Idea (⅓ of time)
[Conversational hook: "You know how...?"]
[2-3 "I don't do X" examples — the jaw-droppers]
[One framework table — scannable in 2 seconds]
[Capability framing: what's now POSSIBLE, not just faster]
[Before/after proof table]

## Patterns (½ of time)
### Pattern 1: [Name]
[Table: input → what happens → unlock]
Key design: [one line]
Team recipe: [one line — who, how, time]
Demo: [one line]

### Pattern 2-3: [Same structure]

## What We're Working On
[2 honest gaps + mitigations]

## Try This Week
[Table: # | Action | Time]

## Discussion
[2 questions about THEIR work]
```

**Adapt for your format**: 13-min talk → more tables, fewer words. 45-min deep dive → can afford more prose in patterns. Workplace post → punchline in title, skip the template structure.

## Key Insight

Knowledge sharing ≠ launch post. A launch post says "here's what we shipped, try it." A knowledge sharing says "here's what I learned, steal it." The audience test: would someone on a different team find this useful?

The strongest sharings frame value as **capability expansion** — "you can now deep dive in minutes" — not efficiency — "saves 35 min." Time savings is incremental and forgettable. New capabilities are transformative and memorable.
