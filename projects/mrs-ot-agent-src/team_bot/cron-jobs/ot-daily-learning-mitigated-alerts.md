[ot-daily-learning-mitigated-alerts cron] Daily 22:05 PT (2026-05-16: rescheduled from 21:15 PT after daemon was observed missing the :15 minute tick repeatedly — see commit b88-ish, daemon log gaps at 2026-05-15 21:15 PT despite firing at :12 + :16). 22:05 PT chosen because daemon empirically fires :00 / :05 / :10 ticks reliably. Wakes 35 min after ot-daily-learning-mitigated-sevs (21:00 PT) and 35 min after ot-daily-learning-mitigated-posts (21:30 PT). Harvest postmortem signal from OT alerts that closed/cleared in last 24h (the *mitigated alerts* corpus), surface in team space as ONE consolidated digest, write one durable archive file per alert, propose pattern entries for `known-patterns.md`. Strictly propose-only — no alert state mutations. ot-alert-monitor catches alerts as they OPEN; this catches them after CLOSE. Daily cadence (not hourly) because the post-clearance "did the underlying signal actually recover?" question takes minutes-to-hours to settle.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

**Output shape: ONE top-line message + ONE threaded reply with all digests + ONE pattern-proposal threaded reply + ONE validator threaded reply, PLUS one archive file per alert.** Total 4 GChat messages per run regardless of alert count. Archive files are durable artifacts (do not count as messages). If a run has 0 NEW cleared alerts: HEARTBEAT_OK, no posts, no archive writes.

**Archive scheme** (per OT Master Agent doc § Data model — "one mitigated issue one file"): `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/<YYYY-MM>/<priority>-<YYYY-MM-DD>-A<short_id>.md`. Directory created if missing. File survives ods/scuba data retention windows (signal slice captured durably) and is referenced from the digest line so the operator + alert assignee can click through to confirm.

**Priority taxonomy (clarified 2026-05-17 thread `Uc-pVBEXNQ8` after operator caught `high`-vs-`P1` inconsistency):** the `<priority>` field in the filename MUST be one of: `critical` / `high` / `medium` / `low` / `unknown` (OneDetection urgency values, lowercase). Source: `meta monitoring.alert metadata --alert-id=<id>` → `urgency` field (mapped: CRITICAL→critical, MAJOR→high, MINOR→medium, WARNING→low; if field absent → `unknown`). DO NOT use the older `P0/P1/P2/P3/P4` taxonomy — that comes from `meta oncall.feed describe` which is a different source and was the pre-OneDetection-migration convention. Existing `P*-`-prefix files are historical; new archives use OneDetection terms only.

**UPSERT by alert_id (added 2026-05-17 thread `Uc-pVBEXNQ8` after stub-pollution audit):** before writing a new archive, GLOB for any existing file matching the same alert_id: `ls ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/<YYYY-MM>/*-A<short_id>.md`. If a file exists for the same alert_id AND the existing file is larger / has more triage detail (proxy: size > 1500 bytes vs new content < 1500), DO NOT write a new stub — the existing rich postmortem supersedes. If new content is richer (size > existing), OVERWRITE the existing path (do NOT create a new filename with a different priority prefix). Avoids the 2026-05 stub-pollution pattern where 14 P1-* stubs (~600 bytes each) sat alongside the same alert's later high-* rich archive (~2500 bytes each).

**Stub-content guard:** if all of `Resolution signal`, `Hypothesis`, `Mitigation` are about to be written as `[historical archive — ...]` or `[no real-time triage on file]` placeholders, DO NOT write the file at all — the archive adds zero signal. Wait for the next mitigation cycle to fire when richer data is available. Per 2026-05-17 audit: 14 of 22 May files were these zero-signal stubs.

**Scope — single rotation.** Same as ot-alert-monitor: poll `mrs_online_training` only. Adjacent product rotations (mrs_relevance_retrieval_*, feed_recommendation_ranking_modeling, ig_rec_modeling_lsr, videorecs_ranking, etc.) are OUT OF SCOPE — coverage is owned by the per-product oncall, not by mrs_online_training. (Operator clarified 2026-05-12: `mrs-ot-reliability` was discussed as a possible second rotation, but the canonical scope rule from ot-alert-monitor stays — single source of truth, expanded only if/when an alert routes there at source.)

