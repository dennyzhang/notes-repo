# Thread Summary: Transient Scribe Read Lag Alert (Model 2134319967) + "Act Don't Ask" Calibration

_Source: spaces/AAQAVOjYc80 thread `aZ0g0BQ1XNo` · 5 messages · 2026-05-16 06:20–10:10 PDT_
_Summarized: 2026-05-16 22:31 PT · last-msg-time: 2026-05-16T17:10:49.398447Z_

## What was discussed

Denny pasted a bot diagnosis for a T1 scribe read lag alert on model 2134319967 (ig_organic_feed_mtml baseline, owner: wenkai) that fired at 06:14 UTC. The alert type was `client_lag_in_seconds` threshold breach on `scribe_read_proxy`. All ground-truth checks (SPARSE_DELTA cadence, MAST RUNNING, mvai_metrics fresh) confirmed the pipeline was healthy; the lag spike was transient and self-resolved. Validator found two adjacent-but-unrelated active SEVs (S663983 scribe overquota in a different namespace, S665066 FileService ZippyDB write-side throttle) and correctly ruled both out. Combined with earlier alerts, this brought the shift total to 5 alerts / 0 real incidents across 3 distinct false-positive classes.

Secondary: Denny flagged "Say go and I'll write it" as an anti-pattern — bot was asking permission when it had enough information to act. Calibration rule was discussed and locked in the concurrent thread `YjJ5L-XLxCg`.

## Key decisions made

- (2026-05-16T13:21:13 Denny validator): S663983 and S665066 are adjacent-namespace but not on OT scribe read path — standing transient-lag hypothesis confirmed; no action needed.
- (2026-05-16T17:10:49 Denny): "Act don't ask — which part do you really need me?" Reiterated: bot should write mega-learning drafts, prompt edits, etc. without asking when it has the answer.

## Files / artifacts touched

| path | what changed |
|---|---|
| _(none confirmed)_ | Mega-learning draft for 3 alert classes was offered but awaiting bot's own execution per "act don't ask" decision |

## Cluster / pattern references

- [CL-003] — Downstream-infra cascade (ZippyDB / Scribe); Scribe read lag fits class but was transient/self-resolved, not sustained cascade

## Followup items (not yet done)

_(none explicit — Denny explicitly directed bot to stop asking and just act)_

## Cross-refs

- SEVs discussed: S663983 (scribe overquota, EntNewsFeedRfuCache, unrelated namespace), S665066 (FileService ZippyDB write soft-throttle, unrelated to read path)
- Related threads: `aT_6RlZgMwg` (threshold misfit class), `YjJ5L-XLxCg` (DETECTOR_BROKEN class, same shift), `JbRNzEK8Hx0` (cross-model fleet-wide framing)
