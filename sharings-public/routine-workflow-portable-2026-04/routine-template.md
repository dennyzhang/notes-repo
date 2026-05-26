# Daily Routine Prompt Template

This template defines what Claude produces for each day's routine entry. Customize the sections, priorities, and coaching criteria to match your role.

## Prompt Structure

```
You are writing today's daily work routine for [NAME] on [DATE].

## Context Files (pre-loaded)
- IDENTITY.md: role, goals, known weaknesses, work style
- CAREER-GOALS.md: current H-cycle goals and milestones
- People profiles: per-person context for each meeting attendee
- FOLLOWUPS.md: pending follow-up items with check-after dates

## Data Sources (pre-fetched)
- Calendar: today's meetings with attendees
- GChat: recent messages from configured spaces
- Diffs: authored and reviewing diffs with status
- Workplace: recent posts from relevant groups
- SEVs/Oncall: active incidents and oncall context

## Output Format

### Action Rows (3-5 items, ordered by priority)
| Priority | Action | Context | Time Est |
|----------|--------|---------|----------|
| RIGHT NOW | [What to do] | [Why it matters today] | 15 min |
| DEEP WORK | [What to do] | [Career-critical reason] | 90 min |
| DECISION | [What to decide] | [Options + recommendation] | 15 min |
| OPS | [Operational task] | [Context] | 15 min |

### Coaching Signals
- IC[N] SCORE: YES/NO — [evidence of architectural decisions vs pure execution]
- Ship rate: X/Y this week
- Scope: N active projects (target 2-3), M active follow-ups (cap 10)
- Comms: Ask:tell ratio ~1:N. [Specific observation + suggestion]

### Diff Review Queue
- DXXXXXX — [short reason it matters / review angle]

### Meeting Prep (per meeting)
**[Time] [Meeting Name] with [Attendees]**
- Shared context: [recent interactions, open threads]
- Prep: [what to review before, what to bring up]

### Rules
- Career-critical items always rank above operational items
- Overdue items get "DEFERRED N DAYS" tag
- If no meetings today, omit Meeting Prep section
- Weekend: deprioritize ops, emphasize deep work
```

## Scoring Criteria

The validation scorer checks:
- Correct date in output
- Minimum 3 action rows
- At least 1 goal reference per action
- IC score assessment present
- Meeting prep for each meeting
- Word count within budget
