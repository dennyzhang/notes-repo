# Thread Summary: 3-Component Model Topology Clarification + SilverTorch Boundary Task

_Source: spaces/AAQAVOjYc80 thread `DYu4zoMBeJE` · 4 messages · 2026-05-21 00:53–00:55 UTC_
_Summarized: 2026-05-24 16:51 PT · last-msg-time: 2026-05-21T00:55:09Z_

## What was discussed

Denny was confused by a command with 3 model entity IDs (`--root-model-entity-id 2130324787`, `--reranker-model-entity-id 2130324829`, `--st-model-entity-id 2130324780`). Bot explained the 3-component retrieval topology: root (2130324787) bundles reranker (2130324829) + SilverTorch/ST (2130324780). The kmeans crash was in the ST component only; other components could be healthy independently. Denny noted a recurring issue — unclear routing when FS-publisher fails but root trainer is healthy — and asked to file a task.

## Key decisions made

- **2026-05-21T00:54Z** — File task for SilverTorch FS-publisher routing boundary clarification. Bot filed T272334386 with routing decision table: `silvertorch/` stack → SilverTorch oncall; non-silvertorch error → MRS OT oncall; stale detector → model owner. Task assigned to Denny, priority MID.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none in notes) | External task T272334386 created |

## Cluster / pattern references

- [CL-001] snapshot-stuck — context: FS missing on STUS-role model, routing ambiguity is part of why CL-001 incidents get misdirected

## Followup items (not yet done)

1. T272334386 requires SilverTorch oncall counterpart to be subscribed and routing rules agreed cross-team. Denny told bot "tell me the name, I'll subscribe them" — bot left it as "TBD."

## Cross-refs

- SEVs discussed: none
- Related threads: `YAACkhGjs04` (the triage that prompted this), `ZZzSG9RViPc` (operator's correction on same incident)
- Tasks: T272334386 (boundary clarification, Denny owner)
