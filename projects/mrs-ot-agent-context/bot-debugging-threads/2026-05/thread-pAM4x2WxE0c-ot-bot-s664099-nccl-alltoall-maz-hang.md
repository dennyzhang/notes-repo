# Thread Summary: S664099 — NCCL ALLTOALL_BASE hang on B200/maz blocking mvai trunk

_Source: spaces/AAQAVOjYc80 thread `pAM4x2WxE0c` · 4 messages · 2026-05-15 11:32–11:34 PT_
_Summarized: 2026-05-16 13:31 PT · last-msg-time: 2026-05-15T11:34:58Z_

## What was discussed

The ot-bot posted a triage card for SEV S664099: NCCL ALLTOALL_BASE collective timeout (600s) during backward pass at `torchrec/distributed/comm_ops.py:1634`, blocking the `mvai/mvai_ig_ranking` conveyor at the Blackwell validation step. Failures reproduced across R8424.2, R8426.2/3/4, R8434.1 on tsp_maz B200 hosts; baseline succeeded on tsp_snb. Validator pass (DEGRADED — self-validation only) confirmed hypothesis and tagged the SEV `mvai-online-training`.

## Key decisions made

- **[2026-05-15T11:32:42Z] Standing hypothesis:** B200/maz-specific NCCL hang — NVLink topology, interconnect fabric, or NCCL driver on tsp_maz B200 differs from tsp_snb. Code regression and P47 (cross-PG deadlock) both falsified.
- **[2026-05-15T11:34:50Z] Validator confirmed:** P47 ruled out by error signature (ALLTOALL_BASE = all ranks same collective ≠ cross-PG deadlock pattern). D104469704 (P47 fix, landed May 11) predates all failing releases. Auto-tagged `mvai-online-training` on S664099.
- **Recommended short-term unblock:** Route `cogwheel_lsr_blackwell_test` to tsp_snb B200 hosts via conveyor config.

## Files / artifacts touched

| path | what changed |
|---|---|
| SEV S664099 | Tag `mvai-online-training` added by validator pass |

## Cluster / pattern references

_(No matching CL-NNN in failure-patterns.md for this specific NCCL/B200 hardware pattern — omitted to avoid fabrication)_

## Followup items (not yet done)

1. Route `cogwheel_lsr_blackwell_test` to tsp_snb B200 via conveyor config to unblock trunk releases. Owner: ezrak. Status: recommended, not confirmed done.
2. File maz B200 infra bug: NCCL ALLTOALL_BASE 600s timeout — include hostname list + NCCL version from `light_cli:794abad` base layer. Owner: infra/maz B200 team. Status: open.
3. Validate D104947534 (watchdog-aware publish waits, Accepted not landed) lands separately for TGIF SIGKILL path. Owner: ezrak. Status: pending land.

## Cross-refs

- SEVs discussed: S664099
- Diffs: D104469704 (P47 fix, landed May 11), D104947534 (watchdog waits, not yet landed)
- Oncall: ig_ranking_modeling, maz B200/interconnect team
- Suggested owner: ezrak
