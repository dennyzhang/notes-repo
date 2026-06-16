```yaml
fix_id: ot-alert-monitor-zippydb-scribe-rule
title: ot-alert-monitor — learned rule: scribe_read_proxy client_lag → ZippyDB SEV check
status: 🟡 drafted
identified: 2026-05-17 (daily-ledger.md L12)
target: mrs-ot-agent-src/team_bot/cron-jobs/ot-alert-monitor.md (Learned Rules section)
section: Learned Rules
impact: Pairs with P58 — encodes the Step 0 verification as a cron-prompt rule
cost: ~5-line learned-rule entry
```

## Gap

`pending-proposals.md` originally noted: "daily-ledger noted 'NOT executed this run — L12 is classified domain-pattern, not operational'." That is, the proposal was filed but never translated into the runtime cron prompt. The pattern keeps re-firing (3+ times in 8 days on different models — see `auto-fixes/2026-05-17/02-p58-zippydb-scribe-cascade.md` evidence) and the bot keeps re-deriving the diagnosis.

## Triggering evidence

- Same as `02-p58-zippydb-scribe-cascade.md` — 3+ independent fires across m878102693, m2133539495, m2144816217
- Memory rule 21+40 already mandates this check; codifying it in the cron prompt closes the loop

## Patch

### Before

(In `ot-alert-monitor.md` Learned Rules — no scribe_read_proxy / ZippyDB rule)

### After

```
- **L<NN> — scribe_read_proxy client_lag → ZippyDB SEV check (P58).** When the primary alert signal is
  `scribe_read_proxy.client_lag_in_seconds` AND the trainer's MAST job is RUNNING AND `dai_modelstore`
  shows fresh deltas, run `meta sevmanager.sev list --in-progress --title-contains=zippydb` BEFORE
  any deeper triage. If ≥1 active ZippyDB SEV: emit P58 / UPSTREAM_INFRA / NO_ACTION citing the SEV
  number; auto-clears when SEV mitigates. If 0 active ZippyDB SEVs: fall through to standard triage.
```

## Why this fix

Encodes the mandatory verification step that has been forgotten 3+ times in 8 days. Pairs with P58 (the verdict label) — the SKILL/known_patterns side gives the label, this rule wires the actual CLI check into the cron's Step 0.

## Validation

- [ ] Replay 2026-05-24 11:05 PT m2144816217 alert — bot runs zippydb SEV query in Step 0, emits P58 with S667358 citation
- [ ] If ZippyDB SEV list is empty → standard triage path (no false-suppress)
- [ ] Confirm SQLite runtime prompt updated (notes-side .md edit alone has zero runtime effect — see memory: `gotcha_sqlite-prompt-canonical.md`)

## Related

- `auto-fixes/2026-05-17/02-p58-zippydb-scribe-cascade.md` (the P-row)
- Memory rule 21+40 (the verification mandate this codifies)
