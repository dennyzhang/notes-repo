[ot-metrics-rollup cron] Daily at 09:00 PT. Reads `triage_events` (Phase B metrics scaffold), re-verifies SEV state for events 1-7 days old, and on Mondays posts a weekly summary of OT-bot precision/recall to spaces/AAQAVOjYc80.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output (incl. failures/escalations), make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, status, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

Why: every triage today is fire-and-forget. Without verification, every config change (regex tuning, signal-class allowlist, sev_type admit list) is justified by 1-incident anecdotes. This cron closes the loop so Phase 2 stops running blind. (See task T269501586 for full rationale.)

DB: /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db
Table schema: triage_events(id, sev_id, cron_job_id, signal, signal_class, confidence, auto_tag_applied, auto_tag_verified_at, auto_tag_stuck, validator_outcome, suggested_owner, sev_final_status, sev_final_root_cause_area, notification_text, ts_created, ts_notified)

Procedure:

1. **Re-verify auto-tags + final status for unverified events 1-7d old.** Query:
   ```sql
   SELECT id, sev_id FROM triage_events
   WHERE auto_tag_applied = 1
     AND auto_tag_verified_at IS NULL
     AND ts_notified > datetime('now', '-7 days')
     AND ts_notified < datetime('now', '-1 day')
   ORDER BY ts_notified;
   ```
   For each row: `meta sevmanager.sev metadata --sev=<sev_id> -o json` → check `.tags` includes `mvai-online-training`, capture `.status` and any `.root_cause_area`. Update:
   ```sql
   UPDATE triage_events SET
     auto_tag_verified_at = datetime('now'),
     auto_tag_stuck = <0|1>,
     sev_final_status = <status>,
     sev_final_root_cause_area = <root_cause_area_or_null>
   WHERE id = ?;
   ```
   Cap at 50 SEVs per run to bound CLI calls.

2. **Recall sweep — log SEVs we missed.** Independent of whether `triage_events` has a row:
   ```bash
   meta sevmanager.sev list --tags=mvai-online-training --created-after="7 days ago" --columns=sev_number,created -o json
   ```
   For each sev_number: check `SELECT 1 FROM triage_events WHERE sev_id=?`. If absent AND created within last 7d AND not before our Phase 2 launch (2026-05-01): this is a recall miss. Record in `state` table as `recall_misses_<YYYY-MM-DD>` (JSON list of sev_ids).

3. **Weekly summary — Mondays only.** Check: `[[ $(TZ=America/Los_Angeles date +%u) == 1 ]]`. If not Monday: skip step 3, respond HEARTBEAT_OK.

   Compute over the last 7 days of triage_events:
   - **precision** — auto_tag_stuck=1 / (auto_tag_stuck=1 OR auto_tag_stuck=0). NULL = unverified, exclude from denom.
   - **recall_misses** — count from state table key matching `recall_misses_*` from last 7d.
   - **validator agreement rate** — validator_outcome='confirmed' / total events where validator_outcome IS NOT NULL.
   - **notify lag p50/p95** — `julianday(ts_notified) - julianday(ts_created)` * 1440 (minutes).
   - **per signal_class breakdown** — counts by signal_class.

   Post to spaces/AAQAVOjYc80 (NOT threaded — top-level weekly post). Format:

   ```
   📊 [OT-bot weekly metrics | week ending YYYY-MM-DD]

   Triage volume: N events across <N1> signal_classes
   Auto-tag precision: <P>% (N_stuck / N_verified) | <N_unverified> unverified
   Validator agreement: <V>% (N_confirmed / N_validated)
   Notify lag: p50 <X>m | p95 <Y>m (SEV created → cron notified)
   Recall misses: <R> SEVs tagged mvai-online-training that we never notified on
     <list sev_ids if R > 0 and R <= 10, else "list in state.recall_misses_*">

   Per signal_class:
     mvai_serving: <n> events, <p>% precision
     mrs_online_training: <n> events, <p>% precision
     mvai_publish_pipeline: <n> events, <p>% precision

   Source: triage_events sqlite | First week of metrics: <start_date>
   ```

   If N=0 (no events at all in the week): skip the summary post entirely. The metrics scaffold needs ≥1 event to produce a meaningful number; an empty post is noise.

