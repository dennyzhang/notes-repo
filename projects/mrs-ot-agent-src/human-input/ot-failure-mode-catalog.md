# OT Failure-Mode Catalog

Consolidated reference for triaging Online Training (OT) failures.
Source: 2026-05-13 gchat thread `tiooNt5H7zU` (Denny + bot iteration); STUS-vs-in-trainer publish path distinction sourced from S660220 (ZippyDB SEV1, 2026-05-06).
Cross-references: `known_patterns.md` (P01–P50), `learnings.md` (L1–L9).

**Maintainer note:** when adding a new failure class, also propose a P-ID for `known_patterns.md`. When adding a new disambiguator probe, append it to `ot-sev-monitor` / `ot-alert-monitor` Step i.

---

## Two foundational concepts

### GIL hang (Python Global Interpreter Lock)

CPython runs only ONE Python instruction at a time per process — controlled by the GIL (process-wide mutex). Any thread executing Python bytecode must `take_gil()` first.

A **GIL hang** = one Python thread acquires the GIL and never releases it. Common causes:
- Pure-Python infinite loop (no syscall = no GIL release)
- C extension that forgets to release the GIL during long-running CPU work
- Snapshot save/load on rank 0, logging, checkpoint metadata, slow Python iterator
- Deadlock between Python `threading.Lock` + GIL acquisition order

**Symptoms in OT:**
- Process is `RUNNING` per OS / MAST (not crashed)
- All other Python threads silently blocked on `take_gil`
- No exception, no traceback, NCCL watchdog quiet
- Python-side instrumentation (mvai_metrics, fb303 heartbeats) **stops emitting**
- Training step loop frozen → DPP reader QPS ~0 → no checkpoint → no snapshot

**Diagnosis:** `py-spy dump --pid <trainer_pid>` on rank 0 host. Main thread in CPU code (no syscall), other threads in `take_gil`.
**Fix:** `kill -9` + restart. Long-term: identify the C extension or Python loop holding the GIL.

### NCCL timeout

NCCL = NVIDIA's GPU collective communication library (all_reduce, all_gather, broadcast, etc.). Every GPU rank must enter the same collective in the same order, or some ranks block waiting for absent peers.

NCCL has a **watchdog** with a default ~600–720 second timeout. When triggered it:
1. Kills the rank with `WorkNCCL.checkTimeout` exception
2. Emits stack trace: `[Rank N] Watchdog caught collective operation timeout: WorkNCCL(SeqNum=…, OpType=ALLGATHER, Timeout(ms)=…)`
3. MAST attempt FAILs, then auto-restarts

**Why it matters for triage:** If a hang lasts >12 minutes and NCCL hasn't tripped → the hang is **not** in a collective. It's somewhere else (GIL, syscall, hardware).

### GIL hang vs NCCL timeout — quick distinction

| | **GIL hang** | **NCCL timeout** |
|---|---|---|
| Where | CPU-side Python (one rank holds GIL, others wait) | GPU collective (allreduce/allgather/broadcast) |
| Symptom | All ranks stuck in Python frames; no NCCL error; watchdog quiet | `Watchdog caught collective operation timeout` after ~10/30 min |
| Evidence | `py-spy dump` shows threads on GIL or `acquire()`; flight recorder shows no in-flight collective | NCCL flight recorder shows hung op; mismatched ranks; `ncclInternalError` / `Timeout` in stderr |
| Common cause | Snapshot save/load on rank 0, logging, checkpoint metadata, slow Python iterator | Straggler rank, network blip, OOM-killed peer, mismatched collective ordering |

---

## Failure-mode taxonomy

### Tier 1 — Symptoms (what alerts/SEVs report)

| Symptom | Threshold | Lane |
|---|---|---|
| **Training example age (TEA)** | <5min good · 30min–1hr degraded · >2h losing data | freshness/SLO |
| **Snapshot publishing stalled** | gap > 1.5× cycle | publishing |
| **Training QPS dip / low** | <50% baseline | throughput |
| **Cold-start slow** | first batch >30min after launch (healthy <30min, problem >2h) | bootstrap |
| **Job FAILED → restart loop** | >3 attempts in 12h | scheduling |

