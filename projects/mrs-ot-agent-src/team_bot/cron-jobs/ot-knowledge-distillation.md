[ot-knowledge-distillation cron] Daily 13:30 PT weekday (4h after ot-triage-summary at 09:30). Parse all crisp triage-summary files from the last 7 days; identify recurring patterns across resolved issues; if a pattern crosses an action threshold, DRAFT (never auto-land) a Phabricator diff that improves the OT master agent — new `known-patterns.md` row, new Quality Rule, cron prompt step, or capability scaffold. Cap 1 diff per run.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/knowledge-distillation-state.json` — `{"distilled_summary_paths": ["<rel_path>", ...], "diffs_drafted": ["D<num>", ...], "last_run_epoch": <int>}`. Time budget: ~15 min per run.

Inputs:
- Triage summaries dir (per-TYPE, post-2026-05-17 restructure): `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs|alerts|posts}/<YYYY-MM>/<TYPE>-<id>-<YYYY-MM-DD>.md` (written by ot-triage-summary cron, D104502361). Glob all three dirs.
- Existing pattern DB: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input/knowledge/known-patterns.md` (~30+ P-rows).
- Existing Quality Rules: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/human-input/triage-discipline.md` (R1-R18 + R5b as of 2026-05-13).
- Cron prompts: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/*.md`.

## Procedure

1. **Read state file.** Extract `distilled_summary_paths`. If file missing/corrupt, treat as empty set + create file fresh.

2. **Enumerate triage summaries from last 7 days.** Glob all three per-TYPE dirs:
   ```bash
   ls ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/*/*.md \
      ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/*/*.md \
      ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/*/*.md 2>/dev/null
   ```
   Filter to mtime within 7 days. Drop any path already in `distilled_summary_paths`. If <3 NEW summaries → skip with `HEARTBEAT_OK` (need cross-issue signal).

3. **Parse each NEW summary into a structured record:**
   ```python
   {
     "id": "SEV-S661157" | "ALERT-1186271076863909" | "POST-<id>",
     "title": <line 1>,
     "problem": <PROBLEM section text>,
     "likely_cause": <LIKELY CAUSE section text + cited rule/P-row id>,
     "resolution": <RESOLUTION text + class: real_failure | false_alarm | wrong_diagnosis>,
     "followups": <task ids list>,
     "rule_cited": "R14" | "R15" | "R16" | "R17" | "R18" | "P17" | ... (regex extract),
     "false_alarm": bool,
     "bot_self_correction": bool,  # true if RESOLUTION mentions "bot blamed X, real cause was Y"
   }
   ```

