# MRS ML Infra — SEV Criteria (OT triage reference)

**Canonical source (signed-off):** [MRS ML Infra SEV Criteria](https://docs.google.com/document/d/10kawZuw5eAzpFm8ZvT8Hgy-wfx-Cjw1sPtcLJ_70wOY/edit?tab=t.0)
— POC Catalin Toda (cit); signed off by MRS ML / Silvertorch / MVAI EMs + TLs (Dec 2025).
Auto-synced daily to `references/gdocs/mrs-ml-infra-sev-criteria.md` (slug in
`references/gdocs/sources.json`). This file is the **distilled triage lookup**;
the gdoc is ground truth — re-check it if a number here looks stale.

**Use during triage to assign / sanity-check SEV level.** The bot does NOT set or
change SEV state (read-only on SEV surface, per CLAUDE.md); this is for the
level the triage *verdict* asserts and for escalation framing only.

## How to read the table

- Criteria shape: **"X% of all models in Tier-Y exceeding Z hours."**
- Default impact metric ≈ **model hasn't published a snapshot** (Paul Lu). Broad
  by design — also counts *degraded* (e.g. publishing snapshots at ~50% of normal
  cadence), not only fully-stalled.
- **Product impact overrides the table (upward):** if a model causes business/
  product impact before these thresholds, ML Infra elevates the SEV to match the
  product impact. e.g. 1 Tier-1 model causing 25% product impact → SEV2.
- **Scope = multi-model outages.** These criteria are for outages impacting **>1
  model**. A single model degrading generally falls under the SEV3
  "model generation stability" row, not a fleet SEV.

## OT (Online Training) — the lane that matters here

| SEV | Condition | Tier | Impact time |
|-----|-----------|------|-------------|
| **1** | > 90% of models | TIER-1 | > 24h |
| **2** | > 25% of models | TIER-1 | > 12h |
| **3** | > 10% of models (**≥ 3 models** impacted) | TIER-1 or TIER-2 | > 3h |
| **3** | > 50% of models | TIER-1 & TIER-2 | > 1.5h |
| **3** | 1 model | TIER-1 | > 3 full-snapshot publishing cycles going stale **AND no DELTAs published in between** |

> OT note (Catalin, from doc comments): if a full publish is in flight when the
> next checkpoint lands, a full may be scheduled back-to-back so no delta is
> emitted in between — that alone is expected; the SEV3 row is about *staleness*
> across ≥3 cycles. If no item-embedding delta is generated, an alert fires.

## Recurring Training (adjacent — minimal_viable_ai oncall)

| SEV | Condition | Tier | Impact time |
|-----|-----------|------|-------------|
| **1** | > 90% of models | TIER-1 | > 24h |
| **2** | > 25% of models | TIER-1 | > 24h |
| **3** | > 25% of models | TIER-1 & TIER-2 | 8h |
| **3** | 1 model **training** | TIER-1 | IFR Retrieval >12h · IFR Ranking >12h · CFR >24h · Video >24h |
| **3** | 1 model **publishing** | TIER-1 | IFR Retrieval >12h · IFR Ranking >24h · CFR >48h · Video offline >24h |

(Per-PG single-model SLOs live in the PG SLO docs linked from the gdoc:
IFR, CFR, Video.)

## Trunk Health (mrs_ml_release_oncall — usually a footnote in OT briefs, not headline)

| SEV | Condition | Tier | Impact time |
|-----|-----------|------|-------------|
| **1** | MC delayed / MB / Cargo for ≥1 model | TIER-1 | 10 weeks |
| **2** | MC delayed / MB / Cargo for ≥1 model | TIER-1 | 2 weeks |
| **2** | 2+ PG conveyors (no MC delayed) | TIER-1 | 2 weeks |
| **3** | **light_cli broken** | TIER-1 | > 1 business day |
| **3** | 1 IG conveyor | TIER-1 | > 2.25 days |
| **3** | 1 Discovery conveyor | TIER-1 | > 4 business days |
| **3** | 2+ PG conveyors, same issue | TIER-1 | > 3 business days |

> `light_cli` has the tightest SLO because it is upstream of every conveyor — a
> broken trunk binary cascades into many conveyors (rationale: Catalin). This is
> why a `light_cli`-class runtime regression (cf. war story S669019, py3.12 leak)
> is high-leverage even when each individual job looks survivable.

## Tier source of truth

- **Model Registry** is canonical. Resolve a model's tier via `cbgf <model_id>`
  or PMT [production_models/mrs](https://www.internalfb.com/production_models/mrs).
- Tier-1 = the most important, limited-slot set (PGs choose). ~200 models across
  Tier-1 & Tier-2.
- Trunk-health tiering: retraining a Tier-1 model on trunk classifies it Tier-1
  for trunk health too.

## Coverage areas → owning oncall

| Area | Oncall |
|------|--------|
| Online Training (produces Full/Delta/Streaming snapshots) | `mrs_online_training` |
| Recurring Training | `minimal_viable_ai` |
| Publishing (checkpoints → Full Snapshots; item-embedding deltas via ST Update Service) | `home_ml_platform` |
| Trunk Health (age since last healthy revision) | `mrs_ml_release_oncall` |
| Serving (out of scope of this doc) | `feed_ranking_infra` |

## References (from the doc)

- Reels SEV guidelines v2 — Consumption relevance (internal wiki)
- Feed Metrics Oncall Runbook § SEV-Criteria (internal wiki)
- Per-PG SLO docs (IFR / CFR / Video) linked in the Recurring SEV3 rows
