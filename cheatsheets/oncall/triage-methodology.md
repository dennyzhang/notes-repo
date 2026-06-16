# Triage Methodology — Generic Quality Framework

> **GROUND TRUTH for generic triage methodology (R1–R13).** The OT agent loads this via the `CLAUDE.md` triage routing row. Prior context-tree forks (`mrs-ot-agent-context/human-input-{generic/triage-methodology,domain/triage-discipline}.md`) are deprecated stubs pointing here. OT-specific rules R1–R21 with OT examples live in `mrs-ot-agent-src/human-input/triage-discipline.md`. Edit here; do not re-fork. (Consolidated 2026-06-10.)

Reusable triage discipline for any alert/SEV/incident monitoring agent. Domain-specific extensions (OT commands, signal taxonomy, stage-skill routing) live in the domain doc that imports this framework.

**Pattern match is the OPENING of triage, not the conclusion.** Every triage caller must run the verification chain before publishing a diagnosis. Stopping at "pattern P fired with 68% confidence" without ground-truth verification produces an unfalsified guess.

## Per-fact tagging — VERIFIED vs INFERRED

Every load-bearing claim carries one of two markers:

| Marker | Means | Example |
|---|---|---|
| `[VERIFIED]` | Sourced from direct query output. Exact command must appear in Evidence Package. | `Job v32 died 21:21 PDT [VERIFIED via <command>]` |
| `[INFERRED, NOT PROVEN]` | Hypothesis from pattern-match / correlation / analogy. Not confirmed by direct data. | `S658056 is upstream cause [INFERRED — needs timeline correlation]` |

A diagnosis with no markers of either kind is wrong — both should appear.

Source: 2026-05-02 incident asserted a fact at 80% confidence based on a single anomalous query; explicit `[INFERRED]` tagging would have surfaced over-confidence.

## Evidence coverage & the discriminating artifact (log-heavy / deep-dive investigations)

Cherry-picked from the MVAI `mvai-ot` deep-dive-investigation-report format (D108074069, 2026-06-09) — generic disciplines for any event-by-event investigation where you reconstruct a timeline from logs. (The VERIFIED/INFERRED + evidence-block discipline above already covers the rest of that format; these six are the net-new pieces.)

- **Headline reframes the surface assumption — never restates it.** When the evidence contradicts the dashboard, say so in the first line (+ confidence tag). *Bad:* "QPS is 0, job appears stuck" (restates the symptom). *Good:* "Job is training, not hung — each step takes 6–13 min in the GPU backward pass + Shampoo optimizer ⇒ QPS≈0 (confidence: high — batch counter advances; FR confirms)." A headline that only confirms the alert adds nothing.
- **State coverage limits — a gap is a finding, not an embarrassment.** Name which hosts/ranks/streams and which time-window you actually read, AND what you could NOT retrieve. A conclusion drawn from host-0 only is **not** a conclusion about hosts 1–2. Every claim's blast radius = the evidence behind it; scope the verdict to what you covered and flag the rest as an explicit gap.
- **Confirmed vs. not-determined as two explicit lists** (extends VERIFIED/INFERRED). For each "not determined" item, name the single artifact that would resolve it — don't guess. "*Why* backward is slow (straggler vs NCCL vs Shampoo root-inverse cost) — the FR dump at `<path>` settles it" beats silently dropping the open question.
- **Next steps end on the discriminating artifact + a conditioned route.** Don't route past the evidence: name the oncall, but condition it on what the next artifact shows ("if FR shows a never-enqueued rank → optimizer-code owner; if a GPU never completed → host fleet"). The single most-discriminating check goes last and explicit, with cheap rule-in/rule-out actions.
- **Record the dead-ends, not just the replayable commands.** In Investigation Commands, include what FAILED and the tooling caveat (e.g. `mast get-logs --use-logarithm` errors with "start time is larger than end time" on a still-RUNNING attempt) so the next responder skips the same dead end.
- **Phase-group a log timeline; never flat-dump.** Group sequential events into phases (restart/scheduling → container bring-up → NCCL pre-check → trainer setup → first batch → steady state); each line = timestamp + what the log *literally* shows. Tabulate repeating units (steps, publish cycles, restarts).

## Quality Rules (generic)

Extracted from operator feedback across 30+ incidents (2026-04 → 2026-05). Each rule addresses a specific failure mode that produced a wrong or unhelpful diagnosis.

