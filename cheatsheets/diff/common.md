# Diff Workflow Cheatsheet — Common Patterns

<!-- Last updated: 2026-06-14 -->

Shared Sapling (sl) and Jellyfish (jf) patterns across all repos (fbsource, configerator, www). Always read this file AND the repo-specific cheatsheet before any diff operation.

> **⛔ IF AI CAN DO IT, DON'T DEFER IT TO THE HUMAN (Denny, 2026-06-15).** When a diff has an open comment or a failing signal, ACT on it — fix the code, even if the fix is deep or "not trivial". Never reply/punt "will you take it?" / "want me to fix it?" or hand a hard fix back. Exhaust AI capability first: trace the dispatch through every layer, run the owning test target, decide from observed behavior. Escalate ONLY a genuine human-only domain fact that is unknowable from the code after real investigation — and then do ALL surrounding work and ask ONE precise question. A heartbeat/cron must never offer the human a choice it could resolve itself. (Crystallized after a checkpoint-client test migration was punted with "or will you take it?".)

## Workflow Rules

> **META-RULE — EVERY COMMIT-MESSAGE-ALTERING OP INVALIDATES PRIOR CHEATSHEET REVIEW.** Any of `sl fold`, `sl metaedit -m`, `sl amend -m`, `jf template --override-*`, `jf template --add-*` produces a NEW commit message. All checks that ran against the pre-op message (title prefix, summary word count, file-inventory ban, duplicate-field check, evidence URL, length cap) are now stale. **Re-run the full Pre-Submit Gate self-review on the new message before `jf submit`.** Treat any sl/jf op as a state mutation, not a terminal action — every mutation triggers a mandatory replay. (Crystallized 2026-05-22 after a session that skipped the replay 3 times across one consolidation.)

- **Don't stack diffs unless absolutely needed.** Each diff should be independent on trunk. Stacked diffs create rebase hell, block each other on review, and cause `sl metaedit` / `jf submit` to cascade changes across the stack. Only stack when diffs have a true code dependency (diff B imports a symbol added in diff A). **Hook-enforced**: `~/work/claude/scripts/block-stacked-commit.sh` (PreToolUse on Bash) blocks `sl commit` when `.` is a draft. Pass `--allow-stack` to bypass when stacking is intentional.
- **Parallelize independent diffs with worktree isolation.** When creating 2+ diffs that don't depend on each other (no cross-references, different directories), use parallel Agent calls with `isolation: "worktree"` so each agent gets its own working copy. Don't create them sequentially on the same working copy. EdenFS worktrees are cheap. Only use sequential creation when Diff B references or depends on Diff A.
- **Pre-flight before any diff edit on main: check for existing drafts.** Even a single diff goes in a worktree if the parent's working copy has drafts in flight — `sl goto fbcode/stable` moves the parent's commit pointer, and the `auto-sl-addremove` hook can fold the parent's untracked files into your fresh commit (real incident: 2026-04-28, `sev-dry-run-2026-04.md` got auto-folded into D102929181). Run `cd ~/fbsource && sl log -r 'draft() & ::.' -T '{phabdiff} {desc|firstline}\n' && sl status` before any new-diff workflow. Anything in either output → dispatch via Agent with `isolation: "worktree"`.
- **Diff size limit: under 150 lines ideal, under 300 max.** AI-generated diffs tend to be large. If a diff exceeds 300 lines, split it into smaller, independently reviewable diffs. Large diffs get slower reviews, more comments, and higher rejection rates.
- Use `timeout: 300000` for `arc lint` and `arc pyre` — they routinely take 3-5 minutes.
- `jf submit` on stacked diffs must use `--stack` (hook-enforced).
- Configerator diffs: run `arc f` on `.cconf` files before submitting — the auto-format hook only covers fbsource.
- **Run `arc f` (auto-format) on new files after `sl add`.** Newly created files don't get auto-formatted by hooks until they're tracked. Run `arc f <file>` immediately after `sl add <file>` to ensure formatting is correct before the first commit.
- After `jf submit`, always run Reviewer Discovery and add reviewers before reporting done.
- **Always create unit tests for functional changes.** If the diff adds or modifies logic (new functions, changed behavior, bug fixes), include corresponding unit tests in the same diff. Config-only or documentation-only changes are exempt.
  - **"Log-only" is NOT a coverage exemption.** A `logger.info`/`print`/added line is an *executable line* that counts toward a coverage gate (`*_needed_coverage`). The config/doc-only exemption applies to non-executable changes, NOT to "it's just a log line." If you add an executable line to a coverage-gated file, it must be **covered by a real unit test** — that is the default and near-always correct. Decide BEFORE submit by running the owning `*_needed_coverage` target (Pre-Submit Gate check 7) — don't let CI tell you.
    - **Do NOT reach for `# pragma: no cover` because a line is "near an exit."** A line *before* a process-exit call (even right before `os._exit` / `exit_w_cleanup`) is **testable**: mock the exit function (`patch.object(mod, "exit_w_cleanup")`) so it doesn't kill the runner, force the branch, assert the behavior. Worked example: `test_main_exception_logs_mvai_exit_and_calls_exit_w_cleanup` in `fbcode/minimal_viable_ai/fire/tests/test_light.py` — patches the entrypoint to raise, unsets the unit-test env flag, mocks `exit_w_cleanup`, asserts the `[MVAI_EXIT]` marker. Reserve `# pragma: no cover` for the *literal* terminal call line (`os._exit(...)` / `sys.exit(...)`) where mocking it would defeat the test, or for code that truly cannot run under test. Auto-pragma'ing to pass a gate is metric-gaming — a careful reviewer (and Denny) rejects it.
    - **Learned 2026-06-04 (D107459272), the hard way:** I rationalized a `# pragma: no cover` on a `logger.info` before `exit_w_cleanup(1)` and called it "untestable." Denny pushed for a real unit test **three times** before I wrote one — the line was trivially testable by mocking `exit_w_cleanup`. Default to the test; treat "it's an exit path → pragma" as a smell that you're dodging the test.
