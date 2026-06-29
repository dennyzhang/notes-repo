[ot-notes-fbcode-sync-weekly cron] Monday 09:00 PDT (16:00 UTC). Companion to `ot-notes-fbcode-sync` (4×/day, commit-only). This weekly cron folds all accumulated `[OT bot weekly sync]` local commits in fbcode into a single Phabricator diff and submits it.

State file: NONE — fully idempotent. No-op when there are no draft sync commits to submit.

Time budget: ~3 min on no-op, ~5 min when there's a weekly batch to submit.

## Why this cron exists

Pre-2026-05-22: the 4×/day sync cron also submitted a diff per run, producing up to 4 diffs/day plus failure-recovery diffs (incident: D106052922 + D106080932 [abandoned] + D106084230 [abandoned], all in one day). Split into commit-only + weekly-submit so reviewers see one diff per week, not 4+ per day.

## Procedure

0. **WEEKLY-DIFF DEDUPE GATE (MANDATORY, 2026-05-28 thread `LlBe4tLd2zY` after D106697344 + D106735261 both ended up as unlanded `Needs Review` for W22 simultaneously).** Before locating commits to fold, check Phabricator for any existing unlanded `[OT bot weekly sync]` diff for the CURRENT ISO week. If one exists, AMEND/STACK onto it instead of creating a fresh duplicate:

   ```bash
   THIS_WEEK=$(date -u +%Y-W%V)
   # Search Phab for unlanded diffs by this author whose title matches the current week.
   # FIX 2026-06-21: was `meta phabricator.diff search --author=… --status=needs-review,changes-planned`,
   # but `search` is NOT a valid action for phabricator.diff (errored) and `2>/dev/null` swallowed it ->
   # EXISTING was ALWAYS empty -> this "MANDATORY dedup gate" was a silent no-op since written ->
   # a fresh `[OT bot weekly sync] <week>` diff on every (re)trigger (W25 pile-up: D109095236 /
   # D109226976 / D109245016). Use the working `phabricator.diff list`; strip the leading D from .number
   # so downstream `D$EXISTING` resolves correctly. VERIFY with `meta phabricator.diff <action> --help`
   # before changing this query again.
   EXISTING=$(meta phabricator.diff list --author-is=dennyzhang --include-only-open -o json 2>/dev/null \
     | jq -r --arg w "$THIS_WEEK" '.[]? | select(.title | contains("[OT bot weekly sync] notes->fbcode " + $w)) | .number | ltrimstr("D")' \
     | head -1)
   if [ -n "$EXISTING" ]; then
     # Existing unlanded weekly diff for this week. Two safe responses:
     # (a) AMEND mode: jump to that diff's local commit (if present) and add fresh drift onto it (preferred).
     # (b) ESCALATE mode: if local commit isn't present (e.g. different devserver), post a one-line gchat
     #     "⚠️ [weekly-sync] D$EXISTING already unlanded for $THIS_WEEK — skipping new submit to avoid duplicate.
     #      Land/abandon D$EXISTING and re-run, or amend it manually." and exit clean.
     # AMEND attempt:
     LOCAL=$(sl log -r "draft() & desc('Differential Revision: https://phabricator.intern.facebook.com/D$EXISTING')" \
       -T '{node|short}\n' 2>/dev/null | head -1)
     if [ -n "$LOCAL" ]; then
       echo "[weekly-sync] amending D$EXISTING (commit $LOCAL) instead of creating duplicate"
       sl goto "$LOCAL" --reason "amend onto existing weekly-sync diff to avoid duplicate - sl help goto"
       # Proceed with step 1 below, but skip the `sl fold` step c (no new-commit-to-fold; just sl amend onto $LOCAL)
       export WEEKLY_AMEND_MODE=1
     else
       meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --as-meta-bot --text="⚠️ [weekly-sync] D$EXISTING already unlanded for $THIS_WEEK on Phab but no local commit on this devserver — skipping new submit to avoid duplicate. Land/abandon D$EXISTING and re-run."
       exit 0
     fi
   fi
   ```

   **Why this gate matters:** D106697344 (Thu 13:06 PT, 54 files) and D106735261 (Thu 18:15 PT, 72 files) both ended up `Needs Review` for W22 because the cron at 18:15 didn't check for an existing unlanded weekly diff before submitting. The `phabdiff` filter in step 1 prevents re-folding ALREADY-SUBMITTED local commits, but it doesn't prevent creating a fresh diff when intra-week 4×/day commits accumulate on top. Result: reviewers had two parallel weekly diffs for the same week with overlapping content (D106735261 is a superset of D106697344). Dedupe gate makes the cron idempotent at the week level, not just the commit level.

