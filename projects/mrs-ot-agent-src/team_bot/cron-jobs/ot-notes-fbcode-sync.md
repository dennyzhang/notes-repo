[ot-notes-fbcode-sync cron] 4×/day. One-way mirror of canonical notes prompts/docs to the fbcode pe_mrs_ml/mrs_ot_agent path. Notes is canonical (post-2026-05-15 migration); this cron keeps the fbcode mirror current so devserver reinstalls bootstrapping from fbcode get fresh prompts.

**This cron COMMITS LOCALLY but does NOT submit a diff.** Diff submission happens once per week via the companion `ot-notes-fbcode-sync-weekly` cron (Monday 09:00 PDT), which folds all `[OT bot weekly sync]` commits accumulated during the week into a single Phabricator diff. Splitting commit-from-submit prevents intra-week diff proliferation (e.g., the May 22 incident where 3 diffs were created in 6h).

State file: NONE — sync script is fully idempotent. No-op on no-drift.

Time budget: ~2 min on no-drift, ~3 min when there's drift to commit.

## Procedure

1. Run the sync script in **--no-submit mode** (commits locally only):
   ```
   bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/notes-to-fbcode-sync.sh --no-submit
   ```

2. After the script runs, **rewrite the commit message** so the weekly cron can identify this commit. The default commit title from the script is `[OT bot sync] notes->fbcode mirror <timestamp>Z` — change it to `[OT bot weekly sync] notes->fbcode <week-tag>` (preserving the rest of the body). Use:
   ```
   cd ~/fbsource
   sl metaedit -r . --message "$(sl log -r . -T '{desc}' | sed '1s/^\[OT bot sync\] notes->fbcode mirror .*$/[OT bot weekly sync] notes->fbcode '$(date -u +%Y-W%V)'/' )"
   ```
   (If you can't run `sed` reliably, just construct the new title in one line: `[OT bot weekly sync] notes->fbcode 2026-W<num>` where W<num> is current ISO week.)

3. Three possible outcomes:

   a. **No drift** — script exits with `[notes-to-fbcode-sync] no drift; fbcode mirror is up to date.` → respond HEARTBEAT_OK and stop. NO GChat message.

   b. **Drift + local commit** — script copies N files, runs `sl commit` (NO `jf submit` because `--no-submit`). After commit-message rewrite (step 2), send ONE GChat message to spaces/AAQAVOjYc80:
      ```
      🔁 [notes->fbcode sync] N file(s) committed locally (no submit; weekly batch on Monday). Local rev: <node|short>
      ```
      Then HEARTBEAT_OK.

   c. **Failure (any non-zero exit)** — capture last 20 lines of script stderr + non-zero exit code. Send ONE GChat message:
      ```
      ⚠️ [notes->fbcode sync] FAILED — exit=<code>. Last lines:
      <stderr tail>
      ```
      Then HEARTBEAT_OK. Do NOT loop.

## Safety rules

- **Hard precondition**: fbcode/pe_mrs_ml/mrs_ot_agent/ working copy must be clean. Script aborts with non-zero exit if not. This protects against folding stray edits into the auto-sync diff.
- **No edits to notes from this cron** — sync is one-way only (notes -> fbcode). If the script ever needs to write back to notes (it doesn't today), require explicit operator authorization.
- **No fbcode commits beyond the sync target** — script only commits paths under fbcode/pe_mrs_ml/mrs_ot_agent/.
- **Cap 1 LOCAL commit per run.** Sync script bundles all drift into one local commit per invocation. NO diff is submitted by this cron — submission is done by `ot-notes-fbcode-sync-weekly` once per week.
- **Diff title is auto-generated** with the sync timestamp; reviewers can identify auto-sync diffs at a glance.
- **Never call gchat.message.create directly** — system auto-delivers final response.

## Why this cron exists (rationale, not behavior)

Pre-2026-05-15: cron prompts and docs lived in fbcode; every iteration required `jf submit --draft` + review (hours-days throughput). Migration moved canonical state to notes for instant iteration (`sl push --to user/dennyzhang`, no review). But fbcode mirror still needs to be current because:
1. `bootstrap.sh` (devserver reinstall) runs `setup-cron-jobs.sh` which reads from fbcode.
2. Phabricator audit trail / disaster recovery.
3. Operators searching code via fbgs expect fbcode to reflect current state.

This cron resolves that by treating fbcode as a lagging-by-≤6h mirror of notes. RADAR auto-stamp on additive doc-only diffs typically lands within minutes.

## Learned Rules (auto-appended)

- 2026-05-22 (post-incident): Diff submission moved OUT of this cron into `ot-notes-fbcode-sync-weekly`. Root cause: prior regime unconditionally `jf submit`d every 6h run, producing 3 stacked diffs in one day after a failure-recovery cycle (D106052922 + D106080932 [abandoned] + D106084230 [abandoned]). Folded the stack into D106052922 and split the cron. See decision in thread `zv128jeH6Q8`.
