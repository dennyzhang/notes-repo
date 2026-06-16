# 2026-06-08 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 16 human messages spanning 2026-06-02T09:03 → 2026-06-04T11:47 PT in **MVAI OT Dev** (8 members; primary contributors: Denny Zhang 6, Li Lu 6, Paul Lu 3)._

_Window: 7d. Skip-until: not set (active polling)._

---

## P0 — bot-integration-blocking items

**1. Delta publish cycle now configurable (D107207628, accepted)**
Li Lu: D107207628 makes whether to skip the current delta publish cycle configurable when a publish would block training. Default = skip (no training block). Configurable: model teams can set a wait duration if freshness > QPS matters for them. Addresses root cause from S668980 analysis (Paul Lu). Li Lu accepted; Denny reviewed and approved. Bot should know this knob exists when diagnosing "training blocked by delta publish" patterns.

**2. Arbaz Khan joined MVAI OT team (weekly meeting)**
Denny onboarded Arbaz Khan to the MVAI OT weekly meeting as of 2026-06-04. Meeting conflict unresolved. Bot context: team now has Denny + Li Lu + Paul Lu + Arbaz Khan. Li Lu's earlier state note mentioning "Arbaz recruitment in progress (Li Lu→Michael Chen)" — Arbaz is the confirmed onboard, not Michael Chen.

---

## P1 — significant nuance / sub-mechanisms

**MVAI OT 2026 tracker = canonical H1 committed model list**
Li Lu confirmed this is the source of truth for committed OT models (Video + Threads) for H1:
`https://docs.google.com/spreadsheets/d/1rzmeEPSgzHO5fR8sNzZixuZzdOe__bwbzQ7KEDEUX_8/edit?usp=sharing`
Bot should cite this when asked "which models are committed for OT this half" rather than guessing from SEV history.

**ETT fixes active (Paul Lu)**
Paul Lu was working on ETT (likely Embedding Table Training) fixes during 2026-06-03. Sporadic availability that day (flat tire). No detail on which ETT issue; may connect to efficiency/OT reliability work.

---

## P2 — references / good-to-know

**ML Infra launch tracker 2023-2026**
`https://docs.google.com/spreadsheets/d/1Dq0ECEA1NbPppahkuw5CvDZbK4ZpM_TRJVYJtumsPpc/edit?usp=sharing`
Covers models the MVAI OT team helped support/debug/unblock that weren't originally in the committed list. Complements the MVAI OT 2026 tracker.

**Team MyClaw space now accessible to Li Lu + Paul Lu**
Denny added Li Lu and Paul Lu to `spaces/AAQA2bZMw24` on 2026-06-02. Both now have access. Keyword: `!ot-bot`. Sibling agent coordination surface — watch for any mentions of `!ot-bot` interactions that might surface triage overlap with this MyClaw instance.

**Li Lu PTO 2026-06-04 to 2026-06-05**
Back 2026-06-06 (Friday). Paul Lu was out 2026-06-02 (dad's cataract surgery). Both returned by week's end.

---

## Cross-references

None explicit. Denny's question about committed H1 models for Video/Threads (thread `9nrwZyum8YU`) directly confirmed the MVAI OT 2026 tracker as the answer — bot previously had no canonical URL for this.

---

## Open coordination threads

1. **Weekly meeting conflict for Arbaz Khan** — flagged 2026-06-04, not resolved. Denny: "we can discuss how to mitigate this meeting conflict later." Needs follow-up to find a slot that works for all 4 members.
2. **D107207628 review** — Li Lu asked for a second look from Denny; Denny said "I can take a look tomorrow" (2026-06-02). Verify if review completed and diff landed.

---

## Integration priority table

| Priority | Item | Where to integrate | Time est |
|---|---|---|---|
| P0 | Delta publish skip-or-wait configurable (D107207628) — add as known knob for training-blocked-by-publish pattern | `known-patterns.md` § delta-publish-block | 10 min |
| P0 | Arbaz Khan on team roster; correct state note re: "Michael Chen" → Arbaz Khan confirmed | `mrs-ot-context/` team file or USER.md addendum | 5 min |
| P1 | MVAI OT 2026 tracker URL as canonical H1 committed-model source | `references/` or `SKILL.md` § model-inventory | 5 min |
| P2 | ML Infra launch tracker URL | `references/` | 5 min |
