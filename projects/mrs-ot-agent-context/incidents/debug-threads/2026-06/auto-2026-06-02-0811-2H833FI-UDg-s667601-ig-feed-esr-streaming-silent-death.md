---
name: auto-2026-06-02-0811-2H833FI-UDg
description: S667601 postmortem — IG Feed ESR item streaming silent death; CUPTI hypothesis; P59 pattern proposal (conflicts with pyBQfXdR-9k P59)
human_involved: false
---

# Thread Summary: S667601 — IG Feed ESR Item Streaming Silent Death

_Source: spaces/AAQAVOjYc80 thread `2H833FI-UDg` · 3 messages · 2026-06-02T15:11–15:14Z_
_Summarized: 2026-06-02 08:14 PT · last-msg-time: 2026-06-02T15:14:22Z_

## What was discussed

Bot posted S667601 postmortem (mrs_online_training, L3, IG Feed ESR main model 2126294138 item streaming not backfilling, active incident 2.3h, closed 2026-06-01). Validator confirmed all claims with one note about recurrence evidence source.

## Key decisions made

- Root cause: item streaming job dies silently; root cause unknown as of closure. Prior occurrence: S666044 (same model). CUPTI loading is an unverified hypothesis — CUDA_INJECTION64_PATH=none not yet confirmed as fix. [2026-06-02T15:11:59Z]
- Remediation: restarted streaming job mvai-training-online-2126294138 v7; TMS configured to auto-restart. [2026-06-02T15:11:59Z]
- Validator note: GChat (spaces/AAQAjkEWYs8) is the source for recurrence — SEV system recurrent_sevs field empty; recurrence not formally linked. Pattern considered systemic (2+ occurrences, same model). [2026-06-02T15:14:22Z]
- Pattern proposed: "ESR item streaming silent death" — symptoms: job appears RUNNING, no item delta updates, cache miss rate spikes, no MAST error. Falsifier: `meta ai.model.instance list --model-id=SERVED_MODEL_ID` shows recent SPARSE_DELTA VALID → streaming alive, not this pattern. [2026-06-02T15:11:59Z]
- ⚠️ P59 ID CONFLICT: This thread also proposes P59. Thread `pyBQfXdR-9k` proposes a different pattern also as P59. One must be renumbered. Resolve by checking max P-row in known-patterns.md before landing either.

## Files / artifacts touched

| path | what changed |
|---|---|
| n/a | postmortem digest in gchat only; no file write |

## Cluster / pattern references

- Pattern P59 proposed (ESR item streaming silent death, CUPTI hypothesis) — NOT YET LANDED
- Prior incident: S666044 (same model 2126294138)
- P59 collision: see thread `pyBQfXdR-9k` (MVAI base layer breaking change pattern)

## Followup items (not yet done)

1. Resolve P59 ID conflict between this thread and `pyBQfXdR-9k` — check max P-row in known-patterns.md, assign non-conflicting IDs
2. Land "ESR item streaming silent death" pattern in known-patterns.md
3. Track root cause investigation with Shuguang Ye (CUPTI/CUDA_INJECTION64_PATH=none hypothesis)
4. Monitor T273267537 (SEV_REPORT task) status

## Cross-refs

- SEVs discussed: S667601, S666044 (prior occurrence, same model)
- Models: 2126294138 (IG Feed ESR main)
- Tasks: T273267537 (SEV_REPORT task, status not verified)
- GChat: spaces/AAQAjkEWYs8 (IG Feed ESR OT thread — recurrence evidence source)
- Related threads: `pyBQfXdR-9k` (P59 ID collision)