### Tier 2 — Failure classes (root mechanism)

#### A. Job hangs (process alive, no progress)

| Class | Mechanism | NCCL trips? | Disambiguator | P-ID |
|---|---|---|---|---|
| **A1. GIL hang** | Python thread holds GIL forever (snapshot save/load, logging, checkpoint metadata, slow iterator) | ❌ no (CPU-only) | py-spy: main thread in CPU code, others in `take_gil` | proposed P44 |
| **A2. C++ extension deadlock** | libtorch/internal mutex deadlock, GIL not involved | ❌ no | py-spy: main thread in libtorch C++ frame, no GIL contention | proposed P45 |
| **A3. Storage syscall stall** | manifold/NFS write blocks indefinitely | ❌ no | OS process state `D`, blocked on `pwrite` / `mmap` | proposed P46 |
| **A4. Hardware stall** | NIC reset, GPU dead, memory ECC | ❌ no (initially) | dmesg / nvidia-smi shows hw fault | **P41** (cudaErrorDevicesUnavailable variant) |
| **A5. Cross-process-group deadlock** | Two PGs serialized in opposite order across ranks | ❌ no (each PG individually progresses) | per-rank PG state diverges; py-spy across ranks shows different collectives | proposed P47 |
| **A6. Blocking RPC without timeout** | Trainer Python main thread blocked on a network RPC: UMM `CreateSnapshot`, Manifold write, TGIF service, Hedwig publish. GIL is FREE (released during socket wait); other Python threads CAN run, but the iteration thread is wedged. | ❌ no (no collective in flight) | py-spy: main thread in `concurrent.futures.Future.result` / `socket.recv` / `_ssl.read`; `/proc/<pid>/status` State `S` not `D`; ZERO new UMM `model.instance` records (any state) since hang onset = strong indicator publish RPC hung before reaching UMM | proposed P48 (sourced 2026-05-13 model 2135033479) |
| **A7. asyncio event-loop deadlock** | Event loop stalled by unresolved `Future`, missing `await`, or coroutine awaiting itself. Loop thread alive but processes no tasks. | ❌ no | py-spy: main thread in `asyncio.base_events._run` / `_run_once` / selector `select.select`; precondition: trainer/publish path uses asyncio (`grep -r 'asyncio'` in model dir) | proposed P49 |

#### B. Collective hangs (one or more ranks fail to enter)

| Class | Mechanism | NCCL trips? | Disambiguator | P-ID |
|---|---|---|---|---|
| **B1. NCCL collective timeout** | Rank drops/network partition → others wait until 12-min watchdog | ✅ yes | `[Rank N] Watchdog caught collective` in error log | umbrella |
| **B2. NCCL hardware fault** | GPU dead before collective entry → `set_device` fails | ❌ direct error | `cudaErrorDevicesUnavailable` at `set_device` (not post-collective) | **P41** |
| **B3. Collective in metrics predicate → gloo desync** | `dist.all_reduce` in `should_compute()` runs only on subset of ranks → DCP gather_object hangs → gloo TCP timeout | partially | `CheckpointingException` + `gloo/transport/tcp/pair.cc Connection closed by peer` + check trainer build for D104469704 | **P43** |

#### C. Training scheduling problems

| Class | Mechanism | P-ID |
|---|---|---|
| **C1. Boxcar planned-maintenance preemption** | OpsPlanner Boxcar host event → `Task was stopped and deallocated: Host Unavailability Event: plannedMaintenance` → MAST auto-restarts | **P38** |
| **C2. SJD auto-restart fails** | `single_job_definition` restart hook misfires; job sits dead instead of restarting | proposed P48 |
| **C3. TMS auto-restart issue** | TMS host-exclusion config drift; same bad host re-assigned → loop. Or stuck in EXPIRED | adjacent to **P41** |
| **C4. Linux signal handling bug** | SIGTERM handler in trainer races with checkpoint write → corrupted checkpoint, zombie children, SIGTERM not propagating | proposed P49 |
| **C5. Slow debug-stuck-job loop** | Stuck job not surfaced for hours; only caught via daily scan | (process gap, not pattern) |

