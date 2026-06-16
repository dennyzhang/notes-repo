# 2026-06-12 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 1 human message at 2026-06-12T08:38:57-07:00 in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributor: Denny Zhang)._

_Window: 7d delta (1-message P0 exception — <5 threshold waived; SEV0 fleet state warrants capture)._

## P0 — bot-integration-blocking items

**S675130 (SEV0 "Facebook, IG, WA, etc down") → S675238 (SEV1 "AI Training SEV0 S675130 Response"): ALL training jobs disabled fleet-wide.**
As of 2026-06-12 08:07am PDT, all offline, recurring, and online training jobs were disabled across MAST, Flow, and Online Training (Denny Zhang, 08:38 PT). Both SEVs In Progress as of 09:00 PT.

**Bot must suppress individual model fleet-health alerts while fleet pause is in effect.** Every trainer-behind / age-climb signal in the fleet is expected and explained during this window — not a model-specific failure. Raising act-now flags during a declared fleet-wide outage pause adds noise, not signal.

**Post-SEV recovery window: expect fleet-wide age spike, not individual model failures.** When jobs resume, training ages will be elevated across all models simultaneously. Bot should classify this as "post-S675130 recovery" and not generate per-model trainer-behind alerts until ages return to normal baseline (typically 1-2h after job restart).

## P1 — significant nuance / sub-mechanisms

**New SEV class: site-wide outage triggering ML training fleet pause.**
S675130-class events (full site outage) drive an intentional fleet-wide training pause (S675238-class response). OT bot should recognize the pattern: when S675238-class SEV is active and cites a site-wide root cause, ALL fleet signals should be interpreted in that context. Confirm fleet resume by checking OT job restart timestamps, not by waiting for age to drop.

## P2 — references / good-to-know

- S675130: https://www.internalfb.com/sevmanager/view/675130 (SEV0, In Progress)
- S675238: https://www.internalfb.com/sevmanager/view/675238 (SEV1, In Progress, "AI Training SEV0 S675130 Response")

## Cross-references

- Carry-forward from 2026-06-11: two IG TIER_1 trainer-behind models (2134319967 88m, 2137792444 57m) that were flagged as act-now items — these are now superseded by the fleet-wide pause. Re-evaluate post-resume.

## Open coordination threads

- **S675130 / S675238 resolution**: monitor for fleet resume announcement; reset fleet-health baseline after jobs restart.
- **IG TIER_1 trainer-behind carry-forward** (2134319967, 2137792444): confirm whether these were already in debugging before fleet pause, or will be first evaluated post-resume.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Fleet-wide outage pause: suppress per-model alerts when SEV238-class active | ot-fleet-health: check for active S67XXXX-class training-pause SEVs before emitting act-now | 1h |
| P0 | Post-SEV recovery classification: age spike = recovery, not per-model failure | ot-fleet-health: add post-outage-recovery state detection | 1h |
| P1 | SEV class taxonomy: site-outage → training-fleet-pause pattern | known-patterns.md: add S675130-class entry | 30m |
