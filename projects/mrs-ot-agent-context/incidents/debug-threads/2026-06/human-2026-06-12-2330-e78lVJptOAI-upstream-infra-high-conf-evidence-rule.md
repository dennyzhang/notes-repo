---
name: human-2026-06-12-2330-e78lVJptOAI-upstream-infra-high-conf-evidence-rule
description: Operator gave generic feedback that upstream_infra high-confidence verdicts need solid confirming evidence; next actions for that triage were thin; bot encoded validator-enforced rule in triage-discipline.md
metadata:
  type: project
  human_involved: true
---

# Thread Summary: UPSTREAM_INFRA High-Confidence Needs Confirming Metric (Generic Rule)

_Source: spaces/AAQAVOjYc80 thread `e78lVJptOAI` · 11 messages · 2026-06-12 23:30–23:36 PDT_
_Summarized: 2026-06-13 21:04 PDT · last-msg-time: 2026-06-13T06:36Z_

## What was discussed

Operator gave generic feedback on a prior triage (model 880283513): "for issue triaged as upstream_infra with high confidence, we should always expect solid evidence which can confirm this. If missing, you should identify and build the missing metric — your next actions in this incidence is thin." Bot encoded the rule as a validator-enforced row in triage-discipline.md's proof-of-work table and did the close-the-thread ritual.

## Key decisions made

- [06:33:32Z] UPSTREAM_INFRA @ high confidence requires a `[VERIFIED]` metric linking the upstream cause to this model's dependency in the symptom window (scope + window match); "SEV exists + similar symptom" = `[INFERRED]`, not high → cap at medium
- [06:33:32Z] Missing confirming metric → build it (new scan/probe, P-017 if recurring), not "monitor"
- [06:36:40Z] UPSTREAM_INFRA next actions must be substantive — build/cite confirming metric, drive+escalate upstream SEV, P-017 if recurring — never passive "monitor for expiry"
- [06:36:40Z] Self-check (red-team): verified "validator-enforced" claim — CLAUDE.md:576 points validator at triage-discipline.md §Anti-laziness which reads the table dynamically ✓
- [06:36:40Z] Flagged (non-urgent, to daily brief): live CLAUDE.md ~19KB behind notes canonical; DETECTOR_BROKEN rules are monitor-prose (skip-risk) vs UPSTREAM_INFRA which is validator-enforced — prefer latter going forward

## Files / artifacts touched

| path | what changed |
|---|---|
| `triage-discipline.md` (notes) | UPSTREAM_INFRA proof-of-work row added to anti-laziness table |
| memory `upstream-infra-high-conf-needs-confirming-metric` | Written |

## Cluster / pattern references

_(none — this thread established a meta-rule, not a pattern match)_

## Followup items (not yet done)

_(none explicitly committed in this thread — follow-up metric build happened in `j7iFKgBgtXg`)_

## Cross-refs

- Related threads: `kELsQU_CtLk` (operator outreach budget rule, same session), `j7iFKgBgtXg` (concrete confirming query built for CL-003/P57 class)
