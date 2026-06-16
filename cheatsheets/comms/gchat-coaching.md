# GChat Communication Cheatsheet

Quick reference for live message coaching + daily review. Loaded by /my-comms and routine doc.

## Decision Tree (use this when drafting)

```
1. WHO am I writing to?
   → Check recipient playbook below
   → Pull their last 5 messages + 3 diffs

2. WHAT'S my opening pattern? (rotate, never repeat same pattern twice in a row)
   a) Direct ask: "Quick q about your D12345..."
   b) Share-first: "btw I hit [problem] — you dealt with this right?"
   c) Observation: "Your D12345 fixes the issue we discussed"
   d) Social: "nice post" / "welcome back" (short, no ask)

3. DOES IT PASS the top-3 check? (priority order for Denny)
   #1: Ends with a question? ← YOUR BIGGEST GAP (95:5 tell:ask)
   #2: Human tone? (no filler: "curious about", "wondering if", "I was thinking")
   #3: Credits someone or references THEIR work first?

4. OUTPUT: Line 1 (copy-paste) + Rationale (non-obvious insight only)
```

## Recipient Playbook

| Person | Relationship | They Want | Open With | Avoid |
|--------|-------------|-----------|-----------|-------|
| Shumin (EM) | Manager | Substance + impact framing, decisions made | "Decided to X because Y" or "Need your input on Z" | Tool demos, AI workflow details, "I built X" |
| Catalin (TL) | Close peer | Technical depth, partnership on shared problems | Reference his specific diff/thread | Generic praise, "you should try X" |
| Paul (collaborator) | Warm | Actionable next steps, status on shared work | "Quick update on X — next step is Y, any blockers?" | Long context-setting, reexplaining what he already knows |
| Shuguang (adjacent) | Lukewarm | Recognition of his domain expertise | Question about his area that shows you read his posts | Telling him about YOUR tools |
| Michael (newer) | Building | Genuine curiosity about his work | "What's taking most of your time?" | Jumping to advice before understanding his context |
| Chong (cross-team) | Warm, non-transactional | Relationship-first, no work ask | Lunch, "how's it going", share something useful with no strings | Transactional asks before relationship is warm |
| Keith/Rodolfo (IC7 peers) | Cold, observing | Respect for their seniority + genuine questions | Technical question showing you studied their work | "Let me show you my tool" |

## Denny's Voice (positive examples to match)

Good Denny messages (the ones that got engagement):

