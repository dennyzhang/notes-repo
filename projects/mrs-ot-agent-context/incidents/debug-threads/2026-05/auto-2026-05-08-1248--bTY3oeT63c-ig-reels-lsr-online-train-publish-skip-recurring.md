---
name: ig-reels-lsr-online-train-publish-skip-recurring
description: IG Reels LSR online_train_publish flow produces no OT diff due to skip_recurring=True in workflow_input_override
metadata:
  type: project
  thread_id: "-bTY3oeT63c"
  space: spaces/AAQAVOjYc80
  human_involved: false
---

# Thread Summary: IG Reels LSR — online_train_publish Step Producing No OT Diff

_Source: spaces/AAQAVOjYc80 thread `-bTY3oeT63c` · 3 messages · 2026-05-08_
_Summarized: 2026-05-08 12:48–12:50 PT · last-msg-time: 2026-05-08T19:50:40Z_

## What was discussed

Jakub Bester posted to mrs.ot: the `online_train_publish` step for IG Reels LSR model 2124252069 was succeeding but producing no OT config diff and never registering the model for online training. The bot triaged and a validator confirmed.

## Key decisions made

- **Root cause confirmed (2026-05-08T19:49):** `skip_recurring: True` in flow f1078311961's `workflow_input_override` causes early return in `recurring_train.py` ~line 591 before TLS config diff generation. Flow reports SUCCEEDED but produces no OT diff — silent early-exit, not an infrastructure failure.
- **JOB_NOT_FOUND on mvai-training-online-2124252069 is expected** — no MAST job was ever created because registration was never reached.
- **Workaround:** Run `mvai online-training-mgr generate-job-config-diff -m 2124252069` → `mvai online-training-mgr register-and-run -m 2124252069 --oncall ig_rec_modeling_lsr`; fix config by setting `skip_recurring: False` and re-running run_loop.py.

## Files / artifacts touched

| path | what changed |
|---|---|
| recurring_train.py ~line 591 | early-return gate guarded by skip_recurring flag |
| FBLearner flow f1078311961 | workflow_input_override with skip_recurring: True |

## Cluster / pattern references

_(No existing cluster ID confirmed — omitted per quality rule.)_

## Followup items (not yet done)

_(None explicitly discussed — bot provided workaround; no followup assigned in thread.)_

## Cross-refs

- SEVs discussed: S656611 (IG Reels LSR holdout softness, L2 In Progress), S661284 (adjacent publish NE regression)
- Posts: https://fb.workplace.com/groups/mrs.ot/permalink/1215710353808301/
- Related threads: `0oaS6lfX95c` (duplicate triage of same post)
