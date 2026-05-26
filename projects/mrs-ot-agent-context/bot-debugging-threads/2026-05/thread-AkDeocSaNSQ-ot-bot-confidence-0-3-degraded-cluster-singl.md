# Thread Summary: S664296 — DPP Workers Oscillating, Threads/Permalink OT Blocked

_Source: spaces/AAQAVOjYc80 thread `AkDeocSaNSQ` · 4 messages · 2026-05-15T11:32–11:35 UTC_
_Summarized: 2026-05-16 14:31 PT · last-msg-time: 2026-05-15T11:35:03Z_

## What was discussed

Bot triage of S664296: DPP workers in die→restart oscillation during Threads/Permalink online training. Confidence 0.3/DEGRADED due to GChat returning empty and model ID not in SEV metadata. Standing hypothesis P51 (PPF token fetch timeout → RETRYABILITY loop) or P30 (DPP pkg version bump silently hanging). Validator pass confirmed ground truth and auto-tagged the SEV.

## Key decisions made

- `confidence: 0.3 / DEGRADED` is appropriate — diagnosis cannot progress without MAST job name (2026-05-15T11:34:50Z)
- S664296 tagged `mvai-online-training` via `meta sevmanager.sev update --add-tag` (2026-05-15T11:34:50Z)
- Ball in hubertliu's court to provide Threads Permalink OT model ID / MAST job name

## Files / artifacts touched

| path | what changed |
|---|---|
| SEV S664296 | added tag `mvai-online-training` |

## Cluster / pattern references

- [CL-003] — upstream-infra-cascade; P51 (PPF token fetch) is a plausible cascade variant but unconfirmed
- P51 [INFERRED] — PPF token fetch timeout → DPP RETRYABILITY
- P30 [INFERRED] — DPP pkg version bump hanging training
- Neither P51 nor P30 confirmed; MAST job name required to distinguish

## Followup items (not yet done)

1. hubertliu: provide Threads/Permalink OT model ID or MAST job name — unresolved at thread close
2. Run `meta ai.mast-job error --name=mvai-training-online-<MODEL_ID>` to distinguish P51 vs P30

## Cross-refs

- SEVs discussed: S664296
- Posts: none
- Related threads: `pAM4x2WxE0c` (concurrent validator-pass, same time window)
