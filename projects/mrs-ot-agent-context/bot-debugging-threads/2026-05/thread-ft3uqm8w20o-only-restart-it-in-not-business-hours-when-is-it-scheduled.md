# Thread Summary: ot-myclaw-weekly-restart UTC timezone bug + notes-fbcode-sync gate fix

_Source: spaces/AAQAVOjYc80 thread `ft3uqm8w20o` · 31 messages · 2026-05-30T00:09–01:20Z_
_Summarized: 2026-05-30 09:45 PT · last-msg-time: 2026-05-30T01:20:45Z_

## What was discussed

Denny asked why `ot-myclaw-weekly-restart` fired at 17:01 PDT Friday (business hours). The bot initially misdiagnosed it as a manual/anomalous trigger; Denny identified the real root cause: cron expression `0 0 * * 6` is evaluated in UTC, making midnight UTC Saturday = 5 PM PDT Friday. Denny fixed the schedule to `0 7 * * 6` (07:00 UTC = midnight PDT Sat). During cleanup, a second issue surfaced: `ot-notes-fbcode-sync` was aborting every run because its trunk-drift gate raw-line-diffed `MANIFEST.json`, false-positiving on encoding (notes was `\u`-escaped, trunk was raw UTF-8 — byte-different, structurally identical). Both were fixed and sqlite synced.

## Key decisions made

- (2026-05-30T00:45:05Z, Denny) Change `ot-myclaw-weekly-restart` cron to `0 7 * * 6` — root cause is UTC eval, not a manual trigger; schedule was the bug.
- (2026-05-30T00:45:05Z, Denny) Keep the business-hours guard in the prompt as defense-in-depth for off-schedule manual triggers.
- (2026-05-30T01:17:42Z, bot) Fix ot-notes-fbcode-sync gate to JSON-aware comparison (parse + compare job ids/fields, threshold 0) — raw byte diff is fragile on unicode encoding.
- (2026-05-30T01:18:19Z, bot) Normalize notes MANIFEST.json to raw UTF-8 to match trunk encoding; eliminates the encoding source of the false positive.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-myclaw-weekly-restart.md` | cron `0 0 * * 6` → `0 7 * * 6`; step-0 guard wording updated to cite UTC root cause |
| `notes/.../cron-jobs/ot-notes-fbcode-sync.md` | trunk-drift gate rewritten as JSON-aware field comparison, threshold 0 |
| `notes/.../MANIFEST.json` | normalized to raw UTF-8 (was `\u`-escaped); structural content unchanged |
| sqlite `cron_jobs` table | schedule + prompt synced for both crons |

## Cluster / pattern references

- Captured as `gotcha_cron-schedule-evaluated-in-utc.md` in memory (crons eval in UTC, not local PT; convert with PDT=UTC-7)
- Captured as `gotcha_trunk-drift-gate-json-encoding-false-positive.md` in memory (JSON-structured files → parse+compare, never raw-line-diff)

## Followup items (not yet done)

_(none — both fixes complete, sqlite parity verified, fbcode audit mirror catches up on next scheduled sync)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none explicit
