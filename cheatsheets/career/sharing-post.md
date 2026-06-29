# Cheatsheet — Sharing Post Quality Gate

Auto-apply when writing or reviewing Workplace sharing posts, team updates, technique sharings, or cross-group knowledge posts.

## Core Rules

### Rule 1: Skip AI Slop by Default

AI-generated posts waste the reader's time. Default behavior: strip all AI filler and focus on the most valuable content only. Every sentence must earn its place — if removing it doesn't lose information, remove it.

Kill on sight:

| Signal | Fix |
|--------|-----|
| Vapid opener ("In today's...", "I'm excited to share...") | Delete. Start with the insight. |
| AI vocabulary ("delve", "foster", "underscore", "pivotal", "tapestry") | Plain words: "explore", "support", "show" |
| Importance inflation ("plays a pivotal role in the broader context") | Say what it does, concretely |
| Dramatic question ("The result? It worked.") | Just say it worked. |
| Filler padding (same thing said 3 ways) | Pick the best sentence. Delete the rest. |
| Not-X-but-Y repeated | Once is rhetoric. Twice is a pattern. Three times is AI. |
| Sycophantic close ("I hope this helps!") | Cut. End with a next step or nothing. |
| Over-formatted (emoji bullets, nested bold headers) | Flatten. Workplace posts are conversational. |

### Rule 2: Senior Staff Bar

Every post must demonstrate strategic thinking, not just individual output:

| Junior framing (avoid) | Senior framing (use) |
|------------------------|---------------------|
| "I built a script that does X" | "We kept losing N hours/week to X. This removes the category." |
| "Here's a cool tool" | "This changes how the team operates: before vs. after" |
| "I fixed this problem" | "This pattern affected 5 teams. Here's the system fix." |
| "Check out my diff" | "This unblocks Y for partner teams. Adoption so far: Z." |
| Describing what you did | Framing why it matters to the org |

**Filters:**
- Does this show a system others can operate, or just a task you completed?
- Is the insight counterintuitive or non-obvious? If every sentence is common knowledge, the post adds no value.
- Would you present this in a calibration discussion? If not, it's not worth a post.

### Rule 3: TL;DR First (Tweet-Length)

Every post opens with a TL;DR: one sentence, 280 characters max. This is what people see before clicking "See more." If it doesn't hook, nothing else matters.

**Format:** Bold the TL;DR. No label needed — just make the first line the summary.

| Bad TL;DR | Good TL;DR |
|-----------|-----------|
| "I want to share some learnings about debugging training jobs that I've found helpful over the past few weeks." (141 chars of nothing) | "OT training job debugging went from 45 min to 5 min — one script replaces 6 manual steps." (91 chars, specific, compelling) |
| "Here are some best practices for oncall that our team has been developing." (75 chars, vague) | "We cut oncall page-to-resolution from 25 min to 8 min by pre-loading runbook context at shift start." (101 chars, quantified) |

### Rule 4: "So What" Test

Within the first 2 sentences after the TL;DR, answer: **why should the reader care?** Frame in their world, not yours.

| Fails "so what" | Passes "so what" |
|-----------------|-----------------|
| "Built a monitoring dashboard" | "3 SEVs last quarter had 20+ min detection lag. This dashboard catches them in under 2 min." |
| "Automated our weekly report" | "The team spent 4 hours/week compiling status. Now it's zero — generated from diffs and tasks automatically." |

### Rule 5: One Concrete Takeaway

The reader must be able to do something different after reading. A post without a takeaway is a diary entry.

Good takeaways:
- A command to run: `scripts/debug-ot-job.sh <job_id>`
- A pattern to adopt: "Add this hook to your CLAUDE.md"
- A decision to make: "If your team hits X, do Y instead of Z"
- A link to try: "Install: `claude-templates skill X install`"

### Rule 6: System, Not Instance

Frame as removing a category of problem, not fixing one thing. This is the difference between a shareable insight and a status update.

| Instance (skip posting) | System (worth sharing) |
|------------------------|----------------------|
| "Fixed a flaky test" | "Found the pattern causing 12 flaky tests across 3 teams — here's the fix and the lint rule that prevents recurrence" |
| "Debugged a MAST job failure" | "MAST OOM failures had no actionable error message. Built a diagnostic that surfaces the real trigger — adopted by 2 other teams" |

### Rule 7: Show, Don't Describe

A screenshot of the tool working replaces 5 paragraphs. Attach inline, not as a link.

Priority: screenshot > code snippet > bullet list > prose paragraph.

## Structure

| Audience | Format | Length |
|----------|--------|--------|
| Workplace group (broad) | TL;DR + 2-3 short paragraphs + screenshot/link | 100-250 words |
| Team group | TL;DR + casual detail, code snippets OK | 50-400 words |
| Cross-org sharing | TL;DR + structured sections, link to doc | 150-350 words + link |
| Leadership-visible | TL;DR + impact-first, quantified, structured | 100-250 words |

**Layout:**
1. TL;DR (bold, first line, ≤280 chars)
2. The problem — what was broken, how bad (1-2 sentences)
3. The solution — what changed, concretely (1-2 sentences)
4. The result — measured impact (numbers)
5. The takeaway — what the reader can do (link, command, pattern)

## Meta-Specific Norms

| Rule | Why |
|------|-----|
| No markdown headers in Workplace | Renders poorly. Use bold text + line breaks. |
| Link diffs/tasks by number | D12345678, T12345678 auto-link in Workplace |
| Tag people with @ | "@alice and @bob" not "thanks to the team" |
| Screenshot inline | Attach directly, don't link to external image |
| Right group | Claude Skills Announcements for skills, Claude Code Community for general |

## Anti-Patterns

### The "AI Summary Post"
```
BAD:
I'm excited to share a powerful new approach to debugging training
jobs. In today's complex ML infrastructure landscape, engineers often
face challenges when diagnosing failures. This solution leverages
advanced techniques to streamline the debugging workflow, fostering
better outcomes for the team.
- Enhanced visibility: Better logs
- Streamlined workflow: Fewer steps
- Improved outcomes: Faster fixes
I hope this helps the team!
```

```
GOOD:
OT job debugging dropped from 45 min to 5 min — one script
replaces 6 manual steps.

We kept hitting GPU memory errors with no useful stack trace. The
error message pointed to the wrong operator. Built a script that
pulls the MAST error, cross-refs host memory via below, and
surfaces the actual OOM trigger.

Try it: scripts/debug-ot-job.sh <job_id>
Landed in D12345678. @alice validated on 3 real failures last week.
```

**Why the good version works:**
- TL;DR is the first line (89 chars, specific, quantified)
- Problem is concrete (GPU memory errors, wrong operator)
- Solution is one sentence, not a paragraph
- Takeaway is a command you can run right now
- Social proof (@alice validated, 3 real failures)

## Preflight (7 checks before posting)

1. **TL;DR**: first line ≤280 chars, specific, would stop someone scrolling?
2. **So what**: reader knows why they should care within 2 sentences?
3. **Bar**: framed as system/category, not instance/task?
4. **Slop**: zero AI vocabulary, zero filler paragraphs?
5. **Takeaway**: reader can do something different after reading?
6. **Specifics**: at least one number, diff, or name?
7. **Length**: under 250 words for broad audiences?

All 7 must pass. Fix before posting.

## See Also

`cheatsheet-workchat.md` (Work Chat messages), `career/project-doc.md` (project proposals)
