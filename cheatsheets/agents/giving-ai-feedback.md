# Giving AI Feedback — Cheatsheet

_Distilled from the OT master-agent CLAUDE.md feedback corpus. The rules that made feedback stick vs. evaporate._

## The 6 things that make a rule land

1. **Name the failure mode precisely.**
   "You posted narration to team chat" beats "that was wrong."
   The rule can only be encoded if the failure has a clear label.

2. **Give a concrete example.**
   Thread ID, date, exact output quoted. Abstract rules drift; a specific case anchors them.

3. **State the desired behavior, not just the prohibition.**
   "HEARTBEAT_OK for no-op runs" > "don't send narration."
   Prohibition leaves the agent guessing what to do instead.

4. **Explain the why.**
   "operator's bandwidth is limited" makes the rule self-enforce in edge cases the rule never anticipated.
   Without a why, the agent finds the nearest loophole.

5. **Generalize immediately.**
   "Don't special-case, fix the class." (P-020)
   If one cron does it wrong, say: "apply this to all sibling crons."
   Otherwise you play whack-a-mole per instance.

6. **Mark scope and strength explicitly.**
   "HARD", "ALL jobs", "cron AND interactive", "no exceptions."
   Soft language = optional in the agent's read.

## Anti-patterns (feedback that doesn't stick)

| What you said | Why it didn't land | Better form |
|---|---|---|
| "that's not right" | No failure label, no desired behavior | "You sent X; correct is Y because Z" |
| "fix it" | No root cause, no generalization | "Fix the class; here's the pattern" |
| "I don't want this" | Prohibition without replacement | "Instead of X, do Y" |
| "as I said before" | Assumes prior memory | Restate the rule fully; agents don't accumulate like humans |
| "be more careful" | Unmeasurable | "Gate on condition C before action A" |

## When to give feedback vs. when to just add a rule

- **Feedback** (to the agent mid-session): when the agent just did something wrong and you want it corrected NOW.
- **Rule in CLAUDE.md** (durable): when the same failure has happened ≥2 times. One instance is a correction; two is a pattern worth codifying.
- **Cheatsheet entry**: when the failure is modality-specific (gchat, diff, gdocs) and reusable across sessions.

## The "why ask" failure mode

If the next step is obvious, reversible, and within already-stated goals — just do it.
Asking "want me to X?" when X is clearly the right next step wastes a round-trip and trains the agent to gate on confirmation it doesn't need.
Reserve asks for: irreversible actions, privacy boundary crossings, genuine ambiguity about which direction to take.

## Format that works for CLAUDE.md rules

```
## Rule title (HARD if non-negotiable)

[One sentence: the behavior and its scope]

**Why:** [the incident or constraint that motivated it]

**Applies to:** [cron / interactive / both; all jobs / specific job]

**Example failure:** [date, thread, what went wrong]
**Correct form:** [what the output should look like instead]
```

_Source: OT master-agent CLAUDE.md corpus, 2026-06-14._

_Last updated: 2026-06-14. Maintainer: dennyzhang._
