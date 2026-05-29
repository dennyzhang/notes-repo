# Thread Summary: Shift Summary Gdoc — Rules 32–60, Comment Anchor Crisis

_Source: spaces/AAQAVOjYc80 thread `cDZgP4hWUTU` · 34 messages · 2026-05-25T19:45–20:46 PT_
_Summarized: 2026-05-28 20:45 PT · last-msg-time: 2026-05-25T20:46:10Z_

## What was discussed

Denny left multiple waves of comments on the 5/26 shift-summary gdoc tab over ~1h. Bot replied to each wave with rule captures (RULES 32–60) and also attempted in-doc surgical fixes. The critical failure: bot's structural edits (removing rows, moving sections) orphaned ~10 comment anchors — making comments appear deleted in Denny's UI. Denny requested revert (option 1). Bot reverted to pre-surgery state (rev 1838), restoring all anchors, but some fixes were lost.

## Key decisions made

- **2026-05-25T19:51** — "you shouldn't delete my comments. you should reply to my comments instead": hard rule established — use `gdocs comments reply` with `[myclaw-ot bot reply]` prefix, NEVER delete operator comments.
- **2026-05-25T19:53** — "beside adding replies, you should make the doc change now": same-session fixes required, not deferred to cron.
- **2026-05-25T21:37** — "again: you deleted my doc comments / reopen them": bot had not deleted them but structural edits orphaned anchors — bot offered 3 options.
- **2026-05-25T21:40** — Denny selected option 1 (revert to pre-surgery): comment anchors take priority over in-doc structural fixes. Structural changes belong in cron regen on fresh tabs.
- **end of thread** — Revert landed at rev 1838. Rules 32–60 captured in cron prompt + sqlite.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-shift-summary.md` | RULES 32–60 added (section order, render_person, L? prohibition, structured cols, etc.) |
| sqlite `jobs` table | SHA parity verified; RULES 32–60 pushed |
| Shift-summary gdoc 5/26 tab | reverted to rev 1838; comment anchors restored |

## Cluster / pattern references

_(omitted — no verified CL-NNN applicable)_

## Followup items (not yet done)

1. Structural changes (§7→§2 promotion RULE 56, SEV+Lvl merge RULE 44, Bot Post Score→bottom RULE 45, render_person across all sections RULE 36-ext) deferred to Tue 8:30 AM cron regen on fresh tab — anchor-safe path.

## Cross-refs

- SEVs discussed: S665454, S667687, S663485
- Related threads: `ENMy7DG8lyk`, `tjmKhFz-J-A`