| # | Rule | Mandate | Failure mode without it |
|---|---|---|---|
| R1 | **Baseline before anomaly** | Cite same job/metric in known-good window before claiming "broken/slow". | Reader can't tell anomalous from normal. |
| R2 | **Layered hypothesis enumeration** | Enumerate every layer the symptom could live at, rule each in/out. No single-hypothesis diagnoses. | Guess masquerading as diagnosis. |
| R3 | **Code-pointer on recommendations** | Every "fix X" cites file path + line. | 5-min file hunt to act on the recommendation. |
| R4 | **Tiered recommendations** | SHORT (≤1d, config flip/revert); MEDIUM (≤1w, cross-team); LONG (weeks+, refactor). | Quick wins weighted same as refactors. |
| R5 | **Soft cross-refs include verification** | Next-action MUST include verification command BEFORE any contingent fix. NOT "if X is upstream, do Y"; instead "first run Z to verify; if yes, then Y". | Soft refs promoted to action items on wrong premises. |
| R5b | **Cross-ref that matches symptom verbatim is the standing hypothesis** | When a cross-ref's title/impact matches the reported symptom verbatim, that cross-ref is the default standing hypothesis until falsified. Don't elevate an inferred new hypothesis above it. | Inferred-but-novel hypotheses feel more specific and get elevated above exact-match open incidents. |
| R6 | **Temporal consistency on suspect diffs** | First-occurrence time ≥ suspect's land time before naming it as regression source. Pull occurrences explicitly. | First-occurrence pre-dates the diff → at most amplifier, not trigger. |
| R7 | **Frequency-over-time inflection check** | For multi-day incidents, plot occurrence frequency. Step-change → check diffs near inflection. | "Soft-warn → hard exception" pattern: latent gap tolerated for days, then a validator diff converts warn to exception. |
| R8 | **Entity multiplicity rule** | Pull the incident's full entity list before forming entity-specific hypothesis. Single → likely entity-specific config; multiple → systemic. | Per-entity fixes chased on systemic problem. |
| R9 | **Mechanism over conclusion** | When the diagnosis is a misconfig, perf regression, or resource exhaustion, name the data-flow chain (Phase A → Phase B → ...) and identify which phase the symptom emerges in. | Reader sees "X causes Y" without understanding *how*; can't extrapolate the fix to sibling cases. |
| R10 | **Calibration anchors on numeric fix recs** | Every numeric knob change cites (a) typical safe value across the fleet AND (b) safe value for the offender's class. Also cite preconditions. | "Reduce X" without anchors makes the operator guess. |
| R13 | **Long-running ≠ stalled — require progress signal** | "Job is 3× baseline duration" is NOT evidence of stuck. Before claiming stalled, cite (a) step rate / progress signal showing flatline, OR (b) terminal status showing non-success, OR (c) logs showing no-op for >N× typical interval. | False alarms route attention to a job that is fine. |

## Evidence-first hypothesis discipline

Cherry-picked from imoc `sev-diagnosis-methodology.md` (2026-06-10). Generalizes R2 (layered hypothesis enumeration) with falsification recipes. The point: an automated RCA (Opsmate / SEVmate / rankpilot) is a **hypothesis, not a finding** — it can be confidently wrong, and its detail creates false confidence.

- **Absence test — the cheapest falsifier.** Before adopting any theory, ask: *"what error does this theory PREDICT that is NOT present in the logs?"* If the predicted signature is absent, the theory is wrong regardless of how plausible it sounds. Worked example: theory predicts `TENANT_QUOTA_EXCEEDED` rejections; logs show zero of those and 89% `vector::_M_range_check` crashes → theory is dead, stop reconciling it as a "secondary factor."
- **Keep 2-3 live hypotheses, score each against evidence.** `Theory A (tool finding) — for: … against: …`; `Theory B (timing) — …`; `Theory C (infra) — …`. **Drop** theories the evidence contradicts; do not demote them to "contributing factors" to avoid admitting they're wrong.
- **Take timing coincidences seriously even when the mechanism isn't obvious.** A change landing at the exact onset minute is a strong signal; complex systems have non-obvious dependency paths. Verify by reverting — if the SEV resolves, the result matters more than your mental model of "it shouldn't affect this."

### Cause vs. correlation (especially during large/multi-SEV outages)

Temporal correlation ≠ causation. For any "A caused B" claim run the 3-test:
1. **Directionality** — does A cause B, B cause A, or C cause both?
2. **Mechanism** — can you name the specific code/config path by which A would cause B? (no path = no claim)
3. **Counterfactual** — if A hadn't happened, would B still have occurred?

For a downstream SEV attributed to a parent outage, additionally check: did it start **with** or **after** the parent? did it **recover when the parent was mitigated**? If it didn't recover, it may be independent. And: **"parent mitigated" ≠ "child recovered"** — "mitigated" means the root cause is fixed, not that every downstream cache/connection/state has. Verify recovery from the child's own metrics, not the parent's status.

## Error-log analysis checklist (frequency ≠ importance)

