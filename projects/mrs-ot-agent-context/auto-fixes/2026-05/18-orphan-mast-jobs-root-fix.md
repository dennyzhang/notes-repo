# Orphan MAST Jobs — Problem Statement for Team Discussion

```yaml
fix_id: orphan-mast-jobs-root-fix
title: MAST cannot distinguish main-process-dead from container-alive, causing orphan training jobs
status: 🟡 drafted
identified: 2026-05-22 S665454 + 2026-05-26 gchat spaces/AAQAxtHFwMQ escalation
target: Cross-team (MAST scheduler + Tupperware + TMS + MVAI)
impact: CL-012, P-001, P-002 — elastic agent zombie class
cost: Multi-team, multi-quarter
```

---

## Problem Statement

**MAST training jobs become orphans — consuming GPU resources while doing zero useful work — because no system reliably detects when the training process dies inside a live container.**

The fundamental invariant that's violated: **"a MAST job in state RUNNING should have an active training process making progress."** Today this invariant has no enforcement.

---

## Impact — SEV-Backed Evidence

### Active SEVs (6 open right now, all stuck-job class)

| SEV | Level | Title | Owner | Duration | Impact |
|---|---|---|---|---|---|
| **S665454** | L3 | Threads Retrieval U2M OT jobs get stuck sporadically | mlygao (Luya Gao) | 10+ days open | 3 jobs stuck 6-22hr each (May 16-18); source rate drop + QE degradation on Threads retrieval. 3 more failures reported May 26. |
| **S665478** | L3 | Reels LSR MB9 OT jobs hanging | xingjiama (Xingjia Ma) | 10+ days open | D-state subprocess unkillable by elastic agent; lupaul fix stack (4 diffs) blocked on light_cli rebuild |
| **S665464** | L4 | Stories ESR Streaming Job occasional failure due to StuckJobException | arafatm | 10+ days open | Recurring — affects 20-58 streaming jobs/day across multiple oncalls (D103046213 reland) |
| **S658165** | L3 | IG OT jobs stuck — silent failure on delta publisher subprocess TCPStore binding | prgzz | 18+ days open | TCPStore binding silent failure → rendezvous never completes → zombie |
| **S657729** | L4 | Prod IFU Sparse Social Model snapshot stale | zhouxinyu | 19+ days open | Snapshot staleness from stuck job |
| **S658565** | L4 | IG Reels CS Omni U2V online publish keep failing | xuzhe | 18+ days open | Daily failures from stuck publish subprocess |

### Closed SEVs (same root cause class, last 90 days)

| SEV | Level | Title | Impact |
|---|---|---|---|
| **S628346** | L3 | MB7 models OT sporadic stuck (4 model IDs) | `threading._shutdown()` deadlock + `exit_w_cleanup` gap + SIGABRT handler hang. 974 GPU-hr waste. |
| **S652049** | L3 | Sequential teacher model OT cannot restart | Elastic agent zombie after worker crash |
| **S662719** | L3 | OT job for VM MTML model stopped | MAST RUNNING but zero training progress |
| **S664106** | L3 | Threads Feed teacher model OT cannot get started | TMS/MAST state desync |

### Fleet-wide evidence

| Metric | Value | Source |
|---|---|---|
| CUDA assert incidents (35 days) | 7+ OT jobs | S665454 investigation paste P2347925094 |
| GPU-hours wasted from py-spy sidecar alone | 3,511 GPU-hr in 3 weeks | D97165868 fix description |
| Estimated monthly waste from CL-012 class | ~512 GPU-hr/month | `patterns/failure-patterns.md` CL-012 |
| Affected oncall rotations | mrs_online_training, mvai, ig_rec_modeling_lsr, threads_ranking | S665464 cross-oncall analysis |
| Jobs affected by S665464 reland pattern | 20-58 streaming jobs/day | S665464 investigation |

---

## Root Cause — Why 5 Detection Layers All Fail

| Layer | What it does | Why it fails for this class | Evidence |
|---|---|---|---|
| **StuckJobDetector** (in-process) | Lease-based heartbeat inside trainer | Dead when trainer dies | S665454: SJD never fired because trainer process was gone |
| **TorchElastic Watchdog** (in-process) | Monitors child process health | D-state subprocesses are unkillable | S665478: watchdog hung trying to kill D-state workers |
| **TW HealthCheck** (container-level) | Probes launcher health via port | Not universally enabled (JK-gated) | Joseph Li (MAST): "MAST interacts with TW through thrift calls, no direct access" |
| **TMS Reconciler** (5-min cycle) | Compares TMS state vs MAST state | If MAST says RUNNING, TMS trusts it | Lyric Wu (TMS): "TMS relies on MAST status.RUNNING" |
| **Zero SM Reaper** (fleet-wide) | Kills jobs with 6hr zero SM util | 6-hour delay — too slow | S665454: job sat 13 hours before manual kill |

