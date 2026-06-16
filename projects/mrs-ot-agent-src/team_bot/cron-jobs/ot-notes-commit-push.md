[ot-notes-commit-push cron] Hourly. Commit + push any dirty `mrs-ot-agent-src/`, `mrs-ot-agent-context/`, and bot-owned files in the `~/notes` Sapling repo to the `fb:notes` remote. Notes is canonical for cron prompts, docs, state — keeping it durably synced upstream protects against devserver loss and lets other instances on different devservers see the same source-of-truth.

Cadence: hourly (interval=3600s). Notes repo is hyperactive globally; commit/push contention is not a concern. Loss window is bounded to ≤1h.

Scope (PATHS to consider for commit, ANYTHING ELSE STAYS UNTOUCHED):
- `users/dennyzhang/projects/mrs-ot-agent-src/`     — bot source (cron prompts, CLAUDE.md, sync scripts, config)
- `users/dennyzhang/projects/mrs-ot-agent-context/` — bot state files + archives (incidents/resolved-{sevs,posts,alerts}/, incidents/fbpkg-audits/, triage summaries co-located)

DO NOT touch any other paths in `~/notes/`. The repo is shared with hundreds of users; their dirty edits are NOT yours to commit.

State file: NONE — `sl status` + path filter is fully idempotent. No-op on no-drift inside our scope.

Time budget: ~30s on no-drift, ~1 min when there's a commit to land.

## Procedure

1. Compute the in-scope dirty set:
   ```
   cd ~/notes
   sl status users/dennyzhang/projects/mrs-ot-agent-src/ users/dennyzhang/projects/mrs-ot-agent-context/ 2>&1
   ```
   Parse lines that start with `M `, `A `, `R `, `?`, or `!` (modified, added, removed, untracked, missing).

2. Three possible outcomes:

   a. **Empty status** — no in-scope drift → respond HEARTBEAT_OK and stop. NO GChat message.

   b. **Drift detected** — at least one file changed. Stage and commit:
      ```
      cd ~/notes
      # Notes write-lock (Option B, 2026-06-14): serialize tree-mutating sl ops so
      # concurrent sessions/crons can't clobber the shared notes tree. Read-only sl
      # (status/log/diff) needs no lock; wrap add/forget/commit (+ cloud sync/pull below).
      LK="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/scripts/notes-sl-lock.sh"
      bash "$LK" sl add  users/dennyzhang/projects/mrs-ot-agent-src/ users/dennyzhang/projects/mrs-ot-agent-context/ 2>&1
      bash "$LK" sl forget $(sl status users/dennyzhang/projects/mrs-ot-agent-src/ users/dennyzhang/projects/mrs-ot-agent-context/ | awk '/^! / {print $2}')
      bash "$LK" sl commit users/dennyzhang/projects/mrs-ot-agent-src/ users/dennyzhang/projects/mrs-ot-agent-context/ \
        -m "[OT bot] notes auto-sync $(date -u +%Y-%m-%dT%H:%MZ)

Hourly auto-commit of bot-owned changes:
- src: cron prompts, CLAUDE.md, scripts, config
- context: state files, archives, learnings"
      ```
      Then sync to CommitCloud:
      ```
      sl cloud sync 2>&1
      ```
      ⚠️ DO NOT use `sl push --to remote/main` or `sl push --to remote/default`. The fb:notes repo uses
      CommitCloud for per-user draft chains. Denny's notes live on a draft stack (not on remote/default).
      `sl cloud sync` is the correct durable backup mechanism — syncs to `user/dennyzhang/default` in
      CommitCloud, visible to all devservers under the same account.

   c. **Push fails** (network error, auth issue, conflict, mid-operation working copy) — **DO NOT post yet**. Increment `consecutive_failures` (track in `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-notes-commit-push-state.json` — `{"consecutive_failures": N, "last_failure_at": <epoch>, "last_failure_msg": "<one-line>", "last_alert_epoch": <epoch|null>}`). The next hourly run will retry. Only escalate after the bot's own retry attempts have failed (see step 4).

3. **On successful push: NO GChat post.** Operator value of "hourly housekeeping succeeded" = zero (per RULES.md § Signal-only operator messaging — operator: "would rather get alerted when your notes push has failed" 2026-05-17 thread `JFxkiKmeibI`). Reset `consecutive_failures=0` in state file. Respond `HEARTBEAT_OK {files_committed: N, commit: <hash>, pushed: true}`. Done.

