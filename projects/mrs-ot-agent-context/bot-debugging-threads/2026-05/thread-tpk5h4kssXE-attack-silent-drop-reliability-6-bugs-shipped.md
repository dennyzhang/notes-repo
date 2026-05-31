# Thread Summary: Attack ot-post-monitor Reliability — 6 Real Bugs Found, 5+F Shipped

_Source: spaces/AAQAVOjYc80 thread `tpk5h4kssXE` · 15 messages · 2026-05-27_
_Summarized: 2026-05-28 22:45 PT · last-msg-time: 2026-05-27T21:10:16Z_

## What was discussed

Denny challenged MyClaw to attack the silent-drop solution (T273158617) for real rather than propose hypotheticals. MyClaw audited the actual cron prompt files and found 6 concrete bugs. All 5 fixable-now bugs were shipped in the same turn, plus BUG F (phantom cleanup).

BUG A (critical): `ot-cron-health-watch` step 6.7 referenced wrong state file paths (`ot-alert-monitor-state.json`, `ot-sev-monitor-state.json` — neither exists). Actual paths are `notes/.../state/alert-state.json` and `spaces/.../ot-sev-state.json`. Class 6 only covered 1 of 3 monitors.

BUG B: `ot-alert` and `ot-sev` state schemas (v1/v2) lacked `notification_outcome` keys — walker found nothing silently. Upgraded to v3 dict-of-dict with `notification_outcome` and added `NO_INSTRUMENTATION` classification.

BUG C: `NOTIF_RESP=$(meta google.chat.message send ... 2>&1)` merged stderr → any deprecation warning broke jq parse → false ERROR despite successful send. Fixed: stderr to tempfile + exit-code gate.

BUG D: `jq ... 2>/dev/null` swallowed parse errors. Fixed: `jq -er` + stderr capture.

BUG E: URL fabrication was advisory text, not structural. Fixed: conditional render gate.

BUG F: 27 phantom 2-byte corrupt state files in `spaces/AAQAVOjYc80/` (past path-mangling bug). Quarantined to `_phantom_quarantine_20260527/` (mv not rm).

## Key decisions made

- (2026-05-27T21:03, Denny) "attack the solution to make it reliable. I suspect you will run into thin work again" — push for real bugs not hypothetical list.
- (2026-05-27T21:07, MyClaw) All 5 fixable bugs shipped in one turn, BUG F simultaneously.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-cron-health-watch.md` | Step 6.7 paths corrected + NO_INSTRUMENTATION classification added |
| `notes/.../cron-jobs/ot-post-monitor.md` | BUG C+D: NOTIF_RESP capture hardened |
| `notes/.../cron-jobs/ot-alert-monitor.md` | BUG C+D+B: NOTIF_RESP hardened + v3 schema migration |
| `notes/.../cron-jobs/ot-sev-monitor.md` | BUG C+D+B: NOTIF_RESP hardened + v3 schema migration |

## Cluster / pattern references

_(No confirmed cluster IDs — omitted)_

## Followup items (not yet done)

1. Observe v2→v3 migration of ot-post-monitor on first cron run.
2. Atomic-read for concurrent state-file access (true next-pass, non-blocker).

## Cross-refs

- Tasks: T273158617 (ot-post-monitor silent drop), comment id 1658542992115382
- Related threads: `qXUTrXlIabc` (continuation — Phase 7 BUG B proper + BUG F immediate)
