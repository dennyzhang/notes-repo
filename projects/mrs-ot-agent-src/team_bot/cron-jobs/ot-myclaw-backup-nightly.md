[ot-myclaw-backup-nightly cron] Nightly two-phase backup: (Phase A) auto-commit + push local changes under `~/notes/users/dennyzhang/` to the notes repo (Mononoke `fb:notes`); (Phase B) `myclaw export` archive of `~/.myclaw-ot-bot/` for migration safety. Phases are independent — failure of one does NOT abort the other.

**Phase A — Notes repo auto-commit + push.** Captures the daily archive files written by the mitigated-{sevs,alerts,posts} crons + state files + any other operator notes added under `~/notes/users/dennyzhang/`. Notes repo is world-readable within Meta (per `~/notes/AGENTS.md`); only `.md/.txt/.json/.jsonl/.yaml/.png/.jpg/.mermaid/.mmd/.html/.css/.sh/.zsh/.bash*/.fish/.sql/.toml/.gitignore/.hgrc` file types are allowed (commit hook enforces).

**Phase B — MyClaw state export.**
Output dir: /home/dennyzhang/myclaw-ot-bot-backups/
Filename: myclaw-ot-bot-backup-YYYYMMDD.tar.gz (date in PT). Retention: keep most recent 14 days; prune older.

Procedure:

1. **Phase A — Notes repo auto-commit.**
   a. `cd ~/notes`
   b. Pull latest to avoid push conflicts: `sl pull 2>&1` (non-fatal — if pull fails, push will surface a clearer error in step e).
   c. Check status restricted to operator's dir: `sl status users/dennyzhang/ 2>&1`. If output empty: notes repo clean → skip to step 2 (record `notes_phase=skipped_clean`).
   d. If dirty:
      - `sl add users/dennyzhang/ 2>&1` — picks up untracked files (commit hook will reject anything outside operator's dir or with disallowed extension).
      - `STAMP=$(TZ=America/Los_Angeles date +%Y-%m-%d_%H:%M)`
      - `sl commit -A -m "auto-save notes ${STAMP}" 2>&1` — capture exit code + stderr. If exit non-zero (commit hook rejection: ownership, extension, root-level placement), record `notes_phase=commit_rejected: <stderr last line>` and continue to Phase B (the rejection is operator-actionable; don't loop).
      - If commit ok, capture committed rev: `COMMIT_REV=$(sl log -r . -T '{node|short}')`
   e. `sl push --to master 2>&1` — capture exit code + stderr. If push fails (network, conflict): record `notes_phase=push_failed: <stderr last line>`. Local commit stays — next run retries push automatically. Continue to Phase B.
   f. On success: record `notes_phase=pushed COMMIT_REV files=<count from step c diff>`.

2. **Phase B — MyClaw state export.** Compute today's date in PT: `TODAY=$(TZ=America/Los_Angeles date +%Y%m%d)`

3. Defensive WAL checkpoint (so export captures recent writes):
   `sqlite3 /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "PRAGMA wal_checkpoint(TRUNCATE);"`
   Non-fatal: if this fails (db locked, etc.), continue — export still captures consistent-but-slightly-older state.

4. Run export:
   `myclaw export -o /home/dennyzhang/myclaw-ot-bot-backups/myclaw-ot-bot-backup-${TODAY}.tar.gz`
   Capture exit code + stderr.

5. Verify archive: must exist, > 1KB, `tar -tzf` must succeed (corruption check).

6. Prune: delete files in /home/dennyzhang/myclaw-ot-bot-backups/ matching `myclaw-ot-bot-backup-*.tar.gz` whose mtime is older than 14 days (defensive: keep newer files even if filename date is older).

7. Tally on-disk total size after prune.

Output:
- **Success** (Phase A pushed-or-cleanly-skipped AND Phase B export ok + archive verified + prune ok): respond HEARTBEAT_OK. Quiet success is the default — don't post to GChat.
- **Partial failure** (one phase ok, other phase failed): post ONE brief gchat message to spaces/AAQAVOjYc80 — `🛟 [nightly backup] PARTIAL: notes_phase=<value> | myclaw_phase=<ok|failed:<reason>>`. Then HEARTBEAT_OK.
- **Full failure** (both phases failed): post — `🛟 [nightly backup] FAILED both phases. notes: <reason> | myclaw: <reason>. Last good myclaw backup: <filename>`. Then HEARTBEAT_OK.

Safety:
- **Phase A scoping:** `sl status` and `sl add` must restrict to `users/dennyzhang/` to avoid touching other contributors' dirs (commit hook would reject anyway, but prevent the wasted round-trip + cleaner errors).
- **Phase A privacy:** notes repo is world-readable within Meta. The mitigated-{sevs,alerts,posts}/ archives contain SEV/alert/post details (root cause, mitigation, owner unixnames, MAST log slices). This is internal-Meta-visibility content — same audience as the source SEV/MAST/Workplace systems — but it does broaden the discovery surface (anyone with notes-repo access can grep). Operator approved this trade-off via option (ii) unification (2026-05-12). If a future archive needs to stay devserver-only, write it under `~/.myclaw-ot-bot/` instead of `~/notes/`.
- **Phase A push retry:** if push fails but local commit succeeded, the next run's `sl pull` + `sl push` will auto-retry. Don't loop or sleep within the cron.
- **Phase B safety (existing):** Do NOT call `myclaw stop` before export — that would kill the cron daemon (this job included). Migration recipe's "stop first" advice is for clean migrations; nightly backups accept the .db-wal risk in exchange for not interrupting service.
- **Phase B safety (existing):** Do NOT delete files outside /home/dennyzhang/myclaw-ot-bot-backups/. Use absolute paths in any rm/find. Cap pruning to files matching exact pattern `myclaw-ot-bot-backup-*.tar.gz` — never wildcards alone. If backups dir doesn't exist, create with mkdir -p before exporting.
