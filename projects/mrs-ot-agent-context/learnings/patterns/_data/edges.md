# Edges (S↔M, M↔R, M↔D, R↔D)

> ⚠️ **MACHINE-CONSUMED DATA — not for direct human reading.**
>
> This file is a YAML-in-markdown edge graph for bot triage traversal (S→M→R→P→D). Operators should read [`../INDEX.md`](../INDEX.md) (entry point) or the per-entity files (`../symptoms.md`, `../failure-modes.md`, `../root-causes.md`, `../systemic-causes.md`, `../mitigations.md`). Edit this file only when adding/updating an entity in the graph.

_Many-to-many relationships between symptoms / failure modes / root causes / mitigations. Each edge has a weight (frequency / confidence) and optional falsifier (how to distinguish from sibling edges)._

This is the relational backbone of the patterns/ knowledge graph. Bot triage flow traverses these edges to converge from observed symptom to identified root cause and recommended mitigation.

---

## Symptom → Failure Mode (S→M)

```yaml
# S-001 example_age spike — multiple mechanism candidates
- from: S-001
  to:   M-001    # elastic agent zombie
  weight: 0.3
  evidence: [S665454, S665478, S665464]
  falsifier: "If mvai_metrics fresh AND MAST attempts stable → not M-001"

- from: S-001
  to:   M-002    # DPP starvation
  weight: 0.25
  evidence: [CL-003 cascades]
  falsifier: "DPP Data Starvation % <2% in system-metrics → not M-002"

- from: S-001
  to:   M-007    # downstream-infra reliability
  weight: 0.20
  evidence: [S665163 ZippyDB, S659917 Feed LSR]
  falsifier: "No active ZippyDB/Scribe/Koski/DPP infra SEV → not M-007"

- from: S-001
  to:   M-011    # holdout periodic data-cycle stall
  weight: 0.15
  evidence: [m2145336177-2026-05-20]
  falsifier: "If example_age is monotonic-rising (not periodic) → not M-011"

- from: S-001
  to:   M-003    # NaN cascade (stale alert post-recovery)
  weight: 0.10
  evidence: [m878858380, m2134801434]
  falsifier: "If MAST attempts show clean restart + mvai_metrics fresh → M-003 stale-fire, not active"

# S-002 FS missing — many root mechanisms
- from: S-002
  to:   M-001
  weight: 0.20
- from: S-002
  to:   M-003
  weight: 0.15
- from: S-002
  to:   M-012    # conveyor regression
  weight: 0.15
  evidence: [S665902]
- from: S-002
  to:   M-013    # STUS kmeans corpus underflow
  weight: 0.10
  evidence: [m2130324780-2026-05-20]
- from: S-002
  to:   M-014    # STUS-normal-cadence misclassification
  weight: 0.40
  falsifier: "Compute gap-vs-cadence ratio. If gap <2× historical cadence → M-014. If gap >>2× cadence OR trainer error logs → not M-014, real failure"
- from: S-002
  to:   M-009    # cogwheel publish failure (pre-prod only)
  weight: 0.10
  falsifier: "If alert is from prod model.instance (not cogwheel test) → not M-009"

# S-003 QPS=0 — overlaps with S-001 but distinct
- from: S-003
  to:   M-001
  weight: 0.30
- from: S-003
  to:   M-002
  weight: 0.25
- from: S-003
  to:   M-005    # ALLREDUCE barrier rank desync
  weight: 0.20
- from: S-003
  to:   M-011
  weight: 0.15
- from: S-003
  to:   M-003
  weight: 0.10

# S-005 StuckJobException
- from: S-005
  to:   M-001
  weight: 0.60    # dominant mechanism
- from: S-005
  to:   M-005
  weight: 0.20
- from: S-005
  to:   M-015    # bloom_index_b overflow
  weight: 0.15

# S-006 mvai_metrics flatline
- from: S-006
  to:   M-001
  weight: 0.50
- from: S-006
  to:   M-003
  weight: 0.30

# S-007 detector self-reports invalid / stale
- from: S-007
  to:   M-016    # detector misconfiguration
  weight: 0.50
  falsifier: "`[Invalid Detector - No Data]` prefix → M-016 confirmed. Snapshot list shows model publishing healthy → M-016."
- from: S-007
  to:   M-017    # no-auto-clear
  weight: 0.30
  falsifier: "Alert age >7d and ACTIVE without state change → M-017"
- from: S-007
  to:   M-003    # stale NaN alerts post-recovery
  weight: 0.20

# S-008 serving error rate
- from: S-008
  to:   M-018    # freshness regression cascade
  weight: 0.40
- from: S-008
  to:   M-007    # downstream-infra (different layer)
  weight: 0.30
- from: S-008
  to:   "T4 serving (out-of-OT-scope, route via R18)"
  weight: 0.30

# S-009 cogwheel / conveyor test failure
- from: S-009
  to:   M-009
  weight: 0.80
- from: S-009
  to:   M-012
  weight: 0.20    # when affects prod publish path too

# S-010 NCCL / distributed collective timeout in trainer log (added 2026-05-20)
- from: S-010
  to:   M-005    # ALLREDUCE barrier rank desync (direct cause when peer slow)
  weight: 0.50
  evidence: [S665464, S665478]
  falsifier: "If AITO classifies as NCCL_TIMEOUT cleanly AND launcher exits → M-005 alone, no M-001 cascade"
- from: S-010
  to:   M-001    # elastic agent zombie (cascade when launcher fails to propagate)
  weight: 0.35
  evidence: [S665478, S665454]
  falsifier: "meta ai.mast-job error returns only user-kill (no AITO class) = M-001 cascade present"
- from: S-010
  to:   M-002    # DPP starvation (when DPP slowness blocks main thread)
  weight: 0.15
  evidence: [CL-003 cascades]
  falsifier: "DPP Data Starvation % <2% in system-metrics → not M-002"

# S-011 TCPStore binding race in delta publisher (added 2026-05-20)
- from: S-011
  to:   M-001    # elastic agent zombie via R-005
  weight: 0.80
  evidence: [S658165]
  falsifier: "Must see bind() / 'Address already in use' in publisher log; otherwise different sub-mechanism"
- from: S-011
  to:   M-005    # rank-init desync if init fails on one rank
  weight: 0.20
  evidence: [S658165 sub-pattern]
```

