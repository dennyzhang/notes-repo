[ot-knowledge-distillation cron] Daily 13:30 PT weekday (4h after ot-triage-summary at 09:30). Parse all crisp triage-summary files from the last 7 days; identify recurring patterns across resolved issues; if a pattern crosses an action threshold, DRAFT (never auto-land) a Phabricator diff that improves the OT master agent — new `known-patterns.md` row, new Quality Rule, cron prompt step, or capability scaffold. Cap 1 diff per run.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/knowledge-distillation-state.json` — `{"distilled_summary_paths": ["<rel_path>", ...], "diffs_drafted": ["D<num>", ...], "last_run_epoch": <int>}`. Time budget: ~15 min per run.

Inputs:
- Triage summaries dir (per-TYPE, post-2026-05-17 restructure): `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs|alerts|posts}/<YYYY-MM>/<TYPE>-<id>-<YYYY-MM-DD>.md` (written by ot-triage-summary cron, D104502361). Glob all three dirs.
- Existing pattern DB: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/how/known-patterns.md` (~30+ P-rows).
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

4. **Pattern detection — six action thresholds, only first-matching action fires per run** (cap 1 diff per run, operator review bandwidth):

   | Signal | Threshold | Proposed action |
   |---|---|---|
   | Same `likely_cause` keyword cluster ≥ 3 distinct issues, NOT covered by any existing P-row | ≥3 | Draft new P-row in `known-patterns.md` Quick-Match Table (next sequential P-id; verify falsifier; cite all source summaries). |
   | Same false-alarm signature on alerts (per R16) ≥ 2 issues, same alert family (e.g., publishing-stability missing DENSE_DELTA across multiple model classes) | ≥2 | Draft addition to `human-input-generic/report-templates/crisp-report-style.md` "Trigger phrases" OR a new entry in `references/triage-discipline.md` examples for R16; OR file a meta task (owner=dennyzhang per memory rule) with the over-broad alert config + recommendation to tune. |
   | `bot_self_correction = true` ≥ 2 issues with same correction class (wrong_root_cause / wrong_model_layer / wrong_causality / inferred_stalled_from_duration / model_id_mismatch) | ≥2 | Strengthen the relevant Quality Rule with a new source-incident citation; if no Quality Rule exists for this class, draft NEW R-rule in `references/triage-discipline.md`. |
   | Same `rule_cited` (R14/R15/R16/R17/R18) preventing N issues from misdiagnosis | ≥3 (positive signal) | Add a "validation evidence" line to that rule's row in triage-discipline.md (e.g., "Validated by N independent triage summaries between <date_first> and <date_last>"). |
   | Same `followups` task type recurring (e.g., "alert threshold tune" filed ≥3 times) | ≥3 | Draft a doc note in `references/autonomous-action-allowlist.md` or file an umbrella meta task aggregating the recurring followups. |
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
   - Apply edits per the proposal.
   - Run `arc lint -a` on touched files.
   - For BUCK / Python changes: `buck2 build` smoke-test the affected target (skip if proposal is markdown-only).

8. **Commit + submit DRAFT diff.**
   ```bash
   sl commit -m "[OT bot] knowledge-distillation: <one-line>"
   jf submit --draft --update-fields
   ```
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
