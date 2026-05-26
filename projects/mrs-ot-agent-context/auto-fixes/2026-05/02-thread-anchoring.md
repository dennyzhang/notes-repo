```yaml
fix_id: thread-anchoring
title: All bot/operator replies anchor to originating triage thread
status: 🟡 drafted
identified: 2026-05-20 thread jrXXZbszX8E
target: team_bot/cron-jobs/*.md (every cron that posts to chat) + bot's own discipline rules
section: GChat output / threading
impact: Preserve audit trail per-incident; eliminate cross-thread context split
cost: ~5-line cron prompt amendment per cron + add to bot's CLAUDE.md
```

## Gap

When a cron posts a triage in thread X (with `Bot reply: ...thread-X` URL), subsequent operator follow-ups, audit corrections, or bot self-corrections sometimes land in a DIFFERENT thread Y. Examples observed today:

1. ot-triage-auditor at 04:21 PDT found WRONG-MODEL-REPLY: m877766932 verdict landed in thread 0ad4RSnVzyQ but the conversational reply in same thread covered m2126189932 (Cluster B) — model_id mismatch between thread anchor and content. (Auditor proposed new rule R-EV5: model_id in bot reply must match triggering cron post.)
2. ot-alert-monitor cluster A vs cluster B in same run land in separate threads; if operator replies to cluster A's thread but their commentary covers cluster B → orphaned context.

## Triggering evidence

- 2026-05-20 04:21 PDT ot-triage-auditor finding (R-EV5 candidate)
- 2026-05-20 thread jrXXZbszX8E operator feedback: "you need to reply chat thread, which is here"

## Patch

### Before

(In cron prompt — threading guidance, often implicit)

```
(no explicit thread guidance)
```

### After

```
THREAD ANCHORING DISCIPLINE

When emitting a cron triage:
  - Each cluster's triage gets its own thread anchor (existing behavior)
  - The triage emit includes `Bot reply: https://chat.google.com/room/<space>/<thread_id>`
  - The model_id / SEV# / alert_id referenced in the triage CONTENT must
    match the thread anchor's content
  - NEVER mix multiple clusters' content into one thread reply

When emitting a follow-up to a prior triage:
  - Identify the originating thread by matching the alert_id / sev_number /
    model_id to the most recent prior bot emit
  - Reply in THAT thread, not the main space top-level
  - If the originating thread can't be identified, default to main space
    BUT explicitly note "no thread anchor — please react in main space"

When the operator replies to a triage thread asking for corrections:
  - Bot's reply MUST land in the same thread (use the thread_id from
    the operator's reply event)
  - Cross-thread split breaks audit trail; the auditor cannot reconstruct
    what was corrected vs. what stood

SANITY CHECK: after emit, verify thread_id of the message matches the
target thread expected for the alert_id / sev_number / model_id. If
mismatch → log warning + retry in correct thread.
```

## Why this fix

Threads in gchat are how operators navigate per-incident discussion. Cross-thread split is exactly the same observability problem we've been flagging at the system level: events scattered across siloed conversations are hard to reconcile. The ot-triage-auditor explicitly flagged this twice today; that's signal that we need codified rules + enforcement.

## Validation

- [ ] After landing, audit 20 consecutive cron emits + operator follow-ups; 100% should respect thread anchoring
- [ ] R-EV5 (auditor rule, candidate from 2026-05-20 04:21 PDT) — bot reply model_id matches triggering cron's anchor model_id — 0 violations in 7d window
- [ ] No "Bot reply in different thread" warnings in cron log

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F output-quality checklist
- `01-alert-url-full-id-encoding.md` (companion link-validation fix)
- `~/.myclaw-ot-bot/CLAUDE.md` discipline section (proposed addition)
