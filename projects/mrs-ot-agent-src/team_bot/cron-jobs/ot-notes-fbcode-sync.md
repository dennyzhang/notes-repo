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

   c. **Auto-recovery applied (script stderr contains `auto-recovery: N dirty file(s) match notes`)** — script succeeded after silently reverting N stray fbcode writes that matched notes. Same gchat as case (b) with prefix `🔁 [notes->fbcode sync] auto-recovered N stray write(s) → N file(s) committed locally`. Then HEARTBEAT_OK.

   d. **Failure (any non-zero exit)** — capture last 20 lines of script stderr + non-zero exit code. Send ONE GChat message:
      ```
      ⚠️ [notes->fbcode sync] FAILED — exit=<code>. Last lines:
      <stderr tail>
      ```
      Then HEARTBEAT_OK. Do NOT loop.

## Safety rules

- **SHARED-FILE TRUNK-DRIFT GATE (MANDATORY, 2026-05-28 thread `LlBe4tLd2zY`).** Before the sync script runs (step 1), for every file in the shared-multi-author allow-list below, compare its CURRENT notes content to fbcode trunk. If trunk has content notes doesn't, ABORT this run with a gchat escalation — do NOT let the mirror proceed and silently overwrite trunk-only content.

  ```bash
  # Run at the very top of step 1, BEFORE invoking notes-to-fbcode-sync.sh
  cd /home/dennyzhang/fbsource
  SHARED_FILES=(
    "fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/CLAUDE.md"
    "fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/cron-jobs/MANIFEST.json"
    "fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/team_bot_config.yaml"
  )
  DRIFT_HITS=()
  for fbcode_file in "${SHARED_FILES[@]}"; do
    notes_file="/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/${fbcode_file#fbcode/pe_mrs_ml/mrs_ot_agent/}"
    if [ ! -f "$notes_file" ]; then continue; fi
    # Trunk-only lines = lines in trunk but NOT in notes (notes would silently drop them)
    TRUNK_ONLY=$(diff <(sl cat -r 'remote/master' "$fbcode_file" 2>/dev/null) "$notes_file" 2>/dev/null | grep -cE '^< ' || echo 0)
    if [ "$TRUNK_ONLY" -gt 5 ]; then
      DRIFT_HITS+=("$fbcode_file: trunk has $TRUNK_ONLY lines notes lacks")
    fi
  done
  if [ ${#DRIFT_HITS[@]} -gt 0 ]; then
    msg="⚠️ [notes->fbcode sync] ABORTED — trunk-drift on shared multi-author file(s):
$(printf '  - %s\n' "${DRIFT_HITS[@]}")
Notes is stale vs trunk for these files. Mirror would silently drop trunk-only content (cf. D106716098 2026-05-28: dropped 10 MANIFEST entries + 2 CLAUDE.md sections).
*Recovery:* for each drifted file, pull trunk (\`sl cat -r remote/master <file>\`) into notes, then re-run this cron. OR: patch-don't-replace via a manual diff that only adds the additive change."
    meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --as-meta-bot --text="$msg"
    exit 0  # HEARTBEAT_OK after escalation — DO NOT proceed to commit
  fi
  ```

  **Why threshold = 5 lines:** small diffs are usually whitespace/comments; ≥5 trunk-only lines indicates a real content gap. Tune via post-incident review.

  **Shared-file allow-list rationale:** these are multi-author registry/spec files where fbcode receives direct edits from non-OT-bot authors (Phase A backports, manual operator edits). Cron prompts (`ot-*-monitor.md`) are notes-canonical-only and safe to mirror without check.

- **Precondition with auto-recovery**: fbcode/pe_mrs_ml/mrs_ot_agent/ working copy must be clean before commit. If dirty, script auto-classifies each dirty file:
  - **Identical to notes** → auto-reverts (notes is SoT; content is already preserved; the dirty write was a stray duplicate, e.g. heartbeat double-write). Continues to copy phase. NO operator escalation.
  - **Divergent from notes** → escalates with exit=1 and prints both lists (divergent paths require manual decision: backport to notes vs revert). This protects against folding stray edits into the auto-sync diff.

  Rationale (2026-05-28, thread `q-ZstjwGxlY`): the old behavior aborted on ANY dirty file even when content was already in notes, requiring operator to manually `sl revert` for cosmetic blockages. Auto-recovery is safe because identical-content reverts are no-ops semantically.
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
- 2026-05-28 (auto-recovery for stray fbcode writes): Sync used to fail any time fbcode was dirty, even when content matched notes. Today's heartbeat double-wrote daily-brief.md into both notes and fbcode → sync aborted, operator had to manually `sl revert`. Fixed by adding per-file content classification: dirty-AND-identical-to-notes → auto-revert silently and proceed; dirty-AND-divergent → still escalate. Notes-as-SoT principle makes auto-revert safe (no content loss). Thread `q-ZstjwGxlY`.
- 2026-05-28 (newline-normalized cmp fallback): Today 12:17 PT sync failed on `daily-brief.md` even though content matched notes exactly. Root cause: `cmp -s` is byte-exact; trailing-newline drift from heartbeat double-write defeats it. Fix added to `notes-to-fbcode-sync.sh`: when `cmp -s` fails, retry with both sides normalized via awk (final-newline-tolerant). Identical-after-normalization → still classified as identical → auto-revert. Eliminates the most common false-divergent classification. If still divergent after normalization → escalate as before (real content drift). Generalizes the "small fix should auto-heal" principle per Denny's directive in team-space thread (2026-05-28).
