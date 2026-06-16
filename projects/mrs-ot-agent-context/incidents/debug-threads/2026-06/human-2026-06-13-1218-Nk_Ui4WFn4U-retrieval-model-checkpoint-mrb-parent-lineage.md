---
name: retrieval-model-checkpoint-mrb-parent-lineage
description: MRB reset wiped the Parent lineage anchor for retrieval model 2137792444, causing `-1 does not exist` churn. Root cause traced, diff authored (and revised), domain knowledge saved.
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Retrieval Model `-1 does not exist` After MRB Reset

_Source: spaces/AAQAVOjYc80 thread `Nk_Ui4WFn4U` · 84 messages · 2026-06-13 12:18–20:51 PDT_
_Summarized: 2026-06-14 21:04 PDT · last-msg-time: 2026-06-13T20:51 UTC_

## What was discussed

Denny asked why the churning OT retrieval model (2137792444, W1350388963722513) tried to *restore* a checkpoint rather than creating one. Investigation revealed this was an MRB (Massive Revert & Ban from S675130/S675238) that wiped the model's `Parent` lineage anchor — leaving valid checkpoints (v1985-1987) orphaned. The `-1` sentinel resolves via parent lineage, not max(VALID version), so without a `Parent` anchor the lookup returns `ModelStoreDBRecordNotFound`. Recovery required re-running the recurring-train parent flow (`flow_tags=parent`) to re-seed the anchor.

## Key decisions made

- **Bot filed T275782360 + D108525530 (draft)** after Denny corrected "why ask" (2026-06-13T19:51) — the rule is: fixable finding → task AND diff in one pass, not pause and ask. (→ encoded as P-019)
- **D108525530 revision**: Denny caught unnecessary `ig_retrieval/` scope creep (2026-06-14T03:29); diff cut from 473→161 lines to base-resolver-only. Minimality gate added to diff-subagent as check #6.
- **Final D108525530 assessment**: Denny pushed (04:59) — auto-resume post-MRB bypasses MRB's intentional safety halt. Decision: replace with actionable fail-fast error (name the missing `Parent` root, surface latest VALID anchor, point to parent-flow re-seed recipe). New diff dispatched.

## Files / artifacts touched

| path | what changed |
|---|---|
| `learnings/deep-dives/retrieval-model-bootstrap-flow.md` | New: 7-step bootstrap flow, MRB-recovery section, `Parent` lineage mechanism |
| `concepts.md` | `Parent` anchor glossary entry, triage quick-match for `-1 does not exist` |
| Memory: `checkpoint-minus1-parent-lineage-mrb.md` | New reference memory, recovery recipe |
| Principles: P-019 | New: fixable finding → task + draft diff in one pass |

## Cluster / pattern references

_(No existing CL-NNN matched — adding to deep-dive as candidate pattern)_

## Followup items (not yet done)

1. New actionable-error diff (replacing D108525530) — dispatched to subagent, status unknown; needs review by `minimal_viable_ai` oncall
2. D108525530 was draft; verify it was superseded/abandoned given the re-scoping decision
3. Confirm with Ziwei/yiliang: what action around 18:00-19:38 PT triggered OT to pick up v1987 (the Parent anchor existed at 01:38 but OT didn't resume until 19:38)

## Cross-refs

- SEVs discussed: S675130, S675238
- Posts: W1350388963722513
- Related threads: `A4VpmKFNOJ4` (same day, cron issue), `k1_36_8oPeQ` (diff D108525530 re-assessment)
- Tasks: T275782360
- Diffs: D108525530
