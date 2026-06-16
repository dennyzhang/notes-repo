```yaml
fix_id: enforcement-hooks-design
title: Pre-emit linter for cron output quality (link validation + thread anchoring + structured-output)
status: 🟡 drafted (design only; build is separate work)
identified: 2026-05-20 thread jrXXZbszX8E (operator framing: "write down + hooks for enforcement")
target: NEW cron infrastructure — pre-emit linter pass
section: Cron emit pipeline
impact: Enforces output-quality rules at machine speed, not via discipline-rule prose
cost: ~1 week initial build; ongoing maintenance as rules evolve
```

## Gap

Writing "always validate links" / "always anchor to thread" in a discipline doc is talk, not enforcement. Without a HOOK that checks before emit, the rules drift back to "rely on the bot remembering". Operator framing: discipline rules need enforcement hooks, not just markdown.

## Design

### Architecture

```
┌─────────────────────┐
│  Cron prompt        │
│  generates draft    │
│  emit text          │
└──────────┬──────────┘
           │ draft_emit_text
           ▼
┌─────────────────────┐
│  PRE-EMIT LINTER    │   ← NEW: catches violations
│  (rules engine)     │     before delivery
└──────────┬──────────┘
           │ {pass, fail+reason, fixed_text}
           ▼
   ┌───────┴───────┐
   │ pass?         │
   ├───────────────┤
   │ yes → emit    │
   │ no  → log +   │
   │       retry / │
   │       human   │
   └───────────────┘
```

### Linter rules (initial set, derived from 2026-05-19/20 session findings)

| Rule ID | Check | Action on violation |
|---|---|---|
| L-LINK-01 | Alert URL has `%40%23%24` (URL-encoded `@#$`) suffix OR no alert URL | reject; require full alert_id |
| L-LINK-02 | SEV URL matches `internalfb.com/sevmanager/view/\d+` form | reject; reformat |
| L-LINK-03 | Paste URL matches `internalfb.com/intern/paste/P\d+/` | reject; reformat |
| L-LINK-04 | MLHub URL has `?...&job_attempt=...&version=...&tab=...` (not bare) | warn |
| L-THREAD-01 | Bot reply's thread_id (if specified) matches an existing cron-output thread for the same alert_id/sev_number/model_id | warn |
| L-THREAD-02 | Bot reply's content's model_id matches the thread anchor's model_id (auditor R-EV5) | reject |
| L-CITE-01 | Verdict cites CL-NNN / S-NNN / M-NNN / R-NNN OR explicitly notes "no matching cluster" | warn |
| L-CITE-02 | Confidence claim ("high"/"medium") supported by ≥1 verified evidence line | warn |
| L-CITE-03 | PAGE verdict has explicit owner + escalation channel | reject |
| L-FAMILY-01 | If R-VC4 family-recurrence ratio ≥3 in 24h, verdict prefix has "⚠️ HOT CELL" or family-escalation language | warn |

### Implementation sketch

```python
# Pseudocode for the linter
def lint_emit(draft_text, context):
    rule_results = []
    for rule in LINTER_RULES:
        result = rule.check(draft_text, context)
        rule_results.append(result)
    
    violations = [r for r in rule_results if r.severity == "reject"]
    warnings = [r for r in rule_results if r.severity == "warn"]
    
    if violations:
        return {
            "pass": False,
            "violations": violations,
            "suggested_fixes": [r.suggested_fix for r in violations],
            "action": "block_emit_or_retry",
        }
    
    return {
        "pass": True,
        "warnings": warnings,
        "action": "emit_with_warnings",
    }
```

### Integration with existing crons

- Each cron's prompt gets a final step: "Before emitting, pass draft through lint_emit(). If reject → revise per suggested_fixes; if persistent fail → emit anyway but log violation count for audit."
- Daemon-level: log all linter results (pass / warn / reject) to a state file for trending.
- Auditor cron: includes linter-violation count in daily summary.

### Phased rollout

| Phase | Duration | Action |
|---|---|---|
| 1 | 1 day | Build linter scaffold + L-LINK-01 (the immediate alert URL fix) |
| 2 | 3 days | Add L-THREAD-01, L-THREAD-02 (auditor R-EV5 catch) |
| 3 | 1 week | Add L-CITE-01..03 (registry citation rules) |
| 4 | 1 week | Add L-FAMILY-01 (R-VC4 trigger) |
| 5 | ongoing | Tune severity thresholds; add new rules as gaps surface |

### Where the linter runs

Two options:
- **In the cron prompt** (Claude self-lints): cheap to build, can be inconsistent; relies on prompt discipline
- **As a daemon-level interceptor** (intercepts cron emit before delivery): more reliable, but requires daemon code change

Recommend starting with prompt-side self-lint (Phase 1-2), then promoting to daemon-interceptor when the rule set stabilizes (Phase 3+).

### Bot's own self-discipline (no enforcement, but rules captured)

The operator-framing was specifically: "you should write down into your claude markdown". The bot's `~/.myclaw-ot-bot/CLAUDE.md` and `RULES.md` should also gain these discipline rules so the bot itself honors them in operator-thread replies (not just cron triages).

Proposed additions to `~/.myclaw-ot-bot/CLAUDE.md`:

```
## Output discipline (added 2026-05-20)

Before sending any response in chat:

1. **Validate every link.** Alert URLs must include the full alert_id
   with %40%23%24 suffix. SEV URLs use canonical form. Paste URLs use
   /intern/paste/P<num>/ form. Click-through validity > brevity.

2. **Anchor replies to the originating thread.** When responding to a
   cron triage or operator question, reply in the SAME thread, not
   cross-thread. Audit trail integrity > convenience.

3. **Cite cluster classification.** Verdicts should reference CL-NNN /
   S-NNN / M-NNN / R-NNN / P-NNN entries from the patterns/ registry.
   Don't re-derive from first principles.

4. **R-VC4 family check.** Before per-incident MONITOR verdict, check
   inventory/heatmap.md for hot cells in this PG/product/pattern slice.
   If hot → prepend "⚠️ HOT CELL" + family-escalation framing.

5. **Verify push state.** When committing to notes/, run
   `sl log -r <hash> --template '{remotebookmarks}'` to confirm push
   succeeded before saying "pushed".
```

These rules apply to bot's interactive responses; the linter applies to
cron emits. Both are needed because the failure modes differ.

## Validation

- [ ] Phase 1 build catches the alert URL truncation bug (re-run 2026-05-20 cluster B verdict through linter → reject + suggested fix)
- [ ] Phase 2 catches the auditor R-EV5 wrong-model-reply finding
- [ ] Audit log shows declining violation count week-over-week as rules tighten

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F output-quality checklist
- All auto-fixes in this 2026-05-20 batch (01-15) are inputs to the linter rules
