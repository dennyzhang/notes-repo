[ot-notes-fbcode-commit cron] 4×/day. One-way mirror of canonical notes prompts/docs to the fbcode pe_mrs_ml/mrs_ot_agent path. Notes is canonical (post-2026-05-15 migration); this cron keeps the fbcode mirror current so devserver reinstalls bootstrapping from fbcode get fresh prompts.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

**This cron COMMITS LOCALLY but does NOT submit a diff.** Diff submission happens once per week via the companion `ot-notes-fbcode-sync-weekly` cron (Monday 09:00 PDT), which folds all `[OT bot weekly sync]` commits accumulated during the week into a single Phabricator diff. Splitting commit-from-submit prevents intra-week diff proliferation (e.g., the May 22 incident where 3 diffs were created in 6h).

State file: NONE — sync script is fully idempotent. No-op on no-drift.

Time budget: ~2 min on no-drift, ~3 min when there's drift to commit.

## Procedure

1. **ONE-WEEKLY-COMMIT WIRING — amend this week's commit, never create a new one per run (THE fix for duplicate sync diffs, 2026-06-04 thread `aenMMohDz0c`: operator "by design your automation should only create one sync diff per week").** Before this fix the cron ran the script in new-commit mode every run → a fresh `[OT bot weekly sync]` commit per run → duplicate diffs. The script HAS `--amend-commit`; this step WIRES it:
   ```bash
   cd ~/fbsource
   CUR_WEEK=$(date -u +%Y-W%V)
   STATE=~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-notes-commit-push-state.json
   PRIOR_WEEK=$(python3 -c "import json;print(json.load(open('$STATE')).get('week_tag',''))" 2>/dev/null || echo "")
   PRIOR_HASH=$(python3 -c "import json;print(json.load(open('$STATE')).get('week_commit_hash',''))" 2>/dev/null || echo "")
   AMEND=""
   # Amend ONLY if same ISO week AND the tracked commit still resolves to a
   # non-obsolete draft (a jf-submit/amend can obsolete it → fall back to new,
   # the staleness that caused the 2026-06-04 respawn).
   if [ "$PRIOR_WEEK" = "$CUR_WEEK" ] && [ -n "$PRIOR_HASH" ] \
      && sl log -r "$PRIOR_HASH" -T '{phase}' 2>/dev/null | grep -q draft \
      && [ "$(sl log -r "$PRIOR_HASH" -T '{obsolete}' 2>/dev/null)" != "obsolete" ]; then
     AMEND="--amend-commit=$PRIOR_HASH"
   fi
   OUT=$(bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/notes-to-fbcode-sync.sh --no-submit $AMEND --week="$CUR_WEEK" 2>&1)
   echo "$OUT"
   ```
   The script already titles the commit `[OT bot weekly sync] notes->fbcode <week>` (no message rewrite needed). `[no drift]` in `$OUT` → no commit → `HEARTBEAT_OK` (skip step 2).

2. **Persist the week's commit hash to state (so the NEXT run amends THIS commit, not a new one).** Parse `COMMIT_HASH=<7char>` from `$OUT`; write it + the week tag back:
   ```bash
   NEW_HASH=$(printf '%s\n' "$OUT" | grep -oE 'COMMIT_HASH=[0-9a-f]+' | head -1 | cut -d= -f2)
   [ -n "$NEW_HASH" ] && python3 -c "import json,sys; p='$STATE'; d=json.load(open(p)); d['week_tag']='$CUR_WEEK'; d['week_commit_hash']='$NEW_HASH'; json.dump(d,open(p,'w'),indent=2)"
   ```
   Without this persist the amend-wiring in step 1 has nothing to find next run → it would respawn a new commit (the original bug). This is the load-bearing line.

