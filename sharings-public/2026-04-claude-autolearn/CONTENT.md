# Make Claude Autolearn For You and About You

Org anchor week sharing — March 2026

---

## 1. The Routine Doc

Nightly command (`/my-debrief`) that asks: "Did today advance my goals?" and "Did I behave like a senior lead?"

It works because Claude reads my persistent `CAREER-GOALS.md` and `PREFS.md` at runtime — it knows what "good" looks like for me specifically. No memory = generic advice. With memory = personalized calibration against my actual gaps and targets.

## 2. People Profiles

~40 structured profiles, one per collaborator. Auto-refreshed from org chart, diffs, Workplace posts, and GChat DMs.

Each profile has: identity, current focus, recent work, conversation history, "how to work with them," and manual annotations (coaching notes, relationship context).

**Key design:** Two zones. Auto-refreshed data (diffs, org) that stays current without effort. Manual annotations (coaching notes, observations) that never get overwritten. This separation is what makes it usable — current without losing nuance.

Before a 1:1, Claude already knows their recent work, open threads, and what they care about.

## 3. Career Coach — Crispy and Problem-Driven

Generic coaching gives platitudes. The fix: feed Claude your specific weaknesses with evidence.

Every weakness in my `PREFS.md` has proof attached — e.g., "5 of 7 recent messages to manager were AI tool shares, not substance." Claude applies a pre-send filter in real-time: "Does this build a system others operate, or showcase my personal skill?"

**The key insight:** A coach is only as good as the self-awareness data you give it. "I'm great at X" is useless. "I repeatedly do Y when I should do Z, here's proof" — that changes behavior.

## What's Still Broken

Two open gaps I haven't solved:

1. **Multi-server coordination.** Claude on my devserver can't enforce its own rules when SSH-ing to a GPU server to update diffs or run tests. Hooks, guardrails, memory — none of it carries across the SSH boundary. The "coordinator" pattern (one Claude orchestrating work across machines) breaks down here.

2. **Instruction following.** Claude repeatedly ignores explicit CLAUDE.md rules. I've written "always run linter before submitting" multiple ways, multiple times. Still get red diffs with lint errors. The memory exists — compliance doesn't. Common sense enforcement is the hardest unsolved problem in this space.

## Where This Is Heading

My current system stores people, goals, and preferences as separate files. It works, but they're siloed — I can't ask "what's connected to this project?" and get an answer that spans people, decisions, and artifacts.

The next level is **cross-entity linking**: typed entities (people, projects, decisions, artifacts) wired together with semantic links, so the AI actually understands how your work connects. Think Zettelkasten for your AI assistant. MetaClaw's upcoming "Brain" overhaul is exploring exactly this — 9 entity types with cross-entity search.

The hard part isn't the data model. It's making the AI reliably populate and maintain it. That circles back to gap #2: memory without compliance is just a database nobody updates.

## How to Get Started

You don't need 40 profiles and a nightly routine on day one. Three steps:

1. **Write `PREFS.md`** — 3 weaknesses with evidence. Immediate coaching value from your next session.
2. **Add one people profile** — your manager. See how 1:1 prep changes when Claude already knows their priorities and your open threads.
3. **Build a routine command** — once the first two feel natural, add a nightly debrief that scores your day against your goals.

---

**Discussion questions:**
- What do you persist across sessions — just code context, or personal/career stuff too?
- How do you handle data that should auto-update vs. data that should never be overwritten?
