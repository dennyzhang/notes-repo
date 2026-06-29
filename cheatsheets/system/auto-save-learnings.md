# Auto-Save Session Learnings — Cheatsheet

**Load when:** Session is ending or context is about to compress after non-trivial work.

## Quick checklist

Before ending a substantive session, scan for unsaved learnings:

1. **Decisions made?** → Save as `project` memory (what was decided + why)
2. **Operator corrections?** → Save as `feedback` memory (the rule + why + how to apply)
3. **New patterns discovered?** → Save as `project` or `reference` memory
4. **Files moved/created/deleted?** → Save as `project` memory if the change isn't obvious from git

## Skip if

- Session was routine (answered a question, ran a command)
- All learnings are captured in committed files already
- Nothing novel happened

## Format

Save in the **working directory where the session started** (the space / project root), under a `learnings/` subdirectory. One file per learning. Frontmatter:

```yaml
---
name: short-kebab-case-slug
description: one-line summary — be specific, this is used for relevance matching
metadata:
  type: project | feedback | user | reference
---
```

Body: rule/fact first, then `**Why:**` and `**How to apply:**` lines for feedback/project types.

Update `MEMORY.md` index with a one-line pointer (under 150 chars).

## Anti-patterns

- Don't dump the whole session into one memory file
- Don't save what's already in the commit message
- Don't save ephemeral state (intermediate debugging, temp file paths)
- Don't manufacture learnings when nothing was learned
- Don't save code patterns or architecture (derivable from reading code)

## Full guide

`~/notes/users/dennyzhang/scripts/auto-save-learnings.md`