---

## Failure Mode → Root Cause (M→R)

```yaml
# M-001 elastic agent zombie — multiple root causes feed into it
- from: M-001
  to:   R-001    # CUDA allocator state corruption
  weight: 0.20
  evidence: [S665454 — 3 jobs affected by same INTERNAL ASSERT]
  falsifier: "meta ai.mast-job logs grep 'CUDACachingAllocator.cpp:3316' → R-001 confirmed"

- from: M-001
  to:   R-002    # exit_w_cleanup gap
  weight: 0.25
  evidence: [S628346 — W21 mega-learning #5]
  falsifier: "mast-job logs grep 'exit_w_cleanup' OR ChildFailedError handler trace → R-002"

- from: M-001
  to:   R-003    # NCCL/Gloo mixed-PG
  weight: 0.15
  evidence: [S665464, D103046213 reland]
  falsifier: "Code grep for 'dist.barrier' with NCCL PG while gloo elsewhere → R-003"

- from: M-001
  to:   R-004    # NCCL collective timeout
  weight: 0.15
  evidence: [S665478]
  falsifier: "Logs grep 'NCCL collective timeout' or 'WatchdogTimeout' → R-004"

- from: M-001
  to:   R-005    # TCPStore binding
  weight: 0.10
  evidence: [S658165]

- from: M-001
  to:   R-014    # ALLREDUCE rank desync from DPP slowness
  weight: 0.15
  evidence: [S661645 — 1-element ALLREDUCE barrier timed out 3h]
  falsifier: "DPP data loading 80-100ms across all ranks per Scuba mvai_metrics → R-014"

# M-002 DPP starvation
- from: M-002
  to:   R-007    # Scribe overload
  weight: 0.30
- from: M-002
  to:   R-008    # ZippyDB CAS throttle
  weight: 0.25
- from: M-002
  to:   R-009    # DPP worker config
  weight: 0.20
- from: M-002
  to:   R-012    # _preload_item_pool deadlock
  weight: 0.15

# M-003 trainer NaN cascade
- from: M-003
  to:   R-010    # Shampoo factor_matrix NaN
  weight: 0.80
- from: M-003
  to:   R-011    # second-moment matrix corruption
  weight: 0.20

# M-004 OT auto-start silent stall
- from: M-004
  to:   R-013    # MVAI expiration
  weight: 0.33
- from: M-004
  to:   R-014a   # FBLearner is_enabled=false
  weight: 0.33
- from: M-004
  to:   R-014b   # skip_recurring=True
  weight: 0.20
- from: M-004
  to:   R-014c   # parent FBLearner stopped → orphan kill
  weight: 0.14

# M-005 ALLREDUCE barrier rank desync
- from: M-005
  to:   R-014    # DPP-driven desync
  weight: 0.40
- from: M-005
  to:   R-003    # NCCL/Gloo mixed-PG
  weight: 0.30
- from: M-005
  to:   R-004    # NCCL timeout unrelated upstream
  weight: 0.30

# M-007 downstream-infra cascade
- from: M-007
  to:   R-007    # Scribe overload
  weight: 0.40
- from: M-007
  to:   R-008    # ZippyDB CAS throttle
  weight: 0.40
- from: M-007
  to:   R-017    # Koski PERMISSION_DENIED ACL
  weight: 0.20

# M-009 cogwheel publish failure class
- from: M-009
  to:   R-018    # CUDA OOM at AOTI
  weight: 0.20
- from: M-009
  to:   R-019    # TorchScript class annotation
  weight: 0.10
- from: M-009
  to:   R-020    # LoweringLogicException incomplete refactor
  weight: 0.20
- from: M-009
  to:   R-021    # Sandcastle I7_XLARGE OOM
  weight: 0.30
- from: M-009
  to:   R-017    # Koski ACL
  weight: 0.10
- from: M-009
  to:   R-024    # TGIF rendezvous timeout transient
  weight: 0.10

# M-011 holdout periodic data-cycle stall (hypotheses to verify)
- from: M-011
  to:   R-025    # FS publish boundary blocking (HYPOTHESIS)
  weight: 0.30
- from: M-011
  to:   R-026    # periodic eval pass (HYPOTHESIS)
  weight: 0.30
- from: M-011
  to:   R-027    # periodic distributed barrier slow rank (HYPOTHESIS)
  weight: 0.20
- from: M-011
  to:   R-028    # GC/compaction side process (HYPOTHESIS)
  weight: 0.20

# M-012 conveyor regression
- from: M-012
  to:   R-029    # Conveyor pkg ModuleNotFoundError
  weight: 0.50
  evidence: [S665902]
- from: M-012
  to:   R-020    # LoweringLogicException
  weight: 0.30
  evidence: [S666451]

# M-013 STUS kmeans corpus underflow
- from: M-013
  to:   R-031    # T2I corpus regression
  weight: 1.00

# M-014 STUS-normal-cadence misclassification
- from: M-014
  to:   R-032    # detector not STUS-aware
  weight: 1.00

# M-016 detector misconfiguration
- from: M-016
  to:   R-033    # threshold misaligned
  weight: 0.40
- from: M-016
  to:   R-034    # data source disconnected
  weight: 0.40
- from: M-016
  to:   D75703936-formula-bug   # known mega-learning
  weight: 0.20
  evidence: [m877766932 facebook_reels_vdd_hstu_v0]

# M-017 detector-no-auto-clear
- from: M-017
  to:   R-035    # hysteresis missing
  weight: 0.60
- from: M-017
  to:   R-036    # re-eval cadence too slow
  weight: 0.40
```

