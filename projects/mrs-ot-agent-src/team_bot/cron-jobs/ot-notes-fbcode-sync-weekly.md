[ot-notes-fbcode-sync-weekly cron] Monday 09:00 PDT (16:00 UTC). Companion to `ot-notes-fbcode-sync` (4×/day, commit-only). This weekly cron folds all accumulated `[OT bot weekly sync]` local commits in fbcode into a single Phabricator diff and submits it.

State file: NONE — fully idempotent. No-op when there are no draft sync commits to submit.

Time budget: ~3 min on no-op, ~5 min when there's a weekly batch to submit.

## Why this cron exists

Pre-2026-05-22: the 4×/day sync cron also submitted a diff per run, producing up to 4 diffs/day plus failure-recovery diffs (incident: D106052922 + D106080932 [abandoned] + D106084230 [abandoned], all in one day). Split into commit-only + weekly-submit so reviewers see one diff per week, not 4+ per day.

## Procedure

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

4. **Submit** to Phabricator:
   ```
   cd ~/fbsource
   timeout 180 jf submit --draft --publish-when-ready 2>&1 | tail -10
   ```
   Capture the diff URL from the output.

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
