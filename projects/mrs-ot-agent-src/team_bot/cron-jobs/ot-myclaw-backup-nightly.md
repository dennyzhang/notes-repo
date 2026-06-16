[ot-myclaw-backup-nightly cron] Nightly two-phase backup: (Phase A) auto-commit + push local changes under `~/notes/users/dennyzhang/` to the notes repo (Mononoke `fb:notes`); (Phase B) `myclaw export` archive of `~/.myclaw-ot-bot/` for migration safety. Phases are independent — failure of one does NOT abort the other.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output (incl. failures/escalations), make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, status, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

**Phase A — Notes repo auto-commit + push.** Captures the daily archive files written by the mitigated-{sevs,alerts,posts} crons + state files + any other operator notes added under `~/notes/users/dennyzhang/`. Notes repo is world-readable within Meta (per `~/notes/AGENTS.md`); only `.md/.txt/.json/.jsonl/.yaml/.png/.jpg/.mermaid/.mmd/.html/.css/.sh/.zsh/.bash*/.fish/.sql/.toml/.gitignore/.hgrc` file types are allowed (commit hook enforces).

**Phase B — MyClaw state export.**
Output dir: /home/dennyzhang/myclaw-ot-bot-backups/
Filename: myclaw-ot-bot-backup-YYYYMMDD.tar.gz (date in PT). Retention: keep most recent 14 days; prune older.

Procedure:

1. **Phase A — Notes repo auto-commit.**
   a. `cd ~/notes`, then set `LK="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/scripts/notes-sl-lock.sh"`. **Notes write-lock (Option B, 2026-06-14):** wrap EVERY tree-mutating sl op below (pull/add/commit/push) as `bash "$LK" sl …` so concurrent sessions can't clobber the shared notes tree (read-only sl needs no lock).
   b. Pull latest to avoid push conflicts: `bash "$LK" sl pull 2>&1` (non-fatal — if pull fails, push will surface a clearer error in step e).
   c. Check status restricted to operator's dir: `sl status users/dennyzhang/ 2>&1`. If output empty: notes repo clean → skip to step 2 (record `notes_phase=skipped_clean`).
   d. If dirty:
      - `bash "$LK" sl add users/dennyzhang/ 2>&1` — picks up untracked files (commit hook will reject anything outside operator's dir or with disallowed extension).
      - `STAMP=$(TZ=America/Los_Angeles date +%Y-%m-%d_%H:%M)`
      - `bash "$LK" sl commit -A -m "auto-save notes ${STAMP}" 2>&1` — capture exit code + stderr. If exit non-zero (commit hook rejection: ownership, extension, root-level placement), record `notes_phase=commit_rejected: <stderr last line>` and continue to Phase B (the rejection is operator-actionable; don't loop).
      - If commit ok, capture committed rev: `COMMIT_REV=$(sl log -r . -T '{node|short}')`
   e. `sl push --to master 2>&1` — capture exit code + stderr. If push fails (network, conflict): record `notes_phase=push_failed: <stderr last line>`. Local commit stays — next run retries push automatically. Continue to Phase B.
   f. On success: record `notes_phase=pushed COMMIT_REV files=<count from step c diff>`.

2. **Phase B — MyClaw state export.** Compute today's date in PT: `TODAY=$(TZ=America/Los_Angeles date +%Y%m%d)`

2.5. **Stray-bloat pre-check (added 2026-06-09 after export timed out at 120s on 8.9G).** `myclaw export` tars the WHOLE `~/.myclaw-ot-bot/` and has NO `--exclude`, so any foreign large file dumped there (real MyClaw state is only `spaces/` + `configs/` + `*.md` + `learnings.md`, ~25M total) bloats the archive past the 120s timeout and corrupts it. Before exporting, audit top-level entries: `du -sh ~/.myclaw-ot-bot/* 2>/dev/null | sort -rh | head -5`. If total `du -sh ~/.myclaw-ot-bot` > 500M OR any single non-state top-level entry > 100M, the offender is almost certainly a stray (e.g., a `mast`/`mast.dwp` binary+debug-symbol dump from a CLI run with cwd here). Record `bloat_detected=<entry:size>` and INCLUDE it in the Phase B output so the operator removes it (do NOT auto-delete foreign files — surface them; only the operator/this-thread context knows if a debug artifact is still wanted). The export will still likely fail until it's removed — flag loudly rather than emit a corrupt archive.

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
- **Bloat detected** (step 2.5 flagged a stray top-level entry, regardless of export outcome): the `bloat_detected=<entry:size>` note is NEVER emitted as bare/final-response text. Fold it into the gchat message posted to spaces/AAQAVOjYc80 [operator 1:1] — append it to the partial/full-failure message if either phase failed, OR if both phases otherwise succeeded post a standalone 1-liner `🛟 [nightly backup] export OK but stray bloat in instance home: <entry:size> — remove it (not MyClaw state) before it times out a future export`. In ALL bloat cases the gchat post goes via an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 …`, THEN the final response is EXACTLY HEARTBEAT_OK.
- **Universal:** every non-quiet case posts its message via an explicit `meta google.chat.message send` to spaces/AAQAVOjYc80, then the cron's FINAL RESPONSE is EXACTLY `HEARTBEAT_OK` with NOTHING before it. Never let a `🛟 …` line BE the final response — the daemon would deliver it to the team channel.

Safety:
- **Phase A scoping:** `sl status` and `sl add` must restrict to `users/dennyzhang/` to avoid touching other contributors' dirs (commit hook would reject anyway, but prevent the wasted round-trip + cleaner errors).
- **Phase A privacy:** notes repo is world-readable within Meta. The mitigated-{sevs,alerts,posts}/ archives contain SEV/alert/post details (root cause, mitigation, owner unixnames, MAST log slices). This is internal-Meta-visibility content — same audience as the source SEV/MAST/Workplace systems — but it does broaden the discovery surface (anyone with notes-repo access can grep). Operator approved this trade-off via option (ii) unification (2026-05-12). If a future archive needs to stay devserver-only, write it under `~/.myclaw-ot-bot/` instead of `~/notes/`.
- **Phase A push retry:** if push fails but local commit succeeded, the next run's `sl pull` + `sl push` will auto-retry. Don't loop or sleep within the cron.
- **Phase B safety (existing):** Do NOT call `myclaw stop` before export — that would kill the cron daemon (this job included). Migration recipe's "stop first" advice is for clean migrations; nightly backups accept the .db-wal risk in exchange for not interrupting service.
- **Phase B safety (existing):** Do NOT delete files outside /home/dennyzhang/myclaw-ot-bot-backups/. Use absolute paths in any rm/find. Cap pruning to files matching exact pattern `myclaw-ot-bot-backup-*.tar.gz` — never wildcards alone. If backups dir doesn't exist, create with mkdir -p before exporting.
