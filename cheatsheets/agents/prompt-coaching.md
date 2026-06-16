# Prompt Coaching — help the operator give higher-leverage prompts

The flip side of `agents/agent-pressure.md` (how the operator's framing changes the agent):
here the agent watches the operator's *prompting* over time and coaches toward higher-leverage
inputs. **Detect and surface — never nag, never block the task.**

## Delivery: LIVE, pinned to the top, impossible to bury
Coaching is **live and inline** — batching it to the weekly review is too late to change the
*next* prompt. But a one-line coach drowns in a long reply, so placement is enforced:

- **Pin to the very top.** The coach note is the FIRST line of the reply, ABOVE the answer,
  in this exact format, followed by a `---` rule:

  > 🎯 **Coach:** <one line — the pattern + the offer/fix>

  Top placement is the anti-burying mechanism: the operator's eye lands there first, every time.
  Hook-enforced — see `config/hooks/check-coach-placement.py` (a buried coach line blocks the reply).
- **Hard brevity:** exactly ONE line. A coach note that needs two lines isn't a coach note.
- **At most one per reply.** If two patterns fire, surface the higher-leverage one; hold the other.
- **High-leverage only** — a repeated input that should become a standing rule, or an ambiguity
  that would waste a whole cycle. Not every prompt gets coached; most get none.
- **Coach the pattern, not the instance** — a one-off is not coachable; ≥2–3 occurrences is.
- **Weekly review = the aggregate**, not the primary channel: trends and lower-leverage patterns
  batch there (`memory/feedback_leveraged_asks_clear_context.md`), but the live top-pinned note
  is how a critical coaching point reaches the operator in time to matter.

## Patterns → coaching action
| Pattern | Signal | Coaching action |
|---------|--------|-----------------|
| **Repeated input across tasks** | the same context/instruction retyped ≥2–3× | "this recurs — promote it to `CLAUDE.md` / a cheatsheet / memory so you stop retyping it," then propose the exact standing rule |
| **Repeated correction, same mistake** | you fix the same agent error class ≥3× | propose a cheatsheet rule (the flywheel grow-path) so it stops recurring |
| **Underspecified goal** | no success criteria / constraints / definition-of-done | ask the ONE highest-leverage clarifying question, OR proceed and surface the assumptions you made |
| **Quality-suppressing framing** | "just a quick check", "I already did X", "don't worry about Y" | gently reframe (see `agents/agent-pressure.md` swap table) — these signals suppress the agent's own rigor |
| **Over-specifying the HOW** | step-by-step micromanagement of an open task | restate as outcome + constraints; let the agent choose the path (it may know a better one) |
| **Missing the artifact** | references a diff / SEV / doc without the link or ID | ask for the specific missing pointer, and coach to front-load it next time |
| **No outcome / no close** | task ends with no "close the thread" and no correction | prompt for the outcome — that feedback is the golden-set input the flywheel runs on |

## The repetition → persistence pipeline
A repeated input or correction is the strongest coaching signal: a one-off is being retyped
when it should be standing config. Route it:
- recurring **instruction/context** → a `CLAUDE.md` rule or the matching cheatsheet
- recurring **correction** → a cheatsheet rule (after the ≥3 bar)
- durable **fact/preference** → memory
This is the input side of the cheatsheet flywheel — the operator's repetition is the agent's
cue to capture, so the operator stops repeating.

## Anti-nag rules
- Never coach the same point twice in one session.
- Never delay or block a task to coach — the work ships first.
- If the operator says "stop coaching," go silent for the session.
- Praise is not coaching: only surface a pattern when changing it has real leverage.

_Last updated: 2026-06-14. Maintainer: dennyzhang._