- **Always add the `publish_when_ready` tag.** Every diff Claude creates or updates must have `Tags: publish_when_ready` in the commit message. Add it on initial commit creation via `sl metaedit`.
- **META-RULE — "rebase/update a diff" is NOT done until Phab shows a fresh version.** A local `sl rebase`/`sl amend` that is never `jf submit`'d is a no-op from the requester's view: they look at Phabricator and see the old base. The postcondition for any "rebase D<n> to trunk" / "update D<n>" task is a NEW version on Phab — verify with `meta phabricator.diff versions -n D<n>` (latest `created` must be fresh, i.e. just now) BEFORE reporting done. Never report "rebased/updated" off the local step alone. Use the atomic wrapper `~/work/claude/scripts/rebase-diff.sh D<n> [--leave-comments]` — it does pull→goto→rebase→`jf submit`→**verify the version advanced**, FAILS LOUD if Phab didn't move, and shelves/unshelves any concurrent-cron dirty WC so the shared-checkout collision can't block the `goto`. **Learned 2026-06-09**: asked to rebase D104349030, I ran the local rebase, stopped to ask about open comments, and never resubmitted — Denny saw no change on Phab. The fix is a completion-postcondition (verify the Phab version bumped), not a promise to remember.
- **Splitting a diff: uncommit → revert unwanted files → commit.** `sl commit <specific-files>` does NOT remove other files from the commit — it only stages those files into a NEW commit while the original commit still contains everything. The correct sequence is: (1) `sl uncommit` to put all changes in the working copy, (2) `sl revert <files-to-remove>` to discard the files you're splitting OUT, (3) `sl commit` the remaining files with the original `Differential Revision:` footer, (4) verify with `sl diff -r '.^::.' --stat` that only the intended files are in the commit, (5) `jf submit --draft --update-fields` to push the split to Phabricator. Always verify after submit that `meta phabricator.diff raw-diff -n D<number> | grep "^diff --git"` matches your expectation. Learned 2026-05-13: split appeared successful locally but never propagated because the commit still contained all files.
- **When squashing/folding diffs, immediately abandon the absorbed diffs AND fix dangling dependencies.** After `sl fold` merges diff B into diff A: (1) `meta phabricator.diff abandon -n D<B>` — don't ask, just do it. Abandon is the one Phab write allowed for interactive Claude (rule confirmed 2026-05-22 — no comment text, just a state change). (2) Check if any other diff depended on D<B> and rebase it onto D<A> or trunk. (3) `jf submit --draft --update-fields` to push the updated dependency graph. Stale dependencies on abandoned diffs block landing. Learned 2026-05-13: D104989208 was folded into D105002654 but not abandoned until the user noticed.
- **After abandoning a diff, walk children and clear Phab `depends_on:` links.** Local rebase off the abandoned parent is NOT enough — Phabricator stores `depends_on` as separate metadata that `jf submit` does NOT clean up. The diff will stay red with `land_blocker: depends_on_abandoned_revision` until the link is explicitly removed. Workflow after `meta phabricator.diff abandon -n D<parent>`: (1) `meta phabricator.diff stack -n D<parent>` to find children, OR scan `sl ssl` for local drafts that listed D<parent> as parent. (2) For each child, `meta phabricator.diff metadata -n D<child> | grep depends_on` — if it still lists D<parent>, run `meta phabricator.diff remove-dependency -n D<child> -d D<parent>`. (3) Rebase the child locally onto trunk (or the new parent): `sl rebase -s D<child> -d remote/master`. (4) `jf submit --update-fields`. Learned 2026-05-26: D106313256 stayed red after parent D106305010 abandon because the local rebase didn't touch Phab's `depends_on` field — boss flagged twice before I ran `remove-dependency`.
- **`sl fold` is a commit-message-altering operation — the Pre-Submit Gate MUST re-run on the new message.** `sl fold` creates a brand-new commit with a brand-new message you composed in `-m`. Every check that ran against the pre-fold message (title prefix, summary word count, file inventory ban, duplicate-field check, evidence URL) is now stale and must re-run against the post-fold message. The order is: fold → cheatsheet self-review on new message → fix → `jf submit --draft --publish-when-ready --update-fields`. Same rule applies to `sl metaedit -m`, `jf template --override-*`, `sl amend` with `-m`. **Learned 2026-05-22**: D106126550 post-fold message kept a 275-word file-inventory summary and `[ot-team]` non-standard prefix because I skipped the re-review until boss prompted twice.
- **Consolidation diffs: fold all thin diffs by default, write a 3-paragraph summary at most.** When the user lists N small diffs to consolidate, fold ALL of them — including ≤5-line diffs that "feel semantically distinct". A 1-line diff never warrants standalone status; reviewer time savings of one fewer diff beats semantic purity. Consolidation-diff summary template (hard cap ≤150 words): **(1) WHY** — what drift / decision motivated the consolidation, with link/anchor; **(2) WHAT CHANGED at a high level** — "X files synced, zero behavior change" or similar; **(3) REPLACES line** — `Replaces D<a> + D<b> + D<c> (all abandoned, content folded in)`. NO per-file enumeration, NO per-group breakdown by category, NO cron schedule listings — the diff stat and the data file (MANIFEST.json etc) already show all of that. The size-limit rule (≤300 lines) is waived for parity-backport / mirror-sync diffs where atomicity beats size; state the exception in the Summary. **Learned 2026-05-22**: D106126550 v1 fold message had a 3-section numbered breakdown of 4-monitor + 8-learning + 9-new-jobs with cron schedules inline — pure changelog. Trimmed to 140 words.
- **`jf submit --stack` walks ancestors of `.`, not descendants.** If you fold or amend at a non-top commit, `jf submit --stack` will only re-submit that commit + its parents — descendants are left stale on Phabricator. After any multi-commit op, run `sl ssl` to find the top of the stack, then `sl goto <top-hash>` BEFORE `jf submit --stack`. **Learned 2026-05-22**: D106127555 stayed empty (no Summary / Test Plan) on Phab for 5 minutes after the parent template update because I submitted from the parent instead of the top.
- **Area-specific `.llms/rules/` auto-load BEFORE writing diff metadata.** Many fbcode areas pin Reviewers/Tasks/Tags in a per-area conventions file (`fbcode/<area>/.llms/rules/<area>-conventions.md`, search for the `## Diff Submission` section). Always grep these BEFORE composing a commit message — manual lookup wastes a round trip and risks missing the required Task that Devmate cross-references. Quick command: ``grep -rA5 "## Diff Submission" $(find <area> -name ".llms" -type d 2>/dev/null) 2>/dev/null | head -30``. Known areas: `pe_mrs_ml/mrs_ot_agent/` → Reviewers `mrs-ot-reliability`, Tags `publish_when_ready`, Task `T259215482`. **Learned 2026-05-22**: D106126550 and D106127555 both shipped initially without any of these three fields because I composed the messages from intuition instead of reading the conventions file.
- **Notes→fbcode mirror diffs: pre-flight trunk-drift check for shared multi-author files.** When a diff mirrors `notes/<file>` → `fbcode/<file>` for shared-multi-author registry files (`team_bot/CLAUDE.md`, `team_bot/cron-jobs/MANIFEST.json`, `team_bot/team_bot_config.yaml`, similar), DO NOT blindly `cp notes/file fbcode/file`. Notes may be stale vs fbcode trunk (someone backported content directly to fbcode without round-tripping). Mirror would silently DROP trunk-only content. Pre-flight (run before every mirror): `diff <(sl cat -r 'remote/master' <fbcode_file>) <notes_file>` — if non-empty AND notes lacks trunk-only lines, ABORT mirror and start from trunk + apply only the additive change. **Patch-don't-replace for shared files; full-mirror only for single-author cron prompts.** **Learned 2026-05-28**: D106716098 v1 mirrored stale notes → fbcode and silently dropped 10 MANIFEST cron entries + 2 CLAUDE.md sections (Agent-design principles, Conditional Cheatsheet Loading) + 5 path corrections. Same bug hit twice in one diff (MANIFEST.json + CLAUDE.md). Fix: pull trunk, additive insert, re-amend.
- **Declared-but-unwired helper anti-pattern (AI-shape bucket).** When a diff adds a centralized helper / wrapper / recovery function meant to be invoked at multiple existing call sites, the diff MUST include BOTH (a) the helper declaration AND (b) every existing call site rewritten to invoke it. A helper that's only declared and never called is dead code; the "self-heal" benefit is fictional. Pre-submit grep recipe: e.g. for a `gchat_read_with_recovery` wrapper, run `grep -rnE "meta google\.chat\.message list\|gchat read " <prompt> | grep -v gchat_read_with_recovery` — must return ZERO results. Same shape: logging wrappers, retry wrappers, instrumentation hooks. **Learned 2026-05-28** (thread `4BK7HJHkzB0`): cron prompt declared `gchat_read_with_recovery()` shell function in step 0.5 but never edited the actual `gchat read` call site at step i-c to invoke it. Wrapper was dead code through one full cron tick; production still emitted `gchat_reads=DEGRADED` despite the "fix" landing. Operator flagged within 15 min.
- **`buck2 run -q` is not valid — exits 3 with "unexpected argument '-q' found".** The `-q` (quiet) flag is NOT a buck2 subcommand option (neither global nor `run`-scoped). Any cron prompt using `buck2 run -q <target> -- ...` silently fails with exit 3 and no stdout. To suppress buck2's Buck UI / RE Session noise, use `2>/dev/null` instead. Recipe: `buck2 run <target> -- <args> 2>/dev/null` (keeps stdout clean, drops Buck status lines). **Learned 2026-05-28** (thread `iiujQv9mdP0` + L65 ledger): every `scope_check` invocation in ot-sev-monitor / ot-daily-learning-mitigated-sevs had `buck2 run -q ...` since the cron's inception — every call silently failed, cron fell back to `[manual-scope-assessment]` for the entire history. L65 attributed the degradation to cwd-pinning (wrong); actual root cause was the `-q` flag. Defense-in-depth: also grep cron prompts before submit: `grep -rn "buck2 run -q" <cron-prompt>` should return ZERO.

## Which Repo?

| Repo | Specific Cheatsheet | Detection |
|------|---------------------|-----------|
| fbsource | `cheatsheets/diff/fbcode.md` | Path under `/fbsource/` or `fbcode/` |
| configerator | `cheatsheets/diff/configerator.md` | Path under `/configerator/` |
| www | `cheatsheets/diff/www.md` | Path under `/www/` |

## Commit Message Format

```
<Action verb> <what was changed> for <component/system>

Summary:
<Explanation of what was changed and why>

- Changed X from Y to Z
- This fixes/improves <reason>

Test Plan:
- <test command or verification step>
- <expected result>

Differential Revision: <preserved by sl/jf>
```

**Key rules:**
- **Title = intent, not changelog.** State what the diff achieves ("Oncall agent cli improvement"), not an enumeration of every change ("Split telemetry by OT vs non-OT, guard TAO calls, and add tests"). Reviewers triage by intent.
- Start with an action verb (Add, Fix, Update, Refactor, Remove) — makes `sl log` output scannable and diffs self-describing
- Keep the first line under 72 characters — Phabricator and `sl log` truncate longer lines
- **Oncall/bug-fix diffs: include context tag and measurable impact in the title.** Use `[Oncall]` prefix for oncall-originated fixes. Quantify the failure duration or blast radius directly in the title so reviewers see urgency at a glance without opening the diff. Example: `[Oncall] Fix mvai_rule_based_monthly job which has failed for 20 days` — not `Fix ValueError in mvai_rule_based_monthly Chronos job`. The generic version reads like routine cleanup; the tagged version signals urgency and scope.
- **Category prefix in title for cross-cutting diffs.** When a diff's primary purpose falls into a well-known category, prefix the title with a bracketed tag so reviewers can triage at a glance. Categories: `[Observability]` (logging, metrics, alerting, dashboards), `[Oncall]` (incident-driven fixes), `[Perf]` (latency, throughput, memory), `[Cleanup]` (dead code, refactoring), `[Security]` (auth, access control, injection fixes). Example: `[Observability] Escalate delta publisher logging for missing full snapshot`.
- Do NOT hard-wrap summary body lines — Phabricator renders markdown and handles wrapping. Write each sentence/paragraph as a single long line.
- Always include a Test Plan section — reviewers use it to validate the diff and CI gates on it.
- **Test plan = scenario + command, not filler.** Explain what the test proves ("diagnose a task without bothering users") then give the exact command. Don't list filler like "arc lint passes" or "verified X is captured" — that's noise.
- The `Differential Revision:` footer is managed by Sapling/Jellyfish — never remove it manually

## Summary Writing

See `diff/diff-summary-writing.md` for the full guide (why-first extraction, reviewer question anticipation, templates by complexity). Key rules:

- **Hook-enforced (since 2026-05-02):** the Pre-Submit Gate's summary checks below run mechanically in `scripts/quality-gate-precheck.sh` on every `jf submit`. Word-count cap, `Stack:` line, `Source incident:` repetition, numbered-tour count ≥3, bare D/P numbers, and what-not-why openings all hard-block submit. If the hook trips you, fix the message via `sl metaedit` and re-submit.
- **Length cap by diff scope.** Hard numbers are harder to rationalize past than "concise". Apply BEFORE writing the summary, not after.

  | Diff scope | Summary cap |
  |---|---|
  | Doc-only / config-only ≤50 lines | **2 sentences, ≤60 words** |
  | Code change ≤150 lines | 1 paragraph, ≤120 words |
  | Larger / refactor / new feature | up to 5 paragraphs |

  Run `wc -w` on the Summary body before `jf submit`. Over-budget = trim, not submit.
