# 2026-05-25 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 10 human messages spanning 2026-05-18T20:05 → 2026-05-21T10:47 in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Denny Zhang (4), Pushpak Raj Gautam (4), Dave Kotfis (1), Xinyuan Zhang (1))._

_Window: 7d delta (last_msg_create_time: 2026-05-18T12:20:04 PDT). Skip-until: not set (active polling)._

---

## P0 — bot-integration-blocking items

### P0-1: SS T2I success rate mitigation — client buffer size bump (Dave Kotfis, 2026-05-19)

Dave Kotfis: *"We're bumping client buffer size to mitigate SS T2I success rate"* — D105733308.

**Bot integration:** when triaging Sparse Streaming T2I success rate alerts, check whether D105733308 has landed and whether it's the active mitigation in flight. Do NOT page model owners if this diff is deployed and metrics are recovering.

### P0-2: New failure class — MAST scheduler metadata injection causes binary-identical job to error (Pushpak, 2026-05-18)

**S665521** — All binaries and hardware were identical. A new job attempt produced a new error. Root cause: MAST scheduler code change set metadata on TW hosts. No binary change — just scheduler-injected metadata changed job behavior.

Denny confirmed the fix for the embedding table sharding conflict from this SEV: two env vars disagreed:
- `host_count_per_domain` — MAST-injected (new, from D99725267)
- `TOPOLOGY_DOMAIN_MULTIPLE` — user override

Fix: **user override wins** (TOPOLOGY_DOMAIN_MULTIPLE takes precedence over MAST-injected host_count_per_domain).

**Bot integration:** when a job fails on a new attempt but binary/HW are unchanged, check for recent MAST scheduler metadata changes before attributing to binary regression. S665521 is a new template: "metadata-injection-induced failure."

---

## P1 — significant nuance / sub-mechanisms

### P1-1: Agent design philosophy — authority by domain, adaptive outside domain

Denny (2026-05-19, thread T4AQaxAuzLg): *"Agent for assigned area should be an authority; agent for unassigned area should be a fast learner and critical thinker."*

Concretely: "Dpp agent for dpp, mvai agent for mvai, etc."

Pushpak raised: can we verify Claude didn't "cheat" (i.e., pull answers from SEV comments that were written post-incident)? Denny: for assigned area, agent shouldn't cheat (must use original signals). For unassigned/new area, some mercy is acceptable.

**Bot relevance:** this is design validation. The OT bot should NOT rely on SEV comment text as a signal when triaging (those can be post-hoc and circular). Evidence must come from pre-existing telemetry.

---

## P2 — references / good-to-know

- **S665521** closed or being resolved — see mrs-ot-oncall catchup for fuller PVR context
- **Weekly sync (RT Infra WS2) canceled 2026-05-21** — Xinyuan Zhang: "Just canceled this week"
- D105733308 — client buffer size bump for SS T2I success rate (Dave Kotfis, 2026-05-19)

---

## Cross-references

- S665521 appears in both rtinfra-ws2 AND mrs-ot-oncall — full triage context in oncall catchup
- D99725267 — MAST scheduler host_count_per_domain injection (root cause of S665521 embedding conflict)

---

## Open coordination threads

- **Was D105733308 (client buffer bump) sufficient for SS T2I recovery?** Dave FYI'd it but no follow-up in window. Operator should confirm resolution.
- **S665521 resolution status** — confirm TOPOLOGY_DOMAIN_MULTIPLE-wins fix landed and job is healthy.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | SS T2I alert → check D105733308 mitigation before paging | ot-alert-monitor verify-step: check if D105733308 is active mitigation | 30 min |
| P0 | New failure class: MAST scheduler metadata injection (S665521 template) | failure-patterns.md: add "metadata-injection-induced failure" pattern | 30 min |
| P1 | Agent anti-cheat rule: evidence must come from pre-existing telemetry, not SEV comments | ot-alert-monitor system prompt: "do not use SEV comment text as triage signal" | 15 min |
