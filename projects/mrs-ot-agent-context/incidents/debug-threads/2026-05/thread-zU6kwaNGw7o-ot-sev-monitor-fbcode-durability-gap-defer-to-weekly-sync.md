# Thread Summary: ot-sev-monitor gate fix durability — defer to Monday weekly sync

_Source: spaces/AAQAVOjYc80 thread `zU6kwaNGw7o` · 3 messages · 2026-05-31 15:38–15:39 UTC_
_Summarized: 2026-06-01 05:45 PT · last-msg-time: 2026-05-31T15:39:48Z_

## What was discussed

Denny flagged that the ot-sev-monitor gate fix (L73/L74/L75 + gate section) was live in sqlite but not on fbcode trunk — the session's commit/push had not completed. Denny offered to handle the push. Bot checked the working-copy state: dirty with multiple in-flight changes (`M CLAUDE.md`, `M bootstrap.sh`, `R apply-space-hooks.py`, etc.) and 12 drafts in flight. Carving a clean isolated hotfix risked auto-folding unrelated changes. Bot recommended deferring to Monday's weekly sync, which will mirror current notes (which has the fix) and land cleanly.

## Key decisions made

- **2026-05-31T15:39:43Z** Bot: deferred to Monday weekly sync. Off-cycle manual land is disproportionately risky given dirty multi-draft state.
- Net exposure: reinstall risk for ~2 days. Runtime (sqlite) fix is durable against everything except a full reinstall.
- If reinstall expected before Monday, Denny should handle the isolated land (lower risk than bot untangling dirty state).

## Files / artifacts touched

| path | what changed |
|---|---|
| `cron-jobs/ot-sev-monitor.md` L73–L75 | Fix in sqlite only; fbcode pending weekly sync |

## Cluster / pattern references

_(omitted — no [CL-NNN] verified in failure-patterns.md)_

## Followup items (not yet done)

1. Monday weekly sync (`ot-notes-fbcode-sync-weekly`) must land `ot-sev-monitor.md` gate fix to fbcode trunk. Verify `sl cat -r remote/master fbcode/.../ot-sev-monitor.md` includes L73–L75 after Monday.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none
