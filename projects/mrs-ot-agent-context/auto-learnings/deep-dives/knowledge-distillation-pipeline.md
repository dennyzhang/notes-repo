# Knowledge Distillation Pipeline in Online Training

## What It Is

A big model (teacher) tutors a small model (student). The student learns from the teacher's soft predictions (e.g., "72% chance of click") in addition to hard labels (clicked / didn't click). Result: small model with big model's knowledge, servable at production cost.

## How Teacher and Student Run

Two separate MAST jobs, not one.

| | Teacher | Student |
|---|---|---|
| MAST job | Separate `KDCheckpointEvalTrainer` job | Normal OT job (`RankingTrainer`) |
| Mode | `model.eval()`, `torch.no_grad()` — inference only | Full training (fwd + bwd + opt) |
| Input | Data via Thrift RPC from Receptor Server | Scribe stream via DPP |
| Output | Predictions sent back via `completeEval()` RPC | Checkpoints, deltas, snapshots |

## How They Communicate

Not Scribe, not Hedwig — a dedicated **Receptor Server** (C++ Thrift RPC service):

1. External client sends batch of examples → Receptor Server via `evalBatch()`
2. Teacher fetches batch via `getData()` RPC
3. Teacher runs `model.forward()` → produces predictions
4. Teacher sends predictions back via `completeEval()`
5. Receptor Server returns predictions to caller

Receptor Server registers with SMC for discovery. Thrift service defined at `ai_infra/online_checkpoint_eval/data_injection/if/receptor.thrift`.

## The Latency Sync Problem

Both teacher and student read from the same Scribe stream. The student is faster (smaller model). Without delay, the student reaches events the teacher hasn't scored yet — trains without soft labels, defeating the purpose.

```
Scribe:    [A] [B] [C] [D] [E]

Teacher:    scores A... scores B... scores C...
                                    ▲ teacher is here

Student:    trains A... trains B... trains C... trains D...
                                                ▲ outruns teacher — no soft label for D
```

## `latency_injection_ms` — The Fix

Delays the student's Scribe reads by N milliseconds. The student reads data that's at least N ms old, giving the teacher time to score each event first.

```
Scribe:    [A] [B] [C] [D] [E]

Teacher:    scores A... scores B... scores C...
                                    ▲ teacher is here

Student:    (delay)... trains A... trains B... trains C...
                                                ▲ aligned — teacher always ahead
```

**The only invariant:** `latency_injection_ms` ≥ teacher's scoring latency. Too short → student outruns teacher, trains without soft labels. Too long → unnecessarily stale data.

Sweet spot: teacher's p99 scoring latency + small buffer.

Config: `ScribeDataSourceConfig.latency_injection_ms` → passed through DPP to `ScribeDatasetOptions.latencyInjectionMs` in the C++ Koski layer.

Source diff: D89318454 (added the parameter passthrough to core model_family and blue_reels_ifu).

## Key Code Paths

| File | Purpose |
|---|---|
| `minimal_viable_ai/core/checkpoint_eval/knowledge_distillation/trainer.py` | `KDCheckpointEvalTrainer` — teacher job |
| `minimal_viable_ai/core/checkpoint_eval/knowledge_distillation/eval_instance.py` | `KDRpcEvalInstance` — RPC communication |
| `minimal_viable_ai/core/checkpoint_eval/knowledge_distillation/train_pipeline.py` | Wraps normal pipeline, adds `complete_eval` |
| `minimal_viable_ai/core/dataloader/dataloader_configs.py:180` | `latency_injection_ms` config field |
| `ai_infra/online_checkpoint_eval/data_injection/if/receptor.thrift` | Receptor Server Thrift definition |

## Triage Relevance

When triaging a model using KD:
- **Student has missing/degraded soft labels** → check if teacher job is running, check `latency_injection_ms` is ≥ teacher scoring latency
- **Student training quality regression with healthy teacher** → verify Receptor Server SMC registration, check RPC timeouts
- **Teacher job name** follows pattern `mvai-training-online-<teacher_model_id>` with `KDCheckpointEvalTrainer` entrypoint — use R14 (verify entrypoint before assuming it's a trainer)
