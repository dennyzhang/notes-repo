# Patterns — Operator Entry Point

_Start here. This is the single-page hot-table + traversal map. Drill into entity files (`symptoms.md`, `failure-modes.md`, `root-causes.md`, `systemic-causes.md`, `mitigations.md`) only when you need the full record._

_Edge graph (machine-consumed) is in [`_data/edges.md`](_data/edges.md)._

---

## 🌐 Failure Landscape — bird's-eye view

The OT failure space groups into **8 R-families** (32 root causes consolidated) and **7 D-families** (25 mitigations consolidated). Drill into [`root-causes.md`](root-causes.md) / [`mitigations.md`](mitigations.md) for full records; this section is the at-a-glance map.

### Where bugs come from — R-families (32 → 8)

| # | R-family | R-NNN entries | Heat |
|---|---|---|---|
| 1 | **TRAINER_CRASH** (worker dies) | R-001, R-003, R-004, R-005, R-010, R-018, R-024 (7) | 🔴 |
| 2 | **LAUNCHER_CONTAINMENT** (death not propagated) | R-002 (1) | 🔴 chronic |
| 3 | **CAPACITY_EXCEEDED** (static / quota) | R-006, R-021, R-022 (3) | 🟡 |
| 4 | **DATA_STARVATION** (DPP / upstream) | R-007, R-008, R-009, R-012, R-015, R-017, R-031 (7) | 🔴 |
| 5 | **PUBLISH_BROKEN** | R-016, R-025\*, R-029 (3) | 🔴 live (S665902) |
| 6 | **FLOW_DISCIPLINE** (cogwheel / workflow) | R-013, R-014, R-019, R-020 (4) | 🟡 |
| 7 | **PERIODIC_STALL** (M-011 hypotheses) | R-026\*, R-027\*, R-028\* (3\*) | 🟡 unverified |
| 8 | **DETECTOR_BROKEN** | R-032, R-033, R-034, R-035 (4) | 🟡 noise |

`*` = unverified hypotheses pending evidence.

### Where fixes go — D-families (25 → 7)

| # | D-family | D-NNN entries | Landed? |
|---|---|---|---|
| 1 | **LIVENESS_PROBES** (detect zombies / stalls) | D-001, D-002, D-003, D-004, D-005, D-006, D-007 (7) | D-007 landed; rest proposed |
| 2 | **CI_GATE** (preempt reland regressions) | D-008, D-015 (2) | All proposed |
| 3 | **DEBUG_PROTOCOL** (playbooks) | D-009, D-010, D-011 (3) | Active |
| 4 | **INFRA_SLA** | D-012, D-013 (2) | Open |
| 5 | **CONFIG_VALIDATION** | D-016, D-017, D-018, D-019, D-020 (5) | Mixed |
| 6 | **DETECTOR_HYGIENE** | D-021, D-022 (2) | Proposed |
| 7 | **OPERATOR_DISCIPLINE** | D-023, D-024, D-025 (3) | Active in cron prompts |

### P → D coverage gap (the structural-debt picture in one glance)

| P-NNN (systemic cause) | Landed mitigation? | Notes |
|---|---|---|
| P-001 main-thread-blocked | ❌ proposed only (D-001, D-005) | Top recurring shape; no closure |
| P-002 launcher-no-propagate | ❌ proposed only (D-001 + D-002 + D-003) | 974 GPU-hr known impact, no mitigation landed |
| P-003 static-config-vs-growth | 🟡 per-instance fixes only (D-019); platform fix (D-020) proposed | |
| P-004 reland-w/o-guardrail | ❌ proposed only (D-008) | |
| P-005 detector-role-mismatch | 🟡 D-022 proposed | |
| P-006 silent-orchestration-event | ❌ no D-NNN yet | |
| P-007 sync-publish-vs-training-periodic | ❌ only D-001 proposed | 4 cells hot in `inventory/heatmap.md` |
| P-008 process-death-no-ancestor | ❌ shared with P-002, none landed | |

**Reading: 0 of 8 systemic causes have a landed structural mitigation.** Every P-NNN is either uncovered or only proposed. This is the structural-debt headline; everything else is tactical.

### R-family × D-family coverage matrix (which mitigations help which bug-source)