---

## Failure Mode → Mitigation (M→D)

```yaml
- from: M-001
  to:   D-001    # external liveness probe — THE structural fix
  status: proposed
- from: M-001
  to:   D-002    # hard exit timeout
  status: proposed
- from: M-001
  to:   D-003    # cgroup force-kill
  status: proposed

- from: M-002
  to:   D-007    # D104947534 SJD publisher-shutdown
  status: in_flight

- from: M-002
  to:   D-005    # ot-timeout-monitor cron
  status: not_started

- from: M-004
  to:   D-006    # ot-autostart-liveness cron
  status: not_started

- from: M-007
  to:   D-012    # downstream-infra SLA conversation
  status: proposed
- from: M-007
  to:   D-013    # OT graceful-degradation
  status: proposed

- from: M-009
  to:   D-008    # post-revert reland-block CI gate
  status: proposed
- from: M-009
  to:   D-015    # host-memory ceiling in cogwheel test
  status: proposed

- from: M-011
  to:   D-004    # ot-age-spike-monitor cron + dashboard
  status: not_started

- from: M-013
  to:   D-017    # lower n_min_embeddings_required stopgap
  status: stopgap
- from: M-013
  to:   D-018    # upstream T2I corpus health monitoring
  status: proposed

- from: M-014
  to:   D-010    # L20 STUS-style escalation rule
  status: landed

- from: M-015
  to:   D-019    # per-model bloom_index fix
  status: in_flight (T271094105)
- from: M-015
  to:   D-020    # bloom-filter auto-scaling
  status: proposed

- from: M-016
  to:   D-021    # archive-match suppression rule
  status: proposed
- from: M-017
  to:   D-021
  status: proposed
- from: M-017
  to:   D-022    # detector clear-cadence tuning
  status: proposed
```

