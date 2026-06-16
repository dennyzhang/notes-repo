[ot-autofix-diff-drafter cron] Daily ~11:13 PT. DEDICATED, single-purpose loop: turn each open [OT auto-fix] task the monitors file into a reviewable --draft fix diff. Deliberately separate from ot-knowledge-distillation (which distills patterns) so this stays single-purpose and reliable — one job, one responsibility.

SCOPE — draft whatever the task requires; route by the task's diagnosis to the right repo (NO artificial scope limit — the task defines the fix):
- Detector misconfig (THRESHOLD_MISFIT / DETECTOR_BROKEN) → configerator detector-tuning diff + MANDATORY PROVE-no-mask backtest.
- Code defect (fbcode capability/trainer/infra) → fbcode fix diff; the diff-subagent runs pyre/tests/lint.
- Agent-repo gap (cron prompt / capability / cheatsheet / script) → notes agent-repo diff.
- Config / data / other → route to the matching repo + the matching verification the task implies.

HARD GUARDRAILS (unchanged regardless of scope):
- **--draft ONLY, NEVER land** (operator / code owner lands). **Cap 1 diff/run.** **Dedup** — skip any task with a linked diff. Reviewers = the owner named in the task. Diff author + tasks stay owner=dennyzhang (owner-guard hook enforces).
- **Conservative-when-uncertain:** only draft when the task's diagnosis is CLEAR and the fix is VERIFIABLE for its type (detector → PROVE-no-mask backtest; code → tests pass; behavior → repro). If it can't be verified, COMMENT the task with exactly what's missing and draft NOTHING. A noise diff is worse than no diff.

EFFECTIVENESS (the point — measured, not hoped):
- **Quality over volume:** every diff goes through the diff-subagent (verbatim `references/diff-subagent-prompt.md`, incl. check #5 reproduce-symptom + full-behavior + verified-terminology, + the repo cheatsheet) so it's landable, not noise. Pick the highest-value eligible task (priority, then age) with a clear+verifiable fix — not just the first.
- **Track drafted→landed** in `state/ot-autofix-diff-drafter-state.json` ({drafted, landed, rejected/abandoned, per-task diff ids}). The weekly digest surfaces the LAND RATE — that is the effectiveness metric. A low land rate = the drafter is producing noise → tighten the clear+verifiable bar. (Self-watching: if drafts aren't landing, stop drafting that class until tuned.)
- **One event = one diff**, linked to its task; comment the diff on the task so the operator isn't asked to re-find it.

EFFECTIVENESS-GAP GUARDS (think-hard caveats — a diff that trips any of these is worthless or HARMFUL; check each before drafting):
- **Duplicate at the ISSUE level, not just task level.** Before drafting, search for ANY diff touching the same detector/file/model — in-flight by ANYONE, OR a prior **abandoned/rejected** one (the task often has no linked diff precisely because its diff was abandoned — re-drafting it repeats a rejected fix). Found → comment the task with the pointer, draft NOTHING. Also dedup TASKS: if ≥2 [OT auto-fix] tasks describe the same underlying issue, draft once and link all.
- **Thin diff.** A diff must PREVENT RECURRENCE, not just silence today's alert. Before submit, answer in the diff: "what recurrence does this prevent, and how is that verified?" If the honest answer is "it stops the alert firing," it's thin → reject, comment the task. A number-tweak with no root analysis is thin.
- **Masking (MOST dangerous).** A threshold raise/widen — OR a detector REMOVAL — that silences an alert catching a REAL degradation HIDES a failure. The PROVE-no-mask backtest must be ADVERSARIAL: replay the detector's recent REAL fires; if the new threshold/removal would miss ANY genuine one, REJECT. "No-mask" is the gate, not a formality.
  - **"No-data" is a SPECIFIC measurement, never inferred from low volume (2026-06-08, D107959319 masking miss).** Remove a detector ONLY if `one_detection_stats` (30d) shows `invalidDetectorAlertCount>0` AND `numViolatingTS=0` AND `newDataPoints=0`. **Low `dataPointsRead`/`newDataPoints` per run (e.g. max 3) is NOT no-data** — sparse real data is still real. If `numViolatingTS>0` the detector fired on a REAL breach → removal MASKS it → REJECT (retune-with-owner, not remove). D107959319 removed two cs_omni detectors reading real data (dataPointsRead~1430, newDataPoints~127, invalidDetectorAlertCount=0) that fired real violations (numViolatingTS 20/194); the earlier backtest misread "max 3 pts/run" as no-data. Cite the literal per-detector counts in every detector diff.
- **Stale task.** Verify the issue is STILL live NOW (SEV In Progress / detector still misfiring / symptom reproduces) before drafting. Resolved → comment + leave for operator to close, draft nothing. Never fix an already-fixed issue.
- **Blast radius.** A shared detector (one detector → N models) change hits all N. The backtest must cover all N and the summary must state the blast radius. Don't mutate a shared detector to fix one model's symptom.
- **Land-rate circuit-breaker.** If drafted→landed rate falls below ~50% over the last ≥4 drafts (from state), STOP drafting and alert the operator 1:1 — the drafter is emitting noise; pause until tuned. Self-halt beats endless noise.
- **Owner/repo from live data.** Verify the reviewer-owner (live, not the task's possibly-stale field) and the correct target repo before drafting.

Steps:
1. Query open [OT auto-fix] tasks (owner=dennyzhang, tag mrs-ot-reliability, title prefix `[OT auto-fix]`, status open, NO linked diff). Rank by priority then age. (Deterministic selection — keep this a flat query, not LLM judgement.)
2. Take the top task whose fix is CLEAR + VERIFIABLE. If none → `HEARTBEAT_OK {autofix_diff: none_eligible}`.
3. Dispatch the diff-subagent to draft the fix IN THE RIGHT REPO for the task's type, with the task's diagnosis + the required verification. `jf submit --draft` (NO --publish-when-ready), Reviewers=owner, Tasks: link the auto-fix task.
4. Drafted → `--add-diff` to the task, comment the task with `D<id>`, bump `drafted` in state, post ONE line to operator 1:1 (`🛟 auto-fix diff drafted: D<id> for T<id> (<area>) — review/land`). Then `HEARTBEAT_OK`.
5. Not safely draftable → comment the task with the blocker, draft nothing, `HEARTBEAT_OK {autofix_diff: blocked}`.

Never auto-land. Never post to team space. Read-only on every external surface except the --draft diff. Conservative by construction; when in doubt, comment the task rather than draft.
