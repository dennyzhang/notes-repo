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

Output:
- Success (verification + recall sweep complete, optional weekly post sent): respond HEARTBEAT_OK. No GChat message except the Monday weekly post.
- Failure (sqlite locked, meta CLI flapping): single brief error to spaces/AAQAVOjYc80: "🛟 [metrics-rollup] FAILED: <one-line reason>". Then HEARTBEAT_OK.

Safety:
- Cap 50 sev re-fetches per run (bound CLI cost).
- Do NOT mutate SEV state. Read-only beyond sqlite UPDATE on triage_events / state.
- Do NOT post during a fresh-install week — if `MIN(ts_notified) FROM triage_events` is < 2 days ago, skip the weekly post (insufficient data, skews precision).

## Learned Rules (auto-appended)

(none yet — this cron is new in 2026-05-05)
