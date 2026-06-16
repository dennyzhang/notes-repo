# Dependency-SLA Matrix — "Which upstream owns this OT outage?"

When OT QPS / freshness drops, the agent's job is NOT to diagnose the upstream's
internals — it is to **quickly decide which dependency is responsible and hand
that oncall strong, per-job evidence.** (Li Lu, S674219: "if we can quickly give
DPP oncall strong evidence, we're good; what introduces the regression, rely on
the owning team.")

Taxonomy + owners mirror the canonical cross-team doc **[MRS OT Reliability —
Cross-Team Follow-ups]** (gdoc `1mpy7J9r-GCkUTNjQzzdWsJDWbFC9iJ3ctZsFdvyX-qs`;
mirrored at `references/gdocs/mrs-ot-reliability-cross-team-followups.md`).

Each section lists **concrete upstream issues seen** (anchored to a P-row / SEV /
follow-up task) and the **metric that confirms each** (source + reading). Per-job
(per mast job id) signals beat fleet aggregates — they ARE the evidence.
`[GAP]` = metric/dashboard we still need (see § Metric gaps).

Rule: on a synchronized multi-job drop, check the **data-side rows (DPP, Scribe,
Hedwig) first** — a shared upstream is the most common synchronizer (S674219).

Each section cites its **leading indicator** — the DP-NNN temporal pattern in
[detection-patterns.md](detection-patterns.md) that catches the issue BEFORE full
outage. Use this file to ROUTE + gather evidence; use detection-patterns.md to
DETECT early. (DP→dependency map: DP-001→SJD, DP-002/003/008→DPP, DP-004→Publisher/
Storage, DP-006→Control Plane, DP-007→Hedwig/Publisher, DP-008→DPP/Scribe.)

## Quick routing table (oncalls are real rotations)

| Dependency | First-look signal (source) | Oncall (rotation) | POC |
|---|---|---|---|
| **DPP** (data reading) | DPP starvation ODS `canvas/pzoyunzx`; `dpp_stats_v2` ingress; `dpp_worker_service_snapshot` | `dpp_distributed_data_reading` | Prasoon Telang · Nasrin Jaleel · Youmei Zhang |
| **Scribe** (data source) | `dpp_stats_v2` token ingress per category/region; KM-U1 Scribe QPS | category-owning team (+ Zeus for TTL) | — |
| **Hedwig** (delta streaming) | streaming success / in-order delivery; publisher queue; flow-control | `home_ml_platform` *(TBD)* | Qiuyu Xiao · jcohen1 (SLO dashboard) |
| **Publisher** (TGIF/GMPP/UMM/Manifold) | KM-P2 streaming success; KM-P4 publisher activity; snapshot CREATING stuck | *(TGIF/UMM POC TBD)* | Shengpei Zhang |
| **SJD** (stuck-job detect + kill) | mvai_metrics liveness vs MAST RUNNING; lease renewal | MVAI platform | Shengpei Zhang · ezrak · hkwok |
| **Control plane** (MAST + TMS) | MAST state/attempts; TMS state, `tms_restarted`, reconciler | MAST `msl_scheduler` · TMS `managed_training_service` | Apurva Samudra · Siyuan Zhu · Neo Li |
| **IPNext / serving** | KM-S1 ATS; snapshot transition / load state | IPNext *(TBD)* | Hongbo Qin |
| **Storage / Manifold** | manifold tier health; `/proc` state D on storage fd | manifold/storage oncall | — |
| **ACL / Koski** | `PermissionDenied`/`Koski` across many jobs at once | AclCheckerService / koski | — |

---

## DPP — Data Reading  (oncall `dpp_distributed_data_reading`; T273130561; 13 SEVs incl. 1 SEV1)

**Leading indicator (catch it early):** DP-008 example-age creep (>1 min/hr over 3h), DP-002 slow-start (QPS <30% baseline >1h), DP-003 QPS cliff (>50% drop >30min) — see [detection-patterns.md](detection-patterns.md).

**Concrete upstream issues seen**
- **20-day Zeus session TTL restart** — every ~20d (1,728,000s) DPP restarts each OT job's data session → ~280 non-actionable example-age dips/half across 50+ jobs (CL-013; P0). Verify: `meta ai.mast-job error --name=<job> --no-truncate` → `Session <ID> has been running for <N> seconds which is higher than limit: 1728000`.
- **EDPP resize blocked by koski filtering cascade** — koski high-filter check blocks scale-up → ~115 OT jobs starved at once (S635390, S660329; P0).
- **DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE** — output queue fills, `getNextBatch` hangs for hours → `DataClientStuckException`; trainer has no getNextBatch timeout (S665454, S662557; P1; cf. P-row autolearn 2026-05-15).
- **DPP oscillation w/o external trigger** — start/stop cycles → 2.8–6h staleness, no upstream SEV (S664296; P1; consistent with P51 PPF token timeout / P30 pkg regression).
- **DPP pkg version change** (`:latest` roll / pin bump) → silent training hang (P30; S651765, fix D104285526).
- **Worker starvation / upstream scribe drain surfacing here** (P16; S674219 — see Scribe).

**Required metrics (confirm + source)**
- per-mast-job DPP starvation ODS — `canvas/pzoyunzx` (KM-U3).
- scribe token ingress — `dpp_stats_v2` (S674219: −75%).
- DPP worker count/queue/error — `dpp_worker_service_snapshot`, `mast_job_name=...` (P30).
- session-TTL restart — `ai_mlu` Scuba `RetryableFatalSystemError`+`Session` (`fburl.com/scuba/ai_mlu/fjh5vmsk`).
- corroboration: trainer `DataClient.cpp "output queue size"` INFO log (one snapshot can mislead — trust the ODS/ingress trend).
- `[GAP-A]` joint OT+DPP **example-age dashboard with SLO-breach alerting** (CL-013 #1, no dashboard today) — data: `mvai_metrics` + `ig_online_training_ats`. Owner: shuminwu (dashboard) + dennyzhang (alerting) + DPP.
- `[GAP-4]` single per-job "DPP health" rollup (ODS + ingress + worker-count in one signal).

**Route:** `dpp_distributed_data_reading` (+ koski / Zeus where named), with the per-job ODS + `dpp_stats_v2` chart.

---

## Scribe — Data Source  (category-owning team; + Zeus for credential/TTL)

**Leading indicator:** DP-008 example-age creep with Q-040 Scribe-QPS drop = upstream drying up (detection-patterns.md).

**Concrete upstream issues seen**
- **Region/tier drain** — DR EAG drained → EAG-reading jobs ~0 DPP ingress → fleet OT QPS=0 (S674219, "75% regression in DPP OT ingress due to EAG scribe drain"; S674227; fix D94521578).
- **Scribe write-volume drop from upstream diffs** — D96993922 / D97007645 dropped Scribe write volume → training-data breakage (S639956, SEV1).
- **Scribe QPS spike / throughput change** → example-age growth (P04); QPS drop across a tier (P12).
- **Upstream label/VM change zeroing shadow rows** — LSR pselect/VM change made `filter_empty_shadow_label` drop ALL shadow rows (autolearn 2026-05-07).

**Required metrics (confirm + source)**
- scribe token ingress per category + region — `dpp_stats_v2` → which category/region dropped.
- Scribe QPS — `bunnylol scribe <category>` (KM-U1).
- `[GAP-1]` per-region/per-category scribe-drain **early-warning** that fires BEFORE DPP ingress collapses (S674219 caught only after fleet impact).
- `[GAP-2]` per-mast-job → scribe category/region MAP (S674219 affected-job list was enumerated by hand).
- `[GAP-3]` non-PBA alert on drops in **training-data write volume to Scribe** (T263890913, open, from S639956).

**Route:** the Scribe category owner (+ Zeus team if credential/TTL plumbing).

---

## Hedwig — Delta Streaming  (oncall `home_ml_platform` *TBD*; POC Qiuyu Xiao; T273145307)

**Leading indicator:** DP-007 silent-publisher-death (KM-P4 `isActive=false` AND `queueSizeBytes=0` across ranks, >30min) — the early signal for both Hedwig and Publisher (detection-patterns.md).

> Use the **`hedwig-oncall` Claude skill** (team-hedwig plugin) to investigate — it drives the Scuba/ODS queries and runbooks. Dashboards: Main `internalfb.com/intern/unidash/dashboard/hedwig`, Tracker `.../hedwig/hedwig_tracker`, Superpeer `fburl.com/unidash/rk6m7hg6`. Oncall WP group 179830296674125.

**Concrete upstream issues seen**
- **Multicast over-subscription → training QPS collapse** — Omni root multicast to 14 ST models → QPS 0 for 10+h (S644248; P0; POC Qiuyu Xiao / Shengpei Zhang).
- **Hedwig rate limit / throttle** — `stream_to_hedwig failed`, `rate limit` (P07).
- **END-message loss** — streaming success drops during stream restarts (P15).
- **Channel delivery degradation** — 79–88% message loss, publisher queue backing up over weeks; do NOT restart trainer before draining queue (OOM) (autolearn 2026-03-30).
- **No SMC hosts on the streaming tracker** — `hedwig.streaming.flow.tracker` empty → publisher silent, reranker ran 6 days isActive=false (KM-P4 discovery).
- **dtype mismatch** (FS INT8 vs delta Float/BF16) → low sparse-delta streaming success (S650346; fix D101297690).

**Required metrics (confirm + source)**
- streaming success rate / in-order delivery rate / delivery-rate SLI — Hedwig unidash + SLICK; KM-P2.
- Hedwig publisher activity — KM-P4, `gmpp` by publish_mode (Q-014); `hedwig.streaming.flow.tracker` SMC host count = 0 → silent.
- publisher queue depth / flow-control state — Hedwig tracker dashboard.

**Route:** `home_ml_platform` (Hedwig) via the `hedwig-oncall` skill; POC Qiuyu Xiao, jcohen1 (SLO dashboard).

---

## Publisher — TGIF / GMPP / UMM / Manifold snapshot+delta  (POC Shengpei Zhang; TGIF/UMM POC TBD)

**Leading indicator:** DP-007 silent-publisher-death (KM-P4) + DP-004 checkpoint stall (no new checkpoint >2× interval → nothing to publish) — detection-patterns.md.

**Concrete upstream issues seen**
- **TGIF publish hang — no timeout/retry** (P0); also endless-retry-loop variant — needs retryability recognition.
- **Snapshot stuck CREATING** — job fails during publish so that snapshot never finishes (CL-001, #2; P48 UMM `CreateSnapshot` blocking RPC; zero new UMM `model.instance` records).
- **Full snapshot blocking deltas** (P01); **publish pipeline deadlock** `wait_for_publish_completion` w/o `publish_complete` (P02, fix D96358986).
- **NCCL timeout from publish stall** (P19); **`invoke_on_rank_and_broadcast_result` gloo recv 1h hang** in model_processing publish path (P34, recurring); **Manifold key collision** (P23); **RAAS fallback → publish stall** (P28).

**Required metrics (confirm + source)**
- snapshot/delta cadence gap — KM-P1/KM-P3; `sigrid_predictor` snapshot latency (last-delta timestamp stale).
- streaming success — KM-P2; UMM `model.instance` records (none since onset = RPC never landed, P48).
- `[GAP-5]` per-job publish-stall detector firing BEFORE the snapshot/delta gap exceeds SLO (P02/P34/P48 caught late/silently; no SJD coverage of publish path).

**Route:** Hedwig (delivery → its own row), `model_processing` (P34), TGIF/UMM owners (POC TBD), SilverTorch/MVAI (FS/delta deadlock).

---

## SJD — StuckJobDetector (job kill + restart)  (MVAI platform; Shengpei Zhang · ezrak · hkwok; T273136092)

SJD is the safety net that detects a stuck OT job and kills→restarts it. Its
COVERAGE GAPS are themselves an OT failure source (~512 GPU-hr/month waste).

**Leading indicator:** DP-001 zombie (MAST RUNNING + KM-T2 QPS=0 >2h) — the exact pattern SJD should catch but misses; the agent must flag it when SJD doesn't (detection-patterns.md).

**Concrete upstream issues seen**
- **Blind when the trainer PROCESS dies but container stays alive** — zombie; MAST RUNNING, no FAILED, no kill (architectural; P61; S628346 974h class, S665454, S670887).
- **Cannot detect publish-path hangs** — SJD watches train-loop liveness only; a stuck publish is invisible (P02/P34; detection ~1.5h; a separate publish SJD lease would cut to ~30min).
- **Heartbeat ≠ progress** — lease-renewal thread renews `mvai_monitor` independently of the stuck trainer → never fires (S670887).
- **Fires but can't kill / no restart** — Elastic-Agent exit-code bug (P21); permissive `max_cont_stucks_before_kill>1`, `tms_restarted=False` (P40, fix D101707010).
- **Low-but-positive QPS (~3k) never trips SJD** — degraded ≠ stuck; needs a throughput monitor, not SJD (S674219 thread).

**Required metrics (confirm + source)**
- trainer liveness — `mvai_metrics` last-sample staleness vs MAST RUNNING (P44 probe) → stale+RUNNING = SJD blind.
- `tms_restarted` + `max_cont_stucks_before_kill` — `meta ai.mast-job metadata` (P40).
- `[MVAI_EXIT]` marker in job log — absent ⇒ EA hung (D107459272).
- `[GAP-6]` SJD-detect → next-attempt-RUNNING **latency** metric (drive kill→restart time down).
- `[GAP-7]` throughput-aware low-positive-QPS detector (QPS << job baseline for N min).

**Route:** MVAI platform (Shengpei Zhang / ezrak / hkwok).

---

## Control Plane — MAST scheduler + TMS

**Leading indicator:** DP-006 TMS/MAST desync crash-loop (MAST RUNNING + TMS≠ONLINE_READY, or ≥3 DEAD attempts <10min each killed by reconciler) — detection-patterns.md (D106193941).

### MAST scheduler / capacity (oncall `msl_scheduler`; Apurva Samudra · Yingie Tang · Takshak Chahande; T273128182)
- **Scheduler stall — PENDING, never dispatched** despite quota (P39; 5 SEVs 2026-04-30→05-05).
- **Preemption cascade** — many jobs DEAD/PENDING at once (P10); **region capacity fragmentation** under quota (autolearn 2026-05-02).
- **Boxcar planned-maintenance preemption** — FAILED attempt w/ `Boxcar`/`OpsPlanner`/`RUNTIME_STATE_LOSS` (P38).
- **Elastic donations / host reclamation** — preempts co-located OT pods (S674182; was a *concurrent red herring* in S674219 — confirm DPP ingress first).
- **Reuses same TW hosts on retry** + **doesn't detect main-process exit when container stays alive** (P0 follow-ups #7/#8; S628346 zombie class).
- Metrics: `meta ai.mast-job metadata/attempts` (PENDING vs FAILED-Boxcar vs preempted); concurrent host-scheduler SEV search; `[GAP-8]` agent-queryable per-entitlement GTR capacity (P39 uses a screenshot today).

### TMS — training management service (oncall `managed_training_service`; Siyuan Zhu · Neo Li · Lyric Wu; T273134930)
- **State stuck != ONLINE_READY** (P08); **expired fbpkg → can't restart** (P03/P17; S661157).
- **"Job expired" = recurring flow `is_enabled=false`** (P53); **identity extraction failure → "nobody" launches** (P0 #6).
- **No auto-restart on stuck** — permissive `max_cont_stucks_before_kill` (P40); **reconciler cycle too slow for OT** + **~2h restart latency vs ~30min SJD** (P0 follow-ups; S670887).
- Metrics: `mvai online-training-mgr print` (KM-TMS1, state EXPIRED); `tms_restarted`/`max_cont_stucks` (P40); recurring-flow `is_enabled` (P53); restart count KM-TMS2.

**Route:** MAST `msl_scheduler` / TMS `managed_training_service` — but only after the data-side (DPP/Scribe/Hedwig) is confirmed healthy.

---

## IPNext / Serving  (oncall IPNext *TBD*; Hongbo Qin; T273145485; 13 SEVs)
- **Model stuck loading / snapshot transition delays** (P0; P09 predictor snapshot stall).
- **Calibration shift / NE explosion after model update** (P0; cf. P06 checkpoint corruption — revert-and-ban).
- **Persistent inference error rates on Tier-1 models** (P0).
- Metrics: KM-S1 ATS; `sigrid_predictor` snapshot apply lag (last applied vs produced); IPNext load/transition state.

**Route:** IPNext (POC Hongbo Qin).

---

## Storage / Manifold  (manifold/storage oncall)
- **Storage syscall stall** — trainer `/proc` state `D`, py-spy on `pwrite`/`fdatasync` into manifold/checkpoint path; co-presents w/ degraded manifold tier (P46).
- **Manifold key collision on publish** (P23).
- Metrics: manifold tier health `fburl.com/manifold-tier-health`; `meta manifold.bucket metadata --bucket <B>`; `/proc/<pid>/status` state D + fd on storage path (P46).

## ACL / Koski  (AclCheckerService / koski)
- **AclCheckerService outage** — `PermissionDenied`/`Koski` failing UNIFORMLY across many jobs at once (P11).
- **DPP PERMISSION_DENIED on a Scribe/koski source** — buried/confusing error, job runs degraded (S665607; DPP P1 — "fail fast with the ACL link").
- Metric: same `PermissionDenied`/`Koski` error across multiple unrelated jobs simultaneously = infra, not per-job config.

---

## Metric gaps — required signals we don't have yet (placeholders / instrumentation asks)

| ID | Gap | Why (incident) | Owner to build |
|---|---|---|---|
| GAP-A | OT example-age dashboard + SLO-breach alerting (per model) | CL-013 #1, 4+ inc/month, no dashboard | shuminwu + dennyzhang + DPP |
| GAP-1 | per-region/category scribe-drain early-warning (pre-DPP-collapse) | S674219 caught post-impact | Scribe / DPP |
| GAP-2 | per-mast-job → scribe category/region map | S674219 job list done by hand | DPP |
| GAP-3 | non-PBA Scribe training-data write-volume alert | S639956 SEV1 (T263890913 open) | DPP/Scribe |
| GAP-4 | single per-job "DPP health" rollup (ODS+ingress+workers) | OT agent slow to detect DPP starvation, S674219 | DPP |
| GAP-5 | per-job publish-stall detector before SLO breach | P02/P34/P48 caught late; no publish-path SJD | Publisher/MVAI |
| GAP-6 | SJD detect→restart latency metric + separate publish SJD lease | ~2h vs ~30min; ~512 GPU-hr/mo waste | MVAI/SJD |
| GAP-7 | throughput-aware low-positive-QPS detector | ~3k-QPS jobs never trip SJD (S674219) | MVAI |
| GAP-8 | agent-queryable per-entitlement GTR capacity | P39 uses a screenshot | MAST `msl_scheduler` |

## Discipline

- **Data-side first on a synchronized drop.** A per-job hang cannot synchronize → shared upstream (Scribe/DPP/Hedwig). S674219 = EAG scribe drain.
- **Restart-required recovery is NOT proof of a non-data cause** — restart can re-point a job to a recovered upstream (S674219).
- **Don't diagnose the upstream's internals.** Show the regression, name the owner, attach per-job evidence; the owning team finds the cause.
- **Multi-job simultaneity ⇒ infra, not per-model config** (P10/P11/P12/P39/S674219). One incident, escalate once with the full job list.
- **Worked example (S674219, SEV1, 2026-06-10):** DPP+Scribe regressed (starvation ODS up; `dpp_stats_v2` ingress −75% from EAG/DR drain) → routed DPP/scribe; tracked S674227, mitigated D94521578. Red herrings: host-preemption S674182 (concurrent) and a single healthy output-queue snapshot on job 2144239965.

## Provenance

Owners/taxonomy/follow-ups from gdoc **[MRS OT Reliability — Cross-Team Follow-ups]**
(`1mpy7J9r-GCkUTNjQzzdWsJDWbFC9iJ3ctZsFdvyX-qs`, Key Contacts table, 2026-06-05).
Per-dependency issues + metrics distilled from known-patterns.md (P01–P62) and the
KM catalog in [slo-recovery-metrics.md](slo-recovery-metrics.md). `[GAP]`/`[GAP-N]`
= signals we still need. Bot extends rows as new dependency outages are triaged.
POCs marked *TBD* where the gdoc has none.
