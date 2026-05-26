# Triage Reference

Per-stage Scuba queries, health thresholds, and dashboards for cross-component OT pipeline diagnosis.

> **Back to:** [SKILL.md](../SKILL.md)
>
> **Deep triage (per-component):** Use the existing MVAI OT reliability skill for full workflows — it's the canonical source.
>
> | Surface | Reference |
> |---|---|
> | Full SEV triage workflow + decision trees | [mvai-ot/reliability/workflows/triage.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md) |
> | Publishing alert analysis, delta status verification | [monitoring.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/monitoring.md) |
> | 20+ real SEV patterns + RCA | [knowledge.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/reference/knowledge.md) |
> | MAST job log analysis | [log_analyzer.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/diagnostics/log_analyzer.md) |
> | Dashboards + escalation contacts | [dashboards.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/dashboards.md) |

## Step 1: Identify the Model

Resolve `model_type` to entity IDs:

```bash
presto instagram --execute "
SELECT model_type_name, model_id, stage,
    CASE WHEN model_category = 'DENSE_SPARSE' THEN 'SPARSE' ELSE model_category END AS snapshot_type
FROM ig_latency_model_ids_per_stage
WHERE ds = '$(date +%Y-%m-%d)'
    AND model_type_name = '<MODEL_TYPE_NAME>'
    AND stage IN ('Scribe', 'Training', 'Inference')
ORDER BY stage, snapshot_type
"
```

## Step 2: Query All 4 Stages in Parallel

Launch all 4 stage queries concurrently (Claude: parallel tool calls; human: separate terminals). Don't wait for T1 before starting T2. Mark UNAVAILABLE on 30s timeout and continue.

### T1: Scribe / DPP

```bash
scuba query ig_online_training_ats \
  --columns model_type p90_latency \
  --filters "model_type = '<MODEL_TYPE>' AND stage = 'Scribe'" \
  --start "-1h" --end "now" --aggregation "avg(p90_latency)"
```

| Signal | Healthy | Degraded |
|--------|---------|----------|
| p90_latency | < 15 min | > 25 min → DPP/MLDP owns |

### T2: Training / MVAI

```bash
mvai online-training-mgr print -m <model_entity_id>
mast job info mvai-training-online-<model_entity_id>
```

| Signal | Healthy | Degraded |
|--------|---------|----------|
| Job status | RUNNING | Crashed/stuck → MVAI owns |
| training_latency | Stable | Spiking → MVAI owns |

### T3: Publishing / SilverTorch

```bash
scuba query gmpp \
  --columns model_type publish_mode event_type time \
  --filters "model_type = '<MODEL_TYPE>' AND event_type IN ('TensorStreamingSessionEnd', 'OperatorRun_Success')" \
  --start "-2h" --end "now" --aggregation "count(*)" --groupby "publish_mode"
```

| Signal | Healthy | Degraded |
|--------|---------|----------|
| Delta publishes | Regular cadence | No recent deltas → SilverTorch owns |
| Full snapshot | Not blocking | Blocking deltas → SilverTorch owns |

### T4: Serving / Recsys + Hedwig

```bash
scuba query runtime_freshness:ai_infra \
  --columns tenant_id event_type control_plane_type \
  --filters "tenant_id = '<MODEL_TYPE>'" --start "-1h" --end "now"
```

| Signal | Healthy | Degraded |
|--------|---------|----------|
| Apply rate | Messages applied ≈ sent | Low → Recsys/Hedwig owns |
| Model age | Stable | Stale → Recsys/Hedwig owns |

## Step 3: Synthesize and Route

```
[MRS OT Agent] Model: <model_type>
Bottleneck: T<N> (<stage_name>) — <owner_team> owns this.
Evidence: <specific metric or error>
Recommended action: <next step>
```

When no known pattern matches, narrow to ≤2 suspect components within 30 minutes:

```
[MRS OT Agent] Model: <model_type>
Issue type: UNKNOWN — no known pattern matched.
Suspect: T<N>, T<M>      Ruled out: T<X>, T<Y> (with thresholds)
Evidence per suspect: <metric or log finding>
Recommended next step: Engage <oncall_1> and <oncall_2>.
Time spent: <minutes>
```

