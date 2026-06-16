# Thread Summary: P57 Pattern Proposal — Manifold Disk Quota → Checkpoint Fail

_Source: spaces/AAQAVOjYc80 thread `AW6Bn3cPPeY` · 3 messages · 2026-05-28T04:11–04:14Z_
_Summarized: 2026-05-29 00:46 PT · last-msg-time: 2026-05-28T04:14:54Z_

## What was discussed

The ot-sev-auditor cron proposed a new detection pattern P57 (Manifold use-case disk quota exceeded → checkpoint failure) sourced from S664296 (Threads/IG DPP oscillation). Symptoms include `kUsecaseSizeExceedsLimit`, `DESC_RIM_THROTTLED_STORAGE`, `ManifoldSRClient::createDirectory`, and `[INFRASTRUCTURE_ERROR][MODEL_STORE]`, with trainer DEAD/restart cascades and downstream DPP oscillation. The validator then confirmed all 6 checks passed for the proposal.

## Key decisions made

- P57 was confirmed valid by the validator at 2026-05-28T04:13Z: root cause kUsecaseSizeExceedsLimit verified in MAST v3 ✓, T272100863 OPEN/due-2026-05-30/hubertliu ✓, no duplicate in known-patterns.md ✓.
- Note: a different P57 was also proposed in the prior run (2026-05-26) for APS pkg stale → SV timeout (S667355). Both are pending operator review to assign distinct IDs.

## Files / artifacts touched

| path | what changed |
|---|---|
| (pending) `~/notes/.../auto-learnings/failure-patterns.md` | P57 proposal to be landed by operator |

## Cluster / pattern references

_(No CL- clusters defined in failure-patterns.md yet.)_

- P57 proposed: Manifold use-case disk quota → checkpoint fail | T2
- Falsifier: `meta ai.mast-job error --name=mvai-training-online-<ID> --version=<V>` — absent kUsecaseSizeExceedsLimit → not P57

## Followup items (not yet done)

1. Operator must review and land P57 (and the prior 2026-05-26 P57 variant) into known-patterns.md with distinct IDs — hubertliu owns T272100863 (due 2026-05-30).

## Cross-refs

- SEVs discussed: S664296
- Posts: none
- Related threads: `sRcOF1RFq-E` (S664296 postmortem review)
