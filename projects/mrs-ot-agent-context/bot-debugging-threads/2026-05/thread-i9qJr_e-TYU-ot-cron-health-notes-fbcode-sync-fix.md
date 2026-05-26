# Thread Summary: OT cron health alerts — notes-fbcode-sync path fix & notes restoration

_Source: spaces/AAQAVOjYc80 thread `i9qJr_e-TYU` · 17 messages · 2026-05-15_
_Summarized: 2026-05-17 14:31 PT · last-msg-time: 2026-05-15T08:04:15Z_

## What was discussed

Bot fired a cron-health-watch alert at 07:46 UTC surfacing three transitions: `ot-sev-tag-review` (hung), `ot-sev-monitor` (missing from scheduler), and `ot-notes-fbcode-sync` (silent failure — exit 127 on missing script). Denny directed the bot to debug and fix the sync failure. Investigation revealed the root cause: the `~/notes/users/dennyzhang/mrs-ot-agent/` tree had been wiped during the 2026-05-14/15 migration reorg, making notes-as-canonical architecture stale. Bot proposed three recovery options; Denny chose Option #2 (restore notes tree as canonical, revert fbcode rewrite). Bot executed, validated end-to-end, and re-registered the sync job.

## Key decisions made

- **Option #2 chosen** (2026-05-15T08:00:44Z): restore `~/notes/users/dennyzhang/mrs-ot-agent/` from fbcode, keep notes as canonical source of truth for cron prompts. Bot's 22-file fbcode rewrite reverted cleanly.
- **Do not fix `.myclaw-ot-team` → `.myclaw-ot-bot` rename drift** in this session (2026-05-15T07:55:19Z "I will fix it in another session") — deferred by Denny.
- **ot-notes-fbcode-sync re-registered** in sqlite with `enabled=1` and original cron schedule `15 */6 * * *` after successful fix.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/users/dennyzhang/mrs-ot-agent/` (full tree) | Restored from fbcode: SKILL.md, known_patterns.md, references/, team_bot/, 18 cron-jobs |
| `~/notes/users/dennyzhang/mrs-ot-agent/team_bot/notes-to-fbcode-sync.sh` | Restored from `/tmp` backup |
| `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db` (jobs table) | `ot-notes-fbcode-sync` re-inserted with `enabled=1` |

## Cluster / pattern references

_(no CL-NNN patterns apply — this thread is bot infrastructure, not MRS OT training failures)_

## Followup items (not yet done)

1. `.myclaw-ot-team` → `.myclaw-ot-bot` rename drift + stale path fixup across cron prompts — Denny deferred to separate session (2026-05-15T07:55:19Z). Status: unknown if completed.

## Cross-refs

- SEVs discussed: _(none)_
- Posts: _(none)_
- Related diffs: D105278931 (Denny referenced — related migration context)
- Related threads: `YzbvznJEslA` (immediately followed — ot-daily-learning-mitigated-posts debug in same morning session)
