# 2026-05-18 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: ~75 human messages spanning 2026-05-04 → 2026-05-18 in **MVAI OT Dev** (8 members; primary contributors: Denny Zhang, Paul Lu, Li Lu, Anthony Foiani)._

_Window: 14d (first-run). first-run: true._

---

## P0 — bot-integration-blocking items

### P0-1: D104919036 — pre-triage health checks now exist in MVAI agent
Denny filed and landed D104919036: _"[MVAI agent][mvai-ot] Add pre-triage health checks for training example age and QPS."_ (2026-05-12).

**Two checks now run before issue triage:**
1. Training example age
2. Training QPS

**Bot integration:** ot-alert-monitor and ot-sev-monitor should be aware these pre-checks exist in the MVAI agent skill. If the MVAI agent already ran them for a given job, bot should not duplicate. Cross-reference results from these checks before asserting data-staleness verdict.

### P0-2: No canonical tier-1 model list for Video / Facebook PG
Active question in team (2026-05-15): what are the committed OT models for Video and Facebook PG? No ground-truth source exists.

Key data:
- **Video SLICK shows 25 models** — but only 3 are in the commitment doc. Dave: "jumped from 5ish to 25 in a few weeks. That's probably incorrect."
- **IG has explicit commitments** (documented from Q1). Video/PG do not.
- **Paul's reference doc** (PG TL sign-off from start of 2025 H2): `https://docs.google.com/document/d/1vMFhbucCwJkQVdD3bTGt-7cE6sdDE2nanGSoiUyvLOU/edit`
- **Hongzhang Yin** is the POC for reliability effort — knows the agreements.

**Bot implication:** when triaging Video or PG model alerts, do NOT assume SLICK coverage = committed model. Verify against committed model list (currently not canonical, ask Hongzhang Yin). Alert on models that are NOT in any known commitment list with lower confidence and note the uncertainty.

---

## P1 — significant nuance / sub-mechanisms

### P1-1: Agent triage accuracy target — 80% by end of Q2 2026
Denny (2026-05-08): _"improve agent to nail 80% of prod model issues in Q2. (from 0% in Q1, 40% in April initial launch)"_. Currently "sub-50%." Three remaining classes after Q2:
1. 20% known prod issues (the long tail)
2. New prod issues (continuous learning)
3. New onboard + QE support (hard to automate)

This is the strategic framing for agent Q2 scope.

### P1-2: MVAI ETT Event Logging — training metadata now wired
Paul Lu landed three diffs:
- D104310013: Wire collected training metadata into MVAITrainingEventsLogger from RecTrainer
- D104310014: Add TrainingMetadata schema and set_trainer_metadata wiring
- D104475167: Convert _train_impl to use log_timed_event decorator

**Bot context:** ETT (Efficient Training Telemetry?) event logging is being expanded. Training metadata is now flowing into the logger. When triaging jobs, ETT logs may contain richer training metadata than before — checkpoint timing, trainer metadata, etc.

### P1-3: SilverTorch model routing rule
Confirmed (2026-05-06): when SilverTorch model (e.g., mvai-training-online-877766818) misses fullsnapshot, **mrs_online_training takes first-crack at investigation**. If root cause is in SilverTorch component (not just OT infra), escalate to SilverTorch oncall. Paul: _"I'm treating ST as a component here like DPP or Manifold."_

### P1-4: SLICK backfill blocked — Presto issue (Anthony Foiani, 2026-05-11/12)
Anthony (2026-05-12): _"Dashboard data might be completely broken right now, having some issues with the backend tech."_

Root cause: Presto completely blocked. Adding a model to SLICK requires recomputing ALL SLIs (rollup recalculation), which requires Presto. So any new model addition breaks SLICK backfill. 

**SLICK data reliable from 2026-04-25 forward** (earlier data may be incomplete). Anthony is working on fix; no ETA.

**Bot implication:** when using SLICK data for historical SLO trends, note the 2026-04-25 data floor. Do not assert historical SLO pass rates with confidence before that date.

### P1-5: SLICK today's data is always stale — use alerting for real-time
SLICK data has a known Presto-related 1d delay. Paul (in MRS Online Training Oncall space): _"we've been using that dash to assess trend as opposed to realtime issues. Realtime issues, we rely on alerting."_

Anthony noted MUMU project is intended to fix this ("today's data is bogus is something MUMU is hopefully fixing").

**Bot implication:** never use SLICK's most-recent-day column to assert real-time state. If today's SLICK shows pink/yellow, it reflects yesterday's data at best.

