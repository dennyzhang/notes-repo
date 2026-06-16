# Systemic Causes (P-001 … P-NNN)

_The recurring **error-cause patterns** that explain WHY similar bugs keep appearing across different specific diffs. One layer deeper than `root-causes.md`._

## 📑 Index (8 entries)

| P-NNN | Shape | R-NNN instances | Heat | Landed mitigation? |
|---|---|---|---|---|
| **P-001** | Main thread blocked in heavy op → timeout-class race | R-004, R-014, R-024, R-027\* | 🔴 4–6/qtr | ❌ proposed (D-001/D-005) |
| **P-002** | Worker died, supervising launcher couldn't propagate exit cleanly | R-001, R-002, R-003, R-005 | 🔴 974+ GPU-hr | ❌ proposed (D-001/D-002/D-003) |
| **P-003** | Static config / threshold exceeded by organic growth | R-006, R-021, R-022 | 🟡 chronic | 🟡 per-instance (D-019); platform (D-020) proposed |
| **P-004** | Reland of reverted bug without test guardrail | R-003 (reland), R-020 | 🟡 recurring | ❌ proposed (D-008) |
| **P-005** | Detector built for role A used on role B | R-032, R-014 (FBLearner-role) | 🟡 chronic | 🟡 D-022 proposed |
| **P-006** | Lifecycle event silently caught by orchestration | R-013, R-014 | 🟡 1–2/qtr | ❌ no D-NNN yet |
| **P-007** | Sync publish op contends with training compute on fixed cycle | R-025\*, R-026\* | 🔴 live (M-011 hot) | ❌ only D-001 proposed |
| **P-008** | Process death doesn't propagate to ancestor visibility | shared w/ P-002 + P-006 | 🟡 companion class | ❌ shared D-001 proposed |

`*` = unverified hypothesis pending evidence. **Reading: 0 of 8 systemic causes have a landed structural mitigation.** See [`INDEX.md`](INDEX.md) for full P→D coverage gap discussion.

---

## Why this layer exists

Each R-NNN in `root-causes.md` is an **immediate bad change** — a specific diff, config value, or condition. But many R-NNNs share an underlying **error-cause pattern** — the same shape of bug recurring across different code paths. Identifying the systemic cause is what enables structural fixes that preempt the next R-NNN of the same class, rather than fixing one bug at a time.

Operator framing (thread `MQwOLaC3jLc` 2026-05-20):

> "Once a user gets a challenge, you need to identify the patterns beyond the immediate recourse."

Each P-NNN entry: what it explains → recurrence pattern → mitigation theme → why it's the systemic cause → R-NNN instances.

---

## P-001 — Main thread blocked in heavy operation → timeout-class race

**What it explains:** Any timeout where one rank/worker's main thread was tied up in a long synchronous operation (compile, large IO, large allocation) just long enough for a peer or watchdog to hit its timeout. The protocol/collective is not the bug; the application-control-flow blocking is.

**Recurrence pattern:** ~4-6 instances per quarter, spanning NCCL/Gloo/TGIF/ALLREDUCE/cogwheel — different specific protocols, same shape.

**Mitigation theme:** Enforce yield discipline in main-thread heavy ops. Async heartbeat from main thread. Restructure heavy op to yield periodically. Per-rank progress probe instead of single-rank watchdog.

**Why it's the systemic cause:** The immediate root causes (specific diffs, specific call sites) keep changing, but the "main-thread-blocked → peer-times-out" shape repeats. Fixing one site does not prevent the next site from manifesting the same shape.

**R-NNN instances:**
- R-004 (NCCL collective timeout — main thread in a heavy op missed the collective)
- R-024 (TGIF rendezvous timeout — same shape on TGIF protocol)
- R-014 (DPP-driven ALLREDUCE rank desync — DPP slowness blocks main thread)
- R-027 (periodic distributed barrier with slow rank — hypothetical M-011 mechanism)

**Linked mitigations:** D-005 (`ot-timeout-monitor` cron + timeout-aware bot rule covers detection); a proposed thread-yield-discipline mitigation (no D-NNN yet) (proposed but unowned — would address the cause)

---

## P-002 — Worker died, supervising launcher couldn't propagate exit cleanly

**What it explains:** A worker process dies (any mechanism) → its supervising launcher (PyTorch elastic agent, light.py, SJD) catches the death event → cleanup fails OR hangs OR propagation doesn't reach the orchestrator → orchestrator (MAST / SJD) sees launcher alive and reports RUNNING. Training stopped but system reports healthy.

**Recurrence pattern:** 5+ SEVs spanning Jan-May 2026 (S665478 NCCL, S665454 CUDA assert, S628346 light.py threading, S658165 TCPStore, S665464 mixed-PG barrier). 974+ GPU-hours of impact known. ~512 GPU-hr/mo waste estimate per CL-012.

**Mitigation theme:** Architectural elastic-agent zombie mitigation — hard exit timeout (D-002), cgroup force-kill of D-state (D-003), external progress-based liveness probe (D-001). All three structural; none currently in flight outside of T265777384 (which is NO_PROGRESS and only covers one sub-path).

