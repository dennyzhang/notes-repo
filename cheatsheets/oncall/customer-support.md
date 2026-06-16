# Customer Post Support Cheatsheet

<!-- Last updated: 2026-05-12 -->

How to respond when tagged in Workplace posts or tasks about OT/training issues. Explain the problem in plain language, investigate with available tools, draft a response — but never comment directly.

## Ground Rules

- **Read-only**: Never comment on Workplace posts or tasks directly. Draft locally, Denny copy-pastes.
- **Simple language first**: Before any technical dive, explain what the system does and what went wrong in 2-3 sentences anyone could understand.
- **Load skills**: Before investigating, load the matching skill (mrs-ot-triage, ml-job-debug, etc.).
- **Response drafts go in**: `context/cache/SUPPORT-DRAFTS.md`

---

## Common Issue Types

### 1. Stale "Dates Trained On" (Metadata Freshness)

**Simple explanation**: Every ML model in production continuously learns from new data. The "Dates Trained On" field shows the time range of training data the model last used. When this date stops updating, it means either: (a) the model's training job isn't saving new checkpoints, or (b) the system that displays the date is reading from a stale source.

**Why it matters**: If the date is stuck, the model might be training on old data, which means prediction quality degrades. Or the model is fine but the dashboard is misleading — still worth fixing because oncall will waste time investigating phantom staleness.

**Investigation steps** (with actual tool calls):
1. Identify the model: `model_entity_id`, `model_type`
2. Check MAST job health:
   ```
   mcp__plugin_mvai_mvai__get_mast_job_error_tool(mast_job_input="<job_name>")
   mcp__plugin_mvai_mvai__get_mast_job_state_transition_time_tool(job_name="<job_name>")
   ```
3. Check checkpoint saves:
   ```
   mcp__plugin_mvai_mvai__get_last_n_checkpoint_metadata_tool(model_entity_id=<id>, last_n=3)
   ```
4. Check data source type: Scribe (OT) vs Hive (batch)
   - Scribe: `trained_end_ts` should be `TS_NOW` macro
   - Hive: timestamps are literal partition strings, fixed at job startup
5. Check Scuba for train_end_ts:
   ```bash
   # Use scuba skill: query mvai_metrics table, filter by model_entity_id, check train_end_ts column
   ```
6. Determine where the UI reads from: UMM (checkpoint metadata) vs Scuba (`mvai_metrics`)

**Known bug**: `job_level_info()` resolves `TS_NOW` at trainer init, freezing `train_end_ts` in all Scuba rows for the job's lifetime. Checkpoint metadata (UMM) is correct — it resolves `TS_NOW` per save. If the dashboard reads from Scuba, it shows stale data.

**Key code paths**:
- `job_resolver.py:1541-1542` — early TS_NOW resolution (the bug)
- `checkpoint_manager.py:280-292` — correct per-save resolution in `as_dict()`
- `metrics_logger.py:61-71` — ScubaLogger stores frozen `_default_args`

### 2. Training Job Failures / Restarts

**Simple explanation**: Each ML model runs as a long-lived training job on GPU servers. These jobs can fail due to hardware issues (GPU memory errors), software bugs (code crashes), or infrastructure problems (network timeouts). When a job fails, the system usually restarts it automatically, but repeated failures indicate a real problem.

**Investigation steps**:
1. Load `ml-job-debug` or `Meta-ML:debug` skill
2. Get MAST job ID → check job attempts, error logs
3. Classify: hardware (GPU/network) vs software (OOM, assertion) vs infra (scheduling, capacity)
4. Check if the model has a restart loop (>3 failures in 24h)

### 3. Publishing Failures (Model Not Serving)

**Simple explanation**: After a model trains on new data, it needs to "publish" — package itself and push to the serving system so real users get predictions from the updated model. If publishing fails, users keep getting predictions from an older version. This is usually less urgent than training failures but still needs fixing.

**Investigation steps**:
1. Check SilverTorch publisher status
2. Check if the model entity ID matches between training and publishing configs
3. Check publishing stability config in configerator
4. Common root cause: model ID mismatch, checkpoint format incompatible

### 4. Alert Misconfiguration (False Positives / Missing Alerts)

