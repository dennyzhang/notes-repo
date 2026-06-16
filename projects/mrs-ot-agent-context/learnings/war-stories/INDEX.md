# War Stories

Deep narratives of significant OT incidents — the full investigation journey, not just the postmortem. Each story captures who found what, the false starts, the technical breakthrough, and the durable lesson for OT oncall.

War stories differ from `incidents/resolved-sevs/` (structured per-SEV archives) and `auto-learnings/patterns/` (clustered failure patterns). A war story is a teaching artifact: give it to a new oncall and they understand a failure mode end-to-end.

## Catalog

| # | SEV | Title | Core lesson | Date |
|---|-----|-------|-------------|------|
| 1 | S665454 | [Zombie training jobs](S665454-zombie-training-jobs.md) | MAST equates "container alive" with "task alive" — sidecars mask main-process death | 2026-05-22 → 2026-06-01 |
| 2 | S628346 | [Elastic agent won't die](S628346-elastic-agent-wont-die.md) | `exit_w_cleanup()` only ran on success path — stuck C++ threads keep agent alive on failure path | 2026-02-25 → 2026-05-12 |
| 3 | S639956 | [Threads training data blackout](S639956-threads-training-data-blackout.md) | Silent `None` guard skipped all training data logging for 9h after a "safe" refactor — L1 | 2026-03-26 |
| 4 | S668980 | [Blocking delta publish stalls training QPS](S668980-blocking-delta-publish.md) | `may_wait_for_ongoing_task_done()` blocks training thread during slow Phase 2 publish — new pattern, not P01/P02 | 2026-05-28 |
| 5 | S669019 | [MVAI Python upgrade leaks during publish](S669019-reels-lsr-mb9-ooms.md) | Python 3.10→3.12 bump leaks in the in-trainer publish path → OOM; native heap profiles truncate at `_PyEval_EvalFrameDefault`, so a runtime bump IS a change-delta | 2026-05-28 → ongoing |

## Failure families

The five stories cover four main OT failure families:

1. **Job stuck (process won't exit):** S665454 (CUDA deadlock), S628346 (C++ threads won't join), and the related S622829 (py-spy ignores SIGTERM). Three mechanisms, one shape — the exit chain is fragile.
2. **Job running but training on nothing:** S639956 (data pipeline silently breaks). Detected only by downstream model degradation hours later.
3. **Job running but QPS periodically degrades:** S668980 (blocking delta publish). Training blocks on slow publish without triggering any monitor — silent QPS dips that look like noise.
4. **Job running but OOMing:** S669019 (memory leak from a platform Python 3.10→3.12 bump on the in-trainer publish path). Trains correctly, just bleeds memory until killed — diagnosable only with Python-frame heap profiling.
