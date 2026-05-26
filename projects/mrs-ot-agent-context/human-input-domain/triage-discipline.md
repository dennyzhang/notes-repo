# Triage Discipline — OT-Specific Extensions

OT-specific verification commands, quality rules, signal taxonomy, and stage-skill routing. Builds on the generic triage methodology framework.

> **Generic framework:** [`../human-input-generic/triage-methodology.md`](../human-input-generic/triage-methodology.md) — per-fact tagging, quality rules R1-R10/R13/R5b, cluster discipline, investigation gate, two-number confidence, stop conditions, output template structure.
>
> **Back to:** [SKILL.md](../../mrs-ot-agent-src/SKILL.md)

## Verification chain (OT-specific commands)

Required for every non-trivial triage. Ground-truth verification MUST cover BOTH publishing AND trainer state for any T3 alert.

1. **Pattern hypothesis.** Run keyword-and-signal pattern match against `known_patterns.md`. State leading + secondary candidates explicitly.

2. **Ground-truth verification.** Run ALL:
   - `meta ai.model.instance list --model-id=<ID> --limit=30 --sort-by=creation_time --sort-order=desc --columns=instance_id,creation_time,snapshot_type,state -o table` — snapshot timeline
   - `meta ai.mast-job metadata --name=<JOB>` — current version + state
   - `meta ai.mast-job attempts --name=<JOB> -o json` — attempt history
   - `meta ai.mast-job insights --name=<JOB> --version=<CURRENT> --attempt=<CURRENT_AT> -o json` — analyzer flags
   - `meta ai.mast-job error --name=<JOB> --version=<PREV> --no-truncate -o json` — **CRITICAL** verbatim error from PREVIOUS failed version. Never trust upstream "RUNNING = healthy" without re-pulling. (Source: 2026-05-02, `ig_textpost_feed_m2m_retrieval` v32 DataClientStuckException missed for hours.)

   Each `known_patterns.md` row has a *Verification Check* column — run it.

2-b. **Timing-window reasoning.** State three timestamps: (1) trigger event, (2) alert fire time, (3) SLO window (MAJOR=1.2× cycle_minutes, CRITICAL=3.0× — see `mvai-ot/reliability/operations/monitoring.md`). If the alert fired within ~1 SLO window of a fresh trainer restart, default explanation is "post-restart bootstrap" — not "infra broken".

2-c. **Read SEV's live GChat — MANDATORY when a chat channel exists.** Live thread is newer than snapshot. Extract `gchat_space_url` / `chat_url` from metadata; if `communication_channel` is non-GChat or absent, note `[no live chat channel — metadata-only]` and skip. Otherwise run `gchat read <space_id>` for ~20 most recent messages, parse for active hypotheses, paste links, ETAs, and contradictions to `root_cause` / `remediation`. Cite per-fact: `[VERIFIED via gchat read <space_id>]`. (Source: 2026-05-02 S657811 — metadata said "archiver restarted, awaiting catchup"; GChat said "~150 versions need manual deletion, won't be solved till next week".)

3. **Active-SEV cross-reference.** Run `meta sevmanager.sev list --in-progress --created-after="2 days ago" --columns=sev_number,title,sev_type,status -o json`. Cross-org Scribe / Hedwig / DPP infra SEVs often won't carry the OT tag but ARE the upstream cause. Surface each and connection.

4. **Owner correction.** Run `meta ai.model-series metadata --model-id=<MODEL_ID>` for `owner_unixname` and `oncall`. Diagnosis "Owners":
   - **Primary (this incident):** model `owner_unixname` + model oncall + product oncall
   - **Source owner:** literal `assigned_user` (alerts) / `owner_unixname` (SEVs) from upstream JSON
   - **OT-side escalation:** per-product routing from `team_bot_config.yaml`
   - **Secondary follow-up (only if a system bug exists):** owner of any routing/config bug surfaced

   Don't promote a system-bug fixer to primary just because they show up in fbcode commits. (Source: 2026-05-02 triage suggested lupaul as primary instead of model-owner ronghuang.)

