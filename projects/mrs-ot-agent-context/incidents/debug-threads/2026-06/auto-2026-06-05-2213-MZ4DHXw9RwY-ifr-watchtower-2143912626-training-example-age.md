---
name: MZ4DHXw9RwY-ifr-watchtower-2143912626-training-example-age
description: ot-alert-monitor triage of A1508512290614499 (IFR Watchtower, model 2143912626) — training example age >10m, 2nd confirmed event in 7d; validator caught 2 errors in the published diagnosis
metadata:
  type: project
  human_involved: false
---

# Thread Summary: A1508512290614499 — IFR Watchtower training example age, model 2143912626

_Source: spaces/AAQAVOjYc80 thread `MZ4DHXw9RwY` · 4 messages · 2026-06-06 05:13–05:16 UTC_
_Summarized: 2026-06-06 21:45 PT · last-msg-time: 2026-06-06T05:16:04Z_

## What was discussed

ot-alert-monitor triage of alert A1508512290614499 ([IFR Watchtower] training example age >10m, model 2143912626, facebook_ifr_main_mtml). Alert self-resolved. Validator ran independently and found 2 errors in the published triage verdict.

## Key decisions made

- **2026-06-06 05:13 UTC — Triage verdict**: NO ACTION; CL-013 UPSTREAM_INFRA pattern (Scribe QPS → high example age). P04 shape is a candidate (falsifier unverifiable post-hoc; feed expired). Model healthy at triage time. Persistent misconfiguration noted: 3rd fire of detector 1508512290614499 in 30d.
- **2026-06-06 05:15 UTC — Validator discrepancies (2)**:
  1. P04 was labelled "MATCH" in the GChat reply; it is unverified (falsifier unrunnable). Archive was correctly phrased; GChat text was imprecise.
  2. Recurrence count stated "3 training_example_age events in 7d" was wrong: May 28 event (ALERT-938817701854850) was SPARSE_DELTA/CL-003, not training_example_age. Confirmed count is 2 (June 2 + June 5).
- **2026-06-06 05:16 UTC**: No operational follow-ups. Model 2143912626 has 2 training_example_age alerts in 7d — below the ≥3 threshold for a new P-row; IG-owned models with ≥3 alerts excluded from MRS OT scope.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-alerts/2026-06/high-2026-06-05-A1508512290614499.md` | archived |

## Cluster / pattern references

- CL-013 — UPSTREAM_INFRA (training example-age spike); cited in triage (unverified against failure-patterns.md)
- CL-003 — SPARSE_DELTA related; used to clarify May 28 alert was NOT training_example_age

## Followup items (not yet done)

_(none — self-resolved, P-row deferred below ≥3 threshold)_

## Cross-refs

- SEVs discussed: S669045 (1% error same model, still In Progress at triage time)
- Related threads: `3luVrm-1sIA` (same IFR Watchtower detector class, model 886797001)
