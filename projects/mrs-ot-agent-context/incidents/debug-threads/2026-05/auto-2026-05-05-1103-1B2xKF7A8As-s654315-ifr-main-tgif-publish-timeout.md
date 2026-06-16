# Thread Summary: S654315 — mvai_ifr_main TGIF async publish timeout (cold-start cogwheel)

_Source: spaces/AAQAVOjYc80 thread `1B2xKF7A8As` · 3 messages · 2026-05-05 11:03–11:05 PDT_
_Summarized: 2026-06-02 10:43 PT · last-msg-time: 2026-05-05T18:05:45Z_
human_involved: false

## What was discussed

Bot triage of S654315 (L3, mvai_publish_pipeline): online_train_publish fails in TGIF async publish for mvai/mvai_ifr_main after IEN fix. SEV was originally mitigated May 1 but reopened to track trunk stability — only 3 good conveyor runs since Apr 28 SIM backout. Primary hypothesis (H1, ~75%): cogwheel starts from scratch without lowering cache → cold-start publish takes ~2hr → exceeds hardcoded cogwheel timeout. Secondary (H2, ~40%): prod runs B200; cogwheel runs H100 — HW mismatch inflates publish latency. Fix D103687503 (timeout increase) grafted to R9496.2, needs ~4hr propagation.

## Key decisions made

- H1 (cold-start timeout) designated primary at ~75% confidence (2026-05-05 11:05 PDT); monitor next 2 conveyor releases after D103687503 propagates
- H2 (HW mismatch B200/H100) kept as secondary track (2026-05-05 11:05 PDT); Catalin Toda escalating for B200 capacity

## Files / artifacts touched

| path | what changed |
|---|---|
| tgif_publisher.py | PG-init hang still present (D80755557 unfixed); SIM reland blocked |
| cogwheel test config | Timeout increase (D103687503 — in-flight on R9496.2) |

## Cluster / pattern references

_(omitted — not verified against failure-patterns.md)_

## Followup items (not yet done)

1. Verify D103687503 propagated and check next 2 conveyor releases — owner: akmahesh
2. Confirm cogwheel HW: `meta tupperware.job list --service=mvai_ifr_main`; file capacity request if H100 confirmed — owner: Catalin Toda
3. Reland SIM (S647019) once H1 confirmed

## Cross-refs

- SEVs discussed: S654315, S658142
- Posts: none
- Related threads: none