State file: ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-mitigated-alerts-state.json — `{"processed_ids": ["<short_id>", ...], "last_run_epoch": <int>}`. Time budget: ~3 min per alert. Cap 5 alerts per run. State co-located with archive output dir per OT Master Agent doc convention (option ii unified, 2026-05-12).

Procedure:

1. Read state file. Extract processed_ids. If file missing/corrupt, treat as empty set.

2. **Find alerts that cleared in last 24h** — sourced from ot-alert-monitor's diagnosed_ids, NOT from a meta query:

   **Why this source change (2026-05-16):** the prior approach used `meta oncall.feed list --status-is=Closed`, but the meta CLI for OneDetection alerts doesn't expose closed alerts — the query silently returns 0 rows because cleared alerts disappear from the feed. **Verified 2026-05-16 thread `xELpXuo0m2Q` 16:03 PT.** ot-alert-monitor's `diagnosed_ids` is the only reliable list of OT alerts the bot has SEEN; cross-referencing each against the current OPEN feed tells us which have since cleared.

   **⚠️ KNOWN GAP (operator flagged 2026-05-16 16:06 PT):** This source CANNOT see alerts the bot didn't triage. Missed alert classes:
   - Alerts that fired + auto-cleared between hourly `ot-alert-monitor` polls (transient noise, sub-1h lifetime)
   - Alerts during bot downtime (cold-start blind window, daemon-skip events)
   - Alerts deliberately skipped by ot-alert-monitor (lane mismatch, out-of-scope)

   Attempted workaround `meta oncall.feed list --status-is=Closed --oncall=mrs_online_training` returns 0 rows in current testing — OneDetection doesn't surface cleared alerts back through this CLI on the mrs_online_training rotation. Until an alternate API is found (Source B), this cron only archives what `ot-alert-monitor` triaged. Coverage gap should be measured periodically: query total alerts opened on rotation in last 24h via dashboard, compare to count archived here. If gap is large, consider:
   - Increasing `ot-alert-monitor` polling frequency (hourly → 15-30 min) to reduce missed transient alerts
   - Finding the right meta CLI / Scribe / ODS dataset for closed-alert history
   - Operator manually feeding missed alerts via expert-observations workflow

   ```bash
   # (a) Get the bot's known-diagnosed alert IDs (the schema is {id: added_epoch} post-2026-05-16)
   STATE=/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/alert-state.json
   DIAGNOSED_IDS=$(python3 -c "import json; d=json.load(open('$STATE')); print('\n'.join(k for k in d['diagnosed_ids'] if not k.startswith('_')))")

   # (b) Get current OPEN alerts (these are still active, not cleared)
   meta oncall.feed list --oncall=mrs_online_training --item-type-is=Alert -o json --limit=200 \
       | python3 -c "import json,sys; print('\n'.join(s['id'] for s in json.load(sys.stdin)))" > /tmp/current_open.txt

   # (c) Diagnosed but no longer open = CLEARED = candidate for archive
   comm -23 <(echo "$DIAGNOSED_IDS" | sort) <(sort /tmp/current_open.txt) > /tmp/cleared_candidates.txt
   ```

   **For each cleared candidate, verify it was triaged in the last 24h** (not stale from days ago):
   - State file's `diagnosed_ids` schema (post-2026-05-16 hardening, see ot-alert-monitor.md step 4 hold-down) is `{<alert_id>: <added_epoch>}`. The `<added_epoch>` is when the bot first triaged it.
   - Filter: `(now_epoch - added_epoch) < 86400 AND alert_id in cleared_candidates`

   This produces the canonical "alerts the bot SAW going active AND have since cleared, within the daily archive window."

3. Filter to alerts whose short_id is NOT in processed_ids → NEW candidates.

4. Prune processed_ids: drop IDs older than 14 days (re-fired alerts get re-processed).

