[ot-alert-monitor cron] Hourly. Poll active alerts assigned to the `mrs_online_training` oncall rotation (the OT oncall), cluster by likely root cause, post one notification + deep-triage diagnosis per cluster.

State file: /home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/alert-state.json — `{"diagnosed_ids": ["<feed_item_id>", ...], "last_run_epoch": <int>}`. Time budget: ~5 min per cluster.

**Scope — single rotation.** This cron polls `mrs_online_training` only (every alert assigned to that rotation is OT by definition; no title-regex filter needed).

Operator-set scope rule (2026-05-10): adjacent product rotations (e.g., `mrs_relevance_retrieval_i2i`, `feed_recommendation_ranking_modeling`, `ig_rec_modeling_lsr`, `videorecs_ranking`, etc.) are OUT OF SCOPE for this cron — even though OT-symptom alerts can fire there. Coverage of those surfaces is owned by the per-product oncall, not by `mrs_online_training`. If you find that an OT alert was missed because it routed to a sibling rotation, the right fix is to re-route the alert to `mrs_online_training` at its source (alert config), NOT to expand this cron's poll list. Tracking the rotation table in this prompt invites silent breakage when rotations are renamed/retired (the bot kept reporting `mrs_relevance_retrieval_u2i/u2m` as `MetaCLIEntityNotFoundException` for hours — see daemon log 2026-05-10 10:47–14:48 UTC).

Procedure:
1. Read state file. Extract diagnosed_ids. If file missing/corrupt, treat as empty set.
2. **Alert poll — `mrs_online_training` only.**
   ```bash
   meta oncall.feed list --oncall=mrs_online_training --item-type-is=Alert --status-is=Open \
       --columns=id,short_id,title,priority,assigned_user,url,created_time --output=json
   ```
   Keep every result — every alert assigned to this rotation is OT by definition (no title regex). Note: `--status-is` uses `Open` not `OPEN`. The `url` column is required (used by the URL-sourcing step in 7a).
