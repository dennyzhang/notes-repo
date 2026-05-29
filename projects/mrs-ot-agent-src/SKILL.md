---
name: mrs-ot-agent
description: >-
  Use when triaging an OT SEV, debugging a stuck online training pipeline,
  investigating ATS regressions or growing model age, or unsure whether
  scribe / training / publish / serving is the broken stage. Inputs:
  S<NUMBER> SEV IDs, MVAI OT MAST job names like mvai-training-online-*,
  or GChat SEV space URLs.
user-invocable: true
argument-hint: <gchat-space-url|SEV-ID|MAST-job-name>
---

# OT Triage Agent

Cross-component triage for the online training pipeline. Given a SEV, GChat
space, or MAST job name, queries all 4 pipeline stages in parallel and
identifies which component is degraded. Routes to the responsible team with
evidence and recommended actions.

## Trigger Phrases

Invoke this skill when the user says any of the below. If multiple components
are mentioned (T1+T2 etc.) without a clear bottleneck, this skill is the right
front door.

| User says | Invoke |
|-----------|--------|
| "what's the status of S<NUMBER>" / "triage S<NUMBER>" | yes |
| "<MAST job name> failing" / "OT job stuck" | yes |
| "OT pipeline is stuck" / "online training broken" | yes |
| "model age growing" / "ATS regression" | yes |
| "is this scribe / training / publish / serving" (unsure of stage) | yes |
| "tune a single MAST job" (already-localized to T2 trainer) | no — use `mvai:mast-job-inspector` |
| "feature group lineage" / "new feature onboarding" | no — feature-discovery skill |

## How to Use

| Mode | Command | Latency | When to use |
|------|---------|---------|-------------|
| Fast | `python3 -m src.cli <input> --no-llm` | ~17s | Live SEV — answers in seconds |
| Full | `python3 -m src.cli <input>` | ~45-60s | Polished narrative report |

Run from `fbcode/pe_mrs_ml/mrs_ot_agent`. Input accepts: GChat SEV space URL,
`S<NUMBER>` SEV ID, or MVAI OT MAST job name (`mvai-training-online-XXXXXXXXXX`).

## Guiding Principles

The agent operates by four foundational principles. Every section below is an
implementation of one or more. When extending the agent, ground the change in
a principle and cite it in the diff summary.

1. **Auto-learn — the agent gets smarter by itself.** Every triage produces signal that feeds back into `known_patterns.md`, `src/capabilities/`, and this file without human nudging. Anti-pattern: "interesting observation, log for later" with no fold-back.
2. **Auto-discover signals across surfaces.** Triage input includes Phabricator diffs, wiki updates, GDocs, meeting notes, Workplace posts, GChat threads — not just SEVs/alerts. Classify what's OT-relevant and use it for context.
3. **Optimize for accuracy AND speed.** Triage value = correct diagnosis × time-to-diagnosis. Improve at least one axis without regressing the other; call out real tradeoffs explicitly.
4. **Auto-identify gaps + close them.** Engineering gaps (code/config/routing) → fix in-place via diff. Architecture/decision gaps → write a proposal and engage the POC; don't fix architectural questions unilaterally.

## Triage Discipline

Pattern match is the OPENING of triage, not the conclusion. Every caller (interactive Claude, `team_bot.py` cron, WIB bot @mention, manual CLI) must run the verification chain before publishing a diagnosis. Stopping at "P01 fired with 68% confidence" without ground-truth verification produces an unfalsified guess.

**Full discipline** — verification chain, `[VERIFIED]`/`[INFERRED]` per-fact tagging, Quality Rules 1-18 + R5b, diagnosis output template, signal-class taxonomy, stage-skill mapping, two-number confidence, stop conditions: see [human-input/triage-discipline.md](human-input/triage-discipline.md).

## Pipeline

```
Input (SEV/GChat/MAST job)
  │
  ├─ Phase 0: Symptom Distillation (optional)
  ├─ Phase 1: Data Gather (17s, parallel)
  ├─ Phase 2: Deep Gather (5s, conditional)
  └─ Phase 3: Analysis + Report (single LLM call, or keyword fallback)
```