5. **Hypothesis chain.** Take the leading pattern, test against (2). If contradicted, *write the falsification* and switch to secondary.

## OT-Specific Quality Rules (R11-R18 + R19)

These extend the generic quality rules in `triage-methodology.md`. Numbering is contiguous.

| # | Rule | Mandate | Failure mode without it |
|---|---|---|---|
| R11 | **Root model vs served model** | When the symptom is on a served model id (snapshot stall, model age, deployment lag), the root cause may be on the upstream root training model id. Every diagnosis MUST cite BOTH ids when they differ: `served_model_id=<X>, root_training_model_id=<Y>`. Walk the lineage before naming a fix. | Diagnosis chases the wrong model id; fix proposed on serving side when root cause is upstream training. Source: 2026-05-08 S661157 — P38 on served `m2128360468` was wrong; root cause was P17 on root `m2131533016` (fire-app fbpkg expired). Cost ~6h. |
| R12 | **Verify model_id ↔ MAST job linkage** | Before reasoning "MAST job X is causing model Y's symptom", confirm `application_metadata.flow_root_workflow_run_id` AND `model_entity_id` match Y. Two facts adjacent in time are NOT necessarily causally linked. | Fake causal chain; real upstream (e.g., an open SEV) gets ranked secondary. Source: 2026-05-08 — bot joined unrelated MAST job + stale snapshots into one hypothesis. |
| R14 | **Job-role verification — check `entrypoint`** | `mvai-training-online-<MODEL_ID>` naming is shared by trainers (entrypoint `train.py`) and STUS publish jobs (entrypoint `st_update_service.py`). Run `meta ai.mast-job metadata` and grep `entrypoint` BEFORE forming any trainer-side hypothesis. Trainer-side hypotheses (NCCL, OOM, step counter) are NOT applicable to STUS jobs. | Hypothesis space wrong by half. Source: 2026-05-08 — same trap hit 3× in one session. |
| R15 | **Recurring-flow enablement check** | Before blaming downstream symptoms (fire-app expired, fbpkg, scheduler), verify the recurring flow is enabled. Check `is_enabled` via `meta ai.recurring-job recurring-flows --owner=<owner>`. If `false` → THAT is the root cause; downstream symptoms are CONSEQUENCES. | Bot proposes fix recipes for a deliberately decommissioned model. Source: 2026-05-08 — bot missed disabled flow 8921769. |
| R16 | **Alert applicability — verify expected snapshot types** | First check: does this model EVER produce the expected snapshot types? Pull last N=2000+ instances, group by `snapshot_type`. If expected type has 0 occurrences → alert is misconfigured (FALSE ALARM). Standing hypothesis becomes "alert config error", NOT "publish path broken". | Operator chases a non-issue. Source: 2026-05-08 m2132070936 — bot noted "DENSE_DELTA never produced" but failed to promote "alert is misconfigured" to standing hypothesis. |
| R17 | **Trainer-liveness probe BEFORE publish/DPP hypothesis** | When symptoms include snapshot stuck, FS stalled, missing deltas, DPP QPS ≈ 0: run `meta scuba.dataset query -d mvai_metrics --view=samples --columns=time -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' --hours=12 -l 1 --order-by=time`. If latest sample > 5 min stale AND MAST attempt RUNNING → trainer Python is hung; downstream symptoms are CONSEQUENCES. Don't propose publish-pipeline or DPP hypotheses until liveness is confirmed. | Bot proposes publish-pipeline fixes for a CPU-side trainer hang. Source: 2026-05-13 — misdiagnosed as TGIF stuck before GIL hang identified. |
| R19 | **SEV mitigation status MUST be verified via `time_mitigated` canonical field — not via in-thread comments** | When citing a co-active or recently-mitigated SEV as root cause or as basis for "expect auto-recovery" guidance, ALWAYS verify via `meta sevmanager.sev metadata --sev=<SEV_ID>` and check the `time_mitigated` field. **If `time_mitigated` is empty → SEV is NOT officially mitigated**, regardless of in-thread comments. **Procedure**: after citing a SEV as mitigated, run `meta sevmanager.sev metadata --sev=<SEV_ID> --show-links` and read `time_mitigated`. If populated: cite canonical timestamp. If empty: emit `[CORRECTION: SEV still In Progress per canonical time_mitigated=empty; in-thread comment is informal — re-check before claiming resolution.]` and update recovery guidance. **Falsifier**: `time_mitigated` populated → SEV officially mitigated. **Sources**: S665163 ZippyDB RE throttling (2026-05-17) — 5 alert archives (A2387001468469120, A878102693-413, A878102693-417, A977255094865118, A2130305043) incorrectly cited S665163 as "mitigated 08:19 PDT May 17" based on in-thread comment; canonical `time_mitigated` empty on re-check 2026-05-18 03:25 PT; S665163 re-fired at 04:05 PT May 18 confirming wrong guidance. ot-knowledge-distillation 2026-05-18 (5 incidents, correction class: `inferred_mitigation_from_thread_not_metadata`). | Archives cite wrong mitigation timestamps; "expect auto-recovery" guidance is wrong; operators stop watching an In Progress SEV; re-fires appear as new incidents; postmortem timelines wrong. |

