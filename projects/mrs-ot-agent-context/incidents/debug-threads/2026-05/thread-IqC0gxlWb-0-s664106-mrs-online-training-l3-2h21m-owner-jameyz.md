# Thread Summary: SEV Digest — S664106 Detailed + Pattern Match P17/CL-009

_Source: spaces/AAQAVOjYc80 thread `IqC0gxlWb-0` · 5 messages · 2026-05-22_
_Summarized: 2026-05-22 21:47 PDT · last-msg-time: 2026-05-22T04:10:59Z_

## What was discussed

Detailed SEV digest for S664106 (Threads Feed teacher model 2128461099 OT cannot get started, L3, owner @jameyz, oncall mvai-training-online / jingchenhu). Root cause: MVAI managed training job hit its configured expiration date, silently stopping all training. Discovered ~10h after failure. Bot also published pattern matching analysis confirming P17 (OT job expired) with a sub-variant distinction: MVAI managed training job expiry date (MLHub tab) vs fbpkg TTL — fbpkg preserve NOT needed in this case.

## Key decisions made

- **2026-05-22T04:10:17Z** Root cause confirmed: CL-009 MVAI-expired sub-class. Remediation `mvai online-training-mgr unexpire-training-job -m 2128461099` → V9 started → QPS back.
- **2026-05-22T04:10:27Z** No new pattern proposals — S664106 maps cleanly to P17 + CL-009; CL-009 citation updated with fresh evidence.
- Bot flagged detection gap: "no alert fires on CL-009 silent stop class" + "discovered ~10h after failure." A Phase-1 check for MVAI job expiration status on any RUNNING-but-no-progress symptom would catch this.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../resolved-sevs/2026-05/L3-2026-05-14-S664106.md` | Archive created, pending @jameyz ✅/✏️ |

## Cluster / pattern references

- CL-009 — MVAI managed training job expiry (silent stop); citation updated
- P17 — OT job expired / TMS state=EXPIRED; sub-variant documented (MVAI managed expiry date ≠ fbpkg TTL)

## Followup items (not yet done)

1. T271955758 OPEN — OT runbook wiki update (owner: llu6)
2. @jameyz to reply ✅/✏️ on archive

## Cross-refs

- SEVs discussed: S664106
- Related threads: `NDDHycLrYGk` (concise variant of same digest)
