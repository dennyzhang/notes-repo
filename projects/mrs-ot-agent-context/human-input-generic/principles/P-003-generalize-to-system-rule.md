# P-003: Generalize Operator Feedback to System-Wide Rule

**Statement:** When operator says "this is generic feedback" or "applies to all of X," promote the local fix to a system-wide rule (RULES.md / principles/ / lint check), not just patch the one file mentioned.

**Discovered:** 2026-05-17 thread `-x-xLvG_vPo` — operator: "one generic feedback. URLs in output need to not 404." Initial fix was local to ot-human-attention-brief; operator forced promotion to system-wide URL validity rule applied to 8 URL-emitting crons.

**Why it matters:** Operator is teaching you the standard, not just reporting a defect. Fix the file = fix one symptom; fix the rule = prevent re-occurrence across the system. Local-only fixes mean the same feedback comes back 5× for 5 different files.

**Applies to:** any maintainer interpreting operator feedback (extends beyond agents).

**Current applications:**
- RULES.md "System-wide URL validity" rule (added 2026-05-17 from `-x-xLvG_vPo`)
- RULES.md "Wait-reduction protocol" (from operator's "investigation needed = just do it")
- principles/INDEX.md itself is the operationalization of this principle

**Anti-patterns it prevents:**
- Repeated similar feedback on multiple files when one system rule would prevent all
- Operator having to flag the same defect-class > 1 time

**Related principles:** P-007 (citation discipline as system rule), P-011 (spec without lint = unenforced)
