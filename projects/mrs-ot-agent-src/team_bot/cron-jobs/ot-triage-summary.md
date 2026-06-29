[ot-triage-summary cron] Daily 9:30 PT weekday. For each triaged issue (SEV / alert / Workplace post) that became RESOLVED in the last 48h AND was triaged by the bot, write a one-file crisp summary in the operator's local incidents/resolved-{sevs,posts,alerts}/ directories (one per TYPE). Style: crisp 5-element template per `human-input-generic/report-templates/crisp-report-style.md` (matches D104497251). One file per issue. Skip if no triage was done OR issue still open.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/triage-summary-state.json` — `{"summarized_ids": ["<TYPE>-<id>", ...], "last_run_epoch": <int>}`. Output dir: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs|alerts|posts}/<YYYY-MM>/` — per-TYPE subdir (post-2026-05-17 restructure). Time budget: ~10 min per run, cap 10 summaries per run.

## Procedure

0. **DEDUP GUARD — execute first, before any other step.** A daemon scheduler race condition fires this job twice within 1–5 min on most weekdays (documented Jun 2–22; T276766497). To prevent duplicate work and duplicate GChat messages, check if a prior run completed recently:

   ```bash
   python3 -c "
   import json, time, os
   f = os.path.expanduser('~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/triage-summary-state.json')
   try:
       d = json.load(open(f))
       print(int(time.time() - d.get('last_run_epoch', 0)))
   except:
       print(9999)
   "
   ```
   If result is **< 600** (another run completed within the last 10 minutes): stop immediately.
   Respond exactly: `HEARTBEAT_OK {"dedup": true, "cause": "prior_run_within_10min"}`
   No prose, no further steps, no state reads.

1. **Read state file.** Extract `summarized_ids`. If file missing/corrupt, default empty set + create file fresh.

2. **Enumerate candidate issues from last 48h of cron output.** Query sqlite `job_runs`:
   ```bash
   sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
       "SELECT job_id, run_at, raw_response FROM job_runs \
        WHERE job_id IN ('ot-sev-monitor','ot-alert-monitor','ot-post-monitor') \
        AND run_at > datetime('now','-48 hours') \
        ORDER BY run_at;"
   ```
   Extract issue IDs from each raw_response by source type:
   - `ot-sev-monitor`: `S\d{6,}` SEV ids
   - `ot-alert-monitor`: `alert_id=([0-9]+)` from short_id URLs
   - `ot-post-monitor`: workplace permalink ids (long numeric tail of `/permalink/<id>/`)
   Tag each as `SEV-<id>`, `ALERT-<id>`, `POST-<id>`. Dedupe.

3. **Filter to RESOLVED issues only.** Per-type resolution check:

   - **SEV**: `meta sevmanager.sev metadata --sev=S<id> -o json` → status ∈ {`Closed`, `Mitigated`} OR `time_mitigated` is set OR `time_closed` is set. If still `In Progress` → skip.
   - **ALERT**: `meta oncall.feed list --oncall=<rotation> --item-type-is=Alert --title-contains=<key> -o json` → check if alert no longer in OPEN list. If still OPEN → skip. Note: alert may have been re-classified as FALSE_ALARM (per R16) — those count as resolved.
   - **POST**: workplace posts don't have a "resolved" state. Resolution heuristic: post has a comment from the model owner OR post-author OR mvai oncall stating "fixed", "resolved", "mitigated", "closed", "false alarm", "thanks" within the last 48h, OR no new comments in 24h+ AND original problem-symptom no longer reported. If ambiguous → skip (bias toward not-yet-resolved).

4. **Filter against `summarized_ids`.** Drop issues already in the summarized set (avoid re-writing). Cap remaining at 10 (oldest first).

5. **For each remaining RESOLVED issue, gather context for the summary:**

   - **SEV**: pull metadata + GChat live thread (`gchat read <space_id>` if accessible) + final root-cause statement from sevmanager `overview` + `incident_impact` + `followup_tasks`. Apply Quality Rules R14 (entrypoint check), R15 (recurring-flow enabled), R16 (alert applicability), R18 (diagnosed-stage scope re-check) to confirm what the actual root cause was — re-run them if the bot's original triage is suspect or pre-dates the rule landing.
   - **ALERT**: pull alert metadata via `meta url.load lookup --input=<alert_url>`. Check if false alarm (per R16) or real failure. If real, what fixed it.
   - **POST**: read post body + comments via `meta workplace.post content` + `meta workplace.comment list`. Identify the operator/author's resolution comment OR last actionable signal.

