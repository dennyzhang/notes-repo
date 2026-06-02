# RULES.md - Denny's Standing Rules

Rules to remember and apply automatically. Add new ones as Denny calls them out.

## #1 — Always Load Team Bot Context

At the start of every session, read:
`~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/CLAUDE.md`

This is the canonical context for the OT team bot. Don't skip it.

**Also browse the principles catalog** at `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/principles/INDEX.md` — 15 agent-design principles distilled from operator feedback. Each principle = an anti-pattern previously caught. Read INDEX (~5min) before editing any cron prompt or shipping operator-facing output.

## GChat

**RULE #1 — Reply in the thread.** Operator-set (2026-05-16 thread `iqRw-QgzYjM`): dedicated discussions aggregate as threads; a reply landing top-level when the operator threaded splits one conversation. **Always check `thread_name` on the operator's most recent message before sending. If it ends in `/threads/<id>` → my reply belongs in that thread.** When in doubt, thread.

- **Critical anti-pattern (2026-05-16):** when operator posts INTO a thread, my reply MUST go back into the SAME thread. Replying at top-level when the operator threaded is a recurring mistake — operator flagged 3x tonight (threads `pKP57GxypBo` 12:25 PT, `pFlYRGd0q2c` 13:55 PT, `iqRw-QgzYjM` 14:07 PT).
- **How to verify:** before sending, check the `thread_name` of the operator's most recent message. If it ends in `/threads/<id>`, my reply belongs in that thread. If `thread_name=''` (empty), top-level is correct.
- **When operator's message and the topic-of-interest are in different threads** (rare — they explicitly redirect me): reply in the thread THEY just posted to, not the thread the topic originated in.
- **Full cheatsheet:** `~/notes/users/dennyzhang/cheatsheets/comms/gchat.md` § "RULE #1 — Reply in the thread."

### Enforcement: Thread-reply PreToolUse hook (2026-05-29, thread `GSSYzY7flFQ`)

Memory-level rules alone are insufficient — the bot ignores them under tool pressure. Rule #1 is enforced at the *harness layer* via a PreToolUse Bash hook in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/.claude/settings.json`.

**What it does:** Blocks any `meta google.chat.message send ... spaces/AAQAVOjYc80` invocation that lacks `--reply-in-thread`. Escape hatch: append `# new-topic` as a comment to confirm a genuinely new top-level thread.

**Persistence — on devserver reinstall:** `bootstrap.sh`'s `apply_space_hooks()` re-applies this hook idempotently after every reinstall. Run:
```
~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/bootstrap.sh
```

**Manual restore (if bootstrap unavailable):**
```bash
python3 ~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/apply-space-hooks.py \
  ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/.claude/settings.json
```

## Signal-only operator messaging — NO RECOVERY/NO-OP/HOUSEKEEPING PINGS (2026-05-17 thread `t6SQVo16dTY` "don't send me messages which have no value to me")

Every operator-facing gchat post must clear this bar: **operator must take an action OR learn something they didn't already know**. If neither is true, DO NOT POST. Write the run summary to `job_runs` and exit with `HEARTBEAT_OK`.

**Default-to-silent classes (NEVER post):**

- **Recovery pings** — "warning → ok" / "critical → ok" / "failure → healthy" transitions where the system self-resolved without operator intervention. The original alert was the signal; the recovery is just noise saying "the thing you got pinged about earlier is no longer a problem." Operator learns nothing new; no action required. The state file remembers; the operator doesn't need to.
  - *Exception:* recovery from a CRITICAL state that the operator was actively investigating (i.e., operator replied in-thread within last 4h). Then post recovery as threaded reply to the original alert thread — closes the loop in context.
- **No-op heartbeats** — "checked 25 things, all clean, 0 transitions, 0 alerts" runs. Pure cron-self-reporting. Write to `job_runs`, exit `HEARTBEAT_OK`, do not post.
- **State-file housekeeping** — "state baseline reset", "hash re-baselined", "suppressed repeat", "dedup window applied". Bot bookkeeping; not operator-actionable.
- **"Already alerted" / deduped follow-ups** — if an alert was posted earlier and the situation is unchanged, do NOT post a status update saying "still in same state." Silence = unchanged.

**Post-worthy classes (DO post):**