## ATS Component Breakdown

Per-model T1/T2/T3/T4 latency decomposition with WoW trends:

```sql
SELECT model_type, stage, ds, AVG(p90_latency) avg_p90, MAX(p90_latency) max_p90
FROM ig_online_training_ats
WHERE model_type = '<MODEL_TYPE>' AND ds >= DATE_ADD('day', -14, CURRENT_DATE)
GROUP BY model_type, stage, ds ORDER BY ds DESC, stage
```

Dashboard: [IG OT SLO](https://ig-data-apps.internalmeta.com/ig/relevance-foundations/online-training-slo/) — canonical SLO surface, source: `fbsource/nest/apps/ig_data_apps/app/(authenticated)/ig/relevance-foundations/online-training-slo/` (D95118501 founding; D106313745 added 11th model `ig_mixed_feed_smsl_esr`; owners: jcohen1, ig_relevance_de).

### SLO thresholds (canonical, per dashboard `_constants.ts`)

| Metric | Threshold | Notes |
|---|---|---|
| Latency SLO | Scribe Delay P90 + Model Age Avg ≤ 10 minutes | Excludes join window. Per-hour pass/fail. |
| Streaming Success SLO | ≥ 99% rate for ≥ 95% of hours | `num_messages_applied / num_messages_sent` per hour from `runtime_freshness`. |
| Combined SLO | Latency AND Streaming both pass | Goal: 95% hours compliant. Aspirational: 98%. |

When interpreting alerts: a single-hour blip rarely violates the streaming SLO (5%-of-hours budget). Multi-hour streaming dips (≥2 hours in a 24h window) start eroding budget.

### Dashboard model coverage (11 models, ordered by ranking stage)

| # | Model | Stage | Product | In agent `models.md`? |
|---|---|---|---|---|
| 1 | `ig_reels_starsearch_t2i_retrieval` | Retrieval | Reels | ✅ |
| 2 | `ig_reels_tab_ss_omni_retrieval` | Retrieval | Reels | ✅ |
| 3 | `ig_reels_tab_cs_omni_retrieval` | Retrieval | Reels | ✅ |
| 4 | `ig_mixed_ifr_u2i_combined_omni_retrieval` | Retrieval | Feed | ✅ |
| 5 | `ig_feed_recs_ifr_t2i_retrieval` | Retrieval | Feed | ❌ gap |
| 6 | `ig_reels_tab_esr_ttsn` | ESR | Reels | ✅ |
| 7 | `ig_reels_tab_vm_esr` | ESR | Reels | ✅ |
| 8 | `ig_feedrec_esr_ttsn` | ESR | Feed | ❌ gap |
| 9 | `ig_mixed_feed_smsl_esr` | ESR | Feed | ❌ gap (newly added by D106313745) |
| 10 | `ig_reels_tab_mtml` | LSR/MTML | Reels | ✅ |
| 11 | `ig_organic_feed_mtml` | LSR/MTML | Feed | ✅ |

Three Feed-side gaps in agent scope: `ig_feed_recs_ifr_t2i_retrieval`, `ig_feedrec_esr_ttsn`, `ig_mixed_feed_smsl_esr`. Expansion is a scope decision (operator owns).

## Decision Trees — symptom → subtree pointer

Per-stage decision trees live in [`mvai-ot/reliability/workflows/triage.md`](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md). They're maintained there with deeper sub-classes.

| Symptom | Subtree |
|---|---|
| Streaming success rate < 95% | Streaming/Publishing |
| Job crashing / NaN / NE regression | Training Stability |
| TMS state ≠ ONLINE_READY / fbpkg expired | Job Lifecycle |
| Job PENDING > 30 min / preemption | Infrastructure/Scheduling |

## SEV Response Playbook (First 5 Minutes)

1. Establish communication — join MatterMost, MRS IMOC channel.
2. Assess blast radius — how many models, which PGs (fleetwide health dashboard).
3. Stop OT if needed — coordinate with TMS/MAST oncalls.
4. Gather evidence — parallel status checks across affected models (Step 2 queries).
5. Route to component owner with evidence package: metrics + logs + timeline.

For SEV0/SEV1: coordinate revert-and-ban with PG leads; restart in batches of 25-50 jobs with 30-min buffer.

### Revert-and-Ban

```bash
mvai online-training-mgr -m <model_entity_id> -s off
mvai ban-versions -m <model_entity_id> --checkpoint-start-version <first_bad>
mvai ban-versions -m <model_id> --ban_snapshot_after_ts "<timestamp>"
mvai online-training-mgr -m <model_entity_id> -s online
```

## Publishing Stability Alert — Data-First Triage

For `dai_modelstore` publishing stability alerts (`publishing stability: <model_type> model <id> missing snapshot types full_snapshot`), follow the workflow in [`mvai-ot/reliability/workflows/triage.md` § Publishing Stability Alert](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md). Two-command path: (1) `meta ai.mast-job attempts` → classify RUNNING vs DEAD vs crash-loop; (2) `scuba dai_modelstore` for last `ModelPublishSuccess`. **Data first, not SEV search.** Normal publish cadence ~90 min — gap >3h is concerning.

## Blast-Radius Heuristics

| Blast Radius | Stage | Likely Cause | Route To |
|---|---|---|---|
| 1-5 models, same PG | T1 | DPP pipeline-specific issue | DPP oncall |
| 1-5 models, same PG | T2 | Model-specific training bug/config | MVAI oncall |
| > 50 models, multi-PG | T1 | Infrastructure (ACL, Scribe global quota, network) | Infra oncall first |
| > 50 models, multi-PG | T2 | Package rollout, DPP release, scheduler issue | Check recent deployments |
| All stages OK, ATS degraded | — | Monitoring gap | PE/MRS — check Falco/Fireball |

## Monitoring Coverage Checklist

Before declaring "all healthy," verify the monitoring stack itself:

| Check | How | Failure means |
|---|---|---|
| Falco listeners active | Falco dashboard for tier config | Alerts won't fire (S630911 pattern) |
| Scuba tables ingesting | Recent data < 5 min old | Stale = looks frozen, not healthy |
| Canvas dashboards loading | Spot-check Training Example Age | No visibility into training freshness |
| Alert routing configured | Oncall rotation has on-shift members | Alert fires but nobody receives it |

Failure → flag as `Monitoring gap — <check> broken. Cannot confirm pipeline health.`

## Key Dashboards

| Dashboard | Purpose | Link |
|---|---|---|
| Fleetwide Health | Overall OT health | mrs_online_training_oncall/online_training_fleetwide_health |
| Training Example Age | Data freshness | fburl.com/canvas/x5jdk9f3 |
| ATS | Training-to-serving latency | fburl.com/unidash/aicx1ux3 |
| DPP Health | Data preprocessing | fburl.com/unidash/tv4cxmm0 |
| MAST Job Failures | Failure Scuba | fburl.com/scuba/ai_mlu/hg7l3phs |
| TMS Launch Failures | Launch failure Scuba | fburl.com/scuba/training_platform_model_events/6r21wcb9 |
| Delta Snapshot Size | Publishing health | fburl.com/unidash/k3e1rkbw |
| Streaming Overview | Streaming debugging | model_freshness_inplace_delta_streaming/user_streaming_debugging |

## Escalation Contacts

| Issue | Oncall | Workplace Group |
|---|---|---|
| DPP/Data Reading | mldp_oncall | [MLDP Users](https://fb.workplace.com/groups/mldp.users) |
| Checkpoints/Model Store | model_store | [Model Store](https://fb.workplace.com/groups/738862774242905) |
| SilverTorch/Publishing | home_ml_platform | [Silvertorch](https://fb.workplace.com/groups/silvertorch) |
| In-Trainer Publisher | model_processing | [Model Processing](https://fb.workplace.com/groups/254777643194247) |
| TMS/Training Launch | managed_training_service | [TMS](https://fb.workplace.com/groups/280672176819805) |
| Hedwig/Streaming | hedwig | — |
| Predictor/Serving | ip_runtime | Inference Platform Users |
| MRS Online Training | mrs_online_training | [MRS OT](https://fb.workplace.com/groups/mrs.ot) |
| MVAI General | mvai | [MVAI](https://fb.workplace.com/groups/378599340852744) |