**Why it's the systemic cause:** Each new Layer-1 trigger (NCCL, CUDA, mixed-PG, threading, TCPStore) reveals a fresh way to enter the zombie state. The Layer-2 mechanism is shared — the death-of-N-didn't-kill-N+1 shape — and is architecturally undefended.

**R-NNN instances:**
- R-001 (CUDA assert in worker subprocess)
- R-002 (`exit_w_cleanup` gap in light.py)
- R-003 (NCCL/Gloo mixed-PG barrier)
- R-004 (NCCL collective timeout)
- R-005 (TCPStore binding race)
- R-014 (D-state worker from kernel-blocked syscall)

**Linked mitigations:** D-001, D-002, D-003 (the structural three); T265777384 (partial, NO_PROGRESS)

---

## P-003 — Static config/threshold exceeded by organic growth

**What it explains:** Configuration with a hardcoded limit (capacity, threshold, ceiling) was chosen for current load; organic growth crosses the limit; system fails because the config wasn't dynamic.

**Recurrence pattern:** Recurring across multiple OT components — bloom_index, T2I corpus, Scribe capacity, ZippyDB CAS rate limits, Sandcastle host memory. ~1-2 instances/month visible.

**Mitigation theme:** Dynamic-sizing / capacity-elasticity discipline. No hardcoded limits in growth-bearing config. Where dynamic isn't feasible, alert on threshold-approach (e.g., bloom_index at 75% capacity → alert).

**Why it's the systemic cause:** Every static limit eventually meets organic growth. The specific config knob differs each time; the "we hardcoded N and N+ε happened" shape repeats.

