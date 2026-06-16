---
name: ot-evolve-loop-iters8-9-1-operator-qa
thread_id: MgAKrTxjoKw
human_involved: true
summarized: 2026-06-12
---

# Thread Summary: ot-evolve-loop Stage 1b→2→3 results + operator Q&A on operator-gated items

_Source: spaces/AAQAVOjYc80 thread `MgAKrTxjoKw` · 17 messages · 2026-06-12T03:20–20:42 UTC_
_Summarized: 2026-06-12 14:05 PT · last-msg-time: 2026-06-12T20:42:40Z_

## What was discussed

Cron posts from ot-evolve-loop (iters 8, 9, 1) reporting online signal harvest (57.1% validator agreement), codex co-grader passing at 9/10, and Stage 3 mutation results (R19 trigger fix committed, two candidates rejected with redesigns). Operator then asked what is actually blocked by them for the self-evolve. Bot initially over-listed three gates; operator pushed back and the bot correctly withdrew 2 of 3 as not real blockers. Key direction set: use **owning oncall as primary route** (not unixname) in triage output, with IC as parenthetical context. Operator confirmed the self-evolve is autonomous and nothing is genuinely blocked.

## Key decisions made

- **Oncall-primary routing** (2026-06-12T19:22 UTC): Operator directed: use owning oncall (e.g. `ig_producer_value`) as the primary PAGE target, not the model-owner unixname. Rationale: unixname can be offline/on-leave; oncall routes to whoever is on-shift and matches how SEVs actually escalate. Prefix wording to change: `suggested owner` → `suggested route`.
- **fbcode promotion is non-blocking** (2026-06-12T20:38 UTC): Operator confirmed weekly sync diff handles notes→fbcode mirror; not a per-win blocker.
- **Notes-commit is the deploy** (2026-06-12T20:38 UTC): Notes is canonical; monitors load it at runtime. No separate deploy step needed for knowledge wins.
- **Fitness weights are operator-owned but not blocking** (2026-06-12T20:42 UTC): Bot confirmed the loop runs fine on current weights; Stage 1b surfaces if they're wrong. Not blocking.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../triage-discipline.md` | R19 trigger fix committed (SPARSE_DELTA-only, "distinct from P57" clarification) |
| `eval/reports/online-signal-2026-06-11.md` | Stage 1b online signal report |

## Cluster / pattern references

_(No verified CL-NNN IDs — omitted)_

## Followup items (not yet done)

1. Implement OwnerRouting v2: oncall-primary direction (route = owning oncall; unixname parenthetical); A/B against 0.684 baseline next run — awaiting next evolve-loop iteration.
2. Implement Decisiveness v2: target PAGE/MONITOR-with-investigation-step (not the internal REAL_OT_FAILURE/NEEDS_INVESTIGATION taxonomy); add `next_action` field to grader.

## Cross-refs

- Related threads: `iowtd38qUyA` (team space, report-quality feedback context)