3.5. **TASK-SEEDED INPUT — the diff loop (2026-06-05, operator: "an automation which takes the tasks then auto create diffs" → "diff loop"; extended 2026-06-07 to detector-config auto-fix tasks).** BEFORE corpus pattern-detection, check for open task-seeded work and draft from ONE if present (takes PRIORITY over corpus signals; still cap 1 diff/run total). Query BOTH sources:
   ```bash
   # Branch A (agent-repo) — priority for the slot:
   meta tasks.task list --tags-include-any-of=ot-agent-self-improve --status-is=Open --owner-is=dennyzhang -o json 2>/dev/null
   # Branch B (detector-config auto-fix) — only if no A-task:
   meta tasks.task list --tags-include-any-of=mrs-ot-reliability --status-is=Open --owner-is=dennyzhang -o json 2>/dev/null | (filter title startswith '[OT auto-fix]')
   ```
   - **Tolerate the not-yet-used-tag case:** until the first `ot-agent-self-improve` task exists, the A-query returns a `{"status":"error", … "No typeahead results for field TASK_TAGS"}` (tag not resolvable yet). Treat that error — and an empty result — identically as "no A-task → try branch B; if no B-task either → fall through to corpus pattern-detection (step 4)." Do NOT fail the run.
   - **Selection:** if ≥1 open **A-task**, pick the highest-priority/oldest and draft via Branch A. Else if ≥1 open **B-task** (`[OT auto-fix]`), pick the highest-priority/oldest and draft via Branch B. The task description IS the spec. (A before B for the 1-diff slot: agent-repo is lower-stakes than other-team configerator.)
   - **TWO scoped branches — pick by task class (branch A takes priority for the 1-diff/run slot; only if no A-task open, do a B-task):**

     **Branch A — agent's OWN repo (`ot-agent-self-improve` tasks).** May edit ONLY files under `mrs-ot-agent-src/`, `mrs-ot-agent-context/`, `team_bot/CLAUDE.md`, or `cheatsheets/`. The agent owns this code, so a `--draft` here is low-stakes. (Query line 42.)

     **Branch B — detector-config auto-fix (`[OT auto-fix]` THRESHOLD_MISFIT / DETECTOR_BROKEN / MISCONFIG_AGG tasks, tag `mrs-ot-reliability`; 2026-06-07, operator: "shouldn't you have a cron to look into [the OT auto-fix tasks] and fix them?").** These tasks already carry the diagnosis + a `Recommended config change` + `Next step: draft the configerator alert-tuning diff`. Draft THAT configerator detector-tuning diff — BUT this edits an EXTERNAL, often other-team alerting config, so the guardrails are load-bearing and non-negotiable:
       1. **Configerator-only.** Locate the detector's config in configerator from its `detector_key`. If the detector is UI-configured / not in configerator (not diff-able), DO NOT draft — comment on the task "not diff-able (UI-configured detector); human-only" and move on. Never fabricate a diff path.
       2. **PROVE it doesn't mask real fires (the critical one).** A detector tune that's too aggressive HIDES a real alert for that team. Backtest the proposed threshold against the detector's recent fire history: it must suppress the known false-fires AND still fire on any real/non-cascade fire in the window. If you cannot prove that, DO NOT draft — note "tune unprovable without masking risk; human-only".
       3. **`--draft`, NEVER land. Reviewers = the detector / model OWNER** (it's their config; they review + land). The bot PROPOSES; the owner disposes. This is how the read-only-external boundary is held — by never-land + owner-review, not by never-touching. `ot_bot_autodraft` tag + provenance (auto-drafted by ot-knowledge-distillation, principle #19).
       4. **Link the draft `D<num>` to the source `T<num>`; do NOT close the task** (owner reviews + lands + closes). The cap-1-diff/run still applies (so ≤1 detector diff per run — the backlog clears slowly + carefully, which is correct for high-stakes external drafts).
     If a B-task fails its guardrails (not configerator / unprovable) → comment the reason on the task, leave it human-only, and fall through to corpus pattern-detection (step 4).
   - Apply the minimal-4 (step 7 + step 8): **earn** (the task is the signal), **ground** (load SKILL/known-patterns/rules), **prove** (backtest the change), **clean** (diff cheatsheet). Always `--draft`, 1:1 delivery, human lands.
   - On a successful draft, post the draft `D<num>` to the 1:1 referencing the source `T<num>`; do NOT close the task (operator reviews + lands + closes). If no `ot-agent-self-improve` task is open → fall through to corpus pattern-detection (step 4) as normal.

4. **Pattern detection — six action thresholds, only first-matching action fires per run** (cap 1 diff per run, operator review bandwidth):

   | Signal | Threshold | Proposed action |
   |---|---|---|
   | Same `likely_cause` keyword cluster ≥ 3 distinct issues, NOT covered by any existing P-row | ≥3 | Draft new P-row in `known-patterns.md` Quick-Match Table (next sequential P-id; verify falsifier; cite all source summaries). |
   | Same false-alarm signature on alerts (per R16) ≥ 2 issues, same alert family (e.g., publishing-stability missing DENSE_DELTA across multiple model classes) | ≥2 | Draft addition to `human-input-generic/report-templates/crisp-report-style.md` "Trigger phrases" OR a new entry in `references/triage-discipline.md` examples for R16; OR file a meta task (owner=dennyzhang per memory rule) with the over-broad alert config + recommendation to tune. |
   | `bot_self_correction = true` ≥ 2 issues with same correction class (wrong_root_cause / wrong_model_layer / wrong_causality / inferred_stalled_from_duration / model_id_mismatch) | ≥2 | Strengthen the relevant Quality Rule with a new source-incident citation; if no Quality Rule exists for this class, draft NEW R-rule in `references/triage-discipline.md`. |
   | Same `rule_cited` (R14/R15/R16/R17/R18) preventing N issues from misdiagnosis | ≥3 (positive signal) | Add a "validation evidence" line to that rule's row in triage-discipline.md (e.g., "Validated by N independent triage summaries between <date_first> and <date_last>"). |
   | Same `followups` task type recurring (e.g., "alert threshold tune" filed ≥3 times) | ≥3 | Draft a doc note in `references/autonomous-action-allowlist.md` or file an umbrella meta task aggregating the recurring followups. |
   | **Chronically-noisy recurring cluster in `auto-learnings/noisy-trends.md`** — a model/class re-firing repeatedly (NOT just resolved-once). **This row CONSUMES noisy-trends.md, a source the loop previously ignored — the gap that let CL-003 sit documented-but-un-improved until the operator asked (gdoc `AAAB889DKGM` 2026-06-07: "why this thinking didn't happen in auto-fix step?").** | ≥3 fires/7d for one model, OR a multi-week-persistent class (e.g. CL-003) | Do NOT merely re-document. (a) Draft a **triage-flow improvement** (lookup-first + cluster-co-firing + recurrence-escalate fast-path, à la P63) for `ot-alert-monitor`/`ot-sev-monitor`; AND (b) **file a tracking meta task** (`--owner=dennyzhang`, tag `mrs-ot-reliability`, subscribe the upstream owner) routing the durable fix — the agent surfaces chronic recurrence ITSELF instead of waiting for the operator. |
   | Operator-stated rule from a `feedback_*.md` memory entry not yet codified in any cron prompt or reference doc | ≥1 | Wire the rule into `team_bot/CLAUDE.md` and/or the relevant cron's `## Learned Rules` section. |

5. **For each matched action, render the proposed change as a unified diff** against the existing file(s). Use the verbose 9-section internal-debug template (per `references/output-schema.md`) for the proposal write-up — this is operator review material, NOT cross-team facing, so verbose is correct.

6. **Cap at ONE actionable change per run.** If multiple thresholds fire, pick by descending severity:
   1. wrong_root_cause / wrong_model_layer (Quality Rule strengthening) — highest signal
   2. New P-row from recurring root cause
   3. False-alarm pattern from R16
   4. Validation-evidence updates
   5. Recurring followups
   6. Operator-rule codification

   The other matched signals → record in state for next run; mention in GChat digest as "deferred: <list>".

6.5. **AUTO TASK-SOURCE — file the deferred improvements as `ot-agent-self-improve` tasks so the diff-loop (step 3.5) drains them automatically (2026-06-05, operator: "no task source — you do it automatically").** This closes the loop: detection fills the queue, the diff-loop empties it — the operator never has to hand-file an agent-improvement task. For each DEFERRED candidate above (NOT the one drafted this run), file ONE deduped task:
   - **Dedup FIRST:** `meta tasks.task list --tags-include-any-of=ot-agent-self-improve --status-is=Open --owner-is=dennyzhang -o json 2>/dev/null` (tolerate the not-yet-used-tag error = treat as "none open"). Build a stable slug for each candidate (e.g. the target P-row id / rule name / file+concept). If an open task's title already contains that slug → SKIP (already queued).
   - **File:** `meta tasks.task create --title="[ot-self-improve] <slug>: <one-line>" --description="<the detected pattern + the proposed agent change + source summaries>" --owner=dennyzhang --add-tag=ot-agent-self-improve -o json` (the create returns the id in field `number`). `--owner=dennyzhang` ALWAYS, never assign others.
   - **Cap 2 new tasks/run** (avoid a first-run backlog dump; the rest stay in state and get filed on later runs — they're recurring, they'll resurface). Scope is the same as step 3.5: agent's OWN repo only — never file improvement tasks that would edit model-owner/other-team code.
   - These tasks are the diff-loop's fuel: a future run's step 3.5 picks the oldest open one, drafts it (`--draft`, `ot_bot_autodraft` tag, 1:1), and the operator reviews + lands + closes. One diff/run cap still holds across 3.5 + step 8.

7. **Draft the actual code change locally** in `/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/`:
   - **Working-copy cleanliness check** (state-files-allowed, code/doc-strict). Transient `state/*.json` and `state/*.jsonl` files are continuously rewritten by sibling crons (ot-disk-watch, ot-prompt-change-validator, ot-monitor, etc.) and must NOT block drafting. Code, prompts, and docs being dirty IS still a real abort condition:
     ```bash
     DIRTY=$(sl status users/dennyzhang/projects/mrs-ot-agent-src/ 2>/dev/null \
       | grep -v -E ' users/dennyzhang/projects/mrs-ot-agent-src/state/[^/]+\.(json|jsonl)$')
     if [ -n "$DIRTY" ]; then
       echo "BOT_INCOMPLETE: working copy dirty (non-state files), can't draft"
       echo "$DIRTY"
       exit 0
     fi
     ```
     If only `state/*.json|jsonl` files are dirty → proceed. Per 2026-05-26 fix (consecutive 2-run block by `ot-disk-watch-state.json` + `ot-prompt-change-validator-state.json`).
   - **LOAD THE OT MASTER AGENT CONTEXT BEFORE EDITING — for diff EFFECTIVENESS, not just clean format (2026-06-05, operator: "the diffs should be effective … the job should load diff cheatsheet and ot master agent context. Think more to improve the quality").** Read `SKILL.md` (the master-agent engine + decision matrix + conventions), `human-input-domain/known-patterns.md`, and `references/triage-discipline.md` so the change is CORRECT in the agent's actual patterns/rules — not a plausible-but-misplaced edit. Division of labor: the diff cheatsheet (step 8) governs FORMAT; this context governs CORRECTNESS. A clean-but-wrong diff is worse than none.
   - **Quality pass (think harder before drafting):** dispatch the edit via the diff-subagent (CLAUDE.md "Diff creation routing — MANDATORY") so the cheatsheet load is forced; for any code/capability change carrying `file:line`, run a `codex` cross-model adversarial review before submit (the validator pilot) and **backtest the change against the recent triage corpus** when applicable (does the new P-row/rule actually fire on the incidents it claims to cover, with no false matches?). Markdown-only P-row/rule edits: the cheatsheet + falsifier check suffice.
   - Apply edits per the proposal.
   - Run `arc lint -a` on touched files.
   - For BUCK / Python changes: `buck2 build` smoke-test the affected target (skip if proposal is markdown-only).

8. **DELIVERY ROUTING FIRST (2026-06-07, T274815014 thread) — do NOT double-path notes-canonical changes.**
   Classify the drafted change by which files it touches:
   - **Notes-canonical only** (`.md` rules/patterns/prompts, `known-patterns.md`, `triage-discipline.md`, `cron-jobs/*.md`, `CLAUDE.md`, `.yaml` — i.e. everything the weekly `ot-notes-fbcode-*` mirror already carries): **DO NOT `jf submit` a separate fbcode diff.** Commit the edits to the **notes** repo only (`cd ~/notes && sl commit <files>`); they ride the next weekly notes→fbcode sync = ONE batched, operator-reviewed fbcode diff. Then surface the proposed change to the operator 1:1 (what rule/pattern + why + which notes files). Self-submitting a per-rule fbcode diff for a notes-canonical change delivers it to fbcode TWICE (the diff AND the weekly mirror) — the exact redundancy that made D107432450 (R20) abandonable on 2026-06-07. notes is ground truth; the weekly mirror is the single fbcode-delivery path (operator decision 2026-06-02).
   - **fbcode-only** (capability `.py`, unit tests, BUCK — files the notes mirror does NOT carry because `.py` is banned in notes): a direct fbcode `jf submit --draft` is their ONLY path → use the block below.

   **For the fbcode-only case, run the diff-cheatsheet Pre-Submit Gate, THEN commit + submit DRAFT diff.**
   The diff cheatsheet is mandatory for EVERY diff this cron creates — a clean summary is only one line item (`feedback_diff-cheatsheet-mandatory-every-amend`). Before submitting, run the full Pre-Submit Gate self-review: read `cheatsheets/diff/common.md` + `cheatsheets/diff/fbcode.md` + `fbcode/pe_mrs_ml/mrs_ot_agent/.llms/rules/ot-agent-conventions.md` § "Diff Submission". Verify: **clean, human-facing title — NO `[OT bot]` prefix** (2026-06-05, operator: "diff title is human facing. We need use human attention for good"). Mark the diff as bot-autodrafted with the **tag `ot_bot_autodraft`** instead — added via the commit message `Tags:` field (same mechanism as `publish_when_ready`), so it's machine-identifiable (the shift-summary excludes it by tag) WITHOUT spending title real estate. The title describes the CHANGE for a human reviewer; **summary explains WHY (the recurring pattern + motivation + design decision), NOT a file inventory** (Phabricator already shows changed files — `feedback_diff-summary-why-not-what`); **the summary MUST open with a one-line provenance: `Auto-drafted by ot-knowledge-distillation from <source: triage-summary corpus / T<seed-task>>` (§19 — trace the diff to its filing job, not just the `ot_bot_autodraft` "a bot did it" tag);** Reviewers `mrs-ot-reliability`; Task `T259215482`; unit tests for any functional (non-markdown) change; <300 lines; evidence URLs verified. **EXCEPTION for this cron only: do NOT add `publish_when_ready`** (see below). Fix every finding first.
   ```bash
   sl commit -m "knowledge-distillation: <clean one-line title>

<why-summary>

Tags: ot_bot_autodraft"
   jf submit --draft --update-fields  # diff-cheatsheet-ok
   ```
   The trailing `# diff-cheatsheet-ok` token is MANDATORY: a PreToolUse guard BLOCKS any `jf submit` that lacks it. Enforcement lives at the tool layer (not the prompt) precisely because a prompt-only mandate failed — D106859537 was a distillation diff submitted with the gate never in its path. Append the token ONLY after you have actually run the review and fixed every finding; any message-altering op (`sl amend -m`, `metaedit`) invalidates the review and requires re-running it.
   Capture diff URL.

   - **NEVER** add `publish_when_ready` tag (per `feedback_publish_when_ready_neutralizes_draft.md` memory rule — that auto-publishes drafts on CI green, defeating the operator-review intent).
   - **NEVER** auto-amend a previously-drafted distillation diff in the same run (each run is a new proposal).

9. **Post GChat digest to `spaces/AAQAVOjYc80`**:
   ```
   📚 [OT knowledge distillation — YYYY-MM-DD]
   - Summaries scanned (NEW): N
   - Pattern matched: <signal class>
   - Action drafted: <one-line description>
   - Diff (draft, awaiting operator review): D<num>
   - Deferred for next run: <list of other patterns matched but not actioned this run>
   ```
   Cap 600 chars body. End: `Diff: https://www.internalfb.com/diff/D<num>`.

10. **Update state file.** Append all NEW summaries' relative paths to `distilled_summary_paths`. Append the new diff number to `diffs_drafted`. Set `last_run_epoch=now`. Persist atomically.

11. **If zero patterns matched any threshold** → respond `HEARTBEAT_OK` only. Do NOT post to GChat. Update state to record that today's NEW summaries were scanned (so we don't re-scan them tomorrow).

