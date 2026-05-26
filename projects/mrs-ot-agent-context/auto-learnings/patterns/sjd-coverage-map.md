# SJD Coverage Map — Stuck-Job Detection Gaps

_Catalog of failure modes where SJD (StuckJobDetector) doesn't kill stuck OT jobs._
_Maintained to track gaps + propose SJD-rule additions to MVAI platform oncall._
_Cross-references [CL-012] in `failure-patterns.md`._

## Coverage map

**Polarity legend** — SJD failures come in two opposite directions:

```
                       TRUE STATE
                       ┌──────────────┬────────────┐
                       │  Job stuck   │  Job fine  │
                       ├──────────────┼────────────┤
   SJD says "kill"     │   ✅ correct │ 🟡 OVERKILL│
   SJD says "alive"    │  🔴 MISS    │   ✅ correct│
                       └──────────────┴────────────┘
```

- 🔴 **MISS** (false negative) — job IS stuck, SJD says alive, no kill. Operator wastes hours noticing manually. Fix direction: give SJD *additional signals* to detect hangs (e.g., "rank-error + alive-process" rule).
- 🟡 **OVERKILL** (false positive) — job is FINE (just slow), SJD says stuck, kills it. Operator's legitimate work gets SIGKILLed. Fix direction: make the trainer *signal liveness* during legitimate long waits (e.g., poll-and-refresh-watchdog like D104947534).

**Why mixing them matters:** the two directions need different fixes. Naively tightening SJD (catches more MISS bugs) creates more OVERKILL; naively loosening SJD (reduces OVERKILL) creates more MISS. The right approach is *per-mechanism* mitigations — D104947534 fixes a specific OVERKILL mechanism without touching SJD's strictness; "rank-error + alive-process" rule (proposed Ask 1) would catch a specific MISS mechanism without affecting OVERKILL behavior.