---

## Root Cause → Systemic cause (R→P) — added 2026-05-20

_Maps each immediate bad change to the recurring error-cause pattern it instantiates. Lets reverse traversal answer "how many R-NNN instances of this pattern have we seen?" and "do we have a mitigation for the systemic cause, or are we fighting each R individually?"_

```yaml
# P-001 — main thread blocked in heavy op → timeout race
- from: R-004  # NCCL collective timeout
  to:   P-alpha
- from: R-024  # TGIF rendezvous timeout
  to:   P-alpha
- from: R-014  # DPP-driven ALLREDUCE rank desync
  to:   P-alpha
- from: R-027  # periodic distributed barrier slow rank (M-011 hypothesis)
  to:   P-alpha

# P-002 — worker died, launcher couldn't propagate exit cleanly
- from: R-001  # CUDA allocator state corruption
  to:   P-beta
- from: R-002  # exit_w_cleanup gap
  to:   P-beta
- from: R-003  # NCCL/Gloo mixed-PG dist.barrier
  to:   P-beta
- from: R-004  # NCCL collective timeout (also P-alpha)
  to:   P-beta
- from: R-005  # TCPStore binding race
  to:   P-beta
- from: R-014  # DPP rank desync (also P-alpha)
  to:   P-beta

# P-003 — static config exceeded by organic growth
- from: R-006  # bloom_index_b=2240
  to:   P-gamma
- from: R-031  # T2I corpus 64,077 minimum
  to:   P-gamma
- from: R-007  # Scribe overload
  to:   P-gamma
- from: R-008  # ZippyDB CAS throttle
  to:   P-gamma
- from: R-021  # Sandcastle I7_XLARGE OOM
  to:   P-gamma

# P-004 — reland of reverted bug without test guardrail
- from: R-003  # D103046213 relanding S656635 (also P-beta)
  to:   P-delta
- from: R-020  # D105054082 incomplete refactor
  to:   P-delta

# P-005 — detector built for role A used on role B
- from: R-032  # detector not STUS-aware
  to:   P-epsilon
- from: R-033  # detector threshold misalignment
  to:   P-epsilon
- from: D75703936-formula-bug  # TZ skew assumption
  to:   P-epsilon

# P-006 — lifecycle event silently caught by orchestration
- from: R-013  # MVAI expiration silent
  to:   P-zeta
- from: R-014a  # FBLearner is_enabled=false
  to:   P-zeta
- from: R-014b  # skip_recurring=True
  to:   P-zeta
- from: R-014c  # parent FBLearner stopped
  to:   P-zeta

# P-007 — synchronous publish op contends with training compute periodically
- from: R-025  # FS publish boundary blocking (M-011 hypothesis)
  to:   P-eta
- from: R-026  # periodic eval pass
  to:   P-eta
- from: R-027  # periodic distributed barrier (also P-alpha)
  to:   P-eta
- from: R-028  # GC/compaction side process
  to:   P-eta

# P-008 — process death doesn't propagate to ancestor visibility
#       (companion class to P-002 at orchestration layer)
- from: P-beta
  to:   P-theta
  relation: companion-class
- from: P-zeta
  to:   P-theta
  relation: companion-class
```