| Phase | Latency | Inputs | Outputs |
|-------|---------|--------|---------|
| 0 Distill | ~5s | Log paste, Scuba URL, screenshot | Structured symptom block |
| 1 Data Gather | 17s | SEV/GChat/MAST job | 8 MAST queries + GChat msgs + signal extraction (`nccl`, `oom`, `stuck`, publish counts) |
| 2 Deep Gather | 5s | Phase 1 signals | Zoomer stragglers (NCCL/stuck), zoomer memory (OOM), system metrics |
| 3 Analyze+Report | ~30s LLM / <1s keyword | Phase 1+2 + 50 patterns + 4 red herrings | 9-section report, bottleneck stage, owner, SLO assessment |

**Pipeline architecture (4-stage diagram + per-stage owner table + Peer Scenario Isolation Phase 0 capability):** see [human-input/pipeline-architecture.md](human-input/pipeline-architecture.md).

**Decision matrix** (T1/T2/T3/T4 degradation → bottleneck/owner): see [human-input/decision-matrix.md](human-input/decision-matrix.md).

**Worked example** (S644354 end-to-end Phase 1 → Phase 3): see [human-input/worked-example-S644354.md](human-input/worked-example-S644354.md).

## SLO Targets (H1 2026)

| Metric | Criteria | Target |
|--------|----------|--------|
| ATS Sparse Latency | Hourly P90 scribe delay + model age ≤ 10 min | 95% hours/week |
| ATS Item Latency | Hourly P90 item delta model age ≤ 10 min | 95% hours/week |
| Streaming Success Rate | Hourly avg ≥ 99% | 95% hours/week |

## Known Patterns

50 patterns + 4 red herrings + 4 triage journals: [known_patterns.md](known_patterns.md). The tool matches error text against these BEFORE LLM analysis.

**Failure-mode taxonomy + GIL/NCCL concept reference + disambiguator command list:** [`human-input/ot-failure-mode-catalog.md`](human-input/ot-failure-mode-catalog.md). Read this before any triage where the symptom set includes BOTH "snapshot stuck" AND "DPP QPS low" — the catalog's cause-vs-consequence map prevents misdiagnosing trainer hangs (P44/A1) as publish-pipeline failures (D-class) or DPP-side issues (E-class).

**Mandatory trainer-liveness probe** (run BEFORE any D/E hypothesis when symptoms include stuck snapshot + low QPS):
```bash
meta scuba.dataset query -d mvai_metrics --view=samples --columns=time \
  -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' \
  --hours=12 -l 1 --order-by=time
```
If latest sample is stale > 5 min while MAST attempt is RUNNING → trainer Python is hung (P44/A1). Don't chase D/E until A is falsified. Source: 2026-05-13 model 2135033479 misdiagnosis.

## Auto-Learn

At the end of every triage, append a candidate `P<N+1>` row to `known_patterns.md` if all three: (1) cause→symptom→fix not yet there, (2) diagnosis confirmed (queries ran, data fits), (3) reusable in next 6 months. **Auto-trigger:** when the triage states "no known pattern matches" AND symptom is well-defined, the candidate row MUST appear inline — not "follow up later". Row format: id, ≤40-char name, error keywords, stage (T1/T2/T3/T4), fix, owner, time-to-apply. Skip on generic LLM observations, duplicates under a different name, one-off config typos, or narration from a closed SEV's GChat.

Worked example (P27 from a Workplace post): [human-input/auto-learn-p27-example.md](human-input/auto-learn-p27-example.md).

## Report Sections (names)

1. SLO Status   2. Pipeline Path   3. Findings Summary   4. Hypothesis Board
5. Blast Radius   6. Similar SEVs   7. Recommended Actions   8. Evidence Package   9. DEPR Assessment

Field-level shape for each section: [human-input/output-schema.md](human-input/output-schema.md).

## Common Pitfalls

