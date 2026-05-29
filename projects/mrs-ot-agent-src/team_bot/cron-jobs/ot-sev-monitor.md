[ot-sev-monitor cron] Hourly. Identify NEW SEVs the mrs_online_training oncall is "looped into" (tagged OR title-class-matched), cluster by shared root cause, post one notification + deep-triage diagnosis per cluster, then independent validator pass. The OMH-style `oncall.feed` query is too narrow — misses cross-team SEVs like S654315 (mvai_ifr_main publish failure).

State file: /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-sev-state.json — `{"diagnosed_ids": {"S<number>": {"added_epoch": <int>, "notification_outcome": <string>}, ...}, "last_run_epoch": <int>}` (v3 schema, 2026-05-27 T273158617 Fix 7 — see migration in step 1). Pre-v3 legacy: bare list `["S<number>", ...]` (v1). Time budget: ~5 min per cluster.

**`notification_outcome` schema (v3, same as ot-post-monitor / ot-alert-monitor).** One of: `POSTED:<msg_resource_name>` (notification sent + threaded reply created), `OOS:<reason>` (out-of-scope; e.g. `OOS:serving_stage_T4`, `OOS:preemptive_launch`), `DEDUP:<source>` (handled by another path), `ERROR:<one-line>` (send failed). State advance with `notification_outcome` absent OR starting with `ERROR:` keeps the entry but flags it for `ot-cron-health-watch` class 6 audit (silent-drop detection).

Procedure:
0. **Concurrent-run guard (2026-05-27).** Before reading state, acquire run lock:
   ```bash
   LOCKFILE="/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-sev-monitor.lock"
   LOCK_MAX_AGE=3600
   NOW=$(date +%s)
   if [ -f "$LOCKFILE" ]; then
     LOCK_TIME=$(cat "$LOCKFILE" 2>/dev/null || echo 0)
     LOCK_AGE=$((NOW - LOCK_TIME))
     if [ $LOCK_AGE -lt $LOCK_MAX_AGE ]; then
       echo "[ot-sev-monitor] Another instance running (lock age=${LOCK_AGE}s). Exiting."
       exit 0
     fi
     echo "[ot-sev-monitor] Stale lock (age=${LOCK_AGE}s). Proceeding."
   fi
   echo "$NOW" > "$LOCKFILE"
   ```
   Release lock as the LAST action in step 10 after writing state: `rm -f "$LOCKFILE"`
1. Read state file. Extract `diagnosed_ids`. If file missing/corrupt, default to empty dict.

   **Migrations (idempotent, run all):**
   - v1→v3: if `diagnosed_ids` is a bare list, upgrade to dict-of-dict by mapping each id → `{"added_epoch": now_epoch, "notification_outcome": "LEGACY_UNKNOWN"}` (original timestamp lost; LEGACY_UNKNOWN marks the visibility gap until next real send).
   - Field access (post-migration): `diagnosed_ids[<sev_id>].added_epoch` and `.notification_outcome`. Anywhere this prompt previously did `if sev_id in diagnosed_ids` (set semantics) still works (dict key check). Anywhere it iterated `diagnosed_ids` as a list MUST switch to `diagnosed_ids.keys()`.

2. Run TWO queries in parallel:
   (A) meta sevmanager.sev list --tags=mvai-online-training --in-progress --columns=sev_number,level,title,owner_unixname,status,created,url -o json --limit 50
   (B) meta sevmanager.sev list --in-progress --created-after="3 days ago" --columns=sev_number,level,title,owner_unixname,status,created,url -o json --limit 100

