# Thread Summary: Gdoc Shift Summary — Fix Now, Not Tomorrow

_Source: spaces/AAQAVOjYc80 thread `ENMy7DG8lyk` · 10 messages · 2026-05-25T19:39–20:24 PT_
_Summarized: 2026-05-28 20:45 PT · last-msg-time: 2026-05-25T20:24:14Z_

## What was discussed

Denny left gdoc comments on the shift-summary doc and asked the bot to fix all of them immediately. Bot initially said it would defer some fixes to the Tuesday 8:30 AM cron regen ("fix it all in the fresh tab"). Denny pushed back: "you should make the changes now, instead of waiting for tomorrow." Bot shipped all 4 fixes in this session.

## Key decisions made

- **2026-05-25T19:53** — "no, you should make the changes now, instead of waiting for tomorrow": deferred-to-cron is not acceptable for same-session fixes that can be done in-doc.
- **2026-05-25T20:24** — Denny confirmed all 4 items done in this turn: 13 gdoc comment replies, S665454+S665214 added to Hand-off, `ot-shift-gdoc-config.json` stale refs fixed, cron prompt updated (Headline table→list, IC-involved SEVs only filter, `[n]` rule fix).

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-shift-summary.md` | tab content as ghtml; post-push checklist inline; `meta google.docs.append markdown` → `gdocs replace/insert-html` |
| `ot-shift-gdoc-config.json` | stale `meta google.docs.*` refs → `gdocs` |
| Shift-summary gdoc 5/26 tab | 13 comment replies; S665454+S665214 in Hand-off |

## Cluster / pattern references

_(omitted — no verified CL-NNN applicable)_

## Followup items (not yet done)

1. D106313256 (cron prompt diff) was draft — needed review + land before Tue 8:30 AM cron.

## Cross-refs

- SEVs discussed: S665454, S665214
- Diffs: D106313256
- Related threads: `tjmKhFz-J-A`, `cDZgP4hWUTU`
