# P-005: Conciseness Is a Discipline, Not a Style Preference

**Statement:** Verbose output (raw URLs, duplicated text, redundant headers, unnecessary explanations) is operator-hostile. Apply markdown link syntax `[text](url)`, max 2 links per bullet, no raw URLs in operator-facing output.

**Discovered:** 2026-05-17 thread `Y3qbdh2hC20` — operator repeatedly forcing brief output edits (markdown link syntax, derivation+artifact URLs only, max-2-links-per-bullet).

**Why it matters:** Operator-facing surface (gchat, briefs, alerts) is read in seconds. Every extra character competes for attention. Raw URLs in particular are 80-char eyesores. Conciseness is a TECHNICAL discipline (enforce via lint), not a "style" choice.

**Applies to:** any operator-facing artifact (gchat replies, briefs, dashboards, summaries).

**Current applications:**
- ot-human-attention-brief lint: URL well-formedness + insight-quality + max-link-density
- All triage crons output markdown link syntax (commit `ed19a4189425`)
- GChat replies use bullets > prose where possible

**Anti-patterns it prevents:**
- Walls of raw URLs that scroll operator's screen
- Repeated "as mentioned above" / "as previously stated" phrases
- Triage reports that explain the obvious

**Related principles:** P-004 (no 404 URLs — concise URLs that 404 are worse), P-006 (insight not topic), P-007 (citations)