**Structural root cause:** Apurva Samudra (MAST): _"TWJM relies on TW reporting the task as dead, but TW only considers the task dead when the container (PID 1) exits — not when the user's process exits."_

---

## Proposed Solutions

### Option A: Universal TW HealthCheck enablement (short-term, weeks)

Enable TW HealthChecks for all `mvai-training-online-*` entitlements. Already exists, just JK-gated.

| Aspect | Detail |
|---|---|
| Covers | Types 2, 3 (elastic agent zombie, sidecar container) — the 80% case |
| Doesn't cover | D-state (HealthCheck probes launcher which is also stuck) |
| Effort | JK rollout, ~days |
| Risk | Low — mechanism already validated on select entitlements |

### Option B: External liveness probe (medium-term, quarter)

Out-of-process watchdog cross-referencing MAST RUNNING status with `mvai_metrics` training progress. If RUNNING + zero metrics for N minutes → force-kill.

| Aspect | Detail |
|---|---|
| Covers | ALL orphan types (completely independent of in-container state) |
| Doesn't cover | N/A — catches everything by checking outcomes, not mechanism |
| Effort | ~2 weeks prototype, ~1 month production |
| Risk | Threshold tuning needed (checkpoint saves, planned pauses) |

### Option C: MAST main-process PID tracking (long-term, multi-quarter)

MAST tracks main command PID separately from container PID. Reports job as FAILED when main process exits, regardless of sidecar state.

| Aspect | Detail |
|---|---|
| Covers | Permanent structural fix for all sidecar-related orphans |
| Doesn't cover | In-trainer stuck (process alive but not progressing) |
| Effort | MAST + TW API change, multi-quarter |
| Risk | Medium — architecture change to MAST/TW contract |

**Recommendation:** Ship A now (days), prototype B this quarter, pursue C as the structural fix.

---

## Stakeholders & Allies

### Directly affected (SEV owners — would benefit immediately)

| Person | Team | Why they care | SEV |
|---|---|---|---|
| **Luya Gao** (mlygao) | Threads Ranking | 3 U2M jobs stuck, QE degradation, filed S665454 | S665454 |
| **Xingjia Ma** (xingjiama) | IG Reels | MB9 OT hanging, authored D106193941 (TMS UNAUTHORIZED fix) | S665478 |
| **Wenping Wang** | Threads | Reported 3+ stuck jobs, manually killing and restarting | S665454 thread |
| **Tianyi Chen** | Threads | Reported 2 X-App U2M failures May 26 | S665454 thread |

### Platform teams (own the fix)

| Person | Team | Role | Evidence of engagement |
|---|---|---|---|
| **Joseph Li** | MAST Scheduler | MAST scheduler oncall; confirmed MAST/TW contract gap | gchat spaces/AAQAxtHFwMQ May 26 |
| **Apurva Samudra** | MAST | Identified structural root cause (PID 1 vs user process) | gchat May 22 |
| **Lyric Wu** (lyricwu) | TMS (managed_training_service) | TMS oncall; confirmed TMS trusts MAST RUNNING | S665454 comment |
| **Sriya Ravi** | MAST | Tagged by Joseph Li for investigation | gchat May 26 |
| **Tupperware oncall** (ctakshak) | Tupperware | Just added to thread May 26 by Luya Gao | gchat May 26 |

### Related fix authors (already working on pieces)

| Person | Team | What they've done |
|---|---|---|
| **Paul Lu** (lupaul) | MRS OT Reliability | Fix stack for S665478 (4 diffs); D105652547 D-state handling |
| **Denny Zhang** (dennyzhang) | MRS OT Reliability | Filed S665454 to managed_training_service, orphan taxonomy |

### Leadership / budget stakeholders

| Person | Team | Why they'd support |
|---|---|---|
| MVAI platform leads | MVAI | $960k/yr savings from zero-SM reaper alone; this closes the remaining gap |
| MRS OT manager | MRS | 6 open L3/L4 SEVs in one failure class; persistent oncall burden |

---

## Questions for the Team

1. **Joseph Li / MAST:** Is there a path to tracking main command PID separately from container PID? What's the engineering cost?
2. **Tupperware oncall:** Can TW report main-process exit independently of container exit? Is this on any roadmap?
3. **MVAI platform:** What's blocking universal HealthCheck enablement? Is it reliability risk or just JK rollout work?
4. **Luya Gao / Wenping / Tianyi:** How many hours/week is your team spending on manual kill-and-restart of stuck jobs?
5. **All:** Are there orphan types we haven't identified? (We have 8; there are likely more.)

---

## References

- Full orphan taxonomy: `auto-learnings/deep-dives/orphan-mast-jobs.md`
- Failure pattern registry: `auto-learnings/patterns/failure-patterns.md` § CL-012
- Gchat escalation thread: `spaces/AAQAxtHFwMQ` (May 22-26)
- TMS Reconciler code: `fbcode/ai_infra/training_management_system/lib/tms_mast_reconciler.py`
- SJD code: `fbcode/aiplatform/stuck_job_detection/stuck_job_detector_core`