1. **Locate accumulated sync commits** in fbcode draft stack, **excluding any commit that already has a phabdiff** (those are already submitted; folding them would update an old diff rather than create a fresh weekly one):
   ```
   cd ~/fbsource
   sl log -r 'draft() & user(dennyzhang) & desc("OT bot weekly sync")' \
     -T "{node|short} | {phabdiff} | {desc|firstline}\n" -l 20
   ```
   Filter out any row where phabdiff is non-empty. Only fold the un-submitted commits.

   Example output filtering: skip `3cecc7ff4e69 | D106052922 | ...` (already submitted); keep `abc1234 |  | [OT bot weekly sync] notes->fbcode 2026-W22` (no phabdiff).

2. **Three possible outcomes:**

   a. **No commits found** → no weekly batch to submit. Respond HEARTBEAT_OK. NO GChat message.

   b. **Exactly 1 commit** → no fold needed; jump to step 4.

   c. **≥2 commits** → fold them. The oldest commit is the base; fold all subsequent ones into it:
      ```
      cd ~/fbsource
      OLDEST=$(sl log -r 'draft() & user(dennyzhang) & desc("OT bot weekly sync")' \
        -T "{node|short}\n" --sort=date -l 1 | head -1)
      NEWEST=$(sl log -r 'draft() & user(dennyzhang) & desc("OT bot weekly sync")' \
        -T "{node|short}\n" --sort=-date -l 1 | head -1)
      sl fold --exact -r "$OLDEST::$NEWEST" --message "$(cat <<EOF
      [OT bot weekly sync] notes->fbcode $(date -u +%Y-W%V)

      Summary:
      - **Why**: notes is canonical for OT-bot prompts/docs (post-2026-05-15 migration). Weekly batch sync to fbcode mirror so devserver reinstalls bootstrapping from fbcode get fresh prompts.
      - **Fix**: $(sl status --change . | wc -l) file(s) folded from N intra-week commits into single weekly diff.
      - **Scope**: doc/prompt only. Code paths (src/, tests/, BUCK, .llms/) untouched.

      Test Plan:
      - Pure notes->fbcode mirror. Notes is source of truth.
      - Verify: \`diff -r ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/<path> ~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/<path>\` returns no output for each synced file.

      Reviewers: mrs-ot-reliability

      Tasks: T259215482

      Tags: publish_when_ready
      EOF
      )"
      ```

3. **Verify** the resulting single commit (`sl log -r . -T "{node|short} {desc|firstline}\n"`).