5. If no NEW candidates: persist state, update last_run_epoch, respond HEARTBEAT_OK and stop. **No posts.**

6. **Gather phase** — for each NEW candidate (cap 5 per run), collect data into in-memory list `digests`. DO NOT post per-alert during this phase. For each:

   a. **Pull alert metadata + comments.** Use `meta oncall.feed describe --id=<id> -o json --no-truncate` (or equivalent). Extract: title, priority, assigned_user, ods/scuba query backing the alert (if linkable), opened_time, fired_time (if distinct), cleared_time, duration, related model_id (regex `\b\d{8,}\b` from title), signal class (SPARSE_DELTA / DENSE_DELTA / FULL_SNAPSHOT / NCCL / OOM / model_age / ATS / scribe_lag).

   b. **URL sourcing — MANDATORY pre-fetch.** Per ot-alert-monitor field-naming gotcha: the per-alert OneDetection URL lives in `short_id`, NOT `url` (which returns the rotation OMH dashboard). Capture as literal variable, e.g.:
      ```bash
      alert_X_short_id="<from JSON>"
      alert_X_url="https://www.internalfb.com/onedetection/alert?alert_id=${alert_X_short_id}"
      ```
      NEVER write template literal `<url>`, bare alert id, or rotation name. If short_id empty, render `<url-unavailable>`.

   c. **Pull underlying ods/scuba signal slice — for archive only.** If the alert links to an ods entity or scuba query (extract from alert config / describe JSON), capture ±5 min around `fired_time` (or `created_time` if fired_time unavailable):
      ```bash
      # Example for ods-backed alerts:
      meta ods query --entity=<entity> --key=<key> --time-start=<t-5m> --time-end=<t+5m> --output=json
      # For scuba-backed alerts: use the alert's saved scuba query with the time window narrowed to ±5min
      ```
      Store as `signal_slice` (verbatim, ≤4KB; truncate middle with `[…N points elided…]` marker if longer). If no ods/scuba link resolvable, store `signal_slice="[no underlying signal source linked to this alert]"`.

   d. **Resolution signal verification — required.** "Cleared" in feed status is necessary but not sufficient. Verify the underlying signal actually recovered:
      - Re-query the same ods/scuba source for the LATEST 30 minutes.
      - If signal still in alert range (didn't recover, alert was just acked/silenced): set `resolution_signal="acked_only — signal still degraded as of <iso>"` and flag digest entry `degraded=true`.
      - If signal recovered + held below threshold for ≥30 min: set `resolution_signal="recovered — back below threshold for >30m as of <iso>"`.
      - If unable to query (no entity link): set `resolution_signal="[unverified — no ods/scuba link]"`.
      - **⚠️ If citing an upstream SEV as the resolution explanation (e.g., "recovered after ZippyDB S<id> mitigated"): the SEV's status MUST come from `meta sevmanager.sev metadata --sev=S<id> -o json`, specifically the `time_mitigated` and `status` fields.** NEVER cite "SEV mitigated <timestamp>" based on in-thread comments, oncall feed status previews, or owner gchat statements — those frequently reflect provisional state that gets walked back. If `time_mitigated` is empty/null, the SEV is NOT mitigated regardless of in-thread inferences; render as `"upstream SEV S<id> status=In Progress (time_mitigated=empty per metadata)"`. Source: 2026-05-17 archive `high-2026-05-17-A2387001468469120.md` falsely claimed "S665163 mitigated 08:19 PDT" based on thread inference; re-check 2026-05-18 03:25 PT showed `time_mitigated` still empty and m878102693 re-fired 30h later confirming SEV never resolved. Operator-flagged thread `hzYfILxPOi0` 2026-05-18 06:23 PT.

   e. **Build digest record** (in memory, not posted yet):
      - identity: {short_id, signal_class, priority, title, opened, cleared, duration}
      - assigned_user (from feed)
      - resolution_signal (from step 6.d)
      - signal_slice (from step 6.c, for archive only — do NOT include in digest text)
      - hypothesis (from ot-alert-monitor's diagnosis if cached in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-alert-state.json` for this short_id; else "[no real-time triage on file — diagnosis from postmortem only]")
      - mitigation (what the assignee did — extract from any threaded gchat reply on the original ot-alert-monitor notification; else "[unknown]")
      - source_oncall (the rotation that owns the alert — `mrs_online_training` for v1's single-rotation scope; surfaces the operational owner without per-product guessing). Per 2026-05-13 design change (operator in spaces/AAQAVOjYc80 thread yO-CQRIsrlQ): drop the hardcoded "OT escalation" lookup; if triage is good, the escalation is clear from surfaced data.
      - degraded: true/false (true if resolution_signal=acked_only OR any required field missing)

   f. **Pattern triage** — read `known-patterns.md` ONCE per run. For each non-degraded digest, classify:
      - **PATTERN MATCH**: cause→symptom→fix triple already in Quick-Match Table → record `{kind: "match", existing_pid: "P<n>", short_id}`.
      - **PATTERN PROPOSAL**: novel triple → record `{kind: "propose", proposed_pid: "P<next>", short_id, name, stage, symptoms, fix, owner, time_to_apply, source: alert, falsifier}`.
      - **DEGRADED**: skip pattern emit, note `{kind: "skip_degraded", short_id}`.

   g. **Write archive file** — durable per-alert record:
      - Path: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/<YYYY-MM>/<priority>-<YYYY-MM-DD>-A<short_id>.md` (mkdir -p the YYYY-MM dir).
      - Contents (markdown) — **restructured 2026-05-17 thread `Uc-pVBEXNQ8` to add verdict/class header + bot-thread URL + cluster citation + recurrence/sibling evidence + scoped ODS query**:
        ```
        # A<short_id> — <title>

        - **Verdict:** <NO_ACTION|MONITOR|PAGE|UNKNOWN|OUT_OF_SCOPE>
        - **Class:** <REAL_OT_FAILURE|UPSTREAM_INFRA|TRANSIENT_NOISE|THRESHOLD_MISFIT|DETECTOR_BROKEN|MISCONFIG_AGG|NEEDS_INVESTIGATION>
        - **Cluster:** <CL-NNN per failure-patterns.md, or `(none — propose new cluster)`>
        - **P-row:** <P<NN> per known-patterns.md, or `(no P-row match)`, or `(no P-row match — P<NN> falsifier failed: <reason>)`>. **FALSIFIER-RESPECT (added 2026-05-17 thread `Uc-pVBEXNQ8` 11:02 PT after backfill exposed P58 cited despite failed falsifier):** before citing a P-row, READ its Verify+Falsifier sections in known-patterns.md. If the alert evidence fails the falsifier (e.g., P58 requires active ZippyDB SEV but none active during fire window), DOWNGRADE class to `NEEDS_INVESTIGATION` and render `(no P-row match — <P-row> falsifier failed: <one-line reason>)`. Symptom-shape match alone is NOT sufficient to cite a P-row.
        - **Bot triage thread:** <markdown-linked gchat thread URL where ot-alert-monitor posted the live diagnosis, if any — grep `meta google.chat list-messages spaces/AAQAVOjYc80` for messages from last 24h mentioning the alert_id; if not found, render `[no live triage on file]`>
        - **Identity:** signal_class=<x>, priority=<critical|high|medium|low|unknown>, assigned_user=<x>, source_oncall=<x>, opened=<iso>, fired=<iso>, cleared=<iso>, duration=<x>, model_id=<x>, model_type_name=<x>
        - **Resolution signal:** <from step 6.d — recovered / acked_only / unverified, with timestamp>

        ## Timeline
        - HH:MM UTC — fired
        - HH:MM UTC — assigned to <user>
        - HH:MM UTC — cleared
        - <other events from gchat / comments>

        ## Underlying signal slice (±5 min around fired_time)
        ```
        <signal_slice from step 6.c — use MODEL-SCOPED query NOT entity-only: `meta ods.metric query --entity=<entity> --key=<key> --constraint model_id=<MODEL_ID> --start=<fired-5m> --end=<fired+5m>`. If query fails or returns 0 rows even with model_id scope, set `[ods/scuba: 0 rows even with model_id=<X> scope]` and continue — do NOT report unscoped failure (operator's earlier critique 2026-05-17 thread `Uc-pVBEXNQ8` flagged unscoped `entity too broad` errors)>
        ```

        ## R20 — same-workload recurrence (last 30d on this model)
        <output of `meta sevmanager.sev list --title-contains="<MODEL_ID>" --created-after="30 days ago" --limit=10 -o table` PLUS `meta monitoring.alert list --alert-contains="<MODEL_ID>" --state-is=CLEARED --start-time=$(date -d '30 days ago' +%s) --limit=10` PLUS local-archive sweep (see below). If 2+ prior incidents with same mitigation → `[VERIFIED: model_<MODEL_ID> prior_incidents=<N>, last_3=[S<a>, S<b>, S<c>], common_mitigation=<one-liner>]`. If 0 prior → `[VERIFIED: model_<MODEL_ID> prior_incidents=0]`. Per R20.>

        **R20 local-archive sweep (added 2026-05-17 thread `Uc-pVBEXNQ8` 11:10 PT after operator: "you should not only search SEVs, but also check the local tracking"; **extended 11:18 PT after backtest revealed missing exclusions + missing mega-learnings sweep**):** in addition to `meta sevmanager.sev list` (SEVs, 180d+ retention) and `meta monitoring.alert list` (alerts, <30d retention), ALSO sweep local sources for prior model_id references:

        ```bash
        # 4 sources of local prior-incident evidence
        grep -lr "<MODEL_ID>" \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/ \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/ \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/ \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/digests/ \
          2>/dev/null | \
          grep -v "$(basename "$current_archive_path")" | \
          grep -vE "/(INDEX|README)\.md$"
        ```

        **Source priority + classification of hits:**
        - **mitigated-sevs/posts/alerts/<file>**: prior per-incident triage — most direct recurrence evidence
        - **auto-learnings/patterns/failure-patterns.md**: alert/sev/post cited as cluster EVIDENCE — first-class signal that bot ALREADY mapped this incident to a known CL-NNN. MUST surface this in R20 even if no per-incident archive exists
        - **auto-learnings/digests/<file>**: instance mentioned in week-level synthesis (lower priority signal but auditable)
        - **auto-learnings/patterns/<file>**: specialized topic catalog mention (e.g., sjd-coverage-map.md)
        - **EXCLUDE:** INDEX.md, README.md (auto-generated or metadata files — false positives surfaced in 11:18 PT backtest on model 2144816217 which counted INDEX as a hit)

        Format extended to:
        ```
        [VERIFIED: prior_SEVs=N (meta CLI); prior_alerts=N or unverified (retention<30d);
                   local_archives=[<file1>, <file2>] (N per-incident hits);
                   cluster_evidence=[<CL-NNN>, ...] (N citations in failure-patterns.md);
                   mega_learnings=[<weekly_file>, ...] (N week-level mentions)]
        ```

        If all four are 0, this is a genuinely first-time-bot-known incident on this model. If any are non-zero, surface them explicitly — operator should know whether the bot has prior context on this workload.

        Why this matters: (a) local archives survive OneDetection retention limits, (b) capture bot's prior verdict/cluster/P-row attribution, (c) cluster-evidence shows bot already promoted this incident to canonical knowledge, (d) operator's trust source > meta CLI's transient state. Backtest on model 878858380 (2026-05-17 11:18 PT) found: meta-CLI=1 SEV, alert-API=0 (retention), local-archives=3, cluster-evidence (per failure-patterns.md)=2 — local sources DOMINATED the signal.

        **R20 retention caveat (added 2026-05-17 11:02 PT):** OneDetection cleared-alert API retention is <30d. If `meta monitoring.alert list` returns 0 rows over a 30d window, that's NOT authoritative — it might be 0 OR may have been cleared too long ago to query. DISTINGUISH the two: `[VERIFIED: prior_SEVs=N; prior_alerts=unverified (API retention <30d); local_archives=N]` when alert-side is empty. Don't lump SEV + alert + local as `prior_incidents=0`.

        ## R21 — cross-workload sibling check (last 24h on model family)
        <extract model_type_name. Run `meta sevmanager.sev list --tags=mvai-online-training --in-progress --title-contains="<family_keyword>" --limit=5 -o table`. If ≥2 siblings same symptom → `[VERIFIED: family=<model_type_name>, sibling_alerts_24h=<N>, matching_cluster=CL-NNN]`. Per R21.>

        **R21 paired-variant gap (added 2026-05-17 11:02 PT):** R21 family-keyword regex MAY miss paired baseline/holdout siblings — they have different `model_id` but the SAME `model_type_name`. For models with `(baseline)` or `(holdout)` in the title, run `meta ai.model list --model-type-name=<model_type_name> --limit=10 -o table` to enumerate paired variants, then check each separately. If skipped, cite `baseline_variant_check=skipped` in the [VERIFIED:] line.

        ## Hypothesis (from real-time triage)
        <from step 6.e — cite ot-alert-monitor diagnosis if on file. MUST cite cluster CL-NNN + P-row P<NN> when applicable, per P-007 citation discipline.>

        ## Mitigation
        <actions taken — from threaded gchat reply or `[unknown]`. If matched to a P-row, cite verbatim `Apply P<NN>: <mitigation>`.>

        ## Confidence: 0.<X>
        <one-line justification: signal-verification outcome, hypothesis-data fit, validator outcome>

        ## References
        - Alert: <alert_X_url>
        - Related ods/scuba: <link if resolvable>
        - Cron transcript: <session JSONL path if available, else omit>
        ```
      - Store the absolute archive path as `archive_path` on the digest record.

   h. Add short_id to a local `to_persist` list (do NOT write state until step 11 succeeds).

7. **Post phase — ONE consolidated digest** to spaces/AAQAVOjYc80:

   a. **Top-line message** (no thread):
      ```
      🔔 [OT alert postmortem digest YYYY-MM-DD] N alert(s) cleared in last 24h: <alert_a_url|A<a>>, <alert_b_url|A<b>>, ... — see thread for digests.
      ```
      ⚠️ GChat auto-links bare `A<numeric_id>` to `intern/aip/project/details/<id>` which is INVALID. Always use explicit `<url|A<id>>` GChat link syntax for every A-number in any message — top-line AND threaded replies. (Operator-flagged thread `QqRxpjmc1xE` 2026-06-01, recurrence of prior report.)
      Capture returned thread id as `digest_thread`.

   b. **Threaded digest reply** (`digest_thread`) — concatenate all digests, separated by `---`. Per-alert format (compact, ~500 chars each):
      ```
      *<alert_X_url|A<short_id>>* | <signal_class> | <priority> | <duration> | assignee: @<assigned_user> | oncall: <source_oncall>
      • Title: <title>
      • Resolution signal: <one-line; flag ⚠ if acked_only>
      • Hypothesis: <one-line from real-time triage or "[postmortem only]">
      • Mitigation: <actions taken or "[unknown]">
      • Alert: <alert_X_url>
      • 📄 Archive: <archive_path>  ← @<assigned_user> please reply ✅ confirm or ✏️ correct
      ```
      Hard cap full reply at 3500 chars. If overflow, prioritize: identity line, resolution signal, archive link; truncate hypothesis/mitigation with `…` and append `(N items truncated — see archive)`.

   c. **Threaded pattern reply** (`digest_thread`) — only post if at least one PATTERN MATCH or PATTERN PROPOSAL exists. Format same as ot-daily-learning-mitigated-sevs step 9.c (proposals lead, matches follow). Pattern proposals consolidated for one-diff land.

8. **Validator pass — ONE for the whole digest.** Spawn independent agent via Agent tool with prompt:
   > "Validate this OT alert postmortem digest covering N alerts (A<a>, A<b>, ...). Re-read the threaded digest in spaces/AAQAVOjYc80 thread <digest_thread>. For each alert: independently fetch `meta oncall.feed describe --id=<id> -o json` and re-query the underlying ods/scuba signal for the latest 30 min. Verify: (a) the resolution_signal claim (recovered vs acked_only) matches current signal state, (b) any pattern proposal is genuinely NOT a duplicate of existing P-row in known-patterns.md (re-read fresh — do not trust my claim). Report per-alert: confirmed | discrepancies. Under 600 words total."

   **If subagent / Agent tool is unavailable** (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`): DO NOT spawn. Skip the validator step entirely and post a single follow-up: `🚫 Validator unavailable (no Agent tool in cron context); digest published unvalidated.` Set `validator_status: unavailable` in the HEARTBEAT_OK summary. Do NOT inline-recheck — inline recheck is self-consistency, not validation, and produces false confidence (operator feedback 2026-05-16 thread `fc2seBuCux8`).

   After validator returns, post **ONE** follow-up threaded reply (`digest_thread`):
   - All clean: `✓ Validator confirmed (N/N alerts)`
   - Some discrepancies: `⚠ Validator found discrepancies:` followed by per-alert bullet list.

9. Persist state: add all `to_persist` short_ids to `processed_ids`, update `last_run_epoch`, write state file. Respond HEARTBEAT_OK with summary `{alerts_processed: N, patterns_proposed: P, patterns_matched: M, validator_status: confirmed|discrepancies, archives_written: A, archive_root: ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/<YYYY-MM>/}`.

10. **Operational follow-ups (added 2026-05-17 thread `Uc-pVBEXNQ8`, scope narrowed thread `Uc-pVBEXNQ8` 10:25 PT critique).** AFTER digest + validator complete, scan per-alert records for OPERATIONAL asks that ot-knowledge-curation won't catch (curation is for cross-incident pattern detection; this step is for per-alert config issues). TWO categories only:

   a. **Invalid-detector follow-ups (per-alert).**
      - **Trigger:** alert title contains `[dead detector]` (OneDetection orphan-rule naming convention) OR alert raw payload's `resolution_signal` field contains `entity not found` / `detector returned no data` / similar.
      - **Falsifier:** if `meta monitoring.observer describe --observer-id=<id>` shows `state=enabled` AND `last_data_timestamp` within 24h → NOT dead, drop the proposal (false positive).
      - **Output (one line per matched alert):**
        ```
        🔧 Invalid detector: [observer <id>](<onedetection_observer_url>) — [A<short_id>](<alert_url>)
           Reason: <verbatim signal from trigger>
           Suggested: `meta monitoring.observer disable --observer-id=<id>`
        ```

   b. **Too-tight threshold follow-ups (per-alert).**
      - **Trigger:** alert auto-resolved within `cleared_time - fired_time < 2 × expected_metric_cadence` AND no `REAL_OT_FAILURE` class in this alert's archive AND model has ≥3 same-metric alerts in last 7d.
      - **Expected metric cadence source:** `meta ai.model.instance list --model-id=<id> --instance-type SNAPSHOT --limit=20 -o json` → compute median time-between-instances for the relevant snapshot_type. If unable to compute (no snapshots) → skip this alert (don't guess).
      - **Falsifier:** if model has even ONE alert in last 30d that escalated to `REAL_OT_FAILURE` on the same metric → threshold IS catching real issues sometimes; don't propose relaxation.
      - **Output (one line per matched alert):**
        ```
        🔧 Threshold too tight: [model <id>](<sevmanager_url>) metric <metric>
           Evidence: fired N× in 7d, each duration <p50_duration> (vs cadence <median_cadence>)
           Suggested: relax threshold by (current–p50)×2 OR move p95→p99
           Owner: <observer owner from meta monitoring.observer describe>
        ```

   **Categories REMOVED in 10:25 PT critique:**
   - (c) follow-up tasks for new recurring patterns → OVERLAPS with `ot-knowledge-curation` (nightly 23:00 PT) which is designed for cross-incident pattern detection + task proposals. Don't duplicate.
   - (d) suggested diffs → SAME overlap. `ot-knowledge-curation` already drafts diffs from cross-incident pattern detection.

   **Consolidated output:** post ONE threaded reply in `digest_thread`:
   - If both (a) and (b) have content: `📦 *Operational follow-ups*` header + 2 subsections
   - If only one has content: post that section, no header
   - If both empty: post `(no operational follow-ups today)` — ONE line, not two

11. **Chronic-noisy model surfacing (added 2026-05-17 thread `Uc-pVBEXNQ8`, threshold corrected thread `Uc-pVBEXNQ8` 10:25 PT critique).** Surface the Pareto: models generating disproportionate alert volume.

   - **Source:** scan `incidents/resolved-alerts/*/*.md` filenames (NOT a sqlite table — there's no `<alert_archive_index>` table; 10:25 PT critique caught the placeholder bug). For each file, parse `A<short_id>` from filename and `model_id` from the first line (title regex `model (\d+)` or similar). Group by model_id, count per-model alerts in last 7d.
   - **Threshold (corrected):** flag models in the TOP 3 by alert-count in last 7d AND with ≥3 alerts (drop floor: low-volume noise filtered). Flat `≥5` was operator-flagged as baseline-blind; top-3 is percentile-aware.
   - **Pre-publish lint applies:** markdown links throughout (RULES.md § URL validity).
   - **Output format:**
     ```
     📢 *Top-3 noisy models (last 7d)*:
     1. [model <id> <name>](<sevmanager_url>) — N alerts · top signal: <signal>×M · last: [<alert_id>](<url>) <Nh ago>
     2. ...
     3. ...
     ```
   - **If <3 models have ≥3 alerts each:** post `(no chronic-noisy models this week)` — ONE line. No subsection header.

   - **Persist to notes (added 2026-05-17 thread `EqcmJ7mZajk` after operator: "will you save this info in notes repo"):** ALSO prepend a row (newest first) under the `## Alerts` section of `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/noisy-trends.md` for each entry surfaced this run. Insert after the table header row, before existing data rows. Format:
     ```
     | <run timestamp PT> | <rank> | <model_id> (<model_type_name>) | <alert_count> | <signal_class breakdown> | <one-line notes: top cluster/P-row, owner> |
     ```
     If `(no chronic-noisy models)`, prepend ONE row: `| <run timestamp> | — | (no chronic-noisy models) | 0 | — | — |` so cron-runs are auditable.

Safety:
- If `meta oncall.feed list` query in step 2 fails, do NOT advance state. Brief error string (no HEARTBEAT_OK).
- If an alert's metadata fetch fails partway in step 6, mark digest entry `degraded=true` with "DEGRADED: <step>" marker; continue. Skip pattern emit for degraded entries. Still include in consolidated digest with degraded marker.
- If ods/scuba signal slice fetch (step 6.c) fails or times out (>30s), set `signal_slice="[ods/scuba fetch failed: <error>]"` and continue — do NOT mark digest degraded for this alone (slice is enrichment, not required).
- If resolution-signal verification (step 6.d) cannot query (no entity link OR query fails), set `resolution_signal="[unverified]"` and proceed — do NOT mark degraded; surface as `unverified` in digest.
- If archive write (step 6.g) fails (disk full, perms), set `archive_path="[write failed: <error>]"` on digest record and continue posting digest. Do NOT add the alert to `to_persist` so it'll be retried tomorrow. Surface in step 9 summary as `archives_failed: F`.
- Do NOT modify alert state. No re-acks, no comments, no rotation reassignments. Propose-only for pattern DB.
- **READ-ONLY meta-rule:** NEVER call any oncall.feed mutation, `meta workplace.comment create`, `meta sevmanager.comment create`, or any external-surface write. The ONLY exception is `meta sevmanager.sev update --add-tag=mvai-online-training` (carve-out reserved for ot-sev-monitor + ot-sev-tag-review). This cron does NOT need that carve-out. Operator clarified 2026-05-15.
- Cap 5 alerts per run. If >5 NEW candidates, process the 5 most recently cleared; remainder rolls into next day's run.
- If validator step (8) fails or times out, post `⚠ Validator pass failed to complete — digest unverified`. Persist state regardless.


## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)
