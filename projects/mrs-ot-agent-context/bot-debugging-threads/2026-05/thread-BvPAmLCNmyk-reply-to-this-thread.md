# Thread Summary: SilverTorch SEV Tagging — `mrs-online-training-silvertorch` Classifier

_Source: spaces/AAQAVOjYc80 thread `BvPAmLCNmyk` · 52 messages · 2026-05-27T22:16–22:56Z_
_Summarized: 2026-05-28 23:47 PT · last-msg-time: 2026-05-27T22:56:12Z_

## What was discussed

Denny requested a new capability: when OT jobs are SilverTorch-based, the corresponding SEV should be auto-tagged `mrs-online-training-silvertorch`. MyClaw identified `application_metadata.distributed_ai_stack` (values: MVAI / SILVERTORCH) as the canonical signal — validated on 30/30 RUNNING jobs with 100% clean signal. Both `ot-sev-monitor` and `ot-alert-monitor` were updated. A title-prefix fallback (`^\[silvertorch/`) was added for prospector-style jobs where MAST metadata is absent. A backfill of all historical OT SEVs was initiated.

## Key decisions made

- [22:20:38] `application_metadata.distributed_ai_stack` chosen as primary source over title-regex — single canonical field, no regex risk, validated on 30 live jobs.
- [22:28:33] Title-prefix fallback added (`^\[silvertorch/` → SILVERTORCH, `^\[mvai/` → MVAI); ambiguous prefixes fall through to `unknown`.
- [22:28:26] `training_stack_source` audit field added to both monitors' diagnosis JSON for auditability.
- [22:32:50] Operator requested backfill of all existing OT SEVs under mvai-online-training tag — MyClaw attempted; hit merge-conflict mid-run and rebased from remote/master pristine baseline.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-sev-monitor.md` | training_stack classifier, silvertorch tag logic (step 9.e), re-eval pass update, title-prefix fallback, `training_stack_source` field |
| `notes/.../cron-jobs/ot-alert-monitor.md` | same fields mirrored |
| D106571152 | fbcode diff, 16+/6- across both files, rebased onto remote/master (no ancestor-stack dependency) |

## Cluster / pattern references

_(omitted — failure-patterns.md CL-IDs not verified)_

## Followup items (not yet done)

1. Backfill all historical OT SEVs with silvertorch tag — initiated (S666632 confirmed backfilled); full fleet backfill status not confirmed after mid-run rebase.

## Cross-refs

- SEVs discussed: S666632 (fbr_hstu, confirmed SILVERTORCH, backfilled)
- Diff: D106571152
- Related threads: none noted
