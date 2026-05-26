[ot-debug-quality-weekly cron] Twice-weekly Mon+Thu 9:00 PT (will collapse to weekly after stabilization). Score the bot's debug quality by comparing each mitigated-issue's INITIAL triage (bot's first gchat post when issue opened) vs ACTUAL root cause (authoritative postmortem / operator-confirmed mitigation). Generate a weekly accuracy report with per-issue delta + aggregate stats + trend.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-debug-quality-state.json` — `{"last_run_epoch": <int>, "weekly_scores": [{"week": "2026-W21", "issues_scored": N, "match_pct": <float>, "cluster_accuracy": <float>, "owner_accuracy": <float>, "mitigation_pct": <float>, "miss_classes": {"cluster_wrong": N, "owner_wrong": N, "no_initial_triage": N}}], "scored_issue_ids": ["SEV-S<id>", "ALERT-A<id>", "POST-W<id>"]}`. Time budget: ~15 min per run.

## Why this exists

Operator (2026-05-17 thread `DEltCr_w2yA`): "Every week there are mitigated issues. For any issues, you will do an initial triage in this gchat, so there is a root cause document in the mitigating issues. Also, you have a triage result from your initial debugging. I want to see the delta."

The bot already produces:
1. **Initial triage** — `ot-{sev,alert,post}-monitor` posts a `verdict + class + standing hypothesis + root_cause_status` when the issue first opens (the "first cut" with limited evidence)
2. **Authoritative root cause** — `ot-daily-learning-mitigated-{sevs,posts,alerts}` archives the postmortem (the "after the dust settled" with full evidence)

Both exist; nobody has been measuring the delta. This cron closes the loop: how good was the initial guess?

## Inputs

- **Bot's initial triage** — scan `job_runs.raw_response` for `ot-{sev,alert,post}-monitor` rows during the issue's open window. Extract the structured fields from the gchat-linked paste (`📊 Machine fields: <paste_url>` line) OR from the inline JSON in raw_response (fallback). Key fields:
  - `verdict` (NO_ACTION | MONITOR | PAGE | UNKNOWN | OUT_OF_SCOPE)
  - `class` (REAL_OT_FAILURE | UPSTREAM_INFRA | DETECTOR_BROKEN | THRESHOLD_MISFIT | etc.)
  - `root_cause_status` (known | partial | not_found)
  - `confidence` (high | medium | low)
  - Cluster citation in narrative (CL-NNN)
  - P-row citation (P<NN>)
  - Owner identification (`owner` field)
  - Standing hypothesis paragraph

- **Authoritative root cause** — archive files at:
  - `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/<YYYY-MM>/L<level>-<date>-S<id>.md`
  - `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/<YYYY-MM>/<pri>-<date>-A<id>.md`
  - `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/<YYYY-MM>/<date>-W<id>.md`
  - Extract: actual root cause (from `## Root cause` section), actual mitigation (from `## Mitigation`), actual cluster (from `**Cluster:**` field), actual owner (from `**Identity:** owner=...`), confidence score

## Procedure

1. **Determine week boundaries.** Today is Monday; score the PREVIOUS week (Mon→Sun, last week's full window). Compute ISO week: `WEEK=$(date -d 'last monday' +%Y-W%V)`, `START=$(date -d 'last monday' +%s)`, `END=$(date -d 'this monday' +%s)`.

2. **Find mitigated issues in the week.** Glob archive files with mtime in [START, END):
   ```bash
   find ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs,posts,alerts}/ \
     -name '*.md' -newermt "$START_DATE" ! -newermt "$END_DATE" \
     ! -name 'INDEX.md' ! -name 'README.md'
   ```
   For each archive, extract the issue ID from filename (S<id> / A<id> / W<id>).

3. **For each archived issue, find its INITIAL triage in sqlite.**
   - Query `job_runs` for rows where `job_id IN ('ot-sev-monitor', 'ot-alert-monitor', 'ot-post-monitor')` AND `run_at` within ±48h of the SEV/alert/post's `opened` time AND `raw_response` LIKE '%<issue_id>%'.
   - If MULTIPLE initial triages exist (e.g., bot triaged the same SEV twice as it evolved), take the FIRST one — that's the bot's "first cut with limited evidence" which is what we're scoring.
   - If NO initial triage exists, classify as `no_initial_triage` (miss class).

4. **For each issue with both inputs, compute the delta.** Score each dimension:

   **(a) Cluster accuracy (CL-NNN match)**
   - Initial cited CL-NNN, archive cites same → `MATCH`
   - Initial cited CL-NNN, archive cites different → `WRONG_CLUSTER` (record both)
   - Initial cited none, archive cites CL-NNN → `MISSED_CLUSTER`
   - Initial cited CL-NNN, archive cites none → `OVER_CLUSTERED` (likely false positive)
   - Both cite none → `BOTH_NONE` (neutral, not scored)

   **(b) Verdict accuracy**
   - Bot said PAGE/MONITOR, archive shows REAL_OT_FAILURE/MITIGATED_WITH_FOLLOWUP → `RIGHT_TO_ESCALATE`
   - Bot said NO_ACTION, archive shows REAL_OT_FAILURE → `MISSED_REAL_ISSUE` (the worst error class)
   - Bot said PAGE, archive shows DETECTOR_BROKEN/THRESHOLD_MISFIT/TRANSIENT_NOISE → `FALSE_PAGE` (the second-worst — pages people for noise)
   - Bot said NO_ACTION, archive shows DETECTOR_BROKEN → `MATCH_NO_OP`
   - Bot said MONITOR, archive shows MITIGATED via routine — `MATCH_MONITOR`

   **(c) Root cause accuracy (semantic match — needs subagent)**
   - Spawn Agent tool with prompt: "Score the semantic match between two root-cause descriptions on a scale of 0-1 (1=identical, 0.7=same mechanism different details, 0.4=same general area but different mechanism, 0=different). Initial: '<bot_root_cause_paragraph>'. Actual: '<archive_root_cause>'. Return just the number + one-line justification."
   - If Agent unavailable, use keyword overlap heuristic: tokenize, count shared technical terms (NaN, ZippyDB, Shampoo, snapshot, scribe, etc.), score = `overlap / max(len_a, len_b)`.

   **(d) Owner identification accuracy**
   - Bot's `owner` field vs archive `**Identity:** owner=...`
   - Exact match → 1.0; same team (oncall match) → 0.5; different person → 0.0

   **(e) Mitigation suggested correctly**
   - If bot's standing hypothesis or P-row suggestion overlaps with actual mitigation → 1.0
   - If bot suggested wrong direction → 0.0
   - If bot said "needs investigation" and archive confirms unknown root → not scored (neutral)

5. **Aggregate per-issue scores.** For each issue, compute composite score:
   ```
   composite = (cluster_score + verdict_score + root_cause_score + owner_score + mitigation_score) / 5
   ```
   Classify the issue:
   - `composite >= 0.85` → `EXCELLENT`
   - `0.65 <= composite < 0.85` → `GOOD`
   - `0.40 <= composite < 0.65` → `PARTIAL`
   - `composite < 0.40` → `MISS`
   - Special: any `MISSED_REAL_ISSUE` or `FALSE_PAGE` → automatically `MISS` regardless of composite (these are the operator-trust-breaking failure modes)

6. **Compute aggregate weekly stats:**
   - Total issues scored, total with no_initial_triage
   - Match % (EXCELLENT + GOOD as fraction of total)
   - Cluster accuracy %, verdict accuracy %, root_cause avg score, owner accuracy %, mitigation %
   - Miss class breakdown
   - **Trend**: compare to previous 4 weeks in state file (delta_pct)

7. **Generate the weekly report.** Post to spaces/AAQAVOjYc80:

   ```
   *📊 ot-debug-quality-weekly — Week 2026-W21*
   
   *Composite: 73% match (▲ +4% vs W20)*
   
   *Scored: <N> mitigated issues* (12 SEVs, 24 alerts, 8 posts) · *No initial triage*: <M> (-_<one line on why if N>0_)
   
   *Per-dimension accuracy:*
   • Cluster match: 78% (▲ +6%) — best dimension this week
   • Verdict: 84% (▼ -2%)
   • Root cause: 0.68 avg (▲ +0.05)
   • Owner: 91% (▲ +3%)
   • Mitigation: 62% (▼ -8%)
   
   *Miss-class breakdown (worst at top):*
   • 🚨 MISSED_REAL_ISSUE: <N> ← trust-breaking
   • 🚨 FALSE_PAGE: <N> ← trust-breaking
   • WRONG_CLUSTER: <N>
   • MISSED_CLUSTER: <N>
   • no_initial_triage: <N>
   
   *Wins this week (3 best):*
   • [S<id> <title>](url) — bot called <hypothesis> at <time>; postmortem confirmed identical root cause + cited same CL-NNN
   • ...
   
   *Misses this week (3 worst):*
   • [S<id> <title>](url) — bot said <bot_hypothesis>; actual was <actual_root_cause>. Gap: <one-line on what bot missed>
   • ...
   
   *4-week trend:*
   ```
   W18: ████████░░ 71%
   W19: ███████░░░ 67%
   W20: █████████░ 69%
   W21: ████████░░ 73%  ← this week
   ```
   
   📊 Per-issue scores: <paste_url>
   ```

   Keep narrative under 3000 chars. Spill the per-issue detail table to paste.

8. **Persist state.** Append this week's row to `weekly_scores`. Add all scored issue IDs to `scored_issue_ids` (prevent re-scoring on backfill runs). Write state file.

9. **Detect regressions.** If composite drops >10% week-over-week OR if `MISSED_REAL_ISSUE` count is >0, flag in the post with `⚠️ regression detected` prefix. The point is to make trust-breaking failures impossible to miss.

## Per-issue detail paste

Each entry in the per-issue paste table:

| Issue | Bot's initial (timestamp) | Actual (archive) | Composite | Miss class |
|---|---|---|---|---|
| [S665222](https://www.internalfb.com/sevmanager/view/665222) | 17:34 PT: MONITOR / class=REAL_OT_FAILURE / hypothesis=NaN cascade from S665135 / no CL citation | actual: CL-005 delta-publish + GPU quota / owner=skyao (bot guessed abmajumdar) | 0.55 | PARTIAL |

## Safety

- **Read-only.** This cron reads `job_runs`, archive files, gchat messages. Never writes anywhere except its own state file + the weekly digest post + the per-issue paste.
- **Only scores issues archived in the week window.** Backfill stubs (BACKFILL HEADER marker) are EXCLUDED — they don't have authoritative root cause to compare against.
- **Subagent timeout 30s per issue.** If subagent fails on >50% of issues, fall back to keyword-heuristic root-cause scoring and flag `degraded_inputs=subagent_unavailable` in the post.
- **Dedup.** If an issue is already in `scored_issue_ids`, skip (don't double-score on re-runs). Allows safe re-runs.
- **Per RULES.md § Signal-only operator messaging:** if no issues to score (week was quiet), respond `HEARTBEAT_OK {issues_scored: 0, reason: "no mitigations this week"}` and DO NOT post. Operator value of "we had a clean week" report = low; reserve attention for actionable feedback.

## What this is NOT

- NOT a per-issue critique on the day-of. That's ot-postmortem-validator's job (validates the digest at write time).
- NOT a real-time accuracy meter. The point is the weekly trend — does the bot get better or worse over time?
- NOT a perfect score. Semantic root-cause matching via subagent is imperfect; treat ±5% as noise. Look at trends across multiple weeks before drawing conclusions.

## Distinct from sibling crons

- **ot-postmortem-validator** (daily 22:30 PT): validates mitigated-* digests for internal consistency (cluster IDs exist, P-rows cited correctly). Does NOT compare initial vs final.
- **ot-knowledge-curation** (nightly 23:00 PT): drafts diffs + mega-learnings from mitigated archives. Forward-looking ("what should we change?").
- **ot-prompt-change-validator** (every 10 min): pre-flight checks on cron prompt edits. Output-shape, not output-quality.
- **ot-debug-quality-weekly** (THIS, weekly Mon 9 AM PT): retrospective accuracy report. Backward-looking ("how did the bot's first guesses score?").

## Read-only

This cron does not mutate SEVs, alerts, posts, archive files, or cron prompts. The ONLY external write is the weekly gchat post + the per-issue paste. No `meta sevmanager.sev update`, no `meta workplace.comment create`, no edits to other crons' state files.
