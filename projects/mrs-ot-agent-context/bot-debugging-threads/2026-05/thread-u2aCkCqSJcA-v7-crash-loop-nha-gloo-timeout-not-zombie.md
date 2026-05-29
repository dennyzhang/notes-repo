# Thread Summary: v7 OT Job Crash-Loop Triage (NHA Gloo Timeout, Not a Zombie)

_Source: spaces/AAQAVOjYc80 thread `u2aCkCqSJcA` · 7 messages · 2026-05-27T05:20–06:04Z_
_Summarized: 2026-05-28 21:45 PT · last-msg-time: 2026-05-27T06:04:59Z_

## What was discussed

Denny asked to debug "why v7 become a zombie training job." Bot investigated and found it was a crash-loop, not a zombie: v7 had 4 attempts (all FAILED/DEAD), with v7/3 killed manually by rayx to launch v8 in MWG. Root cause was NHA region capacity pressure (under_supply=Yes, tenant_under_quota=Yes for feed_online_launched_esr) causing a peer worker to go silent, triggering a Gloo TCP Read timeout on the publish path after 30 min. MAST then had a 1h 18m death-detection lag on attempt 0. Denny pushed back on the "zombie" characterization, correctly identifying it as a crash-loop.

## Key decisions made

- [06:04Z] Confirmed: "zombie" label was wrong. v7 was a crash-loop (actively failing and relaunching) with manual termination, not a P44-GIL-hang or elastic-agent hang (memory: `p44-vs-elastic-agent-hang.md`). A third zombie pattern was identified: trainer crashes but MAST death-detection lags, creating a "post-mortem zombie" window.
- [05:21Z] TMS placed v8 in MWG (not NHA) — NHA region implicated as failure zone; recovery path: monitor v8's first publish event.

## Files / artifacts touched

| path | what changed |
|---|---|
| _(none confirmed in thread — bot offered to amend heartbeat note + add memory; unclear if it was executed)_ | |

## Cluster / pattern references

_(cluster for Gloo-TCP-publish-path hang under NHA capacity pressure not formally filed as CL-NNN; the mechanism resembles CL-003 preconditions but is trainer-internal timeout, not downstream-infra per se)_

## Followup items (not yet done)

1. Distinguish "crash-loop" vs "zombie/hang" in bot terminology — memory entry offered but not confirmed written.
2. MVAI infra: 30-min Gloo Read timeout on publish path too long for OT SLO ≤10 min; recommend shorter timeout or stuck_job_detection preemption.
3. MAST: 1h 18m FAILED-detection lag in NHA-region failure — HPC watcher review suggested.

## Cross-refs

- SEVs discussed: none (the v7 incident was below SEV threshold)
- Related threads: none
- Model: likely ig_feedrec_esr or similar (entitlement feed_online_launched_esr, region NHA→MWG on v8)
