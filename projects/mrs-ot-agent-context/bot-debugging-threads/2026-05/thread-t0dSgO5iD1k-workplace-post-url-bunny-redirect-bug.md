# Thread Summary: Workplace post URL 404 — bunny resolves aliases, not numeric IDs

_Source: spaces/AAQAVOjYc80 thread `t0dSgO5iD1k` · 22 messages · 2026-05-31 04:39–06:14 UTC_
_Summarized: 2026-06-01 05:45 PT · last-msg-time: 2026-05-31T06:14:32Z_

## What was discussed

Denny reported that URL W1337733828321360 (ot-daily-learning-mitigated-posts digest) returned 404. Bot initially diagnosed a slug-vs-numeric-group-id problem in the `fb.workplace.com/.../permalink/` line — but that analysis targeted the wrong element. The actual 404 was the *title hyperlink*, which used `bunny?q=W<id>`. Bunny resolves named aliases (e.g. "fbl"), not arbitrary numeric post IDs. Denny corrected and applied the fix. Bot verified class was clean (only one cron had the bunny antipattern).

## Key decisions made

- **2026-05-31T06:10:30Z** Denny: root cause confirmed — bunny does not resolve numeric W-IDs. Fix applied: `ot-daily-learning-mitigated-posts` title link now uses the direct `fb.workplace.com/groups/.../permalink/<id>/` URL resolved from the WP API during the same step. notes→sqlite ✓.
- Bot verified no other cron emits `bunny?q=W<id>` antipattern — class fix confirmed (only one cron affected).
- **Diagnostic lesson**: pin the exact 404ing element (which link in the message) before theorizing about the URL form. Bot analyzed the `Post:` line (which worked), not the title hyperlink (which 404'd).

## Files / artifacts touched

| path | what changed |
|---|---|
| `cron-jobs/ot-daily-learning-mitigated-posts.md` | Title link changed from `bunny?q=W<id>` to direct WP permalink |
| notes → sqlite | Propagated via standard update; weekly sync to fbcode |

## Cluster / pattern references

_(omitted — no [CL-NNN] verified in failure-patterns.md)_

## Followup items (not yet done)

_(none — class is clean, fix is live)_

## Cross-refs

- SEVs discussed: none
- Posts: W1337733828321360 (ACL access for ephemeral app-layer package)
- Related threads: none
