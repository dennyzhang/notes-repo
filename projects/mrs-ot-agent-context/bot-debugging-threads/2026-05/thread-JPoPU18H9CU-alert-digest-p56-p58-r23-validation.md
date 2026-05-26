# Thread Summary: Alert Digest — P56/P58/R23 Validation + STUS Escalation Rule L20

_Source: spaces/AAQAVOjYc80 thread `JPoPU18H9CU` · 14 messages · 2026-05-20T05:18–05:41 UTC_
_Summarized: 2026-05-20 23:45 PT · last-msg-time: 2026-05-20T05:41:07Z_

## What was discussed

Overnight alert digest processed A1009946182010606 (STUS FS missing, m2130324780), A2149157265940350 (ZippyDB AGG, m878102693), and the A1992805401272397/A1523301739314191/A1729017248472393 cluster (P56 Shampoo NaN cascade, m2134801434). All 3 hits matched existing patterns; validator at 22:30 PT confirmed all classifications correct. L20 STUS escalation rule fired correctly on second repeat of m2130324780 FS alert.

## Key decisions made

- **A2149157265940350 → P58 confirmed** (05:39Z validator): S665163 `time_mitigated=2026-05-19 16:36 UTC` verified via meta CLI — ZippyDB CAS throttle series closed.
- **A1992805401272397 group → P56 confirmed** (05:39Z validator): Shampoo NaN cascade (CL-017); v96 NaN, v97 MAST auto-restart; m2134801434 FULL_SNAPSHOT VALID at 21:43 PDT confirmed healthy.
- **A1009946182010606 → R23/CL-008 THRESHOLD_MISFIT, not P-row** (05:39Z validator): m2130324780 shows 0 FULL_SNAPSHOT in last 50 instances — STUS role confirmed. L20 escalation: 2nd fire in 2d → explicit recommend to @ronghuang suppress/retune alert 1455336899399360.
- **Validator-queue idea strengthened** (05:39Z): pre-recovery FS gap was :2484→:2488 = 6h 6m; alert fired 9 min AFTER :2488 already published — self-recovered before PAGE. Empirical case for 10-15 min agent-validation pass.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-alerts/2026-05/ALERT-1455336899399360-2026-05-18.md` | Created for A1009946182010606 (STUS FS) |
| `incidents/resolved-alerts/2026-05/low-2026-05-19-A2149157265940350.md` | Created for P58 ZippyDB alert |
| `incidents/resolved-alerts/2026-05/low-2026-05-17-A1703030847735006.md` | Updated with P56 Shampoo NaN resolution |

## Cluster / pattern references

- [CL-003] — P58 ZippyDB S665163 cascade (m878102693 AGG alerts)
- [CL-008] — STUS FS cadence mismatch (m2130324780, R23 applies)
- [CL-017] — P56 Shampoo NaN, m2134801434 CUDACachingAllocator NaN → v96 crash → v97 auto-restart

## Followup items (not yet done)

1. Escalate to @ronghuang to suppress/retune alert 1455336899399360 for m2130324780 (STUS FS, 2nd fire — owner: Denny/mrs_online_training oncall)
2. A1938473210332908 (deferred from digest) — still needs triage next cycle

## Cross-refs

- SEVs discussed: S665163 (mitigated), S664499 (NCCL/Shampoo context)
- Related threads: `UH1t_Fwjom4` (parallel SEV digest, same validator session)
