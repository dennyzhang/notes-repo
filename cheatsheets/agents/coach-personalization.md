# Coach Personalization — Per-User Goal Calibration

**Principle**: any AI coach / advisor / evaluator must read a per-user calibration file FIRST,
BEFORE inheriting goals from its prompt header, system instructions, or domain defaults. Different
users have different goals; a single-frame coach gives the wrong advice in good faith.

**Origin**: 2026-06-27 — Denny's ai-coach had hardcoded *"Denny is an IC6 ML Infra TL targeting
IC7"* in its prompt header. The coach inherited that frame and built 7 painpoints + dozens of
forcing functions around IC7-promotion acceleration. Denny's ACTUAL goals are different
(problem-solving mastery, connections, sustainability, flourishing — not promotion race). Denny
flagged the drift: "different people want different goals, so the coach will be adjusted to what
they need."

---

## The mechanism

| Piece | What |
|-------|------|
| **`<user>-CALIBRATION.md` file** | Per-user file. States: real goals, what they DON'T want, default cadence preference, tone, hard-no boundaries. Owned by the user; coach never edits without explicit instruction. |
| **Prompt instruction** | Coach reads CALIBRATION FIRST, BEFORE goals, journal, or any default. If a recommendation would violate calibration, calibration wins. |
| **Quarterly check-in** | Coach surfaces ONE question in periodic output: *"Are your stated goals still your real goals?"* If user doesn't answer, defaults hold. If they do, calibration updates. |

---

## What goes in a CALIBRATION file (minimum schema)

1. **What the user actually wants** — their words, not your inferred frame. 3–5 sentences max.
2. **Default-overrides table** — for each default the coach would apply, what's the recalibrated version. E.g. "Score artifacts for promotion-visibility" → "Score for depth + connection quality."
3. **Goal recalibration** — if there's a separate GOALS.md, the weight/tier shifts that override it.
4. **Cadence preference** — daily / weekly / monthly default. Many users want weekly even if the coach defaults to daily.
5. **Tone calibration** — what kind of pushback is welcome, what kind isn't.
6. **What to ASK periodically** — open questions the coach surfaces but never assumes.

---

## Why this matters more than it looks

Two failure modes a coach can have:
- **Loud failure**: gives bad advice that's obviously wrong → user corrects → coach learns.
- **Quiet failure**: gives plausible advice optimized for the WRONG goal → user follows for months
  → outcome doesn't match user's life → user can't trace the drift back to the calibration error.

Quiet failure is the larger risk. Without a calibration file, the coach can't tell whether its
default frame matches the user — and the user may not notice the drift until significant time
has been spent on the wrong objective function.

---

## Sentinel for "is this calibration-aware?"

A coach is NOT calibration-aware if:
- The prompt header hardcodes goals ("user is targeting X").
- Recommendations are framed in terms of one fixed altitude/outcome.
- Cadences are prescribed (daily / weekly) without a user-stated preference.
- The coach never asks "are these still your goals?"

If any are true, install the CALIBRATION mechanism before next use.

---

## What NOT to do (calibration anti-patterns)

- **Don't let the coach edit CALIBRATION** without explicit user instruction. The file is user-owned;
  coach-suggested edits cross the line from "advisor" to "agenda-setter."
- **Don't bury calibration in goals.md weights.** Weights communicate priority within a frame;
  calibration sets the FRAME itself. Different concept.
- **Don't infer calibration from observed behavior.** Behavior is often forced by circumstance;
  what the user WANTS may not match what they DO. Ask, don't pattern-match.
- **Don't over-update on a single message.** If the user expresses a goal once, mirror it but
  don't rewrite the calibration without confirming it's a stable frame.

---

## Reference

- Origin file: `projects/ai-coach-private/COACH-CALIBRATION.md`
- Sibling principle: `cheatsheets/agents/tracker-intake-filter.md` (filtering BEFORE accepting captures)
- Sibling principle: `cheatsheets/agents/auto-save-learnings.md` (compounding coach quality)

Last updated: 2026-06-28
