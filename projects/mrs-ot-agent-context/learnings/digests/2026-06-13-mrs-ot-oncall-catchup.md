# 2026-06-13 — MRS Online Training Oncall catch-up (gchat `spaces/AAQATpEgSyk`)

_Auto-distilled by `ot-ingest-gchat` cron. Source: 82 human messages spanning 2026-06-09T10:19 → 2026-06-12T14:33 in **MRS Online Training Oncall** (18 members; primary contributors: Li Lu ×27, Denny Zhang ×25, Anthony Foiani ×18)._

_Window: 7d. first-run: false._

## P0 — bot-integration-blocking items

- **Alert misconfiguration confirmed: 2141728947 vs 2141728943.** Alert https://fburl.com/monitoring/gnstlkk3 fires against root model id 2141728947, but should use ST model id 2141728943. Li Lu confirmed as false alarm 2026-06-10; D108089755 updates model registry. Bot: when this alert fires, check whether model id in alert is root-vs-ST mismatch before escalating.

- **Invalid detector** at https://fburl.com/monitoring/x33ohqs7 — Li Lu flagged for OT-bot fix 2026-06-10. Bot should auto-detect and file fix task (aligns with alert-misconfig-autofix pattern in memory).

- **D108195174 landed (2026-06-10)**: [mvai-ot] Add DPP-starvation confirm/refute + preemption discriminator. Bot now has DPP-starvation detection. Triggered by: OT agent failed to detect DPP starvation in today's SEV1 (2026-06-10). Root cause confirmed: scribe drain → DPP starvation. Li Lu: also add root cause example (scribe drain) to agent's known examples.

- **Owner routing update: OT SLICK** — Clement Chang is new POC for OT SLICK. Anthony Foiani is backup. Previously unclear ownership. Bot: route SLICK data/backfill questions to Clement Chang.

- **MRS has no Marketplace OT models** — confirmed by Paul Lu on 2026-06-12. If a SEV touches MARKETPLACE tenant, MRS OT is not involved. Safe to close/skip without investigation.

## P1 — significant nuance / sub-mechanisms

- **SLICK backfill failure modes** — from Clement Chang 2026-06-12:
  1. New missing data: daily SLICK runs hit OOM in Velox queries (per-query memory limit). SLICK team providing levers.
  2. Older data: some original sources have retention limits → historical backfill impossible.
  3. SLICK is NOT model-id/model-type aware — backfill can accidentally populate wrong baseline data for periods before the model launched.
  Bot: SLICK gaps are NOT necessarily OT failures. When SLICK shows red historical data, check: (a) was data ever available, (b) is SLICK backfill currently broken.

- **OT recovery latency** — H2 project proposal from Denny/Li Lu: measure recovery latency with breakdown, identify bottleneck, tune. Li highlighted in her talk. This is a named H2 initiative. Bot: when classifying OT incidents, note time-to-recovery; this feeds the H2 project.

- **S675246, S674219** — SEV1+ incidents 2026-06-12 affecting MRS OT jobs. Li Lu / Paul Lu driving. MRS→Video→Feed recovery sequence: Paul drove unblocking chain at ~14:00 PT 2026-06-12. S675246 is a tracking SEV for FB-wide impact from S675130 (SEV0).

- **Dependent SLA routing table** — Denny shared at https://fburl.com/collab-files/90kcp6mg for team review. This is the OT bot's planned external-escalation routing guide for cross-component OT failures (DPP, Scribe, etc.). Li Lu reviewing.

- **H2 model inventory initiative** — team consensus: need a dash/query listing all OT jobs by PG/model type + owner/oncall. Data accuracy issues: (a) committed models only known at PG launch or in SEVs; (b) alerts missing/outdated per model; (c) model registry may not reliably have OT data. Anthony: Model Registry (MR) could serve this if MR had reliable OT data. Action owner unclear; Li Lu flagged as H2 goal.

- **DPP starvation metric gap** — confirmed: need more DPP metrics beyond starvation for bot to distinguish DPP failure subtypes. Li Lu: need SLA conversations with DPP team. No additional metrics identified yet; follow-up conversation pending.

## P2 — references / good-to-know

- SLICK dashboard: https://fburl.com/monitoring/kd4z0nog
- Alert (misconfigured): https://fburl.com/monitoring/gnstlkk3
- Invalid detector: https://fburl.com/monitoring/x33ohqs7
- Dependent SLA routing table: https://fburl.com/collab-files/90kcp6mg
- Oncall cost note: Anthony Foiani / Rehman Khan (feed_ranking_infra) planning Workplace post: 1 week oncall = 2 weeks productivity loss. Watch mrs.ot group for this post.

## Cross-references

- **D108195174** confirms that bot's DPP-starvation cluster was a REAL gap (missed in live SEV). Pattern upgraded from hypothesis to confirmed real OT failure path.

## Open coordination threads

- **DPP SLA conversation** — Li Lu flagged need for SLA/metrics conversation with DPP team. No meeting scheduled in this window.
- **Model registry OT data** — Anthony Foiani: MR could serve the OT inventory if data is reliable. No owner/timeline for fixing MR OT data yet.
- **SLICK backfill fix** — Clement Chang + SLICK team working on Velox memory levers. No ETA.
- **Oncall cost post** — Rehman Khan planning to post. Keep an eye on mrs.ot Workplace group.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | 2141728947 vs 2141728943 mismatch = root-vs-ST alert misconfiguration pattern | known-patterns.md: alert-root-vs-ST mismatch entry | 30m |
| P0 | Auto-detect invalid detector at x33ohqs7 + file fix task | ot-alert-monitor: add to detector-audit list | 20m |
| P0 | Route SLICK questions to Clement Chang (primary), Anthony Foiani (backup) | SKILL.md owner-routing table | 10m |
| P0 | Marketplace tenant → no MRS OT involvement | SKILL.md: add MRS OT product scope note | 10m |
| P1 | SLICK gaps ≠ OT failures: explain backfill failure modes | known-patterns.md: SLICK-gap entry | 30m |
| P1 | Track time-to-recovery per incident (feeds H2 project) | ot-triage-summary: add recovery_latency_minutes field | 30m |
| P1 | DPP sub-metrics needed; SLA conversation with DPP pending | triage-discipline.md: DPP open gaps section | 20m |
