[ot-daily-learning-mitigated-sevs cron] Daily 9 PM PT. Harvest postmortem signal from OT SEVs that closed/mitigated in last 24h (the *mitigated SEVs* corpus), surface in team space as ONE consolidated digest, write one durable archive file per SEV, propose pattern entries for `known-patterns.md`. Strictly propose-only — no SEV state mutations. ot-sev-monitor catches SEVs as they OPEN; this catches them after CLOSE. Daily cadence (not hourly) because postmortem text takes hours-to-days to populate. Renamed from `ot-sev-postmortem` 2026-05-12 to clarify input corpus and pair with sibling `ot-daily-learning-debugging` (real-time triage output).

**Output shape (post-2026-05-12 consolidation): ONE top-line message + ONE threaded reply with all digests + ONE pattern-proposal threaded reply + ONE validator threaded reply + ONE chronic-noisy reply, PLUS one archive file per SEV.** Total 4-5 GChat messages per run regardless of SEV count. Archive files are durable artifacts (do not count as messages). If a run has 0 NEW SEVs: HEARTBEAT_OK, no posts, no archive writes.

**Archive scheme** (per OT Master Agent doc § Data model — "one mitigated issue one file"): `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/<YYYY-MM>/L<level>-<YYYY-MM-DD>-S<num>.md`. Directory created if missing. File survives log-rolloff (5-min MAST log slice captured durably) and is referenced from the digest line so the operator + SEV owner can click through to confirm.

