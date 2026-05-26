# Decision Matrix

Stage-degradation patterns → bottleneck/owner mapping for OT pipeline triage.

> **Back to:** [SKILL.md](../SKILL.md)

> **Canonical location.** Single source of truth — do not duplicate.

| T1 | T2 | T3 | T4 | Blast Radius | Bottleneck | Owner |
|----|----|----|-----|-------------|-----------|-------|
| degraded | any | any | any | Low (< 5 models) | Data ingestion | DPP/MLDP |
| degraded | any | any | any | High (> 50 models) | **Infrastructure** | Infra oncall → then DPP |
| ok | degraded | any | any | — | Training | MVAI |
| ok | ok | degraded | any | — | Publishing | SilverTorch |
| ok | ok | ok | degraded | — | Serving/streaming | Recsys + Hedwig |
| ok | ok | ok | ok | — | No OT issue | Check model config / NE |
| ok | ok | ok | ok | ATS degraded | **Monitoring gap** | PE/MRS |

## When multiple stages look degraded

| Scribe Lag | Model Age | Streaming Rate | Root Cause | Owner |
|-----------|-----------|----------------|------------|-------|
| ↑ | Stable | Stable | Scribe volume spike / DPP starvation | DPP |
| Stable | Stable | ↓ | Slow predictor processing | Recsys |
| Stable | Stable | ↓ | Hedwig rate limit exceeded | Hedwig |
| ↑ | ↑ | No data | Full snapshot blocking deltas | SilverTorch |
| ↑ | ↑ | No data | Trainer crashed/killed/preempted | MVAI + TMS |
| ↑ | ↑ | No data | **Trainer Python hung** (GIL/A1, P44; mvai_metrics samples → 0 while MAST RUNNING) | MVAI / model owner |
| Depends | ↑ | No data | Revert-and-ban, model NE regression | MVAI |

**Cause-vs-consequence trap (2026-05-13, P44/A1):** the bottom three rows look identical at the symptom layer (FS stuck CREATING + DPP reader QPS ≈ 0 + TEA spike). The disambiguator is `mvai_metrics` Scuba sample freshness for `model_entity_id=<MODEL_ID>` — if zero samples since X while MAST status is RUNNING, the trainer Python is hung and downstream stages are starved, NOT independently broken. ALWAYS run the trainer-liveness probe (R17 in [triage-discipline.md](triage-discipline.md)) before chasing D-class publish or E-class QPS hypotheses. Full failure-mode taxonomy in [known-patterns.md](../../mrs-ot-agent-context/human-input-domain/how/known-patterns.md) § Failure-Mode Taxonomy.
