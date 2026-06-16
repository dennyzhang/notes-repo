---
name: human-2026-06-05-1434-X5aTOk8FuCs-skill-context-sync-consolidated-into-gdoc-sync
description: Operator corrected over-splitting — standalone ot-skill-context-sync cron merged into ot-gdoc-context-sync; uncommitted notes files caught and committed
human_involved: true
---

# Thread Summary: Consolidating skill-sync into gdoc-sync (operator correction)

_Source: spaces/AAQAVOjYc80 thread `X5aTOk8FuCs` · 28 messages · 2026-06-05_
_Summarized: 2026-06-05 23:43 PT · last-msg-time: 2026-06-05T21:49:16Z_

## What was discussed

The bot had created a standalone `ot-skill-context-sync` cron to mirror fbsource skill files into the context tree. Denny pushed back ("why need a new cron") — the skill-sync is the same "mirror external source into context tree" job as `ot-gdoc-context-sync`, just a different source type (fbsource file vs gdoc; sha256 vs revisionId). The bot had over-split on mechanism. The bot consolidated: folded skill-sync into `ot-gdoc-context-sync` as Part 2, deleted the standalone cron (sqlite `deletes=1`). A follow-up question about notes folder sync revealed the changes were in the notes working copy but **uncommitted**; bot caught and committed 6 files (commit `d31dbcbbcdca`). The prompt-change-validator also flagged a real double-post defect in the Part 2 edit (missing `skill-sources.json` → two messages instead of one), which the bot fixed before calling the change done.

## Key decisions made

- **No new cron for skill-sync** — "different mechanism" (sha256 vs revisionId) doesn't justify a separate cron; one cron runs both loops. Decision: Denny correction at 21:34:37Z.
- **Fold as Part 2 of ot-gdoc-context-sync** — cron ID kept to avoid rename churn; dual scope spelled out in cron header.
- **Optional rename to `ot-context-sync`** — on hold pending Denny's word; not yet executed.
- **Commit all working-copy changes before calling it "done"** — notes working tree had 4 modified + 2 untracked files that weren't caught until Denny asked about the notes folder.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/…/cron-jobs/ot-gdoc-context-sync.md` | Added Part 2 skill-sync loop; double-post defect fixed |
| `notes/…/team_bot/MANIFEST.json` | `ot-skill-context-sync` deleted; gdoc-sync purpose updated |
| `notes/…/CLAUDE.md` | Reference updated to folded-in cron |
| `notes/…/references/skills/` | Initial skill mirror files (new, untracked → committed) |
| `notes/…/references/skill-sources.json` | New config file for skill-sync loop |
| `notes/…/cheatsheets/meta-tasks.md` | Committed (was modified, unrelated) |

## Cluster / pattern references

_(no cluster IDs cited — none verified against failure-patterns.md)_

## Followup items (not yet done)

1. Optional rename `ot-gdoc-context-sync` → `ot-context-sync` — Denny to decide (no urgency)
2. Changes not yet in fbcode — pending the weekly notes→fbcode mirror (Monday)

## Cross-refs

- SEVs discussed: none
- Related threads: `TMSbFoqItA0` (same session — untracked notes durability pattern recurred)