## Signal-class taxonomy

Cluster notification prefixes carry a `signal_class` label, computed from the SEV title via `team_lane_scope.classify_signal_class()`.

| signal_class | Title regex (case-insensitive, first match wins) | Meaning |
|---|---|---|
| `mvai_publish_pipeline` | `cogwheel\|TGIF\|conveyor\|lowering\|XL_WEIGHTS\|publish(?!er)\|gmpp\|silvertorch\|light_cli\|fbpkg\|build[ _]node` | Publish/conveyor/release path |
| `mvai_serving` | `vanguard\|predictor\|serving_eval\|sigrid` | Serving/predictor side |
| `mrs_online_training` | (default) | Actual training-path SEVs |

**Class-gated admission:** After signal_class is computed, admission is gated on `team_lane_scope.signal_class_admit_allowlist` (default: `{mrs_online_training, mvai_publish_pipeline}`). A SEV classifying as `mvai_serving` is dropped — inference-stage SEVs are MVAI-team scope, not OT-coordination scope. Override: `signal_class_admit_allowlist: [mrs_online_training, mvai_publish_pipeline, mvai_serving]`.

## Stage-skill invocation (mandatory when symptom maps to a stage)

The agent MUST invoke the stage's skill before publishing the standing hypothesis. Authoritative copy: `triage_config.py → CONFIG["stage_skills"]`.

| Stage | Sub-class | Symptom signature | Skill |
|---|---|---|---|
| T1 | Data Ingestion | DPP starvation, scribe lag, training example age, freshness regression | `fbcode/data_preproc/.llms/skills/dpp-online-training/SKILL.md` |
| T2 | Training | MAST job failure, NCCL/NaN/OOM, trainer stuck, app errors | `fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md` |
| T3a | Publishing — Generation | FULL_SNAPSHOT or delta NOT produced; generation stopped | `fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/reference/monitoring.md` |
| T3b | Publishing — Delivery | Produced but not delivered to predictor; queue buildup; streaming distribution loss | `fbcode/ip_runtime/model_freshness/operation/observability/hedwig-stats/SKILL.md` |
| T4 | Serving | Low streaming success rate; staleness on serving; weight-manager / inplace update fail | `fbcode/ip_runtime/model_freshness/operation/streaming/investigate-success-rate/SKILL.md` |

**Symptom dictates sub-class, not the keyword "publishing".** A "FULL_SNAPSHOT missing" alert is T3a when the trainer never produced one; T3b when production succeeded but delivery failed; T4 when the predictor refused. Run `meta ai.model.instance list` to localize before invoking.

## Diagnosis output — audience determines style

When the bot posts to surfaces **outside this team space**, use the **crisp 5-element template** — see [`../human-input-generic/report-templates/crisp-report-style.md`](../human-input-generic/report-templates/crisp-report-style.md). Verbose 9-section output goes to a paste linked from the post body.

For in-thread replies **within this team space**, use the full 9-section internal-debug template (raw evidence, investigation commands, files-touched — per the generic framework's output template).
