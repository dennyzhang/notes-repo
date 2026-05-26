# Thread Summary: OT cron health alerts — hung/missing jobs + notes path fix

_Source: spaces/AAQAVOjYc80 thread `i9qJr_e-TYU` · 17 messages · 2026-05-15 07:46–08:04 PT_
_Summarized: 2026-05-16 13:31 PT · last-msg-time: 2026-05-15T08:04:15Z_

## What was discussed

OT cron-health-watch fired 2 HIGH alerts after a daemon restart: `ot-sev-tag-review` appeared hung (44+ min with no completion), and `ot-sev-monitor` appeared missing (unregistered in the new daemon session). Simultaneously, `ot-notes-fbcode-sync` was silently failing (exit 127 — script path not found post-migration). Denny asked the bot to debug and fix. The root issue: after the May 14 tree reorg, `~/notes/users/dennyzhang/mrs-ot-agent/` had been removed — making notes-to-fbcode sync impossible and leaving stale canonical-path references. The bot proposed 3 options; Denny selected option 2 (restore notes as canonical).

## Key decisions made

- **[2026-05-15T08:01:24Z] Option 2 selected** — restore `~/notes/users/dennyzhang/mrs-ot-agent/` tree from fbcode, re-register `ot-notes-fbcode-sync` job, keep notes as canonical (not disable the cron or reverse its direction).
- **Deeper stale-path drift** (`.myclaw-ot-team` → `.myclaw-ot-bot` + 21-file rewrite) deferred — Denny said "I will fix it in another session" [2026-05-15T07:55:19Z].

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/users/dennyzhang/mrs-ot-agent/` | Restored from fbcode (SKILL.md, known_patterns.md, references/, team_bot/, cron-jobs/ — 18 files) |
| `~/notes/users/dennyzhang/mrs-ot-agent/team_bot/notes-to-fbcode-sync.sh` | Restored; dry-run validated clean |
| `myclaw.db` jobs table | `ot-notes-fbcode-sync` re-inserted as enabled |

## Cluster / pattern references

_(none — daemon-restart artifacts are operational, not ML failure clusters)_

## Followup items (not yet done)

1. Stale-path drift across all cron prompts (`.myclaw-ot-team` → `.myclaw-ot-bot` rename + 21-file rewrite) — Denny to handle in a separate session. Owner: Denny. Status: deferred.

## Cross-refs

- Related thread context: `ncINfn1Cj2M` (testing session immediately prior, same startup sequence)