- New transition INTO warning/critical/failure (the first "this just broke" notification)
- New finding the operator hasn't seen (e.g., new chronic-noisy model, new cluster proposal, postmortem digest, validator FAIL)
- Persistent failure escalation (3+ consecutive ticks stuck — operator needs to intervene)
- Operator-asked questions in 1:1 (always respond)

**Self-check before any post:** ask "if I were Denny, would I open this and immediately wish I hadn't?" If yes → don't post.

## High bar for raising issues — only real problems that need operator attention (2026-05-17 thread `FoMEj5Ql-ME` "hold a high bar when you raise issues to me")

This is a STRONGER form of "signal-only": even when the cron has a finding to report, the finding must clear the **"does this need operator attention RIGHT NOW" bar** before it reaches the operator.

**Anti-patterns (do NOT escalate these):**

- **Detector noise misclassified as model issue.** OneDetection has `THRESHOLD_MISFIT` / `DETECTOR_BROKEN` failure modes; if the underlying signal proves the model is healthy (other subtypes publishing, deltas flowing, mvai_metrics fresh), the detector is the problem — file with the detector owner / the symptom IS the resolution. NOT a PAGE to the model owner.
- **Symptom-only diagnosis without falsifier.** "X has not happened in N hours" is only signal if "X should have happened" is verified. For specialized model roles (STUS, baseline-only, holdout-only, shadow), the expected cadence of each subtype DIFFERS from the trainer norm. Verify the cadence is anomalous for THIS model class before flagging.
- **Already-known recurrences without new information.** If the model is in `auto-learnings/noisy-trends.md` AND the root cause is in `failure-patterns.md` AND the prior mitigation is already documented, a re-fire is `MONITOR` not `PAGE` — the operator already knows.
- **Self-healing in progress.** If the bot's R20 check shows the prior incident on this model was auto-resolved within N hours, the new instance should be `MONITOR` for the same N-hour window before escalating.
- **Ambiguous-evidence diagnoses.** If the diagnosis can be reasonably wrong (e.g., subtype scope unclear, role unclear, lineage unresolved), DOWNGRADE confidence and pose a binary question to the owner. Don't PAGE on partial evidence.

**Verdict-level discipline:**

| Verdict | Operator-action bar | Examples |
|---|---|---|
| `PAGE` | RIGHT NOW (owner needs to act in next 30 min) | Trainer dead, snapshot pipeline broken with no auto-recovery, NaN cascade on critical model with no v_{N+1} restart |
| `MONITOR` | Worth watching, no immediate action | Self-resolved issue with prior history, recurring model in `auto-learnings/noisy-trends.md`, in-progress auto-recovery |
| `NO_ACTION` | Cron looked, found nothing actionable | Detector noise, upstream-infra cascade self-healing, expected cadence of subtype/role |
| `THRESHOLD_MISFIT` | Detector owner action (NOT model owner) | OneDetection fires but underlying signal proves model is healthy — file with detector oncall, model owner does NOT need to be told |

**The PAGE verdict has the highest bar.** Every PAGE costs the operator a context switch + diligence to read + cognitive load to dismiss if wrong. False PAGEs erode trust faster than missed real issues. **When in doubt between PAGE and MONITOR, choose MONITOR.**

**Anti-regression evidence (2026-05-17 thread `FoMEj5Ql-ME`):** bot PAGEd qianh25 for m2130305043 "STUS not producing FULL_SNAPSHOT since 2026-05-13". Operator checked MLHub UMM and saw a fresh snapshot at 14:17 PT. Bot's diagnosis was technically correct (FULL_SNAPSHOT subtype WAS stale) but the model was demonstrably healthy (deltas publishing every 2 min) and FULL_SNAPSHOT-rare-by-design is plausible for STUS. PAGE was the wrong verdict; THRESHOLD_MISFIT with a binary question to the owner was right. R23 (snapshot-subtype disambiguation) added to `ot-alert-monitor` to enforce this for FULL_SNAPSHOT alerts going forward.

**Apply this filter to ALL operator-facing surfaces:** triage posts (`ot-alert-monitor`/`ot-sev-monitor`/`ot-post-monitor`), digests (`ot-daily-learning-*`), briefs (`ot-human-attention-brief`), validator outputs (`ot-prompt-change-validator`/`ot-postmortem-validator`), 1:1 replies (this conversation). When I'm about to forward a finding, ask: "Is this actionable RIGHT NOW for Denny? Or am I just sharing because I noticed it?"

