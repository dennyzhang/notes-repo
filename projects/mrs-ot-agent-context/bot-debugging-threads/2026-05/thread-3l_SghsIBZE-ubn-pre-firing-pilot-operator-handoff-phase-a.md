# Thread Summary: UBN Pre-Firing Pilot — ot-alert-monitor Already Exists; Operator Handoff Is the Gap

_Source: spaces/AAQAVOjYc80 thread `3l_SghsIBZE` · 41 messages · 2026-05-27_
_Summarized: 2026-05-28 22:45 PT · last-msg-time: 2026-05-27T19:07:32Z_

## What was discussed

Denny initiated a discussion on building a pre-firing UBN pilot — catching OT failures before they auto-page. MyClaw analyzed 76 OT SEVs over 90 days and proposed three automation patterns (publish_failure, ot_job_stuck, hang_freeze). However, upon reading `team_bot/ot-alert-monitor.md`, it became clear the hourly cron already handles deep triage including detector-URL extraction, R-guards, and REAL_OT_FAILURE classification. The backtest (2130324780 / ig_textpost_feed_m2m_retrieval) showed cron catches 3/4 UBNs 35–64 minutes before the UBN auto-fires — detection is not the bottleneck. The real gap: cron posts 🔴 PAGE in the OT space but on-shift oncall doesn't act before the UBN auto-fires. Denny authorized Phase A: wire a direct @-mention to on-shift oncall inside the threaded reply on REAL_OT_FAILURE classification. Auto-mitigation explicitly parked.

## Key decisions made

- (2026-05-27T16:33, Denny) "let's pause the auto-mitigation in this stage" — v1 scoped to early-visibility + operator ping only.
- (2026-05-27T17:01, Denny) "don't ask, unless absolutely necessary" — standing rule for act-not-ask.
- (2026-05-27T18:59, Denny) "Go" — Phase A authorized.
- (2026-05-27T18:59, Denny) "File a meta task, track design, and status there" — T273153751 filed.
- (2026-05-27T19:07, MyClaw) Phase A shipped: `ot-alert-monitor.md` step 7f added (@-mention on REAL_OT_FAILURE only, separate threaded reply, silent-skip on resolution failure, no paging API). Notes→sqlite parity 72699 bytes ✓.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-alert-monitor.md` | Step 7f added: @-mention on-shift oncall on REAL_OT_FAILURE* |
| `notes/.../auto-fixes/2026-05/20-pre-firing-pilot-operator-handoff.md` | Design doc created |

## Cluster / pattern references

_(No confirmed cluster IDs — omitted)_

## Followup items (not yet done)

1. 7-day shadow run on Phase A, then decision gate for Phase B (pre-alert ODS signals before OneDetection fires).
2. T273151495 (verifiable-triple registry) gates Phase B coverage across 8 failure-pattern buckets.

## Cross-refs

- Tasks: T273153751 (pre-firing pilot), T273151495 (verifiable-triple registry)
- Memory: `feedback_ubn-pull-alert-page.md`, `preference_act-dont-ask.md`
- Related threads: `yF_aMB00xMk` (DPP-rotation + T273151495 origin)
