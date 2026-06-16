# Thread Summary: Model 878102693 (ig_organic_feed_mtml) AGG — ZippyDB upstream infra (CL-003)

_Source: spaces/AAQAVOjYc80 thread `Lh5QdvHO7Y0` · 4 messages · 2026-05-23T08:54Z → 2026-05-23T08:56Z_
_Summarized: 2026-05-23 21:47 PT · last-msg-time: 2026-05-23T08:56:41Z_

## What was discussed

AGG alert (`:449`) fired for model 878102693 (ig_organic_feed_mtml) — `scribe_read_proxy.client_lag_in_seconds`, 4 sub-alerts aggregated. This was the 5th+ AGG instance for this model in the same ZippyDB cascade pattern. Denny provided a reference triage that added local_archives check and deeper ZippyDB SEV attribution (S654082, S653864, S667276). T3 publish was unaffected throughout. Bot added rules 21-25 to the triage checklist and identified a meta-failure pattern: stopping at first-layer upstream inference rather than digging to actual root.

## Key decisions made

- **2026-05-23T08:55:21Z** — Verdict 🟡 MONITOR / UPSTREAM_INFRA / auto-resolved: ZippyDB AI training infra degradation (S654082 flash overload + S653864 IG capacity + S667276 CPU hot). Route to ZippyDB infra oncall; no OT action needed. Matches [CL-003].
- **2026-05-23T08:56:41Z** — Meta-lesson codified: bot keeps finding "a" plausible upstream and stopping; fix is mandatory deeper-layer queries (ZippyDB AI Training, local_archives) before writing verdict. Rules 21-25 added.

## Files / artifacts touched

| path | what changed |
|---|---|
| `memory/gotcha_triage-discipline.md` | Rules 21-25 added (ZippyDB AI Training, local_archives checks) |
| paste P2348764485 | Machine fields |

## Cluster / pattern references

- [CL-003] — ZippyDB downstream infra reliability cascade causing scribe_read_proxy lag; T3 publish unaffected; route to ZippyDB oncall

## Followup items (not yet done)

_(none — model auto-resolved, route to ZippyDB infra via existing SEVs)_

## Cross-refs

- SEVs discussed: S654082, S653864, S667276 (ZippyDB infra, all in-progress)
- Posts: none
- Related threads: none
