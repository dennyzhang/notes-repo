# Failure Patterns — Recurring Issues in MRS Online Training

> 📍 **This file is the legacy CL-NNN cluster registry** (sorted by recent impact — the TL/manager view). For graph-style triage traversal (S → M → R → P → D), start at **[`patterns/INDEX.md`](INDEX.md)**. CL-NNN clusters are cross-referenced from individual M-NNN / R-NNN entries in this directory.

**Last reviewed:** 2026-05-18 (ot-bot, thread `BzwgIQr_f48` — consolidation pass) · **Review cadence:** weekly on Sundays · **Auto-update:** by `ot-knowledge-curation` cron nightly @ 23:00 PT · **Audience:** tech leads, managers, and engineers who want a fast picture of where MRS online training (OT) is hurting.

---

## 30-second summary

The MRS OT bot watches incoming alerts, SEVs, and FB posts about online-training breakage. After consolidation 2026-05-18 (threads `BzwgIQr_f48` + `4u3oOvwSD30`), the register is:

- **9 active patterns** — where the gap is real, MRS-OT-owned, and the next step is named
- **4 watch-list patterns** — single-instance or quiescent; revisit only on recurrence
- **4 routed-success patterns** — bot triages correctly, source unchanged but no longer counted as "active"
- **2 out-of-scope patterns** — model-side or release-pipeline-owned; OT bot detects and routes only

### SEV volume snapshot (post-refined-rule archives)

| Month | Archived OT SEVs | MoM change |
|---|---:|---|
| Jan 2026 | 2 | (baseline) |
| Feb 2026 | 8 | +300% |
| Mar 2026 | 15 | +88% |
| Apr 2026 | 8 | −47% |
| **May 2026 (partial, 17/31 days)** | **23** | **+188% partial → ~+425% if Apr-rate holds** |
| **Currently In-Progress** | **10** | — |
| **Total Jan–May (5 months)** | **56** | — |
| **Total Mar–May (3 months)** | **46** | — |

**⚠️ Caveat on May spike:** Bot's full-coverage monitoring started 2026-05-15 (3 weeks before the cutoff). Pre-May archives are partial backfill coverage; the May +188% MoM is **largely a coverage artifact, not a real failure-rate surge.** Real apples-to-apples MoM measurement starts Jun 2026 when all months have full bot-fired coverage. For trend reasoning today: use **Feb–Apr trend (+300% then +88% then −47%)** as the cleaner baseline; treat May as a coverage-uplift outlier.

**Top 4 things to read:** CL-013 (training example-age, top MRS-OT-owned symptom), CL-001 (snapshot-stuck, top alert volume despite routing), CL-014 (NCCL timeout, masks behind other clusters), CL-003 (downstream-infra reliability — DPP/ZippyDB/Scribe cascades, multi-PG simultaneous).

**Note on CL-017 (Shampoo NaN):** moved to out-of-scope 2026-05-18 (thread `4u3oOvwSD30`) — NaN in optimizer state is a **model-side** failure (optimizer config, gradient stability, feature pipeline). OT bot detects and routes to model owner via R21 family-sibling check; the fix belongs to model team, not MRS infra. Same FYI-tracking treatment as CL-004 (cogwheel, NOT-OT-owned).

### 🎉 Highlight — MRS delivered IG 10-min ATS for all launched models

**MRS managed to deliver IG 10-min ATS (Available Training Signal latency) for all launched models** — excluding dependency issues and QE issues which are out of MRS control. This **exceeds the previous assessment** posted at <https://fb.workplace.com/groups/1676744619923718/posts/1972811233650387>.

Why this belongs at the top of a failure-pattern register: it calibrates the "where we're hurting" story. The patterns below catalog the **residual** failure modes — dependency cascades (CL-003), QE/cogwheel noise (CL-004, NOT-OT-owned), and the rare in-MRS failures (CL-001, CL-013, CL-017). The SLA itself is being met for the launched-model fleet; this file documents the tail, not the median.

### 3-month SEV volume by cluster (Feb–May 2026, archived OT SEVs only)

Derived from `incidents/resolved-sevs/<YYYY-MM>/` archives (post-refined-rule). Pre-bot-launch (before 2026-05-15) coverage is partial — cluster mappings for older archives were assigned via title-keyword heuristics during the 2026-05-18 backfill (thread `7wZB1nUQH8Y`). The `(unmapped)` row is mostly Jan–Mar backfill archives where bot triage context was absent at write-time; consolidated CL-NNN remap pass is pending.

**Sort order: importance-weighted, matching the scannable index above.** Within each rank tier, ordered by total 3-month volume. **Out-of-scope rows (CL-017 Shampoo NaN, CL-004 cogwheel) pushed to the bottom of the table** — these are model-side / release-pipeline failures, not MRS-OT failure patterns. Backfill (unmapped) row at very end (administrative).

| Rank | Cluster | Feb | Mar | Apr | May (partial) | 3mo total (Mar–May) | 4wk trend |
|---:|---|---:|---:|---:|---:|---:|---|
| 1 | CL-013 training example-age | 0 | 2 | 1 | 1 | 4 | flat |
| 2 | CL-001 snapshot-stuck | 0 | 0 | 0 | 2 | 2 | rising |
| 3 | CL-014 NCCL timeout | 1 | 0 | 0 | 0 | 0 (masked in others) | hidden |
| 4 | CL-003 downstream-infra reliability (DPP/ZippyDB/Scribe) | 0 | 0 | 0 | 1 | 1 (+ ongoing) | sustained |
| 5 | CL-015 + CL-016 QPS dip/slow | 0 | 0 | 1 | 1 | 2 | flat |
| 7 | CL-009 OT auto-start stall | 0 | 0 | 1 | 1 | 2 | flat |
| 8 | CL-010 migration churn | 0 | 0 | 1 | 1 | 2 (sparse-archived; ~13/4wk title-counted) | sparse-archived |
| | **— MRS-OT-owned subtotal** | **1** | **2** | **3** | **5** | **11** | |
| out-of-scope | CL-004 cogwheel (Not OT-owned) | 0 | 2 | 1 | 4 | 7 | FYI — trunk health workstream |
| out-of-scope | CL-017 Shampoo NaN (Not OT-owned, model-side) | 1 | 0 | 0 | 1 | 1 (+2 alerts) | ACCELERATING — model owners' problem |
| backfill | (unmapped backfills) | 6 | 11 | 3 | 7 | 21 | mostly Jan–Mar |
| backfill | (unmapped backfills) | 6 | 11 | 3 | 7 | 21 | mostly Jan–Mar |
| | **Total archived** | **8** | **15** | **8** | **23** | **46** | rising in May (coverage uplift; see caveat above) |
| | Currently In-Progress (any cluster) | — | — | — | — | **10** | — |

_Caveat 1: archived counts undercount real volume — only ~1/3 of candidate SEVs survived the refined OT-scope rule (see `auto-learnings/deep-dives/ot-sev-scope-rejections.md`). For volume trends use this table; for cluster-rank gap reasoning use the scannable index below._

_Caveat 2: ranks 1–5 here mirror the scannable index. Rank 6 (CL-012) and rank 9 (CL-018) are omitted from this table because the former is a sub-class catalog (not SEV-volume-counted) and the latter is an alert-not-SEV pattern (no archived SEV rows). See scannable index for full rank list._

### Status legend

| Status | Meaning |
|---|---|
| 🔴 **chronic / accelerating** | Top-priority leadership or platform-team ask |
| 🟡 **active, eng-tractable** | Bot-prompt edit / runbook / cron in scope; ship in <1 week |
| 🔵 **routed** | Bot triages correctly; source pattern unchanged but routing reduces operator cost |
| ⚪ **watch** | Single-instance or quiescent; archive if no recurrence by W21+ |
| ⛔ **not-OT-owned** | Detected + routed by bot; fix ownership lives outside MRS-OT |
| 🟢 **mitigated** | Source pattern stopped recurring. **High bar.** Currently **0** |

### Master pattern table — all clusters, sorted by recent impact

_Single table replaces the prior scannable + watch + routed-success + out-of-scope split (4 tables → 1; thread `4u3oOvwSD30` 2026-05-18). Sort weight = `(May incidents × 3) + (3mo volume) + (gap letter L=3 M=2 S=1)`. Not-OT-owned rows sink to bottom._

_**2026-05-20 migration note** (Proposal G in `../solution-design.md`): each cluster now has a **Type** column indicating which layer of the S/M/R/D ontology it lives in: **S**ymptom, **M**echanism, **R**oot cause, **D**efense gap. See `patterns/` for the relational entity files (`patterns/symptoms.md`, `patterns/failure-modes.md`, `patterns/root-causes.md`, `patterns/mitigations.md`, `patterns/edges.md`). This dashboard remains the operator-facing impact-sorted UI; the patterns/ files are the canonical knowledge graph._

