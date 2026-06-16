[ot-ingest-diffs cron] Daily 14:30 UTC (07:30 PT, 30 min after ot-ingest-gdocs). **The authored-diffs context sync.** Mirrors Phabricator diffs authored by **key OT people** (the curated `references/key-people.json` roster — members whose `surfaces` include `diffs`) into `mrs-ot-agent-context/references/diffs/<unixname>.md` (change-metadata ONLY) so every OT-agent bootstrap picks up the recent-authored-diffs corpus — this is what the **change-delta-first ("what changed?") triage step** consults. Each file carries the author's **trust tier** (from key-people.json) for downstream weighting. Today no other cron ingests authored diffs (gchat/post monitors only capture incidental `D###` references). **Read-only on Phabricator** (`meta phabricator.diff list` search ONLY — never comment/update/abandon, per the external-surface read-only meta-rule). Idempotent on diff-id + status; silent on no-drift.

**Provenance:** split out of `ot-ingest-gdocs` Part 3 into its own cron (operator 2026-06-13 — reverses the 2026-06-12 fold-in). Rationale: diff ingestion is a conceptually distinct source (live Phabricator query against a curated people roster, not a doc/file mirror) with its own failure modes and schedule needs, so it gets its own cron, lockfile, and state. The GDocs + skills mirrors stay folded together in `ot-ingest-gdocs` (both are "mirror an external doc/file → references/", a genuinely shared operation). **Roster pivot (operator 2026-06-13):** the author roster moved from the live `mrs_online_training` oncall rotation to the curated, trust-tiered `key-people.json` — "pull from key people ... different people have different trust level." The rotation is now a propose-only candidate feed.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-ingest-diffs-state.json` — `{"consecutive_failures": <int>, "first_failed_iso": "<ISO>|null", "autofix_task": "T<id>|null", "last_run_epoch": <int>}` (default `{"consecutive_failures":0}` if absent — no migration). Diff-id+status drift idempotency is enforced IN the tool (per-author file rewritten only on new/status-changed diff). Lockfile: `~/.myclaw-ot-bot/locks/ot-ingest-diffs.lock` (LOCK_MAX_AGE=900s).

**FIX-DON'T-REPORT + ESCALATE-OBVIOUSLY (HARD, 2026-06-13 thread `A4VpmKFNOJ4`, operator: "fix problems instead of just reporting them" + "major issues should escalate to me in an obvious way").** A diff-ingest error must NOT be a flat `errors: diff-ingest failed` line that reads identically on failure #1 and failure #7. This cron tracks consecutive-failure counts and, on recurrence, ESCALATES obviously AND drives a fix — same recurrence→escalate→auto-fix pattern as `ot-alert-monitor` (steps 7.g / consecutive-403 gate) and the sibling `ot-ingest-gdocs`. This is a class rule: any cron that can emit a recurring error owes recurrence-tracking + obvious-escalation + a driven fix, not a repeated report line.

Procedure:

1. **Lockfile gate.** If `~/.myclaw-ot-bot/locks/ot-ingest-diffs.lock` exists AND mtime is within 900s of now → exit silently (concurrent run). Else write the lockfile with current epoch and proceed. Always remove on exit (trap).

2. **Run the ingestion tool — all logic is in the `.sh` (notes deny_files rejects `.py`):**
   ```
   bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/ingest-ot-diffs.sh
   ```
   **Roster** = the curated `mrs-ot-agent-context/references/key-people.json` — every person whose `surfaces` include `diffs`. Each person carries a `trust` tier (1–3) and `domains`, both stamped onto the output. **Run knobs** (`lookback_days` default 14, `per_author_limit`, `candidate_rotation`) live in `references/diffs/diff-sources.json`. The tool runs ONE bulk `meta phabricator.diff list --author-is=<csv> --time-created-is-after=<date>` query and writes one markdown file per author at `references/diffs/<unixname>.md` (with `trust:`/`domains:` frontmatter) plus a combined `README.md` index (with a Trust column). **Candidate discovery (propose-only):** the tool also resolves `candidate_rotation` (`mrs_online_training`) live; any active member NOT in key-people.json is surfaced to stderr + the README as a candidate-to-add, NEVER auto-ingested — curation stays operator-controlled. To change WHO is ingested, edit `key-people.json` (NOT this prompt, NOT the rotation).

3. **Leak-safe + idempotent (enforced IN the tool, not the prompt):** captures ONLY change-metadata (diff id `D###`, author, title, summary, status, created date, url) — NO diff bodies, NO reviewer lists. Dedup on diff number; a file is rewritten only when a diff is new or its status changed; aged-out diffs are pruned to the lookback window; authors with no in-window diffs have their stale file removed. A no-drift run touches nothing (so the notes auto-push has nothing to commit).

