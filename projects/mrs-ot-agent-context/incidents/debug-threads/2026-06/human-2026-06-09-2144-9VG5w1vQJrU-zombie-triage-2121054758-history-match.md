---
name: 9VG5w1vQJrU-zombie-triage-2121054758-history-match
description: Zombie triage for mvai-training-online-2121054758; operator corrected thin initial triage; history-match step codified
metadata:
  type: project
  human_involved: true
---

# Thread Summary: mvai-training-online-2121054758 zombie triage + history-match calibration

_Source: spaces/AAQAVOjYc80 thread `9VG5w1vQJrU` · 15 messages · 2026-06-09 21:44–21:57 PT_
_Summarized: 2026-06-10 21:04 PT · last-msg-time: 2026-06-10T04:57Z_

## What was discussed

Operator flagged that initial triage (from a Workplace post thread) was too thin — it stopped at "snapshot frozen / publisher silent." Bot re-triaged with the OBSERVE probe set: confirmed zombie (RUNNING but zero mvai_metrics emission since 19:03, no logs after, 2h45m frozen). Traced an error chain: STORAGE_SVC_PUT_CHUNK RESOURCE_BUSY_TIMEOUT (15:21–18:59 on all trainers) → CheckpointDistClient.Save RuntimeError on 7+ ranks → train loop blocks → zombie. Bot labeled root "storage degradation, high confidence." Operator corrected: known issue, same root as S665454 + S670887; real root is worker crash (CUDA allocator assert → SIGABRT) + base-layer bug preventing clean process exit → MAST creates no new attempt → zombie. Fix: manual kill + base layer ≥ D98638473. Li Lu confirmed: "manual kill the jobs as MAST/SJD/TMS will not catch a zombie." Bot calibrated the miss: skipped history-match (step 0), over-fit on frequent storage log lines instead of the CUDA crash signature, tagged "high" confidence before confirming the actual crash.

## Key decisions made

- **Step 0 = history match BEFORE probe set** (2026-06-10 04:57 PT): codified in mast-debugging.md — check prior SEVs + known-issues + runbook posts before running OBSERVE probes.
- **Zombie canonical root**: worker crash + base-layer no-clean-exit (D98638473), mitigation = manual kill. Stop re-deriving from blank slate.
- **No "high" confidence before history match + probe #1 both ran**: confidence guard added to cheatsheet with this thread's misroot as worked anti-example.

## Files / artifacts touched

| path | what changed |
|---|---|
| ~/notes/.../cheatsheets/oncall/mast-debugging.md | Added Step 0 block: S665454/S670887, runbook post 1344542434307166, D98638473, manual-kill, cluster note, confidence guard |

## Cluster / pattern references

- [CL-001] — snapshot-stuck is the downstream symptom; zombie job stops publishing FULL_SNAPSHOT

## Followup items (not yet done)

1. SJD-save-hang systemic follow-up: 2nd recurrence of SJD blind to checkpoint-save hang — file deduped task with decisive metric (time-from-last-emission to auto-kill). Status: discussed, filing status unconfirmed.

## Cross-refs

- SEVs discussed: S665454, S670887
- Posts: 1344542434307166 (Denny's 6/6 runbook)
- Related threads: `nVcnP_Hag08` (shared theme of shallow initial triage corrected by operator)