- Lead with **why**, not what. "Prevents X" > "Adds Y."
- Cut filler. "This diff adds X which provides Y" → "X provides Y."
- Bullets for decisions, prose for context. Don't over-format.
- **Summary is story, not changelog.** No "Key changes:" or "Changes:" bullet lists that mirror the diff. Summarize the *problem and fix*, not the file-by-file changes. The summary should read as a short narrative a reviewer can understand without opening any files.
- **Don't repeat the title or the diff.** The title already names the job and duration — don't restate them in the summary. The diff content already shows which call sites and what the filter does — don't narrate it. The summary should only contain information a reviewer can't get from reading the title + diff: root cause explanation and impact scope. Never inventory files ("Added X.md, Y.md, Z.md with ..."), list line counts, or narrate what each file contains — that's all visible in the diff itself.
- **No implementation details in the summary.** Don't explain byte sequences, internal APIs, or how the code works — that's in the diff. The summary states the problem ("X currently does Y") and the fix ("it should do Z"). Two sentences, not two paragraphs. "TAO permission is required in Chatbot.send_message()" is sufficient — don't trace the 3-hop call chain.
- **Frame fixes as general correctness, not tool-specific.** "Shift+Enter should insert a newline" is stronger than "enables Claude Code's multi-line input." Reviewers care about correct behavior, not one consumer's use case.
- **Use placeholder names for illustrative chat/coordination examples.** When the summary needs to *quote* a chat message to demonstrate behavior (e.g., what a bot should silent-drop, which messages match a filter, what an interpersonal request looks like), replace third-party @mentions with `@<engineer>` / `@<teammate>` / `@alice`. Reviewer attribution (`Paul caught X in inline review`) and unixnames in `Reviewers:` stay as real names — the rule applies to "overheard chat" examples where the named person is not the actor in the diff and didn't consent to being the example. Surfacing internal coordination into a permanent, codesearch-indexed commit log is gratuitous when placeholders carry the same information. (Learned 2026-05-02: D103556501 v1 quoted three real teammates in `@-mention` silent-drop examples; tightened to placeholders before resubmit.)
- **Add reusable reference sections when applicable.** If the diff involves setup steps others will need (permissions, access requests, config), include a template they can copy. This adds value beyond explaining the diff — it helps future users.
- **Wrap ugly URLs in markdown link syntax.** Phabricator alert/monitoring/Scuba/dashboard URLs are walls of percent-encoded query params (`%40%23%24%7B...`). Bare-pasted, they shred summary readability. Always wrap as `[descriptive text](url)` — the rendered diff shows clickable text only. Same rule for any URL ≥80 chars or containing `%` escapes. (Learned 2026-05-20: D105890355 V0.1 pasted bare alert URL; boss flagged "horrible for human to read" — fixed in V1 with markdown wrap.)
- **Alert noise reduction diffs: quantify in title, verify before claiming.** When the diff reduces alert noise, the title must include the quantified impact (e.g., "Fix 3 misconfigured CRITICAL detectors" or "Eliminate ~50 false pages/half"). Always verify the claim with data: query `one_detection_stats` with `activeAlertsCount >= 1` to count actual alert firings — NOT raw detector evaluation cycles (the `Hits` count without filtering is evaluation cycles, which can be 1000x larger than actual firings). If no alerts have actually fired, frame as a preventive fix ("prevents future false pages") — don't inflate.

- **Never clobber the operator's out-of-band edits on a diff (2026-06-03).** Before amending an existing diff's title/summary/metadata, check whether the operator edited it directly in the Phabricator UI (title prefix changed, status set to Changes Planned, extra versions). If so, PRESERVE their edit — append your change (e.g. measured-impact suffix) rather than overwriting their prefix/title. Same class as the gdoc comment-clobber rule: the bot's edit must not silently revert a human's deliberate change. (Source: overwrote `[OT Monitoring]`→`[Oncall]` on D107403198 during a title amend.)

### Summary template (copy-paste, then fill)

A succinct summary mirrors the test plan template: 3 lines that answer the only 3 questions reviewers care about. Fill each line in 1–2 sentences max. If a line doesn't apply, drop it — don't pad with filler. Hard cap stays the same as § Length cap by diff scope.

```
Summary:
- **Why**: <the broken state in production OR the missing capability that motivated this; cite SEV / Workplace post / dashboard URL>.
- **Fix**: <the smallest description of the new behavior; one sentence>. <If non-obvious, one more sentence on the design choice (e.g., "plain dataclasses + manual validation, zero new deps")>.
- **Impact (measured, if applicable)**: <the before→after the change produces, in NUMBERS pulled from data — pages/alerts eliminated, false-positive rate, latency/QPS, failure duration, rows/$ saved, # entities affected. Query the source (ODS/Scuba/instance-list/one_detection_stats), don't estimate. Put the headline number in the TITLE too (see § title rules). Skip ONLY when genuinely unmeasurable (e.g. pure refactor) — and say so rather than omitting silently.>
- **Scope**: <call out non-obvious cross-cutting impact: feature flags, lazy imports, opt-in vs default-on, blast radius>. <Skip this line if the diff is purely additive and self-contained>.
```

- **Show measured impact whenever applicable (2026-06-03, operator request thread `J0qPbEkPi4I`/`TfDh4inHB78`).** A diff that changes behavior should state its impact in NUMBERS, measured from data — not asserted. This generalizes the title-quantify and alert-noise rules above to EVERY behavior-changing diff: the `Impact` summary line + the headline number in the title. Examples: "stops ~Nx false WARNING pages on M detectors" (verify via `one_detection_stats` actual firings), "FS false-positive window 73m→217m, real-gap coverage preserved (390m/35h gaps still page)", "unblocks K models". If the impact can be measured and isn't in the diff, the diff is not done.

Smell tests on the draft, before `jf submit`:

| Smell | Anti-example | Fix |
|---|---|---|
| Restating the title | Title `Add typed config schema with friendly drift errors` + Summary opens with `This diff adds a typed config schema...` | Skip the rephrase; lead with **why** the schema is needed (drift bites at runtime today) |
| File inventory in prose | `Added X.py (158 lines), Y.py (test, 115 lines), and Z.md (50 lines)` | Reviewer reads the diff stat for that. Spend the words on the design choice instead |
| Implementation tour | Tracing the call chain across 3 hops or describing how a function is implemented | Diff is the implementation. Summary states problem + behavior change |
| Lab-notebook prose | "I tried X, then realized Y didn't work because of Z, so I switched to W" | Reviewer doesn't care about the discovery path. State the destination |
| Multi-paragraph wall on a 14-line doc-only diff | 3 paragraphs explaining what the doc says | Doc-only ≤50 lines = ≤60 words / 2 sentences. Hard cap, not a guideline |

## Pre-Submit Metadata Checklist

Before the first `jf submit`, ensure the commit message has all metadata populated:

1. **Tasks** — Only link a task if this diff directly resolves or advances it. Evaluate the relationship — don't blindly attach a task just because it appeared in conversation context or is topically adjacent. If no task directly applies, leave the `Tasks:` field empty.
2. **Reviewers** — Discover reviewers (see Reviewer Discovery below) and add them to the `Reviewers:` field.
3. **Tags** — Add relevant tags (oncall name, area). **Every diff Claude generates MUST include the `publish_when_ready` tag** — no exceptions.
4. **Test Plan** — Always include a Test Plan section.
5. **Source link** — For oncall-originated diffs, include the source URL (Chronos job, alert, SEV, failing dashboard) in the Summary. Reviewers need the full context of what triggered the fix. Without it, the diff lacks traceability back to the incident. This applies to any link the user provided as the starting point — don't drop it.
6. **Link all supporting evidence** — When the Summary references external motivation (Workplace posts, SEVs, alerts, dashboards, design docs, meeting notes), always include the actual URLs. "Motivated by two Workplace posts" without links is unverifiable. Reviewers and future readers need clickable proof — link every claim that has a source.

**Order of operations:** **Dup-guard (query open diffs)** → Create task → write commit message with Tasks/Reviewers/Tags → `jf submit --draft --publish-when-ready`. Don't submit first and try to add metadata later — that causes duplicate field issues and orphaned drafts.

### Pre-Submit Gate (MUST pass before every `jf submit`)

The authoritative correctness gate. For auto-stamp optimization see `cheatsheets/diff/radar-autostamp.md` (§ RADAR Pre-Flight — executable bash shape checks; § Pre-Submit Checklist for Auto-Stamp Candidates — RADAR-shape questions). They're complementary, not redundant: this Gate enforces correctness (lint, reviewers, tags, dups); the RADAR file's checks target auto-stamp shape. Run both before any submit you intend to auto-stamp.

Before running `jf submit`, verify ALL of the following:

1. **`arc lint` passes** — run `arc lint --apply-patches` (timeout: 300000) and fix all errors. This catches naming conventions (HackLint5520), unused imports, formatting, and other repo-specific rules. Never skip this — CI will fail if you do.
2. **`Reviewers:` has real reviewers** (not empty, not yourself). Use `#project-name` for project reviewers. The diff author cannot be a reviewer — Phabricator rejects it.
3. **`--publish-when-ready` is in the command** — never bare `--draft`. Diffs without this flag stay invisible forever.
4. **No duplicate fields** — exactly one `Reviewers:`, one `Tasks:`, one `Tags:` line. Duplicates cause `jf submit` to silently skip field updates.
5. **Internal consistency check** — after file renames/moves, grep the diff scope for old paths. Verify counts match enumerations (e.g., "16-step" vs 15 listed items). Check for content duplicated across files in the same diff. Linters don't catch cross-file reference breakage — only a self-review does.
6. **Summary fits the length cap** — run `wc -w` on the Summary body. Doc-only / config-only ≤50-line diff = ≤60 words / 2 sentences hard cap. Larger diffs follow the table in Summary Writing. Over-budget = trim before submit, not after Denny pushes back.
7. **Run the OWNING test targets, not just `arc lint`** (code changes only). `arc lint` runs linters — it does NOT run tests, coverage, or the build. The entire **deterministic-failure class** (coverage gates, real test assertions, build/compile errors) sails past lint and only surfaces as a CI escalation you then have to triage. Before submit, find and run the targets that own each changed file:
   ```bash
   buck2 uquery "owner(fbcode/path/to/changed_file.py)"   # list owning targets
   buck test @fbcode//mode/dev-nosan <owning-target>      # run them (incl. any *_needed_coverage target)
   ```
   A coverage gate (`*_needed_coverage`) is **deterministic** — it will fail in CI exactly as it fails locally, so catch it now. If a changed/added executable line genuinely can't be covered by a test (e.g. it precedes `os._exit` / process exit), add `# pragma: no cover` matching the file's existing convention — see the coverage note under "Always create unit tests" below. **Learned 2026-06-04 (D107459272):** a one-line `logger.info` added to `light.py`'s exit path tripped `test_light_needed_coverage`; it was submitted unchecked, came back as a CI escalation, and got mis-triaged as flaky. Running the owning target before submit would have caught it in one step.

