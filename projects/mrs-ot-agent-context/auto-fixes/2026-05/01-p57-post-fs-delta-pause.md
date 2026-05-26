```yaml
fix_id: p57-post-fs-delta-pause
title: Add P57 — post-FULL_SNAPSHOT delta pause is TRANSIENT_NOISE
status: 🟡 drafted
identified: 2026-05-17 (daily-ledger.md L10)
target: mrs-ot-agent-src/known_patterns.md (Quick-Match Table)
section: Quick-Match Table
impact: Suppresses false-positive delta-publishing-gap alerts during FS→delta transition
cost: ~3-line table row
```

## Gap

After a FULL_SNAPSHOT lands, models pause delta publishing for the time it takes the trainer to resume the delta cadence (observed ~33 min on `fb_reels_ifu_mtml_v0`). During that window, the delta-publishing-gap alert fires even though the model is healthy. Bot currently has no P-row for this and ends up running a full triage every time.

## Triggering evidence

- ot-alert-monitor 04:27 PDT 2026-05-16; model 883552231
- Same mechanism re-fires on this model family roughly weekly

## Patch

### Before

(In `known_patterns.md` Quick-Match Table — no row for post-FS delta pause)

### After

```
| P57 | Post-FULL_SNAPSHOT delta pause | Delta-publishing-gap alert fires <2× expected gap after a fresh FULL_SNAPSHOT timestamp | TRANSIENT_NOISE — verify next delta lands within 2× expected gap; if so, NO_ACTION | dai_modelstore.ds_partition_count where snapshot_type=FULL_SNAPSHOT (timestamp), then SPARSE_DELTA cadence |
```

## Why this fix

Converts a recurring ~5-min full triage into an O(1) Quick-Match Table hit. The mechanism is benign by design.

## Validation

- [ ] Replay alert on m883552231 from 2026-05-16 04:27 PT — bot emits P57 verdict in <1 min
- [ ] No FULL_SNAPSHOT events within 2× expected gap → falls through to next pattern (don't over-suppress)

## Related

- `auto-fixes/2026-05-17/04-skill-post-fs-delta-pause-check.md` (SKILL.md companion rule)
- `auto-learnings/failure-patterns.md` (CL registry — may want CL-NNN cross-ref once P57 lands)