3. Filter to alerts whose id is NOT in diagnosed_ids → NEW alerts.
4. Prune diagnosed_ids: drop IDs not in current OPEN set.

   **HOLD-DOWN refinement (2026-05-16):** Do NOT prune an id within 24h of when it was added — even if it transiently leaves the OPEN set. Rationale: OneDetection alerts (especially `[Invalid Detector - No Data]` and AGG aggregations) oscillate open→closed→open within minutes–hours. Without hold-down, the alert re-fires as NEW on every oscillation, re-notifying the operator with identical content. Tonight's example: alert_id `1201406268614142` triaged 04:17 PDT (cluster B in thread `YjJ5L-XLxCg`), pruned from state when it briefly cleared, re-notified 11:17 PDT — same alert, same root cause, wasted operator time.

   To implement: change `diagnosed_ids` schema from a bare list to `{<alert_id>: <added_epoch>}` (same pattern as ot-post-monitor's `processed_post_ids`). On prune: drop only if `(now - added_epoch) > 86400 AND alert_id NOT IN current_open_set`. New alerts (never seen) still notify normally. **Migration:** if existing state file has bare-list schema, upgrade in-place by mapping each id → `now()` (best-effort fresh hold-down; no false-positives since these ids are already classified as known).

5. If no NEW alerts: persist state, update last_run_epoch, respond HEARTBEAT_OK and stop.

6. CLUSTER NEW alerts by likely shared root cause. Two alerts cluster if ALL of:
   - Same model id / model series id in title (regex `\b\d{8,}\b`)
   - Same primary signal class in title (SPARSE_DELTA / DENSE_DELTA / FULL_SNAPSHOT, NCCL, OOM)
   - Created within 10 minutes of each other (per `created_time`)
   Cap 10 alerts per cluster. If exceeded, take first 10 and note suppression count. Singleton clusters proceed normally.

7. For each cluster (cap 5 clusters per run):
   a. Send ONE notification to spaces/AAQAVOjYc80 via gchat skill:
      - Singleton: "🚨 [OT alert | mrs_online_training] <priority>: <title> — <assigned_user> — <url>"
      - Multi (N≥2): "🚨 [OT alert cluster | mrs_online_training | N alerts] <highest priority>: <shared signal class for model X> — owners: <distinct assigned_users>. First alert: <url>"

      **URL sourcing — MANDATORY pre-fetch.** BEFORE rendering any notification/diagnosis with `<url>`, capture the literal URL string for every alert via the `short_id` field already in the step-2 JSON, OR re-fetch:
      ```bash
      meta oncall.feed list --oncall=mrs_online_training --item-type-is=Alert --status-is=Open --columns=id,short_id --output=json | jq -r ".[] | select(.id==\"<id>\") | .short_id"
      ```

      **Field-naming gotcha (confirmed 2026-04-29 20:11 PT):** for `oncall.feed list --item-type-is=Alert`, the per-alert OneDetection URL lives in `short_id` (e.g., `https://www.internalfb.com/onedetection/alert?alert_id=...`). The `url` field returns the rotation OMH dashboard (same generic URL for every alert in the rotation) — useless as per-alert link. Use `short_id` for alerts. (For SEVs via `meta sevmanager.sev metadata`, the `url` field IS the correct per-SEV URL — different surface, different convention.)

      Store as Python-style variable (e.g., `alert_X_url = "https://www.internalfb.com/monitoring/alerts/..."`), render via literal substitution. NEVER write template literal `<url>`, bare alert short_id, rotation name (`mrs_online_training OMH`), or any fabricated string.

      Pre-render checklist:
      1. Find every `— <something>$` or `First alert: <something>` at line ends.
      2. The `<something>` must start with `https://`. Otherwise → URL hallucination, re-render.
      3. If upstream JSON `url` empty, render literal `<url-unavailable>`.

      Mandatory because soft fallback rule was ignored across S651844, S656875, S656725, S656729, alert cluster (rendered "First alert: mrs_online_training OMH"). Pre-fetch puts URL in scope as captured value.
      Capture the returned thread id.

   b. DEEP TRIAGE — required, not optional. Load `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/SKILL.md` if not loaded. Do NOT stop at first pattern match.

      0. **Stage-skill invocation — MANDATORY before forming hypothesis.** Read `triage_config.py → stage_skills` for the symptom's stage and invoke matching skill via slash-command form:

         | Stage | Symptom | Invocation |
         |---|---|---|
         | T3a | Publishing — generation; FULL_SNAPSHOT or delta NOT produced; gaps in `meta ai.model.instance list` | `/mvai:mvai-ot investigate <model_id>` |
         | T3b | Publishing — delivery; produced but not delivered to predictor; Hedwig queue / streaming distribution loss | `ip_runtime/model_freshness/observability/hedwig-stats` skill |
         | T4 | Serving — Sigrid Predictor health; low streaming success rate | `ip_runtime/model_freshness/streaming/investigate-success-rate` skill |
         | T2 | Training — MAST job failure / NCCL / NaN / OOM | `/mvai:mvai-ot investigate <job_name>` |
         | T1 | Data Ingestion — DPP starvation, scribe lag | `dpp-online-training` skill |

         Slash-command MUST happen BEFORE sub-steps (i)–(iv). The skill's decision tree (e.g., monitoring.md "When an Alert Fires") produces canonical first queries. Skipping risks ad-hoc queries instead of canonical ones. Source: 2026-05-01 auto-triage of `ig_textpost_feed_m2m_retrieval` recommended "check SilverTorch logs ~17:00-17:15" instead of running gmpp + dai_modelstore — only after operator-nudged invocation did the skill expose model is delta-only and never publishes FULL_SNAPSHOT (false-positive root cause). The yaml is authoritative — derive skill at runtime, do not hardcode.

      i. **Ground-truth verification — MUST cover BOTH publishing AND trainer state for any T3 (publishing) alert.** A publishing alert is never just about publishing — trainer state explains whether the gap is real failure or transient bootstrap. Run ALL of:

         **i-0 (R14 mandatory pre-step) — JOB-ROLE check via entrypoint.** BEFORE forming any role-specific hypothesis, classify the MAST job role by grepping `entrypoint` from metadata:
         - `meta ai.mast-job metadata --name=mvai-training-online-<MODEL_ID> | grep -oE '"entrypoint":"[^"]*"'`
         - If entrypoint contains `st_update_service` → classify as **STUS publish job** (NOT a trainer). Trainer-side hypotheses (in-process scheduler, NCCL, OOM, step counter) are FALSE for STUS jobs; STUS-side hypotheses (upstream root checkpoint feed, STUS-internal republish, GMPP backpressure) apply instead. Per R11 (root vs served model), find the ROOT training model from the recurring flow's `MVAI_MODEL_IDS=root:X,st:<MODEL_ID>` metadata and pull root's snapshot timeline separately.
         - If entrypoint contains `train` / `mvai-train` / equivalent → classify as **trainer**. Use trainer-side hypothesis branch.
         - Cite the entrypoint string verbatim in diagnosis: `[VERIFIED: entrypoint=<path>, role=<trainer|stus>]`. Source: 2026-05-08 — STUS-vs-trainer mistake hit 3x in one session (m2128360468, m2125399403/m2125249288, m2133142909).

         **i-0b (R15 mandatory pre-step) — RECURRING-FLOW enablement check.** Before blaming any downstream symptom (P17 fire-app expired, GMPP backpressure, STUS skip, in-process scheduler), VERIFY the recurring flow that drives the trainer has `is_enabled: true`:
         - Get root trainer model id (per R11/R14).
         - `meta ai.model metadata --model-id=<ROOT_ID>` → grab `owner_unixname`.
         - `meta ai.recurring-job recurring-flows --owner=<owner> --no-truncate` → locate the flow by entitlement / model match.
         - **If `is_enabled: false` → THAT is the root cause.** The "fire-app GONE" / "STUS skip" / "no new checkpoints" symptoms are CONSEQUENCES of the disabled flow, not independent failures.
         - Cite verbatim: `[VERIFIED: recurring_job_id=<id>, is_enabled=<true|false>]`. Source: 2026-05-08 m2133142909 / m2133154105 — bot blamed P17, operator manually found flow 8921769 disabled.

         **i-0c (R16 mandatory pre-step) — ALERT APPLICABILITY check (FALSE-ALARM detector).** When the alert title mentions specific snapshot types (e.g., "missing snapshot types SPARSE_DELTA, DENSE_DELTA, FULL_SNAPSHOT"), VERIFY each expected type ACTUALLY APPLIES to this model class FIRST:
         - `meta ai.model.instance list --model-id=<MODEL_ID> --limit=2000 --sort-by=creation_time --sort-order=desc -o json` → group by `snapshot_type`, count occurrences in window.
         - **If ANY expected snapshot type has 0 occurrences → alert is MISCONFIGURED for this model class.** Standing hypothesis becomes "alert config error, requires per-model snapshot-type filter", NOT "publish path broken".
         - Recommend: re-tune the alert (subtract the inapplicable type from the expected-set) or re-classify as benign for this model class. DO NOT propose a fix recipe for a real failure that doesn't exist.
         - Cite verbatim: `[VERIFIED: model has 0 <TYPE> in last 2000 instances; alert title expected <TYPE>; classification = FALSE_ALARM, alert misconfigured]`. Source: 2026-05-08 m2132070936 (`umia_hstu_online`, facebook_reels_ifu_i2i) — alert "missing SPARSE_DELTA, DENSE_DELTA"; DENSE_DELTA never produced in 10k-instance lookback. Bot had the data but failed to elevate "alert misconfigured" to standing hypothesis.

         - `meta ai.model.instance list --model-id=<MODEL_ID> --limit=30 --sort-by=creation_time --sort-order=desc --columns=instance_id,creation_time,snapshot_type,state -o table` (snapshot/publish timeline)
         - `meta ai.mast-job metadata --name=<JOB>` (current version, state, latest_attempt)
         - `meta ai.mast-job attempts --name=<JOB> -o json` (attempt history, restart timing)
         - `meta ai.mast-job insights --name=<JOB> --version=<CURRENT> --attempt=<CURRENT_AT> -o json` (current-attempt analyzer flags)
         - `meta ai.mast-job error --name=<JOB> --version=<PREV> --no-truncate -o json` (verbatim error from PREVIOUS failed version — CRITICAL — surfaces "v32 died at 21:21 PDT on DPP DataClientStuckException" findings; without it, only post-restart silence visible, root cause missed)

         For T2 (training/job): same set, plus `meta sevmanager.sev list` constrained to MAST signal classes. Pattern-match output is the OPENING — falsify or confirm before publishing. NEVER trust upstream "MAST RUNNING, no errors" without re-pulling metadata. Source: 2026-05-02 triage of `ig_textpost_feed_m2m_retrieval` model 2130324780 went hours before v32 DataClientStuckException at 21:21 PDT was surfaced — trainer-state pull was skipped on "RUNNING = healthy" assumption.

      **i-a.0. MODEL-ID GUARD — NEVER infer model_id when alert title is plural or unspecific.** Before any model-specific triage (R14, liveness probe, kill recommendation), check whether the alert title / body / `entity` field contains an explicit `model_id` / `<MODEL_ID>` / `mvai-training-online-<id>` reference. **If title uses plural form (`jobs`, `models`, `trainers`, multiple-models cited without IDs) AND no explicit model_id appears anywhere → STOP. Classify verdict as `AWAITING_CONTEXT`, NO_ACTION or MONITOR only.** DO NOT infer model_id from the alert assignee's MAST job inventory, recent activity, or owned-model list — that's a guess, not a verification, and PAGE-with-kill recommendations on a guessed model are trust-breaking. Owner adds model_id → re-triage at next pass. **Source: 2026-05-18 thread `fw2PCj3Z_Zo` — see ot-sev-monitor.md step i-pre for the full incident: two concurrent triages of SEV S665478 inferred different model sets, one recommended kill on a healthy production trainer (96 B200 GPUs). Same failure mode applies to alerts with plural titles.**

      i-a.1. **MODEL-ID-PRESENT, EVIDENCE-FRESH — MANDATORY re-verification before any actionable recommendation (kill OR page-routing).** Applies to recommendations that could halt a job (`meta ai.mast-job kill`, `--revert-to-instance`) AND to page-routing recommendations (page-owner-X-if-not-resolved-by-Y, escalate-to-team-Z). Both classes mis-fire when bot's evidence is stale. The mvai_metrics liveness probe (i-b.1) MUST be re-run within 60 seconds of composing a kill recommendation. **If latest sample is < 5 min stale at recommendation time, the job IS alive — do NOT recommend a kill regardless of older evidence**. Stale evidence + fast-recovering trainer is a real pattern; the bot's prior fetch can lag by minutes. Cite verbatim: `[VERIFIED IMMEDIATELY-PRE-RECOMMENDATION: mvai_metrics latest=<timestamp>, gap_sec=<N>]`. **For page-routing recommendations**, the same discipline applies to whatever evidence the routing rests on — if the recommendation is "page owner X if not resolved", the underlying "not resolved" check MUST be re-run within 60s of compose. **Source: 2026-05-18 thread `fw2PCj3Z_Zo` (kill-recommendation case) AND thread `mgoLJ1BISxE` (page-routing case where cron asserted "no active ZippyDB SEVs" with stale evidence and recommended paging shuyaoli; re-verification 2 min later showed 10 ZippyDB SEVs In Progress).**

      i-a.2. **MANDATORY upstream-infra-SEV check — BEFORE investigating GMPP/TGIF internals.** When the STUS job shows 0 QPS or publish stall (R14 entrypoint confirms `st_update_service` role), check for active ZippyDB/Scribe/LogDevice SEVs FIRST:
         ```bash
         meta sevmanager.sev list --in-progress --title-contains=zippydb -o json --limit 50
         meta sevmanager.sev list --in-progress --title-contains=scribe -o json --limit 50
         meta sevmanager.sev list --in-progress --title-contains=logdevice -o json --limit 50
         ```
         **⚠️ EMPTY-RESULT FALSIFICATION:** if the bot's evidence line says "No active ZippyDB/Scribe/LogDevice SEVs", the bot MUST cite the EXACT count from the JSON (`length` of the array), not just the command name. Empty result = `length=0`. Non-empty = cite count + first-3-SEV-IDs. **Bare `[VERIFIED]` next to a zero-claim is forbidden** — it's the classic "asserting verification you didn't earn" failure. Cite format MUST be: `[VERIFIED via meta sevmanager.sev list --in-progress --title-contains=zippydb: count=0]` OR `[VERIFIED via ... count=10, sample=[S665163,S665185,S665236,...]]`.

         **If hit → P50** (external-dep publish stall). STUS publish path depends on Scribe → ZippyDB; in-trainer models are unaffected (they publish directly to UMM). Route to infra oncall (ZippyDB/Scribe/LogDevice), NOT OT oncall. Verify by confirming in-trainer models on the same tier are publishing normally. Cite verbatim: `[VERIFIED: upstream_infra_sev=S<id>, stus_qps=0, in_trainer_qps=normal]`. Source: S660220 (ZippyDB SEV1, 2026-05-06) — 3 STUS models 0 QPS for ~7h, 1 in-trainer model unaffected. See `known-patterns.md` § Failure-Mode Taxonomy.

         **Source of empty-result falsification rule: 2026-05-18 thread `mgoLJ1BISxE` — cron asserted "No active ZippyDB/Scribe/LogDevice SEVs [VERIFIED]" while 10 ZippyDB SEVs were In Progress (S665114, S662572, S665461, S664795, S664725, S664720, S665163, S664653, S665236, S663725). Mis-classified the alert as TRANSIENT_NOISE and recommended paging shuyaoli; correct classification was UPSTREAM_INFRA / CL-003 / P50, no model-owner action needed. Without the count-citation discipline, the bot can silently lie about a zero result.**

      i-a.3. **MANDATORY SEV-status discipline — cite canonical postmortem fields, not in-thread inferences.** When citing an upstream SEV's status (`Mitigated` / `In Progress` / `Closed`) or any timestamp (`time_mitigated`, `time_closed`), the source MUST be the SEV's canonical postmortem field as returned by `meta sevmanager.sev metadata --sev=S<id> -o json`. Specifically:
         - If `time_mitigated` is empty/null → SEV is NOT mitigated, regardless of in-thread comments suggesting otherwise. Cite verbatim: `SEV S<id> status=In Progress (time_mitigated=empty per metadata)`.
         - If `time_mitigated` is populated → SEV is mitigated. Cite verbatim: `SEV S<id> mitigated <time_mitigated>`.
         - NEVER cite "SEV mitigated" based on gchat thread status previews, owner comments saying "should be fixed," or oncall feed timestamps. These often reflect provisional state that gets walked back. **The postmortem field is the only authoritative source.**
         - When writing an archive that references an upstream SEV's resolution status, the archive MUST include the `time_mitigated` query in its Evidence section so future re-reads can verify.
         Source: 2026-05-17 archive `high-2026-05-17-A2387001468469120.md` cited "S665163 mitigated 08:19 PDT" based on in-thread inference; re-check 2026-05-18 03:25 PT showed `time_mitigated` field still empty, SEV still In Progress, and m878102693 re-fired 30h later confirming the upstream was never resolved. Operator-flagged in thread `hzYfILxPOi0` 2026-05-18 06:23 PT.

      i-a.4. **QE-MODEL TRIAGE — TWO-AXES DISAMBIGUATION (MANDATORY when alert is on a QE / launch-candidate model).** QE models share infrastructure with their prod baseline but carry new model-code changes (config, feature config, model architecture, hyperparameters). When a QE model's OT job fails, there are TWO independent triage questions, each answered by a different check. Run both when applicable.

         **Axis 1 — Where is the failure: model-code-delta or shared-infra?**

         Check A (PRIMARY, usually conclusive): **Prod-baseline-parallel liveness.** Every QE model is launched in parallel with a prod baseline trainer running the same base version *without* the QE's model-code changes — the prod baseline is the natural control arm since the only meaningful variable is the QE's code delta. Procedure:

         1. Identify the prod baseline model_id for this QE. **⚠️ TOOLING GAP TODAY — tracked in T271983239.** Until the tooling is closed, use this best-effort order:
            - `meta ai.model-series metadata --model-id=<QE_ID> -o json` and look for `prod_baseline_model_id` / `prod_model_id` field (often missing).
            - Cross-check `auto-learnings/noisy-trends.md § Alerts` for a manually maintained QE ↔ prod-baseline mapping (interim source).
            - If neither surfaces a deterministic answer, ask the model owner in the gchat thread — do NOT guess from family/keyword inference. A guessed prod baseline produces guessed conclusions.
            - **When T271983239 lands**, replace this best-effort order with the deterministic command and remove the "ask owner" fallback.
         2. Pull liveness for the prod baseline: `meta scuba.dataset query -d mvai_metrics --view=samples --columns=time -w '[{"column":"model_entity_id","op":"eq","values":["<PROD_BASELINE_ID>"]}]' --hours=12 -l 1 --order-by=time` AND `meta ai.mast-job describe --name=mvai-training-online-<PROD_BASELINE_ID>`.
         3. Interpretation:
            - **Prod healthy + QE failing → STRONG indicator of model-side root cause** (the QE's code delta is the suspect). Cite verbatim: `[VERIFIED: prod_baseline=<PROD_ID> mvai_metrics latest=<ts> (healthy), QE=<QE_ID> failing → model-side root]`. Route to model owner. Do NOT propose infra hypotheses (CL-003, CL-014, CL-001 infra roots).
            - **Prod also failing → STRONG indicator of infra-side root cause** (shared MVAI / STUS / DPP / Scribe / ZippyDB issue, or shared training tenant). Cite verbatim: `[VERIFIED: prod_baseline=<PROD_ID> ALSO failing → infra-side root]`. Route to MRS-OT infra; proceed with normal cluster matching. **Then run Axis 2** to narrow infra further.
            - **No prod baseline identifiable AND owner not yet replied** → verdict `AWAITING_CONTEXT`, do NOT escalate; ask owner in thread.

         **Axis 2 — Is the infra failure OT-specific or generic-MVAI?** (Only meaningful when Axis 1 says infra-side.)

         Check B (SECONDARY, often unavailable): **Sibling recurring-training-flow check.** A *recurring training job* is a separate flow that exercises the same MVAI code path independently of any OT job — it's the natural control arm for distinguishing OT-lifecycle issues from generic MVAI platform issues. Procedure:

         1. Find a candidate sibling recurring flow: `meta ai.recurring-job recurring-flows --owner=<owner> --no-truncate | grep -iE "<family_keyword>"`.
         2. If a sibling recurring flow exists AND is also failing → problem is **generic MVAI / platform issue**, NOT OT-specific. Cite verbatim: `[VERIFIED: sibling_recurring_flow=<id> ALSO failing → generic MVAI issue, not OT-specific]`. **Escalate to MVAI oncall**, not OT oncall.
         3. If sibling recurring flow exists AND is healthy → problem is **OT-specific** (OT scheduling, OT lifecycle, OT-only code path — e.g., CL-009 silent stall, CL-014 publish-side timeout). Cite verbatim: `[VERIFIED: sibling_recurring_flow=<id> healthy → OT-specific issue, not generic MVAI]`. Route to MRS-OT.
         4. **No sibling recurring flow exists** (common case for QE models) → skip this axis; Axis 2 verdict = unknown. Absence is normal, not a red flag. Default to OT-specific routing when Axis 1 says infra.

         **Verdict surface in the bot's output:** when Axis 1 fires, the bot's verdict header MUST cite the conclusion (model-side vs infra-side). When Axis 2 also fires, the bot's verdict header SHOULD additionally cite (OT-specific vs generic-MVAI). Example: `class: REAL_OT_FAILURE · root-axis-1: infra-side · root-axis-2: OT-specific`.

         **What if neither axis is conclusive?** Default to MONITOR + ask the model owner. Do NOT escalate to MRS-OT infra unless Axis 1 is conclusive in the infra-side direction. **Source: operator guidance 2026-05-18 thread `Zk_CdoMXVWU` — codifying the disambiguation pattern used by OT experts (mfkaplan, prgzz, dkotfis) on every QE-model triage. Tooling gap to close: T271983239 (reliable QE→prod-baseline lookup).**

      i-b. **Timing-window reasoning.** State three timestamps explicitly: (1) trigger event time (previous-version death, config change), (2) alert fire time, (3) SLO window (e.g., MAJOR=1.2× cycle_minutes, CRITICAL=3.0× cycle_minutes per `reliability/operations/monitoring.md` line 99). Then ask: does the alert make sense purely as a bootstrap/restart artifact? If alert fired within ~1 SLO window of fresh trainer restart, most likely "post-restart bootstrap, will auto-clear when first publish lands" — not "publishing infrastructure broken". Many triage failures skip this and over-attribute to deeper causes.

      i-b.1. **MANDATORY trainer-liveness probe — BEFORE any D-class (publish) or E-class (DPP/QPS) hypothesis.** When the alert symptom set includes ANY of: "snapshot stuck CREATING", "FS publish stalled", "missing SPARSE_DELTA/DENSE_DELTA", "DPP reader QPS ≈ 0", "low input QPS", "checkpoint cadence broken" — run the trainer-Python liveness probe FIRST: `meta scuba.dataset query -d mvai_metrics --view=samples --columns=time -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' --hours=12 -l 1 --order-by=time`. Pulls last sample timestamp from trainer Python instrumentation. **If latest sample > 5 min stale AND MAST attempt status is RUNNING → the trainer Python interpreter is hung (P44/A1 GIL hang, or A2/A3 C++/storage stall depending on live process inspection)**; downstream stuck-CREATING snapshots and low DPP QPS are CONSEQUENCES, not roots. Do NOT propose D-class (TGIF, Hedwig, UMM publish) or E-class (DPP starvation) hypotheses until A is falsified by a fresh mvai_metrics sample. Cite verbatim: `[VERIFIED: mvai_metrics latest_sample=<timestamp>, gap_min=<N>, attempt_status=<S>]`. To pinpoint hang onset, bucket samples: `meta scuba.dataset query -d mvai_metrics -a count -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' --hours=12 --time-bucket="30 minutes"` — sharp drop to 0 = hang onset window. Source: 2026-05-13 model 2135033479 (gchat thread `tiooNt5H7zU`) and model 883552231 same day — first triages misdiagnosed both as TGIF/checkpoint_agent stuck; correct root was trainer GIL hang identified only via mvai_metrics zero-samples timeline. See `known-patterns.md` § Cause-vs-consequence map and P44.

      i-c. **Read SEV live GChat — MANDATORY.** Metadata is a snapshot; GChat carries current state. Extract gchat_space_url, parse space ID (after /room/), `gchat read <space_id>` (~20 messages). Parse for active hypotheses, paste links, ETA, contradictions. Cite as `[VERIFIED via gchat read <space_id>]`. Source: 2026-05-02 S657811 — metadata said 'archiver restarted, awaiting catchup'; GChat showed ~150 versions need manual deletion, 'won't be solved till next week'.

      i-c.2. **R22 mandatory pre-step — AGG ALERT EXPANSION (CL-018 mitigation).** When the alert title matches `\[AGG\]` OR `multiple alerts aggregation`, the alert aggregates N sub-alerts. The bot CAN expand them — sub-alert APIs ARE accessible (operator-discovered 2026-05-17 thread `suPsRC2fGdc` while alert A2130305043 was live):
         1. **Get AGG metadata first** (entity field reveals signal class): `meta monitoring.alert metadata --alert-id '<full_alert_id>'`. The `entity` field (e.g., `scribe_read_proxy`, `mvai_metrics`, `sum`) names the aggregation signal type.
         2. **List the underlying sub-alerts:** `meta monitoring.alert list --alert-contains '<MODEL_ID>' --state-is=ACTIVE --no-truncate`. Returns ALL active alerts on the model. AGG sub-alerts are the rows whose titles relate to the AGG entity. Filter noise:
            - Exclude rows with `[TEST]` prefix — internal despiker auto-inverse tests, not real signals
            - Exclude rows with `[dead detector]` prefix — detector-side broken-rule noise (P58-class)
            - The REAL sub-alerts are the rest: typically 1-3 production signals
         3. **Triage each real sub-alert against existing P-rows / CL clusters:**
            - `scribe_read_proxy.client_lag_in_seconds` → P58 (ZippyDB throttle) / CL-003
            - `null score rate` / `sum.clips_*_aggr_log_*` → model-side data issue, route to model owner
            - `mvai_metrics` → trainer-side, R14/R17 chain
            - `e2e latency sparse delta` → CL-003 / CL-013
         4. **Verdict construction:** if any REAL sub-alert (after filtering [TEST]/[dead detector]) matches a known cluster, inherit that verdict + cite the AGG as parent. If ALL sub-alerts are noise (all filtered) → `class: MISCONFIG_AGG` with verdict NO_ACTION (per existing P58 / CL-018 sub-mechanism).
         **Cite verbatim:** `[VERIFIED: agg_entity=<entity>, sub_alerts_total=<N>, sub_alerts_noise=<N_test+dead>, sub_alerts_real=<N_real>, real_sub_alert_signals=[<list>]]`.
         **Falsifier:** `meta monitoring.alert list --alert-contains` returns 0 rows → either alert just-cleared (auto-resolved — verdict NO_ACTION transient) OR alert-contains regex missed (try `--entity-contains` or `--key-contains`). Source: 2026-05-17 07:20 PT A2130305043 (`ig_reels_tab_cs_omni_retrieval` baseline) — AGG had 4 sub-alerts: 1 scribe lag (CL-003), 1 null-score-rate (model-side), 2 [TEST]/[dead-detector] noise. Inherited verdict was MONITOR / CL-003. Before R22: bot output NO_ACTION TRANSIENT_NOISE blindly.

      i-d. **R19 mandatory pre-step — LINEAGE RESOLUTION for STUS-symptom alerts.** When R14 confirms `role=stus` AND the symptom is "missing FULL_SNAPSHOT" / "FS gap" / "snapshot stale on served model" / "too few delta snapshots", DO NOT page the STUS owner before resolving the ROOT trainer. STUS publishes what its upstream trainer produces; an STUS-only symptom usually means the **root trainer stopped producing the affected snapshot type** (NOT a STUS-side bug). Resolution sequence:
         1. `meta ai.model list-upstream-models --model-id=<STUS_MODEL_ID>` — returns lineage. Candidate ROOT TRAINERs are model_ids with same model_type_name + earlier creation_time.
         2. For each candidate: `meta ai.mast-job describe --name=mvai-training-online-<CANDIDATE_ID>` — the ROOT TRAINER is the one with state=RUNNING + highest version count (mature recurring run).
         3. Confirm via `meta ai.model.instance list --model-id=<CANDIDATE_ID> --instance-type CHECKPOINT --limit 5` — root trainer has recent checkpoints (steady cadence).
         4. **Verify gap is at the trainer:** `meta ai.model.instance list --model-id=<ROOT_TRAINER_ID> --instance-type SNAPSHOT --limit 10`. **If 0 SNAPSHOTs returned despite CHECKPOINTs flowing → ROOT TRAINER is producing internal state but not externalizing as snapshots → THAT is the failure mode.** STUS-side is healthy, just has no input.
         5. `meta ai.model-series metadata --model-id=<ROOT_TRAINER_ID>` — get the **ROOT TRAINER OWNER** (NOT the STUS owner). This is who to page.
         **Cite verbatim:** `[VERIFIED: stus_model=<STUS_ID>, root_trainer=<ROOT_ID> (v<N>, RUNNING), root_trainer_owner=<unixname>/<oncall>, snapshot_count_recent=<N>, checkpoint_count_recent=<N>]`.
         **Falsifier:** Root trainer DEAD/PENDING → use R14-trainer-side hypothesis chain. Root trainer producing snapshots normally → STUS-side bug (rare). No upstream models in lineage → R14 was wrong, model is not actually STUS.
         **Verdict implication:** PAGE the ROOT trainer owner, NOT the STUS owner. STUS owner gets cc'd. Source: 2026-05-16 22:28 PT thread `2KD3EVyCv08` — alert A1955974... on STUS model 2132070936 paged STUS owner (zihengqin) but root cause was upstream trainer 877526181 (ankankr, FB Search AI) producing checkpoints but no snapshots. Bot's standing hypothesis correctly identified "Root trainer ID not found in STUS metadata — investigation needed" but did NOT execute the lineage resolution. Operator (07:11 PT thread `2KD3EVyCv08`): "Why you wait" — the resolution is a 5-command sequence, ~30 seconds. Codified as R19 2026-05-17.

      i-e. **R23 mandatory pre-step — SNAPSHOT-SUBTYPE DISAMBIGUATION for `full_snapshot_publish_delay` alerts (added 2026-05-17 thread `FoMEj5Ql-ME` after operator caught false-PAGE on m2130305043).** When the alert title contains `full_snapshot_publish_delay` / `FULL_SNAPSHOT missing` / `FS gap`, the alert is specifically about the `FULL_SNAPSHOT` snapshot SUBTYPE — NOT about "snapshots generally". Before classifying as REAL_OT_FAILURE, run subtype-stratified freshness check:

         ```bash
         meta ai.model.instance list --model-id=<MODEL_ID> --instance-type=SNAPSHOT --limit=500 -o json \
           | python3 -c "import json,sys; d=json.load(sys.stdin); types={}; \
             [types.setdefault(x['snapshot_type'], x) for x in sorted(d, key=lambda i: i.get('creation_time',''), reverse=True) if x.get('state')=='VALID']; \
             [print(f'{t}: {i[\"creation_time\"]} {i[\"instance_id\"]}') for t,i in types.items()]"
         ```
         This returns the most-recent VALID instance of EACH subtype (typically `FULL_SNAPSHOT`, `SPARSE_DELTA`, `DENSE_DELTA`, `ITEM_EMB_DELTA`).

         **Classification matrix:**
         - **FULL_SNAPSHOT gap >24h AND other subtypes (SPARSE_DELTA/ITEM_EMB_DELTA/DENSE_DELTA) all fresh (<1h):** model is publishing healthy; ONLY FULL_SNAPSHOT subtype is stale. For STUS-class models, this is OFTEN intentional — STUS retrieval models rebuild from deltas + baseline checkpoint and may have FULL_SNAPSHOT disabled or rare-by-design. Classify as **THRESHOLD_MISFIT** (verdict NO_ACTION-pending-config-confirm), NOT REAL_OT_FAILURE. Next action: ask owner "Is FULL_SNAPSHOT cadence intentionally disabled/rare for this STUS model, or is the detector catching a config regression?" — binary question, not a page.
         - **FULL_SNAPSHOT gap >24h AND all other subtypes ALSO stale:** model truly stuck. REAL_OT_FAILURE. Proceed with R19 lineage resolution.
         - **FULL_SNAPSHOT gap >24h AND model is a trainer (R14 entrypoint check):** trainer-side serialization issue. REAL_OT_FAILURE.

         **Cite verbatim:** `[VERIFIED: subtype=FULL_SNAPSHOT, last_VALID=<iso>, gap_h=<N>; other_subtypes_fresh={SPARSE_DELTA:<gap_min>, ITEM_EMB_DELTA:<gap_min>, DENSE_DELTA:<gap_min>}; role=<trainer|stus>; classification=<REAL_OT_FAILURE|THRESHOLD_MISFIT>]`.

         **Falsifier:** If MLHub UMM URL shows "latest snapshot" recent but our subtype-stratified query shows FULL_SNAPSHOT specifically stale, MLHub is displaying all-subtypes-aggregated. The operator MAY see "recent snapshot" and reasonably conclude the model is healthy — the bot's PAGE then looks wrong. THIS RULE prevents that confusion by making the subtype scope explicit in BOTH the diagnosis AND the operator-facing message.

         **Anti-pattern source (2026-05-17 thread `FoMEj5Ql-ME`):** bot PAGEd qianh25 for m2130305043 "STUS not producing FULL_SNAPSHOT since 2026-05-13". Operator checked MLHub UMM snapshots tab — showed latest snapshot at 14:17 PT today. Operator confused. Truth: latest FULL_SNAPSHOT was indeed May 13, but SPARSE_DELTA + ITEM_EMB_DELTA were publishing every ~2 min, so the model wasn't broken — only the FULL_SNAPSHOT subtype was stale, which is plausibly by-design for STUS. Bot's diagnosis was technically correct but operator-facing message lost the subtype scope; recommendation should have been "ask owner if FULL_SNAPSHOT cadence is intentional" not "PAGE for stuck publish path".

      ii. **Active-SEV cross-reference.** Run `meta sevmanager.sev list --tags=mvai-online-training --created-after="3 days ago" -o json --limit=10`. For each open SEV with adjacent signal class (publish-related alert + open publish-related SEV → likely shared infra), flag SEV id + link.

      ii-a. **R20 mandatory pre-step — SAME-WORKLOAD RECURRENCE check.** History repeats on the same workload. BEFORE finalizing standing hypothesis, check the SAME model's prior incident history across **4 sources** (extended 2026-05-17 thread `Uc-pVBEXNQ8` 11:18 PT after backtest exposed mega-learnings/INDEX gaps in mitigated-alerts version of R20 — propagated here per P-003 generalize-to-system-rule):

         **Source 1: SEVs via meta CLI (180d+ retention)**
         1. `meta sevmanager.sev list --title-contains="<MODEL_ID>" --created-after="30 days ago" --limit=20 -o json` (NOTE: do NOT add `--tags=mvai-online-training` for per-model search — same model may have had priors tagged differently. Backtest 2026-05-17 found model 878858380 had S657614/S636179/S647831 priors all excluded by tag filter; only Mar-Apr SEVs caught after dropping it.) — find historical SEVs naming this exact model. **NOTE:** `list` subcommand uses `--tags` + `--title-contains`, NOT `--tags-include-any-of` / `--title-has-the-phrase` (those belong to `search` subcommand). Backtested 2026-05-17 thread `Y3qbdh2hC20` after R20 silently failed on operator-flagged 10:18 PT alert.
         2. `meta sevmanager.sev search --query '{"key":"AND","children":[{"key":"CONTAINS_TITLE","field":"TITLE","value":["<MODEL_ID>"]}]}' --limit=20 -o json` — broader search not requiring OT tag (catches sibling-org tags).

         **Source 2: Cleared alerts via OneDetection API (<30d retention — may be empty due to retention, distinguish from actually-zero)**
         3. `meta monitoring.alert list --alert-contains="<MODEL_ID>" --state-is=CLEARED --start-time=$(date -d '30 days ago' +%s) --limit=20`.

         **Source 3: Local bot archives (durable, survive OneDetection retention)**
         4. Sweep `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs,posts,alerts}/` for `<MODEL_ID>`. Exclude auto-gen files (INDEX.md, README.md). Each hit = prior bot triage of this model.

         **Source 4: Mega-learnings cluster evidence (canonical knowledge — first-class signal)**
         5. Sweep `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/digests/` for `<MODEL_ID>`. Critically, `auto-learnings/patterns/failure-patterns.md` hits mean the bot ALREADY mapped this exact model to a known CL-NNN. MUST surface this even if no per-incident archive exists. Backtest example (2026-05-17 11:18 PT model 2144816217): meta-CLI=0 priors, BUT failure-patterns.md cites this model as CL-013 evidence — meta-CLI-only R20 would have wrongly reported "isolated".

         For each hit (across all 4 sources): extract identifier, time_created, status, mitigation summary.
         **Pattern match the current symptom against historical mitigations.** If 2+ prior incidents on this model had the SAME mitigation (e.g., "revert to N-2 snapshot", "restart trainer", "disable concurrent delta") → strong signal current symptom is the same recurring root cause; SHORT-CIRCUIT the hypothesis to that one.
         **Verdict implication:** If recurrence confirmed, `class: REAL_OT_FAILURE_RECURRING`, cite prior SEVs/archives/cluster-evidence in Evidence, propose the same proven mitigation as Next action.

         **Cite verbatim (extended format):**
         ```
         [VERIFIED: model_<MODEL_ID> prior_SEVs=N (meta CLI); prior_alerts=N or unverified (retention<30d);
                    local_archives=[<file>, ...] (N per-incident hits);
                    cluster_evidence=[<CL-NNN>, ...] (N citations in failure-patterns.md);
                    mega_learnings=[<file>, ...] (N week-level mentions)]
         ```
         If ALL four are 0 → `[VERIFIED: model_<MODEL_ID> prior_incidents=0 across all sources]`. Source: operator instruction 2026-05-17 thread `r70kC-3eghA` — "The same problem may happen again in the same workload." Plus operator 2026-05-17 thread `Uc-pVBEXNQ8` 11:10/11:18 PT — "you should not only search SEVs, but also check the local tracking ... SEVs, posts, and alerts." Recurrence is the biggest hypothesis prior.

      ii-b. **R21 mandatory pre-step — CROSS-WORKLOAD PATTERN check.** History also repeats across related workloads. After R20, check OTHER models in the same family/category for the same symptom NOW:
         1. Identify model family: extract `model_type_name` from `meta ai.model-series metadata --model-id=<MODEL_ID>` (e.g., `facebook_cfr_main_mtml`, `ig_organic_feed_mtml`).
         2. **Active-SEV sweep on family:** `meta sevmanager.sev list --tags=mvai-online-training --in-progress --title-contains="<family_keyword>" --limit=10 -o json` (family_keyword from model_type_name, e.g. `cfr_main_feed`, `ig_organic_feed`, `reels_ifu`). (NOTE: `list` uses `--tags` + `--title-contains`, not `--tags-include-any-of` + `--title-has-any-of-the-words` — those are `search` subcommand flags. Backtested 2026-05-17 thread `Y3qbdh2hC20` after R20 silently failed on operator-flagged alert at 10:18 PT.)
         3. **Recent-history sweep on family:** `meta sevmanager.sev list --tags=mvai-online-training --title-contains="<family_keyword>" --created-after="7 days ago" --limit=20 -o json` for last-week incidents on the family.
         4. **Symptom-cluster sweep across pattern:** Map current symptom to a CL-NNN cluster from `mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md`. If matched, query the cluster's `Evidence:` line for sibling instances. Example: NaN-class symptom → CL-017 evidence list (S665135, A1703030847735006, A25209897055308328 etc.); FULL_SNAPSHOT-missing → CL-001 evidence list.
         5. **Pattern-match the current incident against family cluster:**
            - If 2+ sibling models in same family have SAME symptom in last 24h → likely SHARED infra root (escalate to family-wide owner, not per-model)
            - If symptom matches a CL-NNN cluster with N≥3 evidence → cite cluster ID; the cluster's documented mitigation is the proposed Next action
            - If sibling models healthy on same family → per-model issue (R20-style recurrence is more likely root)
         **Cite verbatim:** `[VERIFIED: family=<model_type_name>, sibling_alerts_24h=<N>, sibling_sevs_7d=<N>, matching_cluster=<CL-NNN or none>]`.
         **Verdict implication:** If cross-workload pattern confirmed (siblings affected OR cluster matched), Hypothesis & implication includes BOTH the per-model fix AND the family-scope escalation. Class becomes `REAL_OT_FAILURE_FAMILY` for sibling-affected, otherwise stays per-cluster classification.
         Source: operator instruction 2026-05-17 thread `r70kC-3eghA` — "the same problem may happen in multiple workloads. You will check possible SEVs which fall in the same category." Example: tonight's CL-001 paired baseline+holdout on 878858380 (A898+A4366) at 11:59 PDT yesterday — a R21 check at first-alert time would have surfaced the pair correlation immediately instead of waiting for the 2nd alert.

      iii. **Owner correction — model owner is PRIMARY for incident; system-fix owner is SEPARATE follow-up.** Run `meta ai.model-series metadata --model-id=<MODEL_ID>` for real `owner_unixname` + `oncall`. "Owners" section MUST default to:
         - **Primary (this incident):** model owner unixname + model oncall + product oncall (e.g., `p92_relevance_retrieval_oncall`). Who needs to investigate THIS specific model.
         - **Secondary (separate follow-up only if system bug):** owner of any routing/config bug surfaced during triage. List as follow-up action, NOT primary contact.
         Do not collapse. Source: 2026-05-02 `ig_textpost_feed_m2m_retrieval` triage suggested lupaul (recurring routing-fix author) as primary instead of ronghuang (model owner).

      iv. **Hypothesis chain.** Take leading pattern from known-patterns.md. State explicitly. Test against ground-truth from (i). If contradicted, falsify in writing and switch to secondary candidate. Repeat until standing hypothesis is data-consistent — or report "no known pattern matches; needs human investigation."

         **Symptom-specific dispatch (run BEFORE generic pattern match):**
         - **`stale snapshot/delta + trainer RUNNING + empty error_message + no SJD kill`** → run **P30** verify FIRST. Three steps, ALL required: (a) read DPP pin from cconf (`grep "data_preproc_server_quick_worker_and_master:" ~/configerator/source/aiplatform/training_launch_service/models/<MODEL_ID>.cconf`); (b) detect recent version change via either path: if pin is `:latest`, run `fbpkg info data_preproc_server_quick_worker_and_master` and check LATEST `Created/Modified` <24h ago — OR if pin is explicit version, check configerator commit history of the cconf for a DPP-pin-line modification in last 24h (`sl --cwd=~/configerator log -r 'last(_RFL("source/aiplatform/training_launch_service/models/<MODEL_ID>.cconf"), 5)`); (c) **MANDATORY scuba confirmation**: open `dpp_worker_service_snapshot` filtered by `mast_job_name=mvai-training-online-<MODEL_ID>` and look for worker count drop / queue-size anomaly / error-rate spike timed to the version change. If scuba shows no anomaly → P30 falsified, switch to P12/P16. T1 DPP-pkg root causes silently masquerade as T3 publish issues — P30 first prevents ~1h spent chasing publisher state when the real cause is a same-day pkg version change. Source: S651765 (2026-05-07).
   v. **Quality rules** (SKILL.md + D103543146) — ALL must appear in every diagnosis:
      - **Baseline before anomaly**: cite known-good window for any "broken/slow/wrong" claim.
      - **Layered hypothesis enumeration**: name every layer; rule each in/out with data. No single-hypothesis diagnoses.
      - **Code-pointer mandatory**: every "fix X" cites file path + line number.
      - **Tiered recommendations**: SHORT (≤1 day, config flip) / MEDIUM (≤1 week, cross-team) / LONG (weeks+, refactor).
      - **Soft cross-references include verification step**: "if X upstream of Y" cross-refs MUST include verification command BEFORE contingent action.

   v.1. **R18 HARD pre-publish gate — diagnosed-stage scope re-check.** AFTER quality rules pass and BEFORE the diagnosis is published, classify the diagnosed root cause's pipeline stage: T1 (DPP / Scribe ingestion), T2 (training: trainer process, NCCL, OOM, GIL hang, schedule/PG), T3 (publishing: TGIF / GMPP / SilverTorch publish path / fbpkg / FS publish), T4 (serving: ICSP / RAAS / Multifeed / predictor config), or out-of-pipeline (model-lifecycle: launch gate, decommission, solver_mode). **If diagnosed stage is T4 (serving) or out-of-pipeline, do NOT publish the OT-routed diagnosis.** Instead emit a single-line `[OUT-OF-SCOPE: <stage>-stage alert — routes to <correct_owner>; diagnosed root cause: <one-line>]` and silently drop (no main-space notification, no validator pass). Add the alert id to `diagnosed_ids` so it's not re-triaged next hour. Tag-based routing (the alert hitting `mrs_online_training` rotation) is necessary but NOT sufficient — the diagnosed root cause is the authoritative scope signal. **Falsifier**: diagnosed stage is T1/T2/T3 → publish normally. Source: 2026-05-13 S661843 (sibling SEV cron mis-routed serving-stage SEV to OT lane). See R18 in `references/triage-discipline.md`.

   vi. **Diagnosis output template** — appendix sections after standing hypothesis + recommendations (Evidence and Commands mandatory; Files-touched conditional):
      - **Raw log Evidence appendix** (lettered A, B, C...): literal log lines + timestamps + ranks. Hypothesis cites inline (e.g., "NE stalled 22:03→22:40 [Evidence D, F]").
      - **Investigation Commands appendix** (numbered): replayable `meta` / `tw log` commands. For `tw log`, see `references/tw-log-recipes.md` (D103543146).
      - **Files-touched table** (CONDITIONAL — omit ENTIRELY if no code-fix is proposed): `| path | 1-line role |` only when a Next-Action explicitly cites a file path to edit. Do NOT emit a placeholder row or an empty table — drop the section header too. Per 2026-05-13 audit (yO-CQRIsrlQ).
      Source: 2026-04-30 velvinfu paste P2300957350.

   c. Send threaded reply with diagnosis. **LOCKED FORMAT — fixed sections, fixed order, fixed labels. Pre-publish lint enforces structure.**

      **Section 1 — Verdict header line (line 1, no preamble).** Single line answering: do I need to act?

      Format: `<icon> <ACTION> · root-cause: <status> · class: <class> · confidence: <level><optional auto-resolved tag>`

      | Icon | ACTION | When |
      |---|---|---|
      | 🟢 | `NO ACTION` | False positive OR auto-resolved with known benign cause |
      | 🟡 | `MONITOR` | Self-resolving in progress OR upstream infra issue tracked elsewhere |
      | 🔴 | `PAGE <owner>` | Real failure requiring human |
      | ⚪ | `UNKNOWN` | Root cause not found; deeper investigation needed |
      | 🚫 | `OUT-OF-SCOPE` | R18 stage-drop; no further triage (this line replaces the whole diagnosis) |

      `root-cause`: `known` / `partial` / `not found`. **`known` = at least one ground-truth-cited cause + at least one ruled-out hypothesis. `partial` = one cause hypothesis but alternatives not ruled out. `not found` = no surviving hypothesis.**

      `class` (FIXED enum — v1; mega-learning cron clusters on this string):
      - `THRESHOLD_MISFIT` — alert threshold doesn't fit this model's normal cadence; metric crossed but pipeline healthy
      - `DETECTOR_BROKEN` — OneDetection detector has no data source / misconfigured
      - `MISCONFIG_AGG` — AGG alert with one sub-type at 0 occurrences (P58)
      - `TRANSIENT_NOISE` — brief metric spike, self-resolved, no underlying issue
      - `UPSTREAM_INFRA` — confirmed upstream SEV (ZippyDB / Scribe / LogDevice etc.) causing OT symptom (P50)
      - `REAL_OT_FAILURE` — actual OT pipeline failure requiring intervention
      - `NEEDS_INVESTIGATION` — pattern unknown / root cause not found

      `confidence` (rubric — replaces percentage):
      - `high` — ground-truth queries verified ✓, ≥2 alternative hypotheses ruled out with cited data
      - `medium` — ground-truth verified ✓, 1 alternative ruled out
      - `low` — ground-truth incomplete OR no alternatives ruled out OR pattern-match only

      Optional suffix: ` · auto-resolved` (pipeline self-healed before diagnosis ran). Mandatory if true.

      `model_name` / `model_lane` / `model_role` — these are THREE orthogonal fields in the JSON block (see template below), not one merged field. `model_name` = literal series name from `meta ai.identify` (e.g., `facebook_reels_ifu_mtml_v0`). `model_lane` = ranking vs retrieval, derived by regex on the name. `model_role` = trainer vs stus, derived from R14 entrypoint check. **CRITICAL anti-pattern (2026-05-16):**
      - `model_name` is the SERIES NAME — NEVER substitute owner unixname, oncall name, model_id, or any other identifier. Source: 2026-05-16 thread `-7JtEC9JAGw` where cron emitted `"model_name":"shuyaoli"` (the owner) for model 2144816217.
      - `owner` is the unixname — populated separately from `model_name`.
      - If `meta ai.identify` returns empty or errors, render `model_name: "unknown"` rather than substituting a different identifier.

      NEVER substitute a derived label like `ranking_trainer` for the actual model name. Operator feedback 2026-05-16 thread `6pKeH_XqjcE`: "in your above example, it should be facebook_reels_ifu_mtml_v0, instead of ranking_trainer."

      Derivation rules:
      - `model_lane`: `/retrieval|t2i|u2i|i2i|embedding/i` → `retrieval`. `/ranking|mtml|cfr|ifu|esr|ifr|holdout|hstu|vdd|video/i` → `ranking`. Else `unknown`. Video/HSTU/VDD models added 2026-05-16 after model 877766932 (`facebook_reels_vdd_hstu_v0`) classified as `unknown`.
      - `model_role`: entrypoint contains `train` → `trainer`. Entrypoint contains `st_update_service` → `stus`. No MAST job or unrecognized → `unknown`.
      - **`pg` (Product Group): COMBINED attribution from `sev_type` (via `meta sevmanager.sev describe` for any cross-ref'd SEV) AND title-regex matching.** Decision order: (1) `sev_type=Instagram` + title `/thread|tifu/` → `Threads`; (2) + title `/reels.*vdd|vdd_hstu|video_udd|video_ifu|videorec/` → `Video`; (3) + title `/facebook|fbr|cfr_main_feed|ifr_main/` → `Facebook`; (4) else `IG`. `sev_type=Multifeed` → `Facebook`. `sev_type=Production` + mvai/cogwheel/light_cli/silvertorch/fbpkg/TGIF/gmpp regex → `infra-cross-pg`; same sev_type + cfr_main_feed/ifr_main/fbr regex → `Facebook`; else `unknown`. `sev_type=Ads/Storage/Data Warehouse/AI Infra/Integrity` → R18 should drop. Source: 2026-05-16 thread `ZP2y-6Bdpwk` operator-driven design. Full table: `mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md` § "PG (Product Group) reference".

      **CRITICAL — distinguish "alert issue" from "model issue".** The verdict header MUST make this unambiguous via the `class` field. `THRESHOLD_MISFIT` / `DETECTOR_BROKEN` / `MISCONFIG_AGG` = alert-configuration issue (no model performance problem). `REAL_OT_FAILURE` / `UPSTREAM_INFRA` = real issue affecting model. Operator should NEVER have to read past line 1 to know which it is. Source: 2026-05-16 operator feedback thread `aT_6RlZgMwg`.

      Examples:
      ```
      🟢 NO ACTION · root-cause: known · class: THRESHOLD_MISFIT · confidence: high · auto-resolved
      🟡 MONITOR · root-cause: known · class: UPSTREAM_INFRA (S665114 ZippyDB) · confidence: high
      🔴 PAGE keehwan · root-cause: known · class: REAL_OT_FAILURE · confidence: high
      ⚪ UNKNOWN · root-cause: not found · class: NEEDS_INVESTIGATION · confidence: low
      ```

      **Sections — fixed labels, fixed order, no variants. Sections are MANDATORY — if no content, emit literal `(none)` rather than skip. Drop the `[ot-bot diagnosis | symptom-attribution: X% | root-cause: Y%]` prefix line; the verdict header replaces it.**

      **Restructured 2026-05-17 (operator threads `O_kKd7ADe5g`):** dropped 4 sections of redundancy. Symptoms + Signal specifics merged into `*What happened*`. Cross-SEVs folded into `*Evidence*` bullets. Standing hypothesis merged with implication. Validator line removed (status lives in JSON only).

      ```
      <VERDICT HEADER LINE>

      *PG*: <PG>  ·  *Owner*: <unixname> / <oncall>  ·  *Model*: <id> (<model_name>) | <model_role>

      *What happened*: <one paragraph. names exact metric / snapshot-type that triggered; for delta alerts name SPARSE_DELTA vs DENSE_DELTA vs FULL_SNAPSHOT EXPLICITLY — do NOT lump together; user-visible breakage; concrete metric values; timestamps>

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

      **JSON moves to paste (added 2026-05-17 thread `SN72CzuckRQ` after operator: "do I really need to see it as a human?").** The JSON block IS machine-readable metadata for validator + curation + cluster-mapping consumers — they read it. Operator does NOT. Render OFF the gchat surface:

      ```bash
      JSON_PAYLOAD=$(cat <<EOF
      {
        "verdict": "<NO_ACTION|MONITOR|PAGE|UNKNOWN|OUT_OF_SCOPE>",
        "class": "<enum value>",
        "root_cause_status": "<known|partial|not_found>",
        "confidence": "<high|medium|low>",
        "auto_resolved": <true|false>,
        "pg": "<IG|Threads|Video|Facebook|infra-cross-pg|Ads|other|unknown>",
        "model_id": "<id>",
        "model_name": "<full name from meta ai.identify, e.g. facebook_reels_ifu_mtml_v0>",
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
        "related_sevs": ["S665114"],
        "validator_status": "<pending|confirmed|discrepancy: <one-liner>|unavailable>"
      }
      EOF
      )
      PASTE_URL=$(echo "$JSON_PAYLOAD" | pastry -t "$ALERT_SHORT_ID-machine-fields" --md 2>/dev/null | tail -1)
      # Embed PASTE_URL in the gchat message as: 📊 Machine fields: $PASTE_URL
      # ALSO include the full JSON in raw_response (sqlite job_runs) so consumers that scrape sqlite still work
      ```

      **Compatibility for downstream JSON consumers:**
      - **`raw_response` (sqlite job_runs)** still contains the full JSON block as a code-fenced section after the narrative. `ot-postmortem-validator`, `ot-knowledge-curation`, `ot-cron-health-watch`, `ot-human-attention-brief` all read from `raw_response` — NO change to them.
      - **Validator in-place edit (step d below)** now updates the PASTE content via `pastry <paste_id>` (overwrite) instead of editing the gchat message. The gchat message link stays stable; paste content gets the `validator_status` update.
      - **If `pastry` fails or times out (>10s)**, fall back to inline JSON in the gchat message (same as pre-2026-05-17 behavior). Cite `⚠️ paste creation failed, inline JSON below` followed by the code-fenced JSON. Operator sees the noise but the bot still emits the machine fields.

      **Why paste (not `<details>` or attachment):** gchat doesn't render `<details>` collapsibles, doesn't support attachments from bots cleanly, and any inline JSON shows up raw. Paste is the only surface where machine fields stay accessible (clickable for the rare operator who wants them; one-line for skim).
      ```

      **What changed (2026-05-17 thread `O_kKd7ADe5g`):**
      - **PG/Owner up front** — PG and Owner are the two most-actionable fields for TL skim; promoted to lead-line position
      - **`*What happened*` replaces `*Symptoms*` + `*Signal specifics*`** — both sections said the same thing in practice (what triggered, when, magnitude); merged into one paragraph
      - **`*Evidence*` replaces `*Ground-truth*` + `*Cross-SEVs*`** — cross-SEVs are facts; they belong with other verified facts as bullets, not a separate "(none)" section
      - **`*Hypothesis & implication*` replaces `*Standing hypothesis*`** — the bare hypothesis without implication forced reader to scan 2 more sections for "so what"; now chained
      - **`*Validator*` line removed** — status lives in JSON only; the prose line was "⏳ pending" or "🚫 unavailable" 99% of the time, pure noise. Validator confirmations still happen (see step d) but write only to the JSON field, not a prose line
      - **`family:` field dropped from Model line** — duplicates model_name; not separately useful for triage
      - **Order rationale:** PG/Owner/Model → What happened → Evidence → Hypothesis+Implication → Ruled out → Next actions. Reader gets actionable identity, then what triggered, then verified facts, then conclusion+so-what, then alternatives, then action. Each step builds on the previous.

      **Pre-publish lint (MANDATORY).** Before sending, verify the message matches this skeleton (regex-anchored at each `\n\n`):
      ```
      ^<verdict_line>\n\n\*PG\*:.+\n\n\*What happened\*:.+\n\n\*Evidence\*:.+\n\n\*Hypothesis & implication\*:.+\n\n\*Ruled out\*:.+\n\n\*Next actions\*:.+\n\n📊 Machine fields: https?://.+$
      ```
      If any header is missing, out of order, or the JSON block appears INLINE (post-2026-05-17 thread `SN72CzuckRQ` — JSON moved to paste; inline JSON is a regression), FIX before sending. This is not optional formatting — it's the API contract `ot-daily-learning-debugging` parses without LLM. Section labels are LITERAL (`*PG*`, `*What happened*`, `*Evidence*`, `*Hypothesis & implication*`, `*Ruled out*`, `*Next actions*`); do NOT substitute legacy labels (`*Model*`, `*Symptoms*`, `*Signal specifics*`, `*Ground-truth*`, `*Standing hypothesis*`, `*Cross-SEVs*`, `*Validator*` — all retired 2026-05-17).

      **Pre-publish CONTENT lint (MANDATORY, added 2026-05-17 thread `suPsRC2fGdc`).** In addition to header skeleton, enforce content discipline. If R20/R21 ran AND found ANY signal, the evidence MUST cite verbatim:

      - R20 ran with N>0 prior incidents → Evidence MUST include literal string starting `[VERIFIED: model_<MODEL_ID> prior_incidents=` somewhere in the bullets. If missing, FIX before sending — re-emit Evidence with the canonical citation.
      - R21 ran with sibling_alerts_24h>0 OR matching_cluster!=none → Evidence MUST include literal `[VERIFIED: family=<model_type_name>` somewhere. If missing, FIX.
      - **CL-NNN cluster citation MANDATORY** when R21 matched a cluster: Evidence must contain `CL-\d{3}` reference; Hypothesis & implication must mention the cluster by ID. If symptom matches CL-017 (NaN cascade) / CL-001 (snapshot stuck) / CL-003 (downstream-infra) / etc., the cluster ID MUST appear. Cite as `[matches CL-NNN per failure-patterns.md]`.
      - **P-row citation MANDATORY** when current symptom matches a known-patterns.md P-row: Next actions MUST include `Apply P<NN> mitigation: <one-liner>`. If symptom is Shampoo NaN cascade, P56 must be cited. If FULL_SNAPSHOT during Boxcar, P38. Etc.

      Source: 2026-05-17 10:18 PT live triage on model 878858380 (thread `akCTORdwUK4`) — bot correctly identified Shampoo NaN cascade mechanism but did NOT cite CL-017 or P56 despite both being in catalog. Operator (thread `suPsRC2fGdc` 09:23 PT): "I don't see you have addressed my concerns." Doing-the-work-but-not-citing-it loses accumulation: cluster evidence doesn't grow, downstream parsers can't link, operator sees novel-looking triage on a known recurring pattern. CONTENT lint enforces the discipline.

      **Char cap.** 3000 chars hard cap on threaded message (unchanged). If diagnosis runs over, spill investigation commands / raw log evidence to a paste (`pastry create -t "<alert_short_id>-detail"`) and link from the *Next actions* section: `📄 Full evidence: P<paste_id>`. Do NOT spill required sections — those are always inline.

      End with: "Alert(s): <comma-separated urls>" — literal `url` field per URL sourcing rule. If empty, render `<url-unavailable>`. This goes AFTER the JSON block.

   d. **VALIDATOR PASS** — spawn independent agent via Agent tool with prompt: "Validate this OT alert triage. Re-read diagnosis I just published in spaces/AAQAVOjYc80 thread <thread_id>. Independently run ground-truth queries diagnosis cites (typically `meta ai.model.instance list`, `meta ai.mast-job error`, `meta sevmanager.sev list`). Cross-check standing hypothesis against actual data. Report: (a) confirmed | (b) discrepancies + what data contradicts what. Under 300 words. Do NOT see my reasoning, only the published diagnosis."

      **In-place update of PASTE (NOT new gchat message, NOT edit gchat message text).** After validator returns, EDIT the paste content (created in the step above) via `pastry <paste_id>` overwrite: update the JSON field `"validator_status"` from `"pending"` to `"confirmed"` / `"discrepancy: <one-liner>"`. Gchat message stays unchanged (paste link is stable). **No prose `*Validator*:` line is emitted** (retired 2026-05-17) — status lives in paste's JSON only. Source: 2026-05-16 operator feedback thread `6pKeH_XqjcE` (no two-message-with-gap) + 2026-05-17 thread `SN72CzuckRQ` (JSON off the gchat surface).

      If subagent / Agent tool is unavailable (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`), DO NOT spawn the subagent. Update PASTE JSON: `"validator_status": "unavailable"`. No prose line, no gchat edit.

   e. Add EVERY alert id in cluster to diagnosed_ids in state file immediately after validator pass completes.

8. After loop: persist state, update last_run_epoch. Respond with HEARTBEAT_OK + per-cluster summary line that **MUST include the bot's posted gchat thread URL AND the original alert URL** for each cluster processed (so ot-human-attention-brief can extract these for daily skim links). Format:

   ```
   HEARTBEAT_OK

   ---

   **Run summary** (clusters processed: N):

   **Cluster A** — <model_type_name> <model_id>
   - <verdict_line>
   - <one-line standing hypothesis>
   - Bot reply: https://chat.google.com/room/AAQAVOjYc80/<thread_id>
   - Original alerts: <comma-separated alert URLs from original raw alert payload>

   **Cluster B** — ...
   ```

   **CRITICAL:** the `Bot reply:` line + `Original alerts:` line are MANDATORY in run_summary. Without them, the daily brief cron (`ot-human-attention-brief`) has no way to surface a clickable URL when this cluster shows up as a low-confidence triage. Operator-flagged 2026-05-17 thread `Y3qbdh2hC20` after the brief emitted only sqlite `run <N>` IDs.

Safety:
- If meta oncall.feed list fails, do NOT advance state. Brief error string (no HEARTBEAT_OK).
- If single cluster's deep triage fails partway (e.g., meta ai.model.instance times out), send partial diagnosis with "DEGRADED: <step> failed" marker. Continue.
- Cap 5 clusters per run.
- Do NOT call meta oncall.feed.investigate (creates investigation session).
- Do NOT post comments on SEVs or modify any external state — diagnosis only.
- **READ-ONLY on alerts and Workplace.** NEVER call any oncall.feed mutation (`ack`, `silence`, `comment`, `assign`, `escalate`), never call `meta workplace.comment create`, never call `meta sevmanager.comment create`. Diagnosis is delivered to the GChat lane only; the operator decides routing/ack. The ONLY external write permitted from any OT cron is `meta sevmanager.sev update --add-tag=mvai-online-training` (org-routing tag carve-out, owned by ot-sev-monitor + ot-sev-tag-review). Operator clarified 2026-05-15.

## Learned Rules (auto-appended)

1. [2026-04-29 manual] Always include alert URL (`url` column) in BOTH notification line AND threaded diagnosis. Reviewers need one-click OMH path. Sourced to operator feedback during ifu_lsr alert triage 2026-04-29.
2. [2026-04-29 manual] Pattern-match output (e.g., P01 with 68% confidence) is the OPENING of triage, not the conclusion. ifu_lsr alert on model 883552231 was diagnosed as P01 (FULL_SNAPSHOT blocking deltas) but snapshot timeline showed no FULL_SNAPSHOT in flight during gap — P01 falsified. Always run ground-truth verification before publishing. Likewise: cluster N alerts sharing root cause into ONE diagnosis (today's holdout + prod variants of model 883552231 produced two near-identical diagnoses where one would have sufficed).

3. [2026-05-22 L32] `pastry <paste_id>` (piping to an existing paste ID) READS existing content — it does NOT overwrite. To update an existing paste, use `meta paste.paste update --paste-id=<id> --content=<new_full_content>`. If `meta paste.paste update` is unavailable in cron context → explicitly set the validator field to `🚫 unavailable` directly in the gchat message. Never silently leave the validator status as "pending". Applies to both ot-alert-monitor and ot-post-monitor validator-update steps. Source: ot-alert-monitor 2026-05-21 21:58 UTC silent validator-update failure.

4. [2026-05-22 L35] DPP session max-lifetime expiry is a distinct, predictable TRANSIENT_NOISE pattern (P57 proposal). Identifiers: alert fires ~60–90 min after a clean trainer restart (no MAST error, no OOM), `DPP session uptime` near 1,728,000s (exactly 20 days), model health fully restored after bootstrap. Falsifier: DPP uptime < 19d or MAST shows error → different cause. Classify as NO ACTION · TRANSIENT_NOISE · class=DPP_SESSION_TTL. Source: facebook_ifr_main_mtml_main 886797001 2026-05-22 19:55.

5. [2026-05-24 L40] When classifying THRESHOLD_MISFIT, check alert_state for prior occurrences on the same model. If ≥2nd time → include `⚠️ PERSISTENT_MISCONFIGURATION` notice in the diagnosis reply ("Recurring false-positive. Recommend permanently removing/reconfiguring this detector.") to drive a permanent fix. Without this, the bot silently handles the same false-positive indefinitely. Source: facebook_reels_ifu_i2i 2132070936 2nd THRESHOLD_MISFIT in 15d.

6. [2026-05-25 L46] When `root_cause_sev` is open >48h (`time_mitigated=null`, created >48h ago), the GChat reply must append: `⚠️ Upstream SEV S{id} has been In Progress for >48h — consider paging upstream oncall if escalation hasn't happened.` This is additive to the CL-003 classification, not a replacement. Prevents a long-running upstream SEV generating indefinite OT alert noise with no escalation pressure. Source: S667358 "IG Relevance T20 H100 Scribe Over Quota" 68h unmitigated, ≥3 cluster recurrences.

7. [2026-05-26 L48] Fast-path classification: if `model_type_name` ends in `_retrieval` AND alert_type contains `sparse_delta` or `dense_delta` → classify immediately as R16 FALSE_ALARM / DETECTOR_BROKEN (NO ACTION). Retrieval models publish FULL_SNAPSHOT only; SPARSE_DELTA/DENSE_DELTA detectors have no data source by design and will always fire. Skip T1–T4 investigation entirely. Source: ig_feed_recs_ifr_t2i_retrieval 875620176 holdout + AGG clusters, 2026-05-26 02:59 run.




## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)
