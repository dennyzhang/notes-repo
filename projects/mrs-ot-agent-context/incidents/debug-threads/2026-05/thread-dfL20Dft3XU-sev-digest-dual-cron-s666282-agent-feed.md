# Thread Summary: SEV Digest Cron #1 + S666282 Root Cause via Agent-Feed

_Source: spaces/AAQAVOjYc80 thread `dfL20Dft3XU` · 11 messages · 2026-05-20T04:09–06:39 UTC_
_Summarized: 2026-05-20 23:45 PT · last-msg-time: 2026-05-20T06:39:35Z_

## What was discussed

This is the parallel SEV postmortem cron run that fired alongside UH1t_Fwjom4 (both processed S651873, S665607, S666282). This cron initially stub-skipped S666282 (IG HIM PT model 1082814831) due to empty postmortem form fields. Denny later asked "Why gchat inaccessible for 2nd SEV?" (06:38 UTC), which triggered discovery that the bot wasn't a member of the SEV-specific gchat room, but `meta sevmanager.agent-feed list` contained full Opsmate investigation output.

## Key decisions made

- **S666282 root cause found in agent-feed, NOT form fields** (06:39 UTC): Opsmate Investigator reports "PMTS cannot launch training for model 1082814831 because its lifecycle state from 65 days ago is not in `QRT_START_ELIGIBLE_STATUSES`" — 7-day managed training expiration expired. Previously missed because cron checked form fields only.
- **Cron improvement identified**: before applying stub-guard skip, check `meta sevmanager.agent-feed list --sev=<SEV>` for Opsmate Investigator content. Opsmate now auto-investigates most SEV4s with empty postmortems — this fallback recovers a meaningful fraction of stub-skipped archives.
- **P-row proposals collided with UH1t_Fwjom4** (validator 05:39 UTC): this cron proposed P59 (TGIF rendezvous) and P60 (DPP ACL), both already reserved. Validator resolved: S651873→P20 amend, S665607→P62. See thread UH1t_Fwjom4 for full reconciliation.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-sevs/2026-05/L4-2026-05-19-S651873.md` | Created (duplicate with UH1t_Fwjom4 — reconcile needed) |
| `incidents/resolved-sevs/2026-05/L4-2026-05-19-S665607.md` | Created (duplicate with UH1t_Fwjom4 — reconcile needed) |

## Cluster / pattern references

- [CL-003] — S665607 DPP Koski PERMISSION_DENIED; S666282 PMTS lifecycle stall is OT-adjacent but routing to IG HIM

## Followup items (not yet done)

1. Update ot-sev-postmortem-digest cron prompt: add `meta sevmanager.agent-feed list --sev=<ID>` as fallback before stub-guard skip (owner: Denny, Friday batch)
2. S666282 archive still unwritten — PMTS lifecycle root cause now known; archive m1082814831 under IG HIM with Opsmate content as source

## Cross-refs

- SEVs discussed: S651873, S665607, S666282
- Related threads: `UH1t_Fwjom4` (parallel cron run — same SEVs, conflicting P-row numbers)
