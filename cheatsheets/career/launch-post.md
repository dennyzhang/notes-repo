# Launch Post Cheatsheet

Best practices for writing high-quality launch posts for infra teams. Based on analysis of 8 real Meta Workplace posts (4-269 reactions).

## Narrative Structure

Every launch post tells a three-layer story:
- **Layer 1: Problem** — What problem are we solving? Why is it critical to the business? Why is it urgent now?
- **Layer 2: Win** — What did we achieve? Include both immediate results (metrics, adoption) and future potential (what this unlocks).
- **Layer 3: Complexity** — Why was this hard? What made it non-trivial? (cross-team coordination, scale challenges, tricky edge cases, novel architecture). This earns recognition — if it looks easy, nobody appreciates the effort.
- **Layer 4: Technical depth** — How does it work? Code snippets, architecture details for engineers who want to go deeper.

Layers 1-2 are for leadership. Layer 3 earns recognition by showing difficulty. Layer 4 is for engineers who want depth.

## Principles

1. **Title IS the value prop** — not "Announcing X" but "X can now do Y, Z, and W"
2. **TL;DR first, always** — 3-5 bullets immediately after the title
3. **"You" > "We"** — speak to the reader, not about the team
4. **Show, don't describe** — screenshots, code snippets, clickable demos
5. **Honest about limitations** — sets expectations, builds trust
6. **#thanks tags drive engagement** — each tag is a notification that pulls someone in

## Checklist

- [ ] Title contains the value prop, not just "Announcing [tool name]"
- [ ] TL;DR with 3-5 bullets is first thing after title
- [ ] Problem/context explains WHY this matters (1-2 sentences)
- [ ] At least one hard metric (time saved, adoption numbers, perf improvement)
- [ ] At least one screenshot or code snippet
- [ ] "Try it now" link — bunnylol, direct URL, or clickable example
- [ ] Honest about limitations — what doesn't work yet
- [ ] "What's Next" section — 2-3 upcoming improvements
- [ ] #thanks tags for all contributors
- [ ] Feedback channel linked
- [ ] "You" language throughout
- [ ] No jargon without explanation

## Anti-Patterns

| Anti-pattern | Fix |
|---|---|
| Feature-dump without problem framing | Start with the pain point |
| No visuals (pure text wall) | Add 1+ screenshot |
| Generic CTA ("We welcome feedback") | "Click here to try it" |
| Link to doc instead of inline content | Put the content in the post |
| No #thanks tags | Tag every contributor |
| Burying the lead (background first) | Punchline in title + TL;DR |

## Template

```
# [Tool Name]: [Value Prop in Plain English]

## TL;DR
- [Benefit 1]
- [Benefit 2 — quantified]
- [Benefit 3]
- Try it: [link]

## Why This Matters
[1-2 sentences: what problem, who affected, how painful]

## What's New
[Feature + screenshot or code snippet for each]

## Known Limitations
[What doesn't work yet + when it will be fixed]

## What's Next
[2-3 upcoming improvements]

## Try It
[Direct link + docs link]

## Acknowledgements
#thanks @person1 @person2 for [specific contributions]
```

## Key Insight

The #1 differentiator: **"try it now" links**. Posts with a clickable link to try the thing get 10-50x more engagement than posts that describe what was built. The #2 factor: **#thanks tags** — each is a notification.

## Evidence Sources

| Post | Reactions | Key Pattern |
|---|---|---|
| Metamate Recap Improvements | 269 | Clickable try-it links for every example |
| Metamate Agent Faster | 216 | Title = 3 concrete benefits, cultural moment tie-in |
| Multi-Step Mode | 149 | Honest about limitations, 3 screenshots |
| MAST on Fluent2 | 43 | "One more line of code" — trivial adoption framing |
| EYS Tooling | 33 | Lead with adoption numbers (2770 projects, 1126 EYS) |
| Spares Optimization | 4 | Anti-pattern: no problem framing, no metrics, no visuals |
