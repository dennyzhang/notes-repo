# Thread Summary: Backfill Strategy — Alerts, Posts, and SEVs

_Source: spaces/AAQAVOjYc80 thread `d9mwts37ggk` · 7 messages · 2026-05-18_
_Summarized: 2026-05-18 23:43 PT · last-msg-time: 2026-05-18T05:07:32Z_

## What was discussed

Denny asked whether mitigated alerts and Workplace posts should receive the same archival backfill treatment that was being applied to SEVs. The bot walked through the tradeoffs for each data type and recommended a tiered approach. The session ended with confirming that all planned work was complete and pushed.

## Key decisions made

- (2026-05-18T03:57Z) **Alerts: no backfill.** ODS retention is <30d for most signals; pre-2026-05-15 bot triage context doesn't exist; stubs would be empty tombstones. Instead: run a one-shot daiquery for monthly alert counts → `historical-baseline.md`.
- (2026-05-18T03:57Z) **Posts: April only backfill.** WP post body + comments persist indefinitely; ~26 archives from mrs.ot Workplace group. Skip March unless April surfaces something interesting.
- (2026-05-18T03:57Z) **SEVs: April + March backfill.** Highest ROI — postmortem fields (root_cause / remediation) survive forever; 33 archives landed.
- (2026-05-18T05:06Z) **Work confirmed done.** 33 SEV archives, 26 post archives, INDEX.md + MISSING.md updated (totals: 67 kept / 124 rejected). Pushed at commit `1a0665419916` on `remote/master`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/resolved-sevs/` | +33 backfill archives (Apr+Mar 2026) |
| `mrs-ot-agent-context/resolved-posts/` | +26 backfill archives (Apr 2026) |
| `mrs-ot-agent-context/resolved-sevs/INDEX.md` | regenerated |
| `mrs-ot-agent-context/resolved-posts/INDEX.md` | regenerated |
| `mrs-ot-agent-context/resolved-posts/MISSING.md` | extended with 33 kept + 67 rejected; running totals updated |

## Cluster / pattern references

_(no cluster IDs cited in thread)_

## Followup items (not yet done)

1. Tighten `scope_check.py` to encode refined rule in code (currently post-filter only) — Denny, parked
2. CL-NNN remap pass for the 33+26 new `(unmapped)` archives — Denny, parked
3. Land P_new(1) as P-row under CL-013 and P_new(2) as CL-013 detector-pitfall note — parked
4. Add louder "validator unavailable" banner in `ot-daily-learning-mitigated-posts.md` — parked

## Cross-refs

- SEVs discussed: _(none specific)_
- Posts: _(mrs.ot Workplace group, April cohort)_
- Related threads: `Uc-pVBEXNQ8` (OneDetection urgency taxonomy, referenced in context)