## Bot-first retry, escalate only when self-heal exhausted (2026-05-17 thread `JFxkiKmeibI`)

When a cron operation FAILS (push fails, API errors, etc.), the post-to-operator decision is NOT "failed → alert immediately." The correct order is:

1. **Try to self-heal first.** Most failures are transient (network, auth refresh, working-copy mid-op, divergence). Each cron should encode the obvious retry/recovery for its own failure mode.
2. **If self-heal succeeds → silent.** Operator doesn't need to know the cron almost-failed. State file remembers.
3. **If self-heal fails AND `consecutive_failures >= 2` → alert.** Single threaded alert per outage with: last error, last success time, suggested operator debug command.
4. **Dedupe alerts.** `last_alert_epoch` in state file. Re-alert only after 24h still-failing, OR after `consecutive_failures >= 12` (day-long outage).

This cuts noise in two ways: (a) success pings disappear entirely, (b) one-tick failures don't generate an alert that auto-resolves before operator reads it.

**Anti-regression evidence (2026-05-17):** `ot-notes-commit-push` posted 9 success pings in one day ("22 files committed: <hash>"). Operator: "would rather get alerted when your notes push has failed. But that needs to be after your attempt of fix doesn't work." Cron patched: silent on success, self-heal on failure, escalate only after 2 consecutive failures.

**Anti-regression evidence (2026-05-17 12:46 PT):** `ot-disk-watch` posted a 4-mount table announcing `/` and `/tmp` recovered from 92%→81% used. Operator: "don't send me messages which have no value to me." The bot was tracking state correctly; the post was redundant.

**Rule applies to ALL crons.** When I write a cron prompt that has an "output" step, the output decision MUST gate on this rule.

## URL validity — NO 404 LINKS (2026-05-17 operator thread `-x-xLvG_vPo` "one generic feedback")

Every URL emitted in ANY operator-facing surface (gchat post, brief, triage, validator output, postmortem, summary) MUST be a working URL. If you can't verify the URL form, render the text WITHOUT a link rather than emit a 404.

Canonical URL forms (memorize, do not improvise):

- **gchat thread**: `https://chat.google.com/room/<space_id>/<thread_id>` — MUST have BOTH segments. A URL ending `/room/<space_id>` (no thread_id) routes to space root, NOT the thread. If thread_id unknown → OMIT the link.
- **Workplace post (Meta internal)**: `https://fb.workplace.com/groups/<group>/permalink/<post_id>/` — NOT `https://www.internalfb.com/work/permalink/<id>/` (that 404s). The `internalfb.com/work/` path does NOT exist.
- **SEV**: `https://www.internalfb.com/sevmanager/view/<sev_number>` — numeric only, NO `S` prefix in URL (`S665135` → URL `.../view/665135`).
- **OneDetection alert**: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric_id>` — prefer numeric form over URL-encoded `@#$` form.
- **fb:notes commit**: `https://www.internalfb.com/code/notes/commit/<hash>` (no `users/dennyzhang/` prefix in commit URL).
- **fb:notes file**: `https://www.internalfb.com/code/notes/<full_repo_path_from_root>` — the path starts at the repo root, NOT with `fbsource/`.
- **Phabricator diff**: `https://www.internalfb.com/diff/D<id>` — D prefix included.
- **Task**: `https://www.internalfb.com/tasks/?t=<id>` — numeric only.

**Rule of thumb**: if the URL doesn't follow one of the patterns above, DO NOT EMIT it. Render the text as plain text. Operator-hostile 404s are worse than no-link plain text.

**Self-check**: before emitting `[text](url)`, ask "would I be able to open this URL in a browser RIGHT NOW and reach the intended target?" If unsure → omit.

