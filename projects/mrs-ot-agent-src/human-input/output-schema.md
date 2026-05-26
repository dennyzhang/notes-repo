# Output Schema

Field-level shape for each report section. The LLM that writes the report must populate every field; missing data → `unknown` literal, never fabricated.

> **Back to:** [SKILL.md](../SKILL.md)

**Section 0 (mandatory header) — Model Metadata.** Every triage output starts with a one-line model header so cross-team readers can classify urgency and ownership before scanning the body. Same controlled vocabulary as in [crisp-report-style.md → Model metadata field](crisp-report-style.md#model-metadata-field--controlled-vocabulary).

**Section 0.5 (mandatory) — Symptoms / breaking metrics.** Inserted between Model Metadata and SLO Status. Surfaces *what's actually broken* up front — user-facing impact in one line, then bulleted breaking metrics with concrete observed values (and expected/threshold values where known). Lead with what the user/operator would notice ("trainer stalled", "snapshots missing", "model age growing"), then the supporting metric values. Use concrete numbers, not categories. Source: 2026-05-12 operator feedback in thread `ws1U5g43l7Y` after S663027 triage buried the symptom under verification ceremony — reader had to infer "what's broken" from Ground-truth.

| Section | Field | Type | Example |
|---------|-------|------|---------|
| 0 Model Metadata | `model_name` | string or `unknown` | `ig_textpost_feed_esr` |
| 0 Model Metadata | `model_id` | string or `unknown` | `2133142909` |
| 0 Model Metadata | `arch` | enum: `silvertorch`/`in-trainer`/`fblearner-flow`/`other:<freeform>`/`unknown` | `silvertorch` |
| 0 Model Metadata | `importance` | enum: `prod`/`holdout`/`qe`/`canary`/`dev`/`unknown` | `prod` |
| 0 Model Metadata | `owner` | unixname or `unknown` | `chengchengyuan` |
| 0.5 Symptoms / breaking metrics | `user_impact` | one-line user-facing impact | `Trainer attempt failures every ~40min — QPS≈0` |
| 0.5 Symptoms / breaking metrics | `breaking_metrics` | bulleted list of `<metric>: <observed value> [vs <expected>]` items, ≥1 | `- attempt success rate: 0/3 last 2h (was 92h stable)\n- QPS rank-12: 0 since 19:20 UTC\n- TTD: 62 min (alarm 50968828639)` |
| 1 SLO Status | `state` | enum: `within_budget`/`burning`/`breached`/`unknown` | `burning` |
| 1 SLO Status | `budget_consumed` | string (% or hours/8h budget) | `5.5h of 8h weekly budget` |
| 2 Pipeline Path | `bottleneck` | enum: `T1`/`T2`/`T3`/`T4`/`monitoring_gap`/`no_issue` | `T2` |
| 2 Pipeline Path | `confidence` | enum: `HIGH`/`MEDIUM`/`LOW` | `HIGH` |
| 2 Pipeline Path | `evidence` | bulleted list, ≥3 items | `- Zoomer comm WARNING\n- 3 FAILED attempts\n- ...` |
| 3 Findings Summary | `confirmed` | string list | `Communication bottleneck: 40%+ GPU comm` |
| 3 Findings Summary | `ruled_out` | string list with reason | `OOM (memory 46.4% avg)` |
| 3 Findings Summary | `open` | string list of unverified items | `Publishing correlation (no Scuba CLI)` |
| 4 Hypothesis Board | rows | table: `#, hypothesis, status, evidence, owner, next_step` | see [worked example](worked-example-S644354.md) |
| 4 Hypothesis Board | `status` per row | enum: `HIGH`/`MEDIUM`/`LOW`/`RULED_OUT` | `HIGH` |
| 5 Blast Radius | `affected_models` | int | `1` |
| 5 Blast Radius | `serving_impact` | enum: `confirmed`/`unknown`/`none` | `unknown` |
| 6 Similar SEVs | rows | table: `pattern_id, sev_id, resolution_summary` | `P19, S628346, concurrent delta disabled` |
| 7 Recommended Actions | rows | numbered: `[Owner] action with concrete CLI` | `1. [SilverTorch] Query gmpp Scuba ...` |
| 8 Evidence Package | `mast_url` | URL or `unknown` | `https://www.internalfb.com/mlhub/pipelines/runs/mast/<JOB>` |
| 8 Evidence Package | `sev_url` | URL or `unknown` | `https://www.internalfb.com/sevmanager/view/<NUMBER>` |
| 8 Evidence Package | `paste_paths` | local file paths | `/tmp/sev-triage-S644354/{metadata,errors,attempts}.txt` |
| 9 DEPR Assessment | `detection_gap` | string or `none` | `No GMPP publish-event alerting` |
| 9 DEPR Assessment | `escalation_gap` | string or `none` | `none` |
| 9 DEPR Assessment | `prevention_gap` | string or `none` | `Concurrent delta + full publish unsafe combo` |
| 9 DEPR Assessment | `remediation_gap` | string or `none` | `No automated revert on accelerating-failure detection` |

## Optional templates

### Tabular trade-off comparison (use when 3+ settings/modes/options)

When the diagnosis hinges on comparing 3+ configuration settings, modes, or options against their defaults, render as a table — bullet lists obscure the structure. Two canonical shapes:

**Setting × Default × Problem** — for misconfig diagnoses:

| Setting | Default value | Problem |
|---------|--------------|---------|
| `embedding_delta_percentage` | 1.0 (100%) | Streaming ALL embedding rows every cycle |
| `skip_embedding_table_names` | empty set | Every table included, even low-freshness ones |
| `allow_concurrent_delta_during_full_publish` | False | Deltas blocked during full publish → burst after |
| `max_publishing_rate` | None | Falls through to JK default (800 MB/s) |

**Mode × Cost dimension** — for "which mode" comparisons (used to rule out a tempting hypothesis):

| Mode | GPU overhead | CPU memory impact | QPS impact |
|---|---|---|---|
| MOMENTUM | Higher (continuous DeltaStore tracking) | Minimal | ~2% more QPS loss vs ID_ONLY |
| ID_ONLY | Lower (tracks accessed IDs only) | Minimal | Less QPS loss |

Source: 2026-05-08 operator-shared paste GJqDYSlR6JPB96oFAOtruCpDcE1Gbr0LAAAz (Fei Ding S653266 IFR MTML investigation). The bullet-list version of the same content was 2× longer and harder to scan.

### References block (use whenever ≥3 external links cited)

Group all SEV/MAST/diff/file-path links in a closing **References** block, not scattered mid-text. Format:

- MAST job: `https://www.internalfb.com/mlhub/pipelines/runs/mast/<JOB>`
- SEV: `https://www.internalfb.com/sevmanager/view/<ID>`
- Suspect config: `<path>:<line>` (file path + line, per Quality Rule R3)
- Related paste / FAQ: `P<id>` or `https://www.internalfb.com/intern/everpaste/?...`

Mid-text inline citations (e.g., `[Evidence A]`, `[Quality Rule R6]`) still go inline — the References block is for the auditable URL trail, not for proof-of-claim citations.

## Crisp report style (for cross-team / external-facing posts)

The 9-section template above is for INTERNAL-DEBUG output (this team space, in-thread replies during active triage). When the bot posts to surfaces OUTSIDE this team space — `mrs.ot` Workplace group, SEV GChat space root, cross-team channels — use the **5-element crisp template** instead. The verbose 9-section output goes to a paste; the post body links to it.

Template, when-to-use, anti-patterns, and a worked good-vs-bad example: see [crisp-report-style.md](crisp-report-style.md).

Quick summary:
- Title: `[OT triage] <job-id> (<class>) — <symptom> at <when>`
- **PROBLEM**: 1 sentence + 1-2 numbers
- **LIKELY CAUSE**: 1 sentence + `path:line` code-pointer (per R3); prefix `[INFERRED]` if unverified
- `Detail reporting: [P<id>](https://www.internalfb.com/intern/paste/P<id>)` — paste created BEFORE post
- **ASK**: 1 sentence, 1 ask

Source: 2026-05-08 operator-cited example post `1320976936663716` ("[OT triage] mvai-training-online-2133142909 (SilverTorch) — full snapshot ~9 h stale, hourly cadence broke at 07:42 UTC").