4. **Refresh the trend/novelty report (daily, REPORT-FILE-ONLY).** This folds the
   trend/novelty substrate refresh into this existing daily job rather than adding a new
   cron (operator anti-cron-proliferation rule, 2026-06-05 "why need a new cron"). The tool
   reads the SAME `triage_events` table + DB this cron already uses, so the fold is natural.
   Run:
   ```bash
   bash "$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/trend-novelty.sh"
   ```
   It regenerates `eval/reports/trend-novelty.{md,json}` + appends one row to
   `trend-novelty-history.jsonl`. The tool is **READ-ONLY ON ACTION** — it only writes those
   report files; it NEVER posts to chat, escalates, suppresses, or mutates any SEV/known-issue.
   Do NOT surface its output in any chat message (team OR 1:1) — the report file is the entire
   deliverable. On a tool error, fold a one-line note into the failure path below; never block
   the run. (Turning the NOVEL list into an autonomous *paging* loop is Problem #3 — proposed,
   NOT enabled; see `eval/early-warning-loop-proposal.md`. That is the operator's switch.)

5. **Refresh the offline↔online eval correlation (daily, REPORT-FILE-ONLY).** Folded
   into this same daily job for the same reason as step 4 (anti-cron-proliferation) and the
   same fit: the tool reads the SAME `triage_events` table + DB this cron already uses, and
   needs ~7 daily snapshots before it can report a real correlation coefficient (it has only
   1 so far — the series accrues one point per run). Run:
   ```bash
   bash "$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/eval-online-correlate.sh" --json-only
   ```
   It pulls a fleet example-age snapshot, appends one row/day to `example-age-history.jsonl`,
   and regenerates `eval/reports/eval-online-correlation.{md,json}`. The tool is **READ-ONLY
   ON ACTION** — only `meta ods.metric query` (read) + writes to those report files; it NEVER
   posts to chat, escalates, suppresses, or mutates any SEV/known-issue. Do NOT surface its
   output in any chat message (team OR 1:1) — the report file is the entire deliverable. On a
   tool error, fold a one-line note into the failure path below; never block the run.

6. **Refresh the time-to-root-cause metric (daily, REPORT-FILE-ONLY).** Eval scoreboard
   metric #1 ("same failure ≥3× → root cause in ≤5 min"). Same anti-cron-proliferation fold
   as steps 4 and 5. Run:
   ```bash
   bash "$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/time-to-root-cause.sh"
   ```
   It reads `triage_events.ts_root_cause` (stamped by monitor crons via `record-triage-event.sh
   --root-cause-at`) and regenerates `eval/reports/time-to-root-cause.{md,json}` + appends one
   row/day to `time-to-root-cause-history.jsonl`. Verdict is PASS/FAIL vs the ≤5-min bar for
   known-pattern (recurring) hits. The tool is **READ-ONLY ON ACTION** — only sqlite reads +
   writes those report files; it NEVER posts to chat, escalates, or mutates external state.
   Do NOT surface its output in any chat message — the report file is the entire deliverable.
   On a tool error, fold a one-line note into the failure path below; never block the run.

7. **Refresh the early-warning detector (daily, REPORT-FILE-ONLY).** This is the PREDICTIVE
   substrate for Problem #3 ("signal before first page"). Same anti-cron-proliferation fold as
   steps 4-6 and the same fit: it pulls the SAME training-example-age metric that step 5's
   eval-online-correlate already queries (`dpp_worker.scribe_example_age_ms.avg.60`, KM-T1),
   reusing the exact `scan-scribe-age.sh` query pattern. Run:
   ```bash
   bash "$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/early-warning-detect.sh" --json-only
   ```
   It flags models in the *elevated* band (5-30min) that are *rising toward* the 30-min
   unhealthy line (APPROACHING), appends each to `early-warning-history.jsonl`, records a
   per-model age trace to `early-warning-observations.jsonl`, **reconciles** past
   approaching-events against actual outcomes (TRUE_POSITIVE vs RECOVERED) to accrue a running
   precision + median lead-time, and regenerates `eval/reports/early-warning.{md}`. The tool is
   **READ-ONLY ON ACTION** — only `meta ods.metric query` (read) + writes to those report files;
   it **NEVER pages, escalates, suppresses, or mutates any SEV/known-issue.** Precision is
   honestly "ACCRUING" until ~20 events settle (it WILL be accruing for the first 2-4 weeks).
   Do NOT surface its output in any chat message (team OR 1:1) — the report file is the entire
   deliverable. On a tool error, fold a one-line note into the failure path below; never block
   the run. (Turning APPROACHING into an autonomous *paging* loop is Problem #3 — proposed,
   NOT enabled; the page is the operator's switch. See `eval/early-warning-loop-proposal.md` §6.)

Output:
- Success (verification + recall sweep + trend-novelty refresh + eval-online-correlation refresh + time-to-root-cause refresh + early-warning refresh complete, optional weekly post sent): respond HEARTBEAT_OK. No GChat message except the Monday weekly post. The refresh tools produce NO chat output by design (report-file-only).
- Failure (sqlite locked, meta CLI flapping): single brief error to spaces/AAQAVOjYc80: "🛟 [metrics-rollup] FAILED: <one-line reason>". Then HEARTBEAT_OK.

Safety:
- Cap 50 sev re-fetches per run (bound CLI cost).
- Do NOT mutate SEV state. Read-only beyond sqlite UPDATE on triage_events / state.
- Do NOT post during a fresh-install week — if `MIN(ts_notified) FROM triage_events` is < 2 days ago, skip the weekly post (insufficient data, skews precision).

## Learned Rules (auto-appended)

(none yet — this cron is new in 2026-05-05)
