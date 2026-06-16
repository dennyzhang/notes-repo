# Thread Summary: SJD Coverage Gaps — NCCL Hang / D104947534 Review

_Source: spaces/AAQAVOjYc80 thread `z5JIb7DGm5o` · 23 messages · 2026-05-15 10:09 PT → 2026-05-16 14:01 PT_
_Summarized: 2026-05-16 21:32 PT · last-msg-time: 2026-05-16T21:01:24Z_

## What was discussed

Operator posted OT triage of mvai-training-online-2123154171 (ig_reels_tab_mtml), which hung 11h with no progress after NCCL ALLTOALL_BASE timeout on B200/maz hardware, linked to S664099. Follow-up conversation expanded into why SJD (StuckJobDetector) failed to catch it, a systematic coverage analysis, and a review of diff D104947534 which was proposed as a fix for one related SJD bypass class.

## Key decisions made

- **2026-05-16T20:42Z** — Built `sjd-coverage-map.md` with 5 rows (N=5 SJD bypass scenarios) cataloged, pushed commit `97e73ee8348c`.
- **2026-05-16T20:45Z** — Verdict on D104947534: correct fix for 🟡 OVERKILL class (long publish during shutdown starves SJD watchdog refresh), but does NOT cover Max Kaplan's 🔴 MISS case (C++ NCCL destructor hang, below Python layer). Two different polarity classes.
- **2026-05-16T20:46Z** — D104947534 already CLOSED/landed (author: ezrak). Preferred follow-up channel: GChat DM to ezrak, not diff comment.
- Ultimate root cause of Max's hang: **UNKNOWN** — logs gone 2 days post-incident; B200/maz hardware hypothesis is [INFERRED] from S664099 symptom similarity, not log-matched.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/expert-observations/2026-05-16-sjd-coverage-gaps.md` | Created: SJD coverage map with 5 rows + polarity column (🔴 MISS / 🟡 OVERKILL) |
| `mrs-ot-agent-context/mega-learnings/CLUSTERS.md` | CL-012 updated to N=3, D1-eligible |

## Cluster / pattern references

- [CL-012] — StuckJobDetector coverage gaps. This thread is the primary evidence base for CL-012 (N=3: NCCL deadlock 🔴, publisher-shutdown starvation 🟡, non-publisher cleanup 🔴, in-training publish TBD). D104947534 partially mitigates row #2 only.

## Followup items (not yet done)

1. GChat DM to ezrak: confirm whether `_shutdown_watchdog` should thread through in-training `wait_for_publish_completion` paths (row #4); cross-ref row #3 MISS class. Operator deferred ("ok" at 2026-05-16T20:44Z); no explicit "send" given per RULES.md.
2. Pull MAST attempt logs for mvai-training-online-2123154171 to verify B200/maz hardware root (logs may have aged out).

## Cross-refs

- SEVs discussed: S664099 (NCCL ALLTOALL_BASE on B200/maz, In Progress)
- Posts: W1326387856122624 (Max Kaplan, OT hang)
- Related threads: `pAM4x2WxE0c` (earlier triage of same model, already summarized)
