---
human_involved: false
---

# Thread Summary: ig_reels_tab_mtml FS staleness misdiagnosis + R23 class bug fix

_Source: spaces/AAQAVOjYc80 thread `al9dm6HhBi4` · 7 messages · 2026-06-10 19:08–19:13 PT_
_Summarized: 2026-06-11 00:04 PT · last-msg-time: 2026-06-11T02:13:57Z_

## What was discussed

ot-alert-monitor posted a MONITOR verdict for ig_reels_tab_mtml (model 2133008573, IG) citing S674371 (snapshot MSV validation failure) and S674251 (scribe throughput drop) as the root chain. The verdict claimed a ~3h FULL_SNAPSHOT gap. The bot immediately detected the contradiction: the evidence came from `meta ai.model.instance list`, which silently drops sparse FULL_SNAPSHOT instances when deltas crowd the window — the exact trap documented in `snapshot-query-canonical.md`. The authoritative describe-probe showed FS #41407 @ 18:13 PT (valid, age 56m), disproving "publish stuck." The bot corrected the verdict in-thread and patched R23.

## Key decisions made

- **[2026-06-10 19:12 PT] Verdict corrected:** "publish stuck / ~3h FS gap" was disproven. FS 41407 published post-MSV-failure and post-restart; publish side recovered. L2 trigger by 22:16 PDT was not warranted on FS-publish grounds.
- **[2026-06-10 19:12 PT] R23 class bug fixed:** R23 now derives FULL_SNAPSHOT verdict from `check_snapshot_freshness.py` (describe-probe) as primary; `meta ai.model.instance list` demoted to `confidence≤0.5` fallback stamped "may false-stale." Pushed to sqlite (updates=1 confirmed).
- **[2026-06-10 19:13 PT] Validator failure noted:** The Claude validator "confirmed" the wrong call because it re-ran the same `list` method — shared blind spot. Flagged as evidence for the cross-model codex pilot scope.
- **Real watch item** after correction: Sigrid serving-side — does Sigrid load FS 41407? The Sigrid-FS-age sub-alert is a serving-load metric, not a publish metric; owned under S674371.

## Files / artifacts touched

| path | what changed |
|---|---|
| `ot-alert-monitor.md` R23 step | FS-freshness source switched from `list` to `check_snapshot_freshness.py`; `list` demoted to tagged fallback |
| sqlite (myclaw.db, ot-alert-monitor cron) | Patched R23 prompt pushed live (updates=1 verified) |

## Cluster / pattern references

- [CL-001] Snapshot-stuck — adjacent; this thread's FS issue was validator-method-caused, not a real stuck-creating scenario, but the same staleness-detection gap applies
- [CL-003] Downstream-infra reliability (Scribe) — S674251 (scribe reader throughput drop) was the upstream trigger of snapshot NE regression in this chain
- [CL-018] Alert noise (AGG/dead-detector) — the alert included 3 [dead detector] sub-alerts correctly filtered by R22; bot distinguished real sub-alerts from noise

## Followup items (not yet done)

1. Monitor S674371 (<https://www.internalfb.com/sevmanager/view/674371>, jiaweihuang/ig_rec_modeling_lsr) — watch whether Sigrid actually serves FS 41407 once scribe lag (S674251) mitigates; if unmitigated past 8h window the L3 may escalate under its own SLO.
2. Scope the codex cross-model pilot to include FS-staleness triage verdicts where Claude validator shares the `list` blind spot.

## Cross-refs

- SEVs discussed: S674371, S674251
- Related threads: (none in db from this thread's message content)