#### D. Snapshot publishing & loading

| Class | Mechanism | P-ID |
|---|---|---|
| **D1. fbpkg expired (publisher)** | publisher fbpkg version dropped/expired | **P17** |
| **D2. Stale prod-tag size failure** | publish job rejects size delta vs prod-tag | **P37** |
| **D3. light_cli version cap** | `fbpkg config max-versions=N` → N/N reached, blocks new versions | **P41** |
| **D4. AOTI Triton LLVM bump** | LLVM API removal breaks AOTI lowering across model families | **P42** |
| **D5. AI Codemod bad return annotation** | string-based type resolution (schema_utils) fails | **P40** |
| **D6. TGIF external_weights write failure** | TGIF publisher errors on external_weights/context paths | (under S658492 active investigation) |
| **D7. FS-publish stuck CREATING (consequence-of-A)** | trainer hung mid-FS-publish → snapshot stays CREATING; deltas block behind it | **NOT a root cause** — symptom of A1–A4 |
| **D8. Recurring-flow disabled** | publish/training recurring flow set `is_enabled=false` by operator | falsified by R15 check |
| **D9. Full snapshot stuck in UMM** | UMM publish stage hangs; partial publish; missing shards | (no P-ID) |
| **D10. Performance: publish latency high / load slow at startup** | (no P-ID) |
| **D11. Upstream infra dependency blocks STUS publish** | STUS-only; in-trainer unaffected. See **P50** in `known_patterns.md` for full mechanism and verification chain. | **P50** |

#### E. Performance / QPS

| Class | Mechanism | P-ID |
|---|---|---|
| **E1. Trainer-side QPS dip** | trainer compute slow (model architecture change, kernel regression, OOM near-miss); per-GPU TFLOPS / SM occupancy low | (no P-ID; case-by-case) |
| **E2. DPP-side QPS dip (starvation)** | DPP workers can't supply examples fast enough → trainer waits | (no P-ID) |
| **E3. Reader QPS ~0 as CONSEQUENCE of trainer hang** | trainer not consuming → DPP reader QPS drops as reflection | **NOT a root cause** — symptom of A-class |
| **E4. Slow QPS ramp-up after launch** | new job cold-starts slowly (cache warmup, AOTI compile, model loading) | adjacent to S662798 |
| **E5. New launches: prefer infra optimization** | bf16, qcomm, pipeline, sharding before adding capacity | (rule, not pattern) |

#### F. Cold start

| Class | Mechanism | P-ID |
|---|---|---|
| **F1. First-batch >30min** | DPP not pre-warmed, AOTI compile, sparse param init slow, fbpkg fetch, capacity wait, warmup compile (PT2) | (no P-ID) |
| **F2. Bootstrap artifact** (alert fires within 1 SLO window of restart) | new attempt comes up, alarm fires before first publish lands; auto-clears | rule, not pattern (in `ot-alert-monitor` Step i-b) |

---

## Cause-vs-consequence map (the trap)

When **A1–A5 (job hang)** happens, the visible symptoms are usually:
- **D7** (snapshots stuck CREATING)
- **E3** (DPP reader QPS ~0)
- **Tier-1 freshness symptoms** (example age growing)

It's tempting to triage at the symptom layer. **The consequence-layer evidence (D7+E3) does NOT disambiguate A from D-or-E-root.** The disambiguator is *upstream-of-symptom evidence*: mvai_metrics sample emission rate, checkpoint write cadence, fb303 heartbeat.

