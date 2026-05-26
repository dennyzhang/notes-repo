# Thread Summary: Out-of-Scope SEV 659877 (Serving-Tier) + ordering_bug Detection Class

_Source: spaces/AAQAVOjYc80 thread `DbIQXo1gSBQ` · 6 messages · 2026-05-16 07:22–09:51 PDT_
_Summarized: 2026-05-16 22:31 PT · last-msg-time: 2026-05-16T16:51:48.226608Z_

## What was discussed

Denny posted a bot R18-drop diagnosis for S659877, a T4 serving-stage SEV that `ot-sev-monitor` had surfaced despite having no `mvai-online-training` tag and no MAST job for model 2126510319 (ig_mixed_feed_e2i_retrieval, FBLEARNER_FLOW). This was a scope-creep bug: the monitor was over-matching serving-tier SEVs likely via title keyword fuzzy-match. Denny then directed the bot to follow up directly and automate the detection rather than itemize pending lists. The bot landed two fixes: (1) a notification-ordering note in `ot-sev-monitor.md` and (2) a new `ordering_bug` detection class in `ot-cron-health-watch.md`.

## Key decisions made

- (2026-05-16T16:48:09 Denny): "You should follow up directly next time" — bot should edit the cron prompt instead of listing a pending item. Decision establishes "single-file prompt edit, reversible → just do it" rule.
- (2026-05-16T16:48:09 Denny): "How to make this follow-up automatically" — drove addition of `ordering_bug` detection class to `ot-cron-health-watch`, detecting 🚨 parent + `[OUT-OF-SCOPE]` reply within 15 min.
- (2026-05-16T16:51:38 Denny): Approved draft of `ordering_bug` class addition with "ok".

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../cron-jobs/ot-sev-monitor.md` | Added ORDERING NOTE: filter serving-tier SEVs with no mvai-training MAST job before surfacing |
| `~/notes/.../cron-jobs/ot-cron-health-watch.md` | Added step 6.5 `ordering_bug` detection class; HEARTBEAT counter field `ordering_bugs: O` |

## Cluster / pattern references

- [CL-007] — Cross-org leaks via tag broadness; this is a variant: serving-tier SEV leaking into OT monitor scope via keyword over-match
- [R18] — Cross-org filter rule; this incident exposed a gap in R18's scope for serving-stage vs training-stage SEVs

## Followup items (not yet done)

1. Investigate `ot-sev-monitor` filter over-match mechanism (likely "snapshot"/"training" in SEV title) — root cause not confirmed, just mitigated via ordering note

## Cross-refs

- SEVs discussed: S659877 (T4 serving-tier IGML capacity, out-of-scope), S664024 (referenced as prior retraction example)
- Related threads: `aT_6RlZgMwg` (ordering_bug concept first identified there)
