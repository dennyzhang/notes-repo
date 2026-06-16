---
name: ot-shift-summary-gdoc-oncall-local-notes-wipe
description: Bot fixed gdoc oncall error (Paul Lu→Li Lu) and wiped operator's Local Notes section; retrospective on why prose rules don't fire
metadata:
  type: project
  human_involved: true
---

# Thread Summary: OT shift-summary gdoc — oncall fix + Local Notes wipe retrospective

_Source: spaces/AAQAVOjYc80 thread `3yt3GJLcH_k` · 45 messages · 2026-06-09T16:24–16:54Z_
_Summarized: 2026-06-10 12:04 PT · last-msg-time: 2026-06-09T16:54:18Z_

## What was discussed

Denny left comments on the OT oncall shift gdoc; the bot addressed 4 comments including a wrong "Incoming → Paul Lu" (actually Li Lu, confirmed via `meta oncall.rotation schedule`). Mid-thread the bot discovered it had wiped the operator's human-owned "Local Notes" section via a full-tab `gdocs replace`, despite two existing rules (RULE 72, RULE 80) saying to preserve it. Denny asked the retrospective: why do these mistakes happen, and how to prevent them.

## Key decisions made

- **Prose rules alone don't fire reliably** — the same root as narration leaks, relative-path writes, and oncall heuristics: rules under task focus. The fix is deterministic code + post-push verification, not more prose. (2026-06-09T16:54:18Z final message)
- **Oncall must be queried, not inferred** — shift-summary cron §2 was patched: now queries `meta oncall.rotation schedule --upcoming` for the actual incoming; added header↔timeline consistency gate. (2026-06-09T16:45:33Z)
- **Local Notes carry-forward must be code-level** — RULE 83 added as interim post-push readback assert; long-term fix is moving the carry-forward into the fill script (tracked, not yet done). (2026-06-09T16:53:37Z)
- **RULE 81/82 added** — date-only timeline (no hh:mm), verbose actionable hand-off section. (2026-06-09T16:54:18Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| OT shift gdoc (1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k) | Header fixed: Incoming → Li Lu; alert noise → concrete 60/66 (91%) ratio |
| shift-summary cron §2 | Oncall logic rewritten: query upcoming schedule, consistency gate added |
| shift-summary cron rules | RULE 72/80 strengthened; RULE 81 (date-only), RULE 82 (verbose hand-off), RULE 83 (Local Notes assert) added |

## Cluster / pattern references

_(CL-NNN omitted — unable to verify against failure-patterns.md in this run)_

## Followup items (not yet done)

1. Restore Local Notes from Google Docs version history (File → Version history, revision before 2026-06-09 08:30 PT) — operator's content, operator to restore
2. Move Local Notes carry-forward from prose rule into fill script code (deterministic) — tracking item

## Cross-refs

- SEVs discussed: S669019, S670887 (mentioned in comment replies as OOM-class)
- Related threads: `BRcxJ7gSLzA` (iteration ground-truth discussion), `C2naImRX58I` (cron output noise)