**Triage rule:** when D7+E3 fire together, FIRST check trainer process liveness signals (mvai_metrics, checkpoint cadence, fb303 heartbeat). If those are zero → the root is in A, not D or E. Don't waste cycles on TGIF/DPP/publish-pipeline investigation until trainer liveness is confirmed.

---

## Smoking-gun rules of thumb

| Symptom combo | Likely root | Action |
|---|---|---|
| TEA spike + full snapshot stuck + QPS≈0 | publishing pipeline (UMM/Hedwig) — only IF trainer liveness OK | Check FS state CREATING vs failed; check UMM logs |
| QPS≈0 + flight recorder shows in-flight collective | NCCL / straggler | Check rank flight recorder, identify slowest rank |
| QPS≈0 + flight recorder clean + py-spy on GIL | **CPU/Python hang (A1)** | Force-restart; capture py-spy for postmortem |
| QPS≈0 + flight recorder clean + py-spy in `Future.result` / `socket.recv` | **Blocking RPC without timeout (A6)** | Force-restart; capture which RPC target was hung |
| QPS≈0 + flight recorder clean + py-spy in `asyncio.*` frames | **asyncio event-loop deadlock (A7)** | Force-restart; dump pending task list for postmortem |
| **Pipeline QPS non-zero + Training QPS = 0** | **Trainer-internal stall (A-class)**, NOT Scribe / DPP | Run trainer-liveness probe; do NOT chase upstream-data hypotheses. See § Pipeline vs Training QPS divergence |
| QPS≈0 + restart loops in TMS | scheduling/SJD, not training code | Check TMS host-exclusion + SJD restart hook |
| QPS≈0 + checkpoints continue + FS stuck CREATING | UMM publish — actually trainer hang if checkpoints ALSO stop | Verify checkpoint cadence first; if also stops → A-class |
| Multi-alert: 2+ models with same symptom in same window | Cross-check before concluding "shared infra" | See § Multi-alert cross-check |
| Autoresponder suggests action with snapshot/version-specific arg | Verify the named entity exists FIRST | See § Autoresponder verification rule |

---

## Disambiguator probes (canonical command list)

### Trainer liveness — "is the trainer alive RIGHT NOW?"

**Method 1: mvai_metrics Scuba (Python instrumentation freshness)**
```bash
meta scuba.dataset query -d mvai_metrics --view=samples \
  --columns=time -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' \
  --hours=12 -l 1 --order-by=time
```
- Latest sample timestamp = last moment trainer Python emitted instrumentation.
- If gap > expected cadence (~1min) → trainer Python is hung.

**Method 2: Sample-volume timeline (tells you WHEN it started)**
```bash
meta scuba.dataset query -d mvai_metrics -a count \
  -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' \
  --hours=12 --time-bucket="30 minutes"
```
- Sharp drop to 0 in a bucket → hang started in that window.

**Method 3: Checkpoint cadence**
```bash
meta ai.model.instance list --model-id=<MODEL_ID> --instance-type=CHECKPOINT \
  --limit=10 --sort-by=creation_time --sort-order=desc \
  --columns=checkpoint_version,creation_time,state -o table
```
- Hourly trainer checkpoint cadence is healthy. Gap > 1.5× cadence → trainer not progressing.

### Snapshot publish state

```bash
# Last published snapshots (VALID state)
meta ai.model.instance list --model-id=<MODEL_ID> --limit=10 --sort-by=creation_time --sort-order=desc \
  --columns=instance_id,creation_time,snapshot_type,state,size -o table

# In-flight (CREATING) snapshots — note: --state filter is buggy; pull JSON and filter
meta ai.model.instance list --model-id=<MODEL_ID> --state=CREATING --limit=20 -o json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); [print(x['creation_time'], x.get('snapshot_type'), x['state']) for x in d if x['state']=='CREATING']"
```

### Trainer / collective state