6. **Render crisp 5-element summary per `human-input-generic/report-templates/crisp-report-style.md`** for each issue. Cap ~600 chars body. Format:

   ```markdown
   # [OT triage summary] <SEV-id|alert-id|post-id> — <symptom> — RESOLVED <YYYY-MM-DD HH:MM PT>

   **PROBLEM**: <one sentence + 1-2 supporting numbers — duration, impact scope, affected models>

   **LIKELY CAUSE** (confirmed): <one sentence + path:line code-pointer if applicable; cite Quality Rule that pinpointed it (R14/R15/R16/R17/R18/P-row id)>

   Detail reporting: <link to SEV / alert / post + bot's verbose triage from job_runs (cite raw_response paste id or sqlite ROW URL if available)>

   **RESOLUTION**: <one sentence — what fixed it; who acted; if false-alarm, say "alert misconfigured for model class — re-tune required">

   **FOLLOW-UPS**: <task ids (T<num>) or "none">
   ```

7. **Write each summary to local file** — per-TYPE subdir routing (post-2026-05-17 restructure):
   - SEV: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/<YYYY-MM>/SEV-S<id>-<YYYY-MM-DD>.md`
   - Alert: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/<YYYY-MM>/ALERT-<short_id>-<YYYY-MM-DD>.md`
   - Post: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/<YYYY-MM>/POST-<workplace_permalink_id>-<YYYY-MM-DD>.md`

   **CO-LOCATION NOTE:** triage summaries live alongside per-incident archives in the SAME directory (see e.g. `incidents/resolved-sevs/2026-05/L4-2026-05-11-S661983.md` which contains both archive frontmatter AND a `## Crisp Summary` block). If an archive file for the same issue ALREADY exists from `ot-daily-learning-mitigated-*`, APPEND the crisp summary as a `## Crisp Summary` section to the existing file rather than creating a new file. Detect via filename glob (e.g. for SEV: `ls incidents/resolved-sevs/*/*-S<id>.md`).
   - `mkdir -p` the YYYY-MM dir first.
   - Atomic write (write to `.tmp` then `mv`).
   - Idempotent: if file already exists with same content, skip; if exists with different content, overwrite (newer triage wins).

8. **Append to `summarized_ids` state.** Persist atomically. Update `last_run_epoch` to now.

9. **Send GChat digest to `spaces/AAQAVOjYc80`** if any summaries written:
   ```
   📒 [Daily triage summary — N resolved | YYYY-MM-DD]
   - SEVs: <count>
   - Alerts: <count>
   - Posts: <count>
   - False alarms (R16): <count>
   - Out-of-scope drops (R18): <count>
   Files: ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs|alerts|posts}/<YYYY-MM>/
   ```
   Cap 800 chars. Then respond `HEARTBEAT_OK`.

10. **If zero new resolved issues** → respond exactly `HEARTBEAT_OK` — no prose, no preamble, no "nothing to do" context. The token must be the first content on the first line. Do NOT send anything to GChat. (DD-preamble class, T276623118: prose before HEARTBEAT_OK causes the daemon to treat the response as delivered content.)

## Safety / failure modes

- If sqlite query fails: do NOT advance state, brief error string (no HEARTBEAT_OK). Resume next day.
- If a per-issue context fetch fails (GChat read DEGRADED, alert URL inaccessible, etc.): write a `DEGRADED` note in the summary and continue (don't block the rest of the run).
- NEVER mutate any external state — no SEV updates, no alert reassignments, no Phab comments, no task creation.
- **READ-ONLY meta-rule:** NEVER call `meta workplace.comment create`, `meta workplace.post resolve`, `meta sevmanager.comment create`, any oncall.feed mutation, or any external-surface write. This cron is purely a triage-summary writer to local files + GChat. Operator clarified 2026-05-15.
- NEVER include sibling-org SEVs in the output — apply `team_lane_scope.is_in_mrs_org_scope()` per `4.5` rule from ot-sev-monitor BEFORE summarizing. (Same out-of-org filter that applies to all OT crons.)
- NEVER summarize an issue that was correctly silent-dropped (out-of-scope / sibling-org). Silent-drops should not appear in the summary corpus.

## Why this exists

Operator (2026-05-08): "we need to create a cron job which summarize triaged issues every day. It shall summarize issues like D104497251. Each issue should be one local file. Only do this for resolved issues: SEVs, alerts, user posts."

The bot already triages issues in real-time via three crons (ot-sev-monitor / ot-alert-monitor / ot-post-monitor). Outputs go to GChat threads + sqlite raw_response rows. There's no consolidated record of "what was the issue and what fixed it" per resolved item. This cron creates that audit trail in operator-readable form, in the same crisp 5-element style used for cross-team posts (so the same files can be repurposed as Workplace posts later if needed).

## Learned Rules (auto-appended)

(none yet — cron is new in 2026-05-08)
