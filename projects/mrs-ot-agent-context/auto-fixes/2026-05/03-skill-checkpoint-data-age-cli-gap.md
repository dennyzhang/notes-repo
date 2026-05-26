```yaml
fix_id: skill-checkpoint-data-age-cli-gap
title: SKILL.md — checkpoint_training_data_age_mins is NOT queryable via meta CLI
status: 🟡 drafted
identified: 2026-05-17 (daily-ledger.md L11)
target: mrs-ot-agent-src/SKILL.md (Triage Discipline section)
section: Triage Discipline
impact: Prevents false PAGE/MONITOR when sole signal is unverifiable
cost: 2-line bullet
```

## Gap

`checkpoint_training_data_age_mins` is a OneDetection-only metric — there is no `meta` CLI surface that returns the current value. When this is the **sole** primary alert signal, the bot can neither verify staleness independently nor distinguish a real lag from the known Scuba-formula bug (D75703936; see CL-013 in `auto-learnings/failure-patterns.md`).

## Triggering evidence

- ot-alert-monitor 13:32 PDT 2026-05-16; model 877766932 — bot fabricated a root cause because it had no way to verify the metric
- CL-013 false-spike confirmed in 2026-W21 mega-learning (Part 1, entry 6) — 2nd recurrence on same model in <2 weeks, formula bug still unfixed

## Patch

### Before

(In `SKILL.md` Triage Discipline — no guidance for unverifiable single-signal alerts)

### After

```
- **`checkpoint_training_data_age_mins` is NOT queryable via meta CLI.** If it is the sole primary alert signal:
  emit `confidence: low` / `class: NEEDS_INVESTIGATION`, name the Scuba query to verify
  (`dpp_worker.scribe_example_age_ms.avg.60` is the OT-correct proxy), and route to the model owner +
  OneDetection alert owner for ground truth. Do NOT page on this signal alone.
```

## Why this fix

Closes a class of fabricated triages where the bot guessed at root cause because it had no verification path. Tells the bot to admit the gap and route correctly.

## Validation

- [ ] Replay m877766932 2026-05-16 13:32 PT alert — bot now emits `confidence: low` instead of fabricated root cause
- [ ] Replay any alert where `checkpoint_training_data_age_mins` is one of many signals — still gets full triage (rule only applies when SOLE signal)

## Related

- `auto-learnings/failure-patterns.md` CL-013
- Memory rule 21+40 (mandatory ZippyDB query for `client_lag_in_seconds`) — same family of "mandate the verification step"
