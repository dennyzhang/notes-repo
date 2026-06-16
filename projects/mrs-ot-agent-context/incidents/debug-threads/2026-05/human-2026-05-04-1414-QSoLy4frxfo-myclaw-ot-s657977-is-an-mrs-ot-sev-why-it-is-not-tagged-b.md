---
name: QSoLy4frxfo-s657977-auto-tag-miss
description: Denny asks why S657977 wasn't auto-tagged; bot was corrected on triage_config usage
metadata:
  type: thread_summary
  human_involved: true
---

# Thread Summary: S657977 not auto-tagged — bot approach corrected

_Source: spaces/AAQAVOjYc80 thread `QSoLy4frxfo` · 3 messages · 2026-05-04_
_Summarized: 2026-06-02 08:43 PT · last-msg-time: 2026-05-04T21:47:22Z_

## What was discussed

Denny triggered the bot with `!myclaw-ot S657977 is an MRS OT SEV. why it is not tagged by our automations`. The bot apparently attempted to check `triage_config.yaml` as part of its tagging logic, but Denny corrected: "no triage_config.yaml any more. use B, and also check the SEV page for confirmation?" The thread concluded with "ok" from Denny.

## Key decisions made

- [2026-05-04T21:39:49Z] The bot should NOT use `triage_config.yaml` for tagging decisions — it no longer exists. Use signal "B" (the B-path classifier) instead.
- [2026-05-04T21:39:49Z] Auto-tag logic must also confirm via the SEV page directly, not rely solely on the internal config file.

## Files / artifacts touched

| path | what changed |
|---|---|
| (tagging classifier logic) | approach corrected: drop triage_config.yaml dependency, use B-path + SEV page confirmation |

## Cluster / pattern references

_(omitted — cluster IDs not verified against failure-patterns.md)_

## Followup items (not yet done)

_(none explicit)_

## Cross-refs

- SEVs discussed: S657977
- Related threads: `JdvTAp0oMXk` (same tagging miss pattern, S658386)