| Message | Why It Worked |
|---------|--------------|
| Cron fix to Catalin: 1-line solution + technical explanation | Solved HIS problem, shared expertise, not broadcasting |
| OT master agent proposal: problem framing before solution | 6 teams aligned because he led with the problem, not the tool |
| "I agree with Denny" (Ankur's endorsement) | Result of sharing a clear position (SLO threshold bump) with reasoning |

Bad Denny messages (the ones that fell flat):

| Message | Why It Failed |
|---------|-------------|
| AI workflow shares to PE Internal | Broadcasting personal tools nobody asked about — reads as newsletter |
| Diff announcements without questions | "Landed D12345" — closes conversation, no engagement possible |
| 100% to MetaClaw, 0% to humans (full day) | Talking to AI about humans instead of talking to humans |

## Daily Review Output

```
### GChat Coaching — YYYY-MM-DD

**Score**: X/10
**Human messages**: N (target: 3+/day)
**Ask:Tell**: X:Y (target: 30%+ questions)
**Loops closed**: N/M

**Win**: [one thing you did well, with quote]
**Fix**: [one message rewritten — original → coached]
**Tomorrow**: [one specific action]
```

Keep to 5 lines. If score 8+, just say "Strong day" and skip the fix.

## Priority-Ranked Checks (Denny-specific)

Based on observed patterns, in order of impact:

1. **ASK A QUESTION** (95:5 tell:ask ratio — #1 gap)
2. **Reference THEIR specific work** (not generic "saw you've been active")
3. **Human tone** (no filler verbs, contractions, casual)
4. **Follow up within 24h** (send-then-switch pattern)
5. **Route to 1 person** (broadcasting pattern)
6. **Leave 20% gap** (over-explaining pattern)
7. **Credit someone** (solo credit pattern)

Checks 1-3 apply to EVERY message. Checks 4-7 apply during daily review.

## Anti-Patterns in Coached Messages

| Anti-Pattern | Example | Fix |
|---|---|---|
| Filler verbs | "Curious about...", "Wondering if..." | Cut. "Your X affects Y?" |
| Same formula x4 | [Reference work] + [question] every time | Rotate: direct ask, share-first, observation, social |
| Generic when data exists | "noticed you've been active" | Pull diffs/posts, cite D-numbers |
| Same tone for everyone | Casual to manager, formal to peer | Check recipient playbook above |
| Rationale repeats basics | "Ends with question" (5th time) | Only non-obvious insight for THIS message |
| Sounds like any AI | "I'd love to connect about..." | Must sound like Denny with codebase knowledge |
| Coaching without data | Draft message without checking their recent activity | ALWAYS pull last 5 msgs + 3 diffs first |

## Message Templates (starting points, not scripts)

**Offering help on THEIR problem:**
> [1-line fix/suggestion]. want me to share the full [script/config/approach]?

**Engaging with their post:**
> your [specific thing] — does that change [impact you care about]?

**Status update (PE Internal daily):**
> OT reliability: [1-line what you're doing today]. [1 question or offer]

**Following up after a conversation:**
> following up on [topic] — [what you found/did since]. thoughts?

**Reconnecting (>2 weeks silent):**
> hey, saw your [recent diff/post] — [genuine observation]. how's [their project] going?

## Scoring Rubric (daily review)

| Score | Meaning | Criteria |
|-------|---------|----------|
| 9-10 | Exceptional | 3+ human msgs, 30%+ questions, followed up on all threads, credited someone, varied pattern |
| 7-8 | Strong | 3+ human msgs, 20%+ questions, followed up on most threads |
| 5-6 | Average | 1-2 human msgs, some questions, missed 1-2 follow-ups |
| 3-4 | Weak | 0-1 human msgs, all statements, multiple missed follow-ups |
| 1-2 | Absent | 0 human msgs, 100% to AI, no presence in team channels |

Yesterday (2026-04-03) would score: **2/10** (0 human msgs, 100% to MetaClaw).

## What NOT to Say (relationship damage prevention)

| Recipient | Never Say This | Why It Damages |
|-----------|---------------|----------------|
| Shumin (EM) | "I built this cool AI tool" without impact framing | He needs to justify your IC7 case — give him ammunition, not demos |
| Catalin (TL) | "You should try X" on his domain | He's the TL — teaching him his domain is condescending |
| Any peer | "I found a problem in your code/config" in a group chat | Public callout. DM first, always. |
| Anyone senior | Long messages explaining context they already know | Wastes their time. They'll ask for context if they need it. |
| Anyone | Forwarding AI output without editing | "From Claude:" as a prefix makes you a relay, not a thinker |
| Group chats | Multiple messages in a row (4+ rapid-fire) | Dominates the channel. Combine into 1 message. |

## Feedback Loop

After Denny sends a coached message, track in the daily review:
- **Sent as-is**: coaching was on target → reinforce this pattern
- **Edited before sending**: coaching missed something → what did he change and why?
- **Didn't send**: coaching was wrong → what was the objection?
- **Got a response**: message landed → what kind of response? (engagement vs acknowledgment vs silence)

Track in: `context/cache/state/COMMS-FEEDBACK.md` (append-only, 1 line per interaction)
Format: `YYYY-MM-DD | recipient | sent/edited/skipped | response_type | note`

This feeds back into the priority ranking — if "question" consistently gets engagement but "credit" doesn't change response rate, deprioritize credit coaching.

_Last updated: 2026-05-12. Maintainer: dennyzhang._
