# Thread Summary: EPOCH_PLACEHOLDER JSON lint failure — D106189268 fix

_Source: spaces/AAQAVOjYc80 thread `dFKhKc4jNh4` · 8 messages · 2026-05-23T18:30–18:37Z_
_Summarized: 2026-05-23 22:50 PT · last-msg-time: 2026-05-23T18:37Z_

## What was discussed

Denny asked "why you ask" (context: bot had prompted about something). Bot explained the root cause of a CI failure on diff D106189268: the fbcode sync script blindly mirrors `notes/state/*.json` files including bootstrap seed files (`ot-sev-state.json`, `ot-shift-summary-state.json`) that contain the literal token `EPOCH_PLACEHOLDER` instead of valid JSON. Fbcode lint fails with JSONSYNTAX error. Fix was to substitute `0` for `EPOCH_PLACEHOLDER` in both seed files and shelve M-file working-copy drift in fbcode.

## Key decisions made

- [2026-05-23T18:37Z] Fix: replace `EPOCH_PLACEHOLDER` with `0` sentinel in both seed files (notes commit `10111573be25`, pushed to `user/dennyzhang`).
- [2026-05-23T18:37Z] fbcode working-copy M files shelved as `ot-bot-sync-drift-snapshot-20260523` to unblock the cron.
- [2026-05-23T18:37Z] Memory entry added: validate every `*.json` with `python3 -m json.tool` before shipping a sync diff.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/state/ot-sev-state.json` | `EPOCH_PLACEHOLDER` → `0` |
| `notes/state/ot-shift-summary-state.json` | `EPOCH_PLACEHOLDER` → `0` |
| fbcode working copy | Shelved as `ot-bot-sync-drift-snapshot-20260523` |

## Cluster / pattern references

_(No failure-pattern cluster match — this is a bot dev/infra issue, not an OT training failure.)_

## Followup items (not yet done)

1. Fix seed-file architecture: `state-symlinks.manifest.txt` expects symlink targets that bootstrap never realized — either fix bootstrap or remove manifest entries. Flagged in memory, not blocking.

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none (this is a cron/sync infra bug, not a training incident)
