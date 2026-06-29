---
name: j5a603PrCBk-notes-py-ban-commitcloud
description: Notes repo deny_files bans .py; Commit Cloud draft commits in fbcode provide reinstall-durable persistence without diff review
metadata:
  type: project
human_involved: false
---

# Thread Summary: Notes repo `.py` ban → Commit Cloud draft commits as durability mechanism

_Source: spaces/AAQAVOjYc80 thread `j5a603PrCBk` · 19 messages · 2026-06-07 14:50–18:39 UTC_
_Summarized: 2026-06-18 01:20 PT · last-msg-time: 2026-06-07T18:39:36Z_

## What was discussed

Operator proposed converting `.py` scripts to `.sh` to bypass the notes repo `deny_files` ban. Bot explained this fights the intent (notes is a prose/config repo, not a code repo). Discussion then explored how to get reinstall-durable, fast-iteration persistence for Python code. Bot proposed fbcode draft commits (via `sl commit` without `jf submit`), backed by Commit Cloud. Operator challenged whether this actually works. Bot verified end-to-end: created a draft commit in fbcode, confirmed it appeared in `sl cloud sl` (the server-side workspace) within ~69 seconds, and cleaned it up. Confirmed: Commit Cloud auto-backs-up draft commits without any manual push step.

## Key decisions made

- `.py` → `.sh` conversion is the wrong approach (2026-06-07T14:51Z): smuggles code past a guard that encodes intent; bash is also the wrong tool for complex logic
- `.py` commits to notes *locally* succeed but *can never be pushed* — server-side `deny_files` hook rejects; wedges the whole stack (2026-06-07T14:53Z)
- *Durability mechanism* (2026-06-07T15:30Z): `sl commit` in fbcode (draft, ~2s, no review) → `scm_daemon` auto-syncs to Commit Cloud within seconds → restores on new machine via `sl cloud sync`. `landing` in trunk is NOT required for durability.
- Operator at end of thread (2026-06-07T18:39Z): "create a meta task with plan, then execute it" — implicit approval to migrate scripts to fbcode draft commits

## Files / artifacts touched

| path | what changed |
|---|---|
| fbcode (throwaway test commit `fa0b4df58f22`) | created + hidden (proof-of-concept, cleaned up) |

## Cluster / pattern references

(no cluster IDs applicable — infrastructure/tooling design thread)

## Followup items (not yet done)

1. Migrate existing `.py` tools/scripts from notes repo to fbcode draft commits (operator approved at end of thread)

## Cross-refs

- Related threads: `ZYrq7nDswNQ` (autonomous diff workflow question, same session)
