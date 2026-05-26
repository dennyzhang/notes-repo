# Auto-Save Session Learnings

Generic capability for any MyClaw instance to automatically persist learnings at session end.

## Setup

Add this block to any instance's `RULES.md` or `CLAUDE.md`:

```markdown
## Auto-save session learnings

At the END of every substantive session (before the operator leaves or context
compresses), proactively save learnings to memory. Don't wait to be asked.

**What to save:**
- Project decisions or state changes
- New operational patterns discovered
- Feedback/corrections from the operator
- Cross-references discovered

**What NOT to save:**
- Ephemeral debugging steps or intermediate findings
- Anything already captured in committed files
- Routine task completions with no novel learning

**Where:** Save in the working directory where the Claude session started (the
space directory / project root). Create a `learnings/` subdirectory if it
doesn't exist. One file per learning, not a dump. This keeps learnings
co-located with the project they belong to — not scattered in a global
memory path.

**Trigger:** When the session involved non-trivial work (file edits,
investigations, decisions), scan for unsaved learnings before the final reply.
If nothing novel was learned, skip silently.
```

## Memory File Format

```markdown
---
name: short-kebab-case-slug
description: one-line summary used to decide relevance in future conversations
metadata:
  type: user | feedback | project | reference
---

Content here. For feedback/project types, structure as:
rule/fact, then **Why:** and **How to apply:** lines.
Link related memories with [[their-name]].
```

## Memory Types

| Type | When to save | Example |
|---|---|---|
| `user` | Learn about the operator's role, preferences, knowledge | "user is a PE on MRS OT, prefers terse responses" |
| `feedback` | Operator corrects or confirms approach | "don't mock DB in tests — got burned last quarter" |
| `project` | Ongoing work, goals, decisions not in code/git | "merge freeze begins 2026-03-05 for mobile release" |
| `reference` | Pointers to external systems | "pipeline bugs tracked in Linear project INGEST" |

## Cron Companion (Phase 2)

For truly automatic extraction without relying on the LLM remembering:

1. Create a cron job that runs every 4-8 hours
2. Uses `myclaw-conversations` skill to scan recent conversations
3. Extracts novel learnings (decisions, corrections, discoveries)
4. Writes to memory directory, deduplicating against existing entries
5. Posts a summary to the operator's gchat if anything significant was saved

Cron prompt template:
```
Scan conversations from the last 8 hours. For each substantive session,
extract learnings per the auto-save-learnings cheatsheet at
~/notes/users/dennyzhang/cheatsheets/system/auto-save-learnings.md.
Deduplicate against existing memory files. Save only novel, durable insights.
Skip ephemeral debugging and routine completions.
```