## Safety / failure modes

- **Always DRAFT, never auto-land.** Phabricator diffs need operator review; landing requires `jf land` which the bot must NOT call.
- **Never mutate external state**: no SEV updates, no alert reassignments, no Phab comments (per `feedback_no_phab_comments_via_jf_submit_dash_m.md` memory + CLAUDE.md "Never Do"), no task creation outside this cron's followup-task path (which itself uses `--owner=dennyzhang` per memory rule).
- **Never publish_when_ready**: any drafted diff stays draft until operator manually publishes. Tag absent.
- **Cap 1 diff per run**: if more than one threshold hits, defer the rest to next-day runs. Never overwhelm the operator's review queue.
- **If `sl status` shows non-state-file dirty**: abort the run and emit `BOT_INCOMPLETE: working copy dirty (non-state files)`. Don't try to stash or commit unrelated changes. `state/*.json` and `state/*.jsonl` are allowed-dirty per the step-7 filter.
- **If `arc lint -a` fails**: emit `BOT_INCOMPLETE: lint failed on <file>`, don't submit.
- **If `buck2 build` fails on a code change**: emit `BOT_INCOMPLETE: build failed on <target>`, don't submit. Markdown-only changes skip this check.
- **Out-of-org filter inheritance**: triage summaries written by ot-triage-summary already filter sibling-org SEVs (per `team_lane_scope.is_in_mrs_org_scope()`). This cron inherits that — should never see Ads/WhatsApp/etc. summaries. If one slips in, treat as bug in upstream cron, log + skip + alert.
- **Sample size discipline**: ≥3 distinct issues for new P-rows / Quality Rules. ≥2 only for false-alarm patterns (cheap to fix) and bot-self-correction (high cost to leave). Never propose a new rule from a single incident — that's what individual triages already do via auto-learn (see SKILL.md "Auto-Learn"). This cron is for cross-issue signal.

