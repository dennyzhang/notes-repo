# KD Proposed Change — 2026-05-20 (BOT_INCOMPLETE: dirty working copy, 2nd consecutive day)

**Status**: NOT COMMITTED — notes repo dirty (`ot-prompt-change-validator-state.json` M).
Bot detected the pattern and wrote this proposal for operator review. To land: clean working copy,
apply the diff below, then `sl commit + jf submit --draft`.

**Prior pending proposal**: `kd-proposed-2026-05-19.patch.md` (R16 bootstrap-gap sub-case) is
ALSO unactioned. Today's proposal EXTENDS that one with new evidence from 4 additional false-alarm
scribe-lag archives.

---

## Run Summary

| Field | Value |
|---|---|
| **Date** | 2026-05-20 13:30 PT |
| **New summaries scanned** | 9 |
| **Sources** | resolved-sevs: S651873, S665607, S666007; resolved-alerts: A1009946182010606, A1427819186056622, A1480195820275950, A1600949354510906, A813403845176709, A2149157265940350 |
| **Threshold fired** | Threshold 2 (false-alarm R16, same alert family ≥ 2) |
| **Blocker** | BOT_INCOMPLETE: dirty working copy (2nd consecutive day) |

---

## Pattern Detected (Threshold 2 — false-alarm signature ≥2, same alert family)

### Scribe-lag false-alarm cluster — 4 instances in 7-day window

| Alert | Model | Root | Class | P-row match |
|---|---|---|---|---|
| A1480195820275950 (2026-05-18) | ig_reels_tab_ss_omni_retrieval 2144816217 holdout | ZippyDB S665163 → scribe lag | TRANSIENT_NOISE | P58 ✓ (covered) |
| A2149157265940350 (2026-05-18) | ig_organic_feed_mtml 878102693 | ZippyDB S665163 → scribe lag | NO_ACTION | P58 ✓ (covered) |
| A1427819186056622 (2026-05-19) | ig_reels_starsearch_t2i_retrieval 2145491885 holdout | ARM disabled + upstream SEVs S660677/S659877 → CL-003 cascade; item-emb sub-alerts = R16 FALSE_ALARM | FALSE_ALARM | P58 ✗ (ARM-disabled sub-case NOT covered) |
| A1600949354510906 (2026-05-20) | ig_reels_tab_mtml 2132766001 holdout | Transient scribe spike, no active ZippyDB SEV; 36% chronically noisy holdout → THRESHOLD_MISFIT | THRESHOLD_MISFIT | P58 ✗ (transient-no-SEV sub-case NOT covered) |

**Key finding**: 2 of 4 instances are NOT covered by P58. P58 requires an active ZippyDB SEV.
The uncovered sub-cases are:
1. **ARM-disabled cascade** (A1427819186056622): upstream model ARM disabled → entrepot_cache
   stops feeding examples → scribe lag metrics spike → holdout alert fires. No ZippyDB SEV. R16 correctly
   classifies item-emb sub-alerts as FALSE_ALARM. No triage pattern for the ARM-disabled → scribe lag path.
2. **Transient scribe spike** (A1600949354510906): brief scribe spike (3-min window) on a holdout
   model class with 36% chronic alert noise rate. No active SEV. THRESHOLD_MISFIT. The 36% noisy-holdout
   context is known (Peiyang Yu threshold tuning in-flight) but not codified in any P-row or R16 example.

### Proposed action (Threshold 2 → triage-discipline.md R16 addition)

Add two R16 sub-case bullets covering the ARM-disabled and transient-noisy-holdout scenarios.
Also add R16 validation evidence line (cumulative: now N=5 independent summaries validate R16 in
2026-05-18 to 2026-05-20 window, adding to the N=3 proposed yesterday).

---

## Additional signal (not threshold-met, noted for next run)

### bot_self_correction (Threshold 3, 1 of 2 needed)

- **ALERT-813403845176709** (2026-05-19): Bot triage applied P61 (Conveyor regression / FS blocked
  while trainer runs). Post-resolution: alert auto-recovered before S665902 mitigated → actual root
  cause was NaN bootstrap gap (P56/P59) on model 2134801434, not S665902 conveyor (which affects
  cogwheel-test sub-model 2122381387, different path). **Correction class**: wrong_root_cause
  (P61 applied but P59 was correct). **Root issue**: P59 is NOT in known-patterns.md (only proposed
  in daily-ledger), so bot matched P61 (in team context) instead. Fix: land P59.
- **1 instance only** — threshold 3 needs ≥ 2. Deferred.

### P59–P63 landing backlog (meta-observation)

| Pattern | Proposed | Source | Status |
|---|---|---|---|
| P59: Post-NaN bootstrap gap → FS missing TRANSIENT_NOISE | ~2026-05-18 | daily-ledger L14 | NOT in known-patterns.md |
| P60: Simultaneous sibling NaN = family-wide CL-017/P56 | ~2026-05-18 | daily-ledger L16 | NOT in known-patterns.md |
| P61: Conveyor publish-path regression → FS blocked | 2026-05-19 | daily-ledger L18 + team context | NOT in known-patterns.md |
| P62: [Invalid Detector - No Data] prefix → DETECTOR_BROKEN | 2026-05-20 | daily-ledger L21 | NOT in known-patterns.md |
| P63: STUS kmeans corpus underflow → trainer crash | 2026-05-20 | daily-ledger L22 | NOT in known-patterns.md |