| Rank | ID | Pattern | Type | Status | 4wk | 3mo | Gap |
|---:|---|---|---|---|---:|---:|---|
| 1 | [CL-013](#cl-013--training-example-age-spike) | Training example-age spike | **S** (=S-001) | 🔴 chronic | 4 | 4 | **L** — top OT symptom; no dashboard |
| 2 | [CL-001](#cl-001--snapshot-stuck-creating-heterogeneous-symptom) | Snapshot-stuck-CREATING | **S** (=S-002) | 🔵 routed (R17) | 13+ | 2 | **L** — routed; 3+ root mechanisms unfixed |
| 3 | [CL-014](#cl-014--training-timeout-nccl--watchdog--raas) | Training timeout (NCCL/watchdog/RaaS) | **M** (=M-005 + M-009 sub-cluster) | 🔴 chronic | 3 | 0* | **L** — masks behind other clusters |
| 4 | [CL-003](#cl-003--downstream-infra-reliability-dpp--zippydb--scribe) | Downstream-infra reliability (DPP/ZippyDB/Scribe) | **M** (=M-007) | 🔵 routed (i-0a) | 5+ | 1+ | **L** — ~1 cascade/wk; multi-PG |
| 5 | [CL-015+CL-016](#cl-015--cl-016--training-qps-dip-and-slow-rampup-merged) | Training QPS dip + slow ramp-up | **S** (=S-003 + S-004) | 🔴 active | 3-4 | 2 | **M-L** — OT/PG joint-debug |
| 6 | [CL-012](#cl-012--stuckjobdetector-coverage-gaps) | StuckJobDetector coverage gaps | **D-gap** (M-001 lacks defense) | 🔴 platform | 3-4 | 1 | **M** — ~512 GPU-hr/mo waste |
| 7 | [CL-009](#cl-009--ot-auto-start-silent-stall-100-threads--cross-pg-after-w1215-evidence) | OT auto-start silent stall | **M** (=M-004) | 🟡 D1-eligible | 3 | 2 | **M** — silent quality drift |
| 8 | [CL-010](#cl-010--migration-churn-baseline-noise) | Migration churn (baseline noise) | **M** (metric-inflation class) | 🟡 metric-def | ~13 | 2 | **M** — inflates health metric ~30% |
| 9 | [CL-018](#cl-018--alert-noise-agg--dead-detector--test-rules) | Alert noise (AGG/dead-detector/TEST rules) | **M** (=M-016 + M-017) | 🔵 routed (R22) | 4+ | n/a | **S** — source noise unchanged |
| 10 | [CL-007](#cl-007--cross-org-leaks-via-tag-broadness) | Cross-org leaks via tag broadness | **D-gap** (routing layer) | 🔵 routed (R18) | 0 in scope | ~5/mo at source | **M** — 0 leaks post-R18; sibling-org tagging unchanged |
| 11 | [CL-008](#cl-008--stus-jobs-mis-classified-as-trainer-jobs) | STUS jobs mis-classified as trainer jobs | **M** (=M-014) | 🔵 routed (R14+R23) | 1 new sub-class | ongoing at source | **M** — 0 trainer-mis-class post-R14; naming-collision source unchanged |
| 12 | [CL-002](#cl-002--mitigation-over-reset-causes-secondary-regression-watch) | Mitigation over-reset → secondary regression | **M** (operator-action class) | ⚪ watch | 2 | 2 | **S** — archive at W22 if N≤2 |
| 13 | [CL-005](#cl-005--delta-publishing-exposes-uncharted-failure-modes-watch) | Delta publishing onboarding footguns | **M** (onboarding class) | ⚪ watch | 2 | 2 | **S** — fold into runbook + archive at W22 |
| 14 | [CL-006](#cl-006--mast-schedulingcapacity-as-silent-root-watch--possibly-quiescent) | MAST scheduling/capacity as silent root | **M** (=M-010) | ⚪ watch | 0 (was 5+ in W18) | 0 | **M** (quiescent) — archive at W22 if no recurrence |
| 15 | [CL-011](#cl-011--linux-signal-handling-with-unexpected-job-kill-watch) | Linux signal handling → unexpected job kill | **M** (signal-handling class) | ⚪ watch | 0 | 0 | **XS** — archive at W21 |
| — | [CL-017](#cl-017--optimizer-state-corruption-shampoo-nan--second-moment-matrix) | Shampoo NaN / optimizer state corruption | **R** (=R-010 + R-011) | ⛔ not-OT-owned | 3 | 1 (+2 alerts) | model-side; routed via R21 to model owners |
| — | [CL-004](#cl-004--cogwheel-publish-failures-not-ot-owned) | Cogwheel publish failures | **M** (=M-009) | ⛔ not-OT-owned | ~8 | 7 | trunk-health workstream owns |

_\* CL-014 3mo=0 reflects archived SEVs only; timeout typically filed against parent symptom cluster (CL-001/CL-013) so standalone count understates real volume._

### Top-5 action items (full backlog at file end)

| # | Cluster | Action | Owner | Status |
|---:|---|---|---|---|
| 1 | CL-013 | Dedicated training example-age dashboard + per-incident root taxonomy + `ot-age-spike-monitor` cron | shuminwu (dashboard) + dennyzhang (cron) | not started |
| 2 | CL-014 | Timeout-aware bot rule (~20 line cron edit) + `ot-timeout-monitor` cron candidate | dennyzhang | not started |
| 3 | CL-012 | Land D104947534 (SJD publisher-shutdown fix) + propose rank-error+alive-process SJD rule | ezrak + hkwok | in flight |
| 4 | CL-009 | New `ot-autostart-liveness` cron (~1 week agent work) + brief to renqincai (Threads) | dennyzhang | not started |
| 5 | CL-003 | Downstream-infra SLA conversation with ZippyDB/Scribe/DPP leads + OT-side graceful-degradation design | shuminwu (cross-team) | not started |

See `## Backlog action items` at file end for items B1–B10.

**Removed from top-5 list 2026-05-18 (thread `4u3oOvwSD30`):** CL-017 (Shampoo NaN) action item — moved to out-of-scope. Bot R21 family-sibling escalation is **still useful** and should ship, but tracked as a routing improvement (analogous to R22 for CL-018) not an MRS-OT-owned action. See CL-017 detail section.

See `## Backlog action items` at file end for the remaining ~10 items (CL-002 / CL-005 / CL-010 / CL-015 / CL-016 / CL-018 / CL-006 / CL-011 / CL-001 / CL-004). Those are lower-priority and shouldn't be on the dashboard.

---

## Glossary (trimmed — only non-obvious terms)

- **MRS** — Modern Recommendation Systems
- **OT** — Online Training. Models that update continuously from fresh data
- **QE model** — *Quality Experiment* / launch-candidate model. Runs in parallel with a **prod baseline** trainer; carries new model-code changes (config, feature config, architecture, hyperparameters) on top of the same base version. When a QE OT job fails, the **infra-vs-model disambiguation** is the first triage step: if prod baseline is healthy and QE is failing → model-side root (route to model owner); if both fail → infra-side root (route to MRS-OT). Codified in `ot-alert-monitor.md` step i-a.4 and `ot-sev-monitor.md` step i-pre.b.
- **Prod baseline (model)** — the production-tier trainer running the released base version *without* QE-specific code changes. Acts as the control arm for the QE-vs-infra disambiguation above. Pull liveness via `mvai_metrics` and MAST state; if healthy while QE fails, root is model-side.
- **Recurring training job** — a separate flow that exercises the same MVAI code path independently of an individual OT job. When available (often not), it's the secondary check for *generic-MVAI* vs *OT-specific* root cause: if a sibling recurring flow is also failing → MVAI platform issue, escalate to MVAI oncall not OT. Most QE models do NOT have a sibling recurring job; absence is normal, not a red flag.
- **PG (Product Group)** — Which product owns the model: IG, Threads, Video, Facebook, Ads. **PG is upstream of OT** — model owners generate events that OT consumes
- **MVAI** — Meta's ML platform layer that schedules and manages OT jobs
- **MAST** — Meta's batch scheduler. MVAI submits OT jobs onto MAST
- **STUS** — SilverTorch Update Service. Publishes trained-model deltas to serving. Shares naming with trainers (see CL-008)
- **SJD (StuckJobDetector)** — Platform mechanism that kills wedged jobs. CL-012 covers its blind spots
- **Cogwheel / fbpkg / light_cli** — Build-and-publish toolchain that gates new model versions reaching production
- **NCCL** — NVIDIA GPU collective comm library. Source of many training-timeout SEVs (CL-014)
- **Watchdog** — The thread that detects collective hangs and terminates the job
- **RaaS** — Recommendation-as-a-Service. Downstream consumer of OT (CL-014 includes RaaS timeout spikes)
- **FBLearner** — Meta's ML workflow orchestrator. Wraps MAST submissions in "recurring flows"
- **Downstream-infra** (vs upstream-PG) — ZippyDB, Scribe, LogDevice, **DPP (Data Processing Pipeline)**. From OT's perspective these are storage/data tiers OT calls into (CL-003 covers all four)
- **R-rule (R14, R17, R18, i-0a …)** — Detection rule codified in the OT bot's cron prompts
- **P-row (P44, P50, P52, P59 …)** — Operator-facing triage step in the bot's playbook
- **D1-eligible** — Cluster has ≥3 instances + no mitigation → bot's nightly `ot-knowledge-curation` cron auto-drafts a P-row
- **🟢 mitigated vs 🔵 routed** — Operator calibration (2026-05-16): "mitigated" = source pattern stopped recurring; "routed" = bot triages correctly but source unchanged

---

## How a "pattern" gets registered

1. OT bot triages alerts/SEVs/posts every few minutes
2. When the same failure shape appears across multiple distinct incidents over multiple weeks, the bot writes a weekly summary entry
3. When weekly summaries cluster around a single underlying mechanism, the operator registers a stable Cluster ID here

This file is the **register of named patterns** — not a list of incidents. Individual incidents live in `../digests/2026-W{NN}.md`.

---

## The active patterns (sorted by recent impact, biggest first)

Each entry: **Status** · **Headline + Why it matters** (single combined field) · **Detail** · **Count** · **PG** · **What we've done** · **Gap** (if routed) · **What's needed** · **Evidence** · **Observed**

Watch-list patterns (CL-002, CL-005, CL-006, CL-011) are collapsed into a single section at the end. Routed-success patterns (CL-007, CL-008) follow the active section. CL-004 (out-of-scope) sits at the very end with FYI-only status.

_Section order is maintained for historical anchors; for current priority order, see the Scannable Index above. CL-017 sits below CL-018 in this file by historical accident — it ranks #1 by impact._

---

### CL-013 · Training example-age spike

- **Status:** 🔴 CHRONIC (11-month corpus). Top OT issue
- **Naming note:** Was "training-age / example-age spike" prior to 2026-05-18 (thread `4u3oOvwSD30`). Operator simplified: there is one metric — training **example age** (lag between when an event was generated and when the trainer consumes it). "Training-age" was a synonym, not a second metric. Now uniformly "training example-age."
- **Headline:** Most-recurring user-visible OT failure. 13 SEVs over 11 months, 4 in last 6 weeks. No dedicated dashboard, no single owner, no codified rule
- **What's broken:** Training example-age (lag between events generated and consumed by trainer) spikes from minutes to hours. ~11 distinct sub-mechanisms: (1) upstream data starvation (TIXU/EDPP cascade, scribe overload); (2) scheduler-blocked resize (S635390 koski EDPP block); (3) peak-traffic capacity shortfall (Reels ESR); (4) post-rebase regression (S579685 IG U2I); (5) model-memory pressure forcing config trade-offs hurting QPS (S653266 IFR Main MTML MC12); (6) holdout-model age (S554026, S656875); (7) cross-rank NCCL hangs (overlap with CL-012 and CL-014); (8) DPP 20-day session restart — Zeus TTL expiry forces session kill every ~20 days, ~280 fleet-wide dips/half, self-recovers in ~3-10 min (S667544, D106193584, P2349022281); (9) app-layer version drift dropping scribe holdout delay — stale app layer missing critical fix causes `scribe_reader_catchup_sec=0` (W1218910203488316); (10) upstream serving-tier data poisoning — data IS flowing but corrupted, e.g. Shots QE combinatorial explosion poisoning 61 models (S659243); (11) DPP oscillation — DPP itself oscillates rather than being blocked by external scheduler (S664296, P51/P30 adjacent)
- **Why it matters:** Training example-age is the **direct proxy for OT freshness** — the thing OT exists to deliver. When it spikes, model quality degrades immediately. With 4 in last 6 weeks, cadence has accelerated. Multiple SEV2s in history
- **Count:** Last 4wk = 4 · All-time = 13
- **Who's affected:** Instagram 9 of 13 (4 are Threads), Production (IFR/CFR) 3, AI Infra 1
- **What we've done:** Nothing cluster-level. Per-incident mitigations heterogeneous (HBM table moves, flag changes, scribe scale-ups, EDPP unblocks)
- **What's needed (leadership ask #1):**
  1. Dedicated dashboard: training example-age per OT-model with breach-vs-SLA alerting
  2. Per-incident root taxonomy: map future age-spikes to one of the ~7 sub-mechanism classes
  3. `ot-age-spike-monitor` cron: 1-2 weeks agent work
  - Owner: `shuminwu` → OT workstream lead
- **Evidence (last 4 weeks):** S659917 (2026-05-06 IG, Feed LSR, In Progress), S659474 (2026-05-05 IG, Threads M2M reranker), S656875 (2026-04-29 IG, mixed_feed holdout), S635390 (2026-03-17 IG, Threads U2M EDPP block), **W1218910203488316** (2026-05-09–11 IG, model 2147007224 OT example age step-change at v51→v52 upgrade with `scribe_reader_catchup_sec=0` regression; missing D102533010 latency_injection_ms fix in app layer; CL-013 confirmed via auto-mapping 2026-05-16 21:38 PT), **A1480195820275950** (2026-05-16 IG, model 2144816217 ig_reels_tab_ss_omni_retrieval holdout OT e2e latency sparse delta, 2h self-resolution, P04-candidate per operator triage 2026-05-16 22:16 PT)
- **Evidence (older):** S621928, S620107 (Reels ESR Feb 2026), S614927, S614849 (IFR + AI Infra Jan 2026), S579685 (Oct 2025), S568890 (Sep 2025), S554026 (Aug 2025), S542768 (Jul 2025), S526721 (Jun 2025)
- **Observed:** [W17](../digests/2026-W17.md) → [W20](../digests/2026-W20.md), plus 9 older SEVs to 2025-06
- **Cross-references:** Overlaps mechanism-wise with CL-003 (downstream-infra reliability), CL-014 (training timeout), and CL-015 (sudden QPS dip). CL-013 is the **user-visible symptom layer**

---

### CL-014 · Training timeout (NCCL / watchdog / RaaS)

- **Status:** 🔴 CHRONIC. Operator-flagged 2026-05-16 as a big missing gap
- **Headline:** 2nd-most-recurring OT failure after training example-age. 9+ SEVs over 11 months, 3 in last 4 weeks. No codified bot rule, no systemic fix in flight
- **What's broken:** During training, GPU collective ops (NCCL ALLTOALL_BASE, AllReduce) or downstream calls (RaaS) exceed configured timeouts → (a) watchdog SIGKILLs the job, (b) one rank hangs while others wait, or (c) cascade into RaaS-side spikes. Sub-mechanisms: (1) cross-rank NCCL deadlock with no rank-error visible (overlaps CL-012 #1); (2) `wait_for_publish_completion` blocking call starving watchdog refresh (D104947534 partial fix); (3) RaaS-side timeout spikes when a model's training delivery slows (S661851); (4) NCCL config drift on new hardware (S664099 Blackwell test); (5) IFR/CFR MTML watchdog timeout on cogwheel test (S664499); (6) `_preload_item_pool()` startup deadlock → DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE → GetDataTimeoutError, N=2 cross-family (W1324864999608243, W1324729222955154, proposed P59); (7) elastic agent exit-code propagation failure — non-daemon C++ threads keep Python alive after ChildFailedError, SJD-invisible 6-28h hang, fix D98638473 (S628346, W1326387856122624); (8) metrics all_reduce collective desync before checkpoint save — D104469704 asymmetric all_reduce desyncs ranks → DCP gather_object timeout (S663211); (9) ZCH delta-update publishing NCCL hang (P19 variant) — all ranks blocked on default_pg at ZCH sharding handshake, fleet-wide (W1319390770155666); (10) Python GIL contention — heavy Python callbacks hold GIL while CUDA/DPP wait, triggers NCCL/Gloo timeout as secondary symptom (cross-ref CL-001 P44)
- **Why it matters:** Each timeout costs N GPUs for the timeout window (~30 min before watchdog SIGKILL). Visible SEVs alone: ~72 GPU-hours/year × likely 5-10× hidden-multiplier behind other clusters. **More importantly:** training-timeout is a near-universal sub-mechanism for "job stuck" / "training stopped" parent SEVs — the real impact is masked behind other clusters
- **Count:** Last 4wk = 3 · All-time = 9+
- **Who's affected:** Production 5, Instagram 3, AI Infra 1 — cross-PG
- **What we've done:** R17 catches symptoms (decreased mvai_metrics ticks). D104947534 partial fix for sub-mech #2 (pending land, `ezrak`). No cluster-level bot rule
- **What's needed (leadership ask #2):**
  1. Cross-team coordination with PyTorch DistBE on systemic timeout-tuning (defaults right for B200/Blackwell? watchdog-refresh starvation generalizable beyond publish?)
  2. `ot-timeout-monitor` cron candidate: track watchdog-timeout cadence per model — early-warning before SEV
  3. Tactical (not leadership): timeout-aware bot rule, ~20 line cron edit. Owner: dennyzhang
  - Owner of leadership ask: `shuminwu` → OT workstream lead + PyTorch DistBE
- **Evidence (last 4 weeks):** S664499 (2026-05-15 Production, IFR MTML cogwheel watchdog), S664099 (2026-05-15 Production, NCCL ALLTOALL_BASE on Blackwell, also in CL-012), S661851 (2026-05-12 Production, Engagement MTML RaaS spike)
- **Evidence (older):** S644354 (Mar 2026 Feed ESR NCCL), S614849 (Jan 2026 QPS dip + age), S612181 (Dec 2025 auth → stuck), S564578, S519966, S632893, S533413, **W1319390770155666** (2026-05-06 fleet-wide VDD HSTU NCCL hang on all 8 trainer ranks default_pg at ZCH sharding handshake for delta-update publishing → DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE; 3+ prod/QE HSTU/VDD models affected simultaneously; P19 ZCH delta-update variant; alert gap: 6hr threshold meant no pager fired despite >1h degradation; added 2026-05-16 21:38 PT)
- **Observed:** [W20](../digests/2026-W20.md), plus 6+ older
- **Cross-references:** Overlaps with CL-012 (SJD gap sub-mech #1) and CL-013 (timeout often manifests as age spike). CL-014 is the **timeout-mechanism layer**
- **Added 2026-05-16** per operator thread `ZP2y-6Bdpwk`

---

### CL-001 · Snapshot-stuck-CREATING (heterogeneous symptom)

- **Status:** 🔵 routed by R17 since 2026-05-13. **Gap is BIG** — operator-flagged 2026-05-16
- **Headline:** R17 routes correctly (30s answer to "is the trainer alive?"), but the underlying 3+ root mechanisms continue to recur unchanged
- **What's broken:** Snapshot freezes in "CREATING" state. At least 3 distinct root causes (GIL-hang, snapshot transition race, delta-publisher TCPStore binding, etc.)
- **Why it matters:** Pre-R17 saved ~6.5 oncall hours/month of misdirected triage. **But** the patterns themselves keep happening: 13+ instances in last 4 weeks. Each still requires hands-on remediation per the actual root. R17 made triage faster; did NOT reduce failure count
- **Count (4 weeks):** 13+
- **Who's affected:** IG×7, Facebook×1, Threads×1 (rest pre-PG-tracking)
- **What we've done:** R17 (mandatory trainer-liveness probe). P44 (GIL-hang sub-case)
- **Gap (routed, not mitigated):** Each of 3+ root mechanisms needs its own platform/trainer-side fix. None has been driven to completion. Cadence ~3-4/week unchanged
- **What's needed:** Per-root sub-cluster work — for each of ~3 dominant sub-mechanisms, identify root-cause owner. Status upgrade to 🟢 only when count drops below ~1/week sustained 4 weeks. Owner: dennyzhang (sub-cluster discovery); per-root fix owners TBD
- **Evidence:** S652049, S657690, S658369, S657071, S658165, S661523, S661783, S661157, S661045, W1320805680014175, W1324729222955154, **A898952803114953 + A4366891846955592** (2026-05-16 Facebook, model 878858380 facebook_cfr_main_mtml holdout+baseline FULL_SNAPSHOT missing, paired same-model simultaneous firing strongly suggests shared root — P38 Boxcar planned maintenance OR P17 fbpkg expiry; both ~6h15m+6h30m self-resolved; operator triage 2026-05-16 22:16 PT)
- **Observed:** [W18](../digests/2026-W18.md) → [W20](../digests/2026-W20.md)

---

### CL-003 · Downstream-infra reliability (DPP / ZippyDB / Scribe)

- **Status:** 🔵 routed by i-0a since 2026-05-06. **Gap is BIG** — same routed-not-mitigated pattern as CL-001
- **Renamed 2026-05-18 (thread `4u3oOvwSD30`):** was "Downstream-infra cascade (ZippyDB / Scribe)". Uplevel to **"reliability"** framing and add **DPP** to the explicit bucket. DPP (Data Processing Pipeline) is the third pillar of downstream infrastructure OT depends on, alongside ZippyDB and Scribe; previously DPP-stall cascades (e.g., DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE) were filed against CL-014 (timeout symptom) when they're actually downstream-infra root causes. This rename makes CL-003 the **canonical "downstream-infra reliability"** umbrella, sibling to upstream-PG and trainer-internal categories.
- **Headline:** Bot correctly attributes cascades (~3 oncall hours/month saved), but **downstream-infra outages keep cascading into OT unchanged.** ~1 cascade/week
- **Naming correction (2026-05-16):** Previously labeled "upstream-infra cascade." From OT's perspective, **PG is upstream** and **storage/data tiers (ZippyDB, Scribe, LogDevice) are downstream infrastructure** OT calls into
- **What's broken:** Downstream-infra SEVs (ZippyDB SEV1, Scribe overload, LogDevice issues) starve OT of training data. OT oncalls used to chase trainer-side hypotheses; real issue is one layer down
- **Why it matters:** Pre-i-0a saved ~3 oncall hours/month of mis-triage. **But** cascades themselves continue at ~1/week. Each affects multiple OT models simultaneously. Cross-team friction reduced; cascades aren't prevented
- **Count (4 weeks):** 5+
- **Who's affected:** Multiple PGs simultaneously (cascade nature)
- **What we've done:** Rule i-0a + P50 — bot checks for downstream-infra SEVs first
- **Gap (routed, not mitigated):** Downstream-infra services don't have OT-specific SLAs. When they SEV, OT is collateral damage with no graceful degradation. No backpressure / read-replica failover in flight at storage tier
- **What's needed:** Downstream-infra SLA conversation with ZippyDB/Scribe leads; OT-side graceful degradation. Status upgrade to 🟢 only when cascade rate drops <0.25/week sustained
- **Evidence:** S660220 (ZippyDB SEV1), **S660017** (ZippyDB L1 root, tagged 2026-05-16), S660501, S660546, S660706, S660484, S665114, S635390, **S665163** (2026-05-17 00:15 PT ZippyDB RE-session throttling, In Progress as of 07:05 PT — cascaded to A2387001468469120 IG 878102693 scribe lag at 02:08 PT, bot i-0a triage thread `M-YVGFcrK2g` confirmed correlation)
- **Observed:** [W18](../digests/2026-W18.md) → [W20](../digests/2026-W20.md)

---

### CL-015 + CL-016 · Training QPS dip and slow ramp-up (MERGED 2026-05-18)

- **Status:** 🔴 active — merged 2026-05-18 (thread `BzwgIQr_f48`). Previously CL-015 (sudden mid-training drop) and CL-016 (slow ramp-up) tracked separately; consolidated because both have the same downstream impact (model-quality risk from low QPS), share the joint-debug-with-PG triage pattern, and split into two clusters was inflating the active-pattern count without operational benefit. Sub-mechanism distinction preserved within this section.

- **Headline:** Model's training QPS is wrong — either drops suddenly mid-training ("15a") or fails to ramp up after launch / chronically slow ("15b"). Both = stale model = direct quality risk. The joint-debug pattern (infra-side vs PG/model-side root) is the gap and is best addressed once for both sub-classes.

- **Sub-classes:**
  - **15a: sudden mid-training drop.** QPS plunges within minutes. Roots: serving errors that cascade into training-publish path (S660507, S659671), error-rate spike (S662535), collective hang manifesting as QPS=0 (S644248), upstream data dip (S614849), launch-candidate transition publishes (S663027), explore-traffic falling (S661045), STUS GMPP publisher vulnerability during downstream-infra SEV — GMPP path depends on Scribe/ZippyDB while in-trainer MVAI models unaffected, 0 QPS for ~7h (W1324845696276840), stale app layer causing holdout QPS anomaly — missing critical fix changes QPS characteristics on job restart (W1218910203488316).
  - **15b: slow ramp-up / chronically slow.** QPS doesn't reach steady-state. Roots can be infra-side (capacity, NIC/data colocation, MAST quota) or PG/model-side (batch size, feature config, model architecture). S662798 (Feed LSR MB8) is the canonical instance.

- **Why it matters:** Both = direct model-quality risk. 15a is acute (minutes to detect), 15b is chronic (can persist weeks before noticed). **The joint-debug pattern itself is the gap** — no agreed protocol on who triages first, leads to OT/PG ping-pong. Joint-debug protocol benefits both sub-classes equally; that's why merging is right.

- **Count (4 weeks):** 3-4 combined (15a: 2 SEVs S663027, S661045; 15b: 1-2 SEVs S662798). 3mo archives: 2 (S644248 Apr 15a, S663027 May 15a)
- **All-time:** 9 (15a: 7 SEVs; 15b: 2 SEVs)
- **Who's affected:** Instagram dominates (Reels, mixed_feed, Explore, Threads, Feed LSR); Production also (IFR, CFR)
- **What we've done:** Nothing codified at either sub-class level. Each instance triaged ad-hoc.
- **What's needed (leadership ask):**
  1. **Joint-debug protocol** between OT workstream and PG model-owner leads. Agreed first-pass triage steps + ownership rubric ("is this an infra-side root or model-side root?") + escalation path. Benefits 15a and 15b equally.
  2. **Tactical bot rule** (~20 line cron edit): detect SEV titles matching `QPS.*drop|qps falling|QPS dip|slow QPS|QPS ramp` → auto-apply sub-class taxonomy (15a vs 15b). Owner: dennyzhang.
  3. **Per-incident decision tree** codified — could become a bot rule once protocol exists.
  - Owner of leadership ask: `shuminwu` → OT workstream lead + PG model-owner leads
- **Evidence (last 4 weeks):**
  - 15a: S663027 (2026-05-14 IG ig_feedrec_esr_ttsn launch candidate), S661045 (2026-05-09 IG Explore ig_explore_chaining_mtml qps falling, In Progress)
  - 15b: S662798 (2026-05-13 IG Feed LSR MB8 slow training QPS ramp up)
- **Evidence (older):** S662535, S660507, S659671 (Production tier-1 high-QPS error rate), S644248 (IG Reels Omni QPS to 0, 3mo archive), S614849 (Jan 2026 QPS dips + age)
- **Observed:** [W20](../digests/2026-W20.md), plus older
- **Cross-references:** Overlaps with CL-013 (slow QPS → age spike) and CL-014 (collective hangs cause both). Distinct from CL-013 by mechanism (QPS is throughput, age is freshness; can occur independently).
- **Merge note 2026-05-18 (thread `BzwgIQr_f48`):** preserve sub-class IDs (15a, 15b) inside this section for evidence-linking; CL-015 and CL-016 are now both aliases for this merged cluster. The joint-debug protocol is the single shared next action.

---

---

### CL-012 · StuckJobDetector coverage gaps

- **Status:** 🔴 D1-eligible. 4 sub-classes catalogued. 1 of 4 has a partial fix in flight (D104947534, `ezrak`)
- **Headline:** SJD silently lets wedged OT jobs hold GPUs indefinitely. Bot can detect, only platform can kill
- **What's broken:** SJD doesn't trigger on certain wedge modes. Bot's R17 catches symptoms but can't kill — only platform SJD can. Sub-classes: (1) cross-rank NCCL collective deadlock (S664099); (2) publisher-shutdown cleanup hang (D104947534 partial fix); (3) non-publisher cleanup hang (C++ destructors / NCCL finalize / fd close); (4) in-training publish wait (suspected from D104947534 review); (5) elastic agent ChildFailedError → non-daemon C++ thread hang — Python `threading._shutdown()` blocks on stuck NCCL/DPP/publisher threads after worker failure, MAST never detects failure, 6-28h idle, fix D98638473 (S628346, W1326387856122624); (6) SIGABRT handler hang on rank 0 — torch elastic watchdog resets SIGABRT handler, SIGALRM invokes hung C-level handler preventing cleanup, workaround D96542699 JK rule (S628346)
- **Why it matters:** Each wedged job holds N GPUs for hours-to-days. ~512 GPU-hours/month wasted (1 wedge/week × 8h × 16 GPUs) + model quality drift
- **Count (4 weeks):** 3-4 sub-mechanism classes
- **Who's affected:** infra-cross-pg×1
- **What we've done:** Bot R17 catches symptoms. D104947534 covers sub-class #2 only
- **What's needed (tactical, not leadership):**
  1. `hkwok` (MVAI AI Infra Release oncall): Add "rank-error + alive-process" SJD rule (covers #1 and #3)
  2. `ezrak` (our team): Land D104947534 (covers #2), consider threading `_shutdown_watchdog` through non-shutdown publish-wait sites (covers #4)
  3. dennyzhang: Maintain SJD coverage catalog
- **Catalog:** [`sjd-coverage-map.md`](sjd-coverage-map.md). Source: [`2026-05-16-sjd-coverage-gaps.md`](../../human-input-domain/2026-05-16-sjd-coverage-gaps.md)
- **Evidence:** S664099, mrs.ot post 1326387856122624, D104947534
- **Observed:** [W20](../digests/2026-W20.md)

---

### CL-009 · OT auto-start silent stall (100% Threads → cross-PG after W1215 evidence)

- **Status:** 🟡 novel, **N=3, D1-eligible restored** after W1215710353808301 (2026-05-07 IG Reels LSR) added to evidence 2026-05-16 21:38 PT. Tactical (not leadership) — cron design is ~1 week of agent work
- **Headline:** OT jobs stop launching / stop producing OT-diff with no failure event. Discovered only when downstream notices QPS drop or missing diff
- **What's broken:** OT job stops producing valid output with no MAST failure event. Roots: (a) MVAI manual expiration silently passed; (b) FBLearner recurring flow `is_enabled=false` OR `skip_recurring=True` early-return (P36); (c) parent FBLearner workflow stopped → child MAST job killed by `QuickAppOrphanJobCleanerObserver`
- **Why it matters:** Silent stalls are the worst kind of failure. Time-to-detect = "until downstream notices" = days in 2 of 3 known cases. ~4.5 model-days/month of silent quality drift across Threads + IG Reels
- **Count (4 weeks):** 3 (Threads×2 + IG Reels×1)
- **Who's affected:** Threads (2 instances) + IG Reels (1 instance, W1215). No longer 100% Threads after W1215 evidence — broader OT pattern
- **What we've done:** Nothing codified at cron-rule level. P36 exists in `known-patterns.md` for the `skip_recurring=True` sub-class but is not auto-applied by triage crons
- **What's needed (tactical, not leadership):** New `ot-autostart-liveness` cron. Probe models with `intent==active`; alert if `(now - last_mast_attempt_start) > 2× expected_launch_interval` OR `(online_train_publish step SUCCEEDED) AND (no TLS config diff in last interval)`. ~1 week agent work. Owner: dennyzhang. Threads brief to `renqincai`; IG Reels LSR brief separately if W1215 owner Jakub Bester confirms
- **Evidence:** S664106 (2026-05-14 MVAI-expired sub-class, model 2128461099), Renqin Cai mrs.ot post 1326836659411077 (2026-05-16 recurring-flow-disabled sub-class, model 2124118880), **W1215710353808301** (2026-05-07 IG Reels LSR online_train_publish silent-success via `skip_recurring=True` early return, cites S656611, P36-confirmed)
- **Reattribution note (2026-05-16 21:05 PT):** S665135 was previously cited as the 3rd instance but actual postmortem revealed Shampoo NaN root — reassigned to [CL-017](#cl-017--optimizer-state-corruption-shampoo-nan--second-moment-matrix). The W1215 archive (added 21:38 PT from ot-daily-learning-mitigated-posts) is the verified 3rd instance, restoring D1-eligibility
- **Observed:** [W17](../digests/2026-W17.md) (W1215 backdated to 2026-05-07) → [W20](../digests/2026-W20.md)

---

### CL-010 · Migration churn (baseline noise)

- **Status:** 🟡 baseline, needs metric-definition fix
- **Headline:** ~3-4 planned-work SEVs/week pollute the OT-health metric by ~30%; need `MIGRATION_CHURN` exclusion class
- **What's broken:** Preemptive SEVs for tenant migrations, MVAI+MTIA model swaps, and platform transitions get counted in OT-health metrics. NOT operational failures — planned work
- **Why it matters:** ~13 SEVs/4wk = ~30-40% of OT SEV count. Health metric is inflated by planned work by ~30%. Leaders looking at the metric think OT is failing more than it actually is, distorting staffing decisions
- **Count (4 weeks):** ~13 (stable ~3-4/week)
- **Who's affected:** IG×7, Threads×1, unknown×1
- **What's needed:** Add `class=MIGRATION_CHURN` to verdict-header enum. Subtract from "non-migration SEV count". ~10 lines per cron prompt. Owner: dennyzhang
- **Evidence:** W17: S651844, S654080, S652695, S654102. W18: S655459, S655630, S658691. W19: S660706, S659604, S658691. W20: 1-2
- **Observed:** [W17](../digests/2026-W17.md) → [W20](../digests/2026-W20.md)

---

### CL-006 · (moved to Watch list — see below)

---

### CL-011 · (moved to Watch list — see below)

---

## Watch list (single-instance or quiescent — archive if no recurrence by W21/W22)

---

### CL-002 · Mitigation over-reset causes secondary regression (WATCH)

- **Status:** ⚪ watch (N=2). Below ≥3 threshold. Archive at W22 if no recurrence.
- **Headline:** "Standard" mitigations (clear info.json, kill+re-enable) reset more job state than operators realize; a second regression follows
- **Count (4wk):** 2 (both FB posts)
- **What's needed:** Pre-mitigation checklist in bot's triage output: enumerate what state will be lost. ~1 hour cron edit. Owner: dennyzhang.
- **Evidence:** W1324729222955154, W1320816783346398
- **Observed:** [W20](../digests/2026-W20.md)

---

### CL-005 · Delta publishing exposes uncharted failure modes (WATCH)

- **Status:** ⚪ watch (N=2). Below ≥3 threshold. If N stays ≤2 through W22 → fold into OT-onboarding runbook and archive.
- **Headline:** Onboarding new models to delta publishing has hidden footguns; needs two runbook gates
- **Count (4wk):** 2
- **What's needed:** Two additions to OT onboarding runbook: (a) memory headroom check, (b) require FULL_SNAPSHOT before table-count change. Owner: `llu6` (current `mrs_online_training` oncall).
- **Evidence:** W1320070000087743, W1319356410159102
- **Observed:** [W20](../digests/2026-W20.md)

---

### CL-006 · MAST scheduling/capacity as silent root (WATCH — possibly quiescent)

- **Status:** ⚪ watch (N=5+ in W18, 0 recurrence in W19-W20). If W21+ recurrence → extend R-rule i-0a. Otherwise archive at W22.
- **Headline:** Cluster went quiet for 2 weeks; no longer D1-eligible
- **Count (4wk):** 0 (was 5+ in W18)
- **What's needed:** Wait. If 6th instance lands in W21+, extend R-rule i-0a to also check MAST oncall + scheduler state. Owner: dennyzhang.
- **Evidence:** S658149, S658035, S657920, S657606, S657977
- **Observed:** [W18](../digests/2026-W18.md) only

---

### CL-011 · Linux signal handling with unexpected job kill (WATCH)

_Renamed 2026-05-18 (thread `4u3oOvwSD30`): was "SIGUSR2 stray-signal kills MVAI job". Generalized to "Linux signal handling with unexpected job kill" so future instances involving SIGTERM/SIGHUP/SIGINT/etc. that get treated as fatal map to this cluster, not a new CL._

- **Status:** ⚪ watch (N=1). Archive past 2026-W21 if no recurrence.
- **Headline:** Single distinctive instance from W17
- **Count (4wk):** 0
- **What's needed:** Wait for a second instance. Archive past 2026-W21 if no recurrence. Owner: dennyzhang.
- **Evidence:** S654768
- **Observed:** [W17](../digests/2026-W17.md)

---

---

## Routed-success patterns (monitor only for regression)

### CL-007 · Cross-org leaks via tag broadness

- **Status:** 🔵 routed by R18 since 2026-05-13 (0 leaks in OT scope post-R18). Source unchanged
- **Headline:** R18 made the bot ignore out-of-scope SEVs. Sibling-org tagging breadth at source is unchanged
- **What's broken:** SEVs from sibling orgs (Everstore, Unidash, IG Vital Metrics, IG Direct DE) are tagged `mvai-online-training` because they affect OT among other consumers
- **Why it matters:** Pre-R18 saved ~12 oncall hours/month. Tagging pattern at source is unchanged
- **Count (4 weeks):** 5 pre-R18 in OT scope, 0 post-R18 in OT scope
- **Gap (routed, not mitigated):** Sibling-org tag-breadth unchanged. If sibling orgs improved tagging, R18 would be unnecessary
- **What's needed:** Monitor for R18 regression. Optional: surface tagging breadth issue to sibling-org leads
- **Evidence (pre-R18):** S656088 (Everstore), S655556 (Unidash), S661752, S659215 (IG Vital), S658534 (IG Direct DE)
- **Mitigation routing evidence:** W18=2, W19=3, W20=0 leaks into OT scope
- **Observed:** [W18](../digests/2026-W18.md) → [W19](../digests/2026-W19.md)

---

### CL-008 · STUS jobs mis-classified as trainer jobs

- **Status:** 🔵 routed by R14 since 2026-05-08 (0 mis-classifications post-R14) + **R23 added 2026-05-17 for FULL_SNAPSHOT-subtype false-PAGE class**. Source unchanged
- **Headline:** R14 distinguishes STUS vs trainer correctly. R23 (2026-05-17) catches a NEW sub-class where bot PAGEs STUS owner for `full_snapshot_publish_delay` even though FULL_SNAPSHOT is rare-by-design for STUS retrieval models. Source naming-collision + STUS-subtype-cadence unchanged
- **What's broken:** STUS publish jobs share naming pattern `mvai-training-online-<MODEL_ID>` with actual trainer jobs. Without entrypoint check (R14), bot applied trainer-side hypotheses (NCCL, OOM, step counter) which were FALSE for STUS jobs. **2026-05-17 NEW sub-class (m2130305043):** bot correctly classified as STUS but PAGEd owner for `full_snapshot_publish_delay` (4-day FULL_SNAPSHOT gap) without checking that OTHER snapshot subtypes (SPARSE_DELTA, ITEM_EMB_DELTA) were publishing healthily every 2 min. For STUS retrieval models, FULL_SNAPSHOT cadence may be intentionally rare/disabled — detector misconfig, not model failure
- **Count (4 weeks):** 5+ pre-R14 (trainer-hypothesis-on-STUS), 0 post-R14 trainer-mis-classification. **2026-05-17:** 1 FULL_SNAPSHOT-subtype false-PAGE (m2130305043 → caught by operator, R23 added)
- **Gap (routed, not mitigated):** STUS and trainer still share naming. Bot disambiguates; underlying naming-collision footgun remains for any future tool / manual operator. **2026-05-17 NEW gap:** OneDetection `full_snapshot_publish_delay` detector fires on STUS models even when STUS-class FULL_SNAPSHOT cadence is intentionally rare. Detector should be silenced for STUS models OR the bot must enforce R23 subtype-stratified freshness check before classifying as REAL_OT_FAILURE
- **What's needed:** Monitor for R14 + R23 regression. Optional: propose STUS adopt distinct naming prefix (requires STUS-team buy-in). **NEW:** file detector config bug with OneDetection to silence `full_snapshot_publish_delay` for STUS-class models, OR per-model threshold tuning
- **Evidence:** Documented in W19 corpus. **2026-05-17:** m2130305043 STUS false-PAGE caught by operator (thread `FoMEj5Ql-ME`), led to R23 codification in `ot-alert-monitor` (snapshot-subtype disambiguation: classify as THRESHOLD_MISFIT when FULL_SNAPSHOT stale but other subtypes fresh on STUS models)
- **Observed:** [W19](../digests/2026-W19.md) + **2026-05-17 R23 expansion**

---

### CL-011 · (see Watch list above)

---

### CL-017 · Optimizer state corruption (Shampoo NaN / second-moment matrix) **(Not OT-owned, model-side)**

- **Scope re-classification 2026-05-18 (thread `4u3oOvwSD30`):** Operator confirmed Shampoo NaN is a **model-side optimizer issue**, not an MRS-OT infra failure. Roots are gradient stability, hyperparameter choice, feature pipeline corruption, optimizer config — all owned by per-model teams (feed_ecosystem_core_modeling, igr_retrieval, igml/shots, etc.), not MRS infrastructure. Moved from active register rank 1 to Out-of-scope (alongside CL-004 cogwheel). MRS-OT bot continues to detect + route via R21 family-sibling check (that's a real bot-side capability worth preserving), but the SEV ownership, mitigation, and leadership-ask all live with model teams. **The pattern is real and accelerating; what changed is where it's tracked.**
- **Status:** 🔴 ACCELERATING (model-side problem, externally tracked) — was "ACTIVE + ACCELERATING" in active register prior to 2026-05-18. Today **2 simultaneous cascades on family `facebook_cfr_main_mtml`** (m878858380 + m2134801434) make this family-wide signal
- **Headline:** NaN in optimizer state (most commonly Shampoo's second-moment matrix) makes the model un-publishable; 7+ SEVs over 11 months. **2026-05-17 inflection: TWO sibling models in `facebook_cfr_main_mtml` family hit NaN within 4h (01:00 PT m2134801434, 05:28 PT m878858380)** — first family-wide simultaneous NaN observed; CL-017 escalates from M-L to L gap
- **What's broken:** During training, the optimizer's accumulated state (typically Shampoo's second-moment matrix) develops NaN values. Roots: (a) exploding gradients from bad data or hyperparameter mismatch, (b) corrupted upstream features, (c) accumulated numerical error in long-running training, (d) DPP package update that broke an optimizer code path. The model then either fails publish (`Silvertorch publish NaN failures`) or trains on poisoned state until detected. **Family-wide hypothesis (2026-05-17):** shared optimizer code path / shared upstream feature pipeline across `facebook_cfr_main_mtml` siblings can co-fail — R21 cross-workload check critical for this cluster
- **Why it matters:** Direct model-quality failure mode. Most cases mitigated by reverting to N-2 snapshot, but the underlying corruption can recur if root data/code issue isn't fixed. Some instances have caused SLI drops (S659167 Shots SLI to 84% + Threads FSR drop). **Family-wide co-failure (2026-05-17) means single-model mitigation is insufficient — if root is shared upstream, ALL siblings need the patch**
- **Count (4 weeks):** 3 (S665135 + A1703030847735006 + A25209897055308328) · All-time = 7 (S665135, S661922, S659167, S657711, S559940, A1703030847735006, A25209897055308328)
- **Who's affected:** Production 4 of 7, Instagram 2 of 7, Facebook (cfr_main_mtml family) 2 of 7 — cross-PG with **NEW family-wide pattern in Facebook CFR**
- **Sub-mechanisms:**
  1. Shampoo NaN in second-moment matrix (S665135, S659167)
  2. Silvertorch publish NaN cascading across multiple sourcing models (S661922)
  3. NaN/Inf during training that downstream publish surfaces (S657711)
  4. DPP-package-update-induced NaN regression (S559940)
  5. **Family-wide simultaneous NaN in same model_type_name (2026-05-17 NEW)** — A1703030847735006 + A25209897055308328 on facebook_cfr_main_mtml siblings; auto-recovered via v_{N+1} restart per P56 cascade pattern but co-occurrence strongly suggests shared upstream root
- **What we've done:** Bot now detects 2-sibling-same-symptom family-wide signal via R21 (cross-workload sibling check). Per-incident: revert to N-2 snapshot; some models have "optimizer patch for NaN resilience" (S665135 mentions prod PNUA model m2128701656 has this patch). P56 codified for NaN-cascade pattern (v_N tainted → v_{N+1} restart)
- **Gap:** Mitigations are per-incident snapshot reverts; no upstream fix for the gradient/data root causes. "Optimizer patch for NaN resilience" exists for some models but adoption isn't tracked. **2026-05-17 NEW gap:** family-wide simultaneous failures mean per-model patching may miss the root — need to track whether the shared upstream cause (feature pipeline? optimizer config?) is identifiable from the paired-incident postmortem
- **What's needed:**
  1. Tactical bot rule: detect SEV titles matching `NaN|exploding.gradient|optimizer.state|Shampoo|second.moment` → auto-tag CL-017 + recommend N-2 snapshot revert as first mitigation **AND check R21 family-sibling status**
  2. Adoption tracking for the optimizer-NaN-resilience patch across all OT models, **family-grouped**
  3. Upstream gradient-clipping or data-validation gates (longer-term)
  4. **NEW 2026-05-17:** when 2+ family siblings hit NaN within 24h, escalate to family-wide investigation; current per-incident mitigation hides the shared root
- **Evidence:** S665135 (2026-05-16 IG, TIFU ESR PNUA, NaN in Shampoo second moment, mitigated via revert to snapshot 2396 + ban), S661922 (Production, Silvertorch publish NaN cascade), S659167 (IG, Shots Optimizer QE Backtest → SLI drop), S657711 (IG, MB8 TL Publish NaN/Inf), S559940 (Production, CFR after DPP package update), **A1703030847735006** (2026-05-17 01:00 PT Facebook, m2134801434 facebook_cfr_test NaN loss+NE, v100 auto-restart, bot triage thread `ior-iAJW2ZY`), **A25209897055308328** (2026-05-17 05:28 PT Facebook, m878858380 facebook_cfr_hstu_online NaN loss+NE+calibration, v121 auto-restart, bot triage thread `vWq7RCBJlmA`, model now #1 chronic-noisy per noisy-trends.md § Alerts)
- **Observed:** [W20](../digests/2026-W20.md), plus 4 older + **2 new same-family 2026-05-17**
- **Cross-references:** Overlaps with CL-015 (NaN can cause sudden QPS dip via error rate spike) and CL-013 (long-running training accumulates numerical error → NaN). **2026-05-17:** facebook_cfr_main_mtml family-wide pattern overlaps with P56 (NaN-cascade) — R21 sibling check is the detection mechanism
- **Added 2026-05-16** per S665135 postmortem (thread `gMO2L7p9xaM`); **expanded 2026-05-17** per A1703 + A25209 simultaneous family-wide (threads `ior-iAJW2ZY` + `vWq7RCBJlmA`)

---

### CL-004 · Cogwheel publish failures **(Not OT-owned)**

- **Status:** 🔴 chronic but **NOT OT-owned**. Already aligned per operator 2026-05-16. FYI tracking only — excluded from leadership-ask count
- **Headline:** Pre-QE / pre-prod cogwheel & fbpkg failures are owned by **trunk health workstream**; OT provides on-demand support only. Real cadence ~2 SEVs/week
- **What's broken:** mvai / light_cli build-and-publish pipeline fails ~2/week (CUDA OOM, ImportError, TorchScript annotation, transitive C++ ABI breaks, TGIF timeouts, Sandcastle preemption)
- **Why it matters:** OT-attributable time = ~30 min/incident × ~26/qtr = ~13 OT engineer-hours/quarter. The rest is correctly attributed to trunk-health workstream
- **Count (4 weeks):** ~8 (~2/wk) by trunk-health scope; 26+ by OT bot's tag-broad view
- **Who's affected:** infra-cross-pg×22 (85%), IG×1, unknown×1
- **What we've done:** P52 (TorchScript class). R18 correctly identifies these as out-of-OT-scope when SEV is clearly trunk-stage
- **What's needed:** No leadership ask — already aligned. Bot-side: review R18 to determine if pre-QE cogwheel SEVs should be silently dropped from OT triage. Owner: dennyzhang
- **Evidence:** 26+ SEVs across W18-W20 (see commit `9b12727c7821` for full list)
- **Observed:** [W18](../digests/2026-W18.md) → [W20](../digests/2026-W20.md)

---

### CL-018 · Alert noise (AGG / dead-detector / TEST rules)

_Renamed 2026-05-18 (thread `4u3oOvwSD30`): was "AGG-rule blind spots (aggregation alerts — EXPANSION-DISCOVERED 2026-05-17)". Uplevel to "alert noise" framing because the underlying problem is broader than just AGG-expansion: [TEST] rules from despiker auto-inverse, [dead detector] orphan rules, and AGG bundles all produce noise that bot has to filter. R22 expands AGGs; the [TEST]/[dead-detector] filtering is part of the same pattern. Future detector-hygiene issues map here._

- **Status:** 🔵 routed by R22 since 2026-05-17 08:25 PT. **Source unchanged** — OneDetection AGG bundles continue, with [TEST]/[dead-detector] noise
- **Headline:** OneDetection AGG alerts ARE expandable via `meta monitoring.alert list --alert-contains <MODEL_ID>` (operator-discovered while A2130305043 was live, thread `suPsRC2fGdc` 08:23 PT). Previously thought blind — was actually a discoverability gap. R22 now expands AGG, filters [TEST]/[dead-detector] noise, inherits verdict from real sub-alerts
- **What's broken (corrected):** OneDetection AGG alerts bundle 4+ sub-alerts. ~50-75% are [TEST] (despiker auto-inverse) or [dead detector] noise. The 1-3 real signals are usually scribe-lag / null-score / mvai_metrics — each maps to an existing cluster. **The blind spot was that bot didn't expand them**, not that they were unparseable
- **Why it matters:** Pre-R22, AGG alerts went `verdict: NO_ACTION class: TRANSIENT_NOISE` because bot couldn't see the underlying signals. Real CL-003 / CL-013 / CL-017 cascades hidden inside AGGs were missed. Post-R22, AGG alerts inherit their real-sub-alert cluster classifications
- **Count (4 weeks):** 4+ AGG alerts caught. A2126294138 (27h unassigned), A2130305043 (14h then re-fired 07:20 PT today — this is the alert that prompted the discovery), A on 878102693 (03:12 PT — correctly debunked)
- **Who's affected:** IG primarily (mostly `ig_organic_feed_mtml` / `ig_feedrec_esr_ttsn` / `ig_reels_tab_cs_omni_retrieval`). Likely broader
- **What we've done:**
  - **R22 codified in `ot-alert-monitor.md`** (step i-c.2) since 2026-05-17 08:25 PT. Bot auto-expands AGG, filters noise, inherits verdict
  - TITLE_RULE `\[AGG\]|aggregation.*rule` in `mrs-ot-agent-src/tools/regen-archive-indexes.sh` maps AGG alerts to CL-AGG placeholder for INDEX visibility
- **Gap (routed, not mitigated):**
  - [TEST] and [dead-detector] sub-alerts at SOURCE continue to fire. R22 filters them in bot triage but they still hit OneDetection storage + AGG counter
  - Time-based escalation (>4h unassigned → ot-human-attention-brief 🔴 section) still pending separate work
  - **Source-side fix would be detector hygiene** (clean up despiker auto-inverse [TEST] rules; sweep [dead detector] orphans). Not in OT scope; cross-team to OneDetection ownership
- **What's needed:**
  1. Watch for R22 false-negative cases (filtered as noise when actually a real signal). Should be rare given `[TEST]`/`[dead detector]` are explicit prefixes
  2. Time-based escalation for unassigned AGGs >4h — add to `ot-human-attention-brief` step 2
  3. Optional: surface detector-hygiene observation to OneDetection team if [TEST] / [dead detector] noise rate doesn't drop in 30d
- **Breakthrough evidence (2026-05-17 08:23 PT):**
  - `meta monitoring.alert metadata --alert-id '<full_alert_id>'` returns rich metadata including `entity` field (NOT `grouped_time_series_entity` as claim was — actually meaningful, e.g. `scribe_read_proxy`)
  - `meta monitoring.alert list --alert-contains '<MODEL_ID>' --state-is=ACTIVE` returns ALL active alerts on the model. Filter `[TEST]` + `[dead detector]` → real sub-alerts remain (usually 1-3)
  - For A2130305043: 4 sub-alerts → 2 noise ([TEST] + [dead detector] absolute_source_rate) + 1 real scribe_read_proxy CL-003 (e2e latency sparse delta) + 1 real null score rate (model data issue)
- **Cross-references:** Sibling-pattern of CL-007 (sibling-org tag-broadness; both detection-layer noise). Triage now inherits verdicts from CL-001 (snapshot stuck), CL-003 (downstream-infra reliability), CL-013 (training example-age), CL-014 (NCCL timeout), CL-017 (NaN cascade, out-of-scope) depending on real sub-alert
- **Observed:** [W20](../digests/2026-W20.md)
- **Initially registered 2026-05-17 morning** (per LqKW1jLtNeM standing offer). **Reclassified 🔵 routed 2026-05-17 08:25 PT** after operator-driven live-alert probe in thread `suPsRC2fGdc` revealed expansion API works

---

## PG (Product Group) reference

When the bot reports a SEV, it attaches a `pg` field derived from SEV's `sev_type` ("Stack") + title regex. **PG is upstream of OT** — model owners generate events that OT consumes.

| PG | What gets counted | Approx % (last 4 weeks) |
|---|---|---:|
| IG | Instagram-side OT issues | ~48% |
| infra-cross-pg | mvai / cogwheel / light_cli — affects multiple PGs | ~45% |
| Threads | Threads ranking OT | ~10% |
| Facebook | Facebook Feed / CFR / IFR OT | ~3% |
| Video | Reels / Video VDD | ~3% |
| other | Storage / Data Warehouse / AI Infra (R18 drops) | ~3% |
| unknown | Production-typed SEVs not matching regex | ~3% |
| Ads | Ads team SEVs (R18 drops) | <1% |

For full derivation, see PG-derivation logic in the 3 monitor cron prompts (`ot-sev-monitor.md`, `ot-alert-monitor.md`, `ot-post-monitor.md`).

---

## How to maintain this file

- **Cite `[CL-NNN]`** in new weekly summary entries and thread summaries
- **When a new instance lands:** update Count, Evidence, Observed range. Re-derive PG-breakdown
- **D1-eligible flips when** count reaches ≥3 with no mitigation. Bot's nightly `ot-knowledge-curation` cron auto-drafts a P-row
- **🟢 mitigated requires** the source pattern to have stopped recurring (count drops below baseline sustained 4+ weeks). Bot-routing improvements ≠ 🟢 mitigated; those are 🔵 routed
- **Status flips to archived** if 4+ weeks elapse with no new instance
- **Never renumber.** Append new IDs (CL-017, CL-018 …) at the end
- **Sorted by gap size,** not by ID. Re-sort when gap sizes change
- **Update top tables** (status counts, scannable index, action items) whenever owners/status change
- **When studying mitigated SEVs, pay attention to QPS patterns** (CL-015 sudden dip vs CL-016 slow/ramp-up). These two clusters are operator-flagged 2026-05-16 as easy-to-miss; explicit attention required during weekly-summary extraction
- **Action items table:** consolidates all concrete next steps from per-cluster "What's needed" sections. Mark status as `done` when shipped, `in flight` when someone is actively working it

_File renamed 2026-05-16: was `CLUSTERS.md`, now `failure-patterns.md`. Cluster IDs (`CL-NNN`) are still the canonical identifier._

---

## Backlog action items (not on top-5 dashboard)

Lower-priority items rolled off the top-5 dashboard during the 2026-05-18 consolidation pass (thread `BzwgIQr_f48`). Promote back to top-5 if owner picks up + status flips to in-flight.

| # | Cluster | Action | Owner | Status | Notes |
|---:|---|---|---|---|---|
| B1 | CL-010 | Add `class=MIGRATION_CHURN` to verdict-header enum (~10 lines per cron) | dennyzhang | not started | Removes ~30% noise from health metric |
| B2 | CL-015+CL-016 (merged) | Bot rule: detect QPS-drop/slow-ramp titles → auto-apply sub-class taxonomy (~20 lines) | dennyzhang | not started | Joint-debug protocol = separate leadership ask |
| B3 | CL-002 | Pre-mitigation checklist in bot triage output (~1 hour cron edit) | dennyzhang | not started | N=2 watch; promote if N≥3 by W22 |
| B4 | CL-005 | OT onboarding runbook: memory headroom check + FS-before-table-count gate | llu6 | not started | N=2 watch; fold into runbook + archive if N stays ≤2 |
| B5 | CL-001 | Sub-cluster discovery: identify root-cause owners for ~3 dominant sub-mechanisms | dennyzhang | not started | Routing works; mechanism owners unidentified |
| B6 | CL-004 | Review R18 — should pre-QE cogwheel SEVs be silently dropped from OT triage? | dennyzhang | not started | NOT-OT-owned; bot scope question only |
| B7 | CL-015+CL-016 (joint-debug) | Joint-debug protocol between OT workstream and PG model-owner leads | shuminwu | not started | Leadership ask; cross-team agreement |
| B8 | CL-018 | Time-based escalation for unassigned AGGs >4h → add to `ot-human-attention-brief` | dennyzhang | not started | R22 already routes; escalation is secondary |
| B9 | CL-006 | If 6th instance lands in W21+, extend R-rule i-0a for MAST scheduler check | dennyzhang | watching | Watch only; quiescent W19-W20 |
| B10 | CL-011 | Archive past 2026-W21 if no recurrence | dennyzhang | watching | Watch only; N=1 |

---

## Consolidation history

- **2026-05-18 (thread `BzwgIQr_f48`)** — Operator feedback: "18 failure patterns: that's too many. needs to consolidate and uplevel, especially for the small ones. Key action items: needs to uplevel." Changes:
  - Added 3-month SEV volume table (Feb–May from archives)
  - Re-sorted scannable index by `(May incidents × 3) + (3-month volume) + (gap size)`; CL-017 moved to rank #1 reflecting family-wide acceleration
  - Merged CL-015 + CL-016 into single section (shared joint-debug pattern, same downstream impact)
  - Created **Watch list** for single-instance/quiescent clusters (CL-002, CL-005, CL-006, CL-011) — removed from active count
  - Created **Routed-success** section for CL-007 + CL-008 — no longer in active count
  - Cut action items 15 → top-5; rest moved to Backlog section
  - Headline count: "18 failure patterns" → "10 active + 4 watch + 4 routed-success"
- **2026-05-17 (thread `DEltCr_w2yA`)** — Weekly review; CL-017 expanded for family-wide co-failure
- **2026-05-16 (thread `ZP2y-6Bdpwk`)** — Added CL-013/CL-014/CL-015/CL-016 per operator missing-pattern flag
- **2026-05-16** — File renamed from CLUSTERS.md to failure-patterns.md
