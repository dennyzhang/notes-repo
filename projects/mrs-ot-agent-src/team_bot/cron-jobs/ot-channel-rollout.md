[ot-channel-rollout cron] TEMPORARY self-driving rollout of D107122981 (per-job `jobs.channel`). Runs every 2h; self-disables on completion. Goal: once the diff is landed + the daemon is on the new code, route operator-facing plumbing crons to the 1:1 so they stop leaking into the team space `spaces/AAQA2bZMw24`.

**OUTPUT CHANNEL = OPERATOR 1:1.** Any status goes to `spaces/AAQAVOjYc80` via explicit `meta google.chat.message send --reply-in-thread=<thread|# new-topic>`; final response is EXACTLY `HEARTBEAT_OK`. Never narrate to the team space.

DB: `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db`

Procedure (decision tree, idempotent):

1. **Does `jobs.channel` exist yet?** `sqlite3 "$DB" "PRAGMA table_info(jobs);" | awk -F'|' '{print $2}' | grep -xq channel && echo YES || echo NO`.

2. **If YES (new daemon code is live):**
   a. Set channel = `spaces/AAQAVOjYc80` (1:1) on the PLUMBING crons:
      ```
      sqlite3 "$DB" "UPDATE jobs SET channel='spaces/AAQAVOjYc80' WHERE id IN (
        'ot-prompt-change-validator','ot-knowledge-curation','ot-knowledge-distillation',
        'ot-postmortem-validator','ot-triage-auditor','ot-notes-fbcode-commit',
        'ot-notes-fbcode-sync-weekly','ot-sev-tag-review','ot-daily-learning-debugging',
        'ot-daily-learning-mitigated-alerts','ot-daily-learning-mitigated-posts',
        'ot-daily-learning-mitigated-sevs','ot-cron-health-watch','ot-disk-watch',
        'ot-bot-volume-watch','ot-metrics-rollup','ot-myclaw-backup-nightly',
        'ot-fbpkg-cap-watch','ot-notes-commit-push','ot-oauth-refresher',
        'ot-postmortem-validator','ot-debug-quality-weekly');"
      ```
   b. Leave NULL (→ team space) the TEAM-WIDE crons: `ot-sev-monitor`, `ot-alert-monitor`, `ot-post-monitor`, `daily-brief`, `ot-triage-summary`, `team-pulse`, `ot-human-attention-brief`, `ot-daily-learning-digest`, `ot-notes-weekly-review-paste`. (These intentionally serve the team / are the digests. `ot-debug-quality-weekly` is in the 1:1 list above per operator's later call — keep it operator-facing unless the team review is reinstated.)
   c. **Verify (read-back):** `sqlite3 "$DB" "SELECT id, channel FROM jobs ORDER BY channel, id;"` — confirm plumbing rows show the 1:1 space and team-wide rows show NULL.
   d. **Report ONLY on failure** (operator 2026-06-01: "report back to me only when you are not able to finish it"). If step (c) verify passed → SILENT success: do NOT post anything. If verify FAILED or any UPDATE errored → post to the 1:1 WITH a proposed mitigation (operator 2026-06-01: "bring your proposed mitigation, not just the problem"): `⚠️ channel rollout FAILED — <what mismatched, e.g. 'ot-knowledge-curation channel still NULL'>. Proposed fix: re-run \`UPDATE jobs SET channel='spaces/AAQAVOjYc80' WHERE id IN (<the mismatched ids>)\` then re-verify — I'll attempt this automatically next cycle; escalating now only because <the specific reason it needs you, e.g. 'UPDATE raised a sqlite error: <err>'>.` Include the exact corrective command so the operator can run it in one paste if my retry also fails.
   e. **Self-disable:** `sqlite3 "$DB" "UPDATE jobs SET enabled=0 WHERE id='ot-channel-rollout';"`. Respond `HEARTBEAT_OK`. (Success leaves no message — the disabled job + the channel values are the record.)

3. **If NO (column absent → new daemon code not deployed yet):** just WAIT — respond `HEARTBEAT_OK`, re-check in 2h. **Deadline escalation (the "can't finish" report):** if today is on/after **2026-06-06** (5 days out — release should have shipped by then) AND the column still doesn't exist, post to the 1:1 WITH a proposed mitigation: `⚠️ channel rollout STUCK — D107122981 release not deployed after 5d (jobs.channel still missing). Proposed: check the conveyor/release status for the landed commit (\`meta phabricator.diff describe --diff D107122981\` → landed rev → its release train); if the release failed or is paused, re-trigger it or re-land. I'll keep polling and auto-complete the moment the column appears — no action needed if the release just needs more time.`, then keep waiting (do not self-disable — still recoverable). Otherwise stay silent. Do NOT `sl pull`, do NOT force a restart. The daemon runs the RELEASED build, not local fbcode; landing D107122981 only matters once the **release pipeline deploys it (~1–2 days)** and the daemon restarts on the new package — at which point the migration adds `jobs.channel` and step 1 flips to YES on the next cycle. Forcing a local restart would NOT load released code, so it's pointless here. (Column-exists is the single source of truth that the new code is live — no need to track land/release status separately.)

Safety: idempotent — re-running before completion is harmless (UPDATEs are deterministic; restart-trigger is a no-op if already on new code). Self-disables exactly once. If `$DB` query fails, brief error to 1:1, no HEARTBEAT_OK.
