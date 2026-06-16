# Thread Summary: GChat 403 Recurrence — OAuth Expiry vs scope_check Conflation, Root Cause Clarified

_Source: spaces/AAQAVOjYc80 thread `AYu0E96ZdUE` · 17 messages · 2026-05-27–2026-05-29_
_Summarized: 2026-05-29 07:45 PT · last-msg-time: 2026-05-29T02:40:06Z_

## What was discussed

Thread began with an S668441 triage (ig_textpost_crosssurface_notification_esr 2126712861, STUS; zhanma killed v56 for "test", v57 self-recovered, NO_ACTION). Denny then asked why GChat 403 errors keep recurring. Bot initially conflated two separate failure modes: (1) `scope_check` uses `buck2 run`; (2) GChat reads use `meta google.chat.message list`. Bot then investigated GChat 403 specifically — 6 of last 48 cron ticks tagged `gchat_reads=DEGRADED(403)` in ot-sev-monitor (~12.5% lower bound). Bot also over-committed to cwd-pin as root cause fix, then walked it back: 19:04 PT cron succeeded without the fix, so cwd is defense-in-depth only, not confirmed root cause.

## Key decisions made

- (2026-05-29T02:34:02Z) Denny: "root-cause: known" label on the triage was wrong — should be "root cause unknown / transient" since v56 was manually killed.
- (2026-05-29T02:37:30Z) Bot corrected: cwd-pin is defense-in-depth, not proven fix; real root cause of scope_check degradation unknown/likely transient.
- (2026-05-29T02:40:06Z) Bot confirmed conflation: `buck2 run` = scope_check, GChat 403 = OAuth. These are separate failure modes.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/learnings/daily-ledger.md` | L65 filed + amended: direct root cause UNKNOWN / transient; cwd-pin = defense-in-depth only |
| `ot-sev-monitor` cron prompt | cwd pin for buck2 added (defense-in-depth) |

## Cluster / pattern references

_(omitted — failure-patterns.md not present)_

## Followup items (not yet done)

1. Instrument scope_check: log actual cwd + buck2 exit code + stderr into raw_response for 20+ ticks of real evidence before shipping escalation / pre-flight changes. Owner: bot, status: pending.
2. Audit scope_check_consecutive_degraded counter logic — may be incrementing through ticks that produced unaffected triages.

## Cross-refs

- SEVs discussed: S668441
- Posts: none
- Related threads: `AOQM8O19bHE` (OAuth fix shipped)