| # | Polarity | Failure mode | SJD signal that should fire | Why SJD misses/over-fires today | Best current detection | Status | Reference |
|---|---|---|---|---|---|---|---|
| 1 | 🔴 MISS | Cross-rank NCCL collective deadlock | NO_PROGRESS rule | Watcher rank's Python tick still ticks; collective hangs at C++ layer; some ranks "doing work" (waiting on collective). **Layered root**: proximate = `dist.all_to_all` never returns because ALLTOALL_BASE peers don't deliver expected data. Mechanism = NCCL kernels stay in `ncclInProgress` state until 600s torchrec timeout. **Ultimate root unknown** — S664099 In Progress, attributes to "B200/maz infra rather than code" (baseline succeeds on tsp_snb). Candidates: NVSwitch/NVLink topology bug, IB fabric config on maz racks, NCCL/B200 firmware mismatch, datacenter congestion. Update this row when S664099 publishes root cause. | mvai_metrics liveness (R17) | open | [S664099](https://www.internalfb.com/sevmanager/view/664099), [mrs.ot post 1326387856122624](https://fb.workplace.com/groups/mrs.ot/permalink/1326387856122624/) (Max Kaplan 2026-05-15) |
| 2 | 🟡 OVERKILL | Long legitimate publish wait in publisher.shutdown() | (none — SJD correctly fires, but too early) | Single blocking `future.result(timeout_secs)` call starves the watchdog-refresh callback; SJD then SIGKILLs before the publish would have legitimately completed | mvai_metrics shows ticks until watchdog timeout, then silence (post-kill) | **mitigated by [D104947534](https://www.internalfb.com/diff/D104947534)** (pending land) — polls in 60s chunks + invokes `on_wait_timeout` callback during shutdown waits | (catalog-internal — proactive fix) |
| 3 | 🔴 MISS | Cleanup hang in non-publisher path (C++ destructors, NCCL finalize, fd close) | "Rank-error + alive-process" rule (doesn't exist) | Hang lives outside Python; D104947534's polling pattern doesn't reach C++ destructor / NCCL finalize layers; heartbeat-based SJD sees RUNNING process | mvai_metrics zero-samples timeline | open | [mrs.ot post 1326387856122624](https://fb.workplace.com/groups/mrs.ot/permalink/1326387856122624/) (Max Kaplan 2026-05-15) — actual mechanism in his 11h hang was here, not in publisher.shutdown() |
| 4 | 🟡 OVERKILL | In-training publish wait (same as #2 but outside shutdown) | (none — SJD correctly fires, but too early) | D104947534 threads `on_wait_timeout` only on shutdown paths; in-training `wait_for_publish_completion` call sites still pass `None`. Same starvation mechanism if `publisher_config.timeout_secs` exceeds watchdog window | mvai_metrics liveness (R17) | suspected open — needs D104947534 author confirmation | Inferred from D104947534 review 2026-05-16 thread `z5JIb7DGm5o` |
| 5 | — | _<placeholder for next operator-shared scenario>_ | | | | open | |

## Proposed SJD-rule additions (asks for MVAI platform oncall)

### Ask 1: Rank-error + alive-process rule

**Trigger:** If any rank logs `NCCL ALLTOALL_BASE timeout` (or any 600s+ collective timeout) AND process still alive after N seconds → kill job.

**Catches:** failure mode #1 (NCCL deadlock) and the non-publisher portion of #3 (cleanup hangs outside what D104947534 covers).

**Risk:** false positives on transient NCCL warnings.

**Mitigation:** scope to ERROR-level NCCL collective timeouts only, not warnings. Set N conservatively (e.g., 300s after first error log).

**Owner ask:** MVAI platform oncall — please consider adding to SJD rule set. Reference incidents: S664099 (In Progress, B200/maz hardware-related), and mrs.ot post 1326387856122624 (11-hour silent hang, manually killed by operator).

### Ask 2: Extend D104947534 watchdog-aware wait to in-training publish paths

**Status:** Pending the operator's review of D104947534. The diff threads `on_wait_timeout` through publisher shutdown paths but the in-training `wait_for_publish_completion` call sites still pass `None`. Same blocking-single-call starvation mechanism applies whenever `publisher_config.timeout_secs` exceeds the watchdog window during training.

**Trigger:** Ask diff author whether `_shutdown_watchdog` (set via `set_shutdown_watchdog()`) should also be passed on in-training publish waits, not just shutdown waits.

**Catches:** failure mode #4 (in-training publish wait bypass), preempting it before it manifests as an incident.

**Owner ask:** D104947534 author (Phabricator reviewers).

### Ask 3: _<placeholder for proposals from future scenarios>_

## Detection mechanisms (for cross-reference)

| Mechanism | What it detects | Limitation |
|---|---|---|
| SJD `NO_PROGRESS` | Step counter frozen | Watcher rank may tick even when collective deadlocked |
| SJD `MODEL_PUBLISHING` | No snapshots in window | Catches downstream effect, not root |
| SJD heartbeat absence | Python interpreter dead | Misses cross-rank deadlocks where most ranks alive |
| Bot R17 trainer-liveness | mvai_metrics gap > 5min with MAST RUNNING | Detection only — can't kill job |
| Bot R14 STUS-vs-trainer | Entrypoint check | Routes triage, not detection |
| Bot i-0a upstream-infra check | Active ZippyDB/Scribe SEV correlation | Cross-SEV correlation, not stuck-job detection |

## Trend over time

- **2026-05-15:** Initial catalog seeded with S664099 (NCCL B200/maz) and Max Kaplan post #1326387856122624 observations.
- **2026-05-16 13:36 PT:** Catalog formalized as part of expert-observations Layer-1 workflow (operator request thread `2R3YpI0wAtQ`).
- **2026-05-16 13:42 PT:** D104947534 reviewed in thread `z5JIb7DGm5o`. Initial map split row #2 into publisher-shutdown vs non-publisher cleanup; added row #4 for in-training publish-wait variant.
- **2026-05-16 13:44 PT:** Polarity column added (🔴 MISS vs 🟡 OVERKILL). Sharpened categorization revealed D104947534 fixes the OPPOSITE polarity from Max Kaplan's actual hang: D104947534 prevents over-killing legitimate long publishes (🟡); Max's case was SJD missing a real hang (🔴). The two mechanisms (publisher-shutdown wait starving watchdog vs cleanup hang in non-publisher path) accidentally got conflated as "cleanup hang after error" in the initial seeding. Now correctly distinguished as rows #2 (🟡, mitigated) and #3 (🔴, open). Max's post correctly references row #3, NOT row #2.
- _<future entries as new scenarios + fixes land>_

## Maintenance

- **Add a row** the first time a SEV/post/alert exposes a new SJD blind spot.
- **Update Status** to `mitigated by <SJD rule name>` when MVAI platform ships a fix.
- **Cross-reference [CL-012]** in `failure-patterns.md` for cluster-level tracking (this file is the operational catalog; failure-patterns.md is the pattern registry).
- **Auto-update candidate:** when `ot-knowledge-curation` cron sees CL-012 grow to ≥3 instances, it should draft a D1 diff proposing the SJD-rule addition.

## Cross-references

- Expert observation source: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/2026-05-16-sjd-coverage-gaps.md`
- Cluster registry: `failure-patterns.md` § CL-012
- Trainer-liveness probe: R17 in `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/ot-alert-monitor.md`
- Concept glossary: `~/notes/.../mrs-ot-agent-src/references/concepts.md` (SJD entry — to be added)
