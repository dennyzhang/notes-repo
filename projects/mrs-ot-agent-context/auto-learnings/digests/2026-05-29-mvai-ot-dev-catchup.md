# 2026-05-29 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 55 human messages spanning 2026-05-26T14:40 → 2026-05-28T17:05 in **MVAI OT Dev** (8 members; primary contributors: Denny Zhang ×20, Anthony Foiani ×18, Paul Lu ×9, Shengpei Zhang ×2)._

_Window: 7d (2026-05-22 → today). Standard run._

---

## P0 — bot-integration-blocking items

**New owner routing: Shengpei Zhang (shengpei) = POC for Publisher + SJD**:
- Denny explicitly tagged Shengpei Zhang as "POC of pusher and SJD" and requested review of the reliability doc.
- Shengpei confirmed reviewing and gave SJD feedback (details in P1 below).
- Bot should route Publisher + SJD deep-dive questions to shengpei, not to the generic oncall.

**OT model metadata project started** — Denny committed to leading this foundational work:
- Source of truth: MAST job app metadata (`mvai_trainer_config` paste in MAST run config — derivable, confirmed by Paul Lu).
- Design decision: launcher translates "obscure MAST command line args" → `snapshot_type → expected_interval_minutes` mapping; monitoring framework scrapes Scuba hourly/daily to update Monitoring Registry (MR).
- SLI design decision: shift from "X missed updates per Y minutes" → "age of X" (snapshot freshness). Confirmed by Denny + Foiani.
- Per-model-ID expected intervals: FS every 1h (most models), 4h (heavy models); SD every 10m.
- Current approximation: MGS (Model Generation Staleness). Q2 latency breakdown metric deferred due to resource reduction.
- ELASTIC ↔ DENSE_DELTA mapping still unresolved (Foiani flagged explicitly: "how does ELASTIC map to DENSE DELTA????").
- Open design question: guardrails for MLE misconfiguration → deferred to launcher, not monitoring stack.

**D106406191 landed**: Drop DENSE_DELTA SLI for i2i model 2132070936 (no elastic publish). Bot was previously tracking this as a SLICK issue — it's now closed/resolved via SLI removal.

**D106566401 landed**: Fix max-retries for OT — removes infinite retries support (-1), simplifies code. No longer supports `max_app_retries = -1`. Accepted by Li Lu.

---

## P1 — significant nuance / sub-mechanisms

**SJD capabilities update from Shengpei Zhang (domain expert)**:
- "SJD blind when trainer process dies" → confirmed real issue.
- "SJD cannot detect publish-path hangs" → Shengpei says "counter-intuitive" — needs sample job verification before bot can claim this.
- "SJD not universally enabled across OT fleet" → Shengpei needs data source link to confirm. Bot should NOT cite this without linking to data.
- Action: Denny to add doc comments; detailed discussion to happen in the cross-team doc.

**SLICK dashboard empty model (mgS blank)** — Anthony Foiani debugging, blocked:
- Model blank in SLICK: https://fburl.com/monitoring/7wroob1t. Publishing is blank → MGS blank.
- There is a "model type mismatch" in the query source returning data.
- Foiani attempted backfill; query timed out at 9 weeks, trying 2 weeks.
- Foiani blocked by feed ranking infra explosion (3h sleep 2026-05-28) — will look at by 2026-05-29 (Friday).
- This is top-2 open SLICK gap per Denny.

**fire command dry-run bug fixed (D106588525)**:
- `--dry-run` flag was being ignored in the `fire` command for TMS operations.
- Paul discovered during S668272 testing. Fix landed (Gufan Yin final review).
- Bot's `fire` invocations should be verified to pass `--dry-run` correctly.

---

## P2 — references / good-to-know

- SLICK gap model dashboard: https://fburl.com/monitoring/7wroob1t (blank MGS - top-2 gap)
- Cross-team SEV study doc (same as rtinfra-ws2): https://docs.google.com/document/d/1mpy7J9r-GCkUTNjQzzdWsJDWbFC9iJ3ctZsFdvyX-qs/edit?tab=t.0

---

## Cross-references

- D106406191 resolves the i2i model 2132070936 DENSE_DELTA SLI (bot previously tracked this model for publishing alerts).
- D106566401 changes max-retries semantics — bot's fire-command invocations and retry expectations should align.

---

## Open coordination threads

- **OT model metadata foundational work**: Denny committed to "take a stab on this". No timeline set. Key open issue: ELASTIC ↔ DENSE_DELTA mapping. Anthony and Denny need to align on TrainingRunConfig shape.
- **SLICK empty-model debugging**: Anthony Foiani → unresolved. Expected response by 2026-05-29 (today). Bot should check if this closed.
- **Shengpei SJD review**: Shengpei gave initial read; Denny asked for detailed doc comments. Whether "SJD not universally enabled" is confirmed awaits data-source linkage.
- **MGS → latency breakdown metric migration**: deferred from Q2, no rescheduled date. Current state: MGS only.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Route Publisher+SJD deep-dives to shengpei | Update owner routing table | 5 min |
| P0 | SJD capability nuances (confirmed/unconfirmed) — update triage notes | `failure-patterns.md` SJD section | 15 min |
| P0 | D106566401: max-retries -1 no longer supported → update fire-command guidance | OT triage prompt fire section | 10 min |
| P1 | OT model metadata initiative: SLI = snapshot age, FS/SD expected intervals | Add as project context to team-bot CLAUDE.md | 15 min |
| P1 | ELASTIC ↔ DENSE_DELTA mapping = open gap (do not assume equivalence) | Add caveat to bot's publishing-type classification | 10 min |
| P2 | D106588525: dry-run fix — verify bot's fire invocations pass flag correctly | Spot-check cron prompts with `fire --dry-run` | 5 min |
