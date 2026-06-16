# P-020: A Cron/Agent FIXES & ESCALATES Problems — It Does Not Just Report Them

**Statement:** When an automated job detects a problem, reporting it is not the deliverable — **acting** is. Two binding behaviors: (1) **fix it, or drive a fix** — auto-remediate in-lane where safe, else file ONE deduped tracking/auto-fix task that routes to a drafter/owner; a recurring error must escalate the *response*, never repeat the same flat report line; and (2) **escalate MAJOR issues obviously** — a major problem (authoritative source dark, chronic breach, data loss, broken guarantee) gets a distinct attention-grabbing channel (a `🚨` leading line to the operator), not a line buried in a routine digest. A repeated `errors: <x>` line that reads identically on failure #1 and failure #7 is the anti-pattern.

**Discovered:** 2026-06-13 thread `A4VpmKFNOJ4`. Operator: *"you should fix problems instead of just reporting them"* + *"major issues should escalate to me in an obvious way."* Context: `ot-ingest-gdocs` emitted `errors: fetch_failed (API timeout)` on the same two context docs ~4 of the last 6 daily runs (≈a week), buried in the routine sync summary — never escalated, never fixed — until the operator happened to notice and ask. Root cause of the doc failure: the `gdocs` daemon hangs on large docs (fix: `--no-daemon`) + the Docs API omits `revisionId` for some docs (fix: `sha256(body)` drift key). Root cause of the *behavior*: the recurrence→escalate→auto-fix pattern existed only in the triage monitors (`ot-alert-monitor` steps 7.g / code-mitigation gate), never wired into infra/sync/utility crons.

**Why it matters:** A bot that only reports shifts the work back onto the operator — it makes them the monitor, the triager, AND the fixer, which is the opposite of leverage. Worse, a buried report line repeated daily reads as "handled/known" when it is neither, so a major degradation (a context source dark for a week) hides in plain sight. The whole point of autonomy is to close the loop, not narrate the open one.

**Applies to:** EVERY cron/agent that can emit an error or detect a degradation — triage monitors AND infra/sync/utility jobs (the latter were the blind spot). Generalizable to any operator-facing automated system.

## The two rules
```
Job detects a problem?
  ├─ FIX / DRIVE A FIX (not just report):
  │     recurring or high-confidence → auto-remediate in-lane where safe,
  │     else file ONE deduped [OT auto-fix]/[OT owner-handoff] task (owner=dennyzhang)
  │     that routes to the drafter/owner. Track per-source consecutive-failure
  │     count in state; reset on success. (Reuse ot-alert-monitor's pattern.)
  └─ ESCALATE MAJOR OBVIOUSLY:
        major (source dark / chronic breach / data loss / broken guarantee)
        → 🚨 distinct leading line to the operator 1:1, NOT buried under errors:.
        Exempt from no-op-silence / outreach-budget batching. Routine/no-op → HEARTBEAT_OK.
```

## Enforcement
- `team_bot/CLAUDE.md` (+ local mirror) § "Cron Error Handling — FIX & ESCALATE, never just report (HARD, ALL jobs)".
- Worked instance: `ot-ingest-gdocs` step 3.9 (recurrence tracking + 🚨 CONTEXT-SOURCE-DARK escalation at `consecutive>=2` + deduped `[OT auto-fix]` task, state file `state/ot-ingest-gdocs-state.json`) + the doc fix itself (`--no-daemon`, sha256 drift key) under T275785951.

**Related:** [P-016](./P-016-full-ownership-on-every-fix.md) (full ownership / no confirmation-bait — P-020 is the cron-side counterpart) · [P-017](./P-017-upstream-issue-decisive-metric-task.md) (track upstream with a decisive metric) · [P-019](./P-019-triage-followup-task-and-diff.md) (task + diff for a fixable finding) · [P-002](./P-002-shipping-requires-execution.md).
