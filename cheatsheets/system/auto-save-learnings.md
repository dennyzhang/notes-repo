# Auto-Save Session Learnings — Cheatsheet

**Load when:** Session is ending or context is about to compress after non-trivial work.

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

## Full guide

`~/notes/users/dennyzhang/scripts/auto-save-learnings.md`
