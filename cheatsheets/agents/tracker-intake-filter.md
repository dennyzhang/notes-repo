# Tracker intake filter — reject-at-capture for any tracking system

**Principle**: any tracking surface (painpoint, follow-up, alert, task, suggestion, backlog) needs
an intake filter that REJECTS items at capture, not just expires them later. Without it the surface
bloats with filed-and-forgotten items that drown the genuine signal.

**Origin**: 2026-06-27 — PP-006 (mvai-layer-patching) was tracked in `PAINPOINTS.md` as S3
despite having a named owner (Harry Han / MVAI oncall via `#fileatask`) and zero ongoing Denny
load. Denny flagged "this one is so small. you should have a self-defensive to avoid this."
Auto-close-in-21-days isn't enough — by then the digest noise has already cost Denny attention.

---

## The 4 rules (apply BEFORE assigning an ID / opening a row)

| Rule | Reject if … | Why |
|------|-------------|-----|
| **R1 — named owner** | Item has a named owner (person, oncall, task with assignee) AND user is not blocked AND no recurrence history | It's their work, not the user's load. Track in their system, not ours. |
| **R2 — single-shot mechanical** | Low-sev mechanical item with action already in flight (filed task, draft sent, PR open) AND no expected user touch | It's an open ticket; existing followup/task tracker owns it |
| **R3 — already covered** | Area overlaps an existing higher-sev item (mindset gap, structural ask, durable principle) | Avoid double-surfacing the same thing; the higher-sev row absorbs it |
| **R4 — too narrow** | Single-incident item with no pattern claim AND auto-resolved at incident close | Don't track ephemeral incidents; they leave no scar worth carrying |

---

## Downgrade-not-reject (softer path)

When ONLY some criteria match, lower the severity instead of rejecting:

- One tier down if a clear owner exists but user still has occasional touchpoints (review, sign-off).
- Two tiers down + reject if same plus no expected touch at all.

## Override

`<prefix>!` (with bang) skips the filter entirely — user's manual override for "I know it looks
small, track it anyway." Use sparingly; logged as `[override]` in the audit trail.

---

## What rejection MUST do (not just refuse silently)

1. **Surface in the next digest / output** as a one-line note: `Rejected at capture: <desc>
   [reason: R<n>]`. Silent rejection hides system behavior from the user.
2. **Append to the coach/agent's own learning file** (e.g. `COACH-FEEDBACK.md`) as a `[keep]`
   bullet so the filter compounds — over time the rules tighten based on real-world signal.
3. **Be reversible** in one line — user can re-add with `painpoint!` (or equivalent override)
   if the rejection was wrong.

---

## Where to apply this

| Tracker | Existing intake filter? | Recommended |
|---------|------------------------|-------------|
| `FOLLOWUPS.md` | Yes — "does this serve Goals 1-3? hard cap 10 active" | Already aligned |
| `PAINPOINTS.md` | Yes — R1–R4 above, added 2026-06-27 | Canonical example |
| `ALERTS.md` | Auto-clear on next green run (different shape) | Keep — same family principle (don't accumulate) |
| Any new tracker | Add intake filter before first item | Mandatory; don't ship a tracker without one |

---

## Anti-pattern: "we'll auto-close stale items"

Auto-close after N days is a SAFETY NET, not the primary defense. The primary defense is
rejecting at capture. If the only filter is the expiry timer:

- The user sees noise in every daily digest for the full quiet window.
- The signal-to-noise ratio of the tracker degrades — users stop reading it.
- The auto-close mechanism gets tuned tighter and tighter to compensate, eventually closing
  things that DID matter.

**Capture filter is for relevance. Expiry timer is for forgotten-but-was-valid items.** Both,
not one.

---

## Quick smoke test for any new tracker

Before launching, answer:
1. What's the intake filter? (If "we accept everything," go back.)
2. What happens on rejection? (Silent fail = bug.)
3. How does the user override a wrong rejection? (Friction → user stops trusting the system.)
4. Does the filter learn from rejections? (One-shot rules calcify; rejection-logging compounds.)

If any answer is missing, the tracker isn't ready.

Last updated: 2026-06-28
