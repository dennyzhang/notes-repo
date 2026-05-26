# Thread Summary: m2125081901 — P44 GIL hang vs elastic-agent hang disambiguation

_Source: spaces/AAQAVOjYc80 thread `MdXfe6kDl5Q` · 4 messages · 2026-05-23T19:25–19:32Z_
_Summarized: 2026-05-23 22:50 PT · last-msg-time: 2026-05-23T19:32Z_

## What was discussed

Bot filed a triage for reranker 2125081901 hung at 04:27 PDT (7h51m): mvai_metrics silent, ckpt 609 stuck CREATING, MAST RUNNING, error empty, downstream 2132070936 missing FULL_SNAPSHOT. Bot verdict: P44 Python GIL hang. Cron page agreed and added concrete recovery anchor (kill v4, TMS restarts from ckpt 608) and correct oncall routing (`mrs_relevance_retrieval_i2i`). Denny then corrected: the hang is likely **elastic-agent** (TorchElastic/supervisor frozen), not user-Python P44 — awaiting stack-dump confirmation.

## Key decisions made

- [2026-05-23T19:25Z] Recovery path: kill v4 + TMS auto-restarts from ckpt 608 (cron-provided anchor).
- [2026-05-23T19:32Z] *Denny explicit*: verdict should distinguish P44 (user Python frozen) vs elastic-agent hang (TorchElastic/supervisor frozen). Stack-dump required to disambiguate; P44 claimed prematurely.
- [2026-05-23T19:29Z] Bot self-correction: should always pull `ai.model.instance list` for last CREATING/VALID checkpoint pair before filing triage — gives concrete revert anchor.

## Files / artifacts touched

| path | what changed |
|---|---|
| Workplace post | https://fb.workplace.com/groups/mrs.ot/permalink/1332867342141342/ |
| Paste P2349074541 | Detail triage report |
| `gotcha_p44-vs-elastic-agent-hang.md` (memory) | Added disambiguation rule (py-spy before claiming P44) |

## Cluster / pattern references

- [CL-014] — training timeout (NCCL/watchdog/RaaS); elastic-agent hang is a variant mechanism within this cluster (supervisor process frozen, not user NCCL)

## Followup items (not yet done)

1. Confirm elastic-agent vs P44 via py-spy stack dump — owner: fengzhang1 / mrs_relevance_retrieval_i2i
2. Promote P44/elastic-agent split into `known_patterns.md` once stack-dump confirms — proposed by Denny at 19:32Z

## Cross-refs

- SEVs discussed: none cited explicitly (job-level incident, no SEV opened)
- Related threads: `glb71z7nhJ0` (prior GIL fabrication lesson)
