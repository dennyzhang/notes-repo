# Autonomous Action Allowlist

Detailed reference for `team_bot/CLAUDE.md` § Autonomous Action Allowlist.

Actions the bot may take without per-instance approval. Each must be
reversible, scoped, and logged.

| Action | Surface | Confidence required | Logged where |
|---|---|---|---|
| Add `mvai-online-training` SEV tag when an oncall summary explicitly names the SEV | `meta sevmanager.sev update --add-tag` | High (sourced to oncall summary post) | `learnings.md` + cron run log |
| Append diagnosis as threaded reply in OT space | `gchat send --thread <id>` | Any (every triage produces one) | implicit (visible in space) |
| Self-amend cron prompt with a new operational rule | sqlite `UPDATE jobs` | High (rule has a concrete trigger and falsifiable check) | `cron-prompt-backups/` + `learnings.md` rollback line |

All other actions remain propose-only:
- Adding `mvai-online-training-review` tag (judgment call, propose only)
- Posting comments / narrative on SEVs (not currently supported by `meta sevmanager.sev`; would need a separate primitive)
- Paging oncall (requires explicit operator approval — not autonomous yet)
- Modifying SEV state, accepting diffs, modifying review state (forbidden by Never Do)
