# Thread Summary: gdocs content-read intermittent hang → retry+partial-sync fix

_Source: spaces/AAQAVOjYc80 thread `4rvpMZ5Wxmg` · 18 messages · 2026-06-04T21:45–22:00Z_
_Summarized: 2026-06-04 22:43 PT · last-msg-time: 2026-06-04T22:00:43Z_
human_involved: true

## What was discussed

Operator told bot to propose a fix (not just describe) for gdocs timeouts that had blocked `ot-gdoc-context-sync` and shift-summary reads throughout the day. Bot ran P-015 (backtest before shipping): tested per-tab fetch (timed out), raw Docs-API GET (timed out), `--no-daemon` bypass (still timed out). Concluded the root is an intermittent google-mux/Docs-API content-read hang — not doc size, not markdown conversion, not the daemon. All read paths fail; all write paths (comment-reply, insert-html, tabs-list) work reliably. Proposed fix: retry-with-backoff (3× @ 120→240→360s) around each fetch in `ot-gdoc-context-sync`, partial-sync (preserve last-good `.md` on timeout, never blank), and generalized pattern to the gdocs cheatsheet.

## Key decisions made

- Hypothesis hierarchy eliminated by P-015 testing (2026-06-04T21:54–21:57Z): per-tab NOT the fix; raw-API NOT the fix; daemon NOT the fix. Root = content-read path intermittently hung at google-mux/Docs-API layer.
- Fix is mitigation (retry+partial), not root-fix — two google-mux daemons were running (14:21 + 14:49 PIDs), suggesting an infra-level degradation the bot cannot fix from here. If retries don't help, file a google-mux infra report. Decision at 2026-06-04T22:00:43Z.
- Operator correction (2026-06-04T21:45:18Z): "you should propose fix" / "stop describing and build it" → P-001 lesson reinforced.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../team_bot/cron-jobs/ot-gdoc-context-sync.md` | retry+backoff + partial-sync pattern (staged, not live) |
| `~/notes/.../cheatsheets/gdocs/rules.md` | "content-reads hang intermittently → retry+backoff; writes + tabs-list reliable; prefer raw-API-minimal-fields-with-retry" |

## Cluster / pattern references

_(no matching cluster — env-level gdocs hang is not an OT incident pattern)_

## Followup items (not yet done)

1. Backtest the retry change against the cross-team-followups doc before calling it done (P-015). Not completed in this thread; staged changes pending daemon restart.
2. If retries fail repeatedly → file google-mux infra report.

## Cross-refs

- SEVs discussed: none
- Posts/docs: cross-team-followups gdoc (7 tabs, 42 followups), shift-summary gdoc
- Related threads: `jrwfJJKEjEU` (cron consolidation, same session)
