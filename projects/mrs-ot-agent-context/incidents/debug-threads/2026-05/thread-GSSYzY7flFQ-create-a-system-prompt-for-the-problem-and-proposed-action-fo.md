# Thread Summary: GChat Thread-Reply Hook — Persistent + Portable

_Source: spaces/AAQAVOjYc80 thread `GSSYzY7flFQ` · 53 messages · 2026-05-29_
_Summarized: 2026-05-29 19:48 PT · last-msg-time: 2026-05-29T18:22Z_

## What was discussed

Denny asked for a system-prompt rule + reinstall-persistent hook for thread-reply discipline. Bot initially misread as the gdoc/shift-summary problem; Denny corrected (2026-05-29T17:38Z): the goal was the GChat "reply in thread" enforcement effort. Bot then added HARD section to `team_bot/CLAUDE.md`, generalized `apply-space-hooks.py` to derive space-id from path (was hardcoded), and produced a plain-text copy-paste block for bootstrapping other MyClaw instances. Denny also requested a gchat cheatsheet update — bot added the raw `settings.json` hook payload inline so another instance can copy-paste without running the script.

## Key decisions made

- (2026-05-29T17:43Z) System-prompt rule lives in `team_bot/CLAUDE.md` (bootstrap-loaded daemon context), not ad hoc memory — covers problem, goal, 7 standing actions + PreToolUse hook enforcement.
- (2026-05-29T17:52Z) `apply-space-hooks.py` generalized to derive space-id from `settings.json` path — no longer hardcoded to `AAQAVOjYc80`; makes the script portable to any MyClaw instance.
- (2026-05-29T17:55Z) Plain-text CLAUDE.md block produced for cross-instance teaching — `<MY_SPACE>` placeholder, no script dependency.
- (2026-05-29T18:22Z) gchat cheatsheet updated with raw `settings.json` `PreToolUse[]` block (merge-don't-replace note + validation step) so another MyClaw can adopt without running the script.

## Files / artifacts touched

| path | what changed |
|---|---|
| `team_bot/CLAUDE.md` | HARD section "GChat Reply Discipline" (problem + goal + 7 actions + hook reference) |
| `RULES.md` | Enforcement section for thread-reply PreToolUse hook |
| `apply-space-hooks.py` | Generalized: space-id derived from path, not hardcoded |
| `bootstrap.sh` | `apply_space_hooks()` call added for reinstall idempotency |
| `cheatsheets/comms/gchat.md` | Harness enforcement section + raw hook payload + fold-same-topic note |

## Cluster / pattern references

_(omitted — no failure-cluster context; this is a behavioral/process improvement thread)_

## Followup items (not yet done)

1. fbcode diff with the apply-space-hooks.py + bootstrap.sh changes needs `jf submit` to land on trunk (Denny noted `⚠️ Needs jf submit` at 2026-05-29T17:43Z).

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `HJG9Ec2LuX4` (thread-reply volume discipline root cause)