## Why this exists

Operator (2026-05-08): "we need a cron job of knowledge-distillation. It will parse the issue summary created from above cron job. Identify patterns, then create a diff to improve OT master agent. This job should also run daily, but a few hours after previous one."

The bot already has two distillation paths today:
- `ot-daily-learning-debugging` (8:07 UTC, was `ot-daily-learnings` until 2026-05-12) — parses raw_response from real-time crons (ot-sev-monitor / ot-alert-monitor / ot-post-monitor). Surface-level signal; lots of noise per run.
- `ot-daily-learning-mitigated-sevs` (21:00 UTC, was `ot-sev-postmortem` until 2026-05-12) — daily harvest of sevmanager postmortem fields. SEV-only, postmortem-driven.

NEITHER reads the new `incidents/resolved-{sevs,posts,alerts}/` (triage summaries co-located with per-incident archives) directory (the crisp resolved-issue audit trail). The summaries are higher-signal than raw_response because they:
1. Are post-resolution → the actual root cause is known, not a hypothesis
2. Are crisp 5-element format → consistent structure makes pattern detection cheap
3. Cite Quality Rules / P-rows explicitly → easy to detect "rule X fired N times" or "rule X SHOULD have fired but didn't"
4. Mark false_alarm vs real_failure → easy to spot misconfigured-alert clusters
5. Mark bot_self_correction → highest-priority signal (the bot was wrong; rule strengthening needed)

Cross-issue pattern detection on this corpus is the right place to propose code-level improvements (new P-rows, R-rule strengthening). Daily 4h after triage-summary gives the upstream cron time to write today's summaries; the distillation reads them while context is fresh.

## Companion / non-overlap

- ot-daily-learning-debugging (8:07 UTC): operational rules from raw cron output (per-run text grepping, lots of noise filtering). Renamed from `ot-daily-learnings` 2026-05-12.
- ot-daily-learning-mitigated-sevs (21:00 UTC): SEV postmortem-field harvest (sevmanager structured data, SEV-only). Renamed from `ot-sev-postmortem` 2026-05-12.
- ot-triage-summary (9:30 PT, NEW D104502361): writes the resolved-issue audit trail this cron consumes.
- ot-knowledge-distillation (13:30 PT, THIS): cross-issue pattern detection + diff drafting from the incidents/resolved-{sevs,posts,alerts}/ corpus.

## Learned Rules (auto-appended)

(none yet — cron is new in 2026-05-08)
