---
human_involved: true
---

# Thread Summary: IG Reels Tab MTML 2133008573 — FULL_SNAPSHOT missing + R17 OOM verification rule

_Source: spaces/AAQAVOjYc80 thread `RmHQoswGPJs` · 6 messages · 2026-05-11T19:47–20:38 UTC_
_Summarized: 2026-06-02 17:43 PT · last-msg-time: 2026-05-11T20:38:29Z_

## What was discussed

Alert triage for model 2133008573 (ig_reels_tab_mtml): FULL_SNAPSHOT missing, high priority. Bot diagnosed post-restart bootstrap gap — attempt 1 died on TGIF in-train-loop publish failure (rank 0 reporting rank 22 error), TMS auto-restarted attempt 2 which was healthy. Bot labeled hypothesis "likely OOM" citing S661936 (cgroup OOM during TGIF export). Operator challenged: "why can't you confirm it?" Bot explained the gap — `mast-job error` only returned `TimeoutError` (outermost exception), not a kernel OOM-killer signal. This led to a concrete escalation chain: `mast-job insights` → `mast-job analyze-zoomer-memory` → system-metrics → kernel log grep. Outcome: new rule R17 proposed for triage discipline.

## Key decisions made

- (2026-05-11T19:47Z) Alert is a post-restart FULL_SNAPSHOT bootstrap gap — expected to auto-clear at next publish cycle (~12:54 PDT). Alert handling: monitor, no immediate escalation.
- (2026-05-11T20:34Z) "OOM" must not be a standing hypothesis unless verified by at least one: `insights` (GPU OOM analyzer), `analyze-zoomer-memory` (per-rank GPU peak), system-metrics peak, or kernel log grep. Exitcode=-9 alone ≠ OOM.
- (2026-05-11T20:38Z) **R17 proposed**: when standing hypothesis names OOM and `error` is opaque (TimeoutError / SIGKILL / exitcode=-9), auto-run `insights` + `analyze-zoomer-memory` before declaring OOM. Converts `[INFERRED]` to `[VERIFIED]` or `[FALSIFIED]`. To land in `references/triage-discipline.md` + `ot-alert-monitor.md` + `ot-sev-monitor.md`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `references/triage-discipline.md` | R17 to be added (proposed, not yet landed) |
| `cron-jobs/ot-alert-monitor.md` | Auto-escalation step for OOM (proposed) |
| `cron-jobs/ot-sev-monitor.md` | Auto-escalation step for OOM (proposed) |

## Cluster / pattern references

_(No confirmed CL-NNN IDs apply.)_

## Followup items (not yet done)

1. Land R17 into `triage-discipline.md` (rules table) with the escalation chain: insights → analyze-zoomer-memory → system-metrics → kernel log grep.
2. Add auto-escalation step to `ot-alert-monitor.md` and `ot-sev-monitor.md` — trigger when hypothesis includes OOM or error is opaque SIGKILL/TimeoutError.
3. Confirm S661936 (TGIF cgroup OOM) not recurring in attempt 2 of model 2133008573.

## Cross-refs

- SEVs discussed: S661936 (cgroup OOM, TGIF export, in-progress)
- Posts: none
- Related threads: `1xDS17eyZwo` (model 2132766001, same ig_reels_tab_mtml class, scribe lag from Gloo TCP timeout)
