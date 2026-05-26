```yaml
fix_id: skill-post-fs-delta-pause-check
title: SKILL.md — verify last FULL_SNAPSHOT timestamp before escalating delta-gap
status: 🟡 drafted
identified: 2026-05-17 (daily-ledger.md L10)
target: mrs-ot-agent-src/SKILL.md (Triage Discipline section)
section: Triage Discipline
impact: Auto-suppresses post-FS delta-gap alerts (companion to P57)
cost: 2-line bullet
```

## Gap

Before escalating any delta-publishing-gap alert, the bot must check whether the alert window falls within the model's FS→delta resume gap. Currently it doesn't, leading to false escalations on a recurring benign pattern. This SKILL bullet is the procedural companion to P57 in `known_patterns.md`.

## Triggering evidence

- ot-alert-monitor 04:27 PDT 2026-05-16; model 883552231
- Recurring family-wide pattern on `fb_reels_ifu_mtml_v0` and siblings

## Patch

### Before

(In `SKILL.md` Triage Discipline — no FS→delta gap check)

### After

```
- **Post-FULL_SNAPSHOT delta pause:** Before escalating a delta-publishing-gap alert, verify the last
  FULL_SNAPSHOT timestamp vs alert onset. If the alert falls within 2× the model's expected delta cadence
  after a FULL_SNAPSHOT, classify TRANSIENT_NOISE and wait for the next delta. Apply P57 verdict.
```

## Why this fix

Prevents the bot from triaging away on the symptom while the cause (an intentional pause) is right there in `dai_modelstore`.

## Validation

- [ ] Replay m883552231 2026-05-16 04:27 PT alert — bot checks FS timestamp first, emits TRANSIENT_NOISE
- [ ] If delta does NOT resume within 2× expected gap → escalate normally

## Related

- `auto-fixes/2026-05-17/01-p57-post-fs-delta-pause.md` (the P-row)