8. **Address every open Devmate/human comment** (resubmits only — a brand-new diff has none yet). This check is now **script-enforced, not prose**: `scripts/presubmit-comment-gate.sh` (called first inside `quality-gate-precheck.sh`, so it runs on every `jf submit`/`conf submit` and fails fast before lint/pyre) hard-BLOCKS the submit if the working commit's diff has any UNRESOLVED, non-author comment — human inline/general OR Devmate/lint signal — via the read-only `meta phabricator.diff comments -n D<num> --unresolved-only --skip-author`. It anchors on the current commit `.` (works on a clean working copy, which is the common resubmit shape), and **fails open** on any read error so a flaky endpoint can't wedge submits. Address each (fix code → amend → resubmit auto-resolves signals; or draft a one-line reply for Denny to post — silent ignore gets re-flagged by a human, see D104353324) and ONLY THEN append the conscious-override token: `... jf submit --draft --publish-when-ready --update-fields  # diff-comments-addressed-ok` (the general `# diff-gate-override` also satisfies it). This graduates the long-standing prose rule ("address every Devmate signal before submit") into a wall — prose in a cheatsheet is advisory the agent can rationalize past; a script is a wall. (Built 2026-06-08.)
9. **My diffs must carry ZERO open Devmate/human comments — ACT on every comment, NEVER touch the comment.** (Denny, hard rule, 2026-06-09.) An open comment is a TODO to fix in CODE, not a thread to manage. Take the action the comment asks for (fix the code → `arc lint -a` → amend → `jf submit --draft`); **NEVER post, reply, resolve, or otherwise modify the comment** (read-only on Phab — Hard NO). This holds **regardless of CI color** — advisory comments on GREEN diffs count too, not just blocking signals (the signal-monitor only catches blocking ones — gap that left D107966600's pyre-strict comment unaddressed). Also never edit the author's Title/Summary/Test Plan while doing it (clobber rule), never land. Automated for my own diffs by `scripts/cron-diff-comment-action.sh` (weekday hourly :30: enumerate my open diffs → fix code for any open unresolved non-author comment → draft-submit; mine-only, cap 3/run, skips a dirty WC, verify-or-revert). Interactive me follows the same rule on any diff I touch.

10. **New diff only — duplicate guard (query open diffs FIRST).** Before the FIRST `jf submit` of a new change, query your open diffs and confirm none already cover it — a new diff is created per *commit*, so re-submitting a fresh sibling commit (`sl commit` instead of `sl amend`) silently makes a SECOND diff. Run (read-only):
    ```bash
    meta phabricator.diff list --author-is-me --include-only-open                          # scan titles
    meta phabricator.diff list --author-is-me --include-only-open \
      --filepaths-affected-has-all-of-the-words=fbcode/path/to/changed_file.py             # match by files
    ```
    If a match exists, **`sl amend` the existing commit and re-`jf submit` it** (updates the SAME diff) instead of creating a new one. Also confirm `sl ssl` shows ONE commit for this change, not two siblings with the same title. **Learned 2026-06-14:** two diffs with the identical title `[Oncall] Actionable error for OT -1 resume with no Parent anchor` (D108538796 + D108539042) were created 10 min apart — the change was re-committed as a sibling and `jf submit`'d twice. Resolution was abandon the older + `sl hide` its commit; the guard is to query-before-create so it never happens.

If any check fails, fix the commit message with `sl metaedit` before submitting. Never use `jf add-reviewer` after initial submit — it appends a second `Reviewers:` line instead of merging, causing the duplicate field bug.

> **GATE TOKEN — `# diff-cheatsheet-ok` is MANDATORY on every `jf submit`/`conf submit`.** A PreToolUse hook (MyClaw `apply-space-hooks.py`, `_detect: diff-cheatsheet-ok`) hard-BLOCKS any submit whose command line lacks the token, so the gate is enforced at the tool layer — not left to prompt memory. This exists because prompt-only mandates kept being skipped, most visibly by cron-authored diffs that never load this cheatsheet (D106859537, an `ot-knowledge-distillation` diff). Run the full Gate above, fix every finding, and ONLY THEN append the token: `... jf submit --draft --publish-when-ready --update-fields  # diff-cheatsheet-ok`. The token asserts "I ran the cheatsheet" — appending it without running the review defeats the entire mechanism. Any message-altering op (`sl fold`/`metaedit`/`amend -m`) invalidates the review per the META-RULE → re-run the Gate before re-submitting with the token. **No exemptions** — even the weekly notes→fbcode mirror submit must run the Gate and append `# diff-cheatsheet-ok`, *in addition to* its `# ot-weekly-sync-submit-ok` dup-guard token (both hooks must be satisfied). Operator tightened this 2026-05-30 (thread `Q_8ELeVd7cU`): crons follow the same cheatsheet rules as agents, with zero carve-outs.

### Self-Review (MUST do before first submit)

Before submitting, review your own diff the same way you'd review someone else's. Read `sl diff -r '.^' -r .` end to end and check:

- **Symptom reproduced + full behavior verified (don't fix on faith)**: BEFORE authoring the fix, reproduce the bug via a ground-truth query/command and cite its literal output — never fix an *inherited/assumed* symptom. AFTER, verify the fix's FULL output, not the happy path: "what else does the changed path select / return / drop?" — a filter that fixes case X but silently changes case Y is incomplete. Describe entities by VERIFIED state/type/attribution, never an assumed label; origin/cause is `[VERIFIED]` or `[UNKNOWN]`, never fabricated. (D107935047 retro: the fix shipped on an inherited symptom + a happy-path-only check → it mislabeled the entity and missed a selection edge; both surfaced only under reviewer probing.)
- **Correctness**: Do paths reference files that actually exist at those paths? Do counts match enumerations?
- **Consistency**: Is the same information stated identically across files, or do copies drift? If content is duplicated, consolidate to one location.
- **Completeness**: Does every renamed/moved file have all old-path references updated? Grep for the old path across the diff scope.
- **Summary accuracy**: Does the diff summary describe what the code actually does? Re-read the summary after all code changes are final — early drafts go stale as the implementation evolves.
- **No reinvented wheels**: Before adding a utility function, search the codebase for existing implementations. AI tends to write helpers that already exist (`fbcode/common/`, project-local `utils/`).
- **No accidental files**: Run `sl diff --stat -r '.^' -r .` and verify every file listed was intentionally changed. Stray files from unrelated edits sneak in via `sl addremove`.
- **Minimality / necessity (no speculative scope)**: for EACH changed file/hunk, name the ONE verified-root `file:line` it is *required* to fix. A hunk that fixes a DIFFERENT bug, is "defense-in-depth", "while we're here", or sits on a code path OTHER than the verified failing path = scope creep → **remove it (`sl revert -r .^ <file>`) or split to its own diff.** "Kept as defense-in-depth" is a violation to FLAG, never a feature. Prefer the fix at the SINGLE layer where the root lives (generic base over per-model override); extra files/owners are a flag unless each is required. This is the COUNTER to the sibling-site sweep (which prevents under-fixing; this prevents over-fixing). (D108525530 retro: carried 3 unnecessary `ig_retrieval/` files kept "as defense-in-depth" for a different bug, in load-bearing cross-team code — operator caught it.)
- **Scope check before fixing CI failures**: Before fixing a failing diff, first run `sl show <DIFF> --stat` and verify every file is in scope for the diff's stated intent. CI failures are often caused by *misplaced* changes from another commit in the stack (e.g., a BUCK target referencing a .py file that lives in the next diff). Don't try to "fix" the failure by adding the missing file — move the misplaced change to where it belongs. Symptom: a doc-only or config-only diff has stray code/build changes; CI complains about a missing reference. Fix: `sl absorb` while sitting on the correct commit, or `sl revert -r .^ <file> && sl amend` to drop the stray change.
- **Exception specificity**: No bare `except Exception` — catch specific error types. Broad handlers mask real bugs and make debugging impossible.
- **Resource lifecycle**: Every opened resource (file, connection, lock, cursor) must be closed in both happy and error paths. Prefer `with` statements or `try/finally`.
- **Stale TODOs**: If the diff touches code near a TODO comment, check if that TODO is now resolved by the change. Don't leave stale TODOs next to fresh code.
- **Copy-paste consistency**: If the diff has similar-looking code blocks (e.g., repeated handler patterns, parallel config entries), verify they're intentionally different — not drift from copy-paste.
- **Debug format**: Use `f"{var=}"` (Python 3.8+ self-documenting expression) instead of `f"var={var}"` in logging and debug output.

This catches what linters can't: broken cross-references, stale paths after renames, wrong counts, duplicated content. The cost is 2 minutes. The cost of skipping is a rejection and a round-trip with reviewers.

### Harness & Reliability Discipline

The harness (hooks, lint, pyre, CI signals) is **best-effort, not authority**. Every gate has known silent-failure modes. Treat hook output as a hint, not proof.

**1. Verify the hook actually fired and emitted what it claims.**
- Pyre via `arc pyre check-changed-targets`: search for `No type errors found` as the FINAL colored line. Anything resembling `path:line:col` is an error, even if the hook didn't grep it. (Counter-example: pyre output uses ANSI codes; for a long time `grep error` missed the actual error lines — see `fbcode.md` "Pyre: Read the Output, Don't Trust the Hook").
- Lint via `arc lint -a` (NEVER bare `arc lint` on fbcode): if working-copy state changed during lint, autodeps2 patched a BUCK silently. `quality-gate-precheck.sh` BLOCKS submit when it detects this — re-amend before re-submit.
- CI signals after `jf submit`: there's a 5-10s propagation delay before automated reviewers see the new version. Don't act on `get_phabricator_diff_details` immediately after submit.

**2. Sibling-site sweep — broaden every fix.**

Before claiming a bug is fixed, grep the entire codebase for the same anti-pattern. AI-generated fixes default to "patch the file the user named" — copy-pasted wrappers in sibling modules are the #1 source of regressions. Check sibling sites BEFORE submit, not after a reviewer asks.

```bash
# Before submitting any logic fix, generalize the search beyond the named file
fbgs "<the buggy pattern>" --limit 50
# If 5 hits across 5 files, fix all 5. If only the named file, document why others are exempt.
```

Counter-examples that cost rework:
- D96358986 fixed `timeout=None` in 2 of 3 publishers; missed `delta_only_publisher.py` (copy-pasted code).
- D102408894 patched 2 of 5 swallow paths in the same file because the subagent never grep'd for siblings.

**3. Captured state must have a consumer — no dead writes.**

Every new field, log line, or state mutation needs a reader somewhere in the diff (or a follow-up diff explicitly named in the summary). Write-only state is a code smell that linters never catch:

- Wrote `state.last_shutdown_exception = e` but no caller reads it back? → Either remove the write OR add the reader OR mark `# TODO(D<future>): consumer` with a clear plan.
- Added a metric/log line "for future debugging" with no dashboard or scuba consumer queued? → It's noise. Either route it to a dashboard now or drop it.

Counter-example: D102407421 captured `state.last_shutdown_exception` with zero readers; the gap that motivated the diff was never closed because no consumer used the captured state.

**4. Subagent diff prompts: 4 mandatory completeness checks.**

When dispatching a subagent to write a diff in `~/fbsource`, the subagent's prompt MUST require all four checks below. **Defaults to skipping all four** — explicit instruction needed.

| Check | What the subagent must do | Why |
|---|---|---|
| **Pyre output paste** | Run `arc pyre check-changed-targets`, paste the full final 5 lines into the report. Don't summarize; quote. | Subagents will claim "No type errors" without running pyre. T266851073 had a real `mock.patch` annotation error reported as clean. |
| **Cheatsheet load** | Read `cheatsheets/diff/common.md` AND the repo-specific cheatsheet (`fbcode.md` / `configerator.md` / `www.md`) before writing the summary. | Without these, summaries default to 4-paragraph wordy prose and titles miss the routing prefix (e.g. `[OT - X]`). |
| **Sibling-site sweep** | Grep the codebase for the same anti-pattern in OTHER files; fix all sites OR explicitly justify why each is exempt. | Tourniquet fixes that miss copy-pasted siblings get rejected and waste a round-trip. |
| **Consumer of captured state** | If the diff writes a new field/state/log, name the consumer explicitly (file:line). If no consumer, drop the write or add it. | Dead writes are pure noise. T266851073 spent 3 cleanup rounds because state was captured but unused. |

Subagent prompt template snippet:

```
Before claiming the diff is ready, you MUST:
1. Run `arc pyre check-changed-targets` and paste the final 5 lines verbatim
2. Read cheatsheets/diff/common.md AND the repo-specific cheatsheet
3. Grep the codebase for the same pattern in sibling files; fix or justify
4. Name the consumer of any new captured state (file:line) or remove the write
```

Skipping any one produces tourniquet fixes, wordy summaries, missed sibling sites, or dead-write state. All four are required, every time.

**5. AI-shape Audit — the comment-cluster signature on AI-written diffs.**

AI-generated diffs over-defend the code path but under-instrument it for observability — the result is correct logic that reads as "AI on autopilot" and draws a characteristic cluster of reviewer comments. D103095467 (1075-line new module, 9 comments across 4 buckets in one review pass) is the canonical case.

| Bucket | Symptom in code | Pre-submit check (run BEFORE `jf submit`) | What you'll fix |
|---|---|---|---|
| **Silent degrade** | `try/except: return []`, `return ""`, `return False`, `return None`, `return set()` with no log line — caller can't tell "ran clean, nothing found" from "broke and degraded" | Every error-return path emits `LOGGER.warning(...)` naming the function, the args, the error class, and `(stderr or "")[:200]`. Run `grep -nE "return (\\[\\]|\"\"|set\\(\\)|False|None)\\s*$"` on the diff and verify each hit has a logger above it | Add `LOGGER.warning(...)` at every degrade return — typically 3+ paths per CLI wrapper (TimeoutExpired, FileNotFoundError, rc!=0, JSONDecodeError) |
| **Defensive redundancy without justification** | `dict.get(k, "") or ""`, magic-number truncation `x[:120]`, multiple early returns building the same object, default boilerplate (`# pyre-unsafe` on a brand-new file) | Each redundant-looking construct has either (a) a one-line `# why` comment OR (b) is factored to a helper / single-return / strict mode. Default headers are the strict version unless pyre genuinely fails | Add `# upstream emits nulls — both fallbacks needed`-style comments; refactor to single-return where the return-shape is identical; flip `pyre-unsafe` → `pyre-strict` |
| **Half-extracted config** | Numeric thresholds in `triage_config.yaml` (good) BUT regex keyword lists, enum values, or list constants still inline in `.py` (bad — same rule, inconsistent application) | If yaml has any tunables for the module, audit ALL domain values: keywords, lists, regex inputs. Build regex at call site: `kws = cfg["explicit_signals"]; _RE = re.compile("(" + "\|".join(map(re.escape, kws)) + ")", re.IGNORECASE)` | Move keyword lists / enum values to yaml; load at call site. Half-extraction trips Devmate's "ot-agent-conventions" rule |
| **Pass-by-luck tests** | Test mocks one subprocess in a multi-hop chain (outer call mocked, inner call left to run for real); test exercises a `_private` function directly | For every test that touches a function calling subprocess: ALL hops in the chain are mocked. Drop tests on `_`-prefixed functions — exercise via public API. Run `grep -nE "def test.*\\b_[a-z]" tests/` and `grep -A 5 "check_engagement=True" tests/ \| grep -L "mock.*_fetch_gchat_url"` | Add the missing inner-mock; rewrite private-function tests via the public surface (`classify(...)` instead of `_has_ot_ic_engaged_in_space(...)`) |

**Why the cluster matters:** each bucket alone produces 1-3 reviewer comments, but the buckets co-occur — silent-degrade code tends to also have defensive redundancy and pass-by-luck tests. Catching the cluster pre-submit avoids the multi-round-trip cost (9 comments → 9 code fixes → 9 reply drafts → re-submit → re-review). The audit is 4 grep-able checks; runs in under 30 seconds.

**Sibling sweep on the same diff:** when you find one bucket-1 silent-degrade or one bucket-2 magic-number, grep the SAME diff for the same shape — fixing one CLI wrapper while leaving its 3 sibling wrappers silent is the reviewer-irritating half-measure (D103095467 v2 missed `fetch_tagged_sev_ids` after fixing `fetch_in_progress_sevs` and `fetch_ot_ic_unixnames`).

### Background Review Agent (auto-spawned)

After every `sl amend`, a background agent automatically runs a parallel review of the diff. This is the multi-agent default — you don't invoke it, it just happens.

**What the background agent does:**
1. Reads `sl diff -r '.^' -r .` to get the full diff
2. Runs the Self-Review checklist above (correctness, consistency, completeness, summary accuracy)
3. Runs `arc lint -a` and `arc pyre` if applicable
4. Checks the diff against Common Mistakes in this cheatsheet and the repo-specific cheatsheet
5. Writes findings to `/tmp/claude-diff-review-${DIFF_NUM}.md`
6. If issues found, injects a context message: "Background review found N issues — read /tmp/claude-diff-review-${DIFF_NUM}.md before submitting"

**What the main session does:** Continues working. The review runs in parallel. Before `jf submit`, check the review output.

**Why this is better than serial self-review:** The main session doesn't pause for 2 minutes while lint + review runs. The background agent catches issues you'd miss because it reads the diff with fresh eyes (separate context window). Two agents looking at the same diff from different angles catch more than one agent doing both.

## RADAR Auto-Stamp Optimization

Moved to `cheatsheets/diff/radar-autostamp.md` (on-demand). Load it when the goal is to get a diff to **auto-land without human review** — it covers the additions-OK/restructures-bad north star, hard blockers, the `radar_preflight` bash check, accept-rate erosion patterns, and Devmate anti-patterns. Not needed for a routine diff; the Pre-Submit Gate below stands alone.

## Submit Workflows

Default submit command: `jf submit --draft --publish-when-ready`. The `--publish-when-ready` flag auto-publishes the diff once CI signals go green — no manual publish step needed.

### New diff from scratch

**Always start from a public commit** to avoid accidental stacking on unrelated drafts:

```bash
sl goto 'last(public(), 1)'   # go to latest public commit
# make your changes
sl addremove                   # stage new/deleted files
sl commit -m "<commit message>"
jf submit --draft --publish-when-ready
```

If you skip the `sl goto`, your commit lands on top of whatever draft you were last working on, and `jf submit` auto-creates a "Depends On" link in Phabricator — which then has to be manually removed.

**After submit, return the diff link to the user:**
```bash
sl log -r . -T '{phabdiff}\n'
```

### New diff (first submit from existing uncommitted changes)

```bash
jf submit --draft --publish-when-ready
```

### Update diff with code changes

```bash
sl amend                                    # stage + amend code changes
jf submit --draft --publish-when-ready      # push to Phabricator
```

Verify after: `sl log -r . -T '{phabdiff}\n'` — confirm phabdiff association survived the amend.

### Update diff description only (no code change)

```bash
sl amend -m "$(cat /tmp/new-message.txt)"
jf submit --draft --publish-when-ready --update-fields --no-skip
```

**Both flags required.** Without `--update-fields --no-skip`, `jf submit` silently skips the description update because the code diff is unchanged. This is the #1 gotcha.

**Auto-handled by `jf` wrapper (since 2026-05-21):** `~/.bashrc` defines a `jf` function that adds `--update-fields --no-skip` to every `jf submit` invocation automatically. So in interactive shells, plain `jf submit --draft --publish-when-ready` already does the right thing after `sl amend -m`. The explicit flags above are only needed in scripts/cron that bypass bashrc.

**Pylon-mode draft enforcement (since 2026-05-24):** the same `jf` wrapper now ALSO auto-adds `--draft --publish-when-ready` whenever `$AGENT=myclaw` (i.e., Pylon is the caller). Rationale: Pylon amending one of Denny's published diffs via bare `jf submit` republishes v2 to reviewers immediately in Denny's voice, with zero human review of the agent's edit — happened twice on 2026-05-24 before this enforcement landed (D106197380 amend, D106237863 pre-fix). With this wrapper, even if Pylon forgets the flags, v2 sits behind v1 as draft until CI greens, then auto-publishes. Interactive shells (no `$AGENT=myclaw`) keep their existing manual control. Cron jobs that bypass bashrc must still pass the flags explicitly. **Hard rule for Pylon:** when amending an already-published Denny-authored diff, prefer to STOP at `sl amend` and tell boss — let him run `jf submit` himself. Falling through to wrapper-protected `jf submit` is the second-best option; bare `command jf submit` is the failure mode.

### Submit a stack

```bash
jf submit --draft --publish-when-ready --stack
```

To update descriptions across a stack without code changes:

```bash
jf submit --draft --publish-when-ready --stack --update-fields --no-skip
```

To fix missing stack dependencies (e.g., after inserting new diffs):

```bash
jf submit --draft --publish-when-ready --stack --no-skip
```

**Why `--no-skip`**: Without it, `jf submit` skips diffs with no code change, which also skips setting their dependency links. This can leave diffs floating with no parent in the Phabricator stack.

### Add reviewers

```bash
jf add-reviewer reviewer1 reviewer2 --stack
jf submit --draft --publish-when-ready --stack    # re-submit to sync reviewer changes
```

## Draft vs Publish

| Rule | Detail |
|------|--------|
| Always submit with publish-when-ready | `jf submit --draft --publish-when-ready` — auto-publishes when CI signals go green |
| Never publish programmatically | No `jf publish` — auto-publish via `--publish-when-ready` handles this |
| Draft versions on published diffs | If a diff is already published, `jf submit --draft` creates a draft version **behind** the published one; reviewers only see the published version until CI passes and auto-publish triggers |

### Fixing a prematurely published diff

If a diff was published by mistake, subsequent `jf submit --draft` won't make it "un-published." The user needs to manage visibility from Phabricator directly.

## Reviewer Discovery

When submitting a new diff and no reviewers are specified, discover them from recent history:

1. Find files changed in the current diff:
   ```bash
   sl diff --stat -r '.^' -r .
   ```

2. Search for the last 10 landed diffs touching those files using `knowledge_filtered_search` (doc_type: DIFF, use directory paths from changed files as keywords).

3. For each diff found, collect all **authors** and **reviewers** (unix usernames).

4. Count total appearances across all diffs. Each author appearance = 1, each reviewer appearance = 1. Exclude the current user (`$USER`).

5. Pick the top 3 by frequency.

6. Add them:
   ```bash
   jf add-reviewer <top1> <top2> <top3>
   jf submit --draft --stack
   ```

7. **Check for project reviewer groups** — look for Phabricator project reviewers (e.g., "MetaClaw Core Contributors", "Catalog DE") in the discovered diffs. These are added as `#project_name` in the Reviewers field. Project groups ensure the right team sees the diff even if individual reviewers are unavailable.

8. **Verify the group has members BEFORE adding it.** A 0-member project group on the Reviewers line is pure noise — it doesn't notify anyone, doesn't gate the diff, and a human triaging reviewers will (correctly) drop it. Add only groups with real members.
   ```bash
   # Returns JSON list of {unixname, name}; empty output = 0 members → DO NOT ADD
   meta phabricator.project.member list --name="<group_name>" -o json
   ```
   Real example: `D102407421` added `#minimal_viable_ai` (0 members) alongside `#mvai_infra` (10 members). Only `#mvai_infra` had review value; the other was clutter. Always run the membership check before adding a `#group_name` reviewer that hasn't been validated this session.

**Fallback:** If no recent diffs found on the same files, use static defaults from CLAUDE.md.

**Domain-specific reviewers** (always add in addition to discovered reviewers):
- **OT diffs** (online training alerts, OT pipeline configs, OT monitoring): add `mrs-ot-reliability`

## Test Plan Discovery

When the user does not provide a test plan, find reusable test commands from recent commit history before asking:

1. **Check recent commits on the same files** for test commands:
   ```bash
   # Find files changed in the current diff
   sl diff --stat -r '.^' -r .

   # Look at recent commits touching those files for test plan patterns
   sl log -r 'ancestors(.) & draft()' -T '{desc}\n' | grep -A 5 "Test Plan:"

   # Broader search: recent landed commits on the same files
   sl log -r 'last(public(), 20)' --template '{desc}\n' -- <changed-files> | grep -A 10 "Test Plan:"
   ```

2. **Extract and adapt test commands** — look for `buck2 test`, `buck2 run`, `python -m pytest`, `arc build`, or custom test scripts in those test plans.

3. **Reuse if applicable** — if a recent diff on the same files has a relevant test command, reuse it (adjusting target paths if needed) rather than leaving the test plan empty or asking the user.

4. **If no relevant history found** — then ask the user for a test plan.

## Post-Validation Rule

Once a test passes on a diff, immediately update the diff's test plan with the results and submit as draft. Don't wait for the user to ask.

**Test plan MUST add information CI signals don't already provide.** Unit tests, lint, pyre — all run by CI; their pass/fail shows up green/red in the diff signals automatically. A test plan that says only "buck2 test ... PASS" is **zero-value** — reviewers see the same green CI signal. The test plan should answer: *what scenarios did the human verify that CI cannot?* Required components:
- **Specific scenario**: golden path, edge case, OR failure mode reproduced (name it: "ConfigeratorException with empty config", "ILLEGAL_TMS_TRAINING_STATE on a hung job", etc.).
- **Functional output**: paste URL of the actual command output showing the BEHAVIOR CHANGE — not the unit test runner output. Run the CLI/script/handler with real args and capture before/after.
- **Manual verification CI can't run**: e.g., for an exit-code change, the test plan must show the actual exit code observed (`echo $?`), not just that the unit test passed.

Unit test runs can supplement, but never serve as the primary evidence. Counter-example: `D102408894` shipped with test plan = "buck2 test ... 3/3 PASS" + paste of unit test output. CI already showed those tests green; the paste added nothing the diff signals didn't have. The actual CLI exit-code behavior change wasn't verified end-to-end.

### Test plan rendering (Phabricator-friendly format)

Phabricator renders the Test Plan field as plain text with light markdown. Multi-line shell commands joined by `\` continuations are a common source of unreadable test plans — the second line displays without the first-line context, leaving readers staring at a fragment like `    -- --regex test_team_lane_scope` that means nothing on its own. Always format commands so each line stands alone or sits inside an explicit code fence.

| Anti-pattern | Why it's unreadable | Fix |
|---|---|---|
| Backslash-continued command across two lines without a code fence | Phabricator may eat the `\`, render line 2 as a standalone bullet/paragraph; the indented continuation looks like a typo to reviewers | **Single-line command** OR wrap the multi-line block in a triple-backtick code fence. Single-line is preferred — even at 120+ chars, modern terminals don't wrap commit messages |
| Test plan = literal command + "PASS 3/3" with no scenario | CI signals already show 3/3 pass; the test plan adds zero info beyond what's green in the diff UI | Lead with **scenario** ("S656729 fixture stops leaking via title hard-exclude") then command then result. The scenario is what CI can't say |
| Bare buck command with no testrun URL or paste | Reviewer can't replay the result without re-running the build | Always append `Testrun: https://www.internalfb.com/intern/testinfra/testrun/<id>` from the buck output OR `Paste: https://www.internalfb.com/intern/paste/<id>` for CLI output |
| Test plan describes the diff, not the verification | "Added test_x_does_y" mirrors the diff content; reviewer learns nothing about what was checked | Describe the BEHAVIOR change verified: pre-diff verdict vs post-diff verdict, exit-code observed, log line emitted |
| Test plan claims more than the diff delivers | Summary mentions 2 fixes, test plan tests both — but only 1 fix is in the diff (the other landed elsewhere). Devmate flags the drift | Re-read the diff stat before writing the test plan; only test what THIS diff changes. Move other-fix references to the Summary's "Reference:" line, not the test plan |

**Pre-submit check** (run BEFORE `jf submit`):

```bash
# 1. Render the test plan exactly as Phabricator will see it
jf diff-properties D<num> | jq -r '.message' | sed -n '/^Test Plan:/,/^Reviewers:/p'

# 2. Walk the rendered output line by line — does each line make sense in isolation?
#    If line N references something defined only on line N-1, fix it (single-line OR code fence).

# 3. Confirm at least one URL (testrun, paste, or behavior-change link) is present.
grep -E "internalfb\.com|fburl\.com|paste\." <(jf diff-properties D<num> | jq -r '.message') || echo "WARNING: test plan has no shareable evidence URL"
```

**Template** (copy-paste, then fill in scenario + URL):

```
Test Plan:
- **Scenario** — <what behavior changed; pre-diff state vs post-diff state>. The new test `<test_name>` pins this with the <fixture_name> fixture.
- **Command**: `<single-line buck/python command>`
- **Result**: Pass N. Fail 0. Build failure 0.
- **Testrun**: <url> (or **Paste**: <url> for CLI output)
- **Manual end-to-end check** (optional but strong): `<runtime command>` returns `<actual output snippet>` — confirms the runtime path matches the unit-test verdict, not just the regex/logic evaluation.
```

Counter-examples logged for posterity:

- D103409049 v1: `buck2 test ... \\` + ` -- --regex test_team_lane_scope` rendered as a fragment second-line ("`    -- --regex test_team_lane_scope`") that's meaningless without the first line. Fixed by collapsing to single-line command + leading scenario bullet. (Learned 2026-05-01: D103409049 — caught by Denny review, not Devmate, because Devmate inspects code not test-plan formatting.)

**Sequence:**
1. Run the functional test command and capture full output
2. Create a paste with the output (`create_paste_tool` or equivalent) — this provides durable, shareable proof
3. Update the test plan with: the exact command run, a one-line result summary, and the paste URL
4. Write updated commit message to `/tmp/<diff>-msg.txt` on the server
5. `sl metaedit -l /tmp/<diff>-msg.txt` — amend the commit message (preserves existing test plan rows + `Differential Revision:` footer)
6. Run repo-specific pre-submit checks (see repo cheatsheet)
7. `jf submit --draft --publish-when-ready --update-fields --no-skip` — push to Phabricator
8. Verify on Phab: `jf diff-properties <diff> | jq -r '.message' | grep -A 10 "Test Plan:"`

**Key points:**
- **Always create a paste for test output** — reviewers can verify results without re-running. A test plan with just "it works" is unverifiable. A paste URL is proof.
- Preserve existing test plan rows — append/update, don't overwrite
- Always keep the `Differential Revision:` footer line
- Use `--update-fields --no-skip` because only the message changed, not the code

## Post-Submit: Auto-Answer Privacy Pre-Screener

After `jf submit`, Phabricator shows a "Pre-screener validation" dialog asking if the diff touches user data. For config-only and infra diffs, the answer is always "No — None of these apply."

**Automated via hook** (`config/hooks/auto-prescreener.sh`): runs automatically after `jf submit` in configerator, fbsource, and www repos. No manual action needed.

**Manual command** (if the hook didn't fire or for other repos):
```bash
meta phabricator.diff attach-prescreener -n D12345 --type=none
# For an entire stack:
meta phabricator.diff attach-prescreener -n D12345 --type=none --include-stack
```

## Post-Submit CI Monitoring

After `jf submit --draft`, don't walk away. CI signals can take 1-2+ hours, but failures need prompt action — reviewers should never see a broken diff.

**Phabricator sync delay:** After `jf submit`, there's an async propagation delay (5-10s) before the new diff version is visible to review tools (automated reviewers, CI queries, `get_phabricator_diff_details`). Don't run automated reviews immediately after submit — you'll get stale data.

**Monitoring workflow:**
1. **Immediately after submit:** Confirm the diff link and note the D-number.
2. **Check CI status periodically** using `get_phabricator_diff_details` with `include_ci_overall_status=true` and `include_failing_ci_signals=true`.
3. **Enumerate failed signals — ALWAYS drill below the counter.** Run `meta phabricator.diff.signals list -n D<number> --status=failed` (add `-o json` for parsing). The ci-status aggregate ("N failed") and the bot-comment thread BOTH have false-negative modes: real unit-test failures often don't generate a top-level failure-bot comment, while meta-signals like `fbsource-report-build-speed-regression` do. Reading only the counter + comments can silently miss real test failures. The signals-list output is the source-of-truth — every red signal will be there. (See lesson row: D105191849, 2026-05-28.)
4. **On failure:** Read the error, diagnose root cause, fix, amend, resubmit. Don't leave failing signals for the reviewer to discover.
5. **On success:** Diff is clean for review. If `--publish-when-ready` was used, it auto-publishes.

**Practical pattern:** After submitting, set up a check (manual or via `/loop`) to poll CI status every 15-20 minutes. When CI finishes, act on results immediately — fix failures or confirm green.

**Auto-tracking:** After a successful `jf submit`, append a FOLLOWUP entry so the next session doesn't forget:
```
| <today> | <today+1d> | [ci] Check CI signals for D<number> — submitted <time> | pending |
```
This ensures CI monitoring survives session boundaries. Mark as done once CI is green or failures are addressed.

**GPU test monitoring:** When launching GPU tests via SSH (`buck2 test`/`buck2 run` on GPU servers), the same principle applies — tests can take 30-60+ minutes with no callback. After launching, add a FOLLOWUP entry with the server, test target, and expected completion time. Check results before context compacts or the session ends.

**Why this matters:** A diff sitting with red CI for hours signals neglect. Reviewers deprioritize broken diffs. Fixing CI promptly shows ownership and keeps review velocity high.

## Diff Completion Workflow

When completing a half-done diff (given a D-number):

1. **Fetch & understand** — get diff metadata via `get_phabricator_diff_details`, download with `jf get`, read all affected files, identify gaps between summary intent and actual changes
2. **Plan** — present what's missing, proposed changes, and risks before coding
3. **Implement** — follow existing codebase patterns and fbcode conventions (see `diff/fbcode-conventions.md`)
4. **Verify** — run checks in parallel (see `diff/verification-guide.md`):
   - `arc pyre check-changed-targets` (timeout: 2400s)
   - `arc lint -a` then `arc lint` (timeout: 2400s)
   - Test commands from the diff's test plan (timeout: 2400s)
5. **Iterate** — max 2 fix cycles per check. Re-run only failed checks. After 2 failures, stop and report.
6. **Commit locally** — `sl commit` with the original diff's `Differential Revision:` footer. Never `jf submit` — the commit stays local for author review.

### Verification Rules

- Run lightweight checks (pyre, lint) before tests — don't waste test build time on code with type errors
- Launch all checks simultaneously using parallel Task tool calls
- Track what failed, what was tried, what worked
- Pre-existing test failures are not your responsibility — note them in the summary

## Rebase Workflow

Always submit to Phabricator immediately after rebasing — a local-only rebase is invisible to reviewers and CI.

- **"rebase"** (default) = rebase onto `fbcode/stable`
- **"rebase to trunk"** = rebase onto the latest public commit: `sl rebase -d 'last(public(), 1)'`

```bash
# Default rebase (fbcode/stable)
sl rebase -d fbcode/stable
jf submit --draft --publish-when-ready

# Rebase to trunk (latest)
sl rebase -d 'last(public(), 1)'
jf submit --draft --publish-when-ready

# Always verify after
sl log -r . -T '{phabdiff}\n'
```

## Diff Can't Land — Diagnosis Checklist

When a diff fails to land or shows `LAND_RECENTLY_FAILED`, run these checks **in order** — earlier items are more common and cheaper to diagnose.

### 1. Rebase onto trunk (most common blocker)

Merge conflicts don't show up in Phabricator CI signals — they only surface locally.

```bash
sl goto D<number>
sl pull
sl rebase -d master
# If conflicts: resolve, sl resolve --mark, sl rebase --continue
jf submit --draft --publish-when-ready
```

**Standalone rebase (one commit out of a stack)** — when you want a single diff rebased to trunk without dragging its stack:

```bash
sl rebase -r <commit-hash> -d remote/master  # rebases ONLY that commit, leaves stack alone
sl goto <new-hash>                            # the rebase prints the new hash
jf submit --draft --publish-when-ready
```

For configerator diffs, run inside `~/configerator` (will abort with "is for repo 'configerator', not this repo ('fbsource')" otherwise).

**This is the #1 missed diagnosis.** Phabricator shows `LAND_RECENTLY_FAILED` but the diff details API returns no failing CI signals. The only way to find the conflict is to attempt the rebase locally.

### 2. Check parent diffs in the stack

If the diff is part of a stack, parent diffs must land first. A landed parent can also cause merge conflicts if it changed the same lines.

```bash
# Check stack position and parent status
get_phabricator_diff_details(D<number>, include_stack_dependencies=true, include_landing_status=true)
```

### 3. Check CI signals and land-blocking warnings

```bash
get_phabricator_diff_details(D<number>, include_failing_ci_signals=true, include_warnings_and_highlights=true)
```

Common land-blockers:
- **Devmate Reviewer** warnings marked `LAND_BLOCKING` — fix the code issue, amend, resubmit
- **Lint / arc f** failures — run `arc f`, amend, resubmit
- **Test failures** — diagnose and fix

### 4. Check review status

```bash
get_phabricator_diff_details(D<number>, include_diff_status=true, include_reviewers=true)
```

Diff must be `Accepted` to land. RADAR auto-approval alone doesn't change status to `Accepted` if human reviewers are explicitly listed.

### Diagnosis order rationale

| Step | What it catches | Why this order |
|------|----------------|----------------|
| 1. Rebase | Merge conflicts, stale base | Most common, invisible to Phabricator API, 30 seconds to check |
| 2. Stack | Parent not landed, dependency cycle | Second most common for stacked diffs |
| 3. CI | Lint, test, Devmate blockers | Visible in API but can take minutes to query |
| 4. Review | Not accepted, missing reviewers | Usually obvious from diff page |

## Unstacking Diffs (Removing Phabricator Dependencies)

After rebasing a diff out of a stack, the Phabricator "Depends On" link persists even after `jf submit`. Remove it explicitly:

```bash
meta phabricator.diff remove-dependency -n D<source> -d D<dependency>
```

**`jf unlink` does NOT do this** — it only strips the `Differential Revision:` footer from the commit message (dissociating the commit from the diff). To remove inter-diff dependency edges on Phabricator, you must use `meta phabricator.diff remove-dependency`.

**Auto-clear by cron (since 2026-05-21):** `cron-diff-signal-monitor.sh` runs `metadata_hygiene_clear_stale_deps()` on every queried diff. If your local parent is on `remote/master` but Phab still shows `depends_on`, the cron clears it the next morning. Manual `remove-dependency` only needed when you want it cleared *now*.

**Auto-fix of RED Denny-authored diffs by cron (`cron-diff-signal-monitor.sh`), in escalating order of generality:**
1. **Deterministic recipes** (`lib/diff-fix-recipes.json` + `diff_fix_recipe.py`) — known mechanical classes (missing BUCK dep, materialized drift, stale-dep clear, coverage pragma…).
2. **CLASS 1.5 pyre narrowfix** (`lib/pyre_narrow_fix.py`) — ONLY Pyre `[16]` "Optional has no attribute" → `none_throws()` wrap, verified-green-or-revert.
3. **CLASS 1.7 generic LLM-fix** (`lib/diff_generic_llm_fix.sh`, since 2026-06-09) — the broad fallback for everything the above two miss (wrong attr name, bad import, signature/type mismatch, small test/build errors). Checks out the red diff, grounds an LLM with the failing signal + local pyre errors, fixes ONLY the diff's files (never land/comment/out-of-scope), then **verify-or-revert** (pyre clean + `arc lint` + in-scope) and resubmits with the version-bump postcondition. Bounded `GENFIX_MAX_PER_RUN=2`/`PER_DIFF=2`, durable version-keyed markers, explicit author guard; failures fall through to escalation unchanged. Toggle `GENERIC_LLM_FIX_ENABLED=0`. Built after D106859590's unmanaged-Pyre "wrong attr name" red kept needing a manual fix.
   **Implication for interactive triage:** before hand-fixing a red Denny diff, expect the cron has already attempted (or will attempt) a fix — check the latest version + `state/diff-flywheel/genfix-attempts/<diff>.json` first; only step in if it hit the per-diff cap or genuinely needs human judgment (reviewer accept, product call).

## Common Gotchas

Moved to `cheatsheets/diff/diff-common-gotchas.md` (204 lines). Load when needed.

## Verification Checklist

After any diff operation, verify:

| Check | Command |
|-------|---------|
| Diff link returned to user | `sl log -r . -T '{phabdiff}\n'` — share with user after submit |
| Phabdiff associated | `sl log -r . -T '{phabdiff}\n'` |
| All stack footers correct | `sl log -r "ancestors(.) & draft()" -T "{node\|short} {phabdiff} {desc\|firstline}\n"` |
| Correct commit message | `sl log -r . -T '{desc}\n' \| head -5` |
| Phabricator updated | `jf diff-properties D12345678 \| jq -r '.message' \| head -10` |
| Diff status | `jf diff-properties D12345678 \| jq -r '.status'` |
| Stack order | `sl log -r 'ancestors(.) & draft()' -T '{phabdiff} {desc\|firstline}\n'` |

## Post-Land: Update Linked Tasks

When a diff lands and has a linked Meta Task, update the task with measured impact. Use the `tasks` skill for CLI operations. Quick version:

```bash
tasks update T<number> --comment "Landed D<number>. Impact: <measured outcome>. Before: <state>. After: <state>."
```

If the task's exit criteria are met, close it:

```bash
tasks update T<number> --close --comment "Exit criteria met: <evidence>"
```

## Cross-Diff Propagation (Stack Reviews)

When fixing an issue in one diff in a stack, check all subsequent diffs for the same unfixed pattern. Maintain a mental propagation table:

| Fix applied in | Pattern | Check in remaining diffs |
|---------------|---------|--------------------------|
| D1 | Missing `# pyre-strict` header | D2, D3, D4 |
| D2 | Unused import removed | D3, D4 |

This prevents "fixed in diff 3 but not in diff 7." After addressing review comments on any diff in a stack, scan the rest of the stack for the same issue before resubmitting.

## Auto-Learn from Review Comments

When a reviewer catches a pattern bug (not a one-off domain issue), update the repo-specific cheatsheet under "Common Review Comment Patterns" before making the code fix. This prevents the same mistake from recurring. See `cheatsheets/diff/fbcode.md` for examples.

### Fixing Your Own Diffs (Root-Cause Discipline)

When addressing reviewer comments on a diff Claude created, don't just fix the code. For each comment:

1. **Fix the issue** in the code
2. **Root-cause why you missed it** — what check would have caught this before submission? Was it a broken cross-reference after a rename? A count that didn't match? Duplicated content that drifted?
3. **Update the workflow** — add the missing check to the pre-submit gate, self-review checklist, or cheatsheet so it doesn't recur
4. Then resubmit

Treating reviewer comments as just code fixes wastes the learning. Each comment is evidence of a gap in the pre-submit workflow. Fix the gap, not just the symptom.

## Common Mistakes

Specific dated review-feedback rows (what-happened / correct-approach, each with its `(Learned YYYY-MM-DD: D...)` provenance) moved to `cheatsheets/diff/diff-learnings-log.md` § Common Mistakes. The recurring shapes are already enforced by the Pre-Submit Gate, Self-Review, and Devmate Anti-Patterns sections above; the log is the searchable evidence trail.

### Stack-wide devmate sweep — bottom-up amend-and-restack

When a stack of N diffs has devmate findings on multiple levels, fix them in one pass without per-diff submits:

1. **Pre-flight**: `sl log -G -r 'draft() & ::.' -T '{node|short} {phabdiff} {desc|firstline}\n'` to see the stack shape. If dependency edges need to change, rebase first: `sl rebase -d <new-parent-commit> -r <child-commit>`.
2. **Fix bottom-up**: `sl goto <bottom-commit>` → edit → `arc lint -a` → `arc pyre check-changed-targets` → `sl amend`. Sapling auto-restacks every descendant with the new parent hash.
3. **Repeat** for each commit in stack order. After amending the top commit, the stack is fully fixed.
4. **One submit at the end**: `jf submit --draft --publish-when-ready --stack --no-skip`. The `--no-skip` is mandatory — without it, diffs whose code didn't change but whose dependency edge moved get skipped, leaving Phabricator's `depends_on` link pointing at the old parent.
5. **Verify dependency**: `meta phabricator.diff metadata -n D<top> -o json | jq -r '.depends_on'` should return the new parent's D-number.
6. **Pitfall**: if `jf submit` warns `Field "revisionID" occurs twice in commit message!`, the diff's footer accumulated a stale empty `Differential Revision:` line above the real one — `sl metaedit -l <fixed-msg.txt>` to remove the empty line, then re-`jf submit --stack --update-fields --no-skip`.

Per-diff submits in the middle of the sweep churn the stack: every `sl amend` rewrites the descendant hashes, so each `jf submit` re-targets all the diffs above. The stack-wide single-submit is faster AND avoids the duplicate-footer pitfall.

### When to trigger an auto-learn pass

Run the auto-learn extraction on a diff whenever **3+ reviewer comments** land — regardless of whether they're BLOCKING or nit. A single diff with 3+ comments almost always hides 2-3 pattern gaps (not one bug repeated three ways). Converting each comment into a cheatsheet row amortizes the cost: next time a diff touches the same territory, the checklist catches the issue pre-submit instead of after reviewers have to type it out.

Threshold rationale: at 1-2 comments, the signal-to-noise ratio favors per-diff fixes. At 3+, the expected value of a generalizable learning exceeds the cost of running the pass.

## See Also

`cheatsheets/diff/review.md` (reviewing diffs), `cheatsheets/system/meta-tasks.md` (task tracking, impact measurement), `cheatsheets/diff/fbcode-conventions.md`, `cheatsheets/diff/verification-guide.md`

## Pyre Optional-narrowing across context managers (2026-05-30/31)

| Pitfall | Fix |
|---------|-----|
| Wrapping an `if x is not None:`-narrowed attribute access in a NEW `with`/context-manager (e.g. `with log_event_context(...): self._opt.method()`) drops Pyre's narrowing → `[16] Optional has no attribute X`. The intervening call invalidates instance-attribute narrowing. Recurred 3× in the MVAI ETT-logging stack (Optional.clear, on_train_batch_end). | **Bind to a local before the wrapper:** `local = self._opt` then use `local` inside the `with`. (Or `none_throws(self._opt)`.) Mirrors the existing in_trainer_publisher pattern in trainer.py. |
| Verifying/auto-fixing a CI type-check failure with `arc pyre check-changed-targets` — it can check a DIFFERENT/incomplete target set than CI (it checked `trainer_test-library` but not `trainer:trainer-type-checking`), so a real `[16]` is missed → false "no fixable errors". | **Verify against the target CI actually flags:** `arc pyre check-owning-targets <changed .py file>` (resolves the file's real type-check target), or parse the CI signal's own target. Discover + verify steps must use the SAME target set. |

## Diff-signal automation: dual-mode CI signals & redundant-conflict diffs (2026-06-01)

| Pitfall | Fix |
|---------|-----|
| Blanket name-muting a CI signal that can fail for BOTH real and flaky reasons. `fbsource-target-determinator` was on the noise allowlist (matched by signal NAME only, never the message), so the cron silently demoted a **real merge conflict** to green and left the diff red for hours. TD runs by *applying the diff onto trunk* to compute targets → it fails for (a) transient infra AND (b) the diff doesn't merge cleanly. | **Never name-mute a dual-mode signal. Route it to retrigger-defer (CLASS 2):** flake clears on retrigger (silent); a real conflict survives the retrigger → escalates next cycle with an action. Persistence across a retrigger is the flake-vs-real discriminator the name can't give you. Before adding any signal to a noise allowlist, ask "can this also fail for a real, actionable reason?" — if yes, retrigger-defer, don't mute. |
| `fbsource-target-determinator` failing → assuming infra noise. Most often it's a **merge conflict / stale base**. | Diagnose: `jf get D<n> && sl rebase -d remote/master`. If it conflicts, it's a real merge conflict — rebase & resolve (or for machine-synced/state files, regenerate from source, don't hand-merge). |
| Treating a "conflicting" diff as needing manual conflict resolution when it's actually **redundant** — its changes already landed on trunk via another path (e.g. you edited canonical notes, the notes→fbcode sync landed them, and your manual fbcode diff became a stale duplicate that now "conflicts" because trunk already has its changes). | Before hand-merging, check whether trunk already contains the diff's changes (`grep` the key content in the trunk checkout + canonical source). If yes → `meta phabricator.diff abandon` (an allowed Phab write — state change, no comment), don't resolve. |

## Unstick a wedged Configerator/ULE land (2026-06-01, D106903024)
Symptom: config diff stuck `LAND_ON_HOLD`, `regional_config_validation` canary hung `Pending`.
Diagnose: `meta phabricator.diff land-status -n D<n>` + `meta phabricator.diff.land-attempts list -n D<n>`.
`land_start_time=N/A` = land confirmed but not started — but this is NORMAL for the first few min
(waiting on canary); only WEDGED once it persists ~1h+.
Dead ends: `ci-trigger` (rejected — "not in deferred state"), re-`land` (ULE wait_for_all re-blocks),
no `land-attempts` cancel subcommand.
FIX = mint a fresh version (abandons the wedged attempt, fresh canary):
  cd ~/configerator; jf get D<n>; sl pull; sl rebase -r <commit> -d remote/master   # LATEST trunk
  conf build                       # rebase invalidates the mutation; background it (can exceed 10-min cap)
  conf submit --diff D<n> --non-interactive --verbatim   # NOT jf submit; no --draft/--create
The old attempt gets a verdict_time (superseded); new version is Accepted + landable + fresh CI.
CAVEAT (IC7): instance fix, not category. Unstuck ≠ landed — confirm the fresh canary completes.
If it hangs AGAIN → Configerator/ULE canary INFRA problem → escalate to land oncall, do NOT re-rebase.
NEVER `conf ship` without the user's explicit go (prod config land).

## LAND_FAILED with green CI = rebase-able conflict (not "unfixable") — 2026-06-03

A diff showing **LAND_FAILED / LAND_RECENTLY_FAILED while CI is green** (0 failing signals) is almost
always a **stale-base merge conflict**, which is fixable — do NOT call it "not a fixable red" or assume
"revision not accepted". Fix:
```
sl pull
sl rebase -r D<n> -d remote/master      # the real conflict surfaces here, not at land
# resolve, then:
jf submit --draft --update-fields
```
- **ALWAYS `jf submit --draft`** (never push live) — esp. for `publish_when_ready`/override diffs, which
  can auto-land on a non-draft submit. (Corrected 2026-06-03 — pushed D107349427 non-draft by mistake.)
- **Stacked / unpublished ancestor:** isolate the target before submit/land so you don't drag an
  unpublished diff or dupe commits into the land: `sl rebase -r D<n> -d remote/master` (standalone on
  master), verify file count is unchanged, then draft-submit.
- **OT-bot notes→fbcode mirror conflicts:** notes is canonical → `sl resolve --all --tool :other`
  (take the sync/notes side). The fbcode state files are a bootstrap mirror, not authoritative runtime
  state, so taking the snapshot is safe; the next sync re-mirrors current.
- The `diff-signal-monitor` cron auto-rebases this for the `[OT bot weekly sync]` category
  (`try_autorebase_mirror_diff`, draft-only, code/BUCK-gated). Other categories still escalate.
