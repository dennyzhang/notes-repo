# Thread Summary: Disk-full cascade — cron missed completions (3 health-watch reports)

_Source: spaces/AAQAVOjYc80 thread `c8EAgZyDIKU` · 3 messages · 2026-05-21 12:53:04–12:53:26 UTC_
_Summarized: 2026-05-24 17:50 PT · last-msg-time: 2026-05-21T12:53:26Z_

## What was discussed

Three `ot-cron-health-watch` alerts fired in rapid succession reporting cron missed completions caused by a disk-full event (`/dev/vda4` at 100%, 141MB free). The alerts documented the cascade and recovery status of three impacted cron jobs. No operator action was captured in-thread.

## Key decisions made

_(No decisions captured — all three messages were cron-generated health reports, no operator or bot replies.)_

## Files / artifacts touched

_(No file edits in this thread — health-watch reports only.)_

## Cluster / pattern references

_(No OT failure-pattern clusters — this is daemon/infrastructure health, not OT training.)_

## Followup items (not yet done)

_(No explicit followup discussed in thread. Root cause — disk 100% — was noted as ongoing risk for repeat kills if /tmp temp dirs accumulate again.)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none cited
- Impacted crons: `ot-triage-auditor` (fire at 05:13 PDT killed at +70s, recovered 05:44 PDT), `ot-prompt-change-validator` (fire 05:27 killed at +12m, 2/3 clean re-fires by 05:41 PDT), `ot-sev-monitor` (message dispatcher error 05:16 PDT, DB write failed)
