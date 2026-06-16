```yaml
fix_id: pattern-registry-verifiable-triple
title: Every "known issue pattern" entry must carry a verifiable triple (metric + log + ≥3-job spot-check) before bot uses it for classification
status: 🔴 planning (in progress)
identified: 2026-05-27 thread yF_aMB00xMk
meta_task: T273151495
target:
  - notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/patterns/failure-patterns.md  # CL-NNN cluster registry
  - notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/patterns/failure-modes.md     # M-NNN registry
  - team_bot/cron-jobs/ot-alert-monitor.md (+ ot-sev-monitor.md, ot-post-monitor.md)
  - NEW: team_bot/cron-jobs/ot-pattern-validator.md (monthly drift detector)
impact: Eliminates "fabrication-by-citation" — bot can no longer echo a pattern's population claim without re-grepping
cost: ~1 week (inventory + schema + DPP pilot + cron amendment + validator)
```

## Gap

The bot's pattern DB (`failure-patterns.md` CL-NNN clusters + `mitigations.md` D-NNN + symptom→cause `edges.md`) is rich in narrative evidence but light on **machine-verifiable signatures**. Every entry today lists SEVs/Workplace-posts as evidence, but:

- No structured **metric signature** (ODS path + shape + threshold + recovery window) the cron can re-evaluate.
- No tight **log signature** (`meta ai.mast-job error` substring that ONLY this failure mode emits).
- No periodic **spot-check validation** — the listed evidence is frozen-in-time and may have drifted (signature may now match unrelated failures, or population may have evaporated).

Result: when the cron cites a pattern as the verdict, it's leaning on narrative pattern-matching not provable signature-matching. Population claims get echoed without re-validation.

## Triggering evidence (2026-05-27 thread `yF_aMB00xMk`)