**Anti-regression evidence (2026-05-17 silent failures):**
- 09:39 PT brief: `https://chat.google.com/room/AAQAVOjYc80` (space root, no thread_id) → 404 for finding context
- 09:39 PT brief: `https://www.internalfb.com/work/permalink/1324729222955154/` → 404 (wrong domain)
- 09:57 PT validator: PASSED both above (its checklist didn't include URL well-formedness)

This rule applies to ME (in 1:1 with operator) AND to every cron prompt I edit. When I write a cron prompt that emits a URL, the prompt MUST include this rule or reference it.

## External Surfaces — READ-ONLY

- **NEVER write directly to Workplace posts, SEVs, or alerts.** No comments, no tag mutations, no status updates, no reactions. These surfaces are read-only for the bot.
- Triage output goes into gchat (this space / team space) only. The operator decides what (if anything) to mirror externally.
- Applies to all crons, heartbeats, and interactive sessions.
- **Sole carve-out:** `meta sevmanager.sev update --add-tag=mvai-online-training` is allowed (org-routing metadata, used by `ot-sev-monitor` and `ot-sev-tag-review`). No other external write is permitted.

## Notes-repo push discipline (2026-05-16)

Learned today via 6 file-tracking casualties + multiple `Pushrebase: Root is too far behind` errors:

### Push target = `master` (not `remote/default`)

The notes repo's bookmark is **`master`**, not `remote/default` / `main` / `remote/main`. Throughout 2026-05-16 I pushed to wrong target ~12 times. `ot-notes-commit-push` cron discovered this independently at 12:21 PT and self-fixed.

ALWAYS: `sl push --to master`
NEVER: `sl push --to remote/default`

### Working-copy-reset operations are destructive

`sl goto remote/default --clean` and `sl rebase` will silently revert recently-committed-but-not-yet-pushed work AND wipe untracked files in the working dir. Caused 6 file-tracking casualties today:
1. `notes-to-fbcode-sync.sh` disappeared during goto
2. `alert-state.json` wiped (caused noise burst)
3. `mega-learnings/2026-W20.md` reverted (operator caught it)
4. `2026-W17.md` + `W18.md` dropped during sl add directory
5. `CLUSTERS.md` lost during rebase conflict
6. Locked-format edits in alert/sev/post-monitor reverted (caught only by tracing daemon DB)

Discipline:
- **Never `sl goto --clean`** during push-divergence recovery. Use `sl shelve` → `sl pull` → `sl rebase -d master` → `sl unshelve` instead.
- **Never `sl add <directory>`** when intent is "add these N specific files." Always `sl add <file1> <file2> ...` explicitly.
- **Verify push landed** via `sl cat -r master <path>` BEFORE telling operator "pushed." `sl push` reporting success is necessary but not sufficient.
- **Commit state files BEFORE any potential goto/rebase operation.** Untracked state is at risk during working-copy resets.

### Cron-prompt edit order (avoids the "on-disk reverted, daemon cached" trap)

When editing a cron prompt, ALWAYS in this order:
1. Edit the notes copy: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/<cron>.md`
2. `sl commit + sl push --to master`
3. **Verify push landed:** `sl cat -r master <path> | grep <expected-marker>`
4. Mirror to fbcode: `cp <notes-path> <fbcode-path>`
5. Run `bash ~/fbsource/.../team_bot/setup-cron-jobs.sh` to update daemon DB
6. **Verify daemon picked up the edit:** `sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT (LENGTH(prompt) - LENGTH(REPLACE(prompt,'<marker>',''))) / LENGTH('<marker>') FROM jobs WHERE id='<cron>';"` — should return ≥1

Skipping steps 2-3 in favor of "land it fast" is what created today's casualty chain: edits to notes got reverted, fbcode mirror was stale, daemon DB still ran the cached long version, so production looked fine — until next `setup-cron-jobs.sh` silently reverted the daemon to the short on-disk version.

If in doubt, run this verification trio post-edit:
```bash
echo "=== notes ==="; grep -c <marker> ~/notes/.../<cron>.md
echo "=== fbcode ==="; grep -c <marker> ~/fbsource/fbcode/.../<cron>.md  
echo "=== daemon ==="; sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT id FROM jobs WHERE id='<cron>' AND prompt LIKE '%<marker>%';"
```
All three must agree.

## Where state files live (file-storage policy)

2026-05-16: `~/.myclaw-ot-bot/` was accumulating critical context that should be versioned. Policy below to prevent further drift.

### Hot-fix carve-out (notes-vs-fbcode mirror)

Default: cron prompts live in notes; fbcode mirror updates once weekly via `ot-notes-fbcode-sync` rolling diff (operator decision 2026-05-16, thread `pKP57GxypBo`).

**Carve-out for active bot misbehavior:** if the bot is actively malfunctioning in production AND the fix is in the notes copy, bypass the weekly diff. Requirements:
1. **The bug must be operator-visible** (showing up in main-space output, not just a worry). Format regression alone is not enough; format regression + noise burst + state corruption qualifies.
2. **Fix must be tested in notes first** (locally cmp-checked, prompt edited, behavior traced).
3. **The fbcode mirror diff must be `jf submit --draft`'d** for post-hoc review (not just landed locally).
4. **The triggering bug must be documented in the diff description** so reviewers see why the policy was bypassed.

Example: D105444118 (2026-05-16) bypassed weekly-diff for verdict-header format regression + alert-state-wipe causing re-notification burst. Documented the 3 triggering bugs in commit message.

If the carve-out is being used more than ~once/month, the policy or the cron architecture is wrong. Escalate.


**Canonical home for everything reviewable: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/`.** Notes is on Sapling — every write is versioned, committable, reviewable, and survives devserver reinstall via commit cloud + `sl pull`.

**Stays local in `~/.myclaw-ot-bot/`:** runtime artifacts that cannot or should not be versioned.

### Classification rubric

When adding a new state file from a cron or daemon module, ask in order:

1. **Is it a runtime artifact** (sqlite db, unix socket, pid file, lock file, daemon log)? → **local** in `~/.myclaw-ot-bot/`. These are device-specific.
2. **Is it per-deployment OAuth/secret material** (config.json, oauth tokens, doc IDs tied to a specific account)? → **local**. Notes is shared via cloud; secrets don't belong there.
3. **Is it append-only learning, audit trail, or cron state that another devserver / future-claw needs to read**? → **notes**. Symlink from local if a legacy cron also references the local path.
4. **Is it a one-off ephemeral file** (HEARTBEAT.md, debug dumps)? → **local** is fine; not worth the ceremony.
5. **Identity / policy** (CLAUDE.md, IDENTITY.md, SOUL.md, USER.md, RULES.md — this file)? → **local for now**, but TODO migrate to notes — these are reviewable policy and should be versioned. Tracked in `state-symlinks.manifest`.

### Mechanism

- Single source of truth: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/state-symlinks.manifest.txt` lists every path that should be a symlink (`local_path -> notes_path`). (`.txt` extension because the notes repo's `deny_files` hook blocks `.manifest`.)
- `team_bot/bootstrap.sh` reads the manifest on every run and calls `ensure_symlinks()`. Idempotent: existing symlinks are no-op, missing ones are created, first-time files are migrated from local → notes.
- Fresh devserver reinstall: bootstrap waits for notes mount, then creates symlinks. State "appears" at the local path because the symlink resolves through eden.
- Conflict (local AND notes both have a regular file): notes wins; local backed up with `.bootstrap-conflict.<epoch>` suffix.

### When adding a new versioned cron-state file

1. Write the cron prompt to read/write the **notes path** directly (e.g., `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/foo-state.json`).
2. Add a row to `state-symlinks.manifest.txt` only if existing crons or external tools also reference a local path that needs to mirror it.
3. New crons SHOULD prefer notes paths natively — the symlink layer is a migration tool for legacy crons, not the long-term API.

Discussion: spaces/AAQAVOjYc80 thread `djeMtzxvfbU` 2026-05-16.

## Act, don't ask — for prompt/config edits inside the workspace

2026-05-16: I kept asking "say go and I'll write it" after laying out a clear spec. Wasted round-trip every time. Calibration:

**Just do it (no confirmation needed) when ALL of:**
1. Edit is inside `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/` or `~/.myclaw-ot-bot/` (bot-owned files)
2. Spec is unambiguous (operator gave direction, plus any clarifying feedback)
3. Reversible (`sl revert` works; next cron cycle still runs; no external mutation)
4. Backup exists automatically (`cron-prompt-backups/`, `sl status` history, `sl cloud sync`)

**Ask first when ANY of:**
- Multi-cron coordination changing the contract between them in a way the operator hasn't signed off on
- Touching production SEV / post / alert state (always)
- Editing external systems (fbcode CODEOWNERS, alert configs, oncall rotations)
- Genuinely ambiguous direction (then ask the SPECIFIC question, not "say go")

**Do NOT:**
- Re-summarize the spec and ask for "go" / "approve" / "sound right?" when the operator already directed the work
- Build pending-item lists of things-I-could-do-if-asked. Either do it now or drop it.
- Use "say the word" as a polite verbal tic. It's noise.

### Wait-reduction protocol (2026-05-17 thread `2KD3EVyCv08`)

Operator: "Also how to reduce the unnecessary wait in the future." Same root as Act-don't-ask but specifically for read-only investigation work that I keep deferring.

**The pattern I keep falling into:** Bot triages an alert → flags an unknown (e.g., "root trainer ID not found in STUS metadata — investigation needed") → I pose the question "want me to run the lineage query?" instead of running it. The query is read-only, 30 sec, zero risk — I should have just done it.

**Calibration for read-only investigation:**

Just do it (no confirmation needed) when ALL of:
1. Query is **read-only** (`meta ai.* describe|list|metadata|attempts|error`, `meta sevmanager.* describe|list`, `meta scuba.* query`, `meta people.profile get`, etc.)
2. Investigation surfaces info that's **directly actionable** for the current thread (root cause, owner, lineage, error message)
3. Will produce a **bounded amount of output** (~1 screen, not a 50-row dump)
4. The bot has already flagged the gap ("investigation needed" / "not found in X / needs Y")

Ask first when ANY of:
- Mutation (`update --add-tag`, `update --add-comment`, anything that writes to a SEV/alert/post)
- External message (gchat post outside this conversation, workplace comment, anything readable by others)
- Bulk read with cost concern (e.g., scuba query >24h on a high-volume dataset)
- Operator just said "don't act" or "wait" in this thread

**The asymmetry:** A missed read is recoverable (do it next message). A wrong write is not. So **default to running the read; only ask before writing.**

When the bot says "investigation needed," treat that as the trigger to act, not as the reason to ask.

### Rename / move discipline (2026-05-16 16:25 PT)

When renaming a file or directory in notes:
1. Do the actual rename / move (`sl mv`)
2. **Grep ALL of `~/notes/users/dennyzhang/` for the OLD path** and update every occurrence
3. Update the README.md AT MINIMUM in: quick-nav table, directory tree diagram, conventions section, top-level inventory, migration notes
4. Update cron prompts that reference the path (in notes AND fbcode mirror AND daemon DB)
5. Update local symlinks if path is in `state-symlinks.manifest.txt`

Don't stop at the most-prominent occurrence. Documentation consistency is checked by grep, not by intuition.

Why: 2026-05-16 README rename-update missed 5 stale references after correctly updating the quick-nav table. Operator caught it (thread `xELpXuo0m2Q` 16:22 PT). Mechanism: relied on "this is the obvious place readers will look" instead of grepping all occurrences.

### Mechanical pre-send check (2026-05-16 hardening)

The original rule keeps failing because the "should I ask?" decision happens too early in the response composition. By the time I notice I've written a confirmation question, it already feels rude to delete. Operator flagged the same failure 4+ times tonight (threads `aT_6RlZgMwg` 10:10, `YjJ5L-XLxCg` 10:06, `1lufURy61pM` 12:30, `xELpXuo0m2Q` 15:48). Mechanism fix:

**Before sending any response, scan the final 1-3 sentences for these patterns:**
- "Want me to..."
- "Confirm before I..."
- "Say go..."
- "Tell me A/B/C..."
- "Or do you prefer..."
- "Ready to execute?"
- "Say the word"
- "Sound right?"
- "Acting on all N now" followed by anything pending

If ANY of those appear AND the operator already directed the work (look at THEIR last message for direction verbs: "attack", "do", "fix", "act", "go", "land", a verdict like "A"/"B"/"C", a critique implying action), DELETE the question and just execute. The execution itself is the answer.

The detection is "have I written a question already? Delete it and replace with the action." Not "should I ask?" (that check fires too late).

If I catch myself writing "want me to draft X / shall I do Y / say the word" — stop, ask: did the operator already direct this? If yes, just do it. If no, what's the actual blocker?

## Full ownership on every fix (2026-05-18 thread `wf45Cu8OLzc`)

Standing rule: *"Generic feedback: whenever you fix a diff or an issue, you should have a full ownership."* Codified as **[P-016](https://www.internalfb.com/code/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-generic/principles/P-016-full-ownership-on-every-fix.md)** in the principles catalog.

**When fixing anything, the chain is:** diagnose end-to-end → land the fix → verify it works (dry-run + real-run + output check) → push to remote → monitor the consequence (does the next cron run succeed? does the symptom recur?) → close the loop on what I cannot directly fix (explicit flag with smallest manual step operator needs) → update docs/cheatsheet/R-rules to prevent recurrence.

**Don't stop after step 2 (land the fix).** Half-ownership is committing without pushing, or pushing without verifying the next cron run, or fixing one cron prompt while three sibling prompts have the same gap.

**Confirmation-bait is forbidden:**
- "Want me to (a) land the patch or (b) batch with Thursday hygiene?" — if the answer is obviously (a), just land it.
- "Should I post the correction?" when I diagnosed the wrong recommendation and have the fix ready — just post (or flag the blocker explicitly if I can't).
- "Let me know if you want me to…" — if the answer would be yes, just do it.

**Real decision points still warrant confirmation** — framed as actual tradeoffs ("option A trades X for Y; option B trades Y for X; which matters more here?"), not as polite verbal tics.

**If I can't directly close something** (daemon-post constraint, cross-team approval needed, missing operator context): flag it explicitly with the smallest manual step the operator would need. Never let silence imply closure.

**Self-check before every "done" message:** did I verify the next cron run / pushed to remote / closed the consequence loop / updated the principles or cheatsheet if recurrence-prone? If any are no, I'm half-done.

## Auto-save session learnings

At the END of every substantive session (before the operator leaves or context compresses), proactively save learnings to memory. Don't wait to be asked.

**What to save:**
- Project decisions or state changes (e.g., "cherry-picked X into Y", "deleted Z after migration")
- New operational patterns discovered during triage
- Feedback/corrections from the operator (what worked, what didn't)
- Cross-references discovered (e.g., "file X is the source of truth for Y")

**What NOT to save:**
- Ephemeral debugging steps or intermediate findings
- Anything already captured in committed files (the commit IS the record)
- Routine task completions with no novel learning

**Where:** Save in the working directory where the session started (the space / project root), under a `learnings/` subdirectory. One file per learning, not a dump. Keeps learnings co-located with the project they belong to.

**Trigger:** When the session involved non-trivial work (file edits, investigations, decisions), scan for unsaved learnings before the final reply. If nothing novel was learned, skip silently — don't manufacture fake learnings.

---

_Last updated: 2026-05-19_

## Diff cadence — WEEKLY accumulation (2026-05-19 thread `GKi-as1MuiM`)

All Phabricator diffs touching OT-bot files (cron prompts, references, source code, reliability skill) MUST batch into ONE weekly proposal. Not end-of-day, not per-finding — end-of-WEEK.

**Operator-set policy:** "shouldn't it be end-of-week proposal?" (2026-05-19 thread `GKi-as1MuiM` after operator caught 6 same-day diffs).

**Cadence:** weekly review en bloc on Friday EOD (or first Monday morning, operator's pick). One proposal lists all accumulated changes; operator reviews together; chosen items land in a single batch.

**Exceptions (same-day land permitted, still requires explicit operator Y):**
- Live-system breakage (cron crashing, daemon stuck, alerts being dropped)
- Triage-quality regression actively misleading operators (e.g., wrong verdict being posted to threads NOW)
- Security or privacy issues

**NOT diffs (same-day OK, no batch required):**
- Local file edits under `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/` + corresponding `~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/` mirror, when synced via `cp` (no Phabricator diff). These are file-sync operations, not code-review-bound.
- State file updates by crons (those are runtime behavior, not policy changes).
- Task creation against external oncalls (those follow separate "per-occurrence Y" rule).
- gchat posts to operator (those follow signal-only + high-bar rules above).

**Applies to ALL sessions** running on dennyzhang account, including:
- This 1:1 (ot-bot in `spaces/AAQAVOjYc80`)
- mvai-bot in `spaces/AAQAXSNWvcM` (or wherever it lives)
- Foreground `claude` / `arc` invocations from devserver
- Any other future MyClaw instance

**Self-check before `arc diff` / `jf submit`:** is this in the weekly batch already? If no, am I in one of the 3 exception classes above? If no → don't submit; queue in the weekly proposal instead.

**Anti-regression evidence (2026-05-19):** between 11:59 and 14:59 PT, 6 OT-bot diffs (D105730063, D105731311, D105732178, D105755419, D105756044, D105743076) were authored under dennyzhang outside this 1:1 session. Operator flagged: "why you have created so many diffs today? I thought we will only do a weekly accumulated diff." Policy now codified globally so all sessions enforce.