3. Three possible outcomes:

   **DELIVERY DISCIPLINE (2026-05-30, thread `uT4ZGx2_Pao`: operator — "why I shall care about this? if not, why you send it to me?").** A successful local commit is INTERNAL mechanics with no action for the operator — it must NEVER post to GChat. Stay SILENT on success; post ONLY on failure. Never make an explicit `meta google.chat.message send` call (the daemon auto-delivers the final response — an explicit send double-posts).

   a. **No drift** — script exits `[notes-to-fbcode-sync] no drift; fbcode mirror is up to date.` → respond `HEARTBEAT_OK`. NO GChat message.

   b. **Drift + local commit** — script copies N files, runs `sl commit` (NO `jf submit` because `--no-submit`). After commit-message rewrite (step 2), respond `HEARTBEAT_OK {committed: N, rev: <node|short>}`. **NO GChat message** (silent — internal mechanics).

   c. **Auto-recovery applied (script stderr contains `auto-recovery: N dirty file(s) match notes`)** — script succeeded after silently reverting N stray fbcode writes that matched notes. Respond `HEARTBEAT_OK {auto_recovered: N, committed: M}`. **NO GChat message** (silent).

   d. **Failure (any non-zero exit)** — capture last 20 lines of script stderr + non-zero exit code. This is actionable, so surface it — emit (as your FINAL RESPONSE, which the daemon delivers; do NOT call `meta google.chat.message send`) exactly:
      ```
      ⚠️ [notes->fbcode commit] FAILED — exit=<code>. Last lines:
      <stderr tail>
      ```
      Do NOT loop.

## Safety rules