| Pitfall | Why it bites | Fix |
|---------|-------------|-----|
| `meta ai.mast-job logs` without a search pattern | Hits 538MB PHP limit on large OT jobs → OOMs the triage tool | Always pass a targeted search pattern |
| Stale `query-error-context` data | Sometimes returns prior-version errors; misroutes triage | Cross-reference with `error` output before trusting |
| Empty `system-metrics` output | Treating as "healthy" misses real perf issues | Use `profiling` instead — system-metrics is unreliable |
| Investigating a known red herring | Wastes minutes on benign signals (e.g., Hedwig `SELECTION_NO_HOST`) | Check Ruled-Out list in [known_patterns.md](known_patterns.md) FIRST |
| Trusting MVAI OT debug skill verdict | Reported "logs expired" when they were available (S628346) | Always verify the underlying tool output, not just the skill summary |
| Assuming `mvai-training-online-<id>` is a trainer | The same MAST naming convention covers BOTH actual training jobs AND SilverTorch update service (STUS) publish jobs. STUS doesn't train — it consumes upstream root checkpoints and republishes. Trainer-side hypotheses (in-process scheduler, NCCL, OOM, step counter) are FALSE on STUS jobs; STUS-side hypotheses (upstream feed, GMPP backpressure) are FALSE on real trainers. Hit 3x in one session 2026-05-08 (m2128360468 / m2125399403 / m2125249288 / m2133142909). | **Always run `meta ai.mast-job metadata --name=mvai-training-online-<id>` and grep `entrypoint` BEFORE forming any role-specific hypothesis.** STUS entrypoint contains `silvertorch/experimental/st_update_service/st_update_service.py`. See R14 in [human-input/triage-discipline.md](human-input/triage-discipline.md). |
| Blaming downstream symptom (P17 fire-app expired, GMPP, in-process scheduler) when upstream recurring flow is disabled | Disabled recurring flow → no recurring runs → no fresh fire-app rebuilds → old pin auto-deletes → trainer can't pull → no checkpoints → STUS skips publish. The cascade looks like P17, but the fix is upstream. Operator wastes time rebuilding fire-app on a model the owner deliberately decommissioned. Source: 2026-05-08 m2133142909 — bot blamed P17, operator manually found recurring flow 8921769 was `is_enabled: false`. | **Before blaming downstream, run `meta ai.recurring-job recurring-flows --owner=<owner>` and check `is_enabled` for the flow that drives the trainer.** If `false` → that's the root cause; downstream symptoms are consequences. See R15 in [human-input/triage-discipline.md](human-input/triage-discipline.md). |
| Misdiagnosing publishing alerts by using the wrong data source | `meta ai.model.instance list` uses the `snapshot_type` UMM field, but the publishing stability detector queries Scuba `dai_modelstore` with a derived column: `COALESCE(publish_mode, snapshot_type, 'FULL_SNAPSHOT')`. These can diverge — `model.instance list` may show 0 FULL_SNAPSHOT while the detector (and UMM UI filtered to FULL_SNAPSHOT) sees healthy publishing. Using `model.instance list` led to wrong diagnoses 3 times on the same model (2132070936): May 8 (DENSE_DELTA), May 23 (FULL_SNAPSHOT), May 28 (FULL_SNAPSHOT). | **For any publishing stability alert: query the SAME Scuba source the detector uses, not `meta ai.model.instance list`.** Run: `meta scuba.dataset query -d dai_modelstore -a count --group-by=snapshot_type --hours=6 --where='[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]},{"column":"is_failure","op":"eq","values":["0"]},{"column":"event","op":"eq","values":["ModelPublishSuccess","UMMCommitModelInstance"]}]'`. If the expected type has non-zero count in Scuba but 0 in `model.instance list` → the model IS publishing; `model.instance list` is unreliable for this check. See R16 in [human-input/triage-discipline.md](human-input/triage-discipline.md). |

## Key Commands