**R-NNN instances:**
- R-006 (`bloom_index_b=2240` exceeded by feature cardinality)
- R-031 (T2I embedding corpus dropped below `n_min_embeddings_required=64077`)
- R-007 (Scribe overload — capacity wasn't elastic for traffic growth)
- R-008 (ZippyDB CAS throttle — rate limit hit by aggregate consumer growth)
- R-021 (Sandcastle I7_XLARGE OOM — host-memory budget vs build-size growth)

**Linked mitigations:** D-019 (per-config raise), D-020 (auto-scaling), D-018 (corpus health monitor) — all per-R but addressing the same pattern.

---

## P-004 — Reland of reverted bug without test guardrail

**What it explains:** A diff lands → introduces a bug → SEV → diff reverted as mitigation. Later, the same code re-lands (intentional or unintentional reland) → same bug surfaces. The revert prevented the immediate fire; the absence of a CI gate / test against the bug-pattern lets the code re-enter.

**Recurrence pattern:** 2 confirmed instances today (S665464 ↔ S656635 reland of D103046213; S666451 D105054082 incomplete refactor — 1 of 15 sites fixed). Likely under-counted because identifying a reland requires retrospective comparison.

**Mitigation theme:** Post-revert reland-block CI gate (D-008). When a diff is reverted with a SEV tag, future relands of the same code content fail CI without explicit acknowledgment.

**Why it's the systemic cause:** A revert is a mitigation, not a fix. Without a structural gate to prevent the bug-content from re-entering, the same bug returns whenever someone re-tries the change (or a different author makes the same shape of change).

**R-NNN instances:**
- R-003 (D103046213 mixed-PG barrier — reland of S656635-reverted code)
- R-020 (D105054082 incomplete-refactor — fixed 1 of 15 sites, 14 remain producing the same LoweringLogicException)

**Linked mitigations:** D-008 (proposed, unowned).

---

## P-005 — Detector built for role A used on role B (assumption mismatch)

**What it explains:** Detector was designed against one model role's behavior (trainer cadence, holdout cadence, prod cadence) but is configured to fire on a different role whose behavior pattern violates the original assumption. Result: chronic false positives.

**Recurrence pattern:** Multiple instances per month — FS-missing detectors firing on STUS models, holdout E2E latency thresholds tuned for prod, formula bugs that assume one timezone convention but apply to jobs in another.

**Mitigation theme:** Detector-role-awareness in the detector framework. Detectors should declare what role they target; configuration should reject mismatched applications. Or: detectors should query model role at fire-time and skip if mismatched.

**Why it's the systemic cause:** Each instance gets manually threshold-tuned or moved; the underlying "detector doesn't know what role it's looking at" gap remains. Next role mismatch is structurally inevitable.

**R-NNN instances:**
- R-032 (FS-missing detector threshold not STUS-aware → A1009946182010606 chronic fires on m2130324780)
- R-033 (general detector threshold misalignment class)
- D75703936-formula-bug (TZ skew — assumed UTC convention applied to PDT OT jobs)
- M-016 detector misconfig class

**Linked mitigations:** D-021 (archive-match suppression — symptomatic), D-022 (detector clear-cadence tuning — symptomatic); a proposed role-aware-detectors mitigation (no D-NNN yet) (proposed but unowned — addresses the pattern).

---

## P-006 — Lifecycle event silently caught by orchestration

**What it explains:** A process / workflow / job lifecycle event (manual expiration, parent-workflow-stopped, recurring-flow-disabled) is caught silently by the orchestration layer (MVAI, FBLearner, MAST) without surfacing to operator visibility. The job stops producing output; nobody knows until downstream notices.

**Recurrence pattern:** CL-009 — 3 instances in 4 weeks (Threads×2 + IG Reels×1). Multi-day silent quality drift per instance.

**Mitigation theme:** Unified lifecycle-event propagation contract. Any orchestration-layer event that affects production output must produce an observable signal (alert, ledger entry, OT-side ping).

**Why it's the systemic cause:** Each sub-class (MVAI expiration, FBLearner disabled, parent-stopped) has its own silent-catch path. The shape "lifecycle event caught without surfacing" is the cross-cutting concern.

**R-NNN instances:**
- R-013 (MVAI manual expiration silently passed)
- R-014a (FBLearner `is_enabled=false` early-return)
- R-014b (FBLearner `skip_recurring=True` early-return)
- R-014c (parent FBLearner workflow stopped → child MAST orphan-killed)

**Linked mitigations:** D-006 (`ot-autostart-liveness` cron — observability layer); a proposed lifecycle-propagation-contract mitigation (no D-NNN yet) (proposed but unowned — addresses the cause).

---

## P-007 — Synchronous publish operation contends with training compute on a fixed cycle

**What it explains:** A periodic synchronous operation (FS publish, eval pass, sync barrier, GC) takes a non-trivial wall-clock time and either holds a lock OR contends with training compute, producing a periodic train-stall window that's invisible to MAST liveness signals.

**Recurrence pattern:** Newly surfaced 2026-05-20 (m2145336177 — 25min/hr training stall while snapshot publishing on clockwork ~3min cadence). May be more widespread — 5 IG retrieval-family holdouts firing E2E latency alerts today potentially share this mechanism (M-011).

**Mitigation theme:** Progress-based liveness (not process-aliveness or snapshot-cadence). Dedicated train-progress dashboard. Decouple publish from training where possible.

**Why it's the systemic cause:** Snapshot publishing rate being clockwork led the bot (and the cron) to assume trainer health. The "snapshot output ≠ training progress" assumption invalidates a whole class of triage heuristics.

**R-NNN instances (hypotheses, all from m2145336177 case):**
- R-025 (FS publish boundary blocking training)
- R-026 (periodic eval/validation pass)
- R-027 (periodic distributed barrier with slow rank)
- R-028 (GC/compaction in side process)

**Linked mitigations:** D-001 (external liveness probe — progress-based) closes this class structurally; D-004 (`ot-age-spike-monitor` cron — observability).

---

## P-008 — Process death doesn't propagate to ancestor visibility

(Companion to P-002 at the orchestration layer instead of the launcher layer.)

**What it explains:** Death of a child process or workflow at level N doesn't propagate to level N+1's status reporting. Symptom: parent reports child healthy when child is dead.

**Recurrence pattern:** Overlaps with P-002 (worker → launcher) and P-006 (workflow → operator). The unifying shape across both is "ancestor's view of descendant lifecycle is stale or wrong."

**Mitigation theme:** Periodic lifecycle reconciliation between levels. Don't rely on event-propagation alone; reconcile periodically.

**Why it's the systemic cause:** Each layer (process → launcher, launcher → MAST, MAST → SJD, FBLearner → MAST) independently can drop a lifecycle event. The class is the dependency chain's "no defense-in-depth on lifecycle observability."

**R-NNN instances:** Shared with P-002 + P-006.

**Linked mitigations:** D-001 (progress-based liveness is one structural mitigation covering both P-002 and P-008).

---

## How systemic causes differ from CL-NNN

CL-NNN in `failure-patterns.md` are **operational cluster summaries** sorted by recent impact. P-NNN are **causal patterns underneath** the clusters.

A CL-NNN typically maps to:
- One symptom (S-NNN) — what the user/oncall sees
- One mechanism (M-NNN) or class of mechanisms — how the system breaks
- Multiple root causes (R-NNN) — the specific diffs / configs
- One or more systemic causes (P-NNN) — the recurring CAUSE class

Example: **CL-012 (StuckJobDetector coverage gaps)** is a **mitigation gap** cluster on the operational dashboard. Underneath it:
- Symptom: S-005 StuckJobException raised
- Mechanism: M-001 elastic agent zombie
- Root causes: R-001, R-002, R-003, R-004, R-005, R-014 (6 distinct immediate bad changes)
- Systemic cause: **P-002** (worker died, launcher couldn't propagate cleanly)
- Mitigation: D-001, D-002, D-003 (architectural; close P-002 class entirely)

The structural ask is at the **P-002** level — not at each R-NNN.

---

## How to add new systemic causes

When tonight's session reveals a new bug that maps to an existing P-NNN: add the R-NNN to the instances list. Don't create a new P-NNN.

When the bug's shape doesn't match any existing P-NNN: that's a new systemic cause. Add P-NNN with the same fields as above. Cross-reference in `_data/edges.md` with R→P edges. Consider whether the mitigation theme implies a new D-NNN.

When a P-NNN accumulates many R-NNN instances and no mitigation covers it: that's the structural ask the team should be debating. Surface in `IMPROVEMENT-PROPOSALS.md` as a leadership-level recommendation.
