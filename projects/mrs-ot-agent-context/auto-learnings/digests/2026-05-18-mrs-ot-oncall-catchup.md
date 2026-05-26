# 2026-05-18 — MRS Online Training Oncall catch-up (gchat `spaces/AAQATpEgSyk`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: ~40 human messages spanning 2026-05-04 → 2026-05-12 in **MRS Online Training Oncall** (18 members; primary contributors: Anthony Foiani, Denny Zhang, Paul Lu, Michael Chen, Li Lu)._

_Window: 14d (first-run). first-run: true. Note: most recent messages in this space are from 2026-05-12; space may have been quieter after that date in this window._

---

## P0 — bot-integration-blocking items

### P0-1: SilverTorch model routing rule — mrs_online_training takes first-crack
Confirmed 2026-05-06 thread: when a SilverTorch model (mvai-training-online-877766818 missed fullsnapshot) triggers alerts, **mrs_online_training oncall investigates first**. If root cause is in SilverTorch internals, escalate to SilverTorch oncall.

Paul Lu: _"We should take first crack at investigation and if it's an issue in ST, escalate to them. I'm treating ST as a component here like DPP or Manifold. Open to opinions given how integrated ST is with MVAI."_

**Bot integration:** do NOT route SilverTorch model alerts directly to ST oncall. MRS oncall owns triage; ST is downstream escalation if the fault is in ST code.

### P0-2: SLICK real-time data always stale — do NOT cite for real-time state
SLICK data has Presto-related delay; "today's data is bogus" per Anthony. Also, adding new models to SLICK triggers SLI recompute (all rollups) which requires Presto — currently Presto is blocked (Workplace thread referenced).

Paul: _"we've been using that dash to assess trend as opposed to realtime issues. Realtime issues, we rely on alerting."_

Michael Chen escalated a concern on 2026-05-11 based on SLICK showing many pink models. Paul and Anthony clarified: the pink was stale/in-progress backfill data, not real-time failures. No fleet-wide alert existed.

**Bot integration:** never assert real-time model health from SLICK current-day column. When operator shows SLICK pink/red, treat as "potential trend signal requiring alert-system verification."

---

## P1 — significant nuance / sub-mechanisms

### P1-1: SLO representation debate — model_id vs model_type vs named SLO suites
Anthony Foiani raised unresolved architectural question (2026-05-11):

> "How should we represent the SLOs for these models?
> - model_id level: go stale/disappear as we refresh baselines
> - model_type level: new-tech launch candidates / old-tech holdouts might not have same SLOs
> - both: painful"

Anthony is leaning toward "named SLO suites" at MT level + per-model-id override for exceptions. No decision made; conversation unresolved.

**Bot implication:** SLO attribution for model_id-level alerts may be unreliable if the model recently changed baselines. When triaging an alert where SLICK shows model red, verify whether the model_id is still the current production model for that family (model_id may be stale post-refresh).

### P1-2: Product team dashboards for Discovery and IG models
Michael Chen shared (2026-05-11):
- Discovery Online Models monitoring dashboard (fburl shortcut — not emitting due to URL policy)
- Instagram Online Models monitoring dashboard (fburl shortcut — not emitting due to URL policy)

Paul: "The SLIs should be tied to detectors — so we or home_ml_platform should be receiving alerts if there's an issue." Some models appearing pink last week were newly added tier-1s, not actively failing.

**Bot note:** when cross-referencing model-level SLO state, product team owns these dashboards. Bot should route product owners to their own dashboard rather than reconstructing the same data from scuba queries.

### P1-3: SEV S652695 — Threads Feed LSR online training not stable
Mentioned 2026-05-04. Mitigated. Paul Lu leading the SEV. Denny suggested adding `mvai-online-training-review` tag. SEV: `https://www.internalfb.com/sevmanager/view/652695`

### P1-4: QE launch process task filed — T271013271
Task filed 2026-05-12: "Establish QE launch process for OT support — i) onboarding support ii) align on support SLA." Li Lu taking lead.
URL: `https://www.internalfb.com/tasks/?t=271013271`

### P1-5: mrs_online_training alert subscription — did NOT fire for May 11 fleet-wide concern
Li Lu checked on 2026-05-11 (referencing monitoring alerts page): "Does not seem we got fleet wise alert." Context: Michael Chen flagged SLICK showing many pink Disco models. No corresponding mrs_online_training alert existed. Confirmed this was a SLICK data presentation issue, not a real fleet event.

**Bot implication:** if operator flags that SLICK shows a fleet-wide red/pink but no mrs_online_training alert exists → classify as SLICK_DATA_ISSUE (Presto delay) before investigating as real fleet failure.

---

## P2 — references / good-to-know

### SLICK per-service banner request — unresolved
Denny (2026-05-11): "Is it possible to always avoid showing today's data in SLICK? This might be a recurring confusion for anyone distant from this field." Anthony: "I don't know if there's a per-service banner feature." Michael Chen: confirmed no banner exists. MUMU project intended to fix the underlying data delay.

### SEV review candidates link
Denny (2026-05-04): SEV review candidates were being tracked manually for the mrs-online-training rotation. No automated tracking at that time.

---

## Cross-references

- **S652695** — Threads Feed LSR online training not stable. Mitigated. Paul leading. mvai-online-training-review tag candidate.
- **T271013271** — QE launch process. Li Lu owns. Open.
- **mvai-training-online-877766818** — SilverTorch model that triggered SilverTorch routing discussion. Missed fullsnapshot 2026-05-06.

---

## Open coordination threads

1. **SLO representation (model_id vs model_type vs SLO suites)** — Anthony unresolved on architecture. Operator may want to align with Anthony Foiani before bot emits strong SLO-compliance verdicts at model_id granularity.
2. **SLICK Presto blocker** — Anthony's project underway. Workplace thread shared for context. ETA unknown. Until resolved, SLICK is trend-only.
3. **OT oncall response SLA** — Denny proposed 1d SLA for non-SEV2+ to scale support. Anthony pushed back (perverse incentive to file more SEV2s). No resolution. Operator should decide policy.
4. **T271013271 QE launch process** — Li Lu taking lead. No completion date visible in thread.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | SilverTorch routing rule | failure-patterns.md: "SilverTorch model alerts → MRS first-crack, then ST escalation" | 10 min |
| P0 | SLICK today's data always stale → do not cite for real-time | ot-alert-monitor + ot-sev-monitor: SLICK real-time caveat | 15 min |
| P1 | SLICK fleet-wide pink without alert = SLICK_DATA_ISSUE | ot-alert-monitor: add classification check | 20 min |
| P1 | model_id SLO reliability — verify if model is still current prod | ot-alert-monitor: add model_id currency check note | 15 min |
| P2 | T271013271 QE launch process reference | ot-launch-related prompts | 5 min |
