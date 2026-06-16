# Building an agent eval / self-evolve system

Generic method distilled from the OT-agent eval build (2026-06-09/10). Reusable
for any agent where you want measurable, self-driven improvement.

## The frame
An agent that self-improves needs **variation + selection + retention**. Most
agents have variation (a distillation/proposal loop) and retention (knowledge
files) but no **selection** — so they can only propose, never self-pick. The
eval IS the selection mechanism. Build it first; evolution is then just "keep
changes that raise the eval score."

## Build order (do NOT reorder)
1. **Complete the measuring stick BEFORE optimizing.** Optimizing against a
   partial fitness function overfits to the measured part and silently degrades
   the unmeasured part. Wire every term (even as `null`/`missing_terms`, never
   faked) before turning on mutation.
2. **Trust the grader before auto-accepting.** A single same-model grader shares
   the agent's blind spots. Add a cross-model co-grader (e.g. codex) and measure
   agreement; low agreement → fix the grader, don't mutate.
3. **Then mutate**, gated: keep a change only if composite ↑ AND zero regression
   on the FULL gold set (not a sample) AND it passes adversarial review.

## Fitness function design
- **Reward calibrated competence, not raw accuracy** — especially with no human
  in the loop, confident-and-wrong is the worst outcome. Use a proper scoring
  rule: `1 − (correctness − stated_confidence)²` per case.
- **Hallucination = hard per-case gate**, not a soft term.
- **Pair calibration with decisiveness** so the agent can't game by always
  hedging (high calibration, zero value).
- **Demote instrumental metrics** (e.g. "cited the right rule") — they're
  gameable proxies; score the terminal outcome.
- **Report generalization separately, never fold in** (see leakage).

## Gold-set / corpus traps
- **Curate ruthlessly:** only cases with a *confirmed* ground truth are eval-able.
  Stub/empty/unconfirmed cases score noise. Expect to drop a third.
- **Separate input (what the agent saw) from answer.** Archives usually mix them.
- **Leakage = memorization, not skill.** If the knowledge base was built FROM the
  eval case, the agent "wins" by reciting the answer key. Flag leak-suspect; the
  true number needs **temporal hold-out** (only knowledge predating each case).
- **Measure both jobs:** "given a signal, should I engage?" (detection_recall +
  scoping_precision, needs a negative/noise corpus) is often higher-cost than
  "given an incident, what's the diagnosis?". A triage-only eval is flattering.

## Grader = independent
Separate subagent, sees only the published output + ground truth, NOT the
diagnosing reasoning. The diagnoser rationalizes; the independent grader catches
it. Same principle as a validator pass.

## Honest-signal discipline
- Fixing harness bugs often *confirms* a real problem rather than inflating the
  score — don't assume a flat number after a fix means "no progress."
- No silent truncation: log sampled/capped/missing-term coverage every run.
- A grep over natural-language signals (e.g. operator "you missed X" flags) is
  too noisy — use an LLM extraction pass, or a tiny optional tag for precision.

## Implementation notes
- Dynamic workflows (fan-out subagents) make a full corpus eval minutes not hours.
- Use resume/incremental eval: re-run only the cases a change can affect.
- Loop cadence: gaps > one iteration + an idempotency HEARTBEAT guard = runs
  self-throttle instead of overlapping. More frequent ⇒ faster Goodhart, so keep
  the regression gate on the full set.

## Hard-won lessons (2026-06-12 — running it for real)
- **Report mean ± std over k runs, never a single run.** An LLM-graded eval at n≈60 swings **±~0.03**
  between *identical* runs. A candidate whose gain is ≤ that noise band is luck, not a win — gate on it
  (`eval-stats.sh`: append each run, reject sub-std gains). Single-run deltas lie.
- **FREEZE the corpus; only re-run the decision.** If you re-mine the test set each run, scores aren't
  comparable run-to-run (a "regression" may just be a different corpus). Freeze inputs; bump a `version`
  on curation. Applies to every sub-corpus (gold set AND scoping/negative set).
- **Anti-poisoning is the #1 integrity risk — enforce it executably.** The answer must NEVER appear in
  the input (else you measure memorization, not reasoning). A prose "don't leak the root cause into the
  body" gets ignored — add a code guard (reject if an N-word shingle of ground_truth appears in input).
  Also report a `leak_suspect`/generalization-adjusted score so leaks are visible + discounted.
- **Auto-curate the gold set, but SCORE-BLIND.** Append new confirmed incidents automatically; NEVER
  add/drop a case based on whether the agent passes it (teaching-to-the-test corrupts the eval). Prune
  only the safe class (dups, orphaned source) — never hard cases.
- **Hoist any var the final report reads.** A var scoped inside a branch (e.g. the archive-curation
  path) that the report reads on *every* path = a ReferenceError that crashes AFTER a full expensive run.
- **Concurrency/timeout from a daemon ≠ interactive.** Heavy per-agent context (100s of KB) × wide
  fan-out times out a headless runner; throttle to small waves. "Worked interactively" ≠ "works in cron."
- **A LOOKUP is not a reasoning rule.** A dim that's really a deterministic lookup (e.g. owner→team via a
  CLI) will never converge as a prose rule — every fix spawns edge cases. Move it to a capability. If a
  target needs >2 rule redesigns, switch targets or escalate.

Last updated: 2026-06-12
