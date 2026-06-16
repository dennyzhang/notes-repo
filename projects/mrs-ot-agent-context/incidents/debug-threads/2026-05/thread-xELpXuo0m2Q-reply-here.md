# Thread Summary: mrs-ot-agent-context Restructure + mitigated-alerts Fix + README Consistency

_Source: spaces/AAQAVOjYc80 thread `xELpXuo0m2Q` · 26 messages · 2026-05-16_
_Summarized: 2026-05-17 00:31 PT · last-msg-time: 2026-05-16T23:21:36Z_

## What was discussed

Operator opened with "reply here" and proceeded to direct a full restructure of `mrs-ot-agent-context/`. Bot proposed Options A (full restructure), B+ (low-risk cleanups), C (README only); operator chose A. Then a separate discovery: `mitigated-alerts/` was empty — bot diagnosed the daily-learning cron as structurally broken (query used `--status-is=Closed` which meta CLI didn't support) and rewrote it to source from `diagnosed_ids` in alert state. Operator also flagged four post-restructure issues (identity/ → agent_identity/, learnings.md naming, mitigated-posts filename inconsistency, no mitigated-alerts dir). Thread closed with operator noting README.md was still outdated — bot fixed 6 stale refs.

## Key decisions made

- **[2026-05-16T22:14:54Z] "A"** — full Option A restructure chosen; `mega-learnings/` sub-organized into `weekly/`, `cross-week/`, `registry/`, `catalogs/`; `README.md` created; artifacts cleaned.
- **[2026-05-16T22:57:09Z] Operator feedback batch**: `identity/` → `agent_identity/`; `learnings.md` → `daily-learning-ledger.md` (local symlink kept for backward compat); mitigated-posts filename prefix dropped; README updated.
- **[2026-05-16T23:06:53Z] mitigated-alerts cron rewritten** — source changed from broken `--status-is=Closed` query to `diagnosed_ids ∖ current_open` from `alert-state.json`. Known gap documented: manually-resolved alerts not captured by bot triage are still missed.
- **[2026-05-16T23:11:25Z] Daily cron rescheduled 21:15 → 22:05 PT** — daemon missed 21:15 tick on 2026-05-15 (wake gap documented); moved to empirically reliable slot.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/README.md` | Created then updated 2× (restructure nav + 6 stale-ref fixes) |
| `mega-learnings/` | Sub-organized into 4 subdirs (weekly/, cross-week/, registry/, catalogs/) |
| `mrs-ot-agent-context/identity/` → `agent_identity/` | Renamed; symlinks updated; manifest updated |
| `mrs-ot-agent-context/daily-learning-ledger.md` | Renamed from learnings.md; local symlink kept |
| `mitigated-posts/2026-05/` filenames | Lane prefix dropped; cron prompt updated |
| `team_bot/cron-jobs/ot-daily-learning-mitigated-alerts.md` | Rewritten to use diagnosed_ids source + ⚠️ KNOWN GAP section |
| `~/.myclaw-ot-bot/RULES.md` | Rename discipline added (grep-all-occurrences rule) |

Commits: `de8a91449816` (restructure + README), `3ade7f8ccbcf` (agent_identity rename + ledger rename + mitigated-posts fix), `cbb17d428c40` (mitigated-alerts cron rewrite), `c88487705828` (known-gap section), `2ce163497976` (reschedule 21:15→22:05), `91d2e1550b22` (README stale-ref fix).

## Cluster / pattern references

_(No cluster IDs from failure-patterns.md apply to this structural/operational thread.)_

## Followup items (not yet done)

1. Full Option A regrouping (`archives/`, `distilled/`, `sessions/` top-level) deferred — 48 cron-prompt references; documented as TODO in README.md.
2. `state/` filename normalization (uniform `<cron-id>-state.json`) deferred — cosmetic; 10 cron-prompt updates.
3. mitigated-alerts Source B (query closed alerts from meta CLI per oncall) blocked — meta CLI `--status-is=Closed` returns empty for `mrs_online_training` rotation. Needs upstream investigation.
4. Verify 22:05 PT cron fire on 2026-05-16 actually archived alerts (first real test of rewritten prompt).

## Cross-refs

- Related threads: `iqRw-QgzYjM` (same session — cheatsheets, RULES hardening), `djeMtzxvfbU` (state-files-symlink-devserver policy, referenced in README)
