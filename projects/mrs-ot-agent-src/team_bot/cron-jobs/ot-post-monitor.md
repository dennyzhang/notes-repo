[ot-post-monitor cron] Poll the MRS Online Training Users Workplace group (id 1084744250286987, vanity mrs.ot) for new posts since last successful run, classify by lane, post notification + DEEP-TRIAGE diagnosis for each substantive post.

State file: /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json — `{"last_post_epoch": <int>, "processed_post_ids": {"<post_id>": <added_epoch_int>, ...}, "last_run_epoch": <int>}`. The `processed_post_ids` is a dict (post_id → epoch when first added to the set), NOT a bare list — required by the bounded-prune rule in step 3.d (the bare-list schema couldn't be pruned without a per-id timestamp). Time budget: ~5 min per substantive post. Out-of-scope and oncall_summary posts stay fast.

**Dedup model** — per-id set (`processed_post_ids`) is authoritative; `last_post_epoch` is a coarse pre-filter only. Same pattern as ot-sev-monitor (`diagnosed_ids`) and ot-alert-monitor (`diagnosed_ids`). Pre-2026-05-12 the cron used epoch-cutoff alone, which re-fired any post whose `effective_freshness_time` regressed under it (move-in/late-comment race) — caused 11 duplicate notifications for a single post (Jianhui Sun, 1218910203488316, 2026-05-12 00:01-06:29 UTC). Per-id dedup eliminates that class of bug.

Procedure:
1. Read state file. Extract `last_post_epoch` (coarse cutoff) and `processed_post_ids` (dict of post_id → added_epoch). If file missing/corrupt: default cutoff = (now - 600s), processed_post_ids = empty dict, create file fresh. **Migration:** if existing state file has `processed_post_ids` as a bare list (pre-2026-05-12 schema), upgrade in-place by mapping each id → `now()` (best available proxy for added_epoch since original timestamp is lost). Log the migration once.
2. Run: meta workplace.group activity-feed --group-id=1084744250286987 --columns=post_id,author,message,publish_time_epoch,url --sort-order=desc --limit=20 -o json
3. Determine each post's effective freshness time BEFORE filtering, so posts moved into the group with stale `publish_time_epoch` aren't dropped:
   a. Default `effective_freshness_time = publish_time_epoch`.
   b. For posts where `publish_time_epoch <= cutoff` (would be filtered out as stale), fetch comments via `meta workplace.comment list --post-id=<post_id> --output=json --no-truncate` and scan for the literal `#movebot` directive OR a `Move Bot` author. If present and the move comment's `time` > cutoff, set `effective_freshness_time = move_comment_time` — moved-in posts have stale `publish_time_epoch` but are fresh-to-this-group as of the move. Cache the fetched comment list keyed by post_id so step 5.a.1 can reuse it.
   c. Filter to posts with `effective_freshness_time > cutoff` AND `post_id NOT IN processed_post_ids`. Drop posts authored by "MyClaw" / "ot-bot" / yourself (avoid feedback loops). The per-id check is the strong dedup; the cutoff is just a pre-filter so we don't fetch comments for ancient posts on every poll.
   Gap context: post 1215710353808301 was moved via `#movebot` from MVAI Users at 14:27 PT, original `publish_time_epoch` was 11:14 PT — the prior step-3 filter (publish_time_epoch only) missed it. Per-id dedup (added 2026-05-12) handles re-fires from late comments and re-moves correctly: once a post_id is in `processed_post_ids`, it stays skipped regardless of comment churn.
   d. **Prune `processed_post_ids`**: drop entries where `now() - added_epoch > 14 days`. Fixed TTL based on insertion time — evaluable from stored data alone (no dependency on `effective_freshness_time` which is only computed transiently in 3.a/3.b). 14d > worst-case mrs.ot post lifecycle (typical = hours, longest observed = ~3d for stickied threads); aged-out post returning via re-move after 14d is a non-issue (extremely rare; will safely re-trigger as a fresh post). Pruning is bounded — set size = posts seen in last 14d × ~2 posts/day = ~30 entries steady-state.
   d.1. **For each post processed in step 5 below**: add to `processed_post_ids` as `{post_id: now_epoch}`. The added_epoch is the cron-tick time when the id was first written, NOT the post's `effective_freshness_time` — because freshness time isn't persistable (only the cron tick is observable from stored state).
4. If no new posts: update last_run_epoch to now, respond HEARTBEAT_OK and stop.
5. Otherwise, for each new post (oldest first, cap 5 per run):
   a. Fetch FULL post body via: meta workplace.post content --post-id=<post_id> --columns=author,time,body -o json. Activity-feed message is truncated at 80 chars; classification on truncated text misses real OT issues.
   a.1. **Fetch comments — MANDATORY** (was missing pre-2026-05-07; gap source: post 1215710353808301): if the comment list was already fetched and cached in step 3.b, reuse it; otherwise call `meta workplace.comment list --post-id=<post_id> --output=json --no-truncate`. Comments often contain root-cause diagnoses from peer agents (MoDA, Confucius), human follow-ups, and `#movebot` move records. Classification + diagnosis must consider BOTH body AND comments. If a peer agent (`MoDA`, `Confucius`, `🤖`) has already posted a root-cause comment, surface it in the diagnosis output (do NOT re-derive from scratch — cite the peer-agent finding and verify it).
   b. **Pre-skip:** If title (first line of body, stripped of leading # / *) starts with "Oncall Summary" (case-insensitive), classify as `oncall_summary` — send brief notification only, NO threaded triage reply (status posts, not asks). Advance state and continue.
   c. Send notification to spaces/AAQAVOjYc80 via gchat skill: "🛟 [OT post] <author>: <first 100 chars of body, no newlines> — <url>". Capture thread id.
   d. Classify lane against FULL body using these patterns, in order — first match wins:
      - `sev_id`         (95%): /\bS\d{6,}\b/
      - `mast_job_id`    (90%): /\bmvai-training-online-\d{8,}\b/
      - `mlhub_url`      (85%): /(?:fburl\.com|internalfb\.com)\/mlhub\/\S+/
      - `model_series`   (80%): /\bm\d{8,}\b/  OR  /(?:^|\s)-m\s+\d{8,}/
      - `workplace_post` (70%): /https?:\/\/(?:fb\.)?workplace\.com\/groups\/[^\/\s]+\/(?:permalink|posts)\/\d+/
      - `runbook_path`   (60%): /https?:\/\/(?:www\.)?internalfb\.com\/wiki\/\S+/
      - `paste`          (50%): /\bP\d{7,}\b/  — only when title contains OT-issue keyword
      - `diff`           (50%): /\bD\d{8,}\b/  — only when title contains OT-issue keyword
      - `ot_general`     (40%): no ID matched, but title contains OT-issue keyword (job, fail, error, train, snapshot, publish, OT, mvai, NaN, NCCL, timeout, restart, latency, QPS) — flag for human review
      - `out_of_scope`   (0%): nothing matched; not OT-flavored content
   e. DEEP TRIAGE — required for every lane EXCEPT `out_of_scope` and `oncall_summary`. Load `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/SKILL.md` if not loaded. Then execute:

      i. **Ground-truth verification.** Pull data that confirms or falsifies leading hypothesis. For `mast_job_id`/`mlhub_url`: `meta ai.mast-job metadata --name=<id>` + `meta ai.mast-job error --name=<id>` + `meta ai.mast-job attempts --name=<id>`. For `model_series`: `meta ai.model.instance list --model-id=<id> --limit=30 --sort-by=creation_time --sort-order=desc --columns=instance_id,creation_time,snapshot_type,state -o table`. For `sev_id`: `meta sevmanager.sev metadata --sev=<id>`. Lane match is OPENING of triage — falsify or confirm before publishing.

      i-c. **Read SEV live GChat — MANDATORY.** Metadata is a snapshot; GChat carries current state. Extract gchat_space_url, parse space ID (after /room/), `gchat read <space_id>` (~20 messages). Parse for active hypotheses, paste links, ETA, contradictions. Cite as `[VERIFIED via gchat read <space_id>]`. Source: 2026-05-02 S657811 — metadata said 'archiver restarted, awaiting catchup'; GChat showed ~150 versions need manual deletion, 'won't be solved till next week'.

      i-d. **MANDATORY trainer-liveness probe — BEFORE any D-class (publish) or E-class (DPP/QPS) hypothesis.** When the post symptom set includes ANY of: "snapshot stuck CREATING", "FS publish stalled", "missing SPARSE_DELTA/DENSE_DELTA", "DPP reader QPS ≈ 0", "low input QPS", "checkpoint cadence broken" — run the trainer-Python liveness probe FIRST: `meta scuba.dataset query -d mvai_metrics --view=samples --columns=time -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' --hours=12 -l 1 --order-by=time`. **If latest sample > 5 min stale AND MAST attempt status is RUNNING → the trainer Python interpreter is hung (P44/A1 GIL hang, or A2/A3 C++/storage stall depending on live process inspection)**; downstream stuck-CREATING snapshots and low DPP QPS are CONSEQUENCES, not roots. Do NOT propose D-class (TGIF, Hedwig, UMM publish) or E-class (DPP starvation) hypotheses until A is falsified by a fresh mvai_metrics sample. Cite verbatim: `[VERIFIED: mvai_metrics latest_sample=<timestamp>, gap_min=<N>, attempt_status=<S>]`. Source: 2026-05-13 model 2135033479 + 883552231 — first triages misdiagnosed both as TGIF/checkpoint_agent stuck. See `known-patterns.md` § Cause-vs-consequence map and P44.

      ii. **Active-SEV cross-reference.** Run `meta sevmanager.sev list --tags=mvai-online-training --created-after="3 days ago" -o json --limit=10`. For each open SEV with adjacent signal class (publish-related post + open publish-related SEV → likely shared infra), flag SEV id + link.

      ii-a. **R20 — SAME-WORKLOAD RECURRENCE (4-source).** Check the same model across 4 sources (extended 2026-05-17 thread `Uc-pVBEXNQ8` 11:18 PT per P-003):
         1. SEVs: `meta sevmanager.sev list --title-contains="<MODEL_ID>" --limit=20 -o json` (180d+ retention)
         2. Cleared alerts: `meta monitoring.alert list --alert-contains="<MODEL_ID>" --state-is=CLEARED --start-time=$(date -d '30 days ago' +%s) --limit=20` (<30d retention)
         3. Local archives: `grep -lr "<MODEL_ID>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs,posts,alerts}/ | grep -vE "/(INDEX|README|MISSING|NOISY-MODELS)\.md$"`
         4. Mega-learnings: `grep -lr "<MODEL_ID>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/digests/` — hits in failure-patterns.md = canonical CL-NNN already mapped (first-class signal)

         If 2+ prior incidents had same mitigation → short-circuit hypothesis. Cite: `[VERIFIED: model_<MODEL_ID> prior_SEVs=N; prior_alerts=N|unverified; local_archives=[...]; cluster_evidence=[<CL-NNN>, ...]; mega_learnings=[...]]`. Source: operator 2026-05-17 thread `r70kC-3eghA` + `Uc-pVBEXNQ8`.

      ii-b. **R21 — CROSS-WORKLOAD PATTERN.** After R20, check family for the same symptom: extract model_type_name; sweep `meta sevmanager.sev list --tags=mvai-online-training --in-progress --title-contains="<family_keyword>"`; map symptom to CL-NNN in `mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md`. 2+ sibling models same symptom 24h → family-wide escalation. Cite: `[VERIFIED: family=<model_type_name>, sibling_sevs_7d=<N>, matching_cluster=<CL-NNN or none>]`.

      iii. **Owner correction.** For `model_series`/`mast_job_id`/`mlhub_url`: run `meta ai.model-series metadata --model-id=<MODEL_ID>` (resolve job → model first). Compare against post author's ownership signal. If they differ, list BOTH: post author (asker) AND actual model owner (escalation target).

      iv. **Hypothesis chain.** Take leading pattern from known-patterns.md. State explicitly. Test against ground-truth from (i). If contradicted, falsify in writing and switch to secondary candidate. Repeat until standing hypothesis is data-consistent — or report "no known pattern matches; needs human investigation."
   v. **Quality rules** (SKILL.md + D103543146) — ALL must appear in every diagnosis:
      - **Baseline before anomaly**: cite known-good window for any "broken/slow/wrong" claim.
      - **Layered hypothesis enumeration**: name every layer; rule each in/out with data. No single-hypothesis diagnoses.
      - **Code-pointer mandatory**: every "fix X" cites file path + line number.
      - **Tiered recommendations**: SHORT (≤1 day, config flip) / MEDIUM (≤1 week, cross-team) / LONG (weeks+, refactor).
      - **Soft cross-references include verification step**: "if X upstream of Y" cross-refs MUST include verification command BEFORE contingent action.

   v.1. **R18 HARD pre-publish gate — diagnosed-stage scope re-check.** AFTER quality rules pass and BEFORE the diagnosis is published as a Workplace reply, classify the diagnosed root cause's pipeline stage: T1 (DPP / Scribe ingestion), T2 (training: trainer process, NCCL, OOM, GIL hang, schedule/PG), T3 (publishing: TGIF / GMPP / SilverTorch publish path / fbpkg / FS publish), T4 (serving: ICSP / RAAS / Multifeed / predictor config), or out-of-pipeline (model-lifecycle: launch gate, decommission, solver_mode). **If diagnosed stage is T4 (serving) or out-of-pipeline, do NOT publish the OT-routed diagnosis as a Workplace reply.** The asker may still be in scope (Workplace post in mrs.ot group), but the diagnosis itself names a stage owned by a different team — redirect explicitly: "This is a <stage>-stage issue (<owner>); routing there." Tag-based routing (post hit OT lane via group membership) is necessary but NOT sufficient — the diagnosed root cause is the authoritative scope signal. **Falsifier**: diagnosed stage is T1/T2/T3 → publish full diagnosis. Source: 2026-05-13 S661843 (sibling SEV cron mis-routed serving-stage SEV to OT lane). See R18 in `references/triage-discipline.md`.

   vi. **Diagnosis output template** — three appendix sections after standing hypothesis + recommendations. ALL MANDATORY:
      - **Raw log Evidence appendix** (lettered A, B, C...): literal log lines + timestamps + ranks. Hypothesis cites inline (e.g., "NE stalled 22:03→22:40 [Evidence D, F]").
      - **Investigation Commands appendix** (numbered): replayable `meta` / `tw log` commands. For `tw log`, see `references/tw-log-recipes.md` (D103543146).
      - **Files-touched table**: `| path | 1-line role |` for any "fix in X" recommendation.
      Source: 2026-04-30 velvinfu paste P2300957350.

      For `paste`/`diff`/`ot_general` low-confidence lanes: still run (i)+(ii) but be explicit lane match is weak — frame diagnosis as research starting point, not verdict.

   f. Send threaded reply using **crisp 5-element template** per [`human-input-generic/report-templates/crisp-report-style.md`](../../human-input-generic/report-templates/crisp-report-style.md). Workplace posts in `mrs.ot` are CROSS-TEAM facing; verbose 9-section output goes to a paste, NOT the post body.

      **Step f.1 — Create paste FIRST with LOCKED verbose format (2026-05-16).** Mirrors `ot-alert-monitor` / `ot-sev-monitor` so `ot-daily-learning-debugging` parses all three crons with one parser. Operator feedback 2026-05-16 thread `6pKeH_XqjcE`: "shouldn't we also update the post monitor one?" — yes.

      Paste content uses the same fixed 9-section template + verdict header + JSON block:

      ```
      [ot-bot verbose diagnosis | <post permalink>]

      <VERDICT HEADER LINE — 🟢/🟡/🔴/⚪ ACTION · root-cause: <status> · class: <class> · confidence: <level>>

      *Lane*: <lane> (X%) | post author: <unixname>

      *Model*: <id> (<name>) | pg: <PG> | role: <model_role> | owner: <unixname> / <oncall>
        — OR — (no model in post) —
      *Subject*: <one-line description of the artifact: paste/diff/runbook/SEV/etc.>

      *What happened*: <one paragraph. names exact metric/snapshot-type/symptom that's breaking; for delta symptoms name SPARSE_DELTA vs DENSE_DELTA vs FULL_SNAPSHOT EXPLICITLY — do NOT lump together; user-visible breakage; concrete metric values; timestamps>

      *Evidence*:
      • <fact 1> [VERIFIED via <cmd>]
      • <fact 2> [VERIFIED via <cmd>]
      • <fact N — include any cross-SEVs as evidence bullets>

      *Hypothesis & implication*: <surviving cause + what it implies for the operator. Single paragraph.>

      *Ruled out*:
      • <hypothesis> — <contradicting fact + source>

      *Cross-SEVs*: (folded into Evidence bullets above as of 2026-05-17 restructure)

      *Next actions*:
      1. <action with owner + concrete command>

      📊 Machine fields: <paste_url>

      **JSON moves to paste (added 2026-05-17 thread `SN72CzuckRQ` after operator: "do I really need to see it as a human?").** Build the JSON object (schema below), pipe through `pastry -t "$POST_ID-machine-fields" --md`, embed the resulting URL in the gchat message as `📊 Machine fields: $PASTE_URL`. ALSO include the full JSON in `raw_response` (sqlite job_runs) so downstream consumers that scrape sqlite still work.

      **CONTENT-lint (MANDATORY, 2026-05-17 thread `suPsRC2fGdc`):**
      - R20 ran with N>0 prior incidents → Evidence MUST include `[VERIFIED: model_<ID> prior_incidents=`.
      - R21 ran with matching_cluster!=none → Evidence MUST include `[VERIFIED: family=<model_type_name>`.
      - **CL-NNN citation MANDATORY** when symptom matches a known cluster (failure-patterns.md). Cite by ID in Evidence + Hypothesis & implication.
      - **P-row citation MANDATORY** when symptom matches a known P-row (known-patterns.md). Cite as `Apply P<NN>: <mitigation>` in Next actions.
      Same gap as ot-alert-monitor + ot-sev-monitor; live triage on 878858380 at 10:18 PT 2026-05-17 (thread `akCTORdwUK4`) did the work but didn't cite catalog entries.

      JSON schema (rendered in paste, not gchat):
      ```json
      {
        "verdict": "<NO_ACTION|MONITOR|PAGE|UNKNOWN|OUT_OF_SCOPE>",
        "class": "<enum value>",
        "root_cause_status": "<known|partial|not_found>",
        "confidence": "<high|medium|low>",
        "auto_resolved": <true|false>,
        "post_id": "<id>",
        "post_lane": "<lane from step d>",
        "post_author": "<unixname>",
        "pg": "<IG|Threads|Video|Facebook|infra-cross-pg|Ads|other|unknown>",
        "model_id": "<id or null>",
        "model_name": "<full name from meta ai.identify, e.g. facebook_reels_ifu_mtml_v0, or null>",
        "model_lane": "<ranking|retrieval|unknown>",
        "model_role": "<trainer|stus|unknown>",
        "owner": "<unixname>",
        "oncall": "<oncall name>",
        "signal_specifics": {
          "metric_class": "<snapshot|data_age|scribe_lag|latency|detector_no_data|other>",
          "metric": "<e.g. SPARSE_DELTA cadence, checkpoint_training_data_age_mins>",
          "affected_snapshot_types": ["SPARSE_DELTA"],
          "healthy_snapshot_types": ["DENSE_DELTA", "FULL_SNAPSHOT"]
        },
        "ruled_out": ["<hypothesis 1 (P-row or R-rule id)>", "<hypothesis 2>"],
        "related_sevs": ["S<id>"],
        "validator_status": "pending"
      }
      ```

      **Compatibility for downstream JSON consumers:**
      - **`raw_response` (sqlite job_runs)** still contains the full JSON block as a code-fenced section after the narrative. `ot-postmortem-validator`, `ot-knowledge-curation`, `ot-cron-health-watch`, `ot-human-attention-brief` all read from `raw_response` — NO change to them.
      - **Validator updates** edit the PASTE content (via `pastry <paste_id>` overwrite), NOT the gchat message. Paste link stays stable.
      - **Fallback:** if `pastry` fails or times out (>10s), inline the JSON in the gchat message with `⚠️ paste creation failed` prefix.

      ## Evidence appendix (lettered A/B/C):
      <verbatim log lines, timestamps, ranks>

      ## Investigation Commands appendix (numbered):
      <replayable meta / tw log commands>

      ## Files-touched table:
      <path | role>   (omit ENTIRELY if no code-fix proposed)
      ```

      **Verdict header rules** (same as alert/sev monitors):
      - `🟢 NO ACTION` — false positive OR auto-resolved with known benign cause
      - `🟡 MONITOR` — self-resolving in progress OR upstream infra issue tracked elsewhere
      - `🔴 PAGE <owner>` — real failure requiring human
      - `⚪ UNKNOWN` — root cause not found; deeper investigation needed
      - `🚫 OUT-OF-SCOPE` — R18 stage-drop; single-line, no further diagnosis

      **`class` enum** (same v1 enum as alert/sev): `THRESHOLD_MISFIT` / `DETECTOR_BROKEN` / `MISCONFIG_AGG` / `TRANSIENT_NOISE` / `UPSTREAM_INFRA` / `REAL_OT_FAILURE` / `CONVEYOR_REGRESSION` / `ZOMBIE_SEV` / `NEEDS_INVESTIGATION`.

      **`confidence` rubric**: `high` = ground-truth ✓ + ≥2 ruled-out hypotheses. `medium` = ground-truth ✓ + 1 ruled-out. `low` = ground-truth incomplete OR no ruled-out OR pattern-match only.

      **`model_name` derivation**: from `meta ai.identify --query=<MODEL_ID>` or `meta ai.model-series metadata --model-id=<MODEL_ID>` — the actual series name, e.g. `facebook_reels_ifu_mtml_v0`. **CRITICAL anti-pattern (2026-05-16):**
      - `model_name` is the SERIES NAME — NEVER substitute owner unixname, oncall name, model_id, or any other identifier. Source: 2026-05-16 thread `-7JtEC9JAGw` where cron emitted `"model_name":"shuyaoli"` (the owner) for model 2144816217.
      - `owner` is the unixname — populated separately from `model_name`.
      - If `meta ai.identify` returns empty or errors, render `model_name: "unknown"` rather than substituting a different identifier.

      NEVER substitute a derived label.

      Create the paste:
      ```bash
      meta paste.paste create --content="<above template>" --language=text --title="ot-bot diagnosis: <symptom> on <model_or_job>"
      ```

      Capture the returned paste id (e.g., `P2315669002`).

      **Step f.2 — Render the threaded reply in crisp style** (5 elements, ~6-7 lines, under 600 chars body — unchanged from prior):

      ```
      # [OT triage] <job-id-or-model> (<class>) — <symptom> at <when>

      **PROBLEM**: <one sentence + 1-2 supporting numbers — last-good timestamp, gap duration>

      **LIKELY CAUSE**: <one sentence + path:line code-pointer per Quality Rule R3. If unverified, prefix `[INFERRED]` and omit the code-pointer.>

      Detail reporting: [P<paste_id>](https://www.internalfb.com/intern/paste/P<paste_id>)

      **ASK**: <one sentence — who needs to do what; page-tag if specific>
      ```

      **Step f.3 — Drop the prefix.** Do NOT prefix the reply with `[ot-bot diagnosis | confidence: X%]` or `[ot-bot | confidence: ... | suggested owner: ...]`. These are internal-debug noise on external-facing surfaces.

      **Cap**: ~600 chars body, 1000 chars hard cap. If the diagnosis genuinely needs more, expand the paste, not the post. For low-confidence lanes (paste / diff / ot_general): the LIKELY CAUSE line gets `[INFERRED]` prefix + add a sixth line: `Note: lane match weak — diagnosis is research starting point, not verdict.`

      End ALWAYS with: `Post: <url>` on its own line (existing rule preserved for traceability).

   g. **VALIDATOR PASS** (skip for `out_of_scope` and `oncall_summary` lanes) — spawn independent agent via Agent tool with prompt: "Validate this OT post triage. Re-read diagnosis I just published in spaces/AAQAVOjYc80 thread <thread_id>. Independently run ground-truth queries diagnosis cites. Cross-check standing hypothesis against actual data. Report: (a) confirmed | (b) discrepancies + what data contradicts what. Under 300 words. Do NOT see my reasoning, only the published diagnosis."

      **In-place update of the paste, NOT new gchat message.** After validator returns, EDIT the paste created in step f.1: replace `*Validator*: ⏳ pending` with `*Validator*: ✓ confirmed` or `*Validator*: ⚠ <discrepancy>`. Also update the JSON block field `"validator_status"` from `"pending"` to `"confirmed"` / `"discrepancy: <one-liner>"`. Use `meta paste.paste update --paste-id=<id> --content=...`. Avoids the two-message-with-30s-gap pattern that skimmers miss. Source: 2026-05-16 operator feedback thread `6pKeH_XqjcE`.

      If subagent / Agent tool is unavailable (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`), DO NOT spawn the subagent. Update the paste's validator field to: `*Validator*: 🚫 unavailable (no Agent tool in cron context)`. JSON: `"validator_status": "unavailable"`.

   h. Update state file IMMEDIATELY after validator pass completes:
      - Append `post_id` to `processed_post_ids` (the strong dedup — survives comment/move-in churn).
      - Set `last_post_epoch = max(last_post_epoch, effective_freshness_time)` (NEVER regress; use the freshness time, not raw publish_time_epoch — moved-in posts must advance the cutoff past the move time, not the original publish time, otherwise the next run re-evaluates them as fresh).
6. After loop: update last_run_epoch to now. Respond with HEARTBEAT_OK + per-post summary line that **MUST include the bot's posted gchat thread URL AND the workplace post URL** (for ot-human-attention-brief link extraction):

   ```
   HEARTBEAT_OK

   ---

   **Run summary** (posts processed: N):

   **W<id>** — <verdict_line>
   - Bot reply: https://chat.google.com/room/AAQAVOjYc80/<thread_id>
   - Workplace post: https://fb.workplace.com/groups/mrs.ot/permalink/<id>/
   ```

   Mandatory; operator-flagged 2026-05-17 thread `Y3qbdh2hC20`.

Safety:
- If meta workplace.group activity-feed fails (non-zero exit AND no valid JSON), do NOT advance state. Brief error string (no HEARTBEAT_OK).
- If single post's deep triage fails partway, send partial diagnosis with "DEGRADED: <step> failed" marker. Continue.
- Cap at 5 posts per run.
- **READ-ONLY on Workplace.** NEVER call `meta workplace.comment create`, `meta workplace.post resolve`, `meta workplace.post create`, or any `workplace.*` mutation. NEVER react to a Workplace post or comment. Triage output is delivered to the GChat lane only; the operator decides whether to mirror to Workplace. Operator clarified 2026-05-15 after this cron posted comment 1326221096139300 on Rudra Barua's mrs.ot post ("OT Not Creating New Checkpoints") — see CLAUDE.md § Never Do for the canonical rule.

## Learned Rules (auto-appended)

1. [2026-04-29] Exit code 143 (SIGTERM) from `meta workplace.group activity-feed` with valid JSON returned should be treated as success — advance state normally. The meta CLI sometimes terminates with SIGTERM on completion. Only abort if no valid JSON was produced.
2. [2026-04-29 manual] Lane patterns expanded: added `mlhub_url`, `model_series`, `paste`, `diff`, `ot_general`, `oncall_summary`. Backtest on Apr 26-29 posts showed strict `mvai-training-online-\d+` missed 3 real OT issues. Activity-feed message field is truncated at 80 chars — classification must run on full body via `meta workplace.post content`. Oncall Summary posts must be skip-routed.
3. [2026-04-29 manual] Pattern-match output is the OPENING of triage, not the conclusion. Always run ground-truth verification (snapshot timeline, mast job state, related SEVs) before publishing diagnosis. Sourced to ifu_lsr alert (model 883552231) where P01 (FULL_SNAPSHOT blocking deltas) was diagnosed but snapshot timeline showed no FULL_SNAPSHOT in flight — P01 falsified.




## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)
