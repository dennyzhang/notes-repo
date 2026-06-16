---
name: d108525530-wrong-site-checkpoint-fix-reassessment
description: Follow-on to the retrieval model checkpoint thread. D108525530 was found to patch wrong site (ig_retrieval preemption vs base loader), then reassessed as wrong approach (bypasses MRB safety semantics). New actionable-error diff requested.
metadata:
  type: project
  human_involved: true
---

# Thread Summary: D108525530 Wrong Site + Wrong Approach — Reassessment

_Source: spaces/AAQAVOjYc80 thread `k1_36_8oPeQ` · 67 messages · 2026-06-13 19:47–2026-06-14 05:04 PDT_
_Summarized: 2026-06-14 21:04 PDT · last-msg-time: 2026-06-14T05:34 UTC_

## What was discussed

Denny asked to calibrate D108525530 against Paul Lu's comments on Workplace post W1350388963722513. Three threads converged: (1) the live stack showed the failing path was `job_resolver.py:1270` base loader, not the `ig_retrieval` preemption block D108525530 patched; (2) Ziwei's failed config removal test confirmed the resume pointer lives in persisted `retryable_job_info`, not the config; (3) Denny pushed at 04:59: "is D108525530 really a good fix?" — answer: no, auto-resume post-MRB bypasses MRB's intentional safety gate.

Recovery mechanism confirmed: model worked again because yiliang ran the recurring-train *parent* flow (`flow_tags=parent`, 1-hour batch window) which re-seeded the `Parent` lineage anchor (v1987). The `-1` sentinel resolves via parent lineage, not max(VALID), which is why config edits had no effect.

## Key decisions made

- **D108525530 is the wrong fix** (2026-06-14T05:00): auto-resume post-MRB converts an intentional safety halt into silent bypass. Even if technically sound, it changes MRB semantics without explicit owner buy-in from `tdmi_massive_sev`/`ads_online_training`.
- **New diff approach** (2026-06-14T05:04): actionable fail-fast — replace the cryptic `Checkpoint <eid> : -1 does not exist` with a message naming the missing `Parent` root, pointing to the recurring-train parent re-seed recipe, and surfacing the latest VALID anchor version. No auto-resume, no MRB semantics change.
- **Generic learning on diff minimality** (Denny "what are your generic learning"): P-021 added — every hunk traces to the verified root `file:line`; "defense-in-depth" for a different bug = scope creep; split or remove it. Added to diff-subagent as check #6 and to cheatsheet.

## Files / artifacts touched

| path | what changed |
|---|---|
| `learnings/deep-dives/retrieval-model-bootstrap-flow.md` | Recovery mechanism: `Parent` anchor role, why config edit can't fix stale retry state |
| Principles: P-021 | New: diff minimality — every hunk traces to verified root |
| diff-subagent checks | #6: minimality counter-check added |
| `cheatsheets/diff/common.md` | Minimality section added |

## Cluster / pattern references

_(No existing CL-NNN matched)_

## Followup items (not yet done)

1. New actionable-error diff (replacement for D108525530) — dispatched to subagent at end of thread; needs verification it was created + routed to `minimal_viable_ai` for review
2. D108525530 should be abandoned or marked as superseded; verify its state on Phabricator
3. T275782360 — update with the reassessment and the new diff link once available

## Cross-refs

- SEVs discussed: S675130, S675238
- Posts: W1350388963722513
- Related threads: `Nk_Ui4WFn4U` (original triage), `A4VpmKFNOJ4` (same-day cron fix)
- Tasks: T275782360
- Diffs: D108525530
