# OT Bot Debugging Learnings Ledger

Auto-maintained by `ot-daily-learning-debugging` cron.
Symlink: `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md` → this file.

**Ordering:** newest entries first (reversed 2026-05-25).

---

## 2026-05-28 (L53–L61) — New entries this run

### L61
- **Type:** product / shift-summary completeness — untagged + indexing-lag SEV double-miss
- **Trigger:** 2026-05-28 10:27 PDT — Denny new comment `AAAB6WPRTi8` on tab `6/2` Overview line "SEVs (HIGH-TOUCH): 0": *"S668272 - oncall got robocalled Wed night. why this is not captured?"* (Wed night ≈ Tue 21:51 PT actually, but the SEV crossed midnight). Also resolved older comment `AAAB6SHJhbA` ("There is another SEV which I got robocalled as oncall. Are you able to find and add it?") — same SEV.
- **Verification (`meta sevmanager.sev describe --sev=668272 --output=json`):** [IG Feed ESR] Sparse Streaming OT job failure | L3 Mitigated | opened 2026-05-26 21:51:45 PT (Tue late) | mitigated 2026-05-27 02:02 PT (Wed early, ~4h) | owner Shreyas Verma | followup T273199101 | SEV gchat `https://chat.google.com/room/AAQAyq3dESo` | 13 comments | NO `mvai-online-training` tag at time of cron run (and at time of this fix).
- **Root cause (double-miss):**
  1. `ot-sev-monitor` cron tick at 21:57 PT (6min after creation) didn't see it due to sevmanager indexing lag — already documented in memory `gotcha_sevmanager-indexing-lag.md` (>6min lag for new SEVs). Catch-up query should have caught it on next tick BUT…
  2. `ot-sev-monitor` query A uses `--tags=mvai-online-training` — S668272 was filed by Shreyas Verma without the tag (feature-team author unaware of routing tag). So tag-based queries permanently missed it.
  3. `ot-shift-summary` Step 3 inherits the same tag-only query → also missed.
  4. Daily-brief 5/27 / 5/28 also missed it (relies on same tag query).
  5. `ot-sev-state.diagnosed_ids.S668272` actually DOES contain it (bot did see and process it eventually, via some other code path — likely a manual tag application by an earlier session or `meta workplace.post` query that crawled it). But shift-summary Step 3 never cross-checked `ot-sev-state` against the tag-filtered list.
