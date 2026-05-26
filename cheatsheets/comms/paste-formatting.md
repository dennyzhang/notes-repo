# Paste & Plain-Text Formatting Cheatsheet

Rules for formatting content in `pastry` pastes and other non-markdown-rendering surfaces. Load before creating any paste.

## The core problem

Markdown (pipe tables, `**bold**`, `# headers`) only renders in markdown-aware viewers. Many Meta tools display raw text. If you write markdown for a plaintext viewer, the reader sees garbage.

## Where markdown renders vs doesn't

| Surface | Renders markdown? | Format to use |
|---------|-------------------|---------------|
| Workplace posts | YES | Markdown OK |
| GChat messages | Partial (bold, links, code blocks — NO tables) | Plaintext tables, markdown inline |
| `pastry` / Intern Paste | **NO** | Plaintext only |
| Task descriptions | Partial | Plaintext tables, markdown inline |
| Diff summaries (Phabricator) | YES (Remarkup) | Remarkup tables |
| Claude Code output | YES | Markdown OK |

**Default rule:** if unsure whether the target renders markdown, use plaintext. Plaintext is readable everywhere; markdown in a plaintext viewer is not.

## Tables — the #1 formatting trap

### Don't: markdown pipe tables in pastes

```
| Version | Duration | Kill reason |
|---------|----------|-------------|
| v68     | 480h     | DPP max     |
```

Renders in paste as one unreadable line:
```
| Version | Duration | Kill reason | |---------|----------|-------------| | v68 | 480h | DPP max |
```

### Do: plaintext aligned tables

```
Version  Duration       Kill reason
-------  ------------   --------------------------------
v68      480h (20.0d)   DPP max session duration
v67      100h (4.2d)    DPP session restart (same type)
v66      287h (12.0d)   User kill (align checkpoints)
```

### Do: indented key-value pairs (for narrow data)

```
  Model:       886797001
  Customer:    FEED
  Entitlement: ifr_modeling_tc_prod
  TMS state:   ONLINE_READY
```

### Do: numbered list (for sequences/timelines)

```
1. 2026-05-02 18:37 — v68 attempt 0 starts
2. 2026-05-22 18:48 — DPP kills session (20-day limit)
3. 2026-05-22 18:51 — v68 attempt 1 auto-starts
```

## Other formatting for plaintext surfaces

### Headers — use ALL CAPS + divider lines, not `#`

Pick ONE style and use it throughout. Mixing styles (e.g., `== ==` for some, `---` underline for others, ALL CAPS for a third) looks sloppy.

**Recommended (consistent divider style):**

```
----------------------------------------------------------------
SCOPE OF THE PROBLEM
----------------------------------------------------------------
```

**Also acceptable (underline style):**

```
SCOPE OF THE PROBLEM
====================
```

**Don't mix.** If your first section uses divider lines, every section uses divider lines.

### Two-zone documents (main body + reference)

For longer reports, split into a scannable top and a verification bottom. Use a heavier divider to mark the boundary:

```
================================================================
REFERENCE
================================================================
```

Reference sub-headers use the same style as main body headers — not a different one.

### Bold/emphasis — use CAPS or *asterisks*

Plaintext has no bold. Use `*emphasis*` or `CAPS` sparingly for key terms.

### Code blocks — indent 4 spaces

Pastry preserves whitespace. Indent commands to visually separate them:

```
    meta ai.mast-job error --name=mvai-training-online-886797001 --no-truncate
    mast get-status mvai-training-online-886797001
```

### Horizontal rules — use dashes

```
------------------------------------------------------------
```

### No manual word wrap

Don't hard-wrap paragraph text at 60-70 characters. Pastry's viewer handles line wrapping based on the reader's window width. Manual wraps create choppy, ragged paragraphs that look broken at wider or narrower viewports.

**Don't:**
```
Every ~20 days, DPP kills OT training sessions that
reach a hard session age limit (1,728,000s). During
the ~3-min restart gap the trainer stops consuming
Scribe data, so example age spikes and fires alerts.
```

**Do:**
```
Every ~20 days, DPP kills OT training sessions that reach a hard session age limit (1,728,000s). During the ~3-min restart gap the trainer stops consuming Scribe data, so example age spikes and fires alerts.
```

**Exception:** indented key-value pairs, aligned tables, and code blocks should keep their structure — don't join those into single lines.

### Vertical whitespace — tighten it

One blank line between sections is enough. Double blank lines waste vertical space and make the paste feel loose. Don't add blank lines after divider headers — the divider IS the visual separator.

**Don't:**
```
----------------------------------------------------------------
SCOPE
----------------------------------------------------------------

  Population:  ...
```

**Do:**
```
----------------------------------------------------------------
SCOPE
----------------------------------------------------------------
Population:  ...
```

## Quick checklist before `pastry`

- [ ] No markdown pipe tables — use plaintext aligned tables
- [ ] No `# headers` — use ALL CAPS + dividers
- [ ] No `**bold**` — use CAPS or *asterisks* for emphasis
- [ ] ONE header style throughout — don't mix `== ==` / `---` / ALL CAPS
- [ ] No manual word wrap — let the viewer handle line wrapping
- [ ] No double blank lines between sections
- [ ] Long pastes split into main body + REFERENCE section
- [ ] Code/commands are indented or clearly delimited
- [ ] Preview: `echo "content" | cat` — if it reads well in terminal, it reads well in paste

---

_Last updated: 2026-05-23. Maintainer: dennyzhang._
