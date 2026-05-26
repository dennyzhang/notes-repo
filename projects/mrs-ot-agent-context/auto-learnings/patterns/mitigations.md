# Mitigations (D-NNN)

_Mitigations / fixes — landed, in-flight, or proposed. Each entry: what it does → status → owner → cost → which failure-modes/root-causes it addresses._

---

## 🗂️ Family map — 25 D-NNNs consolidated into 7 families

Use this to scan; drill into the detailed entries below by anchor.

| D-family | Brief | D-NNN entries | Landed? |
|---|---|---|---|
| **LIVENESS_PROBES** | Detect zombies / stalls before MAST does | D-001, D-002, D-003, D-004, D-005, D-006, D-007 | D-007 ✅ landed; rest proposed |
| **CI_GATE** | Preempt reland of reverted bugs | D-008, D-015 | All proposed |
| **DEBUG_PROTOCOL** | Playbooks (NaN / family-SEV / QPS) | D-009, D-010, D-011 | Active in cron prompts |
| **INFRA_SLA** | Downstream-team SLA + OT graceful-degrade | D-012, D-013 | Open (conversations) |
| **CONFIG_VALIDATION** | Validate quotas / thresholds / corpus health | D-016, D-017, D-018, D-019, D-020 | Mixed (D-017 stopgap landed) |
| **DETECTOR_HYGIENE** | Suppress noise + tune at source | D-021, D-022 | Proposed |
| **OPERATOR_DISCIPLINE** | Cron prompt amendments / process | D-023, D-024, D-025 | Active |

Coverage gap: 0 of 8 P-NNN systemic causes have a *landed* structural mitigation (see [`INDEX.md`](INDEX.md) P→D coverage table). _Note: D-014 was an old duplicate of D-008; merged 2026-05-20. The ID D-014 is retired; do not reuse._

---

## D-001 — External liveness probe (out-of-process watchdog on `mvai_metrics` step counter / QPS / example_age)

**What:** Out-of-process watchdog polls `mvai_metrics` for forward progress. If RUNNING + no progress for N min → force-kill MAST job via cgroup. Catches all "trainer alive but no training" cases.

**Status:** Proposed (not started). The single highest-leverage mitigation for the elastic-agent zombie class (M-001) — closes invariants I1 + I4 in Proposal F.

**Owner:** `mrs_online_training` infra. Cost: ~1-2 weeks.

**Generalizes:** D-007 (D104947534 SJD publisher-shutdown — DPP-side only) → to trainer-side too.

**Addresses failure modes:** M-001, M-002, M-005, M-011 (anything that stops training while keeping launcher alive)

---

## D-002 — Hard exit timeout in PyTorch elastic agent after `ChildFailedError`

**What:** PyTorch elastic agent (torchrun launcher) MUST exit within N seconds of catching `ChildFailedError`, regardless of subprocess cleanup state. Currently blocks indefinitely waiting for D-state subprocesses.

**Status:** Proposed. Owner: PyTorch upstream collaborator. Cost: RFC + several releases.

**Addresses failure modes:** M-001 (closes invariant I2 in Proposal F).

---

## D-003 — Cgroup-based force-kill of D-state subprocesses

**What:** D-state subprocesses can't be terminated by signal (SIGKILL ignored). Cgroup deletion at OS level bypasses signal delivery. MAST/SJD could expose a "force-reap" path using this when liveness signal degrades.

**Status:** Proposed. Owner: MAST/SJD infrastructure. Cost: design + cgroup integration.

**Addresses failure modes:** M-001 (closes invariant I3 in Proposal F).

---

## D-004 — `ot-age-spike-monitor` cron + dedicated training-example-age dashboard

**What:** Bot cron that detects training-example-age spikes in real time, mapped to one of ~7 known CL-013 sub-mechanism classes. Plus a dashboard for per-OT-model age with SLA breach alerting.

**Status:** NOT STARTED — **#1 top action item per `failure-patterns.md`**.

**Owner:** `shuminwu` (dashboard) + `dennyzhang` (cron). Cost: 1-2 weeks agent work.

**Addresses failure modes:** M-011 (holdout periodic data-cycle stall), and all CL-013 cluster sub-mechanisms.

---

## D-005 — `ot-timeout-monitor` cron + timeout-aware bot rule

