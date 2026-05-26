# Thread Summary: model 2130305043 (ig_reels_tab_cs_omni_retrieval) — SPARSE_DELTA self-healed + FULL_SNAPSHOT 60h gap

_Source: spaces/AAQAVOjYc80 thread `MkICYBz2c8o` · 4 messages · 2026-05-15_
_Summarized: 2026-05-16 15:32 PT · last-msg-time: 2026-05-15T18:24:27Z_

## What was discussed

Denny pasted an ot-bot triage for model 2130305043 (ig_reels_tab_cs_omni_retrieval, STUS v4 att1) that had fired a Scribe `client_lag_in_seconds` alert due to a 118-min SPARSE_DELTA gap (08:55→10:52 PDT). The gap self-healed at 10:52. The more significant finding surfaced during review: FULL_SNAPSHOT had not been published since 2026-05-11 23:05 UTC (~60h gap) — a separate concern unrelated to the Scribe alert. MyClaw validated both findings and confirmed the STUS v4 job was running with no errors.

## Key decisions made

- [2026-05-15T18:23:44Z] MyClaw assessed SPARSE_DELTA alert as downstream symptom; flagged 60h FULL_SNAPSHOT gap as the real action item requiring owner confirmation from qianh25 / ig_producer_value oncall.
- [2026-05-15T18:24:20Z] Denny ran validator: SPARSE_DELTA gap confirmed closed (10:52:44), ITEM_EMB_DELTA normal, FULL_SNAPSHOT absent from latest 10 instances — 60h gap empirically confirmed.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — triage-only thread) | no notes files written during conversation |

## Cluster / pattern references

- [CL-003] — model 2130305043 SPARSE_DELTA gap cited as S665114 (W20) instance of upstream-infra-cascade / STUS stall cluster. STUS publish-path stall is the suspected mechanism; P50 (upstream infra SEV check) applied and cleared.

## Followup items (not yet done)

1. Confirm FULL_SNAPSHOT drop via `meta ai.model.instance list --model-id=2130305043 --limit=100 --sort-by=creation_time --sort-order=desc -o json` — owner: qianh25 / ig_producer_value oncall; status: open at thread close.

## Cross-refs

- SEVs discussed: (alert only, no named SEV — alert fired 10:28:47 PDT via Scribe client_lag_in_seconds for model 2130305043)
- Related threads: `jJ-go695RTY` (same diagnostic format / confidence attribution approach)