**Simple explanation**: We monitor models with automated alerts — when something looks wrong (training stalls, publishing fails, data quality drops), the system pages the oncall. Sometimes alerts fire when nothing is actually wrong (false positive), or real problems go undetected (missing alert). Both are bad — false positives cause alert fatigue, missing alerts cause outages.

**Investigation steps**:
1. Check SLI detector config in configerator
2. Check model tier designation — is it TIER_1 or experimental?
3. Check if the model is in the monitoring coverage list
4. For false positives: check detector thresholds, check if the model was recently restarted (warm-up period)

### 5. Data Pipeline Issues

**Simple explanation**: Models need a steady stream of data to train on. This data flows through pipes (Scribe streams for real-time, Hive tables for batch). If the pipe breaks or slows down, the model trains on old or incomplete data. The first sign is often DPP (Data Pre-Processing) job failures or high filtering ratios.

**Investigation steps**:
1. Load `dpp-high-filtering` skill if filtering ratio is high
2. Check Scribe category health (for OT models)
3. Check Hive partition availability (for batch models)
4. Check DPP job logs for errors

---

## Response Template

```
## Investigation: [Model ID] — [One-line issue summary]

### What's happening (simple version)
[2-3 sentences in plain language. No jargon. Explain like the reader is smart but doesn't know this system.]

### Root cause
[What specifically broke and why. Include code path if relevant.]

### Impact
[Who/what is affected. Is the model serving stale predictions? Is oncall getting false alerts?]

### Fix
[What needs to change. Link to diff if created. If no code fix, describe the config/operational change.]

### Action items
- [ ] [Immediate fix]
- [ ] [Longer-term prevention]
```

---

## Available Skills for Investigation

| Skill | Use When |
|-------|----------|
| `mrs-ot-triage` | OT pipeline issues — classifies across 6 infra teams |
| `ml-job-debug` | MAST job failures — traces from job-level to error |
| `Meta-ML:debug` | Broader ML/AI job debugging |
| `ci-signals` | CI failures on related diffs |
| `scuba_cli` | Querying Scuba tables for metrics |
| `below` | Host-level performance issues |
| `sandcastle-debug` | Build/test workflow failures |
| `data:scuba` | Scuba data analysis |
| `slick` | SLI/SLO metric analysis |

## Triage Decision Tree

```
Post received
├── Is it about a specific model?
│   ├── YES → Get model_entity_id, model_type
│   │   ├── Training failure? → ml-job-debug
│   │   ├── Stale metadata? → Check data source type, checkpoint saves
│   │   ├── Publishing failure? → Check ST publisher, model ID match
│   │   └── Alert issue? → Check SLI detector config, tier designation
│   └── NO → Is it about infrastructure?
│       ├── GPU/host issue → below, strobelight
│       ├── Build/CI issue → sandcastle-debug, ci-signals
│       └── Data pipeline → dpp-high-filtering, data skills
├── Can I investigate with available skills?
│   ├── YES → Investigate, draft response
│   └── NO → Flag to Denny with: what's needed, who to ask
└── Draft response → SUPPORT-DRAFTS.md
```

---

## Job Setup Validation (Do This First)

For any OT job anomaly, validate job setup before analyzing metrics or system behavior:

1. `--online-training` flag present in launch command
2. Correct hardware pool — B200 for online training, not H100/offline
3. Correct tier — `TIER_1` for production OT jobs
4. MAST classification matches intent (online vs offline)

Only after setup is confirmed, analyze metrics and system behavior.

When comparing a stable OT job to an unstable one, diff their configurations (launch command, hardware, tier, pool) before diffing their metrics. A job running on the wrong hardware pool will exhibit the same symptoms as a genuine system issue but has a completely different root cause.

---

## Common Mistakes

| Wrong Command/Approach | Right Command/Approach | Context |
|---|---|---|
| Diagnosing OT memory spike by explaining publish mechanism + recommending tuning | First check: `--online-training` flag present? Correct hardware pool? MAST classification? | Job on H100 (offline) instead of B200 (online) will show same symptoms but root cause is launch config, not publish behavior |

---

## What Still Needs Human

These types of requests require Denny's judgment — AI drafts context but doesn't answer:
- **Custom skill authoring requests** — "can you build a skill for X?"
- **Org/political routing** — "which team owns this?"
- **Team practice questions** — "how should we handle Y?"
- **Escalation decisions** — whether to escalate to another team's oncall
- **Compensation for incidents** — SLA/credit discussions