1. SEV S667544 + paste P2349020385 claimed "140 DPP rotation hits / 90d / 50+ models, all self-recovering" (CL-013 sub-mechanism #8).
2. Bot (me) repeated the claim as the basis for proposing a bot rule `TRANSIENT_DPP_ROTATION → 🟢 NO ACTION`.
3. Operator asked: can you confirm the MAST log signature for real?
4. Spot-check of top-hit job `mvai-training-online-2137730772` (3 hits in the paste): actual `meta ai.mast-job error --no-truncate` returned `Preempting job ... RUNNING_ON_BORROWED_CAPACITY` on every sampled failed attempt. **Not DPP rotation — preemption.**
5. Root cause of the over-count: Scuba filter was `LIKE 'RetryableFatalSystemError: Session%'` — too loose. Catches non-rotation `Session%` errors.
6. **Confirmed-rotation population is 1** (`mvai-training-online-886797001` / S667544 / v68 attempt 0). Everything else was unverified inflation.

## Required schema — Verifiable Triple

Every CL-NNN cluster and every sub-mechanism (P-row) must gain a `## Verifiable Triple` block:

```markdown
## Verifiable Triple

### Metric signature
- ods_metric: `<dataset>.<entity>.<key>`  (e.g., `mrs.examples_age{model=<id>}`)
- shape: `spike | stall | drop | ramp`
- threshold: `> 10 min` (or `< 1 QPS`, etc.)
- recovery_window: `<= 30 min` (or `n/a` if non-recovering)

### Log signature
- source: `ai.mast-job error --no-truncate` | `ai.mast-job logs` | `scuba ai_mlu` | etc.
- must_contain: `["substring1", "substring2"]`   # ALL must appear, tight enough to exclude siblings
- must_not_contain: `["preempt", "RUNNING_ON_BORROWED_CAPACITY"]`   # disambiguate from confounders

### Validation
- spot_check_jobs:
    - mvai-training-online-<id1> v<N>/<a>  # link to bunny
    - mvai-training-online-<id2> v<N>/<a>
    - mvai-training-online-<id3> v<N>/<a>
- validated_on: YYYY-MM-DD
- validator: <unixname> | ot-pattern-validator cron
- population_query: `<exact scuba/sql with tight filter>`
- population_size: <N hits / 90d / M distinct models>  # re-derived, not echoed
```

Loose substring filters (`%Session%`, `%Failed%`, `%timeout%`) are population-inflation risks and are **forbidden** in `population_query`.

## Plan (6 phases)

### Phase 0 — Inventory
Walk `auto-learnings/patterns/{failure-patterns,failure-modes,mitigations,root-causes,symptoms,systemic-causes}.md` + any `known-patterns.md` / P-row source. Output a table: one row per pattern × columns `[id, name, has_metric_sig, has_log_sig, has_validation, last_validated, status]`. Status = `VERIFIED | UNVERIFIED | NEEDS_TIGHTENING`. Expected outcome: most entries are UNVERIFIED today.

### Phase 1 — Schema definition
Codify the `## Verifiable Triple` block above. Add to `auto-learnings/patterns/INDEX.md` as the new entry-template. Update [`feedback_known-pattern-validation.md`](../../../../.myclaw-ot-bot/spaces/AAQAVOjYc80/memory/feedback_known-pattern-validation.md) to reference this schema.

### Phase 2 — DPP-rotation pilot (concrete first case)
Cheapest test of the schema. For CL-013 sub-mechanism #8:
1. Run tightened Scuba: `error_message LIKE '%higher than limit: 1728000 seconds%' AND error_message LIKE '%restart is necessary to prevent the session%'` over last 90d on `ai_mlu`, `job_name LIKE 'mvai-training-online%'`.
2. Compute actual hit count + distinct model count. Compare to original "140 / 50+" claim.
3. Spot-check top 3 jobs from the tightened result via `meta ai.mast-job error --no-truncate`.
4. Populate the Verifiable Triple for CL-013-#8 with real numbers.
5. Decision point: do we still want a bot rule + DPP-team ask? Yes only if tightened population is materially noisy.

### Phase 3 — Bot enforcement
Amend `ot-alert-monitor.md` (and `ot-sev-monitor.md`, `ot-post-monitor.md`) deep-triage step so the bot MUST cite a `VERIFIED` Triple before classifying as a known cluster. Patterns marked `UNVERIFIED` cannot drive a `NO_ACTION` / `MONITOR` verdict — they downgrade to `NEEDS_INVESTIGATION` until repaired. Follow three-layer flow per [[gotcha_cron-prompt-three-layer-flow]]: edit notes-md → UPDATE sqlite via `readfile` → SHA256-parity → let weekly sync handle fbcode.

### Phase 4 — Monthly pattern-validator cron
New cron `ot-pattern-validator.md` (monthly, 10th of each month). For each VERIFIED pattern:
1. Re-run `population_query` → confirm hit count > 0.
2. If hits = 0: flag DRIFT (pattern may be retired; downgrade to WATCH).
3. Spot-check 3 random jobs from the population → confirm both metric_signature and log_signature match.
4. If any spot-check fails: flag SIGNATURE_DRIFT (auto-downgrade to UNVERIFIED).
5. Post results to OT space.

### Phase 5 — This doc
You're reading it. Tracks back to T273151495.

## Standing rule (saved to operator memory)

[`feedback_known-pattern-validation.md`](../../../../.myclaw-ot-bot/spaces/AAQAVOjYc80/memory/feedback_known-pattern-validation.md): echoing a paste/SEV population claim without re-grepping is fabrication. Cite as "N reported, X confirmed" if you haven't validated.

## Cross-references

- [[gotcha_triage-discipline]] — sibling: blast-radius before citing S-numbers
- [[gotcha_url-discipline-bare-ids]] — sibling: identifiers must be resolved before cited
- [[feedback_known-pattern-validation]] — operator memory for this rule
- T273151495 — meta-task tracking this work
- S667544 / P2349020385 — confirmed-rotation evidence anchor
- `notes/users/dennyzhang/projects/mrs-ot-agent-context/system-fixes/auto-fixes/2026-05/03-registry-first-triage.md` — predecessor: bot MUST consult registry before verdict (this fix adds: registry entries must be VERIFIED before bot trusts them)