```bash
# Attempt history (look for restart loops, attempt durations)
meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID>

# Last failure reason (verbatim)
meta ai.mast-job error --name=mvai-training-online-<MODEL_ID> --attempt=<N> --no-truncate

# JOB_INSPECTOR insights (catches GIL hangs eventually; 0 doesn't mean healthy if hang is fresh)
meta ai.mast-job insights --name=mvai-training-online-<MODEL_ID> --version=<V> --attempt=<N> -o json

# Aggregate system metrics (whole-attempt averages — coarse but shows trainer QPS, GPU util)
meta ai.mast-job system-metrics --name=mvai-training-online-<MODEL_ID> --version=<V> --attempt=<N>

# Source-failure context (Boxcar, AITO)
meta ai.mast-job query-error-context --name=mvai-training-online-<MODEL_ID> --attempt=<N>
```

### Build / diff provenance — "does this trainer contain diff X?"

```bash
# Pull build timestamp from any console / checkpoint_agent log
meta ai.mast-job logs --name=mvai-training-online-<MODEL_ID> --version=<V> --attempt=<N> \
  --file-path=dedicated_log_CheckpointAgentService_0_<TIMESTAMP> | grep -A5 "Build Information"
# Compare 'Built on' / 'Build Revision Timestamp' to D<N> land time
```

### R14 / R15 mandatory checks

```bash
# R14 — if title says "<X>_test" or unfamiliar job name: confirm it's a real MAST job
meta ai.mast-job describe --name=<JOB_NAME>   # or 404 → it's a publish-pipeline step, not trainer

# R15 — recurring flow enabled
meta ai.model-series metadata --model-id=<MODEL_ID> -o json | grep owner_unixname
meta ai.recurring-job recurring-flows --owner=<OWNER> --no-truncate | grep <FLOW_KEYWORD>
# Check is_enabled=true
```

### Live process inspection (requires shell on trainer host)

```bash
# Path 1: MLHub UI button
# https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-<MODEL_ID>?job_attempt=<N>&version=<V>&tab=summary
# → "Capture stack trace" / "Strobelight CPU profile"

# Path 2: SSH to rank-0 host (find via meta ai.mast-job attempts → cluster + task ID)
sudo py-spy dump --pid $(pgrep -f trainer)
# Main thread in `take_gil` → A1 (GIL hang)
# Main thread in libtorch C++ frame, no GIL contention → A2 (C++ deadlock)
# Main thread blocked on pwrite/mmap → A3 (storage syscall)
# Process state D (uninterruptible sleep) > 30s → A3 or A4

# Path 3: NCCL flight recorder dump (rank 0 logs)
meta ai.mast-job logs --name=mvai-training-online-<MODEL_ID> --version=<V> --attempt=<N> \
  --file-path=dedicated_log_CheckpointAgentService_0_<TIMESTAMP> | \
  grep -E "(SeqNum|in-flight|Watchdog)"
```

---

## Pipeline vs Training QPS divergence

Two independent QPS signals on the OT data path. **Treating them as one signal is a common autoresponder failure mode.**

```
Scribe stream  →  DPP workers  →  trainer
                  └── Pipeline QPS ──┘  └── Training QPS ──┘
                  (Scribe→DPP rate)     (trainer iter rate)
```

| Pipeline QPS | Training QPS | Interpretation |
|---|---|---|
| 0 | 0 | **Upstream starvation** — Scribe dry, DPP idle, trainer idle in lockstep. Falsifier: `lg mast:<JOB> -p "token queue size"` returns `0` confirms Scribe dry. |
| non-zero | 0 | **Trainer-internal stall (A-class)** — DPP is producing batches but trainer is not consuming. The Scribe-starvation hypothesis is ruled out by the Pipeline-QPS-non-zero signal alone. **Run trainer-liveness probe (Method 1 above).** |
| non-zero | non-zero but degraded | **Trainer-side throughput regression (E1)** — trainer running but slow. Per-rank trace + critical path analysis. |
| 0 | non-zero (briefly) then 0 | **DPP regression** — Scribe→DPP path broke; trainer drained its existing batch queue then stalled. Look at P12 (DPP bad release) / P30 (DPP pkg version change). |