**UPSERT by sev_num (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` stub-pollution audit):** before writing a new archive, GLOB for any existing file matching the same sev_num across all months: `ls ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/*/*-S<num>.md`. If a file exists for the same sev_num AND the existing file is larger / has more triage detail (proxy: size > 1500 bytes vs new content < 1500), DO NOT write a new stub — the existing rich postmortem supersedes. If new content is richer (size > existing), OVERWRITE the existing path (do NOT create a new filename with a different level prefix). Avoids the cross-source stub-pollution pattern.

**Stub-content guard (added 2026-05-17, ported from alerts):** if all of `Root cause`, `Mitigation`, `Resolution signal` would be written as `[postmortem field empty]` / `[unknown — verify with owner]` / `[gchat: ...]` placeholders, DO NOT write the file at all — the archive adds zero signal. Wait for the next mitigation cycle when richer postmortem text is available.

State file: ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-mitigated-sevs-state.json — `{"processed_ids": ["S<number>", ...], "last_run_epoch": <int>}`. Time budget: ~5 min per SEV. Cap 5 SEVs per run. Note: state file co-located with archive output dir per OT Master Agent doc convention (option ii unified, 2026-05-12). Renamed from `ot-postmortem-state.json` at the same time. Stale state file at `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-postmortem-state.json` is left in place (operator can copy contents over on first run, or accept a one-time re-process of any in-flight processed_ids — bounded by the 24h window).

Procedure:

1. Read state file. Extract processed_ids. If file missing/corrupt, treat as empty set.

2. Find SEVs that closed in last 24h with OT tag:
   ```
   meta sevmanager.sev list --tags=mvai-online-training --closed-after="24 hours ago" \
     --columns=sev_number,level,title,owner_unixname,status,sev_type,closed_time,url -o json --limit 50
   ```
   Also pull broader title-class set as backstop (catches SEVs the auto-tag missed):
   ```
   meta sevmanager.sev list --closed-after="24 hours ago" \
     --columns=sev_number,level,title,owner_unixname,status,sev_type,closed_time,url -o json --limit 100  # --closed-after implies closed; no --status flag needed (per validator 2026-05-17: Resolved is not a valid status value)
   ```
   For second query, filter to titles matching:
   /(mvai|online[._-]?train|publish(?!er)|TGIF|snapshot|delta|streaming|hedwig|silvertorch|gmpp|ifu[._-]?lsr|MRS[._-]?OT|mtml|NCCL|model.age|ATS|scribe.lag)/i

3. Union both sets, dedupe by sev_number → candidate set.

4. **Scope check via `scope_check` capability — MANDATORY** (same single-source-of-truth as ot-sev-monitor; do not inline regex):
   ```bash
   meta sevmanager.sev metadata --sev=S<id> -o json | \
       buck2 run -q fbcode//pe_mrs_ml/mrs_ot_agent:scope_check -- --stdin
   ```
   Drop any candidate where `in_scope=false`. Add to processed_ids silently — DO NOT post any "out of scope" closure note. The 2026-04-30 S657101 leak happened via closure-note channel.

4.5. **Strict OT-title post-filter — MANDATORY (added 2026-05-17 thread `6i0LDKZxIR8` after 36-SEV false-positive backfill).** `scope_check` has a known leak: the `sev_type=Instagram admitted by default` path (step 7) admits any Instagram SEV regardless of title. Many Instagram SEVs are serving / publish-flow / snapshot-deployment incidents, NOT online training. **For SEV archive writes specifically** (this cron writes DURABLE per-SEV files; false positives accumulate in `incidents/resolved-sevs/`), apply a stricter post-filter AFTER `scope_check`:

   ```python
   import re
   KEEP_REGEX = re.compile(
       r'\b('
       r'online[ _]+train(?:ing)?'                       # "online training", "online_training", "online_train"
       r'|online[ _]+training[ _]+(?:job|qps|model)'      # "online training job/qps/model"
       r'|mvai-training-online-'                          # explicit MAST job prefix
       r'|\bOT[ _\-]?(?:job|jobs|model|models|training)\b'  # "OT job", "OT model"
       r'|teacher[ _]model.*online'                       # "teacher model ... online"
       r')',
       re.IGNORECASE
   )
   EXCLUDE_REGEX = re.compile(
       r'(cogwheel_|cogwheel.failure|cogwheel.test|^[^]]*\b(cogwheel|silvertorch_test|light_cli.*build|light_cli.*test|Tag fbpkgs)\b)',
       re.IGNORECASE
   )
   # SEV passes only if KEEP_REGEX matches AND EXCLUDE_REGEX does NOT match
   if not (KEEP_REGEX.search(title) and not EXCLUDE_REGEX.search(title)):
       skip_silently()  # add to processed_ids, do NOT archive, do NOT digest
   ```

   **Why this filter exists:** operator validated 36/36 against this rule (thread `6i0LDKZxIR8`). Per operator: *"If the SEV has `mrs_ml_release_oncall` tag, this is highly unlikely to be OT SEV, unless the SEV page has 'online' keywords."* Generalized: an OT SEV's title MUST have an explicit `online training` / `OT job` / `mvai-training-online-` keyword. Anything else — serving SEVs, publish-flow SEVs, snapshot-deployment SEVs, inference-error SEVs, cogwheel/release-pipeline SEVs — is MVAI or sibling-team scope.

   **TODO (separate diff):** propagate this filter upstream into `fbcode//pe_mrs_ml/mrs_ot_agent/src/capabilities/team_lane_scope.py` by tightening the `sev_type=Instagram admitted by default` path to require a positive title match. Currently kept as a cron-side post-filter to avoid breaking other crons that depend on the more permissive admit. See `auto-learnings/deep-dives/ot-sev-scope-rejections.md` for the 57-SEV regression fixture.

5. Filter to SEVs whose sev_number is NOT in processed_ids → NEW candidates.

6. Prune processed_ids: drop IDs older than 14 days (re-opened SEV gets re-processed).

7. If no NEW candidates: persist state, update last_run_epoch, respond HEARTBEAT_OK and stop. **No posts.**

8. **Gather phase** — for each NEW candidate (cap 5 per run), collect data into an in-memory list `digests`. DO NOT post per-SEV during this phase. For each:

   a. **Pull full postmortem fields** via `meta sevmanager.sev metadata --sev=S<id> -o json --no-truncate`. Extract: root_cause, remediation, prevention, contributing_factors, follow_up_tasks (with owners + status), duration, impacted_areas, tags (verify mvai-online-training present; if not, came in via title-class — note it).

   b. **Read live SEV gchat thread — MANDATORY.** Postmortem text often partial; closing discussion has the real story. Same pattern as ot-sev-monitor: extract gchat_space_url, parse space ID (after /room/), `gchat read <space_id>` (~30 messages). Look for: contradicting hypotheses, post-mortem corrections, action-item ownership disputes, "the real cause was X" reveals not in structured fields.

   c. **URL sourcing — MANDATORY pre-fetch.** Capture SEV URL as literal variable:
      ```bash
      meta sevmanager.sev metadata --sev=S<id> -o json | jq -r .url
      ```
      Store as e.g. `s657811_url = "https://www.internalfb.com/sevmanager/view/657811"`. NEVER write literal `<url>` token, bare sev_number, or fabricated string. If empty, render `<url-unavailable>`.

   d. **Signal-class label** — pull from `signal_class` field of scope_check JSON (step 4). Valid values: `mvai_publish_pipeline` | `mvai_serving` | `mrs_online_training`. Do NOT default to `mrs_online_training` — conflates OT-coordination scope with actual failure domain (S658476, 2026-05-03).

   e. **Extract model_id (for R20/R21 sweeps).** Try in order: (1) MAST job name regex `mvai-training-online-(\d+)`, (2) SEV title regex `\b(\d{8,})\b`, (3) postmortem body grep for `model_id=(\d+)` or `model (\d+)`, (4) gchat thread grep for same. If none found, set `model_id=null` and skip R20/R21 (they require a workload key).

   f. **Build digest record** (in memory, not posted yet):
      - identity: {sev_num, signal_class, level, title, sev_type, opened, closed, duration, model_id, model_type_name (if available)}
      - root_cause (verbatim if short, summarized if long; cite if partial: "[postmortem field empty — sourced from gchat]")
      - remediation
      - prevention
      - contributing_factors (bullet list)
      - followup_tasks (numbered with owner + status; flag OPEN tasks tagged for OT-adjacent owner)
      - gchat_additions (anything from gchat that contradicts/extends structured fields; tag `[VERIFIED via gchat read <space_id>]`)
      - source_oncall (from SEV metadata `oncall_short_name`, OR `oncall` from `meta ai.mast-job metadata` if a MAST job is named — surfaces the operational owner without per-product guessing). Per 2026-05-13 design change: drop the hardcoded "OT escalation" lookup; if triage is good, the escalation is clear from surfaced data.
      - sev_owner (from metadata)
      - degraded: true/false (true if any required field missing; do NOT emit pattern proposal for degraded entries)

   g. **Pattern triage** — read `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/how/known-patterns.md` ONCE per run (not per SEV). **Compute next P-id from the file, not by counting** — gaps exist in the sequence (P29, P35 are reserved/skipped):
      ```bash
      NEXT_PID=$(grep -oE '^\| P[0-9]+ ' ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/how/known-patterns.md \
          | grep -oE '[0-9]+' | sort -n | tail -1 | awk '{printf "P%02d\n", $1+1}')
      ```
      For each non-degraded digest, classify:
      - **PATTERN MATCH**: cause→symptom→fix triple already in Quick-Match Table → record `{kind: "match", existing_pid: "P<n>", sev_num}`.
      - **PATTERN PROPOSAL**: novel triple → record `{kind: "propose", proposed_pid: "<NEXT_PID>", sev_num, name, stage, symptoms, fix, owner, time_to_apply, source, falsifier}` then increment NEXT_PID by 1 for the next proposal in the same run. Use `name ≤40 chars`, `stage ∈ {T1,T2,T3,T4}`, `falsifier` = single command/check that disproves this pattern.
      - **DEGRADED**: skip pattern emit, note `{kind: "skip_degraded", sev_num}`.

      **FALSIFIER-RESPECT (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` 11:02 PT):** for any PATTERN MATCH candidate, READ the cited P-row's Verify+Falsifier sections in known-patterns.md. If the SEV evidence FAILS the falsifier (e.g., P58 requires active ZippyDB SEV but none active during this SEV's window), DOWNGRADE to `NEEDS_INVESTIGATION` class and render `(no P-row match — P<NN> falsifier failed: <one-line reason>)`. Symptom-shape match alone is NOT sufficient.

      **Why grep, not count:** the cron previously suggested "P40" when grepping would have returned "P39" (P39 was already taken by an MAST-PENDING pattern). Counting from apparent last row produced an off-by-one Phabricator merge conflict. Grepping is cheap and authoritative — caught 2026-05-12 in K_OE73Id8g4 thread.

   h. **Pull MAST error log slice — for archive only.** If the SEV metadata (or gchat) names a MAST job (`mvai-training-online-*` family — see ot-agent-conventions.md scope rule), capture ±5 min around `time_started`:
      ```bash
      meta ai.mast-job error --name=<job> --since=<t_started_minus_5min_iso> --until=<t_started_plus_5min_iso>
      ```
      Store as `log_slice` (verbatim, ≤4KB; truncate middle with `[…N lines elided…]` marker if longer). If no MAST job linked, store `log_slice="[no MAST job linked to this SEV]"`. Out-of-scope job prefixes (aps-*, fire-*, torchx-*, conda-*) → store `log_slice="[out-of-MRS-OT-scope job: <prefix>]"` and skip fetch.

   i. **Write archive file** — durable per-SEV record:
      - Path: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/<YYYY-MM>/L<level>-<YYYY-MM-DD>-S<num>.md` (mkdir -p the YYYY-MM dir).
      - Apply UPSERT + stub-content guards from the top of this prompt FIRST.
      - Contents (markdown) — **restructured 2026-05-17 (ported from alerts thread `Uc-pVBEXNQ8`) to add verdict/class header + bot-thread URL + cluster citation + recurrence/sibling evidence**:
        ```
        # S<num> — <title>

        - **Verdict:** <MITIGATED|MITIGATED_WITH_FOLLOWUP|INCOMPLETE_POSTMORTEM|OUT_OF_SCOPE>
        - **Class:** <REAL_OT_FAILURE|UPSTREAM_INFRA|TRANSIENT_NOISE|THRESHOLD_MISFIT|DETECTOR_BROKEN|MISCONFIG_AGG|NEEDS_INVESTIGATION>
        - **Cluster:** <CL-NNN per failure-patterns.md, or `(none — propose new cluster)`>
        - **P-row:** <P<NN> per known-patterns.md, or `(no P-row match)`, or `(no P-row match — P<NN> falsifier failed: <reason>)` per FALSIFIER-RESPECT>
        - **Bot triage thread:** <markdown-linked gchat thread URL where ot-sev-monitor posted the live diagnosis, if any — grep `meta google.chat list-messages spaces/AAQAVOjYc80` for messages mentioning the sev_num; if not found, render `[no live triage on file]`>
        - **Identity:** signal_class=<x>, level=<L>, sev_type=<t>, owner=<sev_owner>, source_oncall=<x>, opened=<iso>, mitigated=<iso>, closed=<iso>, duration=<x>, model_id=<x|null>, model_type_name=<x|null>
        - **Resolution signal:** <metric proving issue mitigated; pull from postmortem if stated, else infer from gchat closure (e.g., "ATS latency back to baseline", "freshness ≤ threshold", "alert cleared >30m"). If unknown: "[unknown — verify with owner]">

        ## Timeline
        - HH:MM UTC — opened
        - HH:MM UTC — mitigated
        - HH:MM UTC — closed
        - <other events from gchat / postmortem>

        ## MAST error log slice (±5 min around time_started)
        ```
        <log_slice from step 8.h>
        ```

        ## R20 — same-workload recurrence (last 30d on this model)
        <if model_id is null, render `[skipped — no model_id extractable]`. Else run `meta sevmanager.sev list --title-contains="<MODEL_ID>" --created-after="30 days ago" --limit=10 -o table` PLUS `meta monitoring.alert list --alert-contains="<MODEL_ID>" --state-is=CLEARED --start-time=$(date -d '30 days ago' +%s) --limit=10` PLUS local-archive sweep below.>

        **R20 local-archive sweep (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` 11:18 PT):** in addition to meta CLI queries (SEVs 180d+, alerts <30d retention), sweep local sources for prior model_id references across 4 corpora:

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

        **Source priority + classification:**
        - **mitigated-sevs/posts/alerts/<file>**: prior per-incident triage — most direct evidence
        - **auto-learnings/patterns/failure-patterns.md**: cited as cluster EVIDENCE — first-class signal that bot ALREADY mapped this workload to a known CL-NNN
        - **auto-learnings/digests/<file>**: week-level synthesis mention (lower priority, auditable)
        - **auto-learnings/patterns/<file>**: specialized topic catalog mention
        - **EXCLUDE:** INDEX.md, README.md (auto-generated; false positives)

        Format:
        ```
        [VERIFIED: prior_SEVs=N (meta CLI); prior_alerts=N or unverified (retention<30d);
                   local_archives=[<file1>, <file2>] (N per-incident hits);
                   cluster_evidence=[<CL-NNN>, ...] (N citations in failure-patterns.md);
                   mega_learnings=[<weekly_file>, ...] (N week-level mentions)]
        ```
        If all four are 0, this is genuinely first-time-known. **R20 retention caveat:** if alert-side is empty, render `prior_alerts=unverified (API retention <30d)`, NOT `prior_alerts=0` — don't lump into `prior_incidents=0`.

        ## R21 — cross-workload sibling check (last 24h on model family)
        <if model_type_name unavailable, render `[skipped — no model_type_name on record]`. Else run `meta sevmanager.sev list --tags=mvai-online-training --created-after="24 hours ago" --title-contains="<family_keyword>" --limit=5 -o table`. If ≥2 siblings same symptom → `[VERIFIED: family=<model_type_name>, sibling_sevs_24h=<N>, matching_cluster=CL-NNN]`. Per R21.>

        **R21 paired-variant gap (added 2026-05-17, ported from alerts):** family-keyword regex MAY miss paired baseline/holdout siblings — different `model_id`, same `model_type_name`. For models with `(baseline)` or `(holdout)` in the title, run `meta ai.model list --model-type-name=<model_type_name> --limit=10 -o table` to enumerate paired variants, check each separately. If skipped, cite `baseline_variant_check=skipped`.

        ## Root cause
        <verbatim or summarized; cite source: "[postmortem field]" or "[gchat verbatim]". **Citation discipline (P-007):** if a cluster (CL-NNN) or P-row (P<NN>) applies, CITE inline — `Matches CL-013 (presto-snapshot false alarm) via P58 (after FALSIFIER-RESPECT)`.>

        ## Mitigation
        <actions taken. If matched to a P-row that passed FALSIFIER-RESPECT, cite verbatim `Apply P<NN>: <mitigation>`.>

        ## Confidence: 0.<X>
        <one-line justification: data quality, postmortem completeness, validator outcome>

        ## References
        - SEV: <sev_url>
        - Diffs blamed/fixed: <list or "none cited">
        - Cron transcript: <session JSONL path if available, else omit>
        ```
      - Store the absolute archive path as `archive_path` on the digest record so the digest line in step 9.b can render `📄 <archive_path>` for owner click-through.

   j. Add sev_number to a local `to_persist` list (do NOT write state until step 11 succeeds).

9. **Post phase — ONE consolidated digest** to spaces/AAQAVOjYc80:

   a. **Top-line message** (no thread):
      ```
      📓 [OT SEV postmortem digest YYYY-MM-DD] N SEV(s) closed in last 24h: S<a> L<x>, S<b> L<y>, ... — see thread for digests.
      ```
      Capture returned thread id as `digest_thread`.

   b. **Threaded digest reply** (`digest_thread`) — concatenate all digests, separated by `---`. Per-SEV format (compact, ~600 chars each):
      ```
      *S<num>* | <signal_class> | L<level> | <duration> | owner: @<sev_owner> | oncall: <source_oncall>
      • Verdict: <verdict> · Class: <class> · Cluster: <CL-NNN|none> · P-row: <P<NN>|none>
      • Title: <title>
      • Resolution signal: <one-line metric proving mitigation>
      • Root cause: <root_cause or [empty — gchat: <gchat_additions one-liner>]>
      • Remediation: <remediation>
      • Prevention: <prevention>
      • Contributing: <bullets joined with `; `>
      • Followups: <numbered, OPEN flagged with ⚠>
      • SEV: <sev_url>
      • 📄 Archive: <archive_path>  ← @<sev_owner> please reply ✅ confirm or ✏️ correct
      ```
      Hard cap full reply at 3500 chars (well under 4096 GChat limit). If overflow, prioritize: (1) identity + verdict line, (2) root cause, (3) remediation; truncate prevention/contributing/followups with `…` and append `(N items truncated — see SEV link)`.

   c. **Threaded pattern reply** (`digest_thread`) — only post if at least one PATTERN MATCH or PATTERN PROPOSAL exists. Format:
      ```
      🧠 PATTERN PROPOSALS / MATCHES (N proposed, M matched)

      *Proposals* (review + land via one diff to known-patterns.md):
      - P<next>  <name>  | T<stage>  | source: S<num>
        symptoms: <list>
        fix: <command/diff/wait verdict>
        owner: <team>  | apply: <wallclock>
        falsifier: <command>
      - P<next+1> ...

      *Matches* (occurrence count helps prioritize pattern attention):
      - S<num> postmortem confirms P<existing>
      - ...
      ```
      Pattern proposals are intentionally consolidated — operator lands them as ONE diff to `known-patterns.md` (covers "one day one diff" preference). DO NOT spawn per-pattern diffs.

10. **Validator pass — ONE for the whole digest** (replaces prior per-SEV validator). Spawn independent agent via Agent tool with prompt:
    > "Validate this OT SEV postmortem digest covering N SEVs (S<a>, S<b>, ...). Re-read the threaded digest in spaces/AAQAVOjYc80 thread <digest_thread>. For each SEV: independently fetch `meta sevmanager.sev metadata --sev=S<id>` and re-read its gchat thread. Verify across the digest: (a) root cause / remediation / prevention quoted accurately, (b) follow-up task lists complete, (c) any pattern proposal is genuinely NOT a duplicate of existing P-row in known-patterns.md (re-read fresh), (d) any P-row CITED passes its falsifier per FALSIFIER-RESPECT — re-check the falsifier against fresh data. Report per-SEV: confirmed | discrepancies. Under 600 words total."

    **If subagent / Agent tool is unavailable** (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`): DO NOT spawn. Skip validator entirely and post a single follow-up: `🚫 Validator unavailable (no Agent tool in cron context); digest published unvalidated.` Set `validator_status: unavailable` in HEARTBEAT_OK. Do NOT inline-recheck (operator feedback 2026-05-16 thread `fc2seBuCux8`).

    After validator returns, post **ONE** follow-up threaded reply (`digest_thread`):
    - All clean: `✓ Validator confirmed (N/N SEVs)`
    - Some discrepancies: `⚠ Validator found discrepancies:` followed by per-SEV bullet list.

11. Persist state: add all `to_persist` sev_numbers to `processed_ids`, update `last_run_epoch`, write state file. Respond HEARTBEAT_OK with summary `{sevs_processed: N, patterns_proposed: P, patterns_matched: M, validator_status: confirmed|discrepancies|unavailable, archives_written: A, archives_skipped_stub: K, archive_root: ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/<YYYY-MM>/}`.

12. **Chronic-noisy model surfacing (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` step 11).** Surface the Pareto: models generating disproportionate SEV volume.

    - **Source:** scan `incidents/resolved-sevs/*/*.md` filenames + first-line title for `model_id`. Group by model_id, count per-model SEVs in last 7d.
    - **Threshold:** flag models in TOP 3 by SEV-count in last 7d AND with ≥2 SEVs (drop floor — SEVs are rarer than alerts, ≥2 already meaningful).
    - **Pre-publish lint applies:** markdown links throughout (RULES.md § URL validity).
    - **Output format** (threaded reply in `digest_thread`):
      ```
      📢 *Top-3 chronic-SEV models (last 7d)*:
      1. [model <id> <name>](<sevmanager_url>) — N SEVs · top class: <class>×M · last: [S<num>](<url>) <Nd ago>
      2. ...
      3. ...
      ```
    - **If <3 models meet threshold:** post `(no chronic-SEV models this week)` — ONE line, no header.
    - **Persist to notes:** prepend a row (newest first) under the `## SEVs` section of `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/noisy-trends.md`. Insert after the table header row, before existing data rows. Format:
      ```
      | <run timestamp PT> | <rank> | <model_id> (<model_type_name>) | <sev_count> | <class breakdown> | <one-line notes: top cluster/P-row, owner> |
      ```
      If `(no chronic-SEV models)`, prepend ONE row: `| <ts> | — | (no chronic-SEV models) | 0 | — | — |` so cron-runs are auditable.

Safety:
- If both `meta sevmanager.sev list` queries fail in step 2, do NOT advance state. Brief error string (no HEARTBEAT_OK).
- If a SEV's metadata fetch fails partway in step 8, mark that digest entry `degraded=true` with "DEGRADED: <step>" marker; continue. Skip pattern emit for degraded entries. Still include in consolidated digest with degraded marker.
- If MAST log fetch (step 8.h) fails or times out (>30s), set `log_slice="[MAST log fetch failed: <error>]"` and continue — do NOT mark digest degraded for this alone (log is enrichment, not required).
- If R20/R21 local-archive sweep grep fails or times out (>30s), set that section to `[sweep failed: <error>]` and continue — do NOT block archive write.
- If archive write (step 8.i) fails (disk full, perms), set `archive_path="[write failed: <error>]"` on the digest record and continue posting the digest. Do NOT add the SEV to `to_persist` so it'll be retried tomorrow. Surface failed archives in step 11 summary as `archives_failed: F`.
- If UPSERT guard skips a write (existing archive richer), surface in summary as `archives_skipped_existing_richer: K` AND still add to_persist (don't re-process tomorrow).
- If stub-content guard skips a write, surface as `archives_skipped_stub: K` AND do NOT add to_persist (let next cycle try with richer postmortem text).
- Do NOT modify SEV state. No tag changes (ot-sev-tag-review's job). No comments. No status changes. Propose-only for pattern DB.
- **READ-ONLY meta-rule:** NEVER call `meta sevmanager.comment create`, `--resolve`, level/narrative edits, or any sevmanager mutation. The ONLY external write permitted is `meta sevmanager.sev update --add-tag=mvai-online-training` (carve-out reserved for ot-sev-monitor + ot-sev-tag-review). This cron does NOT need that carve-out.
- Cap 5 SEVs per run. If > 5 NEW candidates, process the 5 most recently closed; remainder rolls into next day's run.
- If validator step (10) fails to spawn or times out, post `⚠ Validator pass failed to complete — digest unverified` in `digest_thread`. Persist state regardless.


## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)
