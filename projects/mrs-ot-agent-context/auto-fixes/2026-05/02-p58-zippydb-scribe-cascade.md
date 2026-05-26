```yaml
fix_id: p58-zippydb-scribe-cascade
title: Add P58 — ZippyDB RE throttling → scribe_read_proxy client_lag alert
status: 🟡 drafted
identified: 2026-05-17 (daily-ledger.md L12)
target: mrs-ot-agent-src/known_patterns.md (Quick-Match Table)
section: Quick-Match Table
impact: Auto-classifies CL-003 cascade alerts as UPSTREAM_INFRA without per-alert triage
cost: ~3-line table row
```

## Gap

ZippyDB RE-session throttling cascades to `scribe_read_proxy.client_lag_in_seconds` alerts on STUS models. Trainer + publish path are healthy; the alert is downstream-visible only. Bot currently re-derives this from first principles on every fire, which has wasted ~10 triage cycles in two weeks (see daily-ledger and 2026-W21 mega-learning entry 2).

## Triggering evidence

- ot-alert-monitor 02:24 PDT 2026-05-17; model 878102693; root SEV S665163
- ot-alert-monitor 21:13 PDT 2026-05-24; model 2133539495; root SEV S667358
- ot-alert-monitor 11:05 PDT 2026-05-24; model 2144816217; same S667358
- 3+ independent fires/week on different models, same mechanism

## Patch

### Before

(In `known_patterns.md` Quick-Match Table — no row for ZippyDB → Scribe cascade)

### After

```
| P58 | ZippyDB RE throttle → Scribe client_lag | Primary signal = scribe_read_proxy.client_lag_in_seconds; STUS publishing normally; ≥1 active ZippyDB SEV | UPSTREAM_INFRA / NO_ACTION (CL-003) — auto-clears with upstream SEV | meta sevmanager.sev list --in-progress --title-contains=zippydb |
```

## Why this fix

Single Quick-Match line covers a recurring cascade. Pairs with `auto-fixes/2026-05-17/05-ot-alert-monitor-zippydb-scribe-rule.md` which wires the same check into the cron-prompt Step 0.

## Validation

- [ ] Replay 2026-05-24 21:13 PT m2133539495 alert — bot emits P58 verdict citing S667358 in <30s
- [ ] If ZippyDB SEV list is empty → falls through (don't over-suppress)
- [ ] If trainer NOT publishing (e.g. v stuck) → falls through (REAL_OT_FAILURE path)

## Related

- `auto-fixes/2026-05-17/05-ot-alert-monitor-zippydb-scribe-rule.md` (cron-prompt rule)
- `auto-learnings/failure-patterns.md` — CL-003 Downstream-infra reliability
