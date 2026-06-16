# Thread Summary: 🟡 MONITOR wenkai — m878102693 IG scribe lag (CL-003) + audit of 878858380 triage

_Source: spaces/AAQAVOjYc80 thread `yXZMouOo5sU` · 4 messages · 2026-05-21_
_Summarized: 2026-05-22 07:47 UTC · last-msg-time: 2026-05-21T23:59:23Z_

## What was discussed

Two overlapping topics in one thread. Primary: OT MONITOR for model 878102693 (ig_organic_feed_mtml holdout trainer), where elevated scribe_read_proxy.client_lag_in_seconds self-resolved; sibling 2134319967 (baseline) had the same lag same day, pointing to CL-003 (upstream infra cascade). S665066 (FileService zippy shards soft-throttling, In Progress) flagged as likely write-backpressure root cause. Secondary: MyClaw's audit response for P2346253789 (m878858380 NaN triage, from thread ULIdZMP8AN8) was routed into this thread — a routing artifact. The audit flagged R-VERDICT-STABILITY violation, unexplained ~18h FULL_SNAPSHOT gap on v145, and owner-routing inconsistency between job-owner (yufengma) and model-series-owner (yzqian). Auditor self-heal at 23:59 UTC corrected fire-time TZ on the scribe-lag alert.

## Key decisions made

- [2026-05-21T15:07:01Z] Verdict: 🟡 MONITOR wenkai — scribe lag auto-resolved, TRANSIENT_NOISE, confidence medium; no immediate action
- [2026-05-21T15:10:31Z] MyClaw audit of 878858380 triage (P2346253789) identified 3 issues:
  1. R-VERDICT-STABILITY: verdict flipped from NO_ACTION (high confidence) → MONITOR (high confidence) within 17 min on same alert — at minimum downgrade confidence on one
  2. FS-cadence gap: ~18h gap since last FS not explained — v145 silent stall or early death not addressed in triage
  3. Owner-routing: job-owner (yufengma) vs model-series-owner (yzqian) inconsistency is undocumented; recommend formalizing the rule
- [2026-05-21T23:59:23Z] Auditor self-heal R-EV1: alert_created_time=1779336464 → 04:07 UTC / 21:07 PDT; body mislabeled as UTC; verdict tier unchanged

## Files / artifacts touched

| path | what changed |
|---|---|
| `https://www.internalfb.com/intern/paste/P2346255208/` | Machine fields for m878102693 scribe-lag triage |
| `https://www.internalfb.com/intern/paste/P2346253789/` | 878858380 triage paste — audited by MyClaw in this thread |

## Cluster / pattern references

- [CL-003] — scribe lag on 878102693+2134319967 matches Upstream-infra-cascade pattern; S665066 (FileService zippy) as likely backpressure vector

## Followup items (not yet done)

1. wenkai: if scribe lag recurs, correlate with S665066 FileService zippy shards — route to ZippyDB/Scribe oncall if confirmed
2. (From audit, unconfirmed by Denny) File patches to: (a) detect intra-window verdict flips, (b) add FS-cadence sanity check, (c) document owner-routing rule

## Cross-refs

- SEVs discussed: S665066 (FileService zippy, In Progress), S663987 (NE unstable, mitigated 2026-05-14), S665692 (NE spikes, mitigated 2026-05-18), S665163 (ZippyDB, mitigated)
- Alert: A2387001468469120
- Related threads: `ULIdZMP8AN8` (m878858380 audit landed here due to routing artifact), `ZVdqxp0KIX8` (sibling cfr family on same day)