**Rule:** when a downstream symptom (slow snapshot, FS stuck) co-presents with low DPP reader QPS, ALWAYS check the Pipeline QPS vs Training QPS divergence BEFORE accepting "Scribe data starvation" as a candidate. If Pipeline QPS is non-zero, the Scribe hypothesis is dead-on-arrival regardless of how plausible it sounds in the runbook.

Source: 2026-05-13 thread `tiooNt5H7zU` model 2135033479 — autoresponder suggested Scribe starvation at 50% confidence; Pipeline-vs-Training divergence falsified it in one dashboard glance.

## OT job info cache (clearing it does NOT fix runtime hangs)

The "OT job info cache" referenced in autoresponder runbooks is a per-model JSON file in **Manifold**:

```
manifold://deep_retrieval/tree/jobs/mvai-training-online-<MODEL_ID>/info.json
```

Implementation: `fbcode/minimal_viable_ai/utils/online_training_utils/online_training_mgmt.py:1082` (`job_info()`) and the agent-facing wrapper `fbcode/minimal_viable_ai/agent/assistant/functions/online_training.py:156` (`clear_online_training_job_info_cache()`).

**What it stores:** per-model state used by orchestration tooling on session boundaries (TMS auto-restart, `mvai online-training-mgr`, MLHub). Known field: `retryable_job_checkpoint_version` — which checkpoint version TMS resumes from on auto-restart. `-1` = "use the most recent valid one" (`reset_job_info_cache_checkpoint_version()` line 1115).

**What "clearing" does:** literally deletes the JSON file (`client.sync_rm(file_path)`). Next access by orchestration tooling forces re-discovery from authoritative sources (UMM, MAST metadata).

**Why clearing is NOT a fix for in-trainer hangs (A1–A7):**
- The cache is read by orchestration components on **session boundaries** (job submit, restart, registration). It is NOT consulted by the running trainer process during normal iteration or during the in-process publish path.
- A hung trainer mid-attempt won't read the cache; clearing it won't move that process forward.
- The cache only matters for the NEXT restart (and even then, only for `retryable_job_checkpoint_version` selection).
- Verdict: cheap and harmless to clear, but **does not unblock a running A-class hang**. Including it in a runbook as a recovery step for stuck-mid-attempt cases is a reasoning bug.

## Mitigation runbook for in-trainer hang (A-class)

When the trainer-liveness probe (Method 1) confirms an A-class hang and the diagnosis class (A1/A2/A3/A6/A7) is identified or reasonably narrowed, kill + TMS auto-restart is the standard mitigation. Structured form:

### Step 0 — Pre-flight (verify TMS will auto-restart)

```bash
mvai online-training-mgr print -m <MODEL_ID> | grep -E "state|is_blocklisted"
```

Expect: `state=ONLINE_READY`, `is_tms_blocklisted=false`. If `state=EXPIRED` → P17 (fbpkg expired), different fix path. If blocklisted → TMS won't restart, escalate before killing.

### Step 1 — Dry-run preview (safe, no mutation)

```bash
meta ai.mast-job kill --job-name=mvai-training-online-<MODEL_ID>
```

Without `--confirm`, prints a preview only. Verify it targets the right version/attempt and is in a killable state.

### Step 2 — Capture forensics BEFORE killing (irreversible)

The trainer logs from the hung attempt are the only evidence we'll have for postmortem class-disambiguation. Once killed, attempt logs degrade in accessibility over time.

```bash
# Capture py-spy / Strobelight CPU profile via MLHub UI button while process is alive:
# https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-<MODEL_ID>?job_attempt=<N>&version=<V>&tab=summary
# → "Capture stack trace" / "Strobelight CPU profile"

# Capture the gmpp publish log tail
meta ai.mast-job logs \
  --name=mvai-training-online-<MODEL_ID> \
  --version=<V> --attempt=<N> \
  --file-path="dedicated_log_gmpp_in_trainer_publish.mvai-training-online-<MODEL_ID>.trainer.job_version=<V>.job_attempt=<N>.log" \
  --tail=200 > /tmp/<MODEL_ID>_v<V>a<N>_publish_tail.txt
```

