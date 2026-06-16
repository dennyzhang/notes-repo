---
name: R32QmkCG66A-tab-bugs-ot-review-tag
description: Oncall shift tab content bugs + required mvai-online-training-review tag section + post-create self-check
metadata:
  type: project
human_involved: true
---

# Thread Summary: Tab Content Bugs, OT-Review Tag Requirement, Post-Create Self-Check

_Source: spaces/AAQAVOjYc80 thread `R32QmkCG66A` · 13 messages · 2026-06-10_
_Summarized: 2026-06-10 22:10 PT · last-msg-time: 2026-06-10T17:13:45Z_

## What was discussed

Operator flagged multiple content errors in the newly created `6/16` shift tab (exact bugs not enumerated in thread). Operator also requested a new required section: oncall must choose relevant SEVs and add the `mvai-online-training-review` tag. Separately, operator asked why the new tab landed at the bottom rather than the top. Bot fixed content bugs, added the required tagging section to the cron template, confirmed tab positioning is a hard API limitation (no programmatic reorder), and added a post-create self-check that auto-deletes a malformed tab (wrong title or wrong window) so bad artifacts no longer persist silently.

## Key decisions made

- [2026-06-10T16:40:50Z] Operator: "The oncall shift should ask oncall choose SEV and add that tag of mvai-online-training-review. Make it as a required place in oncall doc" → bot added this as a required section
- [2026-06-10T17:09:35Z] Bot re-verified positioning API (not cached assumption): `gdocs docs tabs` set = list/create/delete/rename; no move/reorder/swap; `add-tab` has no `--index` or `--position` — hard API limit confirmed
- [2026-06-10T17:11:45Z] Operator: "for new tabs, make the same mistakes won't happen" → bot added post-create self-check: reads back new tab, asserts title == shift-end Tuesday and header == Tue→Tue range; on mismatch auto-deletes + alerts

## Files / artifacts touched

| path | what changed |
|---|---|
| sqlite (shift-summary cron prompt) | Added mvai-online-training-review tagging section; added post-create self-check with auto-delete |

## Cluster / pattern references

_(No confirmed CL-NNN cluster IDs — omitted)_

## Followup items (not yet done)

1. Tab positioning is operator's: new tabs append to end (hard API limit); operator drags to leftmost once after each new shift starts.

## Cross-refs

- Related threads: `cWZYKBGcGB8` (preceded this thread — create-path fix that produced the `6/16` tab this thread debugged)
