# Thread Summary: Notes taxonomy cleanup — state/ location + references/ → human-input-domain/

_Source: spaces/AAQAVOjYc80 thread `M9ILmOTN29Y` · 19 messages · 2026-05-23T14:48Z → 2026-05-23T15:00Z_
_Summarized: 2026-05-23 21:47 PT · last-msg-time: 2026-05-23T15:00:20Z_

## What was discussed

Denny raised two structural issues: (1) Why are runtime state JSON files inside `mrs-ot-agent-src/` (a human-input-only directory)? (2) The `references/` folder name is ambiguous and in the wrong repo section. Discussion resolved both issues and Phase 1 was executed in-session. Bot recommended moving human-authored docs to `mrs-ot-agent-context/human-input/knowledge/`; Denny confirmed this preference over the initially proposed `mrs-ot-agent-src/human-input/`.

## Key decisions made

- **2026-05-23T14:52:38Z** — "fix it": rename `mrs-ot-agent-src/references/` → `mrs-ot-agent-context/human-input/knowledge/` (20 files, history preserved via `sl mv`).
- **2026-05-23T14:53:26Z** — Denny confirmed: human-authored domain docs belong in `mrs-ot-agent-context/human-input/knowledge/`, not `src/`. Mirrors `human-input-generic/` convention already established.
- **2026-05-23T15:00:20Z** — Phase 1 committed as `bdae7b59f4ce`: 20 files moved, 7 caller files updated, sqlite cron prompts UPSERTed, `context/state/` orphan (10 stale JSONs) deleted, fbcode mirror updated as uncommitted changes for sync script.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-src/references/` (20 files) | Moved → `mrs-ot-agent-context/human-input/knowledge/` |
| `notes/users/dennyzhang/CLAUDE.md` | Path references updated |
| `mrs-ot-agent-src/SKILL.md` | Path references updated |
| `mrs-ot-agent-src/known_patterns.md` | Path references updated |
| `mrs-ot-agent-src/team_bot/CLAUDE.md` | Path references + 3 broken `../references/` links fixed |
| `myclaw.db` | `ot-knowledge-curation` + `ot-knowledge-distillation` cron prompts UPSERTed |
| `mrs-ot-agent-context/state/` | 10 stale orphan JSON files deleted |

## Cluster / pattern references

_(Taxonomy/infra topic — no failure cluster reference)_

## Followup items (not yet done)

1. Phase 2: migrate `mrs-ot-agent-src/state/` (19 live cron state files) → `~/.myclaw-ot-bot/spaces/<space>/state/` with back-compat symlinks at old path during transition. Need brief cron pause or symlink bridge. No owner set yet.
2. `sl push --to master` blocked by `deny_files` hook on root `.gitignore` (pre-existing blocker on 67-commit stack); `bdae7b59f4ce` will land when that's unblocked.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none
