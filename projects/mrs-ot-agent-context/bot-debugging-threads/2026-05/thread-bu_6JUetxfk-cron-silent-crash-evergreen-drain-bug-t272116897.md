# Thread Summary: 05:41 PDT Cron Silent Crash — Evergreen Drain Bug + T272116897

_Source: spaces/AAQAVOjYc80 thread `bu_6JUetxfk` · 7 messages · 2026-05-19_
_Summarized: 2026-05-19 22:41 PT · last-msg-time: 2026-05-19T16:08:08Z_

## What was discussed

Three heavy crons (ot-alert-monitor, ot-sev-monitor, ot-thread-summarizer) all silently crashed at the 05:41 PDT batch with no DB row, no pi.real process, no error. Lighter crons (disk-watch, notes-commit-push) completed fine. Root cause: Evergreen rolling restart with incomplete drain coverage — `drain_thrift_jobs` waits for the thrift queue only, not pi-harness sessions. Bot proposed three fixes; Denny confirmed all three (Y).

## Key decisions made

- **[2026-05-19T13:45:56Z]** Bot confirmed root cause: Evergreen restart (not Anthropic rate-limit); 06:41 batch recovered cleanly. Three-fix proposal outlined: A (MISSED_COMPLETION detector), B (file upstream task), C (stagger heavy crons).
- **[2026-05-19T15:01:42Z]** Denny: "Are you able to fix it" → bot clarified Fix A + C are in-bot-control; Fix B needs upstream myclaw team.
- **[2026-05-19T16:07:41Z]** Denny confirmed Y → all three applied.
  - **Fix A**: MISSED_COMPLETION detector (class 5) landed in `ot-cron-health-watch.md` + synced to fbcode. Detects `Scheduled job firing` lines without matching completion; cross-cron Evergreen-kill signature recognition; auto-mitigation for allowlisted crons.
  - **Fix B**: Task T272116897 filed against myclaw oncall (owner: mhazinsk Matt Hazinski). Priority MID / Size SMALL. Title: `[myclaw] Evergreen restart drain doesn't cover pi-harness sessions`.
  - **Fix C**: Stagger proposal drafted at `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/draft-cron-edits/heavy-cron-stagger-proposal.md` — NOT applied, awaiting explicit Y.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/ot-cron-health-watch.md` | Added MISSED_COMPLETION class 5 detector |
| fbcode mirror | Synced via ot-notes-fbcode-sync |
| `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/draft-cron-edits/heavy-cron-stagger-proposal.md` | New — stagger proposal (not applied) |

## Cluster / pattern references

_(No CL-NNN cluster applies — this is a bot-infrastructure failure, not an OT model failure pattern)_

## Followup items (not yet done)

1. Apply Fix C (heavy cron stagger to `:05/:20/:35`) — Denny explicit Y still pending. Draft exists at `heavy-cron-stagger-proposal.md`.

## Cross-refs

- SEVs discussed: none
- Tasks: T272116897 (myclaw Evergreen drain bug)
- Related threads: `9vLqtKbImwQ` (same session, Denny asking about bots fixing infra issues)