---

## Systemic cause → Defense (P→D) — the structural-ask layer

_This is the level where mitigations prevent ENTIRE CLASSES of future R-NNNs, not just specific instances. The structural ask the team should debate lives here._

```yaml
- from: P-alpha   # main-thread-blocked
  to:   D-005    # ot-timeout-monitor cron (detection layer)
  status: partial-coverage (catches symptom, not cause)
- from: P-alpha
  to:   D-alpha-thread-yield-discipline  # PROPOSED, unowned
  status: not_proposed_as_diff_yet

- from: P-beta    # worker-died-launcher-stuck
  to:   D-001    # external liveness probe (the structural fix)
  status: proposed (highest-leverage mitigation for this entire class)
- from: P-beta
  to:   D-002    # hard exit timeout
  status: proposed
- from: P-beta
  to:   D-003    # cgroup force-kill
  status: proposed
- from: P-beta
  to:   T265777384  # exit_w_cleanup fix (light.py only — partial coverage)
  status: NO_PROGRESS

- from: P-gamma   # static-config-exceeded
  to:   D-019    # per-config raise (per-instance)
  status: partial
- from: P-gamma
  to:   D-020    # auto-scaling (closes the class)
  status: proposed
- from: P-gamma
  to:   D-018    # corpus / capacity health monitoring (early-warning)
  status: proposed

- from: P-delta   # reland-without-guardrail
  to:   D-008    # post-revert reland-block CI gate
  status: proposed (closes the entire delta class)

- from: P-epsilon # detector-role-mismatch
  to:   D-epsilon-role-aware-detectors  # PROPOSED, unowned
  status: not_proposed_as_diff_yet
- from: P-epsilon
  to:   D-021    # archive-match suppression (symptomatic)
  status: proposed (workaround, not class-closing)

- from: P-zeta    # silent-orchestration-event
  to:   D-006    # ot-autostart-liveness cron (observability)
  status: not_started
- from: P-zeta
  to:   D-zeta-lifecycle-propagation-contract  # PROPOSED, unowned
  status: not_proposed_as_diff_yet

- from: P-eta     # periodic-sync-op-contends-with-training
  to:   D-001    # external liveness (progress-based, closes class)
  status: proposed
- from: P-eta
  to:   D-004    # ot-age-spike-monitor cron + dashboard (observability)
  status: not_started

- from: P-theta   # process-death-no-propagation (orchestration layer)
  to:   D-001    # external liveness covers companion to P-beta
  status: proposed
```

---

