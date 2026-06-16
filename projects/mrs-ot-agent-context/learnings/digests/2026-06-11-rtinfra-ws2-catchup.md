# 2026-06-11 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 33 human messages spanning 2026-06-08T08:10:37-07:00 → 2026-06-11T15:24:27-07:00 in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Dave Kotfis (15), Josef Cohen (7), Denny Zhang (4))._

_Window: 7d delta. Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

**Root model ID vs ST model ID in alert detectors — launch runbook gap.**
ig_reels_tab_vm_esr alert fired against root model id 2141728947; should be 2141728943 (ST model id). Bot currently cannot distinguish root-vs-ST alert misconfiguration. Pattern: launch → new model promoted to baseline → alert detector not updated from root→ST model id → false alarm fires. Li Lu confirmed and notified model owner; Anthony Foiani confirmed it's a correct fix. **Launch runbook gap:** alert detector update for ST model id must be a launch runbook step. Bot should flag when a model id in an alert config is a root model id that has a known ST entity id.

**Two IG TIER_1 models trainer-behind today (6/11):** 2134319967 (age 88m), 2137792444 (age 57m). Bot flagged these as fleet health act-now items and posted to this space asking if active debugging is underway. No response yet in window. Confirm status before next fleet health cycle.

## P1 — significant nuance / sub-mechanisms

**py3.12 OOM is a C++/Python binding issue, not a general Python 3.12 leak.**
S669019 root cause: reference counting managed incorrectly across C++/Python boundary in publishing bindings when upgrading 3.10→3.12. Not a general py3.12 regression. py3.10 revert patch validated safe (multiple arms over weekend, no leaks). py3.12 fix still needed ASAP before next launch wave.

**Model registry propagation lag after launch — do not flag as OT failure.**
CS Omni launch went out 6/10 night; model registry change still propagating 6/10 morning (example ages did not immediately drop). Pattern: launch → model registry diff needed → takes up to 1 day to populate → example age metrics lag. Bot should suppress trainer-behind flags for models with a known pending model registry diff in the post-launch window.

**Hardware switch visibility via mlhub execution details.**
When a job switches hardware (e.g., A100→H100), the transition is visible in mlhub UI execution details: job version view shows exact timestamp of hardware switch (e.g., mvai-training-online-2124304578 switched v2→v3 at 2:03AM 5/29). Bot should reference mlhub execution details when diagnosing sudden metric transitions that correlate with hardware changes.

**Data flow monitoring AI-infra dependency: model ID selection logic not replicated.**
AI infra pipelines use different model ID selection logic (ST, Root, reranker) than OT. Josef Cohen hesitant to rely on AI infra datasets for model ID extraction in data flow monitoring — their selection logic has not been validated. Multiple validation rounds requested, no response yet. This is an open blocker for data flow monitoring if AI infra datasets are on the critical path.

**H2 freshness SLO: carried into H2 with open scope question.**
H2 brainstorm held 6/11. Li Lu raised: will there be a new freshness SLO target in H2? No conclusion in window — Dave's response cut off. Track for H2 roadmap discussion.

## P2 — references / good-to-know

- D108089755: [launchux][model registry] Baseline model id for ig_reels_tab_vm_esr → 2125804315. Had merge conflict; Josef Cohen re-stamped; Kang to land — confirm status.
- Sparse streaming + weight manager launched on Reels ESR VM 6/9. First time Reels ESR "looks good" per Dave 6/10.
- Pre-launch check claude skill: Dave Kotfis flagged that this skill must be part of launch review process; scope expansion ongoing. OT bot should align triage with what pre-launch checks cover.
- Aniket Panse (Cinder team) named as POC for Cinder-related data pipeline questions (Pushpak Raj Gautam, 6/9).

## Cross-references

- CL-NNN / P-NN: No direct bot classification confirmations or contradictions this week.
- S669019 py3.12 OOM: cross-referenced from MRS OT Oncall and MVAI OT Dev spaces — consistent framing across all three.

## Open coordination threads

- **D108089755 land status**: Josef re-stamped; Kang had merge conflict and resubmitted. Confirm landed before counting as resolved for ig_reels_tab_vm_esr tracking.
- **Data flow monitoring AI-infra validation**: Josef still waiting on AI infra team response on model ID selection logic validation. Not resolved.
- **IG TIER_1 trainer-behind models** (2134319967, 2137792444): no response to bot's question about active debugging. Follow up.
- **H2 freshness SLO scope**: Li's question to Dave unanswered in window; route to H2 planning thread.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Root-vs-ST model ID in alert detector misconfiguration pattern | Add to alert-monitor: check if alerting model id is root when ST exists | 1h |
| P0 | Suppress trainer-behind flags during post-launch model-registry propagation window | OT fleet-health: check for pending model-registry diffs before flagging | 2h |
| P1 | py3.12 OOM = binding issue not general leak: add to known-patterns.md | known-patterns.md: S669019 entry | 30m |
| P1 | mlhub execution details for hardware switch timestamp | triage-depth.md: add to hardware-switch investigation step | 30m |