- **SHARED-FILE TRUNK-DRIFT GATE (MANDATORY, 2026-05-28 thread `LlBe4tLd2zY`; made DIRECTIONAL 2026-06-06).** Before the sync script runs (step 1), for every file in the shared-multi-author allow-list below, compare its CURRENT notes content to fbcode trunk. The gate must fire ONLY on real droppable trunk content (trunk has it, notes doesn't), NOT on the expected notes-ahead state (notes is the SoT, so a newer notes value / a stale line notes removed is the mirror's normal job — gating on it false-positives every notes-side edit, which HELD the sync repeatedly through 2026-06-06). Therefore: **JSON → HARD abort on missing ENTRIES only** (`missing_ids`; a changed field value is notes-ahead, never gated). **Text → ADVISORY only** (a line-diff can't tell "notes removed stale" from "trunk added new", and the merge-base 3-way that could is too expensive to compute — so warn + proceed; notes is SoT and the pre-overwrite backup is the recovery net for a rare real trunk-direct-edit).

  ```bash
  # Run at the very top of step 1, BEFORE invoking notes-to-fbcode-sync.sh
  cd /home/dennyzhang/fbsource
  SHARED_FILES=(
    "fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/CLAUDE.md"
    "fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/cron-jobs/MANIFEST.json"
    "fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/team_bot_config.yaml"
  )
  DRIFT_HITS=()    # JSON structural drift → HARD abort
  TEXT_WARN=()     # text line-drift → advisory only (proceed)
  for fbcode_file in "${SHARED_FILES[@]}"; do
    notes_file="/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/${fbcode_file#fbcode/pe_mrs_ml/mrs_ot_agent/}"
    if [ ! -f "$notes_file" ]; then continue; fi
    case "$fbcode_file" in
      *.json)
        # JSON-AWARE compare (2026-05-29 thread `ft3uqm8w20o`): a raw line-diff
        # false-positives on encoding differences — notes serialized with
        # ensure_ascii=True (—) vs trunk's raw UTF-8 (—) are byte-different
        # but structurally identical, which aborted the sync forever. Compare the
        # PARSED structure instead: a trunk job id / field absent from notes is
        # real drift; an encoding-only difference is not. (MANIFEST.json schema:
        # {"jobs":[{"id":...}, ...]} — generalize gracefully if schema differs.)
        TRUNK_ONLY=$(python3 - "$fbcode_file" "$notes_file" <<'PYJSON'
import json, subprocess, sys
fb, nf = sys.argv[1], sys.argv[2]
trunk = json.loads(subprocess.run(['sl','cat','-r','remote/master',fb],capture_output=True,text=True).stdout or '{}')
notes = json.load(open(nf, encoding='utf-8'))
def jobs(m): return {j.get('id'): j for j in m.get('jobs', [])} if isinstance(m, dict) else {}
tj, nj = jobs(trunk), jobs(notes)
# Acknowledged intentional renames: trunk still carries the OLD id until the
# fbcode rename diff lands, so a renamed-away id is NOT a silent drop. Prune an
# entry once trunk MANIFEST has caught up to the new name. (2026-05-30 thread
# S2zrir2qpBY: ot-notes-fbcode-sync -> ot-notes-fbcode-commit.)
KNOWN_RENAMED_AWAY = {"ot-notes-fbcode-sync", "ot-disk-watch", "ot-cron-health-watch", "ot-fbpkg-cap-watch", "ot-human-attention-brief", "context-ingestor-gchat", "context-ingestor-posts", "ot-gdoc-context-sync", "ot-ingest-gdoc"}  # ot-disk-watch -> server-disk-guard (2026-06-02); ot-cron-health-watch -> ot-cron-health-guard (2026-06-07, scope expanded watch->guard: auto-mitigate + root-fix); ot-fbpkg-cap-watch -> DEPRECATED 2026-06-08 (light_cli version-cap-pressure monitoring dark); ot-human-attention-brief -> DEPRECATED 2026-06-09, absorbed into daily-brief (superset: §4 AI-needs-help + §6 learnings) — verified NOT a job entry in notes MANIFEST, last run 2026-06-09 08:05. context-ingestor-gchat -> ot-ingest-gchat (2026-06-13 rename); context-ingestor-posts -> ot-ingest-posts (2026-06-13 rename); ot-gdoc-context-sync -> ot-ingest-gdoc -> ot-ingest-gdocs (renames); diffs split out to ot-ingest-diffs (all 2026-06-13). Trunk MANIFEST still carries old ids until rename/remove lands.
missing_ids = (set(tj) - set(nj)) - KNOWN_RENAMED_AWAY           # trunk job ids notes genuinely lacks
# field_drift (shared id, value differs) is NOT droppable trunk content. notes is the
# SoT, so a changed field value is notes-AHEAD (exactly what the mirror exists to
# propagate), not a silent drop. Gating on it false-positived every notes-side field
# edit (2026-06-06: MANIFEST interval=900, cron daily, purpose-string edits HELD the
# sync). The D106716098 drop the gate exists for was missing ENTRIES (= missing_ids),
# never field values. Gate on missing_ids ONLY; field_drift is info, not a hold.
field_drift = sorted(i for i in set(tj) & set(nj) if tj[i] != nj[i])  # info only, NOT gated
print(len(missing_ids))
PYJSON
)
        ;;
      *)
        # Non-JSON (CLAUDE.md, .yaml): trunk-only lines = lines in trunk not in notes.
        # A raw line-diff CANNOT tell direction — "notes intentionally removed a stale
        # line" and "a human edited trunk directly" both render as trunk-only. The
        # disambiguator is a merge-base 3-way (compare both sides to the last-mirror
        # base), but the revset to find that base aborts (>100k-commit scan) — too
        # expensive in fbsource. So text drift is ADVISORY, not a hard hold: notes is
        # the SoT for these files and the sync writes a timestamped pre-overwrite
        # backup, so a rare real trunk-direct-edit is visible + recoverable. Hard
        # structural protection lives in the JSON gate (missing ENTRIES). This kills
        # the 2026-06-06 false-positive where 19 stale pre-migration CLAUDE.md lines
        # (notes correctly removed) HELD the sync.
        TRUNK_ONLY=$(diff <(sl cat -r 'remote/master' "$fbcode_file" 2>/dev/null) "$notes_file" 2>/dev/null | grep -cE '^< ' || echo 0)
        if [ "$TRUNK_ONLY" -gt 5 ]; then
          TEXT_WARN+=("$fbcode_file: $TRUNK_ONLY trunk-only line(s) — likely notes-ahead (stale removed); verify only if you made a trunk-direct edit")
        fi
        continue   # text files NEVER hard-abort; advisory only
        ;;
    esac
    # JSON gate (structural, exact): trunk has ENTRIES notes lacks = real droppable content.
    if [ "$TRUNK_ONLY" -gt 0 ]; then
      DRIFT_HITS+=("$fbcode_file: trunk has $TRUNK_ONLY entry(ies) notes lacks")
    fi
  done
  if [ ${#DRIFT_HITS[@]} -gt 0 ]; then
    msg="⚠️ [notes->fbcode sync] ABORTED — structural trunk-drift (trunk has entries notes lacks):
$(printf '  - %s\n' "${DRIFT_HITS[@]}")
Mirror would silently drop trunk-only entries (cf. D106716098 2026-05-28: dropped 10 MANIFEST entries).
*Recovery:* pull trunk (\`sl cat -r remote/master <file>\`) into notes, then re-run this cron. OR: patch-don't-replace via a manual additive diff."
    meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --as-meta-bot --text="$msg"
    exit 0  # HEARTBEAT_OK after escalation — DO NOT proceed to commit
  fi
  # Text drift is ADVISORY: log + PROCEED (mirror + pre-overwrite backup handle notes-ahead).
  if [ ${#TEXT_WARN[@]} -gt 0 ]; then
    printf '[notes->fbcode sync] text-drift advisory (proceeding):\n'
    printf '  - %s\n' "${TEXT_WARN[@]}"
  fi
  ```

  **Why JSON hard-gates and text only warns:** for `.json` the gate compares PARSED structure, and a trunk ENTRY (job id) absent from notes is unambiguous droppable content → HARD abort, threshold 0. For text (`CLAUDE.md`, `.yaml`) a raw line-diff is direction-blind: a trunk-only line is *usually* notes-ahead (notes removed a stale line) and only *rarely* a trunk-direct-edit, and the two are indistinguishable without a merge-base 3-way (which can't be computed — the revset to find the last-mirror base aborts on a >100k-commit scan). Hard-gating text therefore false-positives on every legitimate notes-side removal (2026-06-06: 19 stale pre-migration CLAUDE.md lines HELD the sync). So text is ADVISORY: warn + proceed, with the sync's timestamped pre-overwrite backup as the recovery net for a rare real trunk-edit. The JSON path was added 2026-05-29 (thread `ft3uqm8w20o`) after a raw line-diff false-positived on encoding alone (`\uXXXX`-escaped notes vs raw-UTF-8 trunk = byte-different, structurally identical) and aborted the sync every run. Keep notes JSON serialized as raw UTF-8 (`ensure_ascii=False`) to match trunk's style.

  **Shared-file allow-list rationale:** these are multi-author registry/spec files where fbcode receives direct edits from non-OT-bot authors (Phase A backports, manual operator edits). Cron prompts (`ot-*-monitor.md`) are notes-canonical-only and safe to mirror without check.

- **Precondition with auto-recovery**: fbcode/pe_mrs_ml/mrs_ot_agent/ working copy must be clean before commit. If dirty, script auto-classifies each dirty file:
  - **Identical to notes** → auto-reverts (notes is SoT; content is already preserved; the dirty write was a stray duplicate, e.g. heartbeat double-write). Continues to copy phase. NO operator escalation.
  - **Divergent from notes** → escalates with exit=1 and prints both lists (divergent paths require manual decision: backport to notes vs revert). This protects against folding stray edits into the auto-sync diff.

  - **DIRECTION-TRUTH + ANTI-CLOBBER when narrating a divergence escalation (2026-06-02, thread `BRcxJ7gSLzA`).** notes is GROUND TRUTH; fbcode is a mirror. When this escalation fires, describe it correctly and NEVER recommend a clobbering recovery:
    - **NEVER say "fbcode is newer" / "notes is stale" / "X missing from notes"** without verifying which side actually holds X. A divergent fbcode file means the *mirror drifted*, not that fbcode is authoritative.
    - **NEVER recommend `cp fbcode→notes` or `patch fbcode-diff → notes`.** Those OVERWRITE notes and delete any notes-only content. (2026-06-02: the escalation narrated a `cp fbcode→notes` recovery for `CLAUDE.md` that would have deleted 102 notes-only lines incl. the `Team-Chat Send Gate` — which the message falsely called "fbcode-newer / missing from notes" when it was notes-only.)
    - **Correct recovery = a MERGE, both directions checked:** for each divergent file, `diff fbcode notes`; capture the fbcode-only lines that are REAL new content INTO notes (preserving notes-only lines); discard fbcode-only lines that are stale/superseded; then the mirror `cp notes→fbcode` (or re-run this sync) makes fbcode match. If unsure whether fbcode-only content is real vs stale, escalate to operator with BOTH the fbcode-only AND notes-only line lists — never auto-pick a direction.

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

## Delivery discipline (HARD, 2026-05-30)

The daemon posts your final response to GChat verbatim unless it is EXACTLY `HEARTBEAT_OK`. Post ONLY on case (b) drift-committed or (c) auto-recovered (the one-line `🔁 [notes->fbcode sync]…` message) or (d) failure. On case (a) no-drift respond EXACTLY `HEARTBEAT_OK` and NOTHING else — no "commit message already correctly titled.", no "no rewrite needed.", no strategy explanation, no narration. Narration/no-op text leaks to chat as spam (operator 2026-05-30).

**Active-run cases (b), (c), (d) — same rule, made explicit (validator FAIL 2026-06-09 run_id=7771: multi-sentence narration still leaked because this rule only named case (a)):** send the one-line `🔁 …` / failure message via an EXPLICIT `meta google.chat.message send`, THEN the cron's FINAL RESPONSE must be EXACTLY `HEARTBEAT_OK {…}` with NOTHING before it — no "Commit landed.", no "Drift detected, committing…", no recap of what was synced. The one-liner is the only user-facing text and it goes via the explicit send, never as the final response.
