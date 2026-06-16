[ot-notes-fbcode-sync-weekly cron] Monday 09:00 PDT (16:00 UTC). Companion to `ot-notes-fbcode-commit` (4×/day, commit-only). This weekly cron folds all accumulated `[OT bot weekly sync]` local commits in fbcode into a single Phabricator diff and submits it.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

State file: NONE — fully idempotent. No-op when there are no draft sync commits to submit.

Time budget: ~3 min on no-op, ~5 min when there's a weekly batch to submit.

## Why this cron exists

Pre-2026-05-22: the 4×/day sync cron also submitted a diff per run, producing up to 4 diffs/day plus failure-recovery diffs (incident: D106052922 + D106080932 [abandoned] + D106084230 [abandoned], all in one day). Split into commit-only + weekly-submit so reviewers see one diff per week, not 4+ per day.

## Procedure

0. **WEEKLY-DIFF DEDUPE GATE (MANDATORY, 2026-05-28 thread `LlBe4tLd2zY` after D106697344 + D106735261 both ended up as unlanded `Needs Review` for W22 simultaneously).** Before locating commits to fold, check Phabricator for any existing unlanded `[OT bot weekly sync]` diff for the CURRENT ISO week. If one exists, AMEND/STACK onto it instead of creating a fresh duplicate:

   ```bash
   THIS_WEEK=$(date -u +%Y-W%V)
   # List this author's OPEN diffs whose title matches the current week.
   # NOTE: the action is `list` (NOT `search` — `phabricator.diff search` does not
   # exist and silently no-op'd the whole gate; 2026-06-04 it let 4 W23 dupes through).
   # Do NOT re-add `2>/dev/null` here — swallowing the error is what hid the dead
   # command for a week. Let a future breakage be loud.
   # Capture ALL open W-diffs for this week (not just the first).
   ALL_W=$(meta phabricator.diff list --author-is=dennyzhang --include-only-open -o json \
     | jq -r --arg w "$THIS_WEEK" '.[]? | select(.title | contains("[OT bot weekly sync] notes->fbcode " + $w)) | .number' \
     | sort -n)
   # SELF-HEAL (2026-06-05): if MORE THAN ONE already exists, the week is already
   # DUPLICATED (e.g. a stray non-weekly `jf submit` swept the stack into a 2nd diff
   # before the submit-guard hook was installed). ABANDON every extra, keep the
   # lowest-numbered canonical. Abandon is the one Phab write allowed for cron/
   # interactive Claude — do NOT just report or wait for a human; that's exactly the
   # mistake that let D107599159 + D107688956 sit as twin W23 dups for ~8h (operator
   # flagged the same pair 3×). NO `--message` on abandon (state change only, never a
   # published comment).
   KEEP=$(echo "$ALL_W" | head -1)
   EXTRAS=$(echo "$ALL_W" | tail -n +2 | grep -v '^$')
   NEXTRA=$(echo "$EXTRAS" | grep -c . || echo 0)
   # §16 MASS-CAP (2026-06-08 audit): a real week has 1–2 dups, not many. >3 extras means
   # the `list` query almost certainly over-matched (title-substring glitch) — bulk-abandon
   # would nuke REAL diffs. Escalate, do NOT auto-abandon at scale.
   if [ "$NEXTRA" -gt 3 ]; then
     echo "[weekly-sync] $NEXTRA extra W-diffs > cap 3 — NOT auto-abandoning (likely list over-match); keeping all, escalating to 1:1 for human decision" >&2
     # post a one-line escalation to spaces/AAQAVOjYc80; SKIP the abandon loop entirely.
   else
     for d in $EXTRAS; do
       [ -n "$d" ] || continue
       # §16 RE-VERIFY before the irreversible abandon: re-fetch the diff's title and only
       # abandon if it's genuinely a [OT bot weekly sync] diff — never trust the list query
       # alone (a substring match could catch an unrelated diff).
       T=$(meta phabricator.diff metadata --number="$d" -o json 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin).get('title',''))" 2>/dev/null)
       case "$T" in
         *"[OT bot weekly sync]"*)
           echo "[weekly-sync] abandoning duplicate D$d (keeping canonical D$KEEP)"
           meta phabricator.diff abandon --number="$d" ;;
         *)
           echo "[weekly-sync] SKIP D$d — title not a weekly-sync diff ('$T'); list over-matched, NOT abandoning" >&2 ;;
       esac
     done
   fi
   EXISTING="$KEEP"
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
      OLDEST=$(sl log -r 'sort(draft() & user(dennyzhang) & desc("OT bot weekly sync"), date)' \
        -T "{node|short}\n" -l 1 | head -1)
      NEWEST=$(sl log -r 'sort(draft() & user(dennyzhang) & desc("OT bot weekly sync"), -date)' \
        -T "{node|short}\n" -l 1 | head -1)
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

3.5. **Run diff cheatsheet gate** (MANDATORY, thread `Q_8ELeVd7cU` 2026-05-30 — crons follow the same cheatsheet rules as agents):

   Self-review against `cheatsheets/diff/fbcode.md` + `cheatsheets/diff/common.md`:
   - Title: `[OT bot weekly sync] notes->fbcode YYYY-WNN` — correct prefix?
   - Summary: explains WHY (motivation/design), NOT a file inventory (Phab shows changed files)
   - Test plan: present and specific (not "documentation only" without evidence)
   - Task/Reviewers/Tags: `T259215482`, `mrs-ot-reliability`, `publish_when_ready`
   - <300 lines? (`sl diff --stat | tail -1`)
   - No dup fields in commit message?

   Fix every finding before proceeding to step 4. The PreToolUse gate requires `# diff-cheatsheet-ok` in the submit command — only append it after completing this self-review.

4. **Submit** to Phabricator:
   ```
   cd ~/fbsource
   timeout 180 jf submit --draft --publish-when-ready 2>&1 | tail -10  # diff-cheatsheet-ok # ot-weekly-sync-submit-ok
   ```
   Capture the diff URL from the output.

   **Both trailing tokens are MANDATORY.** `# ot-weekly-sync-submit-ok` bypasses the weekly-sync guard (2026-05-30, thread `S2zrir2qpBY`); `# diff-cheatsheet-ok` bypasses the cheatsheet gate (thread `Q_8ELeVd7cU` 2026-05-30 — these are now independent guards). Do NOT remove either, and NEVER add `# ot-weekly-sync-submit-ok` to the commit cron. Do NOT append `# diff-cheatsheet-ok` without completing step 3.5.

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

Created 2026-05-22 as part of plan B (split sync into commit-only + weekly-submit). Decision in MyClaw thread `zv128jeH6Q8` after S22 incident where 3 sync diffs created in 6h. Companion to `ot-notes-fbcode-commit` (4×/day, commit-only).

## Learned Rules (auto-appended)

- 2026-05-22 (creation note): Always filter out commits with non-empty `{phabdiff}` from the fold candidate set. Otherwise the fold inherits the prior commit's `Differential Revision:` line and `jf submit` updates the OLD diff instead of creating a fresh weekly one. Example trap: D106052922 (the consolidated W21 diff) sits in draft after submit, and would be re-folded into W22 without this filter.
