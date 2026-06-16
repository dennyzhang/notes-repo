---
name: ig-reels-lsr-ot-diff-missing-duplicate-triage
description: Duplicate triage thread for same IG Reels LSR skip_recurring post — second bot analysis of Jakub Bester's mrs.ot post
metadata:
  type: project
  thread_id: "0oaS6lfX95c"
  space: spaces/AAQAVOjYc80
  human_involved: false
---

# Thread Summary: IG Reels LSR — OT Diff Missing (Duplicate Triage)

_Source: spaces/AAQAVOjYc80 thread `0oaS6lfX95c` · 3 messages · 2026-05-08_
_Summarized: 2026-05-08 13:35–13:38 PT · last-msg-time: 2026-05-08T20:38:48Z_

## What was discussed

Second bot triage thread for the same Jakub Bester mrs.ot post (https://fb.workplace.com/groups/mrs.ot/permalink/1215710353808301/). Same root cause identified: `skip_recurring: True` causing early return in `recurring_train.py` before OT diff generation. Validator confirmed.

## Key decisions made

- **Duplicate triage confirmed** — same Workplace post triggered two separate bot responses in separate threads. Both reached the same diagnosis independently (confidence 85% vs 88%).
- **Confirmed workaround sequence:** (1) Fix `skip_recurring: False` in run_config, (2) re-run `run_loop.py`, (3) `mvai online-training-mgr register-and-run -m 2124252069 --oncall ig_rec_modeling_lsr`, (4) `generate-job-config-diff` remains JOB_NOT_FOUND until after step 3.
- **Timing note:** Jakub hit `generate-job-config-diff` (step 3 of workaround) before step 2 (register-and-run) completed — expected JOB_NOT_FOUND.

## Files / artifacts touched

| path | what changed |
|---|---|
| recurring_train.py ~line 591 | same early-return gate as sibling thread |

## Cluster / pattern references

_(No existing cluster ID confirmed — omitted per quality rule.)_

## Followup items (not yet done)

_(None — see sibling thread `-bTY3oeT63c` for primary record.)_

## Cross-refs

- SEVs discussed: S656611 (L2 In Progress, IG Reels LSR holdout softness)
- Posts: https://fb.workplace.com/groups/mrs.ot/permalink/1215710353808301/
- Related threads: `-bTY3oeT63c` (primary triage of same post)
