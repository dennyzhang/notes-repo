# War Story #1 — Zombie Training Jobs (S665454)

**SEV:** S665454 — Threads Retrieval OT jobs stuck, MAST reports RUNNING, TMS never restarts
**Level:** L3 | **Owner:** Luya Gao (mlygao)
**Duration:** May 16 → Jun 1, 2026 (investigation ongoing)
**GChat:** spaces/AAQAxtHFwMQ
**Impact:** Training QPS and example age drop to 0. Source rate degrades. Significant QE regression across Threads Retrieval U2M models. 7+ jobs affected across maz, mwg, ncg regions. Jobs sat as zombies for hours/days until manually killed.

---

## The problem in one sentence

MVAI OT training workers crash (CUDA SIGABRT while holding driver locks), the process deadlocks instead of exiting, TW container stays alive because sidecars keep running, MAST reports RUNNING, TMS never restarts — job sits as a zombie.

## The call stack

```
MAST Job Scheduler
  └─► Elastic Agent (torch.distributed.elastic — owned by pytorch_distributed_infra oncall)
       └─► MVAI Trainer (light.py — main process)
            └─► Worker Rank N (GPU training loop)
                 └─► PyTorch CUDA Operations
                      └─► c10::CUDACachingAllocator (memory mgmt)
                           └─► libcuda / CUDA Driver
```

## The detection chain that should work (but doesn't)

```
CUDA SIGABRT kills worker process
  → elastic agent's proc.poll() detects exitcode -6
    → elastic agent raises → MVAIExceptionHandler writes reply file
      → light.py calls exit_w_cleanup() → container exits
        → TW reports dead → MAST marks FAILED → TMS restarts
```

The chain breaks because SIGABRT is delivered **while holding CUDA driver locks**. The process can't exit cleanly — it self-deadlocks on mutexes held by the interrupted thread. `proc.poll()` never sees an exit. The elastic agent's `_invoke_run()` loop keeps polling forever.

## Investigation timeline

### Week 1 — Routing the problem (May 21–22)

**Luya Gao** files S665454 after 3 Threads Retrieval OT jobs get stuck. Example age drops to 0, QE degrades.

**Denny Zhang** zooms in on `mvai-training-online-2124122280`: confirms example age spike correlates with DPP scribe read lag. Adds `dpp_starvation` oncall (Yi Zuo). Yi Zuo finds DPP scaling anomaly — suggests hard-setting DPP workers. But this is a separate problem (tracked in S635390), not the zombie issue.

**Denny** adds `managed_training_service` oncall. **Lyric Wu** (TMS oncall) identifies the gap: TMS relies on MAST status.RUNNING. MAST doesn't distinguish main-process-exit from container-alive. Adds MAST oncall (**Apurva Samudra**).

**Apurva Samudra** names the root cause precisely: *"The gap is that TWJM relies on TW reporting the task as dead, but TW only considers the task dead when the container (PID 1) exits — not when the user's process exits. The SIGABRT killed the trainer, not the container."*

**Denny** frames the routing question: *"app layer: trainer, elastic agent. infra layer: TW, MAST."*

### Week 2 — Narrowing the mechanism (May 26–29)

**Wenping Wang** reports more affected jobs. **Feifei Yu** escalates: *"This causes significant QE degradation and prod impact."*

**Luya** adds `tupperware` oncall (**Takshak Chahande**). Joseph Li (MAST): *"we only have container level status"* — MAST has no API to poll main process status.

**Raman Shukhau** (TW) analyzes `mvai-training-online-2124122280`: *"no indications that mast_kill_command was executed and no indications that main process exited. Application itself didn't exit after these exceptions and stayed active in some form (some deadlock or some thread is still alive)."* (P2353199862)

**Takshak** confirms sidecars (VipInjector) are pure sidecar processes in multiNIC config — they won't block container shutdown, but they also won't trigger it. The main task command must exit to tear down the container.

**Takshak** identifies the CUDA driver lock mechanism: *"the trainers are killed while holding CUDA driver locks (libcuda_* frames deep in stack). When raise(SIGABRT) is called from inside the CUDA driver, the process may not exit cleanly."*

**Paul Lu** links D98638473 (elastic agent error handling patch from S628346 — same class of bug).

**Denny** asks Claude to create the call stack diagram with annotations on what's breaking.

### Week 3 — Reproduction attempt (Jun 1)

**Luya** starts test job `mvai-training-online-2120842069` and asks Takshak how to send SIGTERM to reproduce the issue. Awaiting results.

## The five-layer detection gap