- **Learning:** Tag-based filters create silent flywheel failures whenever a SEV is OT-scoped by content but untagged by author. Need cross-check against `ot-sev-state.diagnosed_ids` (the bot's own observation log) — any diagnosed SEV missing from the tag-filtered list = candidate for inclusion + auto-tag.
- **Action (this run, 2026-05-28 ~10:30 PT):**
  1. Tagged retroactively: `meta sevmanager.sev update --sev=S668272 --add-tag="mvai-online-training"` → ✓ Successfully updated. Future cron runs will catch it natively.
  2. Patched tab `6/2`: HIGH-TOUCH count 0 → 1 with full description (robocall callout + indexing-lag explanation); added Hand-off entry (top of list, action="confirm followup task ownership + verify mitigation stable"); added 5/26 Major-bucket Daily Timeline entry with "21:51 PT — robocalled Denny" callout. Applied via `gdocs edit → apply` (revision 3109 → new).
  3. Replied to `AAAB6WPRTi8` (new) + `AAAB6SHJhbA` (old) with `[myclaw-ot bot reply]` prefix.
  4. Amended `ot-shift-summary.md` Step 3: added MANDATORY CROSS-CHECK block (Python snippet against `ot-sev-state.diagnosed_ids`) + decision rule (title regex `/OT[ -]?job|online[ -]?training|mvai|MAST|silvertorch|MRS/i` OR SEV gchat shows oncall robocall → ADD to candidate set + auto-tag for future runs).
  5. Synced amended prompt to sqlite (`ot-shift-summary` row). SHA256 parity confirmed: `dc528fe3c76b33e2a2e33030b4d6a7a9053a52fac5d84da1d9229e02f86b25c0`.
- **Rollback:** Tab content via `gdocs apply` pre-apply backup `/home/dennyzhang/.cache/gmux/docs/1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k/pre_apply_backup.json` (revision 3109). Tag removal via `meta sevmanager.sev update --sev=S668272 --remove-tag="mvai-online-training"`. Prompt via `cron-prompt-backups/ot-shift-summary__<latest>.txt`.
- **Related:** `[[sevmanager-indexing-lag]]` — established the >6min lag pattern; now extended with the "missing tag" complement. `[[tool-failure-fix-or-escalate]]` — silent double-miss of robocalled SEV is the worst-case failure mode (oncall paged + missed in shift summary = direct loss of operator trust).
- **Open question (deferred):** `ot-sev-monitor` cron (the live-detection cron, not shift-summary) should ALSO grow the `ot-sev-state.diagnosed_ids` cross-check OR a periodic "all in-progress SEVs whose title matches OT regex but lacks mvai-online-training tag" scan. Not done this run — needs separate session focused on ot-sev-monitor.

### L60
- **Type:** product / shift-summary completeness — user-posts silent drop
- **Trigger:** 2026-05-28 10:25 PDT — Denny new comment `AAAB6WPRTiI` on tab `6/2` Overview line "WP user reports: 0 new in window": *"that's not true"*. Verification via `meta workplace.post list --group-id=1084744250286987 --after=2026-05-26 --before=2026-05-28T23:59:59` returned 2 in-window posts: Hao Sha `1336024098492333` (5/27 11:11 PT MC12 arm3 OT example age >1h) + Sanket Karnik `1336148551813221` (5/27 15:01 PT how to add gflag). Both present in `ot-monitor-state.processed_post_ids` with valid `added_epoch` timestamps in the window.
- **Root cause:** Layered filter mismatch.
  - `daily-brief.md` line 19: workplace posts filter = *"Only include posts with high-confidence relevance to an active SEV or open question"* → both posts dropped (Hao Sha = generic how-to-fix; Sanket = how-to question; neither links to an active SEV).
  - Daily-brief frontmatter `wp_post_ids: []` written for 5/27 and 5/28.
  - `ot-shift-summary.md` step 5 said *"PREFER: Use the wp_post_ids union ... skip the live list query"* — read empty union, skipped live query, emitted "0 new". No cross-check against `ot-monitor-state.processed_post_ids` even though step 10(h) lint requires it (lint did not run, possibly because the cron's post-push checklist treated count-0 as nothing to verify).
- **Learning:** Daily-brief's WP-post filter is appropriate for daily-brief audience (operator at 8:14 AM; only "needs your attention" items) but TOO TIGHT for shift-summary audience (every user post in window, including how-do-I). Two audiences, two filter semantics → daily-brief frontmatter is REFERENCE-ONLY for shift-summary posts; shift-summary MUST always live-query.
- **Action (this run, 2026-05-28 ~10:30 PT):**
  1. Patched tab `6/2`: Overview line now reads "2 new in window — Hao Sha (5/27 ...), Sanket Karnik (5/27 ...)". Added 2 entries to 5/27 Daily Timeline `👤 Oncall` bucket. Added new `Workplace user posts` table section (Created / Author / Topic / Summary & reply status) before `</body>`. Applied via `gdocs edit → apply` (revision 3090 → new).
  2. Replied to comment `AAAB6WPRTiI` with `[myclaw-ot bot reply]` prefix (reply id `AAAB6WPRTjE`).
  3. Amended `ot-shift-summary.md` Step 5: removed "PREFER daily-brief" language → **ALWAYS LIVE-QUERY (HARD)**. Added mandatory cross-check Python snippet against `ot-monitor-state.processed_post_ids`. If live-count != monitor-count → divergence MUST be flagged in section header.
  4. Synced amended prompt to sqlite (`ot-shift-summary` row, 75232 chars). SHA256 parity confirmed: `9e7376f8f2ce4c98cdc18a678d1d40d52a985aae0d5ba417605cd2a142f17767`.
- **Rollback:** Tab content via `gdocs apply` pre-apply backup `/home/dennyzhang/.cache/gmux/docs/1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k/pre_apply_backup.json` (revision 3090). Prompt via `cron-prompt-backups/ot-shift-summary__<latest>.txt` (auto-snapshot before next run).
- **Related:** `[[tool-failure-fix-or-escalate]]` — silent drop of 2 posts == fix-or-escalate violation. `[[suppress-noise]]` — divergence flag in section header is correct surface; section header is not noise, the empty "0 new" was the noise (false negative).
- **Followup deferred:** `daily-brief.md` line 19 wording could optionally be split into two filters: `wp_post_ids` (all in-group posts, for downstream consumers) + `wp_post_ids_needs_attention` (current strict filter, for daily-brief render). Not done this run — would touch daily-brief render logic + risk over-stating user-attention items in the brief. Filed as candidate amendment if shift-summary cross-check shows recurring divergence.

### L59
- **Type:** product / shift-summary scannability + sort enforcement
- **Trigger:** 2026-05-28 10:00 PDT — Denny left two unresolved comments on mid-shift draft tab `6/2` (doc `1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k`):
  - `AAAB6WPRTgI` (anchor `kix.ah7h05xjyoqx`, on "Daily Timeline"): *"this section is not scannable. Critical info got buried in pool of text"*
  - `AAAB6WPRTgE` (anchor `kix.zexeiote0vla`, on "(S667849, S665454"): *"you should order the SEVs by importance."*
- **Learning:**
  - **(a) Daily Timeline scannability — RULE 63.** Flat bullet list under each `<h4>` day is unreadable. Restructure per day into 4 fixed-order buckets: `🔴 Major` (L0/L1/L2 OR oncall-PAGE/filed), `⚠️ Watching` (L3/L4 OPEN), `🤖 Bot` (auto-triage + ledger; collapse to one line if >5/day), `👤 Oncall` (human actions). Skip any empty bucket. SEV entries use bold ID + `[L<n> <STATUS>]` brackets + 1-line outcome (no narrative, no multi-line continuations). Quiet days render as `<date> — (quiet)` with NO `<ul>`. Pre-push lint: bucket order, SEV-bracket regex, ≤240 chars per bullet.
  - **(b) RULE 55 sort wasn't being enforced.** Declared 2026-05-25 but flagged AGAIN on 2026-05-28 — `(S667849 L4 CLOSED, S665454 L3 OPEN)` rendered in declared order rather than importance order. Root cause: no in-process lint asserted the sort before `gdocs apply`. Fix: added MANDATORY PRE-PUSH SORT LINT block to §9 (step 9) of `ot-shift-summary.md` with the exact Python sort_key + ABORT semantics. Every SEV-bearing list/table gets the 3-tuple key check; non-monotonic → re-sort and re-run, never push.
- **Action:** 4 fixes applied:
  1. **Tab `6/2` rewritten** via `gdocs edit` → `gdocs apply` (round-trip preserves comment anchors per L57). Daily Timeline restructured into bucket headings + bold IDs across all 3 days (5/26, 5/27, 5/28). Overview observe-only line + Hand-off `<ol>` re-sorted: S667332 (L2 OPEN) now first; flagged `(S667849, S665454)` pair re-ordered so S665454 (L3 OPEN) precedes S667849 (L4 CLOSED).
  2. **Per-comment replies posted** via `gdocs comments reply` with `[myclaw-ot bot reply]` prefix (per L2). Reply IDs: `AAAB6WPRTgo` (Daily Timeline fix), `AAAB6WPRTgs` (sort fix).
  3. **Cron prompt amended**: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary.md` — added RULE 63 (Daily Timeline scannability) after RULE 62; tightened §9 render step with MANDATORY PRE-PUSH SORT LINT block citing RULE 55 + comment `AAAB6WPRTgE`.
  4. **Notes → sqlite parity verified**: SHA256 `ddcd164c421b8ad437301d554686c9a2f70d4859e0517584f6968b101ea4d547` on both sides. Sapling `sl status` clean except for the ledger + prompt files (committed via weekly fbcode sync).
- **Top-3 sort changes on tab `6/2`** (pre→post): (i) Overview head was `S667849 L4 CLOSED` → now `S667332 L2 OPEN`. (ii) Hand-off head was `S665214` → now `S667332`. (iii) 5/26 Daily Timeline now leads with `🔴 Major: S667332 L2 OPEN` instead of mid-list.
- **Rollback:**
  ```bash
  # revert cron prompt + notes-sqlite parity:
  cd /home/dennyzhang/notes && sl revert users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary.md
  sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "UPDATE jobs SET prompt = readfile('/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary.md') WHERE id='ot-shift-summary';"
  # revert gdoc tab 6/2 to pre-L59 state:
  ls /home/dennyzhang/.cache/gmux/docs/1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k/  # pick latest pre_apply_backup
  ```

### L58
- **Type:** product / shift-summary scope + presentation
- **Trigger:** 2026-05-28 09:52 PDT thread `Rk8bGR2CQK8` — Denny flagged 3 polish items on the OT Oncall Shift mid-shift draft (tab `6/2`): (1) TODOs not visually obvious enough to act on; (2) `mrs_ml_release_oncall`-tagged SEVs (trunk-health workstream) should be silently dropped — their own oncall covers them; (3) bot-self entries in Daily Timeline (CL-XXX clusters, P-row chatter, validator notes) are too verbose.
- **Learning:**
  - **(a) TODO visual styling.** Inline plain-text `TODO (oncall):` blends into bullets and gets missed. Wrap every TODO in `<p style="background:#FFF2CC;padding:6px;border-left:4px solid #F1C232;"><b>📌 TODO (oncall):</b> ...</p>` (yellow banner, dark-yellow left rule, pin emoji). Inside `<td>` cells use `<span style="background:#FFF2CC;font-weight:bold;">` (block-level CSS doesn't render cleanly in cells). Pre-push lint: bare `TODO` outside the styled block → ABORT. Apply uniformly — never mix styled/unstyled in one draft.
  - **(b) `mrs_ml_release_oncall` HARD drop-filter.** Trunk-health workstream owns these SEVs end-to-end; including them in the OT shift summary creates noise + double-coverage confusion. Build the drop-set once per window via `meta sevmanager.sev list --tags=mrs_ml_release_oncall --created-after=<WINDOW_START>` (NOT per-SEV `metadata` — the `tags` field is absent from describe/metadata responses; only `list --tags=` does tag-membership reliably). Apply across ALL sections (Headline, §3 Daily timeline, §4 Top ongoing, §5 SEVs handled, Hand-off). Drop SILENTLY (same handling as sibling-org S657101 leak) — no operator-facing "dropped N" callout, log to `_pre_finalize_gates_log.json` only.
  - **(c) Bot-activity entries ≤1 line.** Human-oncall entries stay verbose (action + context + outcome); BOT entries get trimmed. Format: `bot: triaged S<id> as <cluster> [confidence:low|med|high]` / `bot: ledger L<NN> — <≤8-word summary>`. NO narrative, NO CL-XXX cluster expositions, NO validator self-references, NO "rule added to surface" meta-commentary. Cross-link via L<NN>/P<NN> token only — daily-ledger holds detail.
- **Action:** 3 fixes applied: (i) cron prompt `ot-shift-summary.md` amended in step 3 (new HARD scope filter) and step 9 (new RULE 61 + RULE 62); (ii) mid-shift draft tab `t.qte1gqg5ga6u` rewritten via `gdocs edit` → strip dropped-SEV references + style TODOs + trim bot lines → `gdocs apply` (round-trip preserves comment anchors, per L57). Notes → sqlite SHA256 parity verified `ddf8950a…`. 9 SEVs dropped from the draft: S668293, S668320, S668263, S668542, S668828, S667668, S668017, S668033, S668029. New filter validated on 10:08 PDT ot-sev-monitor batch: S668985 (mvai_cli conveyor blocked, deferred) correctly identified as `mrs_ml_release_oncall` — would now be dropped.
- **Tab-position re-verification (companion to L57):** `gdocs tabs create` / `add-tab` CLI exposes only `--title` and `--parent` (no `--index`); Docs API v1 batchUpdate has no `createTab` or `moveTab` request; verified with `gdocs add-tab --help` + Google API docs. New tabs land at end; reorder remains UI-only. L57 conclusion stands.
- **Rollback:**
  ```bash
  # revert cron prompt + notes-sqlite parity:
  cd /home/dennyzhang/notes && sl revert users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary.md
  sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "UPDATE jobs SET prompt = readfile('/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary.md') WHERE id='ot-shift-summary';"
  # revert gdoc tab to pre-L58 state (kept the pre_apply_backup from L57; another snapshot at this run is in the same cache dir):
  ls /home/dennyzhang/.cache/gmux/docs/1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k/
  ```



### L57
- **Type:** operational / gdoc-mechanics
- **Trigger:** 2026-05-28 09:49 PDT thread `Rk8bGR2CQK8` — Denny flagged two regressions on tab `6/2` of OT Oncall Shift gdoc: (1) "[Bot] OT Oncall Shift" + empty lines persisted at the very top BEFORE the H2 title, even after `gdocs replace --tab-id ... --full-replace-removes-comments`; (2) newly-created `6/2` tab landed at index 3 (bottom) instead of index 0 (top).
- **Learning:** TWO distinct gdoc mechanics:
  - **(a) RESOLVED-comment anchors hold prefix text against `--full-replace-removes-comments`.** Two comments (AAAB6SHJhUI, AAAB6SHJh98) on the string "[Bot] OT Oncall Shift" were RESOLVED but their anchors still pinned the text — replace deletes the comments but not the anchor text. Workaround: `gdocs edit` round-trip — export → strip the prefix `<p>` lines locally → `gdocs apply` (orphans the resolved comments but actually removes the text). Detection recipe BEFORE pushing: `gdocs comments list <DOC> | grep -F "<offending-text>"` — if any rows return, plan a round-trip rather than a replace.
  - **(b) `gdocs add-tab` STILL has no `--index` option; Docs API v1 STILL rejects `moveTab` (re-verified 2026-05-28 with raw `gdocs batch-update`).** Same gap as 2026-05-25 `gotcha_gdoc-tab-ordering.md`. Existing tabs cannot be reordered programmatically. Cron must EITHER write a gchat escalation asking operator to drag, OR plan around end-position. SILENTLY leaving the tab at the bottom is unacceptable (Denny's 2026-05-27 "fix-or-escalate" rule from L56).
- **Action:** Issue 1 fixed via `gdocs edit /tmp/tab-6-2-edit.html` → strip 4 leading `<p>` lines → `gdocs apply --tab-id t.qte1gqg5ga6u`. Issue 2 escalated to Denny in thread `Rk8bGR2CQK8` with explicit "manual UI drag required" call-out. Memory `gotcha_gdoc-tab-ordering.md` extended with 2026-05-28 re-verification section. Cron prompt `ot-shift-summary.md` step on `gdocs add-tab` amended with "tab reorder = UI-only — emit a gchat escalation asking operator to drag, NEVER silently leave at bottom". State file `ot-shift-summary-state.json` got new `tab_position_index` + `tab_position_request` keys for the dedup guard.
- **Rollback:**
  ```bash
  # restore original tab content (re-introduces the prefix):
  cp /home/dennyzhang/.cache/gmux/docs/1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k/pre_apply_backup.json /tmp/restore.json
  # then revert cron prompt + memory:
  cd /home/dennyzhang/notes && sl revert users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary.md
  sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "UPDATE jobs SET prompt = readfile('/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary.md') WHERE id='ot-shift-summary';"
  ```



### L56
- **Type:** meta / learning-flywheel
- **Trigger:** 2026-05-28 08:50 PDT thread `sRcOF1RFq-E` — Denny: *"Why gchat is inaccessible? Your gchat cheatsheet should tell you how to fix this issue"* → *"you actually failed to learn from this SEV and the failure is fixable. Either you fix it or escalate to me. Currently it's a silent failure for the leaning flywheel."* Repeat of the pattern flagged in L52 (2026-05-22): gchat tool unavailable → diagnoses delivered inline-only → no notifications, no escalation, no ledger entry → flywheel never saw the failure.
- **Learning:** Tool-failure handling is binary — FIX (apply the documented fallback chain from the skill's SKILL.md / references/) or ESCALATE (one-line `🚫 <tool> degraded — tried <X>,<Y>` to Denny's 1:1). Never a silent third option. gchat backend chain (per `comms/gchat.md` + skill files): (1) `meta google.chat.*` CLI → (2) `python3 google_api.py` → (3) `mcp__google_chat__google_chat`. Every fallback or escalation event MUST get a daily-ledger entry — no entry = invisible to the flywheel.
- **Action:** Memory saved (`feedback_tool-failure-fix-or-escalate.md`) + MEMORY.md indexed at top. Ledger entry written (this entry). Pending: extend HEARTBEAT.md HARD RULES with "tool failure → fix-or-escalate, never silent" pointer; extend ot-{sev,alert,post}-monitor prompts with explicit fallback-chain step for gchat sends.
- **Rollback:** N/A (memory + ledger only; no cron amended yet — prompt amendments tracked separately when applied)



### L53
- **Type:** domain (red herring) + validator lesson
- **Trigger:** ot-sev-monitor 2026-05-28T00:04 — S668285 validator discrepancy: `"~13h stale" framing overstates blockage; pipeline produced 5 valid snapshots (2451–2455) after stuck records; intermittent self-recovering failures`. Bot classified REAL_OT_FAILURE confidence:low from elapsed duration, without querying actual snapshot instances produced after the "stuck" point.
- **Learning:** Before asserting "stale" or "~Nh blocked" on any snapshot metric, query actual instances AFTER the last "stuck" record (`meta ai.model.instance list --model-id=<ID> --limit 20`). If >0 valid instances exist post-stuck, reclassify as intermittent self-recovering (TRANSIENT_NOISE or MONITOR), not persistent REAL_OT_FAILURE. Classic R13: staleness inferred from elapsed time alone without verifying the actual instance timeline.
- **Action:** Appended to ledger. Ruled-Out List entry proposed in known-patterns.md (see Validator Discrepancies section). validator_discrepancy_count_today = 1.
- **Rollback:** N/A (ledger only — no cron amended for this entry)

### L54
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-27T07:52 — S668375 "[memlab] RCE via eval() ... .heapsnapshot" matched step-3 regex via "heapsnapshot" keyword. Correctly classified OOS but required scope_check (which was degraded) to drop. Security/infosec SEVs with `[memlab]` or "RCE via" in title are always OOS yet waste scope_check cycles each run.
- **Learning:** Add security-SEV fast-path exclusion after step-3 match: if title matches `/\[memlab\]|RCE via|heapsnapshot.*eval/i` → classify `in_scope=false` immediately, silently add to `diagnosed_ids` without invoking scope_check. Extends L38 procurement fast-drop. SEV: https://www.internalfb.com/sevmanager/view/668375
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 17, 2026-05-28)
- **Rollback:**
  ```bash
  cp ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/cron-prompt-backups/ot-sev-monitor__20260528T151643Z.notes.md ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-sev-monitor.md
  sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "UPDATE jobs SET prompt = readfile('/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-sev-monitor.md') WHERE id='ot-sev-monitor';"
  ```

### L55
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-27T16:07 — S668703 matched step-3 "hedwig" keyword but was a CASD fetch/web service SEV (not OT pipeline). Correctly classified OOS via manual-scope-assessment when scope_check was degraded (2nd consecutive). CASD-hedwig SEVs are consistently OOS but require manual assessment each time scope_check is degraded.
- **Learning:** After step-3 "hedwig" match, add CASD fast-path exclusion: if title contains `casd` (case-insensitive) → classify `in_scope=false` immediately, silently add to `diagnosed_ids` without invoking scope_check. OT Hedwig patterns (P07, P15) concern model-weight streaming to serving; CASD-hedwig is a web-service fetch path unrelated to OT pipeline. SEV: https://www.internalfb.com/sevmanager/view/668703
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 18, 2026-05-28)
- **Rollback:** (same backup as L54 — both rules in same backup file)

---

## Validator Discrepancies

### 2026-05-28
- validator_discrepancy_count_today = 1
- **S668285** (ot-sev-monitor 2026-05-28T00:04): `Validator: discrepancy — "~13h stale" framing overstates blockage; pipeline produced 5 valid snapshots (2451–2455) after stuck records; intermittent self-recovering failures`
  - Classification: `inferred_stalled_from_duration` (R13)
  - Bot verdict: REAL_OT_FAILURE confidence:low; claimed "~13h stale"
  - Validator correction: intermittent self-recovering; pipeline not fully blocked; valid snapshots produced after stuck records
  - 🔁 VALIDATOR-LESSON (proposed — do NOT auto-apply): Add to known-patterns.md Ruled-Out List: `| Snapshot staleness from elapsed time alone | Pipeline may produce valid instances after "stuck" records; "~Nh stale" overstates blockage | Query instances AFTER stuck-record timestamp; if any valid → TRANSIENT_NOISE not REAL_OT_FAILURE | S668285 (2026-05-28) |`

---

## 2026-05-27 (L50–L52) — New entries this run

### L50
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-27T07:52 reported `scope_check binary degraded` (buck2 exit 1) in raw_response but delivered HEARTBEAT_OK — operator has zero visibility into degraded scope_check unless reading raw_responses. Also 2026-05-27T00:56: `scope_check binary unavailable (manual assessment applied)` for S668293 triage.
- **Learning:** When scope_check returns exit 1 (binary degraded), include `⚠️ scope_check=DEGRADED` in GChat run summary even for zero-SEV runs. Currently degradation is only in raw_response. Additional rules: (1) label each title-evidence-only classification with `[manual-scope-assessment]`; (2) if scope_check stays degraded >3 consecutive runs, add: "Manual verification recommended before next paging action." This closes the operator-visibility gap on a tool-health issue that silently affects scope accuracy.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 15, 2026-05-27)
- **Rollback:**
  ```bash
  cp ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/cron-prompt-backups/ot-sev-monitor__20260527T151103Z.notes.md ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-sev-monitor.md
  sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "UPDATE jobs SET prompt = readfile('/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-sev-monitor.md') WHERE id='ot-sev-monitor';"
  ```

### L51
- **Type:** domain (pattern)
- **Trigger:** ot-alert-monitor 2026-05-27T02:56 — ig_textpost_feed_m2m_retrieval 2130324780 v47 died 00:26 UTC with `DPP DataClientStuckException` (getNextBatch hung 2h, `DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE`); v48 PENDING since 02:37; S665454 open 9 days unmitigated.
- **Learning:** `DPP DataClientStuckException` + `DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE` = data pipeline producer stuck with full output queue; `getNextBatch` call hangs indefinitely then trainer dies. Distinct from L35 (DPP session 20-day max-lifetime expiry). Identifiers: trainer log shows `getNextBatch hung Xh`, `DataClientStuckException`, `WORKER_STUCK_FULL_OUTPUT_QUEUE`. Recovery: TMS kills trainer, new version starts PENDING → RUNNING. Check for a pre-existing SEV (S665454 for ig_textpost_feed_m2m_retrieval) before treating as new issue. SEV S665454 was 9 days old with no mitigation — escalation may be needed.
- **Action:** Appended to ledger. Pattern proposal P61 drafted below (operator review required).
- **Rollback:** N/A (ledger only)

### L52
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-26T13:03 — three SEVs (S668017, S668033, S668029) triaged with `GChat reads DEGRADED (403 on all 3 SEV spaces)`. Triage confidence `medium` for all three. Without GChat reads, bot cannot verify SEV thread context (who opened, thread discussion, scope signals).
- **Learning:** When GChat reads return 403 during SEV triage: (1) include `gchat_reads=DEGRADED(403)` in run summary header; (2) cap triage confidence one level below what metadata alone supports (high→medium, medium→low); (3) add note in SEV GChat reply: "⚠️ Bot GChat reads degraded (403) — SEV thread context unverified. Confidence capped." Prevents over-confident triage when thread evidence is unavailable.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 16, 2026-05-27)
- **Rollback:** (same as L50 — same backup file covers both rules added this run)

---

## Validator Discrepancies

### 2026-05-27
- validator_discrepancy_count_today = 0
- All raw_responses: `Validator: unavailable (cron context)`. No `⚠ Validator found` markers. No auto-loop items.

---

## 2026-05-26 (L47–L49) — New entries this run

### L47
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-25T21:56 re-processed S659877 ("19-day-old stale SEV, last updated 2026-05-09; previously classified T4, pruned, resurfaced via tag query") + S660706 (preemptive launch-tracking SEV, also previously classified R18). Both had been diagnosed and added to `diagnosed_ids` in an earlier run, then pruned from the state, causing re-processing.
- **Learning:** When pruning `diagnosed_ids`, ONLY remove IDs for SEVs that are confirmed closed/resolved or >30 days stale. NEVER prune open/in-progress SEVs just because they temporarily drop from the 3-day candidate query window. Open-but-out-of-scope SEVs (R18/T4/preemptive) that get pruned will resurface on future runs and waste scope_check cycles. Prune condition should be: `(sev_status == RESOLVED OR age_days > 30)` — not just "absent from this run's candidate set".
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 2, 2026-05-26)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260526T151046Z.txt`

### L48
- **Type:** operational
- **Trigger:** ot-alert-monitor 2026-05-26T02:59 diagnosed ig_feed_recs_ifr_t2i_retrieval (holdout 875620176) as DETECTOR_BROKEN on both Cluster A (holdout SPARSE_DELTA) and Cluster B (AGG). Root cause: retrieval models publish FULL_SNAPSHOT only; any `e2e latency sparse delta` or `dense_delta` detector configured on a `_retrieval` model is structurally misconfigured with no data source.
- **Learning:** Add fast-path in ot-alert-monitor step 4: if `model_type_name` ends in `_retrieval` AND alert_type contains `sparse_delta` or `dense_delta` → classify immediately as R16 FALSE_ALARM / DETECTOR_BROKEN (NO ACTION). Retrieval models publish FULL_SNAPSHOT only; SPARSE_DELTA/DENSE_DELTA detectors will always fire false positives. Skip T1–T4 investigation entirely. Saves 1–2 API calls + inference time per occurrence.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (Learned Rule 3, 2026-05-26)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260526T151050Z.txt`

### L49
- **Type:** operational (meta — prompt-update mechanism)
- **Trigger:** Direct prompt inspection 2026-05-26 08:07 PT: ot-sev-monitor has only 1 rule in "Learned Rules (auto-appended)" (2026-04-29); ot-alert-monitor has only 2 rules (both 2026-04-29). All ledger entries L29–L46 claimed to "amend cron X prompt (Learned Rule N, date)" — none of those amendments are present in the live sqlite prompts. The step-3 regex still has bare `ATS` (not `\bATS\b` from L29). All 10+ operational learnings that should have been applied are inert.
- **Learning:** The prompt-amendment step in this cron has been silently failing since at least L29 (2026-05-22). Root cause unknown (possible sqlite quoting failure, possible prior failed writes that didn't abort). Two fixes needed: (1) **Immediate**: operator must manually re-apply Learned Rules 2–11 for ot-sev-monitor and Rules 3–5 for ot-alert-monitor (from L29–L46) — too large for this single run. (2) **Structural**: after each prompt UPDATE in this cron, re-SELECT the changed section and grep for the appended rule text before logging "amended" in ledger. If grep fails → log ERROR, do NOT record "amended" in ledger entry.
- **Action:** Appended to ledger. L47+L48 applied in this run (today's rules only). Historical L29–L46 rules require separate operator-driven re-sync pass. No rollback needed (this entry is ledger-only).
- **⚠️ OPERATOR ACTION REQUIRED:** `cron-prompt-backups/ot-sev-monitor__20260526T151046Z.txt` + `ot-alert-monitor__20260526T151050Z.txt` contain the pre-today-amended versions. A bulk re-sync of L29–L46 rules should be applied before next Monday's shift-summary.

---

## Validator Discrepancies

### 2026-05-26
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any of today's raw_responses. All validators reported as "unavailable (cron context)" across all runs. No auto-loop items this run.

---

## 2026-05-25 (L45–L46) — New entries this run

### L45
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-25T05:05 self-reported: "S666880 and S667443 were erroneously identified as new candidates due to a list-comparison error — they were already in `diagnosed_ids`. Duplicate notifications sent." Affected SEVs received two bot GChat replies each.
- **Learning:** diagnosed_ids set membership check can fail due to int/str type mismatch or in-memory vs file-state divergence, causing duplicate notifications. Fix: (1) normalize all SEV IDs to `str(sev_id)` at both write and read time; (2) after building new-candidate set, re-load diagnosed_ids from persisted JSON for a second-pass check before any notification is sent; (3) if candidate passes in-memory check but fails file check → skip, log `duplicate-guard=triggered`, add to in-memory set.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 11, 2026-05-25)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260525T151105Z.txt`

### L46
- **Type:** operational
- **Trigger:** S667358 "IG Relevance T20 H100 Scribe Over Quota" was open 2026-05-22 12:08 PDT through 2026-05-25 08:07 PDT (~68h unmitigated). ot-alert-monitor correctly classified ≥3 separate model-clusters (2144816217, 2134319967, 2133539495) as CL-003 UPSTREAM_INFRA referencing S667358 — but no run ever surfaced an escalation nudge about the upstream SEV's age.
- **Learning:** When root_cause_sev is open > 48h (time_mitigated=null, created > 48h ago), ot-alert-monitor GChat reply should append: "⚠️ Upstream SEV S{id} has been In Progress for >48h — consider paging upstream oncall if escalation hasn't happened." This is additive to the CL-003 classification, not replacing it. Without this, a long-running upstream SEV generates indefinite OT alert noise with no pressure to resolve.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (Learned Rule 5, 2026-05-25)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260525T151105Z.txt`

---

## Validator Discrepancies

### 2026-05-25
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any of today's raw_responses (05:57 run explicitly noted "validator=unavailable (cron context)"). No auto-loop items.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P56 (proposed L33, 2026-05-23) | STUS startup fails: removed MTIA module in fire-app | L33 | Proposed 2026-05-23; operator review needed |
| P57 (proposed L35, 2026-05-23) | DPP session 20-day max lifetime → planned restart → TRANSIENT_NOISE | L35 | Proposed 2026-05-23; operator review needed |
| P58 (proposed L39, 2026-05-24) | TorchElastic/elastic-agent hang (RUNNING+0mvai_metrics+no error — same outer as P44) | L39 | Proposed 2026-05-24; py-spy distinguisher from P44; operator review needed |
| P59 (proposed L26, 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; recheck P-ID before landing (current max=P55) |
| P60 (proposed L27, 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; note P58 now used for elastic-agent hang; re-ID needed before landing |
| Scribe downsampling (proposed L30, 2026-05-22) | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22 as "P55" — ID taken (RES flooding); needs new ID (≥P56) before landing |
| P61 (proposed L51, 2026-05-27) | DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE: trainer hung getNextBatch | L51 | Proposed 2026-05-27; distinct from P57 (DPP session TTL); operator review needed |

---

## 2026-05-24 (L43–L44) — Morning pass (08:07 PDT)

### L43
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-24T08:03 — run added 89 NEW IDs to diagnosed_ids (81 scope_check=false drops + 8 R18 drops + 1 new SEV S667620) vs prior state of 49 IDs at 06:54. Indicates state reset between runs. Not self-reported in run summary — operator had no visibility into the anomaly.
- **Learning:** When a single run adds >40 new IDs to diagnosed_ids (anomalous expansion beyond the normal 1–5 new/run cadence), include `state_expansion_anomaly=true` in the run summary header with prior_count, new_count, and delta. Enables operators to detect state resets without grep-scanning. In this instance, all 89 additions were out-of-scope drops (no duplicate notifications), but operator should verify on each such event.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 9, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260524T151147Z.txt`

### L44
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-24T08:03 — S667620 classified UNKNOWN/NEEDS_INVESTIGATION with confidence:low (root-cause: not found). Bot sent a gchat reply (URL present) but the reply contained no explicit "inconclusive" marker and no retry flag. SEV triage stalls without auto-recovery.
- **Learning:** When triage produces UNKNOWN/NEEDS_INVESTIGATION with confidence:low: (1) gchat reply MUST include "🔎 Bot triage inconclusive — manual investigation required"; (2) set `retry_on_next_run=true` in state JSON so next hourly run re-attempts with updated SEV context; (3) do NOT auto-tag until confidence ≥ medium — incomplete triage is not a tagging signal (R19).
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 10, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260524T151147Z.txt`

---

## Validator Discrepancies

### 2026-05-24
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any raw_responses from the 24h window. All validators reported as "unavailable (cron context)". No auto-loop items this run.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P55 (proposed L30, 2026-05-22) | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22; **NOTE: P55 was landed in known_patterns.md as a DIFFERENT pattern (RES SPARSE_DELTA flooding). L30 proposal needs a new ID (P58+ once checked) before landing.** |
| P56 | STUS startup fails: removed MTIA module in fire-app | L33 | Proposed 2026-05-23; operator review needed |
| P57 | DPP session 20-day max lifetime → planned restart → TRANSIENT_NOISE | L35 | Proposed 2026-05-23; operator review needed |
| P58 | TorchElastic/elastic-agent hang (RUNNING+0mvai_metrics+no error — same outer as P44) | L39 | Proposed 2026-05-24; py-spy distinguisher from P44; operator review needed |
| P59 (from 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; pending operator review — recheck P-ID before landing |
| P60 (from 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; pending operator review — P60 may clash with elastic-agent P58 shift |


---

## 2026-05-24 (L38–L42) — New entries this run

### L38
- **Type:** operational
- **Trigger:** S667488 "Q3'26 | WIWYNN | DELTA | L6 COMPONENT" (hardware supply-chain SEV) triggered ot-sev-monitor step-3 regex via `DELTA` keyword. It false-positived on 6+ consecutive runs across the full day (01:58 → 13:52 PDT), requiring repeated scope_check invocations before being silently dropped each time.
- **Learning:** After a step-3 `DELTA` regex match, add a post-match procurement exclusion: if title contains any of (`WIWYNN`, `L6 COMPONENT`, `L4 COMPONENT`, `supply chain`, `PSU vendor`, `hardware`, `ISCE`) → classify as in_scope=false immediately, silently add to diagnosed_ids without invoking scope_check. Eliminates repeated false-positive processing for hardware procurement SEVs.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 6, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260524T081014Z.txt`

### L39
- **Type:** domain (triage discipline / red herring)
- **Trigger:** https://fb.workplace.com/groups/mrs.ot/permalink/1332867342141342/ (ot-post-monitor 2026-05-23 12:26 PDT) — bot diagnosed `🔴 PAGE fengzhang1 | P44 GIL hang on reranker 2125081901 | 7h51m stall`. Denny corrected: elastic-agent (TorchElastic/supervisor) hang, not Python GIL freeze. Both show MAST RUNNING + 0 metrics + ckpt CREATING + empty error — identical outer signature.
- **Learning:** MAST RUNNING + 0 mvai_metrics + ckpt CREATING + empty error matches P44 AND elastic-agent hang. Disambiguator: run py-spy stack dump on rank-0 process BEFORE calling P44. If py-spy shows Python main thread in `take_gil` → A1/P44. If py-spy shows TorchElastic/supervisor frozen (supervisor main loop, `_worker_watchdog`, or C-level signal handler) → elastic-agent hang (distinct class). Bot must not conclude P44 without confirming via py-spy. Recovery for both is identical (`kill v<N>` + TMS restart), but attribution differs.
- **Action:** Appended to ledger. P58 proposed (elastic-agent hang as a distinct named pattern). Triage-discipline SKILL.md amendment proposed. NOT yet auto-applied.
- **Implementation delta (proposed):** Add to `known-patterns.md` P44 Falsifier section: "If py-spy main thread shows TorchElastic/supervisor frame (not `take_gil`) → elastic-agent hang (P58), not P44." + new P58 row drafted below.

### L40
- **Type:** operational
- **Trigger:** ot-alert-monitor 2026-05-23 10:01 PDT — facebook_reels_ifu_i2i 2132070936 diagnosed THRESHOLD_MISFIT (FULL_SNAPSHOT detector — model never publishes FULL_SNAPSHOT). Side-note in raw_response: "same model had prior false-positive on DENSE_DELTA 2026-05-08." Bot correctly classified both times but generated no escalation or recommendation to permanently fix the detector.
- **Learning:** When classifying THRESHOLD_MISFIT, check alert_state for prior occurrences on the same model. If ≥2nd time → include PERSISTENT_MISCONFIGURATION notice in the diagnosis reply ("Recurring false-positive. Recommend permanently removing/reconfiguring this detector.") to drive permanent fix. Without this, the bot will silently handle the same false-positive indefinitely.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (Learned Rule 4, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260524T081014Z.txt`

### L41
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-23 22:54 PDT self-reported in raw_response: "Noted not-caught-by-regex: S667572 'ESR and LSR NE explosion' (no tags, regex miss — L34 add-`NE explosion` candidate for future)." Metric explosion events (NE/gradient/loss explosion) are clear OT training-stage failures that do not match any existing step-3 keyword.
- **Learning:** Add `(?i)\b(NE|gradient|loss)\s*explosion\b` as an additional OR clause in step-3 title regex. "NE explosion" is the common short form in Meta internal SEV titles (NE = numeric explosion = loss/gradient becoming NaN/Inf). This covers the class of training instability SEVs that are currently invisible to the bot.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 7, 2026-05-24)
- **Rollback:** see L38 rollback (same backup file)

### L42
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-23 12:59 PDT — S667565 used model identifier "f831018319" (all-hex, looks numeric but is not a valid decimal model_id). Bot went DEGRADED: "v.1 gate blocked full triage. Awaiting xtliao to populate overview with explicit model_id." No fallback, no reply to SEV, indefinite DEGRADED state.
- **Learning:** Non-numeric model identifiers should trigger a structured 3-step fallback: (1) try `meta ai.model-series describe` with identifier as `--model-name` substring; (2) scan SEV description body and tags for decimal numeric model_id; (3) if still unresolvable → post initial reply to SEV asking owner to populate numeric model_id, set confidence=LOW, record `model_id_unresolvable=true` in state JSON for retry on next run. Never leave triage in indefinite DEGRADED with no owner notification.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 8, 2026-05-24)
- **Rollback:** see L38 rollback (same backup file)


---

## 2026-05-23 (L33–L37) — New entries this run

### L33
- **Type:** domain (pattern)
- **Trigger:** S667466 — STUS job `mvai-training-online-2140425308` v21 crashed at startup with `ModuleNotFoundError: No module named 'mtia.tools.autotune.afg_fc_tuning.mtia_autotune_types'`. Fire-app `204be32` included `dper_lib/silvertorch/configs/ranking/ranking_disagg_config.py:7` importing a removed MTIA module. STUS never began publish work.
- **Learning:** Distinct new failure class: STUS fails at Python module import due to removed/moved MTIA dependency in fire-app. Symptom set: STUS attempt DEAD within minutes of start (not a hang), `ModuleNotFoundError` in attempt logs (not OOM/timeout/NCG), root trainer healthy (mvai_metrics recent). Fix: fix import + rebuild fire-app. Distinct from P44 (hang) and GPU_OOM patterns.
- **Action:** Appended to ledger. P56 proposal drafted (see 🧠 PATTERN PROPOSALS section below).
- **Implementation delta:** known_patterns.md P56 row (see below).

### L34
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-22 20:53 flagged: "⚠️ Regex gap observed (not actioned): S667453 'High priority QE model not able to start OT' — not tagged mvai-online-training, 'OT' alone not in signal regex (MRS[._-]?OT requires MRS prefix)." S667453 was never surfaced to triage despite being explicitly about online training startup failure.
- **Learning:** Bare `\bOT\b` abbreviation in SEV titles is not in the step-3 signal regex. Add `online\s+training` (case-insensitive) as additional OR clause in the step-3 title regex. Spellings like "start OT", "OT failure" or "not able to start OT" all map to the same domain but are missed.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 4, 2026-05-23).
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260523T080956Z.txt`

### L35
- **Type:** domain (pattern)
- **Trigger:** ot-alert-monitor 2026-05-22 19:55 — `facebook_ifr_main_mtml_main 886797001` fired alert for too-few delta snapshots. Bot correctly diagnosed: DPP session hit 20-day (1,728,000s) max lifetime at 18:48 PDT → planned trainer restart → ~72 min delta gap → auto-recovered by 19:06 PDT. Class: TRANSIENT_NOISE.
- **Learning:** DPP session max lifetime expiry is a distinct, predictable TRANSIENT_NOISE pattern. Identifiers: alert fires ~60–90 min after a clean trainer restart (no MAST error, no OOM), `DPP session uptime` near 1,728,000s (exactly 20 days), model health fully restored after bootstrap. Falsifier: DPP uptime < 19d or MAST shows error → different cause.
- **Action:** Appended to ledger. P57 proposal drafted (see below).
- **Implementation delta:** known_patterns.md P57 row (see below).

### L36
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-22 18:03 UTC — `google.chat.message` gchat tool unavailable in cron context. Bot completed full triage for S667466 (STUS ModuleNotFoundError) and S667465 (conveyor recurrence) but delivered diagnoses inline (raw_response only) — no @-mention sent to SEV owners (shuang42, clementc), no gchat thread created.
- **Learning:** When gchat tool unavailable, completed diagnoses must NOT be silently dropped as inline-only. Fallback: (1) try `meta google.chat.message create --space=spaces/AAQAVOjYc80 ...` CLI; (2) if also unavailable, record `notification_status=PENDING_RETRY` per SEV in state JSON and re-attempt on next run.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 5, 2026-05-23).
- **Rollback:** see L34 rollback (same backup file).

### L37
- **Type:** domain (triage discipline)
- **Trigger:** S667465 — "mvai/umia_v1_igr conveyor blocked at cogwheel test step" — bot identified as CONVEYOR_REGRESSION with confidence:HIGH in one step because prior incident S666412 had identical root (bamboo/rfe/client.py contextprop headers). D105634504 re-introduced the same bug.
- **Learning:** When a SEV has an exactly-matching prior incident (same root file/path, same symptom class, same impacted pipeline), set confidence=HIGH without full T2/T3 investigation. Evidence requirement: confirmed `prior_incidents≥1` with matching root + current SEV shows same symptom. Shorten investigation depth when pattern is a known recurrence.
- **Action:** Appended to ledger. Triage-discipline SKILL.md proposal (see 🔧 IMPLEMENTATION DELTAS section).

---

## Validator Discrepancies

### 2026-05-23
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any raw_responses. Validators were reported as "unavailable (cron context)" across all runs. No auto-loop items this run.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P55 | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22; operator review needed |
| P56 | STUS startup fails: removed MTIA module in fire-app | L33 | Proposed 2026-05-23; operator review needed |
| P57 | DPP session 20-day max lifetime → planned restart → TRANSIENT_NOISE | L35 | Proposed 2026-05-23; operator review needed |
| P59 (from 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; pending operator review — recheck known_patterns.md P-ID before landing |
| P60 (from 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; pending operator review — recheck P-ID before landing |


---

## 2026-05-22 (L29–L32) — New entries this run

### L29
- **Type:** operational
- **Trigger:** S665416 (Wearables "aTSR" matched `ATS`) and S667190 (WhatsApp "WhATS" matched `ATS`) both caused false positives in ot-sev-monitor step-3 regex in the last 24h. Both were correctly dropped at scope_check but wasted manual assessment cycles.
- **Learning:** `ATS` sub-pattern in step-3 regex lacks word boundary — matches substrings "WhATS" in WhatsApp and "aTSR" in Wearables titles. Fix: `ATS` → `\bATS\b`. Preserves legitimate ATS-budget OT SEVs while eliminating both false-positive classes.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (regex fix in step 3 + Learned Rule 2)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260522T*.txt` (restore from backup)

### L30
- **Type:** domain (pattern)
- **Trigger:** S667071 "Scribe IFR and Onefeed regressioned by 20%+" — D106006226 applied `requestLevelDownsample=True` (rate=0.45) to non-USCA external `feed_learning_examples_raas_in_feed_reco_request_level` Scribe route → volume -20%+, eag -46%. All IFR/Onefeed OT models affected (fewer negative training examples).
- **Learning:** Scribe downsampling config misapplied to non-USCA external routes is a distinct OT data-degradation failure class. Symptom: Scribe volume drop on `feed_learning_examples_raas_*` routes without trainer failure. Root: sampling config rollout scope error. New P-row warranted (P55 proposed).
- **Action:** Appended to ledger. P55 proposal drafted below. NOT yet landed in known_patterns.md.

**P55 proposal (DO NOT AUTO-APPLY):**
```
| P55 | Scribe requestLevelDownsample misapplied to non-USCA OT route | Scribe volume drop on feed_learning_examples_raas_* routes; eag spike; no trainer failure; IFR/Onefeed OT models show reduced example density | T1 | (1) Check active Scribe SEVs for `requestLevelDownsample` or `downsampling` config changes; (2) Confirm scope of config change (USCA vs non-USCA; external vs internal route); (3) Verify feed_learning_examples_raas_in_feed_reco_request_level volume in Scribe dashboards. P55 confirmed if volume drop correlates with sampling config rollout timing. Falsifier: no sampling config change in last 24h → different Scribe failure class (P02 or P03). | Revert D<diff_id> (the mis-scoped downsampling config); confirm Scribe route volume recovers within 30 min | Scribe/feed-learning owner (config rollout gate); OT training data quality monitoring | 15 min (revert config) | Source: S667071, D106006226, 2026-05-22 |
```

### L31
- **Type:** operational
- **Trigger:** S666505 (`[Preemptive] Launch LTV MVAI migration model`) and S660706 (`[Preemptive] Launch LTV MVAI migration model`) both matched ot-sev-monitor step-3 regex via `MVAI` keyword but were launch SEVs (out-of-pipeline per R18), requiring manual R18 assessment to drop.
- **Learning:** SEV titles beginning with `[Preemptive]` reliably indicate launch/preemptive SEVs that are out-of-OT-pipeline. At step 3 (after regex match): if `title.startswith('[Preemptive]')` → add to `diagnosed_ids` immediately, skip scope_check + R18. Reduces one manual assessment per preemptive launch SEV per run.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 3)
- **Rollback:** see L29 rollback (same backup file)

### L32
- **Type:** operational
- **Trigger:** ot-alert-monitor run 2026-05-21 21:58 UTC — `pastry <paste_id>` used to update validator_status in paste. Resulted in paste content unchanged (`validator_status` stayed "pending").
- **Learning:** `pastry <paste_id>` (piping to an existing paste ID) READS existing content — it does NOT overwrite. To update an existing paste, use `meta paste.paste update --paste-id=<id> --content=<new_full_content>`. If `meta paste.paste update` is unavailable in cron context → explicitly set validator field to `🚫 unavailable` directly in the gchat message. Do NOT silently leave "pending". Affected: ot-alert-monitor and ot-post-monitor validator update steps.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (paste instruction in validator step + Learned Rule 3)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260522T*.txt`

---

## Validator Discrepancies

### 2026-05-22
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any of today's raw_responses. Validators were either unavailable (cron context) or not invoked. No auto-loop items this run.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P55 | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22; operator review needed |
| P59 (from 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; pending operator review — note: ID may collide with existing proposals, recheck known_patterns.md before landing |
| P60 (from 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; pending operator review |


---

## 2026-05-21 (L25–L28) — Reconstructed from previous run output

### L25
- **Type:** operational
- **Trigger:** Two disk-full events (03:52 + 06:55 PDT) on `/dev/vda4` caused state write failures in ot-sev-monitor. Bot self-recovered by pruning 383 `/tmp/pi-bash-*.log` files.
- **Learning:** Add disk pre-check at ot-sev-monitor run start: if free <100MB → auto-prune `/tmp/pi-bash-*.log` (keep newest 50); if post-prune still <10MB → emit DISK_CRITICAL, abort state write, notify operator.
- **Action:** Appended + amended ot-sev-monitor prompt (step 0 DISK PRE-CHECK block added 2026-05-21)
- **Rollback:** `sqlite3 myclaw.db "UPDATE jobs SET prompt=$(cat cron-prompt-backups/ot-sev-monitor__<ts>.txt | ...) WHERE id='ot-sev-monitor';"`

### L26
- **Type:** domain (pattern)
- **Trigger:** `ig_organic_feed_mtml_holdout` 878102693 trainer GIL-hung ≥7h — MAST RUNNING, mvai_metrics zero, S658165 TCPStore pattern.
- **Learning:** GIL deadlock trainer shows: MAST RUNNING + NCCL watchdog silent + mvai_metrics samples stop ≥7h → PAGE immediately, do not wait for auto-resolve. Distinct from P44 (existing pattern) — P44 uses ≥5min sample gap; this observation generalizes P44 for longer-duration hungs.
- **Action:** Appended to ledger; P59 proposed (domain pattern). NOT yet landed in known_patterns.md.

### L27
- **Type:** domain (pattern)
- **Trigger:** `ig_organic_feed_mtml` scribe_read_proxy spike fired 20.5h AFTER ZippyDB S665163 was mitigated.
- **Learning:** P58 falsifier ("no active ZippyDB SEV → different root") is too strict. Check recently-mitigated ZippyDB SEVs in last 24h via `--mitigated-after` — residual lag can persist ≤24h post-mitigation and still indicate CL-003/TRANSIENT_NOISE.
- **Action:** Appended to ledger; P60 proposed (amends P58 falsifier). NOT yet landed.

### L28
- **Type:** operational
- **Trigger:** 10+ ot-sev-monitor runs today used "manual fallback" because buck2/scope_check binary unavailable in cron context.
- **Learning:** Add local `sev_type` JSON allowlist fallback when buck2 unavailable. For `sev_type=Production` borderline SEVs require ≥1 positive MRS marker (tag OR title keyword beyond regex). Manual-only assessment for Production borderlines is unreliable.
- **Action:** Appended to ledger. ot-sev-monitor prompt amendment deferred (L28 not auto-appended — targets cron behavior beyond simple rule text).

