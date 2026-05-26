# Thread Summary: Model 878102693 (ig_organic_feed_mtml) — Stale Scribe Latency Alert, SIGSEGV Self-Recovered

_Source: spaces/AAQAVOjYc80 thread `0DnwCD0cCII` · 4 messages · 2026-05-15T17:27–17:29 UTC_
_Summarized: 2026-05-16 14:31 PT · last-msg-time: 2026-05-15T17:29:03Z_

## What was discussed

OT alert triage: model 878102693 (ig_organic_feed_mtml). Scribe e2e sparse-delta latency spike aggregated 4 alerts at 22:59 UTC May 14 (18h before triage). At triage time, model was fully healthy: SPARSE/DENSE/FULL_SNAPSHOT all VALID, att1 RUNNING, mvai_metrics alive. Root cause: transient scribe read-proxy lag spike during a stable run, coincident with v53/att0 SIGSEGV on 2026-05-12; att1 self-recovered. Validator pass confirmed.

## Key decisions made

- (2026-05-15T17:28:56Z) Alert classified as stale/auto-resolved; no active failure, no owner page required
- Standing hypothesis: transient scribe read-proxy lag; att0 SIGSEGV is the historical disruption but att1 has been stable since
- Confidence: symptom-attribution 85%, root-cause 55% (scribe lag causality inferred, not confirmed)

## Files / artifacts touched

_(None — read-only triage, no artifacts written.)_

## Cluster / pattern references

- [CL-003] — upstream-infra-cascade; scribe read-proxy lag is a known cascade vector
- P44 (GIL hang) falsified — mvai_metrics live at triage time
- P17 (fbpkg expired) — not evaluated (no TMS error in signal)

## Followup items (not yet done)

_(None — triage closed. Alert auto-resolved; monitor for recurrence per standard OT SOP.)_

## Cross-refs

- SEVs discussed: none directly; v53/att0 SIGSEGV not linked to a SEV
- Alert: `ai/model_registry/alerts/.../878102693.aggregation_rule`
- Owners: wenkai (primary), oncall ig_feed_modeling, MAST raywu22
- Related threads: `jJ-go695RTY`, `kvLe-AJYdn0` (same session, concurrent triage — note different root causes)