Cherry-picked from imoc `sev-diagnosis-methodology.md`. When reading TW logs / Scuba / pastes:

1. **Count error types by %.** The most-frequent error is usually a *symptom*, not the cause.
2. **Find the earliest error.** The first type to appear is usually closest to the root.
3. **Check causal ordering.** A low-frequency Error A (11%) can *cause* a high-frequency Error B (89%). The 11% one is the root cause, not "a minor issue."
4. **Look for what's absent** (the absence test, above).
5. **Account for log rate-limiting.** One error logged per config-reload vs. one logged per request distorts the ratio — the ratio reflects logging frequency, not importance.

## Branching Five Whys

Cherry-picked from imoc `root-cause-methodology.md`. Structure root cause as ONE primary chain plus optional labeled side-branches — and separate "why it happened" from "why it wasn't caught/contained."

- **Primary chain** (fully `[VERIFIED]`): `Why symptom? → why that? → why possible? → why does that gap exist? → systemic insight`. Each Why peels back exactly one layer; the deepest Why is **never "human error"** — push to the systemic gap.
- **0-3 contributing-factor branches** (2-3 Whys each, `[VERIFIED]`/`[INFERRED]` per branch), only when genuinely distinct from the primary chain:
  - **Detection** — why wasn't this caught earlier? (alerting gaps, monitoring blind spots)
  - **Containment** — why was the blast radius so large? (no circuit breaker, no graceful degradation)
  - **Prevention** — why was this change possible without a safeguard? (missing validation, no staged rollout)
- Each branch carries its own systemic insight. Stop at whatever level is actionable — not all incidents need 5 levels.

**Timeline-consistency check (validation gate).** Before publishing the chain, verify monotonic ordering: `root-cause-time < each intermediate-effect-time < symptom-time`. For multi-causal SEVs, monotonicity applies **per branch**, not across branches (different contributing factors have independent timelines). Timestamp by trigger type: diff land time (Phabricator `committed` field), config/JK committed time (ConfigHub mutation), QE ramp time. Inconsistent within a branch → re-examine the chain or flag it `Partial`. (Extends R6, which only anchors first-occurrence ≥ suspect land time.)

## Cluster discipline

N alerts/incidents share root cause (same entity, same signal class, ≤10 min apart) → ONE diagnosis covering all. Batch before diagnosing.

## Try yourself before delegating

Before any "you should check X" / "please verify Y" line, run this 6-step gate:

| Step | Question | If yes |
|---|---|---|
| 1 | CLI subcommand for X? | run it |
| 2 | MCP tool (loaded or via ToolSearch)? | call it |
| 3 | Capability function in codebase? | invoke it |
| 4 | **Skill for X?** (most-missed step) | load via Skill tool |
| 5 | Direct file/data path? | read it |
| 6 | None worked? | document which tried + failure modes, THEN delegate |

Anti-pattern signal: more "you should check..." lines than "I checked X and got Y" lines → verification is being delegated.

Source: 2026-05-01 — verification was delegated to user for ~2h; a skill with the right recipe was available the whole time.

## Two-number confidence (symptom vs root cause)

Single-number confidence conflates two questions. Always report both:

- **Symptom-attribution:** how sure is the failure in this stage / signal class? (Usually high — direct ground-truth queries.)
- **Root-cause:** how sure are we WHY? (Usually lower — hypothesis about trigger.)

Large spreads (e.g., symptom 85% / root-cause 20%) must be called out — high-symptom is actionable for routing, low-root-cause is a flag to keep digging.

## Diagnosis output template (structural)

Every output appends three sections after the standing hypothesis:

| Section | Format | Why |
|---|---|---|
| **Raw log Evidence** | Lettered blocks (A/B/C) of verbatim log lines, each prefaced by a one-line claim. Hypothesis cites them inline: `NE stalled 22:03→22:40 [Evidence D, F]`. | Claim becomes un-fakeable once literal line is in the diagnosis. |
| **Investigation Commands** | Numbered replayable commands. | Diagnosis becomes a runbook, not a verdict. |
| **Files-touched table** | Path + 1-line role for every "fix in X" recommendation. | Reviewer + future-investigator navigation. |

## When you can stop

| Stop OK if | Don't stop if |
|---|---|
| External boundary (other team's code, off-machine service, foreign incident) | Pattern matched at high confidence (still verify) |
| Concrete next-action requiring human decision | Cron's output looked plausible (cron output IS your input) |
| Standing hypothesis consistent with all ground-truth data | Assignee named (verify it's the right escalation) |
| | "Verifying takes longer" (deep triage takes time — that's the trade) |

_Last updated: 2026-06-10. Maintainer: dennyzhang._