| R-family ↓ / D-family → | LIVENESS | CI_GATE | DEBUG_PROTO | INFRA_SLA | CONFIG_VAL | DETECTOR_HYG | OP_DISC |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **TRAINER_CRASH** | ●●● | ○ (R-003 reland) | ○ (R-010 NaN) | | | | |
| **LAUNCHER_CONTAINMENT** | ●●● | | | | | | |
| **CAPACITY_EXCEEDED** | | | | ○ | ●● | | |
| **DATA_STARVATION** | ○ (detect only) | | | ●● | ● (corpus) | | |
| **PUBLISH_BROKEN** | ● (catches stall) | | ○ (conveyor) | | | | |
| **FLOW_DISCIPLINE** | | ●● | | | | | ○ |
| **PERIODIC_STALL\*** | ● (D-001) | | | | | | |
| **DETECTOR_BROKEN** | | | | | | ●● | ○ |

**Legend:** ●●● = primary coverage by multiple D-NNNs in this family · ●● = primary coverage · ● = partial / single-D · ○ = tangential / edge-case only · blank = no mitigation in this family addresses this R-family.

**Reading the matrix:** 
- **LIVENESS_PROBES is the highest-leverage D-family** — covers 5 of 8 R-families (TRAINER_CRASH, LAUNCHER_CONTAINMENT, PUBLISH_BROKEN, PERIODIC_STALL, partial DATA_STARVATION). But all but D-007 are proposed-only.
- **DATA_STARVATION has no in-OT mitigation** — only INFRA_SLA conversations + CONFIG_VALIDATION at the edges. Most of the cost lives upstream.
- **FLOW_DISCIPLINE empty in LIVENESS column** is correct — these are cogwheel/workflow issues, not training-runtime issues. CI_GATE is the right channel.
- **Blank row would mean an R-family with no mitigation coverage** — there are none, but TRAINER_CRASH being mostly-proposed-LIVENESS is the next-worst position.

---

## 🔥 Top 5 hot symptoms (open as of 2026-05-20)

| Rank | Symptom | First-check | Most likely failure mode | Heat |
|---|---|---|---|---|
| 1 | **S-001** Training example-age spike | `meta ai.mast-job system-metrics` for DPP-starvation %; check active ZippyDB/Scribe SEVs | M-007 downstream-infra cascade or M-011 holdout periodic stall | 🔴 chronic (CL-013, 4 fires/4wk) |
| 2 | **S-002** Snapshot stuck CREATING / FS missing | `meta ai.model.instance list` for cadence; check open conveyor SEV; check STUS-role + corpus | M-012 conveyor regression / M-013 STUS kmeans / M-001 zombie | 🔴 live (S665902 in-progress) |
| 3 | **S-010** NCCL / distributed collective timeout | grep trainer log for `Watchdog caught collective operation timeout`; `meta ai.mast-job error` for AITO class | M-005 ALLREDUCE desync → M-001 zombie cascade | 🔴 4–6/qtr (P-001) |
| 4 | **S-005** StuckJobException raised | `meta ai.mast-job query-error-context` — look for AITO_NOT_APPLICABLE + KILLED_BY_USER (dispositive M-001 signature) | M-001 elastic agent zombie | 🔴 chronic (CL-012, 974 GPU-hr) |
| 5 | **S-007** Detector self-reports invalid / stale-fires | Check alert title for `[Invalid Detector - No Data]` prefix; check model publishing healthy; check fire count | M-016 detector misconfig / M-017 no-auto-clear | 🟡 noise (CL-018) |

_Heat ranking is a working estimate from 2026-05-19/20 session findings. Replace with `_data/hot-counts.yaml`-driven values once Proposal H lands._

---

## 🛣️ Three most-traveled triage paths

### Path 1: FS missing on STUS-role model
```
S-002 (FS missing)
  → check STUS role (R14) + active conveyor SEV
  → if CONVEYOR_REGRESSION SEV active + trainer RUNNING + fresh metrics
    → M-012 conveyor regression
      → P-005 detector-built-for-role-A-used-on-role-B (sub-class)
        → D-006 STUS-aware FS-missing detector (proposed)
  → else if STUS kmeans AssertionError in trainer log + upstream T2I corpus below min
    → M-013 STUS kmeans corpus underflow
      → R-013 upstream T2I corpus regression
        → escalate to corpus owner (e.g. ronghuang)
  → else if elastic agent zombie signature (M-001)
    → see Path 2
```

