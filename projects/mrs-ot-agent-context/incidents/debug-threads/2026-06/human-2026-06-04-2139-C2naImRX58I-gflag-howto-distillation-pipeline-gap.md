---
name: gflag-howto-distillation-pipeline-gap
description: Operator asked "what did you learn" from ot-post-monitor digest; bot found digest mis-stated the gflag workaround; created howto.md; operator twice corrected "why ask" instead of requesting approval; pipeline now routes HOWTO class to howto.md
metadata:
  type: project
human_involved: true
---

# Thread Summary: Gflag How-To Distillation & Pipeline HOWTO Gap Fix

_Source: spaces/AAQAVOjYc80 thread `C2naImRX58I` · 18 messages · 2026-06-05 04:39–05:04 UTC_
_Summarized: 2026-06-05 21:44 PT · last-msg-time: 2026-06-05T05:04:03Z_

## What was discussed

Operator asked "what did you learn" from the ot-post-monitor digest. Bot traced W1336148551813221 (Sanket Karnik's HOWTO: adding gflags to OT jobs) and found the digest had mis-stated the workaround (cited `--env` as "the" fix; that's an untested fallback, not the recommended path). Bot created `howto.md` and identified that HOWTO-class posts are silently dropped by the distillation pipeline. Operator twice said "why ask" when bot sought approval — bot acted autonomously both times. Thread also confirmed ot-thread-summarizer should return HEARTBEAT_OK silently instead of posting a "📝 Distilled N threads" digest.

## Key decisions made

- **Gflag how-to captured correctly** in `human-input-domain/howto.md` at 04:57:43 — Li Lu's actual answer (P2353215480): you cannot change a gflag on a running MAST job; recommended fix = rebuild app-layer from latest (defaults often already flipped — e.g. D105728596 made `bulk_type` default `socket,tls-socket` on 5/23). `--env GFLAGS_<flag>=<val>` is untested fallback, not primary.
- **HOWTO posts now routed to howto.md** in ot-post-monitor digest cron — wired without approval (operator: "Why ask" at 04:59:51).
- **ot-thread-summarizer no longer sends chat digest** — returns HEARTBEAT_OK silently; staged in sqlite (updates=1 verified at 05:04:03).
- **Process gap confirmed**: the post-postmortem pipeline routes HOWTO-class posts to bit-bucket instead of knowledge files because it only harvests incident patterns (P-rows). Fixed.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../human-input-domain/howto.md` | Created; gflag how-to entry added (Li Lu P2353215480 answer) |
| `notes/.../team_bot/cron-jobs/ot-post-monitor.md` | HOWTO-class posts now route to howto.md |
| sqlite `ot-thread-summarizer` prompt | Returns HEARTBEAT_OK; no longer posts "📝 Distilled N threads" chat digest |

## Cluster / pattern references

- [P-001] — act don't ask: operator confirmed twice with "why ask"; bot should have acted on both without seeking approval

## Followup items (not yet done)

_(none explicitly stated)_

## Cross-refs

- Posts: W1336148551813221 (Sanket Karnik, gflag HOWTO)
- Pastes: P2353215480 (Li Lu's gflag answer)
- Diff: D105728596 (bulk_type default flip, 2026-05-23)
- Related thread: `5rwiSwCGHBo` (ot-thread-summarizer purpose question)