### P1-6: OT oncall volume and response SLA discussion
Current load: ~15 SEVs + 5 posts per shift per oncall. Denny proposed (2026-05-11) response SLA for non-SEV2+: 1 day, leverage agent for initial triage. Anthony's pushback: risks inflating SEV severity. Still unresolved.

Li Lu confirmed: oncall is seeing more SEVs recently — many are QE/important models where PG team opens preemptive SEVs for debug/new ideas, not just prod failures.

### P1-7: QE launch process task filed — T271013271
Task filed 2026-05-12 via `#fileatask`: "Establish QE launch process for OT support — i) onboarding support ii) align on support SLA." Li Lu taking lead.
URL: `https://www.internalfb.com/tasks/?t=271013271`

### P1-8: IG escalation scope: MRS committed retrieval first-line, non-retrieval on-demand
Denny drafted message to IG (2026-05-14): _"Per Q1, our group (mvai+pe) committed 1st-line on retrieval + on-demand on non-retrieval."_ Bot should use this framing when routing IG-reported sparse delta escalations.

### P1-9: Reels CS Omni scribe delay — downsampling or capacity increase needed
Li Lu + Patrick: Reels CS Omni (mvai-training-online-2130305043) violates scribe delay 4h/day during peak hours. Root cause: needs downsampling or increased training capacity. Patrick confirmed.

**Bot note:** this is the same model (mvai-training-online-2130305043) previously flagged for FULL_SNAPSHOT staleness. May have ongoing training QPS / capacity constraint.

---

## P2 — references / good-to-know

### OT agent context Q&A doc
Denny shared for team enrichment (2026-05-14): `https://docs.google.com/document/d/1EFyx6KNWaF1AxmB5zqdnPynGF3R-8SSM_Tgfxn5H7uE/edit` — Q&A prep before big group meeting. Contains current state of OT commitments and open questions.

### Paul Lu's ST publisher timing bug learnings (2026-05-04)
Paul (from SEV investigation): two new ST publisher findings:
1. Delay in checkpoint will delay ST publisher snapshot publishing
2. There's a bug where the timer for full snapshot publish doesn't reset properly on checkpoint reload.

Paul was integrating these into the OT reliability skill.

### Team highlight framing (Denny, 2026-05-14)
Three team achievements to cite in reviews (aligned with Shuguang from SilverTorch):
1. Supported IG 10 min ATS end of Q1 (a beat — was projected for Q2)
2. Team does more with less (James left early Q1, Denny new, Li Lu 0.5 in OT, open PE PID closed)
3. Built infra latency breakdown metrics (replacing MGS metric which wasn't effective)

---

## Cross-references

- **mvai-training-online-2130305043** — Reels CS Omni. Scribe delay 4h/day peak. Also prior FULL_SNAPSHOT staleness flag. Potentially chronically constrained.
- **T271013271** — QE launch process task. Li Lu owns. Open.

---

## Open coordination threads

1. **IG escalation SLA** — Denny's proposed 1d SLA for non-SEV2+ unresolved. Anthony pushed back. No decision in chat. Operator should decide before next oncall rotation.
2. **Video / PG model commitment list** — No canonical source. Paul to dig up contracts. Hongzhang Yin is the person who knows.
3. **SLICK expansion for Video models** — Blocked pending Presto fix. Monitor Anthony Foiani's MUMU project for resolution.
4. **IG metrics sharing** — Li Lu was going to reach out to IG about metrics. Denny on 2026-05-18 said to hold off (IG unlikely to prioritize). Decision: hold.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | D104919036 pre-triage checks exist — avoid duplication | ot-alert-monitor: note MVAI agent pre-check exists | 20 min |
| P0 | Video/PG model commitment gap | ot-alert-monitor: lower confidence for Video/PG models not on known list | 30 min |
| P1 | SLICK data floor 2026-04-25 | ot-sev-monitor/ot-alert-monitor: don't assert historical SLO pre-04-25 | 15 min |
| P1 | SLICK today's data always stale | ot-alert-monitor: "do not use SLICK current day" guidance | 10 min |
| P1 | SilverTorch routing rule | failure-patterns.md or ot-alert-monitor routing note | 10 min |
| P1 | MRS committed scope: retrieval 1st-line, non-retrieval on-demand | ot-alert-monitor IG routing context | 15 min |
| P1 | mvai-training-online-2130305043 Reels CS Omni capacity constraint | noisy-models.md entry | 10 min |
| P2 | T271013271 QE launch process | reference in relevant prompts | 5 min |