2.5. **Cold-start backfill (2026-05-16).** If `last_run_epoch` is missing OR `(now - last_run_epoch) > 12*3600`: also run query (A') in parallel — same as (A) but adding `--mitigated-after=<last_run_or_24h_ago>` to capture SEVs that mitigated during bot downtime. Source: 2026-05-16 cross-space thread — S664106 was tagged `mvai-online-training` and mitigated ~16h before this instance's first run, so query (A) returned 0 because `--in-progress` excludes Mitigated; the bot never triaged it. The catch-up window covers bot-startup-after-reinstall, devserver-reinstall, and post-restart scenarios.

   For SEVs surfaced ONLY via the (A') backfill query (mitigated, not in active candidate set): add to `diagnosed_ids` without triage (already mitigated; nothing to do). Log line `cold-start backfill: added <N> mitigated SEVs to diagnosed_ids` in HEARTBEAT_OK summary.

3. From (B), filter to titles matching this OT signal-class regex (case-insensitive — intentionally lossy on inclusive side, deep-triage filters false positives):
   /(mvai|online[\s._-]?train|publish(?!er)|TGIF|snapshot|delta|streaming|hedwig|silvertorch|gmpp|ifu[._-]?lsr|MRS[._-]?OT|mtml|NCCL|model.age|ATS|scribe.lag)/i

   **Regex history:** the `online[\s._-]?train` cluster was widened 2026-05-16 (was `online[._-]?train`) after S664106 "Threads Feed teacher model 2128461099 **online training** cannot get started" wasn't matched because the title used a literal SPACE separator. Without the `\s` widening, no-tag SEVs with space-separated `online training` in title fall through.

4. Union (A) + (A' if run) + filtered (B), dedupe by sev_number → candidate set.

4.5. **Scope check via `scope_check` capability — CRITICAL, runs BEFORE notification.** Single source of truth — see `fbcode/pe_mrs_ml/mrs_ot_agent/src/capabilities/team_lane_scope.py`. Do NOT inline regex.

   For each candidate:
   ```bash
   meta sevmanager.sev metadata --sev=S<id> -o json | \
       buck2 run -q fbcode//pe_mrs_ml/mrs_ot_agent:scope_check -- --stdin
   ```

   Output: `{"sev_id": "...", "in_scope": bool, "rationale": "...", "signal": "tag"|"title"|"ic"|"owner"|"sev_type"|null}`. If `in_scope == false`: drop IMMEDIATELY (no notification, no diagnosis, just add to diagnosed_ids). Allowlist-based: Production sev_type requires positive MRS marker. Future tightening goes in capability + `tests/test_team_lane_scope.py`. Run in parallel; ~3-5s per call.

5. Filter candidates whose sev_number is NOT in diagnosed_ids → NEW SEVs.

6. Prune diagnosed_ids: drop IDs not in current candidate set (closed/out-of-scope SEVs forgotten so re-open re-triggers).

6.5. **Re-evaluation pass for diagnosed SEVs (2026-05-01 Problem 2 fix; expanded 2026-05-27 for stack-tag).** For each id in diagnosed_ids ∩ current candidate_set: fetch `meta sevmanager.sev metadata --sev=S<id> -o json`. (a) If `mvai-online-training` NOT in tags AND scope_check returns `in_scope=true`: apply primary auto-tag (per step 9.e). (b) **STACK-SPECIFIC RE-TAG (T273158617 Fix 8 follow-up):** if the SEV is in `diagnosed_ids` with a recorded `training_stack=SILVERTORCH` (look up from the prior diagnosis JSON in `raw_response`) AND `mrs-online-training-silvertorch` NOT in tags: apply the secondary tag. Silent re-tag, log only — DO NOT send any chat output.

7. If no NEW SEVs: persist pruned state, update last_run_epoch, respond HEARTBEAT_OK and stop.

8. CLUSTER NEW SEVs by likely shared root cause: same model id (`\b\d{8,}\b` in title) + same primary signal class (publish/NCCL/OOM/training/serving) + within 4 hours.

9. For each cluster (cap 3 per run):

   **ORDERING NOTE (2026-05-16):** Run step 9.b deep triage FIRST. Only after R18 (step 9.b.v.2) and the silent-drop backstop (step 9.b.v) both pass should step 9.a notification fire. Rationale: notifying before stage classification produced user-facing noise — see S659877 (2026-05-16 07:20–07:22 PT in spaces/AAQAVOjYc80) where a T4 serving-tier IGML capacity SEV produced a 🚨 main-space notification at 07:20 and then a `[OUT-OF-SCOPE: T4 serving-stage]` retraction at 07:22. The R18 gate worked as designed but fires too late in the flow. Execute order: 9.b → 9.b.v → 9.b.v.1 → 9.b.v.2 (R18) → if T4/out-of-pipeline, drop and emit single-line `[OUT-OF-SCOPE]` only; else 9.a notification → 9.c threaded diagnosis → 9.d validator → 9.e auto-tag → 9.f state update.

   a. Send notification to spaces/AAQAVOjYc80:
      Singleton: "🚨 [OT SEV | <signal_class>] L<level> S<num>: <title> — <owner_unixname> — <url>"
      Multi: "🚨 [OT SEV cluster | <signal_class> | N SEVs] L<highest level>: <shared signal class> — owners: <distinct unixnames>. First: S<num> <url>"

      **Send-discipline — capture msg name from API response (T273158617 Fix 4 + 2026-05-27 hardening).** Use the separated-stderr + exit-code-gated pattern (DO NOT use `2>&1` — stderr deprecation warnings break jq parse and produce false-ERROR; DO NOT use `2>/dev/null` on jq — silent parse fail hides bugs):
      ```bash
      ERR_TMP=$(mktemp)
      NOTIF_STDOUT=$(meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --as-meta-bot --text="$NOTIF_TEXT" -o json 2>"$ERR_TMP")
      NOTIF_EXIT=$?
      NOTIF_STDERR=$(cat "$ERR_TMP"); rm -f "$ERR_TMP"
      if [ "$NOTIF_EXIT" -ne 0 ]; then
        NOTIFICATION_OUTCOME="ERROR:notif_send_exit_${NOTIF_EXIT}:$(echo "$NOTIF_STDERR" | head -c 160)"
        NOTIF_NAME=""; THREAD_ID="SEND_FAILED"
      else
        NOTIF_NAME=$(echo "$NOTIF_STDOUT" | jq -er '.name' 2>&1) || {
          NOTIFICATION_OUTCOME="ERROR:notif_parse_failed:$(echo "$NOTIF_NAME" | head -c 100)|stdout=$(echo "$NOTIF_STDOUT" | head -c 60)"
          NOTIF_NAME=""; THREAD_ID="SEND_FAILED"
        }
        if [ -n "$NOTIF_NAME" ]; then
          THREAD_ID=$(echo "$NOTIF_STDOUT" | jq -er '.thread' 2>/dev/null | awk -F/ '{print $NF}')
          NOTIFICATION_OUTCOME="POSTED:$NOTIF_NAME"
        fi
      fi
      echo "[ot-sev-monitor] cluster=$CLUSTER_ID outcome=$NOTIFICATION_OUTCOME thread=$THREAD_ID"
      ```
      **Structural URL gate (T273158617 Fix 5, 2026-05-27).** Bot reply URL in the run summary is **rendered conditionally**: emit `- Bot reply: https://chat.google.com/room/AAQAVOjYc80/$THREAD_ID` **only if `$THREAD_ID` is non-empty AND not `SEND_FAILED`**. Otherwise emit literal `- Bot reply: SEND_FAILED (outcome=$NOTIFICATION_OUTCOME)`. Never synthesize a thread ID. Persist `$NOTIFICATION_OUTCOME` per SEV in step 9.f state update so silent-drop class can't recur. Anti-pattern: ot-post-monitor run #6517 fabricated `yF_aMB00xMk` thread URL while send had silently failed (T273158617).

      **Signal-class label sourcing — MANDATORY.** Pull `<signal_class>` from `signal_class` field of scope_check JSON (step 4.5). Multi-SEV clusters share by construction. Valid values:
        - `mvai_publish_pipeline` — cogwheel/TGIF/conveyor/lowering/publish
        - `mvai_serving` — vanguard/predictor/serving_eval/sigrid
        - `mrs_online_training` — actual training-path (sparse stream stopped, MAST down, NaN NE, NCCL, OOM)
      Source of truth: `team_lane_scope.classify_signal_class()`. Substitute the actual value, never write literal `<signal_class>` token. Source: 2026-05-03 S658476.

      **URL sourcing — MANDATORY pre-fetch.** BEFORE rendering ANY notification/diagnosis with `<url>`, run for every SEV:
      ```bash
      meta sevmanager.sev metadata --sev=S<id> -o json 2>/dev/null | jq -r .url
      ```
      Store as Python-style variable (e.g., `s654315_url = "https://..."`), render via literal substitution. NEVER write template literal `<url>` or bare sev_number. Pre-render checklist: any `— S\d+$` or `— SEV \d+$` at line ends → URL hallucination, re-render. If fetch returned empty, render literal `<url-unavailable>`. Mandatory because soft fallback rule was ignored across S651844, S656875, S656725, S656729.

   b. DEEP TRIAGE per SKILL.md "Triage Discipline":
      i. Ground-truth — `meta sevmanager.sev metadata --sev=S<id>`. If title references model id: `meta ai.model-series metadata --model-id=<ID>` + `meta ai.model.instance list`.

      **i-pre. MODEL-ID GUARD — NEVER infer model_id when SEV title is plural or unspecific.** Before any model-specific triage step (R14, R15, liveness probe, kill recommendation), check whether the SEV body or title contains an explicit `model_id` / `<MODEL_ID>` / `mvai-training-online-<id>` reference. **If title uses plural form (`jobs`, `models`, `trainers`, `OT jobs hanging`) AND no explicit model_id appears in title or body → STOP. Classify verdict as `AWAITING_CONTEXT` with note: "SEV title is plural; owner must populate model IDs before triage proceeds".** DO NOT infer model_id from the owner's MAST job inventory, recent activity, or owned-model list — that's a guess, not a verification, and PAGE-with-kill recommendations on a guessed model are trust-breaking. Owner adds model_id → re-triage next cron pass. **Source: 2026-05-18 thread `fw2PCj3Z_Zo` — SEV S665478 ("reels lsr mb9 OT jobs hanging", no model_id in title/body) triggered two concurrent cron triages that inferred *different* model sets (one cited m2141016310, the other m2123154171+m2123153585). The first triage recommended `meta ai.mast-job kill --name=mvai-training-online-2141016310 --version=15` based on a 7h-mvai_metrics-gap claim, but re-verification showed mvai_metrics samples continuous (12:56 PT, 0-min gap) — m2141016310 was healthy. Acting on the recommendation would have killed 96 B200 GPUs on a healthy production trainer.** This R-rule prevents the entire class of failure.

      **i-pre.b. QE-MODEL INFRA-VS-MODEL DISAMBIGUATION (MANDATORY when SEV is on a QE / launch-candidate model).** When the SEV title or body indicates the affected model is a QE / launch-candidate (suffix `_qe`, `_lc`, `mb9_qe`, MB-launch-blocker context, etc.), the disambiguation question is: **infra-side (would also break prod baseline) or model-side (specific to this QE's code changes)?** Follow `ot-alert-monitor.md` step i-a.4 (same two-check procedure: (1) prod-baseline-parallel liveness check, (2) sibling recurring-flow check). **Verdict routing depends on outcome — model-side roots get routed to model owner, NOT MRS-OT infra. Cite the disambiguation check verbatim in evidence.** Source: operator guidance 2026-05-18.
      i-0. **R14 — JOB-ROLE check via entrypoint, BEFORE any role-specific hypothesis.** When the SEV references a `mvai-training-online-<MODEL_ID>` job, run `meta ai.mast-job metadata --name=mvai-training-online-<MODEL_ID> | grep -oE '"entrypoint":"[^"]*"'` FIRST. If entrypoint contains `st_update_service` → classify as STUS publish job (NOT trainer). Trainer-side hypotheses (in-process scheduler, NCCL, OOM, step counter) are FALSE for STUS jobs. Find the upstream root model from the recurring flow's `MVAI_MODEL_IDS=root:X,st:<MODEL_ID>` and pull root's snapshot timeline separately (per R11). Cite the entrypoint string verbatim: `[VERIFIED: entrypoint=<path>, role=<trainer|stus>]`. Source: 2026-05-08 — STUS-vs-trainer mistake hit 3x in one session.

      i-0a. **MANDATORY upstream-infra-SEV check — BEFORE investigating GMPP/TGIF internals.** When the STUS job shows 0 QPS or publish stall (R14 entrypoint confirms `st_update_service` role), check for active ZippyDB/Scribe/LogDevice SEVs FIRST:
         ```bash
         meta sevmanager.sev list --in-progress -o json --limit 50 | \
           grep -iE "zippy|scribe|logdevice"
         ```
         **If hit → P50** (external-dep publish stall). STUS publish path depends on Scribe → ZippyDB; in-trainer models are unaffected (they publish directly to UMM). Route to infra oncall (ZippyDB/Scribe/LogDevice), NOT OT oncall. Verify by confirming in-trainer models on the same tier are publishing normally. Cite verbatim: `[VERIFIED: upstream_infra_sev=S<id>, stus_qps=0, in_trainer_qps=normal]`. Source: S660220 (ZippyDB SEV1, 2026-05-06) — 3 STUS models 0 QPS for ~7h, 1 in-trainer model unaffected. See `known-patterns.md` § Failure-Mode Taxonomy.

      i-0b. **R15 — RECURRING-FLOW enablement check, BEFORE blaming downstream symptoms.** When the symptom is "trainer not producing checkpoints" / "publish stalled" / "FULL_SNAPSHOT gap" / "fire-app expired", VERIFY the recurring flow that drives the trainer is enabled FIRST. (1) Get root trainer model id (per R11/R14). (2) Run `meta ai.model metadata --model-id=<ROOT_ID> | grep owner_unixname`. (3) `meta ai.recurring-job recurring-flows --owner=<owner> --no-truncate | grep <flow_keyword>` and locate the flow. (4) Check `is_enabled` column. **If `false` → THAT is the root cause; do NOT propose P17 / fire-app rebuild / STUS skip / GMPP backpressure as root cause — those are consequences.** Cite verbatim: `[VERIFIED: recurring_job_id=<id>, is_enabled=<true|false>]`. Source: 2026-05-08 m2133142909 / m2133154105 — bot blamed P17 fire-app expiry; operator manually found recurring flow 8921769 (`threads_feed_esr_prod`, owner chengchengyuan) was disabled.

      i-0c. **MANDATORY trainer-liveness probe — BEFORE any D-class (publish) or E-class (DPP/QPS) hypothesis.** When the symptom set includes ANY of: "snapshot stuck CREATING", "FS publish stalled", "DPP reader QPS ≈ 0", "low input QPS", "checkpoint cadence broken" — run the trainer-Python liveness probe FIRST: `meta scuba.dataset query -d mvai_metrics --view=samples --columns=time -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' --hours=12 -l 1 --order-by=time`. Pulls last sample timestamp from trainer Python instrumentation. **If latest sample > 5 min stale AND MAST attempt status is RUNNING → the trainer Python interpreter is hung (P44/A1 — GIL hang, or A2/A3 — C++/storage stall depending on live process inspection)**; downstream stuck-CREATING snapshots and low DPP QPS are CONSEQUENCES, not roots. Do NOT propose D-class (TGIF, Hedwig, UMM publish) or E-class (DPP starvation) hypotheses until A is falsified by a fresh mvai_metrics sample. Cite verbatim: `[VERIFIED: mvai_metrics latest_sample=<timestamp>, gap_min=<N>, attempt_status=<S>]`. To pinpoint hang onset, bucket samples: `meta scuba.dataset query -d mvai_metrics -a count -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' --hours=12 --time-bucket="30 minutes"` — sharp drop to 0 = hang onset window. Source: 2026-05-13 model 2135033479 (gchat thread `tiooNt5H7zU`) — first triage misdiagnosed as TGIF/checkpoint_agent stuck; correct root was trainer GIL hang at 06:03:35 PDT, identified only via mvai_metrics zero-samples timeline. See `known-patterns.md` § Cause-vs-consequence map and P44.

      i-c. **Read SEV live GChat — MANDATORY.** Metadata is a snapshot; GChat carries current state. Extract gchat_space_url, parse space ID (segment after /room/), `gchat read <space_id>` (~20 messages). Parse for active hypotheses, paste links, ETA, contradictions. Cite as `[VERIFIED via gchat read <space_id>]`. Source: 2026-05-02 S657811 — metadata said 'archiver restarted, awaiting catchup'; GChat showed ~150 versions need manual deletion, 'won't be solved till next week'.

      i-d. **R19 mandatory pre-step — LINEAGE RESOLUTION for STUS-symptom SEVs.** When R14 confirms `role=stus` AND the SEV symptom is "missing FULL_SNAPSHOT" / "FS gap" / "snapshot stale on served model" / "too few delta snapshots", DO NOT page the STUS owner before resolving the ROOT trainer. STUS publishes what its upstream trainer produces; an STUS-only symptom usually means the **root trainer stopped producing the affected snapshot type** (NOT a STUS-side bug). Resolution sequence (5 commands, ~30 sec):
         1. `meta ai.model list-upstream-models --model-id=<STUS_MODEL_ID>` — returns lineage.
         2. For each candidate: `meta ai.mast-job describe --name=mvai-training-online-<CANDIDATE_ID>` — ROOT TRAINER has state=RUNNING + highest version count.
         3. `meta ai.model.instance list --model-id=<CANDIDATE_ID> --instance-type CHECKPOINT --limit 5` — confirm recent checkpoints (steady cadence).
         4. `meta ai.model.instance list --model-id=<ROOT_TRAINER_ID> --instance-type SNAPSHOT --limit 10`. **If 0 SNAPSHOTs despite flowing CHECKPOINTs → root trainer is the failure mode.**
         5. `meta ai.model-series metadata --model-id=<ROOT_TRAINER_ID>` — get ROOT TRAINER OWNER (NOT STUS owner).
         **Cite verbatim:** `[VERIFIED: stus_model=<STUS_ID>, root_trainer=<ROOT_ID> (v<N>, RUNNING), root_trainer_owner=<unixname>/<oncall>, snapshot_count_recent=<N>, checkpoint_count_recent=<N>]`. PAGE the ROOT trainer owner. Source: 2026-05-16 22:28 PT thread `2KD3EVyCv08` (alert variant). Codified across alert+sev crons 2026-05-17.
      ii. Active-SEV cross-ref — `meta sevmanager.sev list --tags=mvai-online-training --created-after="7 days ago" -o json`. Identify related SEVs in same signal class.

      ii-a. **R20 mandatory pre-step — SAME-WORKLOAD RECURRENCE check (4-source).** History repeats on the same workload. BEFORE finalizing standing hypothesis, check the SAME model's prior incident history across 4 sources (extended 2026-05-17 thread `Uc-pVBEXNQ8` 11:18 PT per P-003 generalize-to-system-rule):

         **S1 — SEVs via meta CLI (180d+):**
         1. `meta sevmanager.sev list --title-contains="<MODEL_ID>" --limit=20 -o json`.

         **S2 — Cleared alerts via OneDetection API (<30d retention):**
         2. `meta monitoring.alert list --alert-contains="<MODEL_ID>" --state-is=CLEARED --start-time=$(date -d '30 days ago' +%s) --limit=20`.

         **S3 — Local bot archives:**
         3. `grep -lr "<MODEL_ID>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs,posts,alerts}/ | grep -vE "/(INDEX|README|MISSING|NOISY-MODELS)\.md$"` — each hit = prior bot triage.

         **S4 — Mega-learnings cluster evidence (first-class signal):**
         4. `grep -lr "<MODEL_ID>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/digests/`. Hits in `failure-patterns.md` = bot already canonical-mapped this model to CL-NNN. Surface even if no per-incident archive exists.

         For each hit: extract identifier, time_created, status, mitigation. If 2+ prior incidents had SAME mitigation → strong signal recurring; short-circuit hypothesis.

         **Cite verbatim (extended):**
         ```
         [VERIFIED: model_<MODEL_ID> prior_SEVs=N; prior_alerts=N or unverified;
                    local_archives=[<file>, ...]; cluster_evidence=[<CL-NNN>, ...];
                    mega_learnings=[<file>, ...]]
         ```
         If all 4 are 0 → `[VERIFIED: model_<MODEL_ID> prior_incidents=0 across all sources]`. Source: operator 2026-05-17 thread `r70kC-3eghA` + `Uc-pVBEXNQ8`.

      ii-b. **R21 mandatory pre-step — CROSS-WORKLOAD PATTERN check.** History also repeats across related workloads. After R20:
         1. Extract `model_type_name` from `meta ai.model-series metadata --model-id=<MODEL_ID>`.
         2. Active-SEV/alert sweep on family: `meta sevmanager.sev list --tags=mvai-online-training --in-progress --title-contains="<family_keyword>"`.
         3. Symptom-cluster sweep: map current symptom to CL-NNN in `mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md`. If matched, query cluster Evidence list for sibling instances.
         4. **Pattern-match:** 2+ sibling models in same family with SAME symptom in 24h → shared infra root (escalate family-wide); symptom matches CL-NNN with N≥3 → cite cluster + documented mitigation; siblings healthy → per-model (R20 more likely).
         **Cite verbatim:** `[VERIFIED: family=<model_type_name>, sibling_alerts_24h=<N>, sibling_sevs_7d=<N>, matching_cluster=<CL-NNN or none>]`. Source: operator 2026-05-17 thread `r70kC-3eghA` — "the same problem may happen in multiple workloads."
      iii. Owner correction — verify model owner if relevant; vs SEV owner_unixname.
      iv. Hypothesis chain — pattern-match against known-patterns.md, then verify or falsify.
      v. **Scope check — SILENT DROP backstop.** Re-run capability call (same as step 4.5). If `in_scope == false`: silently add to diagnosed_ids. **DO NOT send any threaded reply, closure note, or "out of scope" message** — text mentioning sibling-org SEVs IS the leak (S657101 leaked via closure-note channel).
   v. **Quality rules** (SKILL.md + D103543146) — ALL must appear in every diagnosis:
      - **Baseline before anomaly**: cite known-good window for any "broken/slow/wrong" claim.
      - **Layered hypothesis enumeration**: name every layer; rule each in/out with data. No single-hypothesis diagnoses.
      - **Code-pointer mandatory**: every "fix X" cites file path + line number.
      - **Tiered recommendations**: SHORT (≤1 day, config flip) / MEDIUM (≤1 week, cross-team) / LONG (weeks+, refactor).
      - **Soft cross-references include verification step**: "if X upstream of Y" cross-refs MUST include verification command BEFORE contingent action.

   v.1. **HARD pre-finalize gate — training-job-state citation REQUIRED for snapshot/FS symptoms.** When the SEV/symptom involves any of: "missing FULL_SNAPSHOT", "snapshot delay", "snapshot stale", "publish stuck", "model age growing", "FS gap", "no new snapshots" — the diagnosis MUST cite at least one literal `meta ai.mast-job attempts --name=<JOB>` AND one literal `meta ai.mast-job error --name=<JOB> --version=<PREV>` in the Investigation Commands appendix, and MUST quote at least one fact from those outputs in the Ground-truth section (attempt state, FAIL timestamp, or verbatim error_message line). **If the cron about to publish a diagnosis cannot satisfy this gate**, STOP and emit instead: `BOT INCOMPLETE — required training-job-state check skipped on snapshot/FS symptom; rerun with: meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID> + meta ai.mast-job error --name=mvai-training-online-<MODEL_ID> --version=<PREV>`. Source: 2026-05-07 S661157 — bot diagnosed "FS generation stopped at 14:10" without ever checking the training job; reality was Boxcar planned-maintenance preemption at 05:59 PT (P38), already auto-restarted by TMS, no real failure.

   v.2. **R18 HARD pre-publish gate — diagnosed-stage scope re-check.** AFTER step v.1 passes and BEFORE the diagnosis is published, classify the diagnosed root cause's pipeline stage: T1 (DPP / Scribe ingestion), T2 (training: trainer process, NCCL, OOM, GIL hang, schedule/PG), T3 (publishing: TGIF / GMPP / SilverTorch publish path / fbpkg / FS publish), T4 (serving: ICSP / RAAS / Multifeed / predictor config), or out-of-pipeline (model-lifecycle: launch gate, decommission, solver_mode). **If diagnosed stage is T4 (serving) or out-of-pipeline, do NOT publish the OT-routed diagnosis.** Instead emit a single-line `[OUT-OF-SCOPE: <stage>-stage SEV — routes to <correct_owner>; diagnosed root cause: <one-line>]` and silently drop (no main-space notification, no validator pass, no auto-tag). Add the SEV to `diagnosed_ids` so it's not re-triaged next hour. Tag-based routing (the SEV being tagged `mvai-online-training`) is necessary but NOT sufficient — the diagnosed root cause is the authoritative scope signal. **Falsifier**: diagnosed stage is T1/T2/T3 → publish normally. Source: 2026-05-13 S661843 (`ig_stories_tray_mtml` holdout) — cron correctly diagnosed root cause as ICSP `solver_mode=ON_DEMAND` (T4), explicitly falsified training-path hypothesis ("no `mvai-training-online-875799562` MAST job"), but published the diagnosis routed to mrs_online_training because the SEV was tagged `mvai-online-training`. Operator: "This is not an online training SEV. This is inference stage SEV. Right?" See R18 in `references/triage-discipline.md`.

   vi. **Diagnosis output template** — appendix sections after standing hypothesis + recommendations (Evidence and Commands mandatory; Files-touched conditional):
      - **Raw log Evidence appendix** (lettered A, B, C...): literal log lines + timestamps + ranks. Hypothesis cites inline (e.g., "NE stalled 22:03→22:40 [Evidence D, F]").
      - **Investigation Commands appendix** (numbered): replayable `meta` / `tw log` commands. For `tw log`, see `references/tw-log-recipes.md` (D103543146).
      - **Files-touched table** (CONDITIONAL — omit ENTIRELY if no code-fix is proposed): `| path | 1-line role |` only when a Next-Action explicitly cites a file path to edit. Do NOT emit a placeholder row like `| no fix proposed | n/a |` or an empty table — drop the section header too. Per 2026-05-13 audit (yO-CQRIsrlQ): empty Files-touched appeared on ~80% of triages, was operator-flagged as noise.
      Source: 2026-04-30 velvinfu paste P2300957350.

   c. Send threaded reply with diagnosis. **LOCKED FORMAT (2026-05-16) — fixed sections, fixed order, fixed labels. Pre-publish lint enforces structure. Mirrors `ot-alert-monitor.md` so downstream parsers can consume both.**

      **Section 1 — Verdict header line (line 1, no preamble, replaces prior `[ot-bot diagnosis | symptom-attribution: X% | root-cause: Y%]` prefix).**

      Format: `<icon> <ACTION> · root-cause: <status> · class: <class> · confidence: <level><optional auto-resolved tag>`

      | Icon | ACTION | When |
      |---|---|---|
      | 🟢 | `NO ACTION` | False positive OR auto-resolved with known benign cause |
      | 🟡 | `MONITOR` | Self-resolving in progress OR upstream infra issue tracked elsewhere |
      | 🔴 | `PAGE <owner>` | Real failure requiring human |
      | ⚪ | `UNKNOWN` | Root cause not found; deeper investigation needed |

      Note: `OUT-OF-SCOPE` (R18 stage-drop, step 9.b.v.2) does NOT use a verdict header — it emits the single-line `[OUT-OF-SCOPE: ...]` and stops, no diagnosis published.

      `root-cause`: `known` / `partial` / `not found`. **`known` = ground-truth-cited cause + at least one ruled-out hypothesis. `partial` = one cause hypothesis but alternatives not ruled out. `not found` = no surviving hypothesis.**

      `class` (FIXED enum — v1; mega-learning cron clusters on this string):
      - `THRESHOLD_MISFIT` — alert/SLI threshold doesn't fit this entity's normal cadence; pipeline healthy
      - `DETECTOR_BROKEN` — detector has no data source / misconfigured
      - `MISCONFIG_AGG` — AGG alert with one sub-type at 0 occurrences (P58)
      - `TRANSIENT_NOISE` — brief spike, self-resolved, no underlying issue
      - `UPSTREAM_INFRA` — confirmed upstream SEV (ZippyDB / Scribe / LogDevice etc.) causing OT symptom (P50)
      - `REAL_OT_FAILURE` — actual OT pipeline failure requiring intervention
      - `CONVEYOR_REGRESSION` — conveyor publish pipeline blocked by upstream code regression (S665090 class)
      - `ZOMBIE_SEV` — stale SEV resurfaced via monitor filter, no live incident (S659877 class)
      - `NEEDS_INVESTIGATION` — pattern unknown / root cause not found

      `confidence` (rubric — replaces percentage):
      - `high` — ground-truth queries verified ✓, ≥2 alternative hypotheses ruled out with cited data
      - `medium` — ground-truth verified ✓, 1 alternative ruled out
      - `low` — ground-truth incomplete OR no alternatives ruled out OR pattern-match only

      Optional suffix: ` · auto-resolved` (incident self-healed before diagnosis ran). Mandatory if true.

      `model_name` / `model_lane` / `model_role` / `training_stack` — four orthogonal JSON fields, not merged. `model_name` = literal series name from `meta ai.identify` (e.g., `facebook_reels_ifu_mtml_v0`). `model_lane` = ranking vs retrieval, derived by regex on the name. `model_role` = trainer vs stus, derived from R14 entrypoint check. `training_stack` = MVAI vs SilverTorch, derived from `application_metadata.distributed_ai_stack` (see R14b below).

      **CRITICAL anti-pattern (2026-05-16):**
      - `model_name` is the SERIES NAME — NEVER substitute owner unixname, oncall name, model_id, or any other identifier. Source: 2026-05-16 thread `-7JtEC9JAGw` where cron emitted `"model_name":"shuyaoli"` (the owner) for model 2144816217.
      - `owner` is the unixname — populated separately from `model_name`.
      - If `meta ai.identify` returns empty or errors, render `model_name: "unknown"` rather than substituting a different identifier.

      NEVER substitute a derived label like `ranking_trainer` for the actual model name. Operator feedback 2026-05-16 thread `6pKeH_XqjcE`.

      Derivation rules:
      - `model_lane`: `/retrieval|t2i|u2i|i2i|embedding/i` → `retrieval`. `/ranking|mtml|cfr|ifu|esr|ifr|holdout|hstu|vdd|video/i` → `ranking`. Else `unknown`.
      - `model_role`: entrypoint contains `train` → `trainer`. Entrypoint contains `st_update_service` → `stus`. No MAST job or unrecognized → `unknown`.
      - **`training_stack` (T273158617 Fix 8)**: derive from `application_metadata.distributed_ai_stack` on the MAST job describe output. One-shot extraction, NO regex: `meta ai.mast-job describe --name=<JOB> -o json | jq -r '.application_metadata | fromjson | .distributed_ai_stack'`. Maps to one of: `MVAI` (default for `mvai-training-online-*` trainers + STUS), `SILVERTORCH` (for jobs with `SilverTorch*` name prefix — typically `OFFLINE_TRAINING` or `RECURRING_TRAINING` job_type), or other vendor strings as they appear. If no MAST job is resolvable (e.g., SEV title plural, model decommissioned) → `unknown`. **Verified 2026-05-27 across 11 sample jobs: signal is canonical and 100% reliable; do NOT try to regex the entrypoint as a substitute.** Note: `entrypoint=silvertorch/experimental/st_update_service/*` indicates STUS *role* (not stack) — those jobs are still MVAI-stack; this is a known cross-cut between R14 and R14b.
        - **TITLE-PREFIX FALLBACK (2026-05-27 backtest finding):** if MAST resolution returns `unknown` BUT the SEV title matches regex `^\s*\[silvertorch/` (case-insensitive), set `training_stack = "SILVERTORCH"` and record `training_stack_source = "title_prefix"` in the JSON for auditability. Same for `^\s*\[mvai/` → `MVAI` with `training_stack_source = "title_prefix"`. MAST-resolved values always take precedence over title-prefix; record `training_stack_source = "mast_describe"` for those. Title-prefix is operator-curated convention (verified backtest 7d: 11/11 `[mvai/*]` and 1/1 `[silvertorch/*]` were correct), but ambiguous prefixes like `[model_e2e/ifr_prospector]` MUST fall through to `unknown` — that pattern exists as BOTH SilverTorch (`SilverTorch-prospector-*`) AND MVAI (`fire-*-ifr_prospector_axsweep_*`) jobs in production, so the prefix alone is not authoritative. Sources: 2026-05-27 thread `BvPAmLCNmyk` operator approval; S666632 backtest confirms `[silvertorch/fbr_hstu]` mapping.
      - **`pg` (Product Group): COMBINED attribution from `sev_type` (via `meta sevmanager.sev describe`) AND title-regex matching.** sev_type alone gives org-tree categories (Instagram = IG+Threads+Reels combined; Production = mvai-infra-mostly); title regex separates the PGs the operator cares about. SEV UI labels sev_type as "Stack".

        **Decision order (first match wins):**
        1. `sev_type=Instagram` AND title `/thread\|tifu/i` → `pg="Threads"` (Threads is org'd under Instagram; title regex separates)
        2. `sev_type=Instagram` AND title `/reels.*vdd\|vdd_hstu\|video_udd\|video_ifu\|videorec/i` → `pg="Video"` (Reels/Video specific)
        3. `sev_type=Instagram` AND title `/facebook\|fbr\|cfr_main_feed\|ifr_main/i` → `pg="Facebook"` (FB cross-product hosted under IG sev_type)
        4. `sev_type=Instagram` (else) → `pg="IG"` (IG core — Reels, Feed, Stories, Direct, Explore)
        5. `sev_type=Multifeed` → `pg="Facebook"` (FB Feed multi-stage pipeline)
        6. `sev_type=Video` → `pg="Video"` (standalone Video, rare)
        7. `sev_type=Production` AND title `/\[mvai\/\|cogwheel\|light_cli\|silvertorch\|fbpkg\|TGIF\|gmpp/` → `pg="infra-cross-pg"` (MVAI infra / release pipeline)
        8. `sev_type=Production` AND title `/cfr_main_feed\|ifr_main\|fbr\|facebook_/` → `pg="Facebook"` (FB SEVs that didn't get proper sev_type)
        9. `sev_type=Production` (else) → `pg="unknown"` (operator created SEV without filling PG-specific impacted_areas)
        10. `sev_type=Ads` → `pg="Ads"` (out of MRS scope; R18 should drop before this is emitted)
        11. `sev_type=Storage` / `Data Warehouse` / `AI Infra` / `Integrity` → `pg="other"` (tag-noise; R18 should drop)
        12. sev_type missing / unrecognized → `pg="unknown"`

        Source: 2026-05-16 thread `ZP2y-6Bdpwk` operator-driven design — verified that `sev_type=Instagram` covers IG+Threads+Reels (org tree), and most FB SEVs come in as `sev_type=Production` with cfr_main_feed/ifr_main/fbr titles. Title-regex layer separates them into operator-meaningful PG buckets. PG reference table with full data at `mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md` § "PG (Product Group) reference".

      **CRITICAL — distinguish "alert/monitoring issue" from "real incident".** The verdict header MUST make this unambiguous via the `class` field. `THRESHOLD_MISFIT` / `DETECTOR_BROKEN` / `MISCONFIG_AGG` / `ZOMBIE_SEV` = monitoring-side issue (no real problem). `REAL_OT_FAILURE` / `UPSTREAM_INFRA` / `CONVEYOR_REGRESSION` = real issue. Operator should NEVER have to read past line 1 to know which it is. Source: 2026-05-16 operator feedback thread `aT_6RlZgMwg`.

      **Sections — fixed labels, fixed order, no variants. Sections are MANDATORY — if no content, emit literal `(none)` rather than skip.**

      **Restructured 2026-05-17 (operator thread `O_kKd7ADe5g`):** dropped 4 sections of redundancy. Symptoms + Signal specifics merged into `*What happened*`. Cross-SEVs folded into `*Evidence*` bullets. Standing hypothesis merged with implication. Validator line removed (status lives in JSON only).

      ```
      <VERDICT HEADER LINE>

      *PG*: <PG>  ·  *Owner*: <unixname> / <oncall>  ·  *Model*: <id> (<model_name>) | <model_role> | stack=<training_stack>

      *What happened*: <one paragraph. names exact metric / snapshot-type / SEV signal class that triggered; for delta SEVs name SPARSE_DELTA vs DENSE_DELTA vs FULL_SNAPSHOT EXPLICITLY — do NOT lump together; user-visible breakage; concrete metric values; timestamps>

      *Evidence*:
      • <fact 1> [VERIFIED via <cmd>]
      • <fact 2> [VERIFIED via <cmd>]
      • <fact N — include any cross-SEVs as evidence bullets: e.g., "S665163 ZippyDB throttle In Progress since 00:15 PDT [VERIFIED via meta sevmanager.sev describe]">

      *Hypothesis & implication*: <surviving cause + what it implies for the operator. Single paragraph.>

      *Ruled out*:
      • <hypothesis> — <contradicting fact + source>

      *Next actions*:
      1. <action with owner + concrete command>

      📊 Machine fields: <paste_url>
      ```

      **JSON moves to paste (added 2026-05-17 thread `SN72CzuckRQ` after operator: "do I really need to see it as a human?").** The JSON block IS machine-readable metadata for validator + curation + cluster-mapping consumers — they read it. Operator does NOT. Render it OFF the gchat surface:

      ```bash
      # Build the JSON object (same fields as before), pipe to pastry, get URL
      JSON_PAYLOAD=$(cat <<EOF
      {
        "verdict": "<NO_ACTION|MONITOR|PAGE|UNKNOWN>",
        "class": "<enum value>",
        "root_cause_status": "<known|partial|not_found>",
        "confidence": "<high|medium|low>",
        "auto_resolved": <true|false>,
        "sev_id": "<S id>",
        "pg": "<IG|Threads|Video|Facebook|infra-cross-pg|Ads|other|unknown>",
        "model_id": "<id or null>",
        "model_name": "<full name from meta ai.identify, e.g. facebook_reels_ifu_mtml_v0, or null>",
        "model_lane": "<ranking|retrieval|unknown>",
        "model_role": "<trainer|stus|unknown>",
        "training_stack": "<MVAI|SILVERTORCH|unknown>",
        "training_stack_source": "<mast_describe|title_prefix|none>",
        "owner": "<unixname>",
        "oncall": "<oncall name>",
        "signal_class": "<from team_lane_scope>",
        "signal_specifics": {
          "metric_class": "<snapshot|data_age|scribe_lag|latency|detector_no_data|other>",
          "metric": "<e.g. SPARSE_DELTA cadence, checkpoint_training_data_age_mins>",
          "affected_snapshot_types": ["SPARSE_DELTA"],
          "healthy_snapshot_types": ["DENSE_DELTA", "FULL_SNAPSHOT"]
        },
        "ruled_out": ["<hypothesis 1 (P-row or R-rule id)>", "<hypothesis 2>"],
        "related_sevs": ["S<id>"],
        "validator_status": "<pending|confirmed|discrepancy: <one-liner>|unavailable>"
      }
      EOF
      )
      PASTE_URL=$(echo "$JSON_PAYLOAD" | pastry -t "$SEV_ID-machine-fields" --md 2>/dev/null | tail -1)
      # Embed PASTE_URL in the gchat message as: 📊 Machine fields: $PASTE_URL
      # ALSO include the full JSON in raw_response (sqlite job_runs) so consumers that scrape sqlite directly still work
      ```

      **Compatibility for downstream JSON consumers:**
      - **`raw_response` (sqlite job_runs)** still contains the full JSON block as a code-fenced section after the narrative. `ot-postmortem-validator`, `ot-knowledge-curation`, `ot-cron-health-watch`, `ot-human-attention-brief` all read from `raw_response` — NO change to them.
      - **Validator in-place edit (step d below)** now updates the PASTE content via `pastry <paste_id>` (overwrite) instead of editing the gchat message. The gchat message link stays stable; paste content gets the `validator_status` update.
      - **If `pastry` fails or times out (>10s)**, fall back to inline JSON in the gchat message (same as pre-2026-05-17 behavior). Cite `⚠️ paste creation failed, inline JSON below` followed by the code-fenced JSON. Operator sees the noise but the bot still emits the machine fields.

      **Why paste (not `<details>` or attachment):** gchat doesn't render `<details>` collapsibles, doesn't support attachments from bots cleanly, and any inline JSON shows up raw. Paste is the only surface where machine fields stay accessible (clickable for the rare operator who wants them; one-line for skim).
      ```

      **What changed (2026-05-17 thread `O_kKd7ADe5g`):**
      - **PG/Owner up front** — most-actionable fields for TL skim; promoted to lead-line
      - **`*What happened*` replaces `*Symptoms*` + `*Signal specifics*`** — both said the same thing in practice
      - **`*Evidence*` replaces `*Ground-truth*` + `*Cross-SEVs*`** — cross-SEVs are facts; belong with other facts
      - **`*Hypothesis & implication*` replaces `*Standing hypothesis*`** — bare hypothesis forced 2 more sections to reach "so what"; now chained
      - **`*Validator*` prose line removed** — status lives in JSON only; was "⏳ pending" or "🚫 unavailable" 99% of time, pure noise
      - **`family:` field dropped from Model line** — duplicates model_name

      **Pre-publish lint (MANDATORY).** Before sending, verify the message matches this skeleton:
      ```
      ^<verdict_line>\n\n\*PG\*:.+\n\n\*What happened\*:.+\n\n\*Evidence\*:.+\n\n\*Hypothesis & implication\*:.+\n\n\*Ruled out\*:.+\n\n\*Next actions\*:.+\n\n📊 Machine fields: https?://.+$
      ```
      If any header is missing, out of order, or the JSON block appears INLINE (post-2026-05-17 thread `SN72CzuckRQ` — JSON moved to paste; inline JSON is a regression), FIX before sending. Section labels are LITERAL (`*PG*`, `*What happened*`, `*Evidence*`, `*Hypothesis & implication*`, `*Ruled out*`, `*Next actions*`); do NOT substitute legacy labels (`*Model*`, `*Symptoms*`, `*Signal specifics*`, `*Ground-truth*`, `*Standing hypothesis*`, `*Cross-SEVs*`, `*Validator*` — all retired 2026-05-17).

      **Pre-publish CONTENT lint (MANDATORY, 2026-05-17 thread `suPsRC2fGdc`).** Enforce content discipline:
      - R20 ran with N>0 prior incidents → Evidence MUST include `[VERIFIED: model_<MODEL_ID> prior_incidents=`.
      - R21 ran with matching_cluster!=none OR sibling_sevs_7d>0 → Evidence MUST include `[VERIFIED: family=<model_type_name>`.
      - **CL-NNN citation MANDATORY** when symptom matches a known cluster (NaN → CL-017, snapshot-stuck → CL-001, downstream-infra → CL-003, training-age → CL-013, NCCL-timeout → CL-014, AGG → CL-018). Evidence + Hypothesis & implication must reference cluster by ID.
      - **P-row citation MANDATORY** when symptom matches a known P-row. Next actions: `Apply P<NN>: <mitigation>`.
      Source: 2026-05-17 10:18 PT live triage on 878858380 (thread `akCTORdwUK4`) — did the work, didn't cite CL-017/P56. Same gap fix landed in ot-alert-monitor.

      **Char cap.** 3000 chars hard cap. If diagnosis overruns, spill investigation commands / raw log evidence to a paste (`pastry create -t "<sev_id>-detail"`) and link from *Next actions*: `📄 Full evidence: P<paste_id>`. Required sections always inline.

      End with: "SEV(s): <comma-separated urls>" — literal `url` field per URL sourcing rule. If empty, render `<url-unavailable>`. AFTER the JSON block.

   d. **VALIDATOR PASS** — spawn independent agent via Agent tool with prompt: "Validate this OT SEV triage. Re-read diagnosis I just published in spaces/AAQAVOjYc80 thread <thread_id>. Independently run: (1) `meta sevmanager.sev metadata --sev=S<id>` for each SEV in cluster, (2) ground-truth queries the diagnosis cites, (3) cross-check standing hypothesis against actual data. Report: (a) confirmed | (b) discrepancies + what data contradicts what. Under 300 words. Do NOT see my reasoning, only the published diagnosis."

      **In-place update of PASTE (NOT new gchat message, NOT edit gchat message text).** After validator returns, EDIT the paste content (created in the step above) via `pastry <paste_id>` overwrite: update the JSON field `"validator_status"` from `"pending"` to `"confirmed"` / `"discrepancy: <one-liner>"`. Gchat message stays unchanged (paste link is stable). **No prose `*Validator*:` line is emitted** (retired 2026-05-17) — status lives in paste's JSON only. Source: 2026-05-16 operator feedback thread `6pKeH_XqjcE` (no two-message-with-gap) + 2026-05-17 thread `SN72CzuckRQ` (JSON off the gchat surface).

      If subagent / Agent tool is unavailable (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`), DO NOT spawn the subagent. Update PASTE JSON: `"validator_status": "unavailable"`. No prose line, no gchat edit.

   e. AUTO-TAG — decoupled from hypothesis confidence (2026-05-01 fix). Fires on **signal-class evidence**, NOT mechanistic-hypothesis confidence. Tag if ALL hold:
      - `scope_check` returned `in_scope=true` (verified at step 4.5)
      - `mvai-online-training` not already in tags (verify via `meta sevmanager.sev metadata --sev=S<id> -o json | jq -r '.tags // empty'` — DO NOT trust list-filter caches)
      - validator pass either confirmed OR was DEGRADED (memory/subagent block is NOT a skip reason; only explicit "validator found scope discrepancy" is)

      Run: `meta sevmanager.sev update --sev=S<id> --add-tag=mvai-online-training`
      Log LITERALLY: "Auto-tagged ✓" or "Auto-tag failed: <stderr verbatim>". Skip ONLY if validator flagged scope discrepancy, OR scope_check returned in_scope=false at any step. **Mechanistic hypothesis uncertain is NOT a skip reason.**

      **STACK-SPECIFIC SECOND TAG (T273158617 Fix 8 follow-up, 2026-05-27):** if the diagnosis JSON's `training_stack == "SILVERTORCH"` AND `mrs-online-training-silvertorch` NOT already in tags (re-verify via fresh `meta sevmanager.sev metadata` — do NOT cache), run an ADDITIONAL update: `meta sevmanager.sev update --sev=S<id> --add-tag=mrs-online-training-silvertorch`. Log LITERALLY: "Stack-tagged ✓ (silvertorch)" or "Stack-tag failed: <stderr verbatim>". Independent of the primary tag — both can fail independently and BOTH should be retried on the next pass via step 6.5 re-evaluation. For clusters with mixed-stack models (some MVAI, some SILVERTORCH), the silvertorch tag fires per-SEV whose attributed model has `training_stack=SILVERTORCH` — not at cluster level. Skip conditions identical to primary tag (in_scope=false / validator-flagged discrepancy).

   f. Add every SEV sev_number in cluster to `diagnosed_ids` using v3 schema: `diagnosed_ids[<sev_number>] = {"added_epoch": <now_epoch>, "notification_outcome": "$NOTIFICATION_OUTCOME"}` where `$NOTIFICATION_OUTCOME` was captured in step 9.a's send-discipline block. **HARD GATE (T273158617 Fix 7):** if `$NOTIFICATION_OUTCOME` is unset OR starts with `ERROR:`, keep the entry with the `ERROR:` outcome — DO NOT silently mark with a fabricated `POSTED:` value. `ot-cron-health-watch` step 6.7 will pick up the ERROR for triage. For backfill/preemptive/procurement silent-add paths (step 3 backfill, step 2.A' mitigated, [Preemptive], procurement-exclusion): set outcome to `OOS:<reason>` (e.g. `OOS:preemptive_launch`, `OOS:procurement_hardware`, `OOS:mitigated_backfill`).

10. After loop: persist state, update last_run_epoch, respond with HEARTBEAT_OK + per-SEV summary line that **MUST include the bot's posted gchat thread URL AND the SEV URL** (for ot-human-attention-brief link extraction):

    ```
    HEARTBEAT_OK

    ---

    **Run summary** (SEVs processed: N):

    **S<id>** — <verdict_line>
    - Bot reply: https://chat.google.com/room/AAQAVOjYc80/<thread_id>
    - SEV: https://www.internalfb.com/sevmanager/view/<id>
    ```

    Mandatory; operator-flagged 2026-05-17 thread `Y3qbdh2hC20`.

    **URL-derivation rule (T273158617 Fix 4, 2026-05-27):** the `<thread_id>` MUST be `$THREAD_ID` from step 9.a's captured send response. NEVER synthesize, NEVER re-use a thread from a different cluster, NEVER reference a thread the current cron tick did not create. If `$THREAD_ID == "SEND_FAILED"`, render `- Bot reply: SEND_FAILED (outcome=<notification_outcome>)` and prefix the SEV header with `⚠️ NOTIFICATION DROPPED`. Anti-pattern: ot-post-monitor run #6517 fabricated `yF_aMB00xMk` thread URL while actual send had silently failed.

Safety:
- If both (A) and (B) fail, do NOT advance state. Brief error string (no HEARTBEAT_OK).
- If only one succeeds, proceed and note "DEGRADED: query <X> failed" in diagnosis.
- If cluster deep triage fails partway, post partial diagnosis with "DEGRADED: <step>", continue, do NOT auto-tag.
- Cap 3 clusters per run.
- Do NOT modify SEV state beyond `--add-tag=mvai-online-training` and (conditionally) `--add-tag=mrs-online-training-silvertorch` (no resolve, no level change, no narrative edits).

## Learned Rules (auto-appended)

1. [2026-04-29 manual] `oncall.feed list --oncall=mrs_online_training --item-type-is=SEV` is too narrow — only catches SEVs routed to mrs_online_training as responsible rotation, misses cross-team SEVs like S654315. Wider scope (tagged-OR-title-class) plus deep-triage scope check catches real "looped in" set. Sourced 2026-04-29 15:21 PT.

2. [2026-05-22 L29] `ATS` sub-pattern in step-3 title regex lacks word boundary — matches substrings "WhATS" in WhatsApp and "aTSR" in Wearables titles. Fix: `ATS` → `\bATS\b`. Preserves legitimate ATS-budget OT SEVs while eliminating both false-positive classes. Source: S665416 (Wearables aTSR), S667190 (WhatsApp WhATS).

3. [2026-05-22 L31] SEV titles beginning with `[Preemptive]` reliably indicate launch/preemptive SEVs that are out-of-OT-pipeline. At step 3 (after regex match): if `title.startswith('[Preemptive]')` → add to `diagnosed_ids` immediately, skip scope_check + R18. Reduces one manual assessment per preemptive launch SEV per run. Source: S666505, S660706 (both `[Preemptive] Launch LTV MVAI migration model`).

4. [2026-05-23 L34] Bare `\bOT\b` abbreviation in SEV titles is not in the step-3 signal regex. Add `online\s+training` (case-insensitive) as an additional OR clause in the step-3 title regex. Spellings like "start OT", "OT failure" or "not able to start OT" all map to the same domain but are currently missed. Source: S667453 "High priority QE model not able to start OT".

5. [2026-05-23 L36] When `google.chat.message` tool unavailable in cron context, completed diagnoses must NOT be silently dropped as inline-only. Fallback ladder: (1) try `meta google.chat.message create --space=spaces/AAQAVOjYc80 ...` CLI form; (2) if also unavailable, record `notification_status=PENDING_RETRY` per SEV in state JSON and re-attempt on next run. Never drop a triage. Source: 2026-05-22 18:03 UTC S667466/S667465 silent-drop incident.

6. [2026-05-24 L38] Procurement exclusion after step-3 `DELTA` match: if title contains any of (`WIWYNN`, `L6 COMPONENT`, `L4 COMPONENT`, `supply chain`, `PSU vendor`, `hardware`, `ISCE`) → classify in_scope=false immediately, silently add to diagnosed_ids without invoking scope_check. Eliminates repeated false-positive processing for hardware procurement SEVs. Source: S667488 "Q3'26 | WIWYNN | DELTA | L6 COMPONENT" false-positive on 6+ consecutive runs.

7. [2026-05-24 L41] Add `(?i)\b(NE|gradient|loss)\s*explosion\b` as an additional OR clause in step-3 title regex. "NE explosion" is the common short form in Meta internal SEV titles (NE = numeric explosion = loss/gradient becoming NaN/Inf). Covers training instability SEVs currently invisible to the bot. Source: S667572 "ESR and LSR NE explosion" regex miss.

8. [2026-05-24 L42] Non-numeric model identifiers (e.g., hex-like `f831018319`) must trigger a structured 3-step fallback: (1) try `meta ai.model-series describe` with identifier as `--model-name` substring; (2) scan SEV description body and tags for decimal numeric model_id; (3) if still unresolvable → post initial reply to SEV asking owner to populate numeric model_id, set confidence=LOW, record `model_id_unresolvable=true` in state JSON for retry on next run. Never leave triage in indefinite DEGRADED with no owner notification. Source: S667565 "f831018319" hex-identifier triage DEGRADED.

9. [2026-05-24 L43] State expansion anomaly reporting: when a single run adds >40 new IDs to `diagnosed_ids` (vs the normal 1–5 new/run cadence), include `state_expansion_anomaly=true` in the run summary header with prior_count, new_count, and delta. Enables operators to detect state resets without grep-scanning. Source: 2026-05-24T08:03 run added 89 new IDs.

10. [2026-05-24 L44] When triage produces UNKNOWN/NEEDS_INVESTIGATION with confidence:low: (1) gchat reply MUST include "🔎 Bot triage inconclusive — manual investigation required"; (2) set `retry_on_next_run=true` in state JSON so next hourly run re-attempts with updated SEV context; (3) do NOT auto-tag until confidence ≥ medium — incomplete triage is not a tagging signal (R19). Source: S667620 inconclusive triage with no explicit marker.

11. [2026-05-25 L45] `diagnosed_ids` set-membership check can fail due to int/str type mismatch or in-memory vs file-state divergence, causing duplicate notifications. Fix: (1) normalize all SEV IDs to `str(sev_id)` at both write and read time; (2) after building new-candidate set, re-load `diagnosed_ids` from persisted JSON for a second-pass check before any notification is sent; (3) if candidate passes in-memory check but fails file check → skip, log `duplicate-guard=triggered`, add to in-memory set. Source: 2026-05-25T05:05 S666880/S667443 duplicate-notification incident.

12. [2026-05-26 L47] When pruning `diagnosed_ids`, ONLY remove IDs for SEVs that are confirmed closed/resolved or >30 days stale. NEVER prune open/in-progress SEVs just because they temporarily drop from the 3-day candidate query window. Open-but-out-of-scope SEVs (R18/T4/preemptive) that get pruned will resurface on future runs and waste re-processing cycles. Source: S659877 (19-day stale T4) + S660706 re-processed 2026-05-25 21:56 run after prior prune.

13. [2026-05-26 manual] **MULTI-ATTEMPT PEER-IP VERIFICATION before claiming "same bad host" or "retry-on-same-allocation".** When a Gloo / NCCL / network-peer failure recurs across multiple MAST attempts and the diagnosis proposes a host-eviction fix (e.g., P2352139502-class), EXTRACT the failing peer's IPv6 host portion from EACH attempt's stderr (`meta ai.mast-job logs --attempt=<N>` then grep for `\[fe80::|2401:db00:.*:[0-9a-f]+\]`). Tabulate `attempt → peer_host_portion → status`. The "same bad host" claim is valid ONLY if the peer host portion matches across ≥2 consecutive failed attempts. If host portions DIFFER across attempts (e.g., attempt 0 = `...7371:1c09:1532`, attempt 1 = `...2e18:330b:153f`), the underlying signal is **region / capacity-level fault** (multiple NHA hosts going silent within hours — typically correlated with `under_supply: Yes` on the entitlement or a regional SMC blip), NOT a single-host eviction problem. Fix-scope recommendation MUST track this distinction: host-eviction works for matched-IP repeats only; differing IPs across attempts require region-migration or capacity-rebalance trigger. Cite verbatim: `[VERIFIED: attempts=[(0,<ip>,FAILED),(1,<ip>,FAILED),...], same_host=<true|false>]`. Source: 2026-05-26 S668272 (mvai-training-online-2124455858) — bot's threaded diagnosis claimed "SAME bad host (2e18:330b:153f:a00 both)" while attempt 0 actually failed on a different host (`7371:1c09:1532:a00`); operator caught the omission. Pattern-reuse across attempts without verifying peer-IP equality is fabrication.

14. [2026-05-26 manual] **GLOO FAILURE MODES are distinguished by `pair.cc:<line>` + error class, NOT by substring `gloo/transport/tcp`.** When cross-referencing a current SEV against historical SEVs as "same Gloo pattern", matching on the substring `gloo/transport/tcp/pair.cc` is INSUFFICIENT — it produces false-cluster citations across mechanistically distinct failure modes. Required match: BOTH the `.cc:<line>` AND the error class string must be identical. Known modes (extend as new ones surface): (a) `pair.cc:545` `Read error` → TCP read timeout, peer hung silently with no FIN — typically host/NIC fault, non-deterministic, requires manual kill + region migration. (b) `pair.cc:559` `Connection closed by peer` → peer process exited cleanly with FIN — typically deterministic code regression around publish path, revision-bisectable, often self-resolves after fix lands. (c) `pair.cc:<other>` → label as `adjacent but distinct` until characterized. When citing a cross-SEV in the *Hypothesis & implication* or *Ruled out* sections, the citation MUST include `[pair.cc:<line> + <error_class>]` verbatim; if either differs from the current SEV, prefix the citation with `adjacent but distinct —`. Source: 2026-05-26 S668272 (current: `pair.cc:545` Read error, host hang on live OT training) vs S667687 (cited: `pair.cc:559` Connection closed, cogwheel test on `online_train_publish`) — bot's threaded diagnosis labeled them "same Gloo TCP pattern, different model," which is shallow pattern-reuse that would misdirect MAST infra investigation. Per MEMORY R43: pattern-reuse across alerts where underlying mechanisms differ is fabrication.

15. [2026-05-27 L50] **scope_check binary degradation → surface DEGRADED warning even when no SEVs triaged.** When `buck2 run fbcode//pe_mrs_ml/mrs_ot_agent:scope_check` returns exit 1 (binary degraded): (1) include `⚠️ scope_check=DEGRADED` in the GChat run summary even for zero-SEV runs (currently degradation is only in raw_response, invisible to operator unless they read raw data); (2) label each title-evidence-only classification with `[manual-scope-assessment]` so false positives are traceable; (3) if scope_check remains degraded for >3 consecutive runs, append to warning: "Manual verification recommended before next paging action.". Source: ot-sev-monitor 2026-05-27T07:52 (scope_check exit 1, HEARTBEAT_OK delivered, degradation invisible) + 2026-05-27T00:56 (scope_check degraded, SEV manually assessed).

16. [2026-05-27 L52] **GChat reads 403 during SEV triage → degrade confidence one level.** When `meta google.chat.message list` returns 403 on SEV-space read during active triage: (1) include `gchat_reads=DEGRADED(403)` in run summary header; (2) cap triage confidence at one level below metadata alone supports (high→medium, medium→low) — thread evidence unavailable; (3) add note in SEV GChat reply: "⚠️ Bot GChat reads degraded (403) — SEV thread context unverified. Confidence capped." Source: ot-sev-monitor 2026-05-26T13:03 — S668017+S668033+S668029 triaged with `GChat reads DEGRADED (403)`, confidence `medium` (would have been `high` with thread access).

17. [2026-05-28 L54] **Security/infosec SEV fast-path exclusion after step-3 match.** If title matches `/\[memlab\]|RCE via|heapsnapshot.*eval/i` after step-3 regex match → classify `in_scope=false` immediately, silently add to `diagnosed_ids` without invoking scope_check. Extends L38 procurement fast-drop to cover infosec/vuln SEVs that match OT regex via "heapsnapshot" or "[memlab]" keywords. When scope_check is degraded these SEVs still get manual-assessed every run without this guard. Source: S668375 "[memlab] RCE via eval() ... .heapsnapshot" matched step-3 via "heapsnapshot" keyword.

18. [2026-05-28 L55] **CASD-hedwig fast-path exclusion after step-3 "hedwig" match.** After step-3 regex matches on "hedwig" keyword, if title contains `casd` (case-insensitive) → classify `in_scope=false` immediately, silently add to `diagnosed_ids` without invoking scope_check. CASD-hedwig SEVs are web-service/fetch SEVs unrelated to OT Hedwig publish path (OT Hedwig patterns P07/P15 are about model-weight streaming to serving, not CASD fetch). Source: S668703 "hedwig = casd fetch/web SEV, not OT pipeline" — required manual-scope-assessment when scope_check was degraded.


## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)
