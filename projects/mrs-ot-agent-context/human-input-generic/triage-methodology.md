# Triage Methodology — Generic Quality Framework

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
