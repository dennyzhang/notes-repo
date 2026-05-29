# Thread Summary: IG Feed ESR Gloo TCP — Multi-Attempt Host Evidence + Two New Triage Rules

_Source: spaces/AAQAVOjYc80 thread `HQ2QrEyQXSo` · 7 messages · 2026-05-27_
_Summarized: 2026-05-28 22:45 PT · last-msg-time: 2026-05-27T06:13:22Z_

## What was discussed

Denny posted a triage report for mvai-training-online-2124455858 (IG Feed ESR) v7 failure: Gloo TCP timeout at gloo/transport/tcp/pair.cc:545 caused crash-loop across attempts 0–2 before rayx manually killed and relaunched in mwg. MyClaw flagged two evidence gaps: (1) "SAME bad host" was only true for attempts 1–2 (attempt 0 hit a different IPv6 peer `...7371`, not `...2e18`), weakening the single-host-eviction framing; (2) cross-reference to S667687 was a shallow substring match — different Gloo failure modes (pair.cc:545 Read timeout vs pair.cc:559 Connection closed by peer, cogwheel test not live training). Denny chose option B: feed both gaps as R-rules into ot-sev-monitor.

## Key decisions made

- (2026-05-27T06:11, Denny) "B" — both gaps become R-rules, not a SEV chat correction.
- (2026-05-27T06:13, MyClaw) L48 "Multi-attempt peer-IP verification": if proposing host-eviction fix for Gloo/NCCL failure, must verify IPs across ALL attempts; differing IPs → region-level fault not single-host. L49 "Gloo failure-mode discrimination": cross-SEV citation requires matching both `pair.cc:<line>` AND error class verbatim; substring `gloo/transport/tcp` alone is insufficient.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-sev-monitor.md` | L48 (entry 13) + L49 (entry 14) added to Learned Rules section |

## Cluster / pattern references

_(No confirmed cluster IDs in failure-patterns.md — omitted)_

## Followup items (not yet done)

_(None explicitly discussed)_

## Cross-refs

- SEVs discussed: S668272 (current job), S667687 (cited cross-ref, ruled distinct)
- Related threads: `yF_aMB00xMk` (DPP-rotation follow-up started same day)