**Known-patterns.md max = P58**. Five consecutive daily-ledger proposals are stuck. Two consecutive
knowledge-distillation runs have been blocked by dirty working copy. The bot is USING P59-P63 in
triages (citing them as "proposed" or "from team context") but they are not in the canonical pattern
DB — this causes classification errors (e.g., A813403845176709 misclassified as P61 when P59 was
the right pattern). **Priority action for operator**: land P59–P63 or clean the working copy so the
next KD run can draft the diff.

---

## Proposed Unified Diff

**File**: `fbcode/pe_mrs_ml/mrs_ot_agent/references/triage-discipline.md`
**Rule**: R16 — add ARM-disabled and transient-noisy-holdout sub-cases + cumulative validation evidence

```diff
--- a/fbcode/pe_mrs_ml/mrs_ot_agent/references/triage-discipline.md
+++ b/fbcode/pe_mrs_ml/mrs_ot_agent/references/triage-discipline.md
@@ R16 row, after the existing P56/bootstrap-gap sub-case added in kd-proposed-2026-05-19, before | R17 | @@
+
+**R16 sub-case — ARM-disabled cache stop → upstream scribe lag (CL-003 cascade, NOT ZippyDB):** When
+a scribe_read_proxy.client_lag alert fires and there is NO active ZippyDB SEV, check whether
+upstream model cache (e.g., `igml::entrepot_cache_*`) has its ARM disabled. If ARM is disabled, the
+cache stops feeding training examples → scribe lag metrics rise → holdout alert fires. This is a
+CL-003 sub-mechanism distinct from P58 (which requires an active ZippyDB SEV). **Verification**: check
+for upstream infra SEVs (S660677/S659877-class) AND inspect ARM status for
+`igml::entrepot_cache_<model_family>`. If ARM disabled + no ZippyDB SEV + holdout model + item-emb
+sub-alerts produce 0 ITEM_EMB_DELTA → R16 false alarm, CL-003 cascade sub-case. No OT action.
+Escalate to IG OT SLO / Josef Cohen for ARM re-enable. **Source**: ALERT-1427819186056622
+(2026-05-19, ig_reels_starsearch_t2i_retrieval holdout 2145491885).
+
+**R16 sub-case — chronically noisy holdout model scribe spike (THRESHOLD_MISFIT, no SEV needed):**
+For IG holdout models with documented chronic alert noise (e.g., 36% false-alarm rate on
+ig_reels_tab_mtml holdout 2132766001), a brief transient scribe spike (<10 min) that fires an AGG
+alert BUT the underlying training pipeline is healthy (SPARSE_DELTA continuous, MAST RUNNING, no
+error) → classify as THRESHOLD_MISFIT without deep investigation. **Verification**: (1) Confirm AGG
+fire window < 10 min via alert timestamps. (2) Confirm model is publishing via `meta ai.model.instance
+list --model-id=<ID>`. (3) Check `noisy-models.md` for this model ID / model_type_name. If all three
+→ THRESHOLD_MISFIT, no OT action. Route threshold-tuning request to Peiyang Yu (threshold tuning
+in-flight per 2026-05-18 domain context). **Source**: ALERT-1600949354510906 (2026-05-20,
+ig_reels_tab_mtml holdout 2132766001).
+
+**Validation evidence (R16 cumulative — updated 2026-05-20):** Validated by N=5 independent triage
+summaries between 2026-05-18 and 2026-05-20: (1) ALERT-1621571482326635 (ZippyDB → sparse latency,
+NO_ACTION); (2) ALERT-4366891846955592 (CL-017 bootstrap gap → FS baseline, NO_ACTION); (3)
+ALERT-898952803114953 (CL-017 bootstrap gap → FS holdout, NO_ACTION); (4) ALERT-1427819186056622
+(ARM-disabled CL-003 → holdout scribe lag, FALSE_ALARM); (5) ALERT-1600949354510906 (transient
+scribe spike → noisy-holdout THRESHOLD_MISFIT). All correctly bot-classified at confidence: high or
+medium. Pattern is robust across 3 distinct sub-cases (snapshot-type mismatch, bootstrap-gap,
+scribe-spike-transient).
```

---

## How to Land

```bash
cd ~/notes
sl status  # must show CLEAN — fix ot-prompt-change-validator-state.json M first
# Option A: commit that state file change if it's intentional
sl add users/dennyzhang/projects/mrs-ot-agent-src/state/ot-prompt-change-validator-state.json
sl commit -m "chore: ot-prompt-change-validator-state.json update"
# Option B: revert it if it's stale / erroneous
sl revert users/dennyzhang/projects/mrs-ot-agent-src/state/ot-prompt-change-validator-state.json

# Then: apply the diff above manually to the appropriate triage-discipline.md
# (notes copy OR fbsource copy depending on sync workflow)
# arc lint -a <file>
# sl commit -m "[OT bot] knowledge-distillation 2026-05-20: R16 ARM-disabled + noisy-holdout sub-cases"
# jf submit --draft --update-fields
# NEVER add publish_when_ready tag
```

---

## Combined with 2026-05-19 Proposal

The 2026-05-19 proposal (R16 bootstrap-gap sub-case) is ALSO pending. If landing both:
- Apply kd-proposed-2026-05-19.patch.md diff first (bootstrap-gap sub-case)
- Apply this diff second (ARM-disabled + noisy-holdout sub-cases + updated validation evidence)
- Single commit with combined message referencing both dates.