**What:** ~20-line cron edit + new monitor to detect timeout-class symptoms (NCCL/watchdog/RaaS). Distinguishes from other clusters that hide timeout root cause.

**Status:** NOT STARTED — **#2 top action item**.

**Owner:** `dennyzhang`. Cost: ~20-line cron edit + monitor scaffolding.

**Addresses failure modes:** M-005 (ALLREDUCE rank desync), M-001 (NCCL collective timeout path).

---

## D-006 — `ot-autostart-liveness` cron

**What:** Probe `intent==active` models. Alert if `(now - last_mast_attempt_start) > 2× expected_launch_interval` OR `online_train_publish step SUCCEEDED` AND `no TLS config diff in last interval`.

**Status:** NOT STARTED — **#4 top action item**.

**Owner:** `dennyzhang`. Cost: ~1 week agent work. Threads brief to `renqincai`; IG Reels LSR brief if W1215 owner Jakub Bester confirms.

**Addresses failure modes:** M-004 (OT auto-start silent stall).

---

## D-007 — D104947534 (SJD publisher-shutdown fix + DPP-QPS watchdog)

**What:** SilverTorch SJD fix to detect DPP-side QPS=0 patterns and trigger restart. CL-012 sub-mechanism mitigation.

**Status:** IN FLIGHT. Owners: ezrak + hkwok.

**Scope limitation:** DPP-side only. Doesn't cover trainer-side stalls (those need D-001 generalization).

**Addresses failure modes:** M-002 (DPP starvation, partial coverage).

---

## D-008 — Post-revert reland-block CI gate

**What:** When a diff is reverted with a SEV tag, future relands of the same code content fail CI without explicit acknowledgment. Closes the reland anti-pattern.

**Status:** Proposed. Owner: release-eng / source-control. Cost: ~1 week.

**Addresses root causes:** R-003 (D103046213 reland of S656635-reverted code), R-020 (D105054082 incomplete-refactor reland pattern).

---

## D-009 — Joint OT/PG debug protocol (for QPS-class issues)

**What:** Agreed first-pass triage steps + ownership rubric ("is this an infra-side root or model-side root?") + escalation path for training QPS dip / slow ramp-up patterns. Eliminates OT/PG ping-pong.

**Status:** Proposed. Owner: `shuminwu` (cross-team).

**Addresses failure modes:** M-002, M-007, M-010 (for both CL-015a sudden-drop and CL-015b slow-ramp sub-classes).

---

## D-010 — P56 NaN mitigation playbook + L20 STUS-style escalation rule for CL-017

**What:** P56 NaN mitigation playbook (model-side, owners apply when CL-017 fires). Plus L20-style ratchet: 2nd+ family-wide CL-017 fire in 24h → explicit "family-level threshold suppression OR Shampoo guardrails" recommendation, not yet-another-passive-MONITOR.

**Status:** P56 playbook exists in known-patterns.md. L20-style family-wide ratchet for CL-017 = not yet codified in cron prompts.

**Addresses failure modes:** M-003 (NaN cascade), repeat-fire problem from R-VC4 auditor finding.

---

## D-011 — R-VC4 family-SEV escalation (bot prompt amendment)

**What:** When same-cluster failures fire ≥3+ times in 7d across same model-family OR ≥5 cross-submodel-family same-detector signal → escalate from per-incident verdict to "family-level SEV proposal" recommendation.

**Status:** Proposed (flagged by auditor 6+ times today as carryover gap). Cron prompt amendment needed.

**Owner:** dennyzhang (cron prompt edit).

**Addresses repeat-fire patterns:** CL-017 cfr family, CL-013 IG retrieval holdout family

---

## D-012 — Downstream-infra SLA conversation with ZippyDB / Scribe / DPP leads

**What:** Leadership ask: formal SLAs from upstream infra teams; OT-side graceful-degradation design when SLAs miss.

**Status:** Proposed — #5 top action item per failure-patterns.md.

**Owner:** `shuminwu` (cross-team).

**Addresses failure modes:** M-007 (downstream-infra reliability cascade).

---

## D-013 — OT-side graceful-degradation design

**What:** Design OT pipeline to degrade gracefully under upstream-infra failures rather than fail loudly.

**Status:** Proposed (paired with D-012).

