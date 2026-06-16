# Thread Summary: Model 2129126909 (ig_mixed_ifr_u2i baseline) — Tenant Preemption Killed att1, att2 Recovered

_Source: spaces/AAQAVOjYc80 thread `kvLe-AJYdn0` · 3 messages · 2026-05-15T17:28–17:28 UTC_
_Summarized: 2026-05-16 14:31 PT · last-msg-time: 2026-05-15T17:28:57Z_

## What was discussed

OT alert triage: model 2129126909 (ig_mixed_ifr_u2i_combined_omni_retrieval baseline). Scribe sparse-delta latency alert at 07:07 UTC May 15. Root cause: P10-variant tenant preemption — fire-limaojia (priority 50) preempted att1 (priority 40, tenant feed_online_qe_retrieval) at 2026-05-15 04:04 PDT. Graceful shutdown exceeded 300s; forceful kill. att2 started 11:07 UTC and publishing normally. Alert was transient during att1's final hours. Validator confirmed all error verbatim claims.

## Key decisions made

- (2026-05-15T17:28:21Z) Root cause: P10-variant preemption by higher-priority tenant; alert auto-resolved with att2 stabilization
- No active failure at triage time; no owner page required
- If preemption recurs: escalate to ig_feed_retrieval to raise tenant priority (40 → higher) or request dedicated capacity

## Files / artifacts touched

_(None — read-only triage.)_

## Cluster / pattern references

- [CL-006] — MAST scheduling/capacity as silent root; preemption by tenant priority difference is a scheduling-capacity class failure
- P10-variant [VERIFIED] — job preempted by higher-priority tenant; fire-limaojia at level 50 vs model at 40
- P44 / P48 (GIL hang / blocked RPC) — falsified; publishing was active at 07:07 UTC
- P17 (fbpkg expired) — falsified; no TMS expiry in att1 error

## Followup items (not yet done)

_(None — triage closed; att2 stable, alert auto-resolved.)_

## Cross-refs

- SEVs discussed: none
- Alert: `3362683783911618@#$scribe_read_proxy@...` (sparse delta latency, 07:07 UTC May 15)
- Owners: stevezhuang (primary), oncall ig_feed_retrieval, MAST jongha
- Related threads: `0DnwCD0cCII`, `jJ-go695RTY` (concurrent triage session — note: these three alerts had three distinct root causes, not a shared scribe pipeline issue)
