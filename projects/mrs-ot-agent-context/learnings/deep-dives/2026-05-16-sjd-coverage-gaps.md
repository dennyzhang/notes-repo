# Expert observations from dennyzhang — 2026-05-16

_Source: spaces/AAQAVOjYc80 threads `z5JIb7DGm5o`, `2R3YpI0wAtQ` (2026-05-16)._

_Layer-1 entry per workflow design in `2R3YpI0wAtQ` 2026-05-16. Operator-curated observations the bot's regular learning crons would miss because they require cross-incident pattern recognition + SJD-domain expertise._

---

## Observation 1: SJD has multiple coverage gaps for stuck-job detection

**The pattern I'm seeing:**

SJD (StuckJobDetector) is the canonical "kill stuck OT jobs" mechanism, but multiple failure modes silently bypass it. The bot's R17 trainer-liveness probe (mvai_metrics) catches some of these, but the platform-level SJD doesn't — meaning the bot keeps detecting them post-hoc rather than the platform killing them automatically.

**Evidence (verified):**

- **S664099** — `[mvai/mvai_ig_ranking] cogwheel_lsr_blackwell_test train failure — NCCL ALLTOALL_BASE timeout on B200 maz hosts`. In Progress. Started 2026-05-13 18:59 PT. Cross-rank collective deadlock; surviving ranks are "doing work" (waiting on NCCL collective at C++ layer); SJD sees process alive; rank watcher heartbeat may still tick.
- **mrs.ot post 1326387856122624** (Max Kaplan 2026-05-15) — `OT Job logged an error at 11pm, job did not clean up and hung for 11 hours`. Model `mvai-training-online-2123154171` (`ig_reels_tab_mtml`). 679-min `mvai_metrics` gap while MAST showed RUNNING. Manually killed by operator at 09:58 PT next morning. Cleanup-hang-after-error class.
- **<future scenarios — operator dropping into thread `z5JIb7DGm5o`>**

**SJD coverage map (what we know so far):**

| # | Failure mode | SJD signal that should fire | Why SJD misses it | Best current detection | Status |
|---|---|---|---|---|---|
| 1 | Cross-rank NCCL collective deadlock | NO_PROGRESS rule | Watcher rank's Python keeps ticking; collective hangs at C++ layer | mvai_metrics liveness (R17) | open |
| 2 | Cleanup hang after error — publisher shutdown variant | "Rank-error + alive-process" rule (doesn't exist) | Heartbeat-based rules see RUNNING process; error-log scanning isn't a SJD input | mvai_metrics zero-samples timeline | **partially mitigated by D104947534** (pending land) |
| 3 | Cleanup hang after error — non-publisher variant | Same as #2 | Hang in C++ destructors / NCCL finalize / fd close; Python polling can't see | mvai_metrics zero-samples timeline | open |
| 4 | In-training publish wait starves watchdog (same mechanism as #2 but outside shutdown) | NO_PROGRESS rule | D104947534 threads watchdog callback only on shutdown paths; in-training call sites still pass None | mvai_metrics liveness (R17) | suspected open — needs author confirmation |
| _next_ | _<placeholder for next operator scenario>_ | | | | open |

**What I think the bot should do differently:**

1. **Track these gaps as a stable cluster** (proposed: [CL-012] in `auto-learnings/failure-patterns.md`).
2. **Maintain a dedicated catalog** `auto-learnings/summaries/catalogs/sjd-coverage-map.md` with proposed SJD-rule additions formatted as asks for MVAI platform oncall.
3. **Triage crons should automatically flag** when they detect a stuck job that SJD didn't catch — feeding the coverage map without manual curation.
4. **At cluster N≥3**, `ot-knowledge-curation` should auto-draft a D1 diff proposing a new SJD rule.

**2026-05-16 13:42 PT update — D104947534 reviewed (thread `z5JIb7DGm5o`):**

Proposed mitigation diff `[mvai/mvai_ig_ranking] Make in-trainer publish waits watchdog-aware` reviewed.
- **What it fixes:** Cell #2 (publisher-shutdown variant of cleanup-hang). Polls `future.result()` in 60s chunks during shutdown, calls watchdog-refresh callback between chunks. Surgical, well-scoped, tested.
- **What it doesn't fix:** Cells #1 (NCCL deadlock, different layer) and #3 (cleanup hang outside publisher path — C++ destructors, NCCL finalize, fd close).
- **New gap identified:** Cell #4 — the same mechanism exists in in-training publish waits (not just shutdown), but D104947534 doesn't thread the watchdog callback through those call sites. Asked the author whether `_shutdown_watchdog` should be passed in non-shutdown waits too.
- **CL-012 instance count:** updated from N=2 → N=3 (rows 1, 2/3, 4 distinct sub-mechanisms now catalogued). N=3 hits D1 trigger threshold.

**Why this isn't already in regular weekly summaries:**

Regular learning crons trigger on postmortem archives (mitigated SEVs / posts / alerts). The SJD-coverage-gap framing is cross-incident — same gap manifests across S664099, Max's post, and likely future scenarios. The bot's per-incident triage correctly identifies each one but doesn't connect them at the architectural level. That's the value of expert observations: pre-emptively naming the pattern so future incidents auto-cluster correctly.

---

## How this file gets used

1. **Layer-1 ingest (manual):** I (bot) read this file at session start; new entries inform triage priors.
2. **Layer-2 ingest cron (future):** scheduled cron scans this directory, verifies cited evidence via meta CLI, proposes failure-patterns.md updates.
3. **Layer-3 triage integration (future):** triage crons grep expert-observations when triaging a new incident; surface relevant priors in `*Cross-SEVs*` section.

For now: this file is the canonical record. Updates: append new observations as separate `## Observation N: <title>` sections.
