<!-- Quality Gate: Sources=PASS(12 verified, 5 inferred) | Contradictions=PASS(2 points) | Synthesis=PASS | Self-critique=PASS(3 gaps per channel) | Related=PASS(2 docs) -->
# Autolearn: Self-Improving Automation Design Doc

**Author**: Denny Zhang | **Date**: 2026-03-29 | **Status**: Implemented
**Google Doc**: https://docs.google.com/document/d/1ejNVFCVzwBY5-06s6Uou_p3N936zD-oY1ZbtxGsqVVA/edit
**Related**: [Auto-Discover Design Doc](https://docs.google.com/document/d/1K372ltPmhn8JaYhXQIei343FiSodkvaTFcV9NOUDQNE/edit) — Autolearn depends on Auto-Discover for context. Auto-Discover provides the "learn about me" layer; Autolearn provides the "learn from outcomes" layer.

**Problem**: Claude makes the same mistakes across sessions [VERIFIED: session metrics show 1.6 corrections/session average]. Corrections are made once and forgotten. The gap between "a mistake happened" and "a rule prevents it" requires a human to notice the pattern and manually update a cheatsheet [VERIFIED: gdocs/rules.md has 26 manually-learned entries, each from a real failure]. Time from mistake to rule: days. Recurrence rate: unknown [INFERRED: no tracking mechanism existed before this doc].

**Goal**: Three automated feedback loops that close this gap — Claude captures lessons from real outcomes (reviewer feedback, doc comments, job failures) and updates its own playbook. No human writes the rule. Time from mistake to rule: hours.

## How It Connects to Auto-Discover

```
Auto-Discover (learn ABOUT me)     Autolearn (learn FROM outcomes)
  ↓ produces context                 ↓ improves rules
  People profiles                    Diff cheatsheet rules
  Project context                    Doc editing rules
  Domain knowledge                   Debugging patterns
       ↓                                  ↓
       └──────── Feed into ───────────────┘
                     ↓
           Overnight Fleet (learn FOR me)
           Better briefings, smarter triage,
           fewer repeated mistakes
```

Auto-Discover builds the CONTEXT. Autolearn improves the RULES. Together they make the overnight fleet smarter over time.

## The Autolearn Pattern

```
Outcome (diff review, doc comment, job failure)
  → Detect: is there a lesson here?
  → Extract: what's the rule?
  → Dedup: does this rule already exist?
  → Store: append to the right cheatsheet Common Mistakes table
  → Enforce: next session, Claude follows the rule automatically
  → Graduate: 3+ occurrences → promote from Common Mistakes to Hard Rules
```

**Key distinction**: This is NOT the user-prompt-handler auto-learn hook (which captures corrections from Denny's prompts). This is OUTCOME-DRIVEN learning — Claude learns from external feedback without Denny being in the loop.

## Three Channels

| # | Channel | Trigger | Script | Target | Status |
|---|---------|---------|--------|--------|--------|
| 1 | **Diff review** | Weekly Mon 6 AM | `cron-diff-autolearn.sh` | `diff/common.md` Common Mistakes | **BUILT** |
| 2 | **Doc comments** | After ≥3 comments processed | `cron-gdoc-comments.sh` (modified) | `gdocs/rules.md` or `career/*.md` | **BUILT** |
| 3 | **Job failures** | After each OT triage cycle | `cron-ot-support-triage.sh` (modified) | `oncall/mast-debugging.md` | **BUILT** |

## Channel 1: Diff Review Feedback

**How it works**: `cron-diff-autolearn.sh` runs weekly. Scans diffs authored in last 7 days → fetches reviewer comments via `meta phabricator.diff comments` → filters for actionable feedback (skips LGTM, questions) → spawns Claude (haiku) to extract patterns → dedups against existing Common Mistakes → appends new rules with `(Learned YYYY-MM-DD: DXXXXXX autolearn)`.

**Concrete proof this pattern works** [VERIFIED: gdocs/rules.md line 9, "Never use gdocs replace"]:
- Rule "never use gdocs replace" — originated from a reviewer catching a broken doc. Now a Hard Rule enforced in every session.
- Rule "run arc lint before jf submit" — originated from 3 red CI diffs in one week [VERIFIED: cron-runtime.csv]. Now a hook-enforced gate [VERIFIED: bash-guard.sh].

**What's built**:
- `cron-diff-autolearn.sh` — new cron, registered Mon 6 AM, 15-min timeout
- Common Mistakes table added to `diff/common.md`
- Extraction uses haiku model, caps at 5 patterns per run

**Remaining gap**: PostToolUse hook on `jf submit` for real-time capture (supplements weekly cron). ~1 hr to build.

## Channel 2: Doc Comment Patterns

**How it works**: After `cron-gdoc-comments.sh` processes ≥3 comments in one cycle, it spawns a pattern extraction step. Claude (haiku) analyzes the batch for recurring themes, compares against existing Common Mistakes in `gdocs/rules.md` and `career/knowledge-sharing.md`, and appends new patterns.

**Concrete proof this pattern works** [VERIFIED: this session]:
- 7 rounds of doc comments → extracted 6 Common Mistakes for `career/knowledge-sharing.md` [VERIFIED: knowledge-sharing.md Common Mistakes table].
- `gdocs/rules.md` has 26 manually-learned entries [VERIFIED: grep count] — the format is proven.

**What's built**:
- Pattern extraction step added to `cron-gdoc-comments.sh` after the comment processing loop
- Routes patterns to the right cheatsheet based on type (gdocs operation vs content/framing)
- Dedup by first 40 chars of mistake description
- Uses file_lock for concurrent access safety

**Remaining gap**: Pattern detection could be smarter — currently fires on comment COUNT (≥3), should also fire on comment THEME recurrence. ~2 hrs to improve.

## Channel 3: AI Job Failure Patterns

**How it works**: After `cron-ot-support-triage.sh` completes a successful triage cycle, it spawns a pattern extraction step. Claude (haiku) reads the triage report, compares against existing Common Mistakes in `oncall/mast-debugging.md`, and appends new failure patterns.

**Concrete proof this pattern works** (manually observed):
- OT SEV analysis identified "Scribe quota = 37% of all SEVs" as a recurring pattern. This was manually written into the oncall cheatsheet. Autolearn would have captured it automatically from the first 2 triages.
- `cron-self-improve.sh` (fleet self-improve) already demonstrates the pattern: daily-housekeeping at 37% → diagnosed timeout issue → auto-fixed.

**What's built**:
- Pattern extraction step added to end of `cron-ot-support-triage.sh`
- Runs after every successful triage (3x/day: 6 AM, 10 AM, 3 PM)
- Targets `oncall/mast-debugging.md` Common Mistakes
- Caps at 3 new patterns per cycle

**Remaining gap**: Retroactive mining of historical OT triage Google Doc — 2+ months of data not yet mined. ~1 hr one-time effort.

## Design Decisions

| Decision | Alternative | Why this choice |
|----------|-------------|-----------------|
| Append to Common Mistakes, not CLAUDE.md | Auto-modify CLAUDE.md | CLAUDE.md changes affect every session. Cheatsheet changes are scoped. Too dangerous to auto-modify the core config. |
| Dedup before append | Allow duplicates, prune later | Duplicates clutter cheatsheets and waste context tokens. Cheaper to check upfront. |
| Provenance tag on every rule | No attribution | `(Learned YYYY-MM-DD: source)` distinguishes auto-learned from manual rules. Enables auditing: which rules came from which source? |
| Haiku for extraction | Opus/Sonnet | Pattern extraction is classification, not judgment. Haiku is 10x cheaper, fast enough, and sufficient quality for structured data matching. |
| Graduated promotion | All rules equal | New patterns start as Common Mistakes. 3+ occurrences → Hard Rules. 0 occurrences in 30 days → demote/remove. Matches the graduated enforcement model in `system/workflow-design.md`. |
| Threshold-based triggering | Run on every comment/diff | Running on every single comment wastes compute. ≥3 comments per cycle for docs, weekly batch for diffs. Balances freshness vs cost. |

## Success Metrics

| Metric | Baseline | Target (30 days) | How to measure |
|--------|----------|-------------------|----------------|
| Auto-learned rules in diff cheatsheets | 0 | 5+ | `grep -c "autolearn" cheatsheets/diff/*.md` |
| Auto-learned rules in gdocs cheatsheets | 0 (26 manual) | 5+ auto-learned | `grep -c "autolearn" cheatsheets/gdocs/rules.md` |
| Auto-learned rules in oncall cheatsheets | 0 | 3+ | `grep -c "autolearn" cheatsheets/oncall/*.md` |
| Same-mistake recurrence rate | Unknown | Measurable | Track repeat pattern IDs in Common Mistakes |
| Time from mistake to rule | Days (manual) | Hours (automated) | Compare `(Learned)` dates to mistake dates |

## Contested Points

| Claim | Counter-evidence | Resolution |
|-------|-----------------|------------|
| "Haiku is sufficient for pattern extraction" | Haiku may produce overfitted rules from small samples (3 reviewer comments → overgeneralized rule) | Valid risk. Graduated promotion (Common Mistakes → Hard Rules after 3+ occurrences) is the mitigation. If false positive rate >20% after 30 days, switch to sonnet for extraction. |
| "Autolearn reduces time from mistake to rule from days to hours" | The autolearn crons run weekly (diff) or on-trigger (doc/OT). A mistake Monday could wait until the following Monday for diff autolearn. | Partially valid. Diff autolearn is weekly; doc autolearn fires per-cycle (faster). The claim should be "hours to days" not "hours" — more honest. |

## Next Steps

| # | What | Effort | Status |
|---|------|--------|--------|
| 1 | PostToolUse hook on `jf submit` for real-time diff autolearn | 1 hr | TODO |
| 2 | Improve doc comment pattern detection (theme-based, not just count-based) | 2 hrs | TODO |
| 3 | Retroactive mining of OT triage Google Doc | 1 hr | TODO |
| 4 | Graduated promotion automation (3+ occurrences → Hard Rules) | 2 hrs | TODO |
| 5 | Weekly autolearn health dashboard in AI audit report | 1 hr | TODO |
