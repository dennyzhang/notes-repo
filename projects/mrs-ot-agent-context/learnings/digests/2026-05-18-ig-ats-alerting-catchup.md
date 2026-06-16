# 2026-05-18 — IG ATS Alerting catch-up (gchat `spaces/AAQAtGhVkUw`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 6 human messages spanning 2026-05-14 in **IG ATS Alerting** (6 members; primary contributors: Denny Zhang, Josef Cohen, Li Lu)._

_Window: 14d (first-run). first-run: true. Low message volume this window (6 msgs); but all 6 are high-signal decisions, not noise._

---

## P0 — bot-integration-blocking items

### P0-1: D105212397 LANDED — OT sparse-delta latency alerts now route to mrs_online_training

Josef Cohen's diff `D105212397` completed final review by Pei Zhang on 2026-05-14.

**Diff title:** `[Real Time Infra] Centralized alerting: route OT sparse-delta latency alerts to mrs_online_training`

**What this means:**
- IG has per-model sparse alerts built into their model registry centralized alerting system
- D105212397 subscribes `mrs_online_training` oncall to IG's OT sparse-delta latency alerts
- **Scope confirmed by Denny:** sparse-delta alerts ONLY. MRS is not subscribed to all IG ATS alerts, only the sparse latency ones.
- Josef: "Let me ensure I can subscribe MRS to just our ATS alert without subscribing them to anything unnecessary"

**Bot integration (P0 — blocking):** As of ~2026-05-14, mrs_online_training oncall is now receiving IG-side sparse-delta latency alerts. The bot's ot-alert-monitor may start seeing alerts from this new source. Bot should:
1. Recognize that IG sparse-delta latency alerts now arriving in mrs_online_training queue are expected (new, not anomalous)
2. Apply the correct triage path: IG ATS latency → check IG OT SLO dashboard → route to Josef Cohen / IG Relevance Foundations if IG-side issue; route to MRS oncall if MRS-side infra issue
3. Do NOT route IG-side ATS alerts to the same triage path as MRS model alerts

**Alert source context:** IG's centralized alerting uses a model registry to define per-model sparse alerts. MRS is now a subscriber. The alert subscription was at the ATS sparse-delta level specifically.

---

## P1 — significant nuance / sub-mechanisms

None beyond P0-1 this window. The 6-message thread is a focused, single-decision conversation.

---

## P2 — references / good-to-know

### Background context from Denny's framing
Denny's message (2026-05-14) explaining why MRS needed this subscription:

> "MRS oncall didn't see a signal in the past few weeks because we don't subscribe to IG OT publish-side alerts; we only see ATS at the top of the funnel when there are SEVs. That's a visibility gap in our upstream chain, not just this one incident."

This subscription closes the visibility gap. Bot can now proactively triage sparse-delta latency signals before they escalate to IG-visible SEV threshold.

---

## Cross-references

- **D105212397** — merged alert routing diff. Canonical evidence that new alerts exist.
- **D105576627** — Josef Cohen's follow-up (OT SLO follow-ups: context toggle, granularity, SLICK linkout). Related to same alerting infrastructure.

---

## Open coordination threads

None — the conversation was a closed decision thread. D105212397 landed; subscription active. No follow-up items in thread.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | IG sparse-delta alerts now arriving in mrs_online_training | ot-alert-monitor: recognize IG-sourced sparse-delta alerts; add IG ATS triage path | 45 min |
| P0 | Alert source mapping: IG centralized alerting → mrs_online_training | Add to failure-patterns.md or triage-discipline.md: "IG ATS latency alerts are now subscribed via D105212397" | 15 min |