Without forensics, the next firing on a different model has zero new information to work from.

### Step 3 — Execute the kill

```bash
meta ai.mast-job kill \
  --job-name=mvai-training-online-<MODEL_ID> \
  --expected-version=<V> \
  --confirm \
  --reason="restart stuck in-trainer publish path; class A<N> per liveness probe at <TIMESTAMP>"
```

`--expected-version=<V>` pins the kill to the audited version; refuses if a TMS-side restart already raised the version while you were typing. `--reason` lands in the audit trail.

### Step 4 — Confirm TMS auto-restart fires (~30-60 seconds)

```bash
meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID> --version=<V> -o json | \
  jq -r '.[] | "\(.attempt) \(.status) \(.start_time)"'
```

Expect prior attempt → FAILED, new attempt → STARTING/RUNNING. If after 2 min there's no new attempt, manually re-trigger:

```bash
mvai online-training-mgr register-and-run -m <MODEL_ID>
```

### Step 5 — Confirm publishing resumes (~10-15 minutes after new attempt boots)

```bash
meta ai.model.instance list --model-id=<MODEL_ID> --limit=5 \
  --sort-by=creation_time --sort-order=desc -o table
```

Expect a new SPARSE_DELTA / DENSE_DELTA snapshot row created AFTER the new attempt's start time.

### Watch-for / abort signals

| Signal | Action |
|---|---|
| New attempt starts and crashes within 5 min | Same hang reproducing → don't keep restart-looping; file SEV with the captured forensics |
| New attempt RUNNING but no publish within 30 min | Same hang class recurring → root cause is environmental or per-model-state, not transient |
| New attempt RUNNING + publish resumes | Mitigation succeeded; queue forensics review of prior attempt logs to find root cause |

## Autoresponder verification rule

Autoresponder runbooks (e.g., "MVAI Agents" from MLHub) cycle through plausible candidates from a static template. They do NOT verify entity preconditions before suggesting actions. **Before executing any autoresponder-suggested mitigation, verify the named entity actually exists in the state the action assumes.**

Concrete examples seen 2026-05-13:
- Autoresponder suggested `update_checkpoint_or_snapshot_validity(versions=[5397], is_valid=False)` for model 2135033479. Pre-check via `meta ai.model.instance list --model-id=2135033479 --limit=5` showed last instance was 5396; **5397 was never created**. The invalidate-5397 call would no-op or fail. Suggestion: skip.
- Autoresponder suggested "Clear OT job info cache (already done by agents) — may unblock publish retry." The cache is read on session boundaries; a running trainer mid-attempt does not consult it. Clearing is harmless but does not unblock the live hang. Suggestion: cosmetic only, not on the critical path.

**Verification protocol for autoresponder suggestions:**
1. Identify the entities named in the suggestion (snapshot version, checkpoint id, fbpkg name, oncall).
2. For each, run a read-only `meta` CLI to confirm current state.
3. If the entity does not match the action's precondition (e.g., snapshot version doesn't exist, checkpoint already invalid, fbpkg already preserved) → skip the action and document why.
4. Move to the next suggestion.

Source: 2026-05-13 model 2135033479 triage (gchat tiooNt5H7zU).

## Multi-alert cross-check

When 2+ alerts/SEVs fire in the same time window, the bias is to assume a shared root cause (infra-wide event, cluster degradation, common dependency outage). **That bias is wrong as often as it's right.** Always run a fast cross-check before committing to the shared-root narrative.