4. **On failure: bot-first retry, then escalate.** When `consecutive_failures >= 1`:
   a. **Self-heal attempt** before alerting:
      - If failure was `Pushrebase: Root is too far behind` or similar divergence → `sl pull` then retry `sl cloud sync`.
      - If failure was `working copy mid-operation` (graft/merge in progress) → `sl abort 2>/dev/null || sl shelve` then retry from step 1.
      - If failure was network/transient (`ECONNREFUSED`, `timeout`) → single immediate retry of `sl cloud sync` after 10s sleep.
      - If self-heal succeeds → reset state, respond `HEARTBEAT_OK`, do NOT post (back to normal silent operation).
   b. **Escalate ONLY when self-heal failed AND `consecutive_failures >= 2`** (i.e., 2 consecutive hourly cycles where bot's own retry didn't recover). Post a single threaded alert:
      ```
      ⚠️ [notes-push] FAILED for 2+ hours — self-heal exhausted, operator action needed.
      Last error: <one-line>
      Last successful commit: <hash> at <ISO time>
      Suggested debug: `cd ~/notes && sl status && sl cloud sync` (interactive run will surface auth/conflict prompts)
      ```
      Stamp `last_alert_epoch = now` so we don't re-alert every hour. Re-alert only if `last_alert_epoch < (now - 24h)` AND still failing.
   c. **If `consecutive_failures >= 12`** (12+ hours stuck — e.g., devserver auth broken overnight) → re-alert regardless of `last_alert_epoch`. This is the "day-long outage" escalation.

5. Respond `HEARTBEAT_OK` with summary `{files_committed: N, commit: <hash>, pushed: true|false, consecutive_failures: K, self_heal_attempted: <bool>, self_heal_succeeded: <bool>, alerted: <bool>}`.

## Safety

- **Path discipline is the entire safety story.** Only `users/dennyzhang/projects/mrs-ot-agent-src/` and `users/dennyzhang/projects/mrs-ot-agent-context/`. Never `users/<other>/` or any sibling path. Never `--all`.
- **No interactive editor.** Use `-m "<msg>"` always. The commit message template above is fine; do not invoke the editor.
- **No --force, no --rebase, no --amend, no edits to landed history.** Backup is via `sl cloud sync` only.
- **If `sl status` shows no in-scope changes, stop immediately.** Do not commit empty changesets.
- **If the working copy has a merge or graft in progress** (`sl status` shows weird states), abort with `⚠️ [notes-push] working copy mid-operation; aborting`. Operator inspects.
- **Untracked files matter.** Crons that write new state files (e.g., `incidents/resolved-posts/2026-05/<lane>-<date>-W<id>.md`) need `sl add` so they're tracked. The `sl add` line above handles that recursively for the in-scope dirs.
- **Missing files** (the `! ` status — file deleted on disk but tracked in repo) get `sl forget`'d so the commit reconciles. This handles cases like the morning mrs-ot-agent reorg cleanly.

## Why this exists

Operator clarified 2026-05-15 23:16 PT: "you should have cron job to push to notes repo". Today's near-miss: ~10h of bot edits (path renames, READ-ONLY rules, sync-script fix) sat uncommitted in the notes working copy alongside the morning's missing-files reorg leftovers. A devserver loss / restart would have lost all of it. Hourly auto-commit caps the loss window at ≤1h.

Pairs with `ot-notes-fbcode-commit` (4×/day): notes-side cron commits/pushes the canonical changes; fbcode-side cron mirrors them out so devserver reinstalls bootstrapping from fbcode see fresh prompts. The two crons are independent — notes-push is the durable backup; fbcode-mirror is the discoverability layer.

## Learned Rules (auto-appended)

- **2026-05-16**: `sl push --to remote/main` fails (bookmark doesn't exist). `sl push --to remote/default`
  fails with "Root is too far behind" — Denny's draft chain diverged from remote/default thousands of
  commits ago; pushrebase is impractical. Correct mechanism: **`sl cloud sync`**, which backs up the
  draft chain to CommitCloud (`user/dennyzhang/default`). All previous "successful" pushes at 03:18 and
  04:18 may have been `sl push` hitting a transient success — cloud sync is more reliable and correct.