4. **Self-report from the tool's summary JSON, never narrated.** The last stdout line is `{"summary":{"authors":N,"authors_with_diffs":A,"diffs":M,"written":W,"errors":E,"lookback_days":D}}`. Capture these counts VERBATIM for the step-6 message. If `errors`>0 → set the error flag (forces step-6 post). If `written`==0 and `errors`==0 → no diff drift (silent `HEARTBEAT_OK`, step 6).

5. **Recurrence tracking + chronic escalation + auto-fix (the fix-don't-report mechanism).** Read the state file.
   - **On success this run** (`errors`==0) → reset `consecutive_failures` to 0, clear `first_failed_iso`. If it had an `autofix_task` and is now succeeding, note `recovered` for the summary and leave the task for the operator to close.
   - **On error this run** (`errors`>0) → `consecutive_failures += 1`; set `first_failed_iso` if newly failing.
   - **CHRONIC gate — `consecutive_failures >= 2`:** this is a MAJOR issue (the recent-authored-diffs corpus is dark → the change-delta-first triage step runs on a stale "what changed?" view). Drive a fix AND escalate, but **DO NOT re-🚨 every run** (P-017: once it's tracked, the task is the tracker — re-narrating each recurrence is the anti-pattern):
     - **(b) DRIVE A FIX (don't just report)** — if no OPEN `autofix_task`: file ONE deduped `[OT auto-fix]` task (`--owner=dennyzhang --add-tag=mvai-online-training`, title `[OT auto-fix] ot-ingest-diffs failing <N> runs: <error_kind>`, body = error_kind + last-N-run history + candidate fix-site, e.g. "oncall.rotation.members list failing → check rotation name / auth" / "phabricator.diff list erroring → check meta CLI auth"). Store the id in `autofix_task`. `ot-autofix-diff-drafter` picks it up for the confirming source-dive + `--draft`.
     - **(a) ESCALATE OBVIOUSLY — but THROTTLED.** Emit the 🚨 leading line ONLY on: (i) the TRANSITION into chronic (`consecutive_failures == 2`), OR (ii) no open `autofix_task` exists yet, OR (iii) a weekly re-alert beat (`consecutive_failures % 7 == 0`). Otherwise (chronic, task already open, not a weekly beat) → do NOT 🚨; keep counting silently (the error still appears in the step-6 `errors:` line, and the open task carries it). When you DO emit, format the FIRST line of the step-6 message as:
       `🚨 [ot-ingest-diffs] AUTHORED-DIFFS CORPUS DARK — failing <consecutive_failures> consecutive runs since <first_failed_iso> (<error_kind>). change-delta-first triage context is STALE. Fix: <one-line candidate or "needs investigation">. Task: T<id>.`
       (operator 1:1 `spaces/AAQAVOjYc80`; exempt from no-op-silence. This throttle keeps "major + obvious" from decaying into daily noise.)
   - Update `last_run_epoch` and write the state file back.

6. **Drift notification — the ONLY send in this cron.** **If step 5 flagged CHRONIC, its 🚨 escalation line goes FIRST, above the routine block below.**
   - If ANY diff-corpus file synced (`written`>0) OR an error occurred (`errors`>0) → post exactly ONE message to `spaces/AAQAVOjYc80` (operator 1:1):
     ```
     [ot-ingest-diffs] synced <W> diff-files (<M> diffs, <A>/<N> authors, <D>d lookback)
     errors: <error_kind or 'none'>
     ```
     (counts come VERBATIM from the `ingest-ot-diffs.sh` summary JSON — `written`/`diffs`/`authors_with_diffs`/`authors`/`lookback_days`, never narrated; omit the `errors:` line when none).
   - If `written`==0 AND `errors`==0 (no drift, no error): silent — respond EXACTLY `HEARTBEAT_OK`, send nothing.

7. **Persistence model.** Synced files live in `mrs-ot-agent-context/references/diffs/` (the runtime corpus tree alongside `references/gdocs/`, `references/skills/`) — notes-only, NOT in `-src/` and NOT mirrored to fbcode. Phabricator is the actual source of truth; notes is just a versioned checkpoint cache, captured by the nightly `ot-myclaw-backup-nightly` cron's notes push. No `jf submit` needed for routine syncs. Fresh agent bootstraps load context via the OT-agent skill loader (which reads `mrs-ot-agent-context/`), not via fbcode reinstall.

8. **Out of scope** (do not attempt; if a future requirement surfaces, file a follow-up task):
   - Diff bodies / reviewer lists — change-metadata only, by design (leak-safe).
   - Write-back to Phabricator (comment/update/abandon) — read-only by design.
   - Non-OT-dev authors — scope is the `roster_rotation` membership; to refine, edit `diff-sources.json` `roster_rotation`, NOT this prompt.

Run-time budget: ~60s (one live roster resolution + one bulk diff query + per-author file writes). Cap roster at the rotation's active membership (the tool handles this).