**Cross-check sequence:**
1. For each alert/model, pull `meta ai.model.instance list --model-id=<ID> --limit=10 --sort-by=creation_time --sort-order=desc` — confirm each alert names a real symptom and not a false positive.
2. Compare model TYPES across the alerts. If they're different model classes (e.g., one delta-only, one full-snapshot-bearing), check whether the alert's expected snapshot-type set matches the model class — false-positive class.
3. Look for SHARED downstream targets: same UMM tier, same Hedwig stream, same Manifold path prefix, same fbpkg. A shared-infra hypothesis requires a shared dependency.
4. If symptoms diverge (one model has new UMM records, the other doesn't; one has Boxcar in error log, the other doesn't), the alerts are independent. Treat each separately.

Source: 2026-05-13 — alert on 2141728943 (`ig_reels_tab_vm_esr`) fired ~30 min after 2135033479's hang. Initial bias was "infra-wide publish-pipeline event affecting both." Cross-check via `meta ai.model.instance list` showed 2141728943 had 200+ valid recent deltas (no actual outage); the alert was a false positive (misconfigured to expect FULL_SNAPSHOT on a delta-only model). 2135033479's hang was confirmed standalone, not part of a cluster.

## Coverage gaps in the OT master agent

| Gap | Why it matters | Action |
|---|---|---|
| No P-ID for A1 (GIL hang) | Both 883552231 and 2135033479 today were freelance-triaged | Promote to **P44** in `known_patterns.md` |
| No A vs D-vs-E disambiguation rule in cron prompts | First triage on 2135033479 went straight to D6 (TGIF) and E2 (DPP) without checking A | Add to `ot-alert-monitor` + `ot-sev-monitor` Step i: "if symptoms include both stuck-CREATING-snapshot AND low-DPP-QPS, FIRST query mvai_metrics for trainer liveness before any D/E hypothesis" |
| No instrumented-process liveness probe in standard triage | mvai_metrics Scuba query not in cron's investigation toolbox | Add canonical "trainer alive?" probe (Method 1 above) to step i |
| C2 (SJD auto-restart fail), C4 (signal handling) not in known_patterns | Mentioned but never formally tracked | Track in learnings.md as P48/P49 proposals when next observed |
| `--state=CREATING` filter buggy on `meta ai.model.instance list` | Returns VALID rows mixed in | Always post-filter the JSON; don't trust the table output |
| MAST log fetch via CLI hits `responseSizeBytes` / PHP OOM | Can't grep publish logs / per-DPP-worker logs from CLI | Use `mvai_metrics` Scuba (Method 1) as fallback for trainer-side evidence |

---

## Change log

- 2026-05-13: Initial version. Source — gchat thread `tiooNt5H7zU` triage of model 2135033479 (FS 5397 stuck CREATING, trainer hung at 06:03:35 PDT). Iteration with Denny exposed 4 reasoning bugs the cron made; this catalog codifies the disambiguators that would have caught them on first pass.
- 2026-05-13 (later): Extended A-class taxonomy. Added A6 (blocking RPC without timeout, P48) and A7 (asyncio event-loop deadlock, P49) — A3 (storage syscall) was filesystem-only and didn't cover network RPC blocks (the most likely class for 2135033479). Added Pipeline-vs-Training QPS divergence section (operator-derived disambiguator that one-shot-falsifies Scribe starvation). Added OT job info cache section (with sourcing to `online_training_mgmt.py:1082`). Added structured kill-and-restart mitigation runbook with forensics-capture-before-kill. Added autoresponder verification rule and multi-alert cross-check rule (sourced from 2141728943 false-positive cross-check). Updated smoking-gun rules table with 5 new rows. Patterns 41 → 43.
- 2026-05-14 (rebase merge): Reconciled with trunk's D-class taxonomy update. D3 mapping corrected to P41 (light_cli version cap, sourced S657811/S661987). Added D11 row (P50 — Upstream infra dependency blocks STUS publish, STUS-only path; sourced S660220 ZippyDB SEV1 2026-05-06). Cross-reference range expanded to P01–P50.
