# Thread Summary: S664099 triage — NCCL ALLTOALL_BASE timeout, mvai_ig_ranking B200/maz

_Source: spaces/AAQAVOjYc80 thread `pAM4x2WxE0c` · 4 messages · 2026-05-15_
_Summarized: 2026-05-17 14:31 PT · last-msg-time: 2026-05-15T11:34:58Z_

## What was discussed

Bot posted a triage for SEV S664099: NCCL ALLTOALL_BASE collective timeout (600s) at `torchrec/distributed/comm_ops.py:1634` during backward pass for the `mvai/mvai_ig_ranking` conveyor. Failure reproduced across releases R8424.2, R8426.2/3/4, R8434.1 — all on tsp_maz B200 hosts. Baseline succeeded on tsp_snb, ruling out a code regression. Validator ran self-validation (agent tool unavailable), confirmed the hypothesis, and auto-tagged `mvai-online-training` on the SEV. Triage confidence: 0.85, suggested owner: ezrak.

## Key decisions made

- **Hypothesis confirmed** (2026-05-15T11:34:50Z validator): B200/maz NCCL ALLTOALL_BASE hang is host-infrastructure, NOT code regression — 4+ release failures with no common diff correlation, and snb baseline succeeded.
- **P47 (cross-PG deadlock) falsified** (2026-05-15T11:34:50Z): D104469704 landed May 11, predates all failing releases; error signature (all-ranks same collective timeout) ≠ cross-PG deadlock pattern.
- **Immediate unblock path**: route `cogwheel_lsr_blackwell_test` to tsp_snb B200 hosts via conveyor config — proposed in triage (11:32 UTC), not confirmed as executed.
- **Auto-tagged** `mvai-online-training` on S664099 — confirmed success (`tags_added=mvai-online-training`, 2026-05-15T11:34:50Z).

## Files / artifacts touched

| path | what changed |
|---|---|
| S664099 (SEV) | Tag `mvai-online-training` added via `meta sevmanager.sev update` |

## Cluster / pattern references

- [CL-014] — Training timeout (NCCL / watchdog / RaaS) — this thread is a direct instance of the NCCL timeout cluster on B200 hosts; B200/maz-vs-snb topology difference as root is a new sub-mechanism not yet documented in CL-014.
- [CL-004] — Cogwheel/conveyor publish failures — `mvai_ig_ranking` conveyor is blocked at Blackwell validation step; no new trunk releases shipping → model freshness degrading.

## Followup items (not yet done)

1. File maz B200 infra bug: NCCL ALLTOALL_BASE 600s timeout — include hostname list, NCCL version from `light_cli:794abad` base layer. Owner: triage suggests infra team. Status: proposed, not confirmed filed.
2. Get full NCCL trace: `meta ai.mast-job error --name=<cogwheel_lsr_blackwell_job> --no-truncate | grep -iE "ALLTOALL|timeout|rank"`. Status: proposed, not confirmed executed.

## Cross-refs

- SEVs discussed: S664099
- Posts: _(none)_
- Related diffs: D104947534 (watchdog-aware publish waits for mvai_ig_ranking — Accepted, not yet landed at time of triage; separate mechanism)
- Related threads: `AkDeocSaNSQ` (same timestamp — parallel triage thread, likely same session)