| Signal / Symptom | Command |
|------------------|---------|
| Job state, hosts, region | `meta ai.mast-job metadata --name <JOB>` |
| Last error, last kill | `meta ai.mast-job error --name <JOB>` |
| Failure interval / restart pattern | `meta ai.mast-job attempts --name <JOB>` |
| PENDING vs RUNNING time | `meta ai.mast-job scheduling --name <JOB>` |
| Auto insights (Zoomer WARNINGs) | `meta ai.mast-job insights --name <JOB>` |
| Per-rank straggler analysis | `meta ai.mast-job analyze-zoomer-stragglers --name <JOB>` |
| Per-rank memory analysis | `meta ai.mast-job analyze-zoomer-memory --name <JOB>` |

## Data Sources

| Stage | Scuba Table | Key Columns |
|-------|-------------|-------------|
| T1 | `ig_online_training_ats` (stage='Scribe') | `model_type`, `p90_latency` |
| T2 | `fct_ats_training`, `training_platform_model_events` | `model_type`, `training_latency` |
| T3 | `gmpp` | `model_type`, `publish_mode`, `model_snapshot_id` |
| T4 | `runtime_freshness:ai_infra` | `tenant_id`, `event_type`, `control_plane_type` |

## Reference Files

| File | Purpose |
|------|---------|
| [known_patterns.md](known_patterns.md) | Pattern DB (50 patterns, 4 red herrings) |
| [human-input/ot-failure-mode-catalog.md](human-input/ot-failure-mode-catalog.md) | Failure-mode taxonomy (A–F classes), GIL/NCCL concepts, smoking-gun rules, disambiguator command list, cause-vs-consequence map |
| [human-input/triage-discipline.md](human-input/triage-discipline.md) | Verification chain, per-fact tagging, Quality Rules 1-18 + R5b, signal-class taxonomy, stage-skill invocation, two-number confidence |
| [human-input/pipeline-architecture.md](human-input/pipeline-architecture.md) | 4-stage diagram + Peer Scenario Isolation capability |
| [human-input/decision-matrix.md](human-input/decision-matrix.md) | Stage-degradation → bottleneck/owner mapping |
| [human-input/worked-example-S644354.md](human-input/worked-example-S644354.md) | End-to-end Phase 1 → Phase 3 example |
| [human-input/output-schema.md](human-input/output-schema.md) | Field-level shape for the 9 report sections |
| [human-input/triage-reference.md](human-input/triage-reference.md) | Per-stage Scuba queries, health thresholds |
| [human-input/models.md](human-input/models.md) | In-scope model table with entity IDs |
| [human-input/ownership.md](human-input/ownership.md) | Component ownership, delegation routing, oncall contacts |
| [human-input/tw-log-recipes.md](human-input/tw-log-recipes.md) | tw log query recipes for trainer/publisher logs |
| [human-input/auto-learn-p27-example.md](human-input/auto-learn-p27-example.md) | Auto-learn worked example (P27 from Workplace post) |
| [human-input/external-skill-inventory.md](human-input/external-skill-inventory.md) | Sibling skills owned by other teams (TGIF model-processing, IP serving-debug) and how to register a new one |
| [contracts/](contracts/) | Integration interface for partner team skills |
| [integration/](integration/) | Sub-agent bridges (MVAI, SilverTorch, Recsys) |
| [auto_learn/](auto_learn/) | Auto-learning ingest pipeline (P2-10) — curation gate, distillation wrapper, retrieval, feedback log |
| [journals/](journals/) | Backtest validation (S644354, S628346, S640723, S647381) |
| [tests/](tests/) | 437+ tests: decision matrix logic + fast triage tool |

## Key Documents

| Document | Link |
|----------|------|
| Design doc | [MRS OT Master Agent Proposal](https://docs.google.com/document/d/1Zf3-P_fYdiGngU3qjYUGbEesQNnE1t1MifIIJipG-cY/edit) |
| IG OT SLO dashboard | [SLO Dashboard](https://ig-data-apps.internalmeta.com/ig/relevance-foundations/online-training-slo/) |
| Meta Task | [T259215482](https://www.internalfb.com/T259215482) |
