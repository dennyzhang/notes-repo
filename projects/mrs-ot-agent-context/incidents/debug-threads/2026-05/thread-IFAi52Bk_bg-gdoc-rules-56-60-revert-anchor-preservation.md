# Thread Summary: Shift Summary Gdoc — Rules 56–60, Revert + Anchor Preservation

_Source: spaces/AAQAVOjYc80 thread `IFAi52Bk_bg` · 32 messages · 2026-05-25T21:19–22:25 PT_
_Summarized: 2026-05-28 20:45 PT · last-msg-time: 2026-05-25T22:25:26Z_

## What was discussed

Continuation of the shift-summary gdoc comment review. Denny left three more waves of comments (9 net-new). Bot captured RULES 49–55 (§6 Open Diffs cols, auto-learnings consultation for theme bullets, bot-internal diff filter, UBN count in headline, SEV identification clauses, alert format, sort+prev-week reference). Denny again said "besides replying the comments, you should update the doc now." Bot made in-doc surgical changes. The same anchor-orphan issue recurred — Denny picked option 1 again (revert). Bot reverted at rev 1838. Then a second wave of 9 comments triggered RULES 56–60 (section order, filler text removal, render_person helper, L? prohibition, internal badge). Bot applied 8 in-doc fixes after confirmation.

## Key decisions made

- **2026-05-25T21:27** — "besides replying the comments, you should update the doc now": rule repeated from `cDZgP4hWUTU`. In-doc fixes are mandatory, not optional.
- **2026-05-25T21:37** — Anchor orphan recurred. Denny chose option 1 (revert) again.
- **2026-05-25T21:40** — "1. Revert to revision 1836": confirmed structural changes that orphan comment anchors must be deferred to fresh-tab cron regen.
- **2026-05-25T21:47** — Bot clarified Drive API only exposes milestone revisions (1380 and 1838); actual rev 1836 inaccessible. Defaulted to working forward (option A).
- **2026-05-25T21:51** — S663485 level: L? → L4 fix confirmed done.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-shift-summary.md` | RULES 49–60 added to template |
| sqlite `jobs` table | SHA parity verified for RULES 49–60 |
| Shift-summary gdoc 5/26 tab | reverted + 8 forward fixes applied (S663485 L4, filler drop, [internal] badges, etc.) |

## Cluster / pattern references

_(omitted — no verified CL-NNN applicable)_

## Followup items (not yet done)

_(thread ends mid-session — further fixes in the subsequent interaction context)_

## Cross-refs

- SEVs discussed: S663485, S665454, S659671, S659917, S659877, S657071, S654768, S635148
- Related threads: `cDZgP4hWUTU`, `4cK6Iy70qYg`
