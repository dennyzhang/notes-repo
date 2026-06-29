# Communication Cheatsheet

Best practices for 1:1s, cross-team asks, Workplace posts, and relationship building. Calibrated to Denny's communication patterns (broadcasting → depth) and Goal 3 (become the person people invest in).

## The Gravity Model (Source: Goal 3 Research)

Pull, don't push. Become someone people are drawn to, not someone who broadcasts at them.

| Force | What it means | Anti-pattern it replaces |
|-------|--------------|------------------------|
| **Vulnerability before expertise** | Share what you're uncertain about before what you've built | Leading with "I built X" (closes conversation) |
| **Ask, then stay** | After they answer, ask one follow-up. The second question is where real conversation starts. | Ask one question → immediately offer your solution |
| **Solve their problem, not yours** | Before every message: "What is this person stuck on right now?" | Sharing your doc/tool with 8 people simultaneously |

## Pre-Send Filter

Before sending ANY message, ask:

1. **Is this about THEM or about ME?** If it's about you (sharing, announcing, stamping), rethink.
2. **Does this person need this right now?** If not, don't send it.
3. **Am I asking or telling?** Target ratio: 1:1. You're currently at 1:20.
4. **Will this thread go 3+ exchanges?** If not, it's broadcasting, not conversation.

## 1:1 Meeting Prep

### Before the meeting (2 min prep)

1. Read their recent diffs (last 7 days): `knowledge_filtered_search(doc_types: ["DIFF"], authors: ["<their_fbid>"])`
2. Check FOLLOWUPS.md for items mentioning this person
3. Read their people profile if it exists: `context/people/<NAME>.md`
4. Prepare ONE genuine question about their current challenge

### During the meeting

| Do | Don't |
|----|-------|
| Start with a question about their work | Start with your updates |
| Ask "how did you approach that?" after every explanation | Offer your solution immediately |
| Note specific things they said (for follow-up) | Take generic notes |
| Stay in their problem for 3+ exchanges | Switch to your topic after 1 exchange |

### After the meeting (1 min)

- Write down 1 specific follow-up action
- Send a follow-up message within 24 hours referencing something specific they said
- Update their people profile with new context

## Cross-Team Communication

### Asking for something

```
Hi [name],

I'm working on [your context, 1 sentence] and hit [specific problem].

Your team's [specific system/expertise] is the closest fit because [why].

Would [specific ask — not vague "can you help?"] work? I'd need it by [date].

Happy to [what you offer in return — context, a review, a shared tool].
```

**Rules:**
- Name the specific person, not the team alias
- State what you need in the first 3 sentences
- Include a deadline
- Offer something in return (reciprocity)

### Sharing wins (Workplace posts)

```
[One-line result with metric]

Problem: [What was broken, who was affected]
What we did: [Your specific contribution]
Impact: [Before → After with numbers]
What's next: [Follow-up or how others can use this]

Thanks: [Specific people with specific contributions]
```

**Rules:**
- Lead with the result, not the effort
- Name specific people's contributions (not "thanks to the team")
- Keep under 10 lines
- Don't share the same thing with 8 people — share with the 1 person who has the problem it solves

## Giving Feedback

### The SBI Framework (Source: Center for Creative Leadership)

| Element | What it is | Example |
|---------|-----------|---------|
| **Situation** | When and where | "In yesterday's design review..." |
| **Behavior** | What they did (observable, not interpreted) | "...you raised the failure mode question that nobody else asked..." |
| **Impact** | Effect on you/team/outcome | "...which changed the design to include retry logic. That would have been a SEV without it." |

**Rules:**
- Behavior must be observable (not "you seemed disengaged")
- Impact must be concrete (not "it was helpful")
- Deliver within 48 hours (context fades)
- Positive feedback in public, constructive in private

## Anti-Patterns (from GChat analysis)

| Pattern | Signal | Fix |
|---------|--------|-----|
| **Send-then-switch** | Send message, close tab, never follow up | Re-read their last message after sending. Follow up. |
| **Uninvited teaching** | See someone's inefficiency, offer solution unprompted | Ask first: "How are you approaching X?" |
| **AI tools as identity** | Urge to share a tool/demo | Ask: "What's frustrating about your workflow?" |
| **Compliment dead-end** | "That's impressive" + done | Add: "How did you approach it?" |
| **Broadcasting** | Same doc shared with 5+ people | Share with 1 person who has a specific problem it solves |

## See Also

`career/psc.md` (framing collaboration impact), `context/myself/GOAL3-PRACTICE.md` (practice plan), `context/myself/PREFS.md` (communication style awareness)