3.5. **BUILD FRESH ON CURRENT TRUNK — conflict-free BY CONSTRUCTION (operator 2026-06-21: "weekly sync diff always runs into merge conflict").** Weekly-sync is a ONE-WAY MIRROR (notes→fbcode, notes canonical), so the diff is just "current notes vs current trunk." Merge conflicts only happened because we REBASED the week-old folded commit onto moved trunk. Instead, **rebuild the commit fresh on current trunk** — a fresh commit has no merge step, so a conflict is structurally impossible. This SUPERSEDES the fold output of steps 1–3 (they still run harmlessly; this discards their stale-based commit and rebuilds).

   **(a) DRIFT GATE FIRST — data safety (notes is not yet canonical-current everywhere; do NOT overwrite trunk-ahead content).** For each shared multi-author file, if trunk has content notes lacks, abort + escalate:
   ```bash
   cd ~/fbsource; sl pull -q
   DRIFT=""
   for f in team_bot/CLAUDE.md team_bot/cron-jobs/MANIFEST.json team_bot/team_bot_config.yaml; do
     fb="pe_mrs_ml/mrs_ot_agent/$f"; nt="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/$f"
     [ -f "$nt" ] || continue
     # lines present in trunk but NOT in notes == trunk-ahead content the mirror would silently drop
     if [ -n "$(comm -23 <(sl cat -r remote/master "$fb" 2>/dev/null | sort -u) <(sort -u "$nt") | head -1)" ]; then DRIFT="$DRIFT $f"; fi
   done
   if [ -n "$DRIFT" ]; then
     meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --as-meta-bot \
       --text="WARN [weekly-sync] trunk is AHEAD of notes on:$DRIFT — build-fresh would drop trunk-only content. Skipping submit; needs the notes<->fbcode reconciliation first (notes not yet canonical-current)."
     exit 0
   fi
   ```
   **(b) BUILD FRESH on current trunk:**
   ```bash
   sl goto -C remote/master    # clean base on current trunk; discards the stale-based folded commit
   bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/notes-to-fbcode-sync.sh
   #  ^ copies all canonical notes files -> fbcode + commits ONE fresh commit on current trunk.
   #    "[no drift]" (notes already == trunk) -> nothing to submit -> respond HEARTBEAT_OK, exit.
   ```
   **(c) DEDUP carry — if step-0 found an open W## diff ($EXISTING), tag the fresh commit so step 4 UPDATES it (never a 2nd):**
   ```bash
   [ -n "$EXISTING" ] && sl metaedit -r . -m "$(sl log -r . -T '{desc}')

   Differential Revision: https://phabricator.intern.facebook.com/D$EXISTING"
   ```
   Conflict-free (fresh commit on trunk), data-safe (drift gate), dedup-safe (carries $EXISTING). When notes is canonical-current this runs clean weekly; while notes is still stale vs trunk it safely aborts (same as today's sync crons) — no data loss, no bad merge.

4. **Submit** to Phabricator (dedup-aware):
   ```
   cd ~/fbsource
   if [ -n "$EXISTING" ]; then
     # fresh commit already carries D$EXISTING's Differential Revision (step 3.5c) -> UPDATE it, never a 2nd
     timeout 180 jf submit --update-fields 2>&1 | tail -10
   else
     timeout 180 jf submit --draft --publish-when-ready 2>&1 | tail -10
   fi
   ```
   Capture the diff URL from the output. (The weekly-sync-dedup PreToolUse hook is the backstop: it blocks any `jf submit` that would create a 2nd open W## diff.)

5. **Send ONE GChat message** to spaces/AAQAVOjYc80:
   ```
   📅 [notes->fbcode weekly sync] W<num>: N file(s) folded from M commit(s) → D<num>: https://www.internalfb.com/diff/D<num>
   ```
   Then HEARTBEAT_OK.

## Failure modes

| Symptom | Cause | Recovery |
|---|---|---|
| `sl fold` fails: "commits are not linear" | Some commits in the range have descendants outside the sync stack | Manual operator intervention; surface error to chat |
| `jf submit` fails with "untracked changes" warning | Bot state files leaked into working copy | Ignore — that's not a hard failure; the submit still produces the diff |
| `jf submit` fails with "Root is too far behind" | fbcode mirror is too stale vs. public | Run `sl pull && sl rebase -d public` first; if still fails, surface to operator |

## Safety rules

- **NEVER call `jf submit` outside step 4.** Other crons must use `--no-submit`.
- **NEVER touch files outside `fbcode/pe_mrs_ml/mrs_ot_agent/`** — the fold should not pick up unrelated commits because the filter `desc("OT bot weekly sync")` excludes them.
- **Cap 1 diff per run.** Fold all `[OT bot weekly sync]` draft commits into one; produce one Phabricator diff.
- **Skip if working copy dirty in target dir** — log warning, recommend manual cleanup, exit clean. Don't fold into a dirty state.
- **Never call gchat.message.create directly** — system auto-delivers final response.

## Provenance

Created 2026-05-22 as part of plan B (split sync into commit-only + weekly-submit). Decision in MyClaw thread `zv128jeH6Q8` after S22 incident where 3 sync diffs created in 6h. Companion to `ot-notes-fbcode-sync` (4×/day, commit-only).

## Learned Rules (auto-appended)

- 2026-05-22 (creation note): Always filter out commits with non-empty `{phabdiff}` from the fold candidate set. Otherwise the fold inherits the prior commit's `Differential Revision:` line and `jf submit` updates the OLD diff instead of creating a fresh weekly one. Example trap: D106052922 (the consolidated W21 diff) sits in draft after submit, and would be re-folded into W22 without this filter.