| Layer | What it sees | Gap |
|-------|-------------|-----|
| **Worker process** | CUDA SIGABRT → deadlock on driver locks | Can't exit cleanly; no Python handler runs |
| **Elastic agent** | `proc.poll()` on worker PID | If agent is in the same process or deadlocked too, poll loop hangs forever |
| **Reply file** (`/logs/mast_hpc_task_failure_reply_file`) | Written by `MVAIExceptionHandler` | Only written if Python exception path runs. SIGABRT skips it entirely |
| **TW** | Container PID 1 status | Only marks dead when container exits. Sidecars keep container alive |
| **MAST → TMS** | TW task state | Equates "container alive" = "task alive". No process-level health signal |

## How to confirm main process exit (for future stuck jobs)

Ranked by reliability:

1. **Check the PID on the host** — trainer PID is logged at startup in stderr. Check `/proc/<pid>`. If absent, process is dead. **Most definitive.**
2. **Reply file exists** — `/logs/mast_hpc_task_failure_reply_file` present means Python exit path ran. Absent proves nothing (SIGABRT prevents writing).
3. **`[MVAI] Start cleaning up the process with exit code N`** in stderr — proves `exit_w_cleanup()` ran.
4. **Elastic agent `exitcode: -6` log** — proves agent detected the SIGABRT. Only logged if agent itself survived.
5. **Log gap** — no output for extended period. Indirect but practical.

## Code paths (for oncall reference)

- **Entry point:** `minimal_viable_ai/fire/light.py` → `invoke_main()` → `main()` → `mast_error_handling_entrypoint()` → `run()`
- **Reply file writer:** `mvai_infra/utils/exception_handler.py` → `MVAIExceptionHandler.__call__` → `write_mast_reply_file()`
- **Exit handler:** `mvai_infra/exceptions/exceptions.py` → `exit_w_cleanup()` (900s timeout, then `os._exit()`)
- **Elastic agent monitor loop:** `torch/distributed/elastic/agent/server/api.py:906` → `_invoke_run()` → `_monitor_workers()` every `monitor_interval` seconds
- **Worker PID poll:** `torch/distributed/elastic/multiprocessing/api.py:953` → `_poll()` → `handler.proc.poll()`
- **TMS reconciler:** `ai_infra/training_management_system/lib/mast_reconciler/reconciler.py:239` — compares ONLINE_READY models vs MAST-reported active models

## Ownership map

| Component | Team | Oncall |
|-----------|------|--------|
| Elastic agent (`torch.distributed.elastic`) | PyTorch Distributed Infra | `pytorch_distributed_infra` |
| MVAI trainer (light.py) | MVAI | MVAI oncall |
| MAST scheduler | MAST | `c2mast` |
| Tupperware agent | TW | `tupperware` |
| TMS reconciler | TMS | `managed_training_service` |

## Durable lessons

1. **"Container alive" ≠ "task alive."** Any sidecar (VipInjector, sshd, cert renewal) keeps the container running after the main process dies. MAST has no process-level health signal — only container-level.

2. **SIGABRT while holding GPU driver locks = zombie, not crash.** The process doesn't exit; it deadlocks. `proc.poll()` never returns. Reply files never written. Every detection mechanism that depends on "process eventually exits" fails.

3. **Route by the detection gap, not the trigger.** The CUDA assert is the trigger, but the real bug is the missing watchdog. Whether it's SIGABRT, NCCL timeout, or any other hard crash — if the process can't exit cleanly, the entire MAST→TMS restart chain is blind.

4. **"No indications that main process exited" is the diagnostic signature.** When oncall sees a zombie job: no reply file + no `exit_w_cleanup` log + sidecars still running = this failure mode.

5. **Elastic agent is app-layer, not infra.** Oncall for elastic agent bugs is `pytorch_distributed_infra`, not MAST or TW. The agent is a babysitter that spawns workers and monitors PIDs — it never touches a GPU.

## Status

**Open.** Reproduction test job launched Jun 1. Fix direction: trainers need to handle SIGTERM gracefully by completing or canceling in-flight CUDA operations before exiting. Longer-term: MAST needs a process-level health signal independent of container status (e.g., watchdog sidecar or heartbeat lease).

## References

- SEV: https://www.internalfb.com/sevmanager/view/665454
- GChat: https://chat.google.com/room/AAQAxtHFwMQ
- Raman's analysis paste: P2353199862
- CUDA error paste: P2352790214
- Takshak's sidecar analysis: P2353066121, P2353085936
- Related: S628346 (same class), S665478 (elastic agent error handling diffs), D98638473 (patch)
