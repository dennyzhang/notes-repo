---
name: human-2026-05-06-1509-drAQ_-nwhLg
human_involved: true
---

# Thread Summary: reels_ifu_mtml_v0 model 883552231 — alert threshold too tight, configerator diff needed

_Source: spaces/AAQAVOjYc80 thread `drAQ_-nwhLg` · 5 messages · 2026-05-06 15:09–15:49 PDT_
_Summarized: 2026-06-02 11:44 PT · last-msg-time: 2026-05-06T22:49:14Z_

## What was discussed

Second alert cluster on model 883552231 (facebook_reels_ifu_mtml_v0) same day (14:35–14:38 PDT). Bot computed a 4-cycle FS-to-first-delta baseline: median 38.2 min, inferred alert threshold ~32 min. Diagnosis: alert misconfiguration — threshold fires before model's normal delta publication lag. Operator asked bot to "fix it" (raise threshold via configerator). Bot discovered model 883552231 has no per-model cconf in `configerator/source/ai/model_registry/mrs/facebook_reels_ifu_mtml_v0/models/`. Operator then asked to research who worked on model registry cconf last half (Archis Gore, archisgore) and build project context into claude folder.

## Key decisions made

- 2026-05-06T22:10:00Z bot diagnosis: standing hypothesis — alert threshold (~32 min) < model's median FS-to-first-delta lag (38.2 min); alert fires nearly every FS cycle; root cause is alert misconfiguration not publishing failure
- 2026-05-06T22:22:11Z operator decision: confirmed root cause, asked bot to fix threshold via diff
- 2026-05-06T22:49:14Z operator follow-on: model has no per-model cconf yet; build project context from Archis Gore's (archisgore) diffs/posts in last half to understand model registry tooling for generating cconf

## Files / artifacts touched

| path | what changed |
|---|---|
| `configerator/source/ai/model_registry/mrs/facebook_reels_ifu_mtml_v0/models/` | no cconf exists yet — needs to be generated via model registry tooling |

## Cluster / pattern references

(Alert threshold misconfiguration — alert fires before model's normal publishing lag completes. No CL-NNN in failure-patterns.md for this pattern; relates to CL-001 publishing stability alerts but is alert-config root cause, not infra root cause.)

## Followup items (not yet done)

1. Research Archis Gore's (archisgore) diffs + posts from last half to understand model registry cconf generation tooling
2. Write project context to `~/.myclaw-ot-bot/...` or notes folder
3. Generate per-model cconf for model 883552231 and raise alert threshold to ≥ p95 (~46 min) via configerator diff

## Cross-refs

- SEVs discussed: (none open)
- Alerts: model 883552231 2nd cluster (OneDetection)
- Related threads: `EhGJO1jWA6g` (same model, morning FS-blocking-deltas thread)