### Path 2: Training stopped but MAST says RUNNING (M-001 cascade)
```
S-003 (QPS=0) OR S-005 (StuckJobException) OR S-006 (mvai_metrics flatline)
  → `meta ai.mast-job query-error-context` returns AITO_NOT_APPLICABLE + KILLED_BY_USER
  → M-001 elastic agent zombie (CONFIRMED by absent AITO class)
    → identify trigger:
      ├── S-010 NCCL timeout → R-004 collective timeout (P-001 main-thread blocked)
      ├── S-011 TCPStore bind() failed → R-005 binding race (P-002 worker death no propagation)
      ├── CUDA assert in log → R-001 allocator assert
      └── unknown → R-002 exit_w_cleanup gap
    → P-002 (worker died, launcher couldn't propagate cleanly)
      → D-001 external liveness probe (proposed)
      → D-002 hard exit timeout (proposed)
      → D-003 cgroup force-kill (proposed)
```

### Path 3: Example-age spike, model otherwise healthy
```
S-001 (example_age spike)
  → check active SEVs (ZippyDB / Scribe / Koski / DPP)
  → if active OR recently-mitigated infra SEV (<48h window)
    → M-007 downstream-infra reliability cascade (TRANSIENT_NOISE if mitigated)
      → CL-003 residual-recovery sub-pattern
      → NO OT ACTION
  → else if DPP Data Starvation % >10% sustained
    → M-002 DPP starvation
      → R-007/R-008/R-009 (Scribe/ZippyDB/DPP-config)
  → else if periodic stall (25 min/hr, etc.) + SM utilization p50 <5%
    → M-011 holdout periodic data-cycle stall
      → P-007 sync-publish-op-vs-training-fixed-cycle
        → D-001 progress-based watchdog (proposed)
```

---

## 🗺️ Entity files cross-link

| Layer | File | Count | First entry | Last update |
|---|---|---|---|---|
| **S** symptoms (what we see) | [`symptoms.md`](symptoms.md) | 11 | S-001 example-age spike | 2026-05-20 (S-010, S-011 added) |
| **M** failure modes (how it's broken now) | [`failure-modes.md`](failure-modes.md) | 17 | M-001 elastic agent zombie | 2026-05-20 |
| **R** root causes (specific bad change) | [`root-causes.md`](root-causes.md) | 32 | R-001 CUDA allocator assert | 2026-05-20 |
| **P** systemic causes (recurring shape) | [`systemic-causes.md`](systemic-causes.md) | 8 | P-001 main-thread-blocked | 2026-05-20 (renumbered from Greek) |
| **D** mitigations | [`mitigations.md`](mitigations.md) | 25 | D-001 external liveness probe | 2026-05-20 |
| **edges** (S↔M↔R↔P↔D) | [`_data/edges.md`](_data/edges.md) | — | machine-consumed | 2026-05-20 |

---

## How to use this file

- **You see a new alert**: scan the hot table → if symptom matches, follow first-check; if it doesn't match any of the 5, jump to `symptoms.md` keyword index.
- **You want to know the structural ask** (not "fix this bug" but "fix this class of bug"): traverse to P-NNN in `systemic-causes.md` and check its mitigation theme.
- **You're writing a new triage and need to cite the graph**: cite by entity ID (e.g., `S-010 → M-005 → P-001`), not by long-form description.
- **You learned something new**: add to the right entity file + update edges + update this hot table if it's now top-5.

---

## Adding new entries

1. **Symptom** is novel → add S-NNN with: alert pattern, metric pattern, typical observable, first-instance evidence
2. **Failure Mode** is novel → add M-NNN with: causal description, falsifier, evidence list
3. **Root cause** is novel → add R-NNN with: specific bug name, error string, file:line if known, fix-in-flight diff if any
4. **Systemic cause** is novel → add P-NNN with: recurring error-cause pattern underneath R-NNNs
5. **Mitigation** is novel → add D-NNN with: failure-mode/root-cause it addresses, status, owner, cost estimate
6. Update `_data/edges.md` with the new entity's connections

Cite SEV/alert evidence, date-stamp, and the thread/session where the learning surfaced.

## Reverse traversal (R → S for spreading-detection)

When a new SEV pins down R-NNN: query R→M→S edges to identify other symptoms the same root cause produces. Proactively check those signals across fleet. Closes the "20-58 jobs/day affected, each oncall only sees 1-2" class of blind spot.

## Migration status

- Phase 1: existing CL-NNN entries categorized in `failure-patterns.md` headers
- Phase 2: top-tier S/M/R/D entities populated from 2026-05-19/20 session findings
- Phase 3 (in progress): full edge graph in `_data/edges.md` — weights need population from historical data
- Phase 4 (planned): rewrite ot-alert-monitor + ot-sev-monitor cron prompts to traverse S→M→R→D explicitly
