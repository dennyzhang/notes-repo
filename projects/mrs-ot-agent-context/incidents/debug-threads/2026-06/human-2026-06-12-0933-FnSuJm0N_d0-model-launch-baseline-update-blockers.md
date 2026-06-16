---
name: model-launch-baseline-update-blockers
thread_id: FnSuJm0N_d0
human_involved: true
summarized: 2026-06-12
---

# Thread Summary: What blocks fixing model launch / baseline update (#1 poller)

_Source: spaces/AAQAVOjYc80 thread `FnSuJm0N_d0` · 11 messages · 2026-06-12T16:33–17:32 UTC_
_Summarized: 2026-06-12 14:05 PT · last-msg-time: 2026-06-12T17:32:17Z_

## What was discussed

Operator asked what blocks fixing "issue #1" — the model-launch / baseline-update false-positive class where gaffe/guts detectors fire missing-FS alerts on models mid-launch (old baseline gone, new not yet registered). Bot initially listed 4 blockers including "no enumerable scan source" and "no timestamp on launch state." Operator then provided a concrete MLHub model_launches URL (`launchId=1345300064205665`), pointing to the `EntMLHubIPModelLaunch` / XDB `ux_launch` entity. Bot investigated and found this overturns blockers #2 and #3: the launch record carries a timestamp (`creation_time`/`update_time`), a status enum (`REGISTERED→COMPLETED`), and the candidate model id — making a poller buildable.

## Key decisions made

- **MLHub model_launches is the correct scan source** (2026-06-12T17:32 UTC): `EntMLHubIPModelLaunch` / `ux_launch` carries timestamp + status + candidate model id. A poller can do: "launch COMPLETED + candidate→Baseline → if registry `baseline_model_id` ≠ candidate → run `baseline_update.py`". Kills blockers #2 and #3 from the initial list.
- **Remaining blockers confirmed** (2026-06-12T17:32 UTC): (1) net-new poller to build + own (launch side owned by `ip_inference_experience_launch`/`mlhub_models`, registry write by `igml_model_registry`); (2) COMPLETED semantics ≠ registry write (need candidate-vs-registry compare, not a flag); (3) land contention on `SIMULTANEOUS_MODIFICATION` still needs rebase-retry logic.

## Files / artifacts touched

| path | what changed |
|---|---|
| T275648607 | Updated with MLHub model_launches finding — poller now buildable |

## Cluster / pattern references

_(No verified CL-NNN IDs — omitted)_

## Followup items (not yet done)

1. Confirm scope: does `ig_reels_tab_vm_esr`'s launch flow through `EntMLHubIPModelLaunch` (IPNext launch record)? Bot offered to verify and spec the poller on T275648607.
2. Spec and build the net-new scanner/trigger (joins `ux_launch` + model registry; runs `baseline_update.py` with rebase-retry on conflict).

## Cross-refs

- Tasks: T275648607
- SEVs discussed: none
