---
name: cWZYKBGcGB8-shift-tab-auto-create-fix
description: Oncall shift tab creation — cron skip→auto-create fix; first run created wrong window, hardened + corrected
metadata:
  type: project
human_involved: true
---

# Thread Summary: Oncall Shift Tab — Create Instead of Skip

_Source: spaces/AAQAVOjYc80 thread `cWZYKBGcGB8` · 25 messages · 2026-06-10_
_Summarized: 2026-06-10 22:10 PT · last-msg-time: 2026-06-10T16:46:59Z_

## What was discussed

Operator corrected that the shift-summary cron's "missing tab → skip" behavior was wrong: creating the incoming shift tab is the cron's own responsibility, not a precondition to bail on. Bot diagnosed the root gap (Tuesday close-out only created the *outgoing* tab; nothing created the *incoming* one, so the first mid-shift run on day 2 found no tab and bailed via a "NO-TAB GATE" at cron line 781). Bot fixed the create-path, but the initial run created a malformed `6/10` tab with a rolling today-minus-7 window instead of the correct Tue→Tue `6/16` (Jun 9-16). Bot verified the output, caught the error, deleted the bad artifact, hardened the create-path with a deterministic shell computation, and re-ran successfully.

## Key decisions made

- [2026-06-10T15:46:02Z] Operator: creating the incoming tab is the cron's job — do not skip
- [2026-06-10T16:17:59Z] Root identified: `NO-TAB GATE (HARD)` block in cron prompt deliberately skipped on missing tab; design premise was wrong — missing incoming tab is normal day-1 state, not a masked failure
- [2026-06-10T16:34:31Z] Bot verified post-run and caught the bad artifact (`6/10` rolling window, not `6/16` Tue→Tue) before operator saw it
- [2026-06-10T16:36:21Z] Create-path hardened: deterministic `SHIFT_START=last-tuesday`, `SHIFT_END=+7`, `TAB_TITLE=$SHIFT_END`, both-must-be-Tuesday assert before `add-tab`
- [2026-06-10T16:46:59Z] Correct `6/16` tab created (Li Lu, Day 2/7, 5 needs-oncall items pre-filled)

## Files / artifacts touched

| path | what changed |
|---|---|
| sqlite (shift-summary cron prompt) | NO-TAB GATE replaced with auto-create logic + deterministic Tue→Tue computation |

## Cluster / pattern references

_(No confirmed CL-NNN cluster IDs — omitted)_

## Followup items (not yet done)

1. Operator to manually drag `6/16` tab to leftmost position in the Docs UI — Docs API v1 has no `move`/`reorder`/`swap` and `add-tab` has no `--position` flag; new tabs always append to the end. Hard API limit.

## Cross-refs

- SEVs discussed: _(none)_
- Related threads: `R32QmkCG66A` (immediate follow-up on content bugs in same `6/16` tab)
