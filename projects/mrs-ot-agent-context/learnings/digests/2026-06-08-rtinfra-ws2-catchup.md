# 2026-06-08 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 37 human messages spanning 2026-06-01T14:06 → 2026-06-08T08:10 PT in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Dave Kotfis 14, Pushpak Raj Gautam 13, Josef Cohen 6)._

_Window: 7d. Skip-until: not set (active polling)._

---

## P0 — bot-integration-blocking items

**1. Hardware validation pre-launch check is now landed (D106704835)**
Denny accepted D106704835 "Add hardware validation check for OT pre-launch checks" — a SEV follow-up. Bot should treat hardware type (A100 vs H100) as a pre-launch gate, not just a triage datapoint. Dave requested the stamp; this affects OT pre-launch checklist.

**2. A100→H100 switch causes GRADUAL scribe delay recovery (days, not immediate)**
Job `mvai-training-online-2124304578` switched from A100→H100 at v2→v3 on 2026-05-29, then pinned via D107567877. As of 2026-06-08, scribe delay is still stabilizing. Dave: "the improvement has been very gradual. And it hasn't yet bottomed out." Bot must not classify gradual delay recovery post-hardware-switch as a new failure — add "delayed H100 transition effect" as a recovery sub-class.

**3. `ig_textpost_feed_m2m_retrieval` = Threads model, NOT IG**
Pushpak confirmed: rule of thumb — `textpost` prefix in model name = Threads, despite the `ig_` namespace. Bot currently routes `ig_textpost*` to IG ownership — this is wrong. Owner: Threads team, no MRS-OT goals on this model.

---

## P1 — significant nuance / sub-mechanisms

**Hardware switch detection via MLHub UI**
Canonical method to check which hardware a MAST job ran on, and when it switched:
- MLHub → Pipelines → Runs → `<job_name>` → Execution Details tab → per-version host type + schedule time
- URL pattern: `https://www.internalfb.com/mlhub/pipelines/runs/mast/<job_name>?job_attempt=0&version=<N>&tab=execution_details&env=PRODUCTION`
- No scuba query for this yet (Josef Cohen asked, open).

**Scribe delay canonical metric = P90, not P50**
Team uses P90 on `dpp_worker.scribe_example_age_ms` in `dpp_stats_v2` Scuba as the primary staleness signal. P50 looks normal when P90 is spiking (seen in this week's discussion). When triaging example age issues, check P90 first.
- Scuba query (Reels ESR context): `https://fburl.com/scuba/dpp_stats_v2/k387vbo3`
- Example age P90+ canvas: `https://fburl.com/canvas/kyx5l0ir`
- Item model age P50 scuba: `https://fburl.com/scuba/sigrid_predictor/29s2obbr`

**Null item ages spike — unexplained, confirmed real**
Dave Kotfis 2026-06-03: "a spike in null item ages which we don't understand" — confirmed by Dave this is NOT a reporting artifact (Pushpak asked). Root cause unknown as of this week.

**Scribe item latency breakdown gap**
Josef Cohen is negotiating with the scribe team for finer breakdowns of item scribe latency. Scribe team has "not been super receptive." Using DFM dataset read/write expansion (Josef's proposal) as a forcing function. This gap means current scribe-side latency views (`fburl.com/canvas/9tedibry`) show aggregate, not component breakdown.

**Active SEVs with hardware/latency angle**
- S668980: Reels ESR sparse latency — being addressed in new MB (MB6.5 launched Friday 2026-06-06; sparse latency "looking good" as of 2026-06-08)
- S659917: Feed LSR — also addressed in new MB
- S656663: CS Omni sparse latency — Dave expected close 2026-06-06; verify if actually closed
- S670393: Filed via detector 1441772260965558 (item snapshot regression, NOT a reporting issue per Dave)

---

## P2 — references / good-to-know

**Varys model reliability dashboard** (Pushpak shared 2026-06-04):
`https://mrs-data-apps.internalmeta.com/core-modeling/model-reliability/varys?qe=fm_mc2_ifu_backtest_v3&range=7d`
Team uses this for model reliability tracking; bot currently doesn't cite it.

**DFM dataset doc** (Josef Cohen, 2026-06-03):
"DFM Data: Overview & Realtime Infra Integration"
`https://docs.google.com/document/d/1MQi8ReKOPtbEkN9CHVGxVpSr8GnAj7AcTYxNraecc7I/edit?usp=sharing`
DFM = the item-scribe dataset. Josef expanding DFM read/write surface for latency observability.

**CS Omni WP post** (referenced by Pushpak):
Dave's WP post covers CS omni sparse latency context: `https://fb.workplace.com/groups/1676744619923718/permalink/2057653955166114/`

---

## Cross-references

None of the messages explicitly cited bot cluster labels (CL-NNN or P-NN). Denny shared a bot triage output (6 IG models with high example age) directly into this space — team responded confirming 2 of the 4 model types (Reels ESR, Feed LSR) are being addressed in the new MB; `ig_textpost` = Threads (not in scope).

---

## Open coordination threads

1. **Hardware scuba query** (Josef Cohen asked 2026-06-08, no answer in window): team wants a scuba view overlaying H100 shift timing with measured latency for a given model type. No canonical query exists yet.
2. **CS Omni sparse (S656663)** — expected close 2026-06-06. Verify actual closure.
3. **Scribe item latency breakdown** — Josef Cohen negotiating with scribe team, stalled. Track this as ongoing.
4. **Null item ages spike** — open root cause investigation, no resolution in window.

---

## Integration priority table

| Priority | Item | Where to integrate | Time est |
|---|---|---|---|
| P0 | `ig_textpost*` = Threads, not IG — fix ownership routing in bot | `known-patterns.md` + `triage_config.yaml` model-type routing | 15 min |
| P0 | "Delayed H100 transition effect" as recovery sub-class for scribe delay | `known-patterns.md` § scribe-delay causes | 10 min |
| P0 | Hardware validation now a pre-launch gate (D106704835) | `SKILL.md` pre-launch checklist section | 10 min |
| P1 | Add P90 `dpp_worker.scribe_example_age_ms` as primary scribe metric (not P50) | `SKILL.md` § example-age triage | 10 min |
| P1 | MLHub UI execution details as canonical hardware-check method | `SKILL.md` § hardware triage | 5 min |
| P2 | Varys reliability dashboard URL | `references/` or `known-dashboards.md` | 5 min |
| P2 | DFM dataset doc URL | `references/` | 5 min |
