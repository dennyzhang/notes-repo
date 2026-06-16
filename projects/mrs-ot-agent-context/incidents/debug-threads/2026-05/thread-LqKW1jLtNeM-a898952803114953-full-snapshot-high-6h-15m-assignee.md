# Thread Summary: Alert Mapping — FULL_SNAPSHOT Paired Alerts + Validator Gap Closed

_Source: spaces/AAQAVOjYc80 thread `LqKW1jLtNeM` · 5 messages · 2026-05-17 05:13 – 05:16 UTC_
_Summarized: 2026-05-17 13:31 PT · last-msg-time: 2026-05-17T05:16:47Z_

## What was discussed

`ot-daily-learning-mitigated-alerts` cron fired for 2026-05-16 digest. Operator submitted a pattern-triage annotation; bot integrated and closed a known validator gap.

Alerts processed:
- **A898952803114953** (FULL_SNAPSHOT, high, ~6h15m, model 878858380) + **A4366891846955592** (~6h30m, same model) → both mapped to [CL-001]. These fired simultaneously at 11:59 PDT and cleared at ~18:15–18:30 PDT.
- **A1480195820275950** (~2h, e2e latency sparse delta) → mapped to [CL-013]. Operator hypothesis: P04.
- **A2130305043** (~14h) → mapped per operator triage.

Pattern matches (operator triage, unverified at cause level): P38/P17 for paired FULL_SNAPSHOT alerts; P04 for e2e latency.

Validator-unavailable gap: cron context lacks Agent tool so the validator-pass step in `ot-daily-learning-mitigated-alerts` cannot run. Bot documented this as a known structural gap and confirmed operator triage was correct (no corrections needed).

## Key decisions made

- **2026-05-17T05:16Z** — Validator-unavailable gap formally documented and closed for this session. No new patterns warranted from this digest.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/mega-learnings/registry/CLUSTERS.md` | CL-001 evidence updated (A898952803114953 + A4366891846955592 paired alerts, model 878858380) |
| `mrs-ot-agent-context/mitigated-alerts/2026-05/` | Alert archive files added |

Commit: `1c1c9fe28b53` (5 alerts mapped + 3 bugs fixed), `be9fb50b6b63` (validator gap).

## Cluster / pattern references

- [CL-001] — Snapshot-stuck-CREATING (heterogeneous); paired FULL_SNAPSHOT alerts for FB CFR Main MTML model 878858380 added as evidence
- [CL-013] — Training-age / example-age spike; e2e latency sparse delta alert (A1480195820275950) added

## Followup items (not yet done)

_(No followups discussed.)_

## Cross-refs

- Related threads: `auJF0q4xTiY` (same session's post triage)