**Addresses failure modes:** M-007, M-018.

---

## D-015 — Host-memory ceiling check in cogwheel test config

**What:** Add memory-budget check in umia_v1_igr (and similar) cogwheel test configs to fail-fast on OOM-prone changes before publish_all step crashes.

**Status:** Proposed (per S666322 today's triage). Cost: small config addition.

**Addresses root causes:** R-018 (CUDA OOM at AOTI), R-021 (Sandcastle I7_XLARGE OOM).

---

## D-016 — Quota-tenant-path validation in launcher

**What:** Validate that OT jobs land in `threads_online_training` (Scribe-based) tenant, not `threads_offline`. Fail launch with explicit error if wrong bucket.

**Status:** Proposed.

**Addresses root causes:** R-022 (GPU quota misconfiguration).

---

## D-017 — Lower `n_min_embeddings_required` as stopgap

**What:** Short-term mitigation while T2I corpus is restored: lower minimum threshold in `fbcode/silvertorch/experimental/realtime/fresh_index_initializer.py:91`.

**Status:** Stopgap, not yet applied.

**Addresses root causes:** R-031 (T2I corpus regression), part of P63 quick-match guidance.

---

## D-018 — Upstream T2I corpus health monitoring

**What:** Alert on T2I embedding corpus count when it drops below threshold + N. Catch corpus regression BEFORE STUS kmeans fails.

**Status:** Proposed.

**Addresses root causes:** R-031.

---

## D-019 — Raise `bloom_index_b` OR migrate to dynamic-sized bloom filter (per-model fix)

**What:** Specific per-model bloom_index capacity fix.

**Status:** T271094105 (lizichao).

**Addresses root causes:** R-006.

---

## D-020 — Bloom filter auto-scaling (platform fix)

**What:** Dynamic bloom-filter sizing in the publish_all framework — automatic capacity expansion when cardinality grows.

**Status:** Proposed (longer-term than D-019). Owner: `p92_relevance_retrieval` + MVAI infra.

**Addresses root causes:** R-006 family-wide.

---

## D-021 — Archive-match suppression rule (cron + alert-monitor)

**What:** When `alert_id` has a recent archive (in `incidents/resolved-alerts/<YYYY-MM>/`) AND classifies as DETECTOR_BROKEN/STALE → suppress re-triage entirely.

**Status:** Proposed (Friday batch).

**Addresses failure modes:** M-016 (detector misconfig), M-017 (no-auto-clear).

---

## D-022 — Detector clear-cadence tuning at detector source

**What:** Detectors should auto-clear faster when metric stops violating threshold. Currently many fire for days post-recovery.

**Status:** Proposed. Owner: detector-source teams (varied).

**Addresses failure modes:** M-017.

---

## D-023 — Pre-mitigation state-loss checklist (CL-002 watch class)

**What:** Bot's triage output enumerates which job state will be lost on standard mitigation (clear info.json, kill+re-enable) — prevents over-reset → secondary-regression class.

**Status:** Proposed (~1 hour cron edit). Owner: `dennyzhang`.

**Addresses failure modes:** CL-002 watch-class mechanism (mitigation over-reset).

---

## D-024 — Registry-first triage discipline (cron prompt amendment)

**What:** Before any verdict, cron MUST grep `failure-patterns.md` cluster registry + this `patterns/` directory by symptom keyword. If matching CL-NNN / S-NNN exists, adopt classification explicitly. Don't re-derive root cause from first principles. (Proposal F third commit content.)

**Status:** Proposed (Friday batch). Owner: dennyzhang. Cost: ~30-line prompt amendment.

**Addresses analytical gap:** narrow-lens / re-derivation errors observed across 2026-05-19/20 session.

---

## D-025 — Bot access to SEV-specific gchat rooms

**What:** Currently bot can't read SEV-specific gchat rooms (e.g., AAQAZlWotYI for S665478). Many SEV root-cause analyses live ONLY in gchat (not agent-feed, not form fields). Bot's blind to these. Need either: bot added as member to SEV rooms (operator action OR automated when SEV opens), or alternative gchat read access path.

**Status:** Proposed. Blocked on access policy.

**Addresses analytical gap:** SEVs like S661645 where the canonical RCA is operator+CC-bot discussion in chat, not in agent-feed.
