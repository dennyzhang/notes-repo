# Thread Summary: Devserver Reinstall Durability + ot-notes-fbcode-sync Rename + Submit-Guard

_Source: spaces/AAQAVOjYc80 thread `S2zrir2qpBY` · 58 messages · 2026-05-31_
_Summarized: 2026-06-01 04:45 PT · last-msg-time: 2026-05-31T01:11:27Z_

## What was discussed

Denny triggered a deep dive into two failures: (1) why two duplicate weekly fbcode-sync diffs appeared (D106890247 kept, D106934327 abandoned), and (2) whether the new submit-guard hook would survive a devserver reinstall. The bot had submitted the 4×/day commit-cron outside the Monday gate — the same failure as May-22. Separately, Denny asked to rename `ot-notes-fbcode-sync` to something more precise given the commit/diff split.

## Key decisions made

- **2026-05-31T00:52** Root cause confirmed by Denny: agent ran `jf submit` twice outside the Monday gate — prompt instruction alone wasn't a hard stop.
- **2026-05-31T00:52** Design confirmed: keep commit-frequent / diff-weekly split; add PreToolUse submit-guard (not collapse to weekly-only).
- **2026-05-31T00:55** Rename to `ot-notes-fbcode-commit` (Denny proposed `ot-notes-commit` but that collides with existing `ot-notes-commit-push`).
- **2026-05-31T01:03** Denny: "the devserver survival should be a generic feedback" — led to `feedback_devserver-reinstall-durability` memory entry (notes→sqlite→fbcode→LAND; "works now" ≠ "survives reinstall").
- **2026-05-31T01:09** Land deferred: worktree isolation unavailable (Sapling); main working copy tangled with active weekly-sync draft stack + 18:15 cron window. Safe plan: land after stack settles.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-notes-fbcode-commit.md` | renamed from `ot-notes-fbcode-sync.md` |
| `notes/.../MANIFEST.json` | updated job-id for the renamed cron |
| `team_bot/apply-space-hooks.py` | added submit-guard hook spec (not yet landed to fbcode trunk) |
| `spaces/AAQAVOjYc80/.claude/settings.json` | 4th PreToolUse hook: blocks `jf submit`/`conf submit` of weekly-sync commits without `# ot-weekly-sync-submit-ok` token |

## Cluster / pattern references

_(omitted — failure-patterns.md does not exist yet)_

## Followup items (not yet done)

1. Land `apply-space-hooks.py` to fbcode trunk standalone (not via notes mirror — `.py` is denylisted); required for reinstall durability of the submit-guard hook.
2. Drop the acknowledged-rename skip from the commit-cron gate after D106890247 lands (removes `ot-notes-fbcode-sync` from trunk).

## Cross-refs

- SEVs discussed: none
- Related threads: `xc_VJG_out4` (notes push blocked by .db/.py), `rLh3PKgXCmA` (diff-cheatsheet hook)
