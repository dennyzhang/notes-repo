# Pipeline Architecture

4-stage online-training pipeline (Scribe/DPP → Training → Publishing → Serving) and the Peer Scenario Isolation Phase 0 capability for routing model-specific vs feature-wide incidents.

> **Back to:** [SKILL.md](../SKILL.md)

```
  T1: Data Ingestion    T2: Training         T3: Publishing       T4: Serving
  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
  │ Scribe/DPP     │──▶│ MAST Job/MVAI  │──▶│ SilverTorch    │──▶│ Recsys/Hedwig  │
  │                │   │ Trainer loop   │   │ GMPP Publisher │   │ Weight Manager │
  └────────────────┘   └────────────────┘   └────────────────┘   └────────────────┘
  ◄────────────────────── E2E ATS Latency ──────────────────────►
```

| Stage | Component | Owner | Health metric | Scuba table |
|-------|-----------|-------|---------------|-------------|
| T1 | Scribe / DPP | DPP / MLDP | Scribe lag, example age | `ig_online_training_ats` (stage='Scribe') |
| T2 | MAST Job / MVAI Trainer | MVAI | Job RUNNING, training_latency, NCCL, OOM | `fct_ats_training`, `training_platform_model_events` |
| T3 | SilverTorch / GMPP Publisher | SilverTorch | publish cadence, FULL_SNAPSHOT events | `gmpp` |
| T4 | Recsys / Hedwig / Weight Manager | Recsys + Hedwig | Streaming success rate, model age at serving | `runtime_freshness:ai_infra` |

## Peer Scenario Isolation (Phase 0 capability)

| When to use |
|-------------|
| Issue is attached to a specific `model_entity_id` AND you must answer "is the feature-combination broken vs. is only this model broken" before routing — saves 20-30 min of ad-hoc Hive |

How it works:
1. Query `ai_infra.fct_ats_inference_component` for the model's
   `(snapshot_type × snapshot_update_type)` combinations over 7 days.
2. Find peer OT models with the same signature.
3. Score peer health by snapshot production rate.
4. Emit one of four verdicts (table below).

| Verdict | Meaning | Triage action |
|---------|---------|---------------|
| `model_specific` | ≥10 peers with same signature, ≥80% healthy | Fix the model — compare config to named healthy peer |
| `feature_wide` | ≥10 peers, <50% healthy | Feature regression — escalate to feature owner |
| `new_scenario` | <5 peers with this signature | No prior art — feature owner must investigate |
| `inconclusive` | Everything else | Don't fork triage on this; gather more evidence |

**Entry point:** `src/capabilities/peer_scenario.py::isolate(model_id)`.

```bash
cd fbcode/pe_mrs_ml/mrs_ot_agent
buck2 run :sev_fast_triage_lib -- -m pe_mrs_ml.mrs_ot_agent.src.capabilities.peer_scenario <model_id>
```

**Thresholds** live in `triage_config.yaml` under `peer_scenario:` — tune
there, not in code. Reference task: T266624272.
