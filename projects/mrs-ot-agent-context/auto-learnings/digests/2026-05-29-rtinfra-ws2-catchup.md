# 2026-05-29 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 37 human messages spanning 2026-05-27T07:58 → 2026-05-29T09:39 in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Dave Kotfis ×14, Denny Zhang ×12, Josef Cohen ×7, Paul Lu ×4)._

_Window: 7d (2026-05-22 → today). Standard run._

---

## P0 — bot-integration-blocking items

**New canonical reliability doc** — Denny published the H1 OT SEV study this week. The bot should know this exists and reference it for component attribution decisions:

- Doc: `[MRS OT Reliability] Cross-Team Follow-ups — MAST · DPP · TMS · Publisher · SJD`
- URL: https://docs.google.com/document/d/1mpy7J9r-GCkUTNjQzzdWsJDWbFC9iJ3ctZsFdvyX-qs/edit?tab=t.0#heading=h.r3ctgk36tp4l
- Scope: 64 OT SEVs in H1 → 16 P0 follow-ups across 7 components. Active cross-team work now.
- Tasks filed: T273128182 (MAST reliability), T273130561 (DPP reliability)

**MAST retry eviction gap** — new confirmed mechanism from S668272:
- MAST does not evict bad hosts on retry. Performs up to 20 retries.
- Each retry: 30-60 min (expected ~10 min) → total downtime 4h+ before recovery.
- Additionally: flight recorder runs serially, adds latency to shutdown, delays MAST kill signal.
- Bot should classify "MAST retry storm / no eviction" as distinct failure subclass, not generic MAST failure.
- Owner for resolution: MAST team (task T273128182). OT team asked MAST to build a "job kill latency" metric.

**New open SEV — Reels SS Omni / SS T2I item latency** (in progress as of 2026-05-29 09:14):
- Symptom: item latency increase + null rate spike → fallback to full snapshot → latency degrades further.
- Root hypothesis (Josef Cohen): `high P90+ item snapshot age → null rate spikes → full snapshot fallback → item latency increase`
- Also: `scribe_read_proxy` P90 4 min slower for new model ID; Scuba (dpp_worker.scribe_example_age_ms) shows 0-7 min — discrepancy unexplained.
- Dave Kotfis: "Lets open a SEV." Josef Cohen investigating today.
- Owner of investigation: Dave Kotfis (dkotfis), Josef Cohen (jcohen1)

**MVAI OT agent canonical invocation** — Pushpak Raj Gautam asked; answer is now documented in this space:
- Claude skill: `/mvai:mvai-ot investigate <model_id_or_job>`
- Confirmed works in Claude (not RankPilot). Paul Lu has the setup post.
- Bot should route MVAI OT triage requests directly to this skill, not manual triage.

---

## P1 — significant nuance / sub-mechanisms

**Item null rate as new failure mechanism** (new, distinct from sparse failure):
- Dave Kotfis: "I don't think we've seen null rates be an issue with item before, only sparse."
- Josef Cohen confirmed: null rate spiked on Reels SS Omni after a recent launch (model ID mismatch suspected).
- Mechanism chain: `model launch → high snapshot age P90 → null rate spike → fallback to full snapshot → item latency increase`.
- This is NOT a sparse delta failure — it's an item snapshot freshness failure. Different detector, different SLO path.

**Scribe metric split: `scribe_read_proxy` vs `dpp_worker.scribe_example_age_ms`**:
- The two metrics can disagree significantly (7.5-11 min vs 0-7 min for same window).
- Dave: "Maybe coming from differences between scribe_read_proxy and dpp_worker.scribe_example_age_ms."
- Bot should not treat these as interchangeable when diagnosing scribe lag. Recommend checking both.
- Relevant Scuba dashboard: https://fburl.com/canvas/xilhg2vt (Dave's scribe P90 view)

**Flight recorder serial execution as shutdown-delay root cause**:
- When a trainer job hangs on shutdown, the delay is partly caused by flight recorder running serially.
- This adds latency to the shutdown sequence → MAST kill signal delayed → measured downtime inflated.
- Not a MAST bug per se — this is OT-side behavior that makes MAST's recovery look slower than it is.

---

## P2 — references / good-to-know

- ODS monitoring dashboard for ig_reels_starsearch_t2i_retrieval (SS T2I) e2e latency: https://fburl.com/monitoring/k4sskbba
- Reels SS Omni item latency spike canvas: https://fburl.com/canvas/5sciimer
- Scuba sigrid_predictor view: https://fburl.com/scuba/sigrid_predictor/wgrfh9bl
- Scribe P90 scuba view: https://fburl.com/canvas/xilhg2vt
- OT reliability cross-team doc (MAST+DPP+TMS+Publisher+SJD): https://docs.google.com/document/d/1mpy7J9r-GCkUTNjQzzdWsJDWbFC9iJ3ctZsFdvyX-qs/edit?tab=t.0

---

## Cross-references

None from this space this week (no CL-NNN / P-NN references).

---

## Open coordination threads

- **Reels SS Omni item latency SEV (in progress today)**: Dave Kotfis + Josef Cohen. Open coordination — Josef investigating scribe_read_proxy vs dpp_worker discrepancy. SEV may be opened today. Bot should watch S-number.
- **MAST reliability deep-dive** (T273128182): Reaching out to MAST POC for fixing plan with committed timeline. Bot should track whether MAST responds to the dependent-SLA ask.
- **DPP reliability deep-dive** (T273130561): Same — DPP POC contact in progress.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Add cross-team reliability doc URL to canonical sources | Add to `failure-patterns.md` + context header | 15 min |
| P0 | MAST retry-no-eviction = distinct failure subclass | `failure-patterns.md` new entry | 20 min |
| P0 | Item null-rate failure chain = new mechanism (not sparse) | `failure-patterns.md` + triage-routing note | 20 min |
| P1 | scribe_read_proxy vs dpp_worker.scribe_example_age_ms divergence note | Add to scribe-lag triage notes | 10 min |
| P1 | Flight recorder serial = shutdown delay contributor | Add to "job shutdown slow" pattern | 10 min |
| P2 | MVAI OT skill invocation: `/mvai:mvai-ot investigate` | Already in routing note; confirm canonical | 5 min |
