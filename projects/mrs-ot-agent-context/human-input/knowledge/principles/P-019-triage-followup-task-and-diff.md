# P-019: Deep-Triage Follow-up = File the Task AND (If Fixable) Author the Diff — Don't Stop at the Task, Don't Ask

**Statement:** When deep triage of an issue surfaces a concrete fix, the standing pattern is: (1) **file a meta task** to track it (`owner=dennyzhang`), (2) **keep updating the task's findings** as the diagnosis sharpens, and (3) **if it's fixable, author the `--draft` diff** — do not stop at the task, and do not back off into "want me to make the diff?" Filing the task is necessary but NOT sufficient; the diff is the deliverable when the fix is in reach. The only thing left for the human is review/land (the irreversible step the bot is read-only on).

**Discovered:** 2026-06-13 thread `Nk_Ui4WFn4U`. Operator, after the bot deep-triaged the `ig_retrieval` MRB-reset checkpoint churn (model 2137792444 / S675238) to an exact code path but filed only a task and asked whether to make the diff: *"Why ask"* → *"You should create task and diff. This is generic feedback for follow-up like this type of issues"* → *"You should file a meta task, and update your findings when you are clear. If fixable, create the diff."*

**Why it matters:** Backing off to "task filed, want the diff?" when the fix is already pinned to a `file:line` is confirmation-bait — it spends an operator round-trip to authorize work the bot could just do (the diff is `--draft`, reversible, and the human still gates the land). Stopping at the task lets a verified, fixable root cause sit idle. The task is the *tracker*; the diff is the *fix*. For a fixable issue both are owed in one pass.

**The bar for "if fixable":** the fix is fixable-now when the triage has produced a verified `file:line` site, a concrete change, and the change is in-scope (in a repo the bot can edit, `--draft` only). If the site/change is still ambiguous, the honest move is to keep the task open and update findings — NOT to ship a guessed diff. (3 legitimate back-offs preceded D108525530 because the site was genuinely ambiguous; the 4th proceeded because the trunk gap — `assert model_instance is not None` instead of anchor-fallback — was verified.) So: back off on *ambiguity*, never on *"should I bother."*

**Applies to:** any triage/investigation follow-up that yields a code or config fix — bot-specific or generalizable. The dual-artifact (task + draft diff) is the default close-out shape for a fixable finding.

## The pattern
```
Deep triage surfaces a fix?
  ├─ File the tracking task (owner=dennyzhang)             [always]
  ├─ Update the task findings as the diagnosis sharpens     [always, P-016]
  └─ Is the fix fixable-now (verified file:line + concrete in-scope change)?
        ├─ Yes → author the --draft diff, attach to the task. Don't ask.
        └─ No (site/change still ambiguous) → keep task open, update findings, dig. Don't ship a guess.
```

## Enforcement
- Worked instance: T275782360 (tracker) + D108525530 (`--draft` fix) — `ig_retrieval/job_resolver.py` anchor-fallback, filed in one pass per this principle.
- Refines [P-016](./P-016-full-ownership-on-every-fix.md) (full ownership / no confirmation-bait) with the concrete dual-artifact shape for triage follow-ups; complements [P-017](./P-017-upstream-issue-decisive-metric-task.md) (when the fix is UPSTREAM/out-of-lane, the task carries a decisive metric instead of a diff) and the autonomous-task-lifecycle rule (drive the task to close, escalate only the human-gated step).

**Related:** [P-016](./P-016-full-ownership-on-every-fix.md) · [P-017](./P-017-upstream-issue-decisive-metric-task.md) · [P-001](./P-001-act-dont-ask-for-readonly.md) · [P-003](./P-003-generalize-to-system-rule.md).