## Root Cause → Mitigation (R↔D, specific fixes)

```yaml
- from: R-002
  to:   T265777384    # exit_w_cleanup fix
  status: NO_PROGRESS as of 2026-05-20 morning brief

- from: R-003
  to:   D105401690    # forward fix for S665464 mixed-PG
  status: in_flight

- from: R-004
  to:   D105606893, D105652547    # new light_cli with NCCL handling
  status: in_flight

- from: R-005
  to:   D103808649, D103808619    # TCPStore binding fix
  status: landed (per S665454 thread reference)

- from: R-006
  to:   D-019    # raise bloom_index_b (T271094105)
  status: in_flight

- from: R-020
  to:   D105862249    # cover 14 remaining sites
  status: submitted, awaiting land

- from: R-029
  to:   D-conveyor-fix    # forward fix for S665902 ModuleNotFoundError
  status: in_flight
```

---

## Cross-mechanism interactions (compound failures)

Some incidents have compound mechanisms (M_A → M_B):

```yaml
# DPP starvation → ALLREDUCE rank desync → elastic agent zombie
- compound: [M-002, M-005, M-001]
  example: S661645 (DPP slow → barrier desync → 3h ALLREDUCE timeout → potential M-001 cascade if cleanup hangs)

# Trainer NaN cascade → MAST auto-restart → restart fails on conveyor regression (compound P56+P61, falsely identified by bot 2026-05-19)
- compound: [M-003, M-012]
  example: NONE confirmed — bot inferred this on m2134801434 but auditor falsified (model self-recovered before PAGE)

# Holdout data-cycle stall → freshness regression → serving cascade
- compound: [M-011, M-018]
  example: m2145336177 (25min/hr stalls — serving impact yet to manifest as SEV)
```

---

## Indices

**Quick keyword → S-NNN:**
- `example_age`, `client_lag`, `scribe_read_proxy` → S-001
- `FULL_SNAPSHOT missing`, `Publishing Stability` → S-002
- `qps falling`, `QPS to 0` → S-003
- `slow ramp`, `MB warmup` → S-004
- `StuckJobException`, `STUCK`, `manual kill` → S-005
- `mvai_metrics flat`, stale samples → S-006
- `[Invalid Detector - No Data]`, alert age >7d active → S-007
- `error rate elevated`, `tier 1 error rate` → S-008
- `cogwheel test`, `online_train_publish`, `publish_all`, `LoweringLogicException` → S-009

**Quick failure-mode name → M-NNN:**
- elastic agent zombie → M-001
- DPP starvation → M-002
- trainer NaN cascade → M-003
- OT auto-start silent stall → M-004
- ALLREDUCE rank desync → M-005
- snapshot transition / bad_sparse fallback → M-006
- downstream-infra reliability cascade → M-007
- cogwheel publish failure class → M-009
- MAST scheduling preemption → M-010
- holdout periodic data-cycle stall → M-011
- conveyor regression → M-012
- STUS kmeans corpus underflow → M-013
- STUS-normal-cadence misclassification → M-014
- bloom_index_b overflow → M-015
- detector misconfig → M-016
- detector no-auto-clear → M-017
- freshness regression cascade → M-018

---

## How to update edges

When a triage discovers a new evidence point for an existing S→M or M→R edge:
- Append the SEV/alert ID to the `evidence:` list
- Bump the weight by a small amount if recent + confirmed; reduce if disproven

When a triage falsifies an edge:
- Mark the edge `status: falsified` with date + counter-evidence
- Keep it in the file for historical record; remove from active triage flow

When a new edge surfaces:
- Add S/M/R/D entities if novel
- Add edge with initial weight (≤0.10 for first-instance evidence; ≤0.30 for second; up to ~0.50 for repeated)
- Add falsifier to distinguish from sibling edges in the same source

Weight semantics: rough probability the edge applies given the predecessor entity. Used for prioritizing triage flow (highest weight = check first).
