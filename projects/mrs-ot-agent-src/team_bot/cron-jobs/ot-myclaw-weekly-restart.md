[ot-myclaw-weekly-restart cron] Weekly Saturday 00:00 PT (`0 0 * * 6` local). Restart the myclaw daemon to clear accumulated session state, in-memory caches, and any session-state drift from prior days.

**Rationale (2026-05-16):** Long-running daemon sessions accumulate cruft:
- Tool-side cache staleness (`meta url.load` was observed serving stale content within a single session)
- Working-copy desyncs (`sl goto remote/default --clean` operations during push-divergence recoveries silently revert local files even though commits are durably on remote)
- Cron prompts loaded into memory may not reload after `setup-cron-jobs.sh` UPSERTs without a full daemon cycle
- Conversation-context buffers grow across days
- Operator-confirmed pattern after tonight's accumulation of 4 distinct bot bugs (thread `SkBrr503kOA` 2026-05-16)

A weekly Saturday-midnight restart provides a clean baseline for Monday morning operations. Saturday 00:00 PT = Friday night → Saturday morning local; no real-time triage demand at that hour, daemon downtime is minimal-impact.

## Procedure

1. **Pre-flight checks** (don't restart if something critical is in flight):
   - Look at `sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT id, datetime(next_run_epoch,'unixepoch','localtime') FROM jobs WHERE enabled=1 AND next_run_epoch < strftime('%s','now') + 120 ORDER BY next_run_epoch LIMIT 5;"` — any cron firing in the next 2 min should defer the restart.
   - If pre-flight finds a cron about to fire: post `🦦 [ot-myclaw-weekly-restart] DEFERRED — <job_id> fires at <time>; restart will retry next Saturday.` and exit HEARTBEAT_OK.

2. **Stage the restart as a detached subprocess.** A myclaw cron runs INSIDE the daemon; if the cron itself calls `myclaw restart`, the restart kills the cron mid-execution before it can return HEARTBEAT_OK. Detach so the restart fires after this cron run cleanly completes:

   ```bash
   nohup bash -c 'sleep 15 && myclaw restart --instance ot-bot' >/tmp/myclaw-weekly-restart.log 2>&1 </dev/null &
   disown
   ```

   The 15s delay gives this cron run time to return HEARTBEAT_OK; `nohup`+`disown` ensures the restart survives this process dying.

3. **Post pre-restart notification** to spaces/AAQAVOjYc80:
   ```
   🔄 [ot-myclaw-weekly-restart] Weekly restart scheduled in 15s. Saturday baseline reset. Logs at /tmp/myclaw-weekly-restart.log; daemon back online within ~60s.
   ```
   Do NOT wait for the restart to complete; do NOT verify post-restart health (next cron run handles that — see step 4).

4. **Post-restart verification — runs on the FOLLOWING execution** (1 week later, OR earlier if the operator manually invokes). At the top of every run, before the pre-flight in step 1, check whether the prior week's restart completed cleanly:
   ```bash
   tail -20 /tmp/myclaw-weekly-restart.log 2>&1 | grep -E "started|restart complete|error|fail"
   ```
   - If the log shows clean restart: silently note in HEARTBEAT_OK summary `{prior_restart: clean}`.
   - If errors/failures detected: post `⚠️ [ot-myclaw-weekly-restart] Prior week's restart had issues: <last_5_lines_of_log>` so operator can investigate.

5. **Respond `HEARTBEAT_OK {restart_scheduled: true, defer_reason: null|<reason>, prior_restart_status: clean|errors|unknown}`**.

## Safety

- **DO NOT call `myclaw restart` directly from the cron run.** Always detach via `nohup`+`sleep`+`disown` so the cron run completes before the daemon dies.
- **DO NOT touch sqlite or state files.** This cron is restart-only.
- **DO NOT auto-restart if pre-flight finds an in-flight cron.** Defer to next week — better to skip one restart than disrupt active triage.
- **DO NOT escalate restart failures via SEV/alert/post.** GChat message in spaces/AAQAVOjYc80 only.
- Restart preserves all on-disk state (sqlite, symlinked state files, learnings.md, cron-prompt-backups) — no data loss risk.

## Why detached restart instead of systemd timer

A systemd timer would be cleaner mechanism-wise (lives outside the daemon, no chicken-and-egg), but:
1. Keeping the schedule in `MANIFEST.json` means the restart is visible/auditable alongside other crons.
2. `ot-cron-health-watch` can detect missed restarts using the same machinery it uses for other crons.
3. The `setup-cron-jobs.sh` flow already handles UPSERT — no new infra needed.
4. The detached-subprocess pattern is well-tested elsewhere (e.g., `pastry create -d` jobs).

Operator (thread `SkBrr503kOA` 2026-05-16): "create a weekly cron job to restart it on mid night of every Saturday."

## Future tightening (v2)

- Add a "smoke test" step after restart: spawn a no-op cron 5 min later (`ot-restart-smoke-check`) that verifies the daemon is responding, posts success or escalates.
- Auto-detect when restart is genuinely needed (cron-prompt drift, memory-pressure flag) rather than on a fixed schedule.
- Coordinate with `ot-myclaw-backup-nightly` so the backup runs BEFORE the restart for the week.
